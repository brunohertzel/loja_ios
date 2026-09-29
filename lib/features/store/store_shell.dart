import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/generated_app_config.dart';
import '../../core/config/platform_info.dart';
import '../../core/models/bootstrap_config.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../../widgets/brand_logo.dart';
import '../auth/auth_repository.dart';
import '../auth/biometric_service.dart';
import '../auth/login_page.dart';
import '../cart/cart_controller.dart';
import '../sofie/sofie_widget.dart';
import 'account_pages.dart';
import 'checkout_page.dart';
import 'product_detail_page.dart';
import 'store_models.dart';
import 'store_repository.dart';

class StoreShell extends StatefulWidget {
  const StoreShell({
    super.key,
    required this.api,
    required this.auth,
    required this.store,
    required this.biometrics,
    required this.bootstrap,
    required this.onLoggedOut,
  });

  final ApiClient api;
  final AuthRepository auth;
  final SecureSessionStore store;
  final BiometricService biometrics;
  final AppBootstrap bootstrap;
  final VoidCallback onLoggedOut;

  @override
  State<StoreShell> createState() => _StoreShellState();
}

class _StoreShellState extends State<StoreShell> {
  late final StoreRepository _repository;
  late final CartController _cart;
  final GlobalKey<_AccountPageState> _accountKey = GlobalKey<_AccountPageState>();
  final GlobalKey<_OffersPageState> _offersKey = GlobalKey<_OffersPageState>();
  int _index = 2;
  Timer? _cartSyncDebounce;
  bool _cartInitializing = true;
  bool _applyingServerCart = false;
  StoreSponsoredCampaign? _selectedSponsoredCampaign;

  @override
  void initState() {
    super.initState();
    _index = 2;
    _repository = StoreRepository(widget.api, auth: widget.auth);
    _cart = CartController();
    _cart.addListener(_onCartChanged);
    unawaited(_initializeCart());
  }

  Future<void> _initializeCart() async {
    _cartInitializing = true;
    await _cart.load();
    try {
      final server = await _repository.serverCart();
      if (server.isNotEmpty) {
        _applyingServerCart = true;
        await _cart.replaceFromServer(server);
      } else if (_cart.items.isNotEmpty) {
        await _repository.syncServerCart(_cart.serverPayload());
      }
    } catch (_) {
      // Sem rede, o carrinho local continua utilizável.
    } finally {
      _applyingServerCart = false;
      _cartInitializing = false;
    }
  }

  Future<void> _refreshCartFromServer() async {
    if (_cartInitializing) return;
    try {
      final server = await _repository.serverCart();
      _applyingServerCart = true;
      await _cart.replaceFromServer(server);
    } catch (_) {
    } finally {
      _applyingServerCart = false;
    }
  }

  void _onCartChanged() {
    if (_cartInitializing || _applyingServerCart) return;
    _cartSyncDebounce?.cancel();
    _cartSyncDebounce = Timer(const Duration(milliseconds: 550), () async {
      try {
        await _repository.syncServerCart(_cart.serverPayload());
      } catch (_) {
        // O snapshot local continua salvo e será sincronizado na próxima ação.
      }
    });
  }

  @override
  void dispose() {
    _cartSyncDebounce?.cancel();
    _cart.removeListener(_onCartChanged);
    _cart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      OffersPage(
        key: _offersKey,
        repository: _repository,
        cart: _cart,
        sponsoredCampaign: _selectedSponsoredCampaign,
        onShowAllOffers: () => setState(() => _selectedSponsoredCampaign = null),
      ),
      CategoriesPage(repository: _repository, cart: _cart),
      StoreHomePage(
        repository: _repository,
        cart: _cart,
        bootstrap: widget.bootstrap,
        onOpenCart: () => setState(() => _index = 3),
        onOpenSponsoredCampaign: (campaign) {
          setState(() {
            _selectedSponsoredCampaign = campaign;
            _index = 0;
          });
        },
      ),
      CartPage(
        cart: _cart,
        store: widget.store,
        auth: widget.auth,
        api: widget.api,
        biometrics: widget.biometrics,
        bootstrap: widget.bootstrap,
      ),
      AccountPage(
        key: _accountKey,
        store: widget.store,
        auth: widget.auth,
        api: widget.api,
        biometrics: widget.biometrics,
        bootstrap: widget.bootstrap,
        repository: _repository,
        cart: _cart,
        onLoggedOut: widget.onLoggedOut,
      ),
    ];

    return AnimatedBuilder(
      animation: _cart,
      builder: (context, _) => Scaffold(
        body: Stack(
          children: [
            IndexedStack(index: _index, children: pages),
            if (widget.bootstrap.sofie.enabled)
              Positioned(
                left: widget.bootstrap.sofie.onLeft ? 14 : null,
                right: widget.bootstrap.sofie.onLeft ? null : 14,
                bottom: 8,
                child: SofieFloatingButton(
                  api: widget.api,
                  config: widget.bootstrap.sofie,
                  onCartChanged: _refreshCartFromServer,
                ),
              ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) {
            setState(() {
              // Tocar diretamente na aba Ofertas volta para "Todas".
              if (value == 0) _selectedSponsoredCampaign = null;
              _index = value;
            });
            if (value == 0) _offersKey.currentState?.showAllOffers();
            if (value == 3) unawaited(_refreshCartFromServer());
            if (value == 4) {
              _accountKey.currentState?.refreshSession();
            }
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.local_offer_outlined),
              selectedIcon: Icon(Icons.local_offer),
              label: 'Ofertas',
            ),
            const NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Categorias',
            ),
            const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Loja',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _cart.itemCount > 0,
                label: Text('${_cart.itemCount}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: _cart.itemCount > 0,
                label: Text('${_cart.itemCount}'),
                child: const Icon(Icons.shopping_cart),
              ),
              label: 'Carrinho',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Conta',
            ),
          ],
        ),
      ),
    );
  }
}

enum _OfferFilterMode { all, sponsored, campaign, offerCampaign }

class OffersPage extends StatefulWidget {
  const OffersPage({
    super.key,
    required this.repository,
    required this.cart,
    this.sponsoredCampaign,
    required this.onShowAllOffers,
  });
  final StoreRepository repository;
  final CartController cart;
  final StoreSponsoredCampaign? sponsoredCampaign;
  final VoidCallback onShowAllOffers;

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  List<StoreProduct> _offers = const [];
  List<StoreSponsoredCampaign> _sponsoredCampaigns = const [];
  _OfferFilterMode _filterMode = _OfferFilterMode.all;
  StoreSponsoredCampaign? _filterCampaign;
  StoreCampaign? _filterOfferCampaign;
  bool _loading = true;
  String? _error;

  bool get _showingSponsored => _filterMode != _OfferFilterMode.all;

  @override
  void initState() {
    super.initState();
    if (widget.sponsoredCampaign != null) {
      _filterMode = _OfferFilterMode.campaign;
      _filterCampaign = widget.sponsoredCampaign;
    }
    _load();
  }

  @override
  void didUpdateWidget(covariant OffersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sponsoredCampaign?.id != widget.sponsoredCampaign?.id) {
      setState(() {
        if (widget.sponsoredCampaign == null) {
          _filterMode = _OfferFilterMode.all;
          _filterCampaign = null;
        } else {
          _filterMode = _OfferFilterMode.campaign;
          _filterCampaign = widget.sponsoredCampaign;
        }
      });
    }
  }

  void showAllOffers() {
    if (!mounted) return;
    setState(() {
      _filterMode = _OfferFilterMode.all;
      _filterCampaign = null;
      _filterOfferCampaign = null;
    });
  }

  void _selectFilter(_OfferFilterMode mode, [StoreSponsoredCampaign? campaign]) {
    setState(() {
      _filterMode = mode;
      _filterCampaign = mode == _OfferFilterMode.campaign ? campaign : null;
      if (mode != _OfferFilterMode.offerCampaign) {
        _filterOfferCampaign = null;
      }
    });
    if (mode == _OfferFilterMode.all) widget.onShowAllOffers();
  }

  void _selectOfferCampaign(StoreCampaign campaign) {
    setState(() {
      _filterMode = _OfferFilterMode.offerCampaign;
      _filterCampaign = null;
      _filterOfferCampaign = campaign;
    });
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final home = await widget.repository.home();

      // A aba Ofertas nunca pode ser substituida pela vitrine patrocinada.
      // O endpoint possui sua lista de ofertas, mas tambem consolidamos os
      // produtos promocionais presentes na Home para evitar perder ofertas
      // normais caso uma campanha patrocinada esteja ativa.
      final merged = <String, StoreProduct>{};

      void addOffer(StoreProduct product, {bool trustedOffer = false}) {
        if (product.id.trim().isEmpty) return;
        if (!trustedOffer && !product.hasOffer) return;
        merged.putIfAbsent(product.id, () => product);
      }

      for (final product in home.offers) {
        addOffer(product, trustedOffer: true);
      }
      for (final product in home.products) {
        addOffer(product);
      }
      for (final product in home.sponsored) {
        addOffer(product);
      }
      for (final sponsoredCampaign in home.sponsoredCampaigns) {
        for (final product in sponsoredCampaign.products) {
          addOffer(product);
        }
      }

      _offers = merged.values.toList(growable: false);
      _sponsoredCampaigns = home.sponsoredCampaigns;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaign = _filterMode == _OfferFilterMode.campaign
        ? _filterCampaign
        : null;

    final sponsoredMerged = <String, StoreProduct>{};
    for (final sponsoredCampaign in _sponsoredCampaigns) {
      for (final product in sponsoredCampaign.products) {
        if (product.id.trim().isNotEmpty) {
          sponsoredMerged.putIfAbsent(product.id, () => product);
        }
      }
    }

    final normalCampaignsById = <int, StoreCampaign>{};
    for (final product in _offers) {
      final c = product.campaign;
      // Na aba Ofertas, campanhas promocionais comuns continuam agrupadas em
      // "Todas". Somente datas especiais (1/1, 2/2, 3/3 ... 12/12) ganham
      // um filtro nominal proprio. Patrocinadas mantem seus filtros separados.
      if (c != null && c.id > 0 && _isSpecialDateOfferName(c.name)) {
        normalCampaignsById.putIfAbsent(c.id, () => c);
      }
    }
    final normalCampaigns = normalCampaignsById.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final visibleOffers = switch (_filterMode) {
      _OfferFilterMode.all => _offers,
      _OfferFilterMode.sponsored => sponsoredMerged.values.toList(growable: false),
      _OfferFilterMode.campaign => campaign?.products ?? const <StoreProduct>[],
      _OfferFilterMode.offerCampaign => _offers
          .where((p) => p.campaign?.id == _filterOfferCampaign?.id)
          .toList(growable: false),
    };

    final backgroundCandidates = campaign == null
        ? const <String>[]
        : _sponsoredBackgroundCandidates(campaign);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ofertas'),
      ),
      body: Stack(
        children: [
          if (backgroundCandidates.isNotEmpty)
            Positioned.fill(
              child: _SponsoredAssetImage(
                repository: widget.repository,
                rawUrls: backgroundCandidates,
                fit: BoxFit.cover,
              ),
            ),
          if (backgroundCandidates.isNotEmpty)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor.withOpacity(.78),
              ),
            ),
          Positioned.fill(
            child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
            _OffersCampaignFilter(
              mode: _filterMode,
              campaign: campaign,
              campaigns: _sponsoredCampaigns,
              offerCampaigns: normalCampaigns,
              selectedOfferCampaign: _filterOfferCampaign,
              repository: widget.repository,
              onSelect: _selectFilter,
              onSelectOfferCampaign: _selectOfferCampaign,
            ),
            if (_filterMode == _OfferFilterMode.offerCampaign && _filterOfferCampaign != null) ...[
              const SizedBox(height: 12),
              _OfferCampaignStatus(campaign: _filterOfferCampaign!),
            ],
            if (_filterMode == _OfferFilterMode.sponsored) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.campaign_outlined, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Ofertas patrocinadas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (campaign != null) ...[
              const SizedBox(height: 12),
              _SponsoredOffersHeader(campaign: campaign, repository: widget.repository),
              const SizedBox(height: 14),
            ],
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _ApiMissingCard(message: _error!, onRetry: _load),
            ],
            if (_filterMode == _OfferFilterMode.campaign && campaign != null && visibleOffers.isNotEmpty)
              _SponsoredProductGrid(
                products: visibleOffers,
                campaign: campaign,
                repository: widget.repository,
                cart: widget.cart,
              ),
            if (_filterMode != _OfferFilterMode.campaign && visibleOffers.isNotEmpty)
              _ProductGrid(
                products: visibleOffers,
                repository: widget.repository,
                cart: widget.cart,
              ),
            if (!_loading && _error == null && visibleOffers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 70),
                child: Center(
                  child: Text(
                    switch (_filterMode) {
                      _OfferFilterMode.all => 'Nenhuma oferta ativa neste momento.',
                      _OfferFilterMode.sponsored => 'Nenhuma oferta patrocinada ativa neste momento.',
                      _OfferFilterMode.campaign => 'Nenhum produto encontrado para esta campanha patrocinada.',
                      _OfferFilterMode.offerCampaign => 'Nenhum produto encontrado para esta oferta.',
                    },
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
          ),
        ],
      ),
    );
  }
}


bool _isSpecialDateOfferName(String name) {
  final match = RegExp(r'^(\d{1,2})\s*[/.-]\s*(\d{1,2})(?:\D|$)').firstMatch(name.trim());
  if (match == null) return false;
  final left = int.tryParse(match.group(1) ?? '');
  final right = int.tryParse(match.group(2) ?? '');
  return left != null && right != null && left == right && left >= 1 && left <= 12;
}

class _OfferCampaignStatus extends StatelessWidget {
  const _OfferCampaignStatus({required this.campaign});
  final StoreCampaign campaign;

  String _countdown(int seconds) {
    if (seconds <= 0) return 'começando agora';
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (days > 0) return '${days}d ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}min';
    return '${minutes.clamp(1, 59)}min';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final upcoming = campaign.isUpcoming;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: upcoming ? scheme.primaryContainer.withOpacity(.55) : scheme.secondaryContainer.withOpacity(.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: upcoming ? scheme.primary.withOpacity(.30) : scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(upcoming ? Icons.timer_outlined : Icons.local_offer_outlined, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(campaign.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  upcoming
                      ? 'Começa em ${_countdown(campaign.secondsToStart)}${campaign.hidePrices ? ' · preços liberados na abertura' : ''}'
                      : 'Oferta ativa agora',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OffersCampaignFilter extends StatelessWidget {
  const _OffersCampaignFilter({
    required this.mode,
    required this.campaign,
    required this.campaigns,
    required this.offerCampaigns,
    required this.selectedOfferCampaign,
    required this.repository,
    required this.onSelect,
    required this.onSelectOfferCampaign,
  });

  final _OfferFilterMode mode;
  final StoreSponsoredCampaign? campaign;
  final List<StoreSponsoredCampaign> campaigns;
  final List<StoreCampaign> offerCampaigns;
  final StoreCampaign? selectedOfferCampaign;
  final StoreRepository repository;
  final void Function(_OfferFilterMode mode, [StoreSponsoredCampaign? campaign]) onSelect;
  final ValueChanged<StoreCampaign> onSelectOfferCampaign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.filter_alt_outlined, size: 19, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Filtrar ofertas',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                avatar: const Icon(Icons.local_offer, size: 17),
                label: const Text('Todas'),
                selected: mode == _OfferFilterMode.all,
                onSelected: (_) => onSelect(_OfferFilterMode.all),
              ),
              if (campaigns.isNotEmpty) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.campaign_outlined, size: 17),
                  label: const Text('Patrocinadas'),
                  selected: mode == _OfferFilterMode.sponsored,
                  onSelected: (_) => onSelect(_OfferFilterMode.sponsored),
                ),
              ],
              for (final item in campaigns) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: _SponsorLogo(
                    campaign: item,
                    repository: repository,
                    size: 22,
                  ),
                  label: Text((item.sponsorName ?? item.name).trim()),
                  selected: mode == _OfferFilterMode.campaign && campaign?.id == item.id,
                  onSelected: (_) => onSelect(_OfferFilterMode.campaign, item),
                ),
              ],
              for (final offerCampaign in offerCampaigns) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.event_available_outlined, size: 17),
                  label: Text(offerCampaign.name),
                  selected: mode == _OfferFilterMode.offerCampaign &&
                      selectedOfferCampaign?.id == offerCampaign.id,
                  onSelected: (_) => onSelectOfferCampaign(offerCampaign),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class StoreHomePage extends StatefulWidget {
  const StoreHomePage({
    super.key,
    required this.repository,
    required this.cart,
    required this.bootstrap,
    required this.onOpenCart,
    required this.onOpenSponsoredCampaign,
  });
  final StoreRepository repository;
  final CartController cart;
  final AppBootstrap bootstrap;
  final VoidCallback onOpenCart;
  final ValueChanged<StoreSponsoredCampaign> onOpenSponsoredCampaign;

  @override
  State<StoreHomePage> createState() => _StoreHomePageState();
}

class _StoreHomePageState extends State<StoreHomePage> {
  StoreHomeData? _data;
  bool _loading = true;
  String? _error;
  StoreProductSort _sort = StoreProductSort.standard;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _data = await widget.repository.home(sort: _sort);
    } on ApiException catch (e) {
      _error = e.statusCode == 404
          ? 'A API de vitrine ainda não está instalada no módulo Mobile do servidor.'
          : e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            BrandLogo(
              logoUrl: GeneratedAppConfig.logoUrl.trim().isNotEmpty
                  ? GeneratedAppConfig.logoUrl.trim()
                  : (GeneratedAppConfig.iconAndroidUrl.trim().isNotEmpty
                      ? GeneratedAppConfig.iconAndroidUrl.trim()
                      : null),
              size: 30,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                GeneratedAppConfig.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<ThemeMode>(
            tooltip: 'Tema',
            icon: const Icon(Icons.brightness_6_outlined),
            onSelected: AppThemeModeController.instance.setMode,
            itemBuilder: (_) => const [
              PopupMenuItem(value: ThemeMode.system, child: Text('Tema do aparelho')),
              PopupMenuItem(value: ThemeMode.light, child: Text('Modo claro')),
              PopupMenuItem(value: ThemeMode.dark, child: Text('Modo escuro')),
            ],
          ),
          IconButton(
            onPressed: widget.onOpenCart,
            icon: AnimatedBuilder(
              animation: widget.cart,
              builder: (_, __) => Badge(
                isLabelVisible: widget.cart.itemCount > 0,
                label: Text('${widget.cart.itemCount}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SearchPage(repository: widget.repository, cart: widget.cart)),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search),
                    SizedBox(width: 10),
                    Expanded(child: Text('Buscar produtos na loja')),
                  ],
                ),
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 18),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 18),
              _ApiMissingCard(message: _error!, onRetry: _load),
            ],
            if (data != null) ...[
              if (data.banners.isNotEmpty) ...[
                const SizedBox(height: 18),
                _BannerCarousel(banners: data.banners),
              ],
              if (data.sponsoredCampaigns.isNotEmpty) ...[
                const SizedBox(height: 10),
                _SponsoredCampaignsBlock(
                  campaigns: data.sponsoredCampaigns,
                  repository: widget.repository,
                  cart: widget.cart,
                  onOpenCampaign: widget.onOpenSponsoredCampaign,
                ),
              ] else if (data.sponsored.isNotEmpty) ...[
                const SizedBox(height: 10),
                _SponsoredStrip(products: data.sponsored, repository: widget.repository, cart: widget.cart),
              ],
              if (data.products.isNotEmpty) ...[
                const SizedBox(height: 18),
                Row(children:[const Expanded(child:_SectionTitle(title: 'Para você')), _SortMenu(value:_sort, onChanged:(v){setState(()=>_sort=v); _load();})]),
                const SizedBox(height: 10),
                _ProductGrid(
                  products: data.products,
                  repository: widget.repository,
                  cart: widget.cart,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key, required this.repository, required this.cart});
  final StoreRepository repository;
  final CartController cart;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<StoreCategory> _categories = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _categories = await widget.repository.categories();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Categorias')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = _categories[i];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.category_outlined)),
                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProductListPage(
                                title: c.name,
                                repository: widget.repository,
                                cart: widget.cart,
                                categoryId: c.id,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      );
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.repository, required this.cart});
  final StoreRepository repository;
  final CartController cart;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  List<StoreProduct> _products = const [];
  bool _loading = false;
  String? _error;
  StoreProductSort _sort = StoreProductSort.standard;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _products = await widget.repository.products(query: q, sort: _sort);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Buscar')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Produto, código ou descrição',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward)),
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 18),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 18),
              Text(_error!),
            ],
            if (_products.isNotEmpty) ...[
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerRight, child: _SortMenu(value:_sort,onChanged:(v){setState(()=>_sort=v);_search();})),
              const SizedBox(height: 10),
              _ProductGrid(products: _products, repository: widget.repository, cart: widget.cart),
            ],
          ],
        ),
      );
}

class ProductListPage extends StatefulWidget {
  const ProductListPage({
    super.key,
    required this.title,
    required this.repository,
    required this.cart,
    this.categoryId,
  });
  final String title;
  final StoreRepository repository;
  final CartController cart;
  final String? categoryId;

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  List<StoreProduct> _products = const [];
  bool _loading = true;
  String? _error;
  StoreProductSort _sort = StoreProductSort.standard;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _products = await widget.repository.products(categoryId: widget.categoryId, sort: _sort);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment:CrossAxisAlignment.stretch, children:[Align(alignment:Alignment.centerRight,child:_SortMenu(value:_sort,onChanged:(v){setState(()=>_sort=v);_load();})),const SizedBox(height:10),_ProductGrid(
                      products: _products,
                      repository: widget.repository,
                      cart: widget.cart,
                    )]),
                  ),
      );
}

class CartPage extends StatelessWidget {
  const CartPage({
    super.key,
    required this.cart,
    required this.store,
    required this.auth,
    required this.api,
    required this.biometrics,
    required this.bootstrap,
  });
  final CartController cart;
  final SecureSessionStore store;
  final AuthRepository auth;
  final ApiClient api;
  final BiometricService biometrics;
  final AppBootstrap bootstrap;

  Future<bool> _ensureLogin(BuildContext context) async {
    try {
      // Valida/renova silenciosamente a sessao existente. Cliente que ja esta
      // logado nao deve visitar Login so porque o access token venceu.
      if (await auth.ensureAuthenticated()) return true;
    } on ApiException catch (e) {
      // Rede/servidor indisponivel nao significa logout. Nao abrimos Login
      // nesses casos, pois isso mascarava falhas temporarias como sessao expirada.
      if (!e.isUnauthorized) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
        return false;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nao foi possivel validar sua sessao: $e')),
        );
      }
      return false;
    }

    if (!context.mounted) return false;
    var loginSucceeded = false;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (loginContext) => LoginPage(
          api: api,
          auth: auth,
          store: store,
          biometrics: biometrics,
          bootstrap: bootstrap,
          onLoggedIn: () {
            loginSucceeded = true;
            Navigator.of(loginContext).pop();
          },
        ),
      ),
    );

    // O endpoint de login acabou de emitir e persistir os tokens. Nao faz
    // uma segunda chamada /me.php antes do checkout; isso evitava o falso
    // retorno para a tela de login em servidores que filtravam Authorization.
    if (loginSucceeded) return true;

    try {
      return await auth.ensureAuthenticated();
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Carrinho'),
          actions: [
            AnimatedBuilder(
              animation: cart,
              builder: (_, __) => cart.items.isEmpty
                  ? const SizedBox.shrink()
                  : TextButton(
                      onPressed: () => cart.toggleAll(!cart.allSelected),
                      child: Text(cart.allSelected ? 'Desmarcar todos' : 'Selecionar todos'),
                    ),
            ),
          ],
        ),
        body: AnimatedBuilder(
          animation: cart,
          builder: (_, __) {
            if (!cart.isLoaded) {
              return const Center(child: CircularProgressIndicator());
            }
            if (cart.items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 72,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    const Text('Seu carrinho está vazio.'),
                  ],
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 150),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: cart.allSelected,
                        onChanged: (value) => cart.toggleAll(value ?? false),
                      ),
                      Expanded(
                        child: Text(
                          '${cart.selectedItemCount} de ${cart.itemCount} item(ns) selecionado(s)',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ...cart.items.map((line) => AnimatedOpacity(
                      opacity: line.selected ? 1 : .55,
                      duration: const Duration(milliseconds: 160),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(6, 10, 8, 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: line.selected,
                                onChanged: (value) => cart.toggleSelected(line.lineId, value ?? false),
                              ),
                              SizedBox(
                                width: 70,
                                height: 70,
                                child: line.product.imageUrl == null
                                    ? const Icon(Icons.shopping_bag_outlined)
                                    : Image.network(
                                        api.resolvePublicUrl(line.product.imageUrl) ?? line.product.imageUrl!,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined),
                                      ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(line.product.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 4),
                                    Text('${_money(line.pricing.effectiveUnitPrice)} ${_unitSuffix(line.product.unit)}'),
                                    if (line.observationSummary.trim().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        line.observationSummary,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        IconButton.filledTonal(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => cart.increment(line.lineId, -1),
                                          icon: const Icon(Icons.remove, size: 18),
                                        ),
                                        SizedBox(
                                          width: 72,
                                          child: Text(
                                            formatQuantity(line.quantityVisual, line.quantityMultiplier != null ? 0 : (line.product.quantityRules?.isB2b == true ? 3 : 0)),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                        IconButton.filledTonal(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => cart.increment(line.lineId, 1),
                                          icon: const Icon(Icons.add, size: 18),
                                        ),
                                        const Spacer(),
                                        Text(_money(line.subtotal), style: const TextStyle(fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                    if (line.quantityMultiplier != null) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        '${formatQuantity(line.quantityReal, 3)} ${line.product.unit ?? ''} no pedido',
                                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () => cart.remove(line.lineId),
                                        icon: const Icon(Icons.delete_outline, size: 17),
                                        label: const Text('Remover'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Subtotal selecionado (${cart.selectedItemCount})'),
                            Text(_money(cart.selectedTotal), style: const TextStyle(fontWeight: FontWeight.w900)),
                          ],
                        ),
                        if (cart.selectedItemCount != cart.itemCount) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${cart.itemCount - cart.selectedItemCount} item(ns) ficaram guardados no carrinho e não entrarão nesta compra.',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Preço, campanhas, frete e pedido mínimo serão recalculados pelo servidor somente com os itens selecionados.',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: AnimatedBuilder(
          animation: cart,
          builder: (_, __) => cart.items.isEmpty
              ? const SizedBox.shrink()
              : SafeArea(
                  minimum: const EdgeInsets.all(14),
                  child: FilledButton(
                    onPressed: cart.selectedItems.isEmpty
                        ? null
                        : () async {
                            final logged = await _ensureLogin(context);
                            if (!logged || !context.mounted) return;
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CheckoutPage(
                                  repository: StoreRepository(api, auth: auth),
                                  cart: cart,
                                  reauthenticate: () => _ensureLogin(context),
                                ),
                              ),
                            );
                          },
                    child: Text(
                      cart.selectedItems.isEmpty
                          ? 'Selecione ao menos um item'
                          : 'Continuar com ${cart.selectedItemCount} item(ns) · ${_money(cart.selectedTotal)}',
                    ),
                  ),
                ),
        ),
      );
}

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    required this.store,
    required this.auth,
    required this.api,
    required this.biometrics,
    required this.bootstrap,
    required this.repository,
    required this.cart,
    required this.onLoggedOut,
  });
  final SecureSessionStore store;
  final AuthRepository auth;
  final ApiClient api;
  final BiometricService biometrics;
  final AppBootstrap bootstrap;
  final StoreRepository repository;
  final CartController cart;
  final VoidCallback onLoggedOut;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _logged = false;
  bool _checking = true;
  String? _name;
  String? _photoUrl;
  bool _photoChanging = false;
  final ImagePicker _imagePicker = ImagePicker();
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _biometricChanging = false;
  bool _notificationsEnabled = false;
  bool _notificationsChanging = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() => refreshSession();

  Future<void> refreshSession() async {
    if (mounted) setState(() => _checking = true);
    final localName = await widget.store.customerName;
    final biometricEnabled = await widget.store.biometricEnabled;
    final biometricAvailable = widget.bootstrap.security.biometrics ? await widget.biometrics.isAvailable() : false;
    final hasSession = await widget.auth.ensureAuthenticated();
    if (!hasSession) {
      if (mounted) {
        setState(() {
          _logged = false;
          _name = null;
          _photoUrl = null;
          _checking = false;
          _biometricEnabled = biometricEnabled;
          _biometricAvailable = biometricAvailable;
        });
      }
      return;
    }

    // Assim que existe token utilizavel, a Conta nao volta visualmente para
    // "Entrar" enquanto /me.php esta confirmando os dados no servidor.
    if (mounted) {
      setState(() {
        _logged = true;
        _name = localName;
        _biometricEnabled = biometricEnabled;
        _biometricAvailable = biometricAvailable;
      });
    }

    try {
      final json = await widget.auth.me();
      final customer = mapValue(json['customer']);
      final name = nullableString(customer['name']) ?? localName;
      var photoUrl = nullableString(customer['photo_url']);
      try {
        final profile = await widget.repository.accountProfile();
        photoUrl = nullableString(profile['photo_url']) ?? photoUrl;
      } catch (_) {}
      var notificationsEnabled = _notificationsEnabled;
      if (widget.bootstrap.features.push) {
        try {
          notificationsEnabled = await widget.repository.notificationPreference();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _logged = true;
          _name = name;
          _photoUrl = photoUrl;
          _notificationsEnabled = notificationsEnabled;
          _checking = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        // So derruba a conta quando o servidor confirmou 401. Falha de rede
        // nao transforma uma sessao local existente em "deslogado".
        if (e.isUnauthorized) {
          _logged = false;
          _name = null;
          _photoUrl = null;
        }
        _checking = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _login() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (loginContext) => LoginPage(
          api: widget.api,
          auth: widget.auth,
          store: widget.store,
          biometrics: widget.biometrics,
          bootstrap: widget.bootstrap,
          onLoggedIn: () => Navigator.of(loginContext).pop(),
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _changeProfilePhoto() async {
    if (_photoChanging) return;
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      imageQuality: 88,
    );
    if (picked == null) return;
    setState(() => _photoChanging = true);
    try {
      final bytes = await picked.readAsBytes();
      final lower = picked.path.toLowerCase();
      final mime = lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';
      final url = await widget.repository.uploadProfilePhoto(
        imageBase64: base64Encode(bytes),
        mimeType: mime,
      );
      if (mounted) {
        setState(() => _photoUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil atualizada.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _photoChanging = false);
    }
  }

  Future<void> _openProfilePhoto() async {
    final raw = _photoUrl?.trim() ?? '';
    if (raw.isEmpty) return;
    final resolved = widget.api.resolvePublicUrl(raw) ?? raw;
    final uri = Uri.tryParse(resolved);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _removeProfilePhoto() async {
    if (_photoChanging || (_photoUrl?.isEmpty ?? true)) return;
    setState(() => _photoChanging = true);
    try {
      await widget.repository.deleteProfilePhoto();
      if (mounted) setState(() => _photoUrl = null);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _photoChanging = false);
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (_biometricChanging) return;
    if (!widget.bootstrap.security.biometrics) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometria desativada na configuração do Mobile.')));
      return;
    }
    if (enabled && !_biometricAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nenhuma biometria foi cadastrada neste aparelho. Cadastre Face ID/Touch ID ou biometria em ${PlatformInfo.biometricSettingsLabel} e tente novamente.')));
      return;
    }
    final refresh = await widget.store.refreshToken;
    if (enabled && (refresh == null || refresh.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ative “Manter conectado” no próximo login para usar a biometria.')));
      return;
    }
    setState(() => _biometricChanging = true);
    try {
      if (enabled) {
        final ok = await widget.biometrics.authenticate(reason: 'Confirme sua biometria para habilitar o acesso ao aplicativo');
        if (!ok) return;
      }
      await widget.auth.setBiometric(enabled);
      if (mounted) {
        setState(() => _biometricEnabled = enabled);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(enabled ? 'Acesso por biometria ativado.' : 'Acesso por biometria desativado.')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _biometricChanging = false);
    }
  }


  Future<void> _toggleNotifications(bool enabled) async {
    if (_notificationsChanging) return;
    setState(() => _notificationsChanging = true);
    try {
      final saved = await widget.repository.setNotificationPreference(enabled);
      if (mounted) setState(() => _notificationsEnabled = saved);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _notificationsChanging = false);
    }
  }

  Future<void> _logout() async {
    await widget.auth.logout();
    if (mounted) widget.onLoggedOut();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Minha conta')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: _logged && (_photoUrl?.trim().isNotEmpty ?? false)
                          ? NetworkImage(widget.api.resolvePublicUrl(_photoUrl) ?? _photoUrl!)
                          : null,
                      child: !(_logged && (_photoUrl?.trim().isNotEmpty ?? false))
                          ? Icon(_logged ? Icons.person : Icons.person_outline)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _logged ? (_name ?? 'Cliente') : 'Entre na sua conta',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(_logged ? 'Acompanhe seus pedidos e endereços.' : 'Login por e-mail ou CPF.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_checking) const LinearProgressIndicator(minHeight: 2),
            if (_checking) const SizedBox(height: 10),
            if (_logged) ...[
              Card(child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined), title: const Text('Meus pedidos'), trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrdersPage(repository: widget.repository))),
              )),
              Card(child: ListTile(
                leading: const Icon(Icons.favorite_border), title: const Text('Favoritos'), trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FavoritesPage(repository: widget.repository, cart: widget.cart))),
              )),
              Card(child: ListTile(
                leading: const Icon(Icons.location_on_outlined), title: const Text('Meus endereços'), trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddressesPage(repository: widget.repository))),
              )),
              Card(
                child: ListTile(
                  leading: _photoChanging
                      ? const SizedBox(width:24,height:24,child:CircularProgressIndicator(strokeWidth:2))
                      : const Icon(Icons.account_circle_outlined),
                  title: const Text('Foto de perfil'),
                  subtitle: Text((_photoUrl?.trim().isNotEmpty ?? false)
                      ? 'Foto sincronizada com sua conta.'
                      : 'Adicione uma foto à sua conta.'),
                  trailing: PopupMenuButton<String>(
                    enabled: !_photoChanging,
                    onSelected: (value) {
                      if (value == 'upload') unawaited(_changeProfilePhoto());
                      if (value == 'open') unawaited(_openProfilePhoto());
                      if (value == 'delete') unawaited(_removeProfilePhoto());
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value:'upload', child:Text('Enviar / trocar foto')),
                      if (_photoUrl?.trim().isNotEmpty ?? false)
                        const PopupMenuItem(value:'open', child:Text('Abrir / baixar foto')),
                      if (_photoUrl?.trim().isNotEmpty ?? false)
                        const PopupMenuItem(value:'delete', child:Text('Remover foto')),
                    ],
                  ),
                  onTap: _photoChanging ? null : _changeProfilePhoto,
                ),
              ),
              if (widget.bootstrap.security.biometrics)
                Card(
                  child: SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: const Text('Entrar com biometria'),
                    subtitle: Text(_biometricAvailable
                        ? (_biometricEnabled ? 'Ativado neste aparelho.' : 'Use sua digital/biometria para entrar sem digitar a senha.')
                        : 'Cadastre Face ID/Touch ID ou biometria em ${PlatformInfo.biometricSettingsLabel} para habilitar.'),
                    value: _biometricEnabled,
                    onChanged: _biometricChanging ? null : _toggleBiometric,
                  ),
                ),
              if (widget.bootstrap.features.push)
                Card(
                  child: SwitchListTile(
                    secondary: const Icon(Icons.notifications_outlined),
                    title: const Text('Notificações'),
                    value: _notificationsEnabled,
                    onChanged: _notificationsChanging ? null : _toggleNotifications,
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: _logout, icon: const Icon(Icons.logout), label: const Text('Sair')),
            ] else
              FilledButton.icon(onPressed: _checking ? null : _login, icon: const Icon(Icons.login), label: const Text('Entrar')),
            const SizedBox(height: 28),
            const _BuildDebugInfo(),
            const SizedBox(height: 8),
          ],
        ),
      );
}

class _BuildDebugInfo extends StatelessWidget {
  const _BuildDebugInfo();

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(.68),
          fontSize: 10.5,
          height: 1.35,
        );
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info == null
            ? 'carregando...'
            : '${info.version}+${info.buildNumber}';
        final builtAt = GeneratedAppConfig.buildGeneratedAt.trim().isEmpty
            ? 'data do build indisponível'
            : GeneratedAppConfig.buildGeneratedAt.trim();
        return Semantics(
          label: 'Informações de versão do aplicativo',
          child: Text(
            'Soft Ecommerce Mobile v$version\nBuild: $builtAt',
            textAlign: TextAlign.center,
            style: textStyle,
          ),
        );
      },
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products, required this.repository, required this.cart});
  final List<StoreProduct> products;
  final StoreRepository repository;
  final CartController cart;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final cols = constraints.maxWidth >= 760 ? 4 : 2;
          final width = (constraints.maxWidth - ((cols - 1) * 10)) / cols;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: products
                .map((p) => SizedBox(
                      width: width,
                      child: _ProductCard(product: p, repository: repository, cart: cart),
                    ))
                .toList(),
          );
        },
      );
}

class _ProductCard extends StatefulWidget {
  const _ProductCard({required this.product, required this.repository, required this.cart});
  final StoreProduct product;
  final StoreRepository repository;
  final CartController cart;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  late bool _favorite;
  bool _changingFavorite = false;

  @override
  void initState() {
    super.initState();
    _favorite = widget.product.favorite;
  }

  Future<void> _toggleFavorite() async {
    if (_changingFavorite) return;
    setState(() => _changingFavorite = true);
    try {
      final value = await widget.repository.toggleFavorite(widget.product.id);
      if (mounted) setState(() => _favorite = value);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _changingFavorite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final scheme = Theme.of(context).colorScheme;
    final borderColor = product.hasOffer ? scheme.error : (product.sponsored ? scheme.tertiary : scheme.outlineVariant);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color:borderColor, width:(product.hasOffer||product.sponsored)?2:1)),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailPage(product: product, repository: widget.repository, cart: widget.cart))),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(aspectRatio:1.15, child:Stack(children:[
              Positioned.fill(child:Container(decoration:BoxDecoration(color:scheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(14)),child:product.imageUrl==null?const Icon(Icons.image_outlined,size:52):ClipRRect(borderRadius:BorderRadius.circular(14),child:Image.network(widget.repository.api.resolvePublicUrl(product.imageUrl)??product.imageUrl!,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.image_not_supported_outlined,size:48))))),
              if(product.hasOffer) Positioned(left:6,top:6,child:_SkinBadge(text:'OFERTA',color:scheme.error)),
              if(product.sponsored) Positioned(left:6,bottom:6,child:_SkinBadge(text:'PATROCINADO',color:scheme.tertiary)),
              Positioned(top:6,right:6,child:Material(color:scheme.surface.withOpacity(.94),shape:const CircleBorder(),child:IconButton(tooltip:_favorite?'Remover dos favoritos':'Favoritar',visualDensity:VisualDensity.compact,onPressed:_changingFavorite?null:_toggleFavorite,icon:_changingFavorite?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):Icon(_favorite?Icons.favorite:Icons.favorite_border,color:_favorite?Colors.redAccent:null))))
            ])),
            const SizedBox(height:8),
            SizedBox(height:42, child:Center(child:Text(product.name,maxLines:2,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w800,height:1.15)))),
            const SizedBox(height:6),
            SizedBox(height:42, child:Align(alignment:Alignment.centerLeft, child:_ProductPrice(product:product))),
            const SizedBox(height:4),
            Align(alignment:Alignment.centerRight,child:IconButton.filledTonal(visualDensity:VisualDensity.compact,onPressed:product.available?()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>ProductDetailPage(product:product,repository:widget.repository,cart:widget.cart))):null,icon:const Icon(Icons.add_shopping_cart,size:19))),
          ]),
        ),
      ),
    );
  }

}


class _SkinBadge extends StatelessWidget {
  const _SkinBadge({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final foreground =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

class _ProductPrice extends StatelessWidget {
  const _ProductPrice({required this.product});
  final StoreProduct product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (product.priceHidden) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_clock_outlined, size: 16, color: scheme.primary),
          const SizedBox(width: 5),
          Text('Preço surpresa', style: TextStyle(fontWeight: FontWeight.w900, color: scheme.primary, fontSize: 13)),
        ],
      );
    }
    final emphasizedColor = product.hasOffer ? scheme.error : scheme.onSurface;
    final main = TextStyle(
      fontWeight: FontWeight.w900,
      color: emphasizedColor,
      fontSize: 18,
      height: 1.0,
    );
    final fullPrice = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant,
    );
    final fractionCaption = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      color: scheme.onSurfaceVariant,
      height: 1.05,
    );
    final label = (product.fractionLabel ?? '').trim();

    // Replica a hierarquia visual usada na vitrine WEB:
    // Preço cheio: R$ 49,90   (pequeno)
    // R$ 24,95                (destaque)
    // a cada 500 g            (legenda)
    if (product.priceDisplayMode == 'CHEIO_E_MENOR' &&
        product.fractionPrice != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Preço cheio: ${_money(product.price)}',
            style: fullPrice,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(_money(product.fractionPrice!), style: main, maxLines: 1),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(label, style: fractionCaption, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ],
      );
    }
    if (product.priceDisplayMode == 'PRECO_MENOR' &&
        product.fractionPrice != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_money(product.fractionPrice!), style: main, maxLines: 1),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(label, style: fractionCaption, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (product.hasOffer)
          Text(
            _money(product.oldPrice!),
            style: fullPrice.copyWith(decoration: TextDecoration.lineThrough),
          ),
        Text(_money(product.price), style: main),
      ],
    );
  }
}

class _SortMenu extends StatelessWidget { const _SortMenu({required this.value,required this.onChanged}); final StoreProductSort value; final ValueChanged<StoreProductSort> onChanged; @override Widget build(BuildContext context)=>PopupMenuButton<StoreProductSort>(initialValue:value,tooltip:'Ordenar produtos',onSelected:onChanged,itemBuilder:(_)=>StoreProductSort.values.map((v)=>PopupMenuItem(value:v,child:Row(children:[if(v==value) const Icon(Icons.check,size:18),if(v==value) const SizedBox(width:6),Flexible(child:Text(v.label))]))).toList(),child:Chip(avatar:const Icon(Icons.sort,size:18),label:Text(value==StoreProductSort.standard?'Ordenar':value.label))); }
ImageProvider<Object>? _sponsoredImageProvider(StoreRepository repository, String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return null;
  if (value.startsWith('data:image/') && value.contains(';base64,')) {
    try {
      return MemoryImage(base64Decode(value.split(';base64,').last));
    } catch (_) {
      return null;
    }
  }
  final resolved = repository.api.resolvePublicUrl(value) ?? value;
  return NetworkImage(resolved);
}


List<String> _sponsoredAssetCandidates(StoreSponsoredCampaign campaign, {required bool logo}) {
  final raws = logo
      ? <String?>[
          campaign.sponsorLogoUrl,
          ...campaign.visualAssets,
          campaign.heroImageUrl,
          campaign.bannerUrl,
        ]
      : <String?>[
          campaign.heroImageUrl,
          campaign.bannerUrl,
          ...campaign.visualAssets,
          campaign.sponsorLogoUrl,
        ];
  final out = <String>[];
  for (final raw in raws) {
    final value = (raw ?? '').trim();
    if (value.isNotEmpty && !out.contains(value)) out.add(value);
  }
  return out;
}

List<String> _sponsoredBackgroundCandidates(StoreSponsoredCampaign campaign) {
  final raws = <String?>[
    campaign.backgroundImageUrl,
    ...campaign.backgroundAssets,
  ];
  // So usa outros assets como ultimo fallback. Wallpaper real continua tendo
  // prioridade e nunca e substituido por uma cor/arte inventada.
  if (campaign.backgroundAssets.isEmpty &&
      (campaign.backgroundImageUrl ?? '').trim().isEmpty) {
    raws.addAll(campaign.visualAssets.reversed);
  }
  final out = <String>[];
  for (final raw in raws) {
    final value = (raw ?? '').trim();
    if (value.isNotEmpty && !out.contains(value)) out.add(value);
  }
  return out;
}

class _SponsoredAssetImage extends StatelessWidget {
  const _SponsoredAssetImage({
    required this.repository,
    required this.rawUrls,
    required this.fit,
    this.alignment = Alignment.center,
  });

  final StoreRepository repository;
  final List<String> rawUrls;
  final BoxFit fit;
  final Alignment alignment;

  Widget _imageAt(int index) {
    if (index >= rawUrls.length) return const SizedBox.shrink();
    final provider = _sponsoredImageProvider(repository, rawUrls[index]);
    if (provider == null) return _imageAt(index + 1);
    return Image(
      image: provider,
      fit: fit,
      alignment: alignment,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _imageAt(index + 1),
    );
  }

  @override
  Widget build(BuildContext context) => _imageAt(0);
}

class _SponsoredHeroVisual extends StatelessWidget {
  const _SponsoredHeroVisual({
    required this.campaign,
    required this.repository,
    required this.height,
  });

  final StoreSponsoredCampaign campaign;
  final StoreRepository repository;
  final double height;

  @override
  Widget build(BuildContext context) {
    final urls = _sponsoredAssetCandidates(campaign, logo: false);
    if (urls.isEmpty) return const SizedBox.shrink();
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(.06)),
      ),
      child: _SponsoredAssetImage(
        repository: repository,
        rawUrls: urls,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _SponsoredCampaignStyle {
  const _SponsoredCampaignStyle({
    required this.background,
    required this.border,
    required this.foreground,
    required this.accent,
    required this.accentForeground,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final Color accent;
  final Color accentForeground;

  static double _contrast(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final hi = l1 > l2 ? l1 : l2;
    final lo = l1 > l2 ? l2 : l1;
    return (hi + .05) / (lo + .05);
  }

  static Color _readable(Color background, Color? preferred) {
    if (preferred != null && _contrast(background, preferred) >= 4.2) return preferred;
    final black = Colors.black;
    final white = Colors.white;
    return _contrast(background, black) >= _contrast(background, white) ? black : white;
  }

  factory _SponsoredCampaignStyle.of(BuildContext context, StoreSponsoredCampaign campaign) {
    final scheme = Theme.of(context).colorScheme;
    final background = AppTheme.parseColor(campaign.backgroundColor) ?? scheme.tertiaryContainer;
    final accent = AppTheme.parseColor(campaign.accentColor) ?? scheme.tertiary;
    final border = AppTheme.parseColor(campaign.borderColor) ?? accent;
    final preferredText = AppTheme.parseColor(campaign.textColor);
    final foreground = _readable(background, preferredText);
    final accentForeground = _readable(accent, null);
    return _SponsoredCampaignStyle(
      background: background,
      border: border,
      foreground: foreground,
      accent: accent,
      accentForeground: accentForeground,
    );
  }
}

class _SponsorLogo extends StatelessWidget {
  const _SponsorLogo({required this.campaign, required this.repository, this.size = 46});
  final StoreSponsoredCampaign campaign;
  final StoreRepository repository;
  final double size;

  @override
  Widget build(BuildContext context) {
    final urls = _sponsoredAssetCandidates(campaign, logo: true);
    if (urls.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .20),
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.all(size * .06),
          child: _SponsoredAssetImage(
            repository: repository,
            rawUrls: urls,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _SponsoredOffersHeader extends StatelessWidget {
  const _SponsoredOffersHeader({required this.campaign, required this.repository});
  final StoreSponsoredCampaign campaign;
  final StoreRepository repository;

  @override
  Widget build(BuildContext context) {
    final style = _SponsoredCampaignStyle.of(context, campaign);
    final sponsor = (campaign.sponsorName ?? '').trim();
    final backgroundUrls = _sponsoredBackgroundCandidates(campaign);
    final hasIdentity = _sponsoredAssetCandidates(campaign, logo: true).isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: style.background,
        border: Border.all(color: style.border, width: 1.5),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (backgroundUrls.isNotEmpty)
            Positioned.fill(
              child: _SponsoredAssetImage(
                repository: repository,
                rawUrls: backgroundUrls,
                fit: BoxFit.cover,
              ),
            ),
          if (backgroundUrls.isNotEmpty)
            Positioned.fill(child: ColoredBox(color: style.background.withOpacity(.32))),
          Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SponsoredHeroVisual(campaign: campaign, repository: repository, height: 158),
            if (_sponsoredAssetCandidates(campaign, logo: false).isNotEmpty) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hasIdentity) ...[
                  _SponsorLogo(campaign: campaign, repository: repository, size: 42),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PATROCINADO POR', style: TextStyle(color: style.foreground.withOpacity(.72), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .6)),
                      Text(sponsor.isEmpty ? campaign.name : sponsor, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: style.foreground, fontSize: 16, fontWeight: FontWeight.w900)),
                      if (sponsor.isNotEmpty && campaign.name.trim().isNotEmpty && campaign.name.trim().toLowerCase() != sponsor.toLowerCase())
                        Text(campaign.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: style.foreground.withOpacity(.84), fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: style.accent.withOpacity(.12), borderRadius: BorderRadius.circular(999)),
                  child: Text('CONTEÚDO\nPATROCINADO', textAlign: TextAlign.center, style: TextStyle(color: style.accent, fontSize: 7, fontWeight: FontWeight.w900, height: 1.05)),
                ),
              ],
            ),
            if ((campaign.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(campaign.description!, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: style.foreground.withOpacity(.86), fontSize: 12)),
            ],
          ],
        ),
          ),
        ],
      ),
    );
  }
}

class _SponsoredCampaignsBlock extends StatefulWidget {
  const _SponsoredCampaignsBlock({
    required this.campaigns,
    required this.repository,
    required this.cart,
    required this.onOpenCampaign,
  });

  final List<StoreSponsoredCampaign> campaigns;
  final StoreRepository repository;
  final CartController cart;
  final ValueChanged<StoreSponsoredCampaign> onOpenCampaign;

  @override
  State<_SponsoredCampaignsBlock> createState() => _SponsoredCampaignsBlockState();
}

class _SponsoredCampaignsBlockState extends State<_SponsoredCampaignsBlock> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final safeIndex = _index < 0 ? 0 : (_index >= widget.campaigns.length ? widget.campaigns.length - 1 : _index);
    final campaign = widget.campaigns[safeIndex];
    final style = _SponsoredCampaignStyle.of(context, campaign);
    final sponsor = (campaign.sponsorName ?? '').trim();
    final backgroundUrls = _sponsoredBackgroundCandidates(campaign);
    final hasLogo = _sponsoredAssetCandidates(campaign, logo: true).isNotEmpty;
    final hasHero = _sponsoredAssetCandidates(campaign, logo: false).isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: style.border, width: 1.5),
        borderRadius: BorderRadius.circular(16),
        color: style.background,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (backgroundUrls.isNotEmpty)
            Positioned.fill(
              child: _SponsoredAssetImage(
                repository: widget.repository,
                rawUrls: backgroundUrls,
                fit: BoxFit.cover,
              ),
            ),
          if (backgroundUrls.isNotEmpty)
            Positioned.fill(child: ColoredBox(color: style.background.withOpacity(.30))),
          Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasHero) ...[
              _SponsoredHeroVisual(campaign: campaign, repository: widget.repository, height: 104),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                if (hasLogo) ...[
                  _SponsorLogo(campaign: campaign, repository: widget.repository, size: 38),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PATROCINADO POR', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .5, color: style.foreground.withOpacity(.72))),
                      Text(sponsor.isEmpty ? campaign.name : sponsor, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: style.foreground)),
                      if (sponsor.isNotEmpty && campaign.name.trim().isNotEmpty && campaign.name.trim().toLowerCase() != sponsor.toLowerCase())
                        Text(campaign.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, color: style.foreground.withOpacity(.80))),
                    ],
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: style.accent,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                  ),
                  onPressed: campaign.products.isEmpty ? null : () => widget.onOpenCampaign(campaign),
                  child: const Text('Ver ofertas →'),
                ),
                if (widget.campaigns.length > 1)
                  PopupMenuButton<int>(
                    tooltip: 'Trocar campanha',
                    color: Theme.of(context).colorScheme.surface,
                    onSelected: (value) => setState(() => _index = value),
                    itemBuilder: (_) => List.generate(widget.campaigns.length, (i) => PopupMenuItem(value: i, child: Text(widget.campaigns[i].name))),
                    icon: Icon(Icons.more_horiz, color: style.foreground),
                  ),
              ],
            ),
            if (campaign.products.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: campaign.products.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (ctx, i) {
                    final product = campaign.products[i];
                    return SizedBox(
                      width: 104,
                      child: Card(
                        color: Theme.of(context).colorScheme.surface,
                        clipBehavior: Clip.antiAlias,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: style.border.withOpacity(.45))),
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailPage(product: product, repository: widget.repository, cart: widget.cart))),
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: product.imageUrl != null
                                      ? Image.network(widget.repository.api.resolvePublicUrl(product.imageUrl) ?? product.imageUrl!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined))
                                      : const Icon(Icons.inventory_2_outlined),
                                ),
                                Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, height: 1.05)),
                                const SizedBox(height: 2),
                                _SponsoredCompactPrice(product: product, color: style.accent),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
          ),
        ],
      ),
    );
  }
}

class _SponsoredCompactPrice extends StatelessWidget {
  const _SponsoredCompactPrice({required this.product, required this.color});
  final StoreProduct product;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (product.priceHidden) {
      return Text('Preço surpresa', textAlign: TextAlign.center, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: color));
    }
    final label = (product.fractionLabel ?? '').trim();
    if ((product.priceDisplayMode == 'CHEIO_E_MENOR' || product.priceDisplayMode == 'PRECO_MENOR') &&
        product.fractionPrice != null) {
      return Column(
        children: [
          if (product.priceDisplayMode == 'CHEIO_E_MENOR')
            Text('Preço cheio: ${_money(product.price)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(_money(product.fractionPrice!), textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: color)),
          if (label.isNotEmpty) Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w700)),
        ],
      );
    }
    return Text(_money(product.price), textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: color));
  }
}

class _SponsoredProductGrid extends StatelessWidget {
  const _SponsoredProductGrid({required this.products, required this.campaign, required this.repository, required this.cart});
  final List<StoreProduct> products;
  final StoreSponsoredCampaign campaign;
  final StoreRepository repository;
  final CartController cart;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final cols = constraints.maxWidth >= 760 ? 4 : 2;
          final width = (constraints.maxWidth - ((cols - 1) * 10)) / cols;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: products.map((p) => SizedBox(width: width, child: _SponsoredProductCard(product: p, campaign: campaign, repository: repository, cart: cart))).toList(),
          );
        },
      );
}

class _SponsoredProductCard extends StatelessWidget {
  const _SponsoredProductCard({required this.product, required this.campaign, required this.repository, required this.cart});
  final StoreProduct product;
  final StoreSponsoredCampaign campaign;
  final StoreRepository repository;
  final CartController cart;

  @override
  Widget build(BuildContext context) {
    final style = _SponsoredCampaignStyle.of(context, campaign);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: style.border, width: 2)),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailPage(product: product, repository: repository, cart: cart))),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
              aspectRatio: 1.15,
              child: Stack(children: [
                Positioned.fill(child: Container(decoration: BoxDecoration(color: style.background.withOpacity(.22), borderRadius: BorderRadius.circular(14)), child: product.imageUrl == null ? const Icon(Icons.image_outlined, size: 52) : ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(repository.api.resolvePublicUrl(product.imageUrl) ?? product.imageUrl!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined, size: 48))))),
                Positioned(left: 6, top: 6, child: _SkinBadge(text: 'PATROCINADO', color: style.accent)),
              ]),
            ),
            const SizedBox(height: 8),
            SizedBox(height: 42, child: Center(child: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.15)))),
            const SizedBox(height: 6),
            SizedBox(height: 42, child: Align(alignment: Alignment.centerLeft, child: _ProductPrice(product: product))),
            const SizedBox(height: 4),
            SizedBox(width: double.infinity, child: FilledButton.tonalIcon(onPressed: product.available ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailPage(product: product, repository: repository, cart: cart))) : null, icon: const Icon(Icons.add_shopping_cart, size: 18), label: const Text('Adicionar'))),
          ]),
        ),
      ),
    );
  }
}

class _SponsoredStrip extends StatelessWidget { const _SponsoredStrip({required this.products,required this.repository,required this.cart}); final List<StoreProduct> products; final StoreRepository repository; final CartController cart; @override Widget build(BuildContext context){final p=products.first;return Card(clipBehavior:Clip.antiAlias,color:Theme.of(context).colorScheme.tertiaryContainer,child:InkWell(onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>ProductDetailPage(product:p,repository:repository,cart:cart))),child:SizedBox(height:82,child:Row(children:[const SizedBox(width:12),Icon(Icons.campaign_outlined,color:Theme.of(context).colorScheme.tertiary,size:34),const SizedBox(width:12),Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Patrocinado',style:TextStyle(fontWeight:FontWeight.w900,fontSize:12)),Text(p.name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800)),Text(_money(p.price),style:TextStyle(fontWeight:FontWeight.w900,color:Theme.of(context).colorScheme.primary))])),const Icon(Icons.chevron_right),const SizedBox(width:10)])))) ;} }

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners});
  final List<StoreBanner> banners;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _index = 0;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.banners.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients || widget.banners.isEmpty) return;
      final next = (_index + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 2.25,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.banners.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (_, i) {
                final banner = widget.banners[i];
                if (banner.imageUrl != null && banner.imageUrl!.isNotEmpty) {
                  return Image.network(
                    banner.imageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => _BannerFallback(title: banner.title),
                  );
                }
                return _BannerFallback(title: banner.title);
              },
            ),
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (i) {
              final selected = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: selected ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _BannerFallback extends StatelessWidget {
  const _BannerFallback({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primaryContainer,
            ],
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
        ),
      );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.onTap});
  final StoreCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 154,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: category.imageUrl != null && category.imageUrl!.isNotEmpty
                        ? Image.network(
                            category.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.grid_view_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : Icon(
                            Icons.grid_view_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      category.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      );
}

class _ApiMissingCard extends StatelessWidget {
  const _ApiMissingCard({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(Icons.storefront_outlined, size: 50, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 10),
              const Text('Loja Mobile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
            ],
          ),
        ),
      );
}

String _money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
String _unitSuffix(String? unit) {
  final u = (unit ?? 'UN').toUpperCase();
  return ['UN', 'UND', 'UNID', 'UNIDADE'].contains(u) ? 'cada' : 'por $u';
}
String _qty(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '').replaceAll('.', ',');
