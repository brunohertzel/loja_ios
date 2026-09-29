import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../cart/cart_controller.dart';
import 'store_models.dart';
import 'store_repository.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.product,
    required this.repository,
    required this.cart,
  });
  final StoreProduct product;
  final StoreRepository repository;
  final CartController cart;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late StoreProduct _product;
  bool _loading = false;
  String? _error;
  final Set<int> _selectedIds = <int>{};
  final Map<int, TextEditingController> _numberControllers = <int, TextEditingController>{};
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _observationController = TextEditingController();
  double _quantityVisual = 1;
  late bool _favorite;
  bool _changingFavorite = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _favorite = widget.product.favorite;
    _loadDetails();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _observationController.dispose();
    for (final controller in _numberControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDetails() async {
    if (_product.id.isEmpty) return;
    setState(() => _loading = true);
    try {
      _product = await widget.repository.product(_product.id);
      _favorite = _product.favorite;
      _initializeOptions();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _initializeOptions() {
    _selectedIds.clear();
    for (final c in _numberControllers.values) {
      c.dispose();
    }
    _numberControllers.clear();

    for (final block in _product.optionBlocks) {
      if (block.type == 'number') {
        for (final option in block.options) {
          _numberControllers[option.id] = TextEditingController();
        }
        continue;
      }
      final defaults = block.options.where((o) => o.isDefault).toList();
      if (block.type == 'checkbox') {
        _selectedIds.addAll(defaults.map((e) => e.id));
      } else if (defaults.isNotEmpty) {
        _selectedIds.add(defaults.first.id);
      } else if (block.isRequired && block.options.isNotEmpty) {
        // Igual ao site: radio obrigatório sem padrão usa a primeira opção.
        _selectedIds.add(block.options.first.id);
      }
    }
    final rules = _product.quantityRules;
    _quantityVisual = rules?.defaultVisual ?? 1;
    _syncQuantityText();
  }

  ProductOption? get _quantityOption {
    for (final block in _product.optionBlocks) {
      for (final option in block.options) {
        if (_selectedIds.contains(option.id) &&
            option.affectsQuantity &&
            (option.quantityMultiplier ?? 0) > 0) {
          return option;
        }
      }
    }
    return null;
  }

  double get _quantityReal {
    final multiplier = _quantityOption?.quantityMultiplier;
    if (multiplier != null && multiplier > 0) {
      final visual = _quantityVisual.floor().clamp(1, 999999).toDouble();
      return visual * multiplier;
    }
    final rules = _product.quantityRules;
    if (rules?.isB2b == true) {
      return _quantityVisual < 0.001 ? 0.001 : _quantityVisual;
    }
    return _quantityVisual.floor().clamp(1, 999999).toDouble();
  }

  int get _quantityDecimals {
    if (_quantityOption != null) return 0;
    return _product.quantityRules?.isB2b == true ? 3 : 0;
  }

  void _syncQuantityText() {
    final text = _quantityDecimals == 0
        ? _quantityVisual.floor().clamp(1, 999999).toString()
        : _quantityVisual.toStringAsFixed(3);
    _quantityController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _setQuantity(double value) {
    final hasMultiplier = _quantityOption != null;
    final b2b = _product.quantityRules?.isB2b == true;
    if (hasMultiplier) {
      value = value.floorToDouble();
      if (value < 1) value = 1;
    } else if (b2b) {
      if (value < 0.001) value = 0.001;
    } else {
      value = value.floorToDouble();
      if (value < 1) value = 1;
    }
    setState(() {
      _quantityVisual = value;
      _syncQuantityText();
    });
  }

  void _onManualQuantity(String raw) {
    final value = double.tryParse(raw.replaceAll(',', '.'));
    if (value == null) return;
    final hasMultiplier = _quantityOption != null;
    final b2b = _product.quantityRules?.isB2b == true;
    setState(() {
      if (hasMultiplier) {
        _quantityVisual = value.floor().clamp(1, 999999).toDouble();
      } else if (b2b) {
        _quantityVisual = value < 0.001 ? 0.001 : value;
      } else {
        _quantityVisual = value.floor().clamp(1, 999999).toDouble();
      }
    });
  }

  void _selectSingle(ProductOptionBlock block, int? id) {
    if (id == null) return;
    setState(() {
      for (final option in block.options) {
        _selectedIds.remove(option.id);
      }
      _selectedIds.add(id);
      _normalizeVisualAfterOptionChange();
    });
  }

  void _toggleCheckbox(ProductOption option, bool value) {
    setState(() {
      if (value) {
        _selectedIds.add(option.id);
      } else {
        _selectedIds.remove(option.id);
      }
      _normalizeVisualAfterOptionChange();
    });
  }

  void _normalizeVisualAfterOptionChange() {
    if (_quantityOption != null) {
      _quantityVisual = _quantityVisual.floor().clamp(1, 999999).toDouble();
    }
    _syncQuantityText();
  }

  Map<String, double> _numberValues() {
    final out = <String, double>{};
    for (final entry in _numberControllers.entries) {
      final value = double.tryParse(entry.value.text.trim().replaceAll(',', '.'));
      if (value != null) out['${entry.key}'] = value;
    }
    return out;
  }

  String? _validate() {
    for (final block in _product.optionBlocks) {
      if (!block.isRequired) continue;
      if (block.type == 'number') {
        final hasValue = block.options.any((o) {
          final value = _numberControllers[o.id]?.text.trim() ?? '';
          return value.isNotEmpty;
        });
        if (!hasValue) return 'Preencha “${block.name}”.';
      } else {
        final selected = block.options.any((o) => _selectedIds.contains(o.id));
        if (!selected) return 'Selecione “${block.name}”.';
      }
    }
    for (final block in _product.optionBlocks.where((b) => b.type == 'number')) {
      for (final option in block.options) {
        final raw = _numberControllers[option.id]?.text.trim() ?? '';
        if (raw.isEmpty) continue;
        final value = double.tryParse(raw.replaceAll(',', '.'));
        if (value == null) return 'Valor inválido em “${option.name}”.';
        if (option.numberMin != null && value < option.numberMin!) {
          return '“${option.name}” deve ser no mínimo ${formatQuantity(option.numberMin!, 3)} ${option.numberUnit ?? ''}.';
        }
        if (option.numberMax != null && value > option.numberMax!) {
          return '“${option.name}” deve ser no máximo ${formatQuantity(option.numberMax!, 3)} ${option.numberUnit ?? ''}.';
        }
      }
    }
    return null;
  }

  String _observationSummary() {
    final groups = <String, List<String>>{};
    for (final block in _product.optionBlocks) {
      if (block.type == 'number') {
        for (final option in block.options) {
          final raw = _numberControllers[option.id]?.text.trim() ?? '';
          if (raw.isEmpty) continue;
          groups.putIfAbsent(block.name, () => <String>[]).add(
                '${option.observationText.isEmpty ? option.name : option.observationText}: ${raw.replaceAll('.', ',')}${(option.numberUnit ?? '').isEmpty ? '' : ' ${option.numberUnit}'}',
              );
        }
      } else {
        for (final option in block.options.where((o) => _selectedIds.contains(o.id))) {
          groups.putIfAbsent(block.name, () => <String>[]).add(
                option.observationText.isEmpty ? option.name : option.observationText,
              );
        }
      }
    }
    final lines = <String>[];
    groups.forEach((key, values) => lines.add('$key: ${values.join(', ')}'));
    final obs = _observationController.text.trim();
    if (obs.isNotEmpty) lines.add('Obs Cliente: $obs');
    return lines.join('\n');
  }

  Future<void> _toggleFavorite() async {
    if (_changingFavorite) return;
    setState(() => _changingFavorite = true);
    try {
      final value = await widget.repository.toggleFavorite(_product.id);
      if (mounted) setState(() => _favorite = value);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _changingFavorite = false);
    }
  }

  void _addToCart() {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    widget.cart.addConfigured(
      product: _product,
      quantityVisual: _quantityVisual,
      quantityReal: _quantityReal,
      quantityMultiplier: _quantityOption?.quantityMultiplier,
      selectedVariationIds: _selectedIds.toList(growable: false),
      numberValues: _numberValues(),
      observation: _observationController.text.trim(),
      observationSummary: _observationSummary(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Produto adicionado ao carrinho.')),
    );
    Navigator.of(context).pop(true);
  }

  Uri? _storeBaseUri() {
    final api = Uri.tryParse(widget.repository.api.baseUrl);
    if (api == null) return null;
    final marker = '/api/mobile/';
    final idx = api.path.indexOf(marker);
    final rootPath = idx >= 0 ? api.path.substring(0, idx + 1) : '/';
    return api.replace(path: rootPath, query: null, fragment: null);
  }

  Future<bool> _openHtmlUrl(String rawUrl) async {
    final text = rawUrl.trim();
    if (text.isEmpty) return false;
    final parsed = Uri.tryParse(text);
    if (parsed == null) return false;
    final resolved = parsed.hasScheme
        ? parsed
        : (_storeBaseUri()?.resolveUri(parsed) ?? parsed);
    if (resolved.scheme != 'http' && resolved.scheme != 'https') return false;
    return launchUrl(resolved, mode: LaunchMode.externalApplication);
  }

  Widget _technicalHtml(BuildContext context, String html) {
    final scheme = Theme.of(context).colorScheme;
    return HtmlWidget(
      html,
      baseUrl: _storeBaseUri(),
      textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface,
            height: 1.42,
          ),
      customStylesBuilder: (element) {
        final tag = (element.localName ?? '').toLowerCase();
        if (tag == 'img') {
          return const {
            'max-width': '100%',
            'height': 'auto',
          };
        }
        if (tag == 'h1' || tag == 'h2' || tag == 'h3' || tag == 'h4') {
          return {
            'color': _hexColor(scheme.primary),
            'font-weight': '800',
            'margin-top': '16px',
            'margin-bottom': '8px',
            'line-height': '1.25',
          };
        }
        if (tag == 'table') {
          return {
            'width': '100%',
            'border-collapse': 'collapse',
            'margin-top': '10px',
            'margin-bottom': '14px',
            'border': '1px solid ${_hexColor(scheme.outlineVariant)}',
          };
        }
        if (tag == 'th') {
          return {
            'background-color': _hexColor(scheme.primary),
            'color': _hexColor(scheme.onPrimary),
            'padding': '10px',
            'font-weight': '800',
            'border': '1px solid ${_hexColor(scheme.outlineVariant)}',
          };
        }
        if (tag == 'td') {
          return {
            'color': _hexColor(scheme.onSurface),
            'padding': '10px',
            'border': '1px solid ${_hexColor(scheme.outlineVariant)}',
            'vertical-align': 'top',
          };
        }
        if (tag == 'p') {
          return {
            'color': _hexColor(scheme.onSurface),
            'margin-top': '6px',
            'margin-bottom': '10px',
            'line-height': '1.5',
          };
        }
        if (tag == 'li') {
          return {
            'color': _hexColor(scheme.onSurface),
            'margin-bottom': '5px',
          };
        }
        if (tag == 'strong' || tag == 'b') {
          return {
            'color': _hexColor(scheme.onSurface),
            'font-weight': '800',
          };
        }
        return null;
      },
      onTapUrl: _openHtmlUrl,
      onErrorBuilder: (context, element, error) => Text(
        element.text,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  String _hexColor(Color color) {
    final value = color.value & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    final pricing = calculateCampaign(p, _quantityReal);
    final media = p.gallery.isNotEmpty
        ? p.gallery
        : <String>[if (p.imageUrl != null) p.imageUrl!];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produto'),
        actions: [
          IconButton(
            tooltip: _favorite ? 'Remover dos favoritos' : 'Favoritar',
            onPressed: _changingFavorite ? null : _toggleFavorite,
            icon: _changingFavorite
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_favorite ? Icons.favorite : Icons.favorite_border, color: _favorite ? Colors.redAccent : null),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          _Gallery(media: media, repository: widget.repository),
          const SizedBox(height: 18),
          Text(
            p.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if ((p.code ?? '').isNotEmpty) _InfoPill('Cód. ${p.code}'),
              if ((p.brand ?? '').isNotEmpty) _InfoPill(p.brand!),
              if ((p.department ?? '').isNotEmpty) _InfoPill(p.department!),
              if ((p.unit ?? '').isNotEmpty) _InfoPill('Unidade: ${p.unit}'),
            ],
          ),
          const SizedBox(height: 14),
          _ProductDetailPrice(product: p),
          if (p.campaign != null) ...[
            const SizedBox(height: 8),
            _CampaignBox(product: p, pricing: pricing),
          ],
          // Compra primeiro: as mesmas escolhas do site ficam antes da ficha técnica.
          if (p.optionBlocks.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Personalize o item', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Escolha corte, preparo, porção/embalagem e demais opções disponíveis para este produto.'),
            const SizedBox(height: 10),
            ...p.optionBlocks.map(_buildOptionBlock),
          ],
          const SizedBox(height: 14),
          _QuantityCard(
            product: p,
            quantityVisual: _quantityVisual,
            quantityReal: _quantityReal,
            quantityOption: _quantityOption,
            controller: _quantityController,
            onMinus: () => _setQuantity(_quantityVisual - 1),
            onPlus: () => _setQuantity(_quantityVisual + 1),
            onChanged: _onManualQuantity,
            subtotal: pricing.subtotal,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _observationController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Observações especiais',
              hintText: 'Ex.: preferência de corte, gordura...',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          if (p.recommendations.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Você pode gostar',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 238,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: p.recommendations.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = p.recommendations[index];
                  return _RecommendationCard(
                    product: item,
                    repository: widget.repository,
                    cart: widget.cart,
                  );
                },
              ),
            ),
          ],
          if ((p.fullDescription ?? p.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 22),
            _SectionCard(
              title: 'Informações do produto',
              child: Text(p.fullDescription ?? p.description ?? ''),
            ),
          ],
          if ((p.barcode ?? '').isNotEmpty ||
              (p.technicalHtml ?? '').isNotEmpty ||
              (p.technicalInfo ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Ficha técnica',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.fact_check_outlined, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Características e especificações do produto',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  if ((p.barcode ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.qr_code_2, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Código de barras', style: Theme.of(context).textTheme.labelMedium),
                                SelectableText(
                                  p.barcode!,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if ((p.technicalHtml ?? '').isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _technicalHtml(context, p.technicalHtml!),
                  ] else if ((p.technicalInfo ?? '').isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      p.technicalInfo!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(14),
        child: FilledButton.icon(
          onPressed: p.available && !_loading ? _addToCart : null,
          icon: const Icon(Icons.add_shopping_cart),
          label: Text(p.available ? 'Adicionar ao carrinho · ${_money(pricing.subtotal)}' : 'Indisponível'),
        ),
      ),
    );
  }

  Widget _buildOptionBlock(ProductOptionBlock block) {
    final title = '${block.name}${block.isRequired ? ' *' : ''}';
    if (block.type == 'select') {
      int? value;
      for (final o in block.options) {
        if (_selectedIds.contains(o.id)) {
          value = o.id;
          break;
        }
      }
      return _SectionCard(
        title: title,
        child: DropdownButtonFormField<int>(
          value: value,
          decoration: const InputDecoration(hintText: 'Selecione...'),
          items: block.options
              .map((o) => DropdownMenuItem<int>(value: o.id, child: Text(o.name)))
              .toList(),
          onChanged: (id) => _selectSingle(block, id),
        ),
      );
    }
    if (block.type == 'number') {
      return _SectionCard(
        title: title,
        child: Column(
          children: block.options.map((o) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _numberControllers[o.id],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
                decoration: InputDecoration(
                  labelText: o.name,
                  suffixText: o.numberUnit,
                  helperText: _rangeText(o),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }
    if (block.type == 'checkbox') {
      return _SectionCard(
        title: title,
        child: Column(
          children: block.options.map((o) {
            return CheckboxListTile(
              value: _selectedIds.contains(o.id),
              contentPadding: EdgeInsets.zero,
              title: Text(o.name),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) => _toggleCheckbox(o, value ?? false),
            );
          }).toList(),
        ),
      );
    }
    return _SectionCard(
      title: title,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: block.options.map((o) {
          return ChoiceChip(
            label: Text(o.name),
            selected: _selectedIds.contains(o.id),
            onSelected: (_) => _selectSingle(block, o.id),
          );
        }).toList(),
      ),
    );
  }

  String? _rangeText(ProductOption option) {
    final parts = <String>[];
    if (option.numberMin != null) parts.add('mín. ${formatQuantity(option.numberMin!, 3)}');
    if (option.numberMax != null) parts.add('máx. ${formatQuantity(option.numberMax!, 3)}');
    if (option.numberStep > 0) parts.add('passo ${formatQuantity(option.numberStep, 3)}');
    return parts.isEmpty ? null : parts.join(' · ');
  }
}


class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.product,
    required this.repository,
    required this.cart,
  });

  final StoreProduct product;
  final StoreRepository repository;
  final CartController cart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 156,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductDetailPage(
                  product: product,
                  repository: repository,
                  cart: cart,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (product.imageUrl ?? '').isNotEmpty
                        ? Image.network(
                            repository.api.resolvePublicUrl(product.imageUrl!) ?? product.imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.image_not_supported_outlined),
                          )
                        : const Icon(Icons.image_outlined, size: 42),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  product.priceHidden ? 'Preço surpresa' : _money(product.fractionPrice ?? product.price),
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                if ((product.fractionLabel ?? '').isNotEmpty)
                  Text(
                    product.fractionLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _ProductDetailPrice extends StatelessWidget {
  const _ProductDetailPrice({required this.product});
  final StoreProduct product;

  @override
  Widget build(BuildContext context) {
    if (product.priceHidden) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock_outlined),
            const SizedBox(width: 8),
            Text('Preço surpresa', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          ],
        ),
      );
    }
    final mainStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w900,
          color: Theme.of(context).colorScheme.primary,
        );
    final mode = product.priceDisplayMode.toUpperCase();
    if (mode == 'CHEIO_E_MENOR' && product.fractionPrice != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preço cheio: ${_money(product.price)}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text('${_money(product.fractionPrice!)} ${product.fractionLabel ?? ''}', style: mainStyle),
        ],
      );
    }
    if (mode == 'PRECO_MENOR' && product.fractionPrice != null) {
      return Text('${_money(product.fractionPrice!)} ${product.fractionLabel ?? ''}', style: mainStyle);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (product.hasOffer)
          Text(
            _money(product.oldPrice!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(decoration: TextDecoration.lineThrough),
          ),
        Text(_money(product.price), style: mainStyle),
      ],
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.media, required this.repository});
  final List<String> media;
  final StoreRepository repository;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      return AspectRatio(
        aspectRatio: 1.1,
        child: Container(
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(22)),
          child: const Icon(Icons.image_outlined, size: 80),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 1.08,
      child: PageView.builder(
        itemCount: media.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Image.network(
                repository.api.resolvePublicUrl(media[i]) ?? media[i],
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined, size: 70),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CampaignBox extends StatelessWidget {
  const _CampaignBox({required this.product, required this.pricing});
  final StoreProduct product;
  final CampaignPriceResult pricing;

  @override
  Widget build(BuildContext context) {
    final c = product.campaign!;
    String title;
    if (!c.active) {
      title = '${c.name} · começa em ${_campaignCountdown(c.secondsToStart)}';
    } else if (c.type == 'SIMPLES') {
      title = 'Na promoção sai por ${_money(c.offerPrice)} ${_unitText(product.unit)}';
    } else if (c.type == 'QTDE_MINIMA') {
      title = 'A partir de ${formatQuantity(c.minimumQuantity, 3)} ${product.unit ?? ''}: ${_money(c.offerPrice)} ${_unitText(product.unit)}';
    } else if (c.type == 'LEVE_X_PAGUE_Y') {
      title = 'Leve ${formatQuantity(c.minimumQuantity, 3)} e pague ${formatQuantity(c.paidQuantity, 3)}';
    } else {
      title = c.name;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pricing.applied ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
        border: Border.all(color: pricing.applied ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(!c.active ? Icons.timer_outlined : (pricing.applied ? Icons.local_offer : Icons.card_giftcard), color: !c.active ? Theme.of(context).colorScheme.primary : (pricing.applied ? Colors.green.shade700 : Colors.orange.shade800)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                if ((pricing.message ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(pricing.message!, style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityCard extends StatelessWidget {
  const _QuantityCard({
    required this.product,
    required this.quantityVisual,
    required this.quantityReal,
    required this.quantityOption,
    required this.controller,
    required this.onMinus,
    required this.onPlus,
    required this.onChanged,
    required this.subtotal,
  });
  final StoreProduct product;
  final double quantityVisual;
  final double quantityReal;
  final ProductOption? quantityOption;
  final TextEditingController controller;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<String> onChanged;
  final double subtotal;

  @override
  Widget build(BuildContext context) {
    final isB2b = product.quantityRules?.isB2b == true;
    final decimals = quantityOption != null ? 0 : (isB2b ? 3 : 0);
    final visualLabel = quantityOption?.quantityText?.trim().isNotEmpty == true
        ? quantityOption!.quantityText!
        : 'Quantidade';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(visualLabel, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton.filledTonal(onPressed: onMinus, icon: const Icon(Icons.remove)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.numberWithOptions(decimal: decimals > 0),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimals > 0 ? r'[0-9,.]' : r'[0-9]'))],
                    onChanged: onChanged,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: onPlus, icon: const Icon(Icons.add)),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Total estimado', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    Text(_money(subtotal), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
            if (quantityOption != null) ...[
              const SizedBox(height: 8),
              Text(
                'Pedido será gerado em ${product.unit ?? 'UN'}: ${formatQuantity(quantityReal, 3)} ${product.unit ?? ''}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ] else if (isB2b) ...[
              const SizedBox(height: 8),
              Text('Quantidade aceita até 3 casas decimais. Mínimo 0,001 ${product.unit ?? ''}.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      );
}

class _InfoPill extends StatelessWidget {
  const _InfoPill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.45),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

String _campaignCountdown(int seconds) {
  if (seconds <= 0) return 'agora';
  final days = seconds ~/ 86400;
  final hours = (seconds % 86400) ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${minutes}min';
  return '${minutes.clamp(1, 59)}min';
}

String _money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
String _unitText(String? unit) {
  final value = (unit ?? 'UN').toUpperCase();
  return ['UN', 'UND', 'UNID', 'UNIDADE'].contains(value) ? 'a unidade' : 'por $value';
}
