import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/bootstrap_config.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import 'sofie_models.dart';
import 'sofie_repository.dart';

class SofieFloatingButton extends StatelessWidget {
  const SofieFloatingButton({
    super.key,
    required this.api,
    required this.config,
    this.onCartChanged,
  });

  final ApiClient api;
  final SofieConfig config;
  final Future<void> Function()? onCartChanged;

  @override
  Widget build(BuildContext context) {
    if (!config.enabled) return const SizedBox.shrink();
    final color = AppTheme.parseColor(config.primaryColor) ??
        Theme.of(context).colorScheme.primary;
    final foreground = color.computeLuminance() > .48 ? Colors.black : Colors.white;

    return SizedBox(
      width: 62,
      height: 62,
      child: FloatingActionButton(
      heroTag: 'sofie-fab',
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      backgroundColor: color,
      foregroundColor: foreground,
      tooltip: 'Falar com ${config.name}',
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SofieChatPanel(
          api: api,
          config: config,
          onCartChanged: onCartChanged,
        ),
      ),
      child: _SofieAvatar(api: api, config: config, size: 44, foreground: foreground),
    ),
    );
  }
}

class SofieChatPanel extends StatefulWidget {
  const SofieChatPanel({
    super.key,
    required this.api,
    required this.config,
    this.onCartChanged,
  });

  final ApiClient api;
  final SofieConfig config;
  final Future<void> Function()? onCartChanged;

  @override
  State<SofieChatPanel> createState() => _SofieChatPanelState();
}

class _SofieChatPanelState extends State<SofieChatPanel> {
  late final SofieRepository _repository;
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<SofieMessage> _messages = const [];
  List<SofiePendingAction> _actions = const [];
  List<SofieSuggestedProduct> _suggested = const [];
  String _status = 'ABERTA';
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _pollTimer;

  int get _lastId {
    var id = 0;
    for (final message in _messages) {
      if (message.id > id) id = message.id;
    }
    return id;
  }

  @override
  void initState() {
    super.initState();
    _repository = SofieRepository(widget.api);
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final session = await _repository.bootstrap();
      if (!mounted) return;
      setState(() {
        _messages = session.messages;
        _actions = session.pendingActions;
        _status = session.status;
        _loading = false;
        _error = null;
      });
      _startPolling();
      _scrollBottom();
      if (widget.onCartChanged != null) unawaited(widget.onCartChanged!());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_sending || !mounted) return;
    try {
      final reply = await _repository.poll(_lastId);
      if (!mounted) return;
      if (reply.messages.isNotEmpty || reply.pendingActions.isNotEmpty) {
        setState(() {
          _mergeMessages(reply.messages);
          _actions = reply.pendingActions;
          _status = reply.status;
        });
        _scrollBottom();
      }
    } catch (_) {
      // Poll silencioso; a conversa continua utilizavel.
    }
  }

  Future<void> _send([String? quick]) async {
    final message = (quick ?? _text.text).trim();
    if (message.isEmpty || _sending) return;
    _text.clear();

    final localId = -DateTime.now().microsecondsSinceEpoch;
    setState(() {
      _sending = true;
      _error = null;
      _messages = [
        ..._messages,
        SofieMessage(id: localId, origin: 'CLIENTE', text: message),
      ];
    });
    _scrollBottom();

    try {
      final reply = await _repository.send(message);
      if (!mounted) return;
      setState(() {
        if (reply.messages.isNotEmpty) {
          _messages = _messages.where((m) => m.id != localId).toList();
          _mergeMessages(reply.messages);
        } else if (reply.response.isNotEmpty) {
          _messages = [
            ..._messages,
            SofieMessage(
              id: reply.lastId > 0 ? reply.lastId : DateTime.now().millisecondsSinceEpoch,
              origin: 'SOFIE',
              text: reply.response,
            ),
          ];
        }
        _actions = reply.pendingActions;
        _suggested = reply.suggestedProducts;
        _status = reply.status;
        _sending = false;
      });
      _scrollBottom();
      if (widget.onCartChanged != null) unawaited(widget.onCartChanged!());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _confirm(SofiePendingAction action) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final reply = await _repository.confirmAction(action.id);
      if (!mounted) return;
      setState(() {
        if (reply.response.isNotEmpty) {
          _messages = [
            ..._messages,
            SofieMessage(
              id: reply.lastId > 0 ? reply.lastId : DateTime.now().millisecondsSinceEpoch,
              origin: 'SOFIE',
              text: reply.response,
            ),
          ];
        }
        _actions = reply.pendingActions;
        _sending = false;
      });
      _scrollBottom();
      if (widget.onCartChanged != null) unawaited(widget.onCartChanged!());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    }
  }

  void _mergeMessages(List<SofieMessage> incoming) {
    final byId = <int, SofieMessage>{};
    for (final message in _messages) {
      if (message.id > 0) byId[message.id] = message;
    }
    for (final message in incoming) {
      if (message.id > 0) byId[message.id] = message;
    }
    final local = _messages.where((m) => m.id <= 0).toList();
    final server = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    _messages = [...server, ...local];
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = AppTheme.parseColor(widget.config.primaryColor) ?? scheme.primary;
    final brandText = brand.computeLuminance() > .48 ? Colors.black : Colors.white;
    final media = MediaQuery.of(context);
    final height = media.size.height * .78;
    final keyboard = media.viewInsets.bottom;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboard),
        child: Container(
      height: height,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              color: brand,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              children: [
                _SofieAvatar(api: widget.api, config: widget.config, size: 42, foreground: brandText),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.config.name,
                        style: TextStyle(
                          color: brandText,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${widget.config.role} · ${_status == 'FILA' ? 'aguardando atendente' : _status == 'HUMANO' ? 'atendimento humano' : 'online'}',
                        style: TextStyle(color: brandText.withOpacity(.82), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  color: brandText,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: scheme.onErrorContainer, fontSize: 12),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              itemCount: _messages.length,
              itemBuilder: (_, index) => _MessageBubble(
                message: _messages[index],
                brand: brand,
              ),
            ),
          ),
          if (_suggested.isNotEmpty)
            SizedBox(
              height: 88,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                scrollDirection: Axis.horizontal,
                itemCount: _suggested.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final product = _suggested[index];
                  return Container(
                    width: 190,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        if (product.imageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              product.imageUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox(width: 48),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                              if (product.priceText != null) Text(product.priceText!, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w900, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (_actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Column(
                children: _actions
                    .map(
                      (action) => SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _sending ? null : () => _confirm(action),
                          icon: const Icon(Icons.shopping_cart_checkout),
                          label: Text(
                            action.valueText.isEmpty
                                ? 'Confirmar ação da ${widget.config.name}'
                                : 'Confirmar · ${action.valueText}',
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (!_loading)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
              child: Row(
                children: [
                  _Quick(text: '🏷️ Ofertas', onTap: () => _send('Quais são as melhores ofertas de hoje?')),
                  _Quick(text: '🛒 Carrinho', onTap: () => _send('O que tem no meu carrinho?')),
                  _Quick(text: '📦 Pedido', onTap: () => _send('Como está meu pedido?')),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2500,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Fale com a ${widget.config.name}...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: ActionChip(label: Text(text), onPressed: onTap),
      );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.brand});
  final SofieMessage message;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.fromCustomer;
    final background = mine ? brand : scheme.surfaceContainerHighest;
    final foreground = mine
        ? (brand.computeLuminance() > .48 ? Colors.black : Colors.white)
        : scheme.onSurface;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 330),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: foreground, height: 1.3),
        ),
      ),
    );
  }
}

class _SofieAvatar extends StatelessWidget {
  const _SofieAvatar({
    required this.api,
    required this.config,
    required this.size,
    required this.foreground,
  });
  final ApiClient api;
  final SofieConfig config;
  final double size;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final raw = (config.iconUrl ?? config.avatarUrl ?? '').trim();
    final url = raw.isEmpty ? '' : (api.resolvePublicUrl(raw) ?? raw);
    if (url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: size,
              height: size,
              child: Center(
                child: SizedBox(
                  width: size * .34,
                  height: size * .34,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() => SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Icon(
            Icons.auto_awesome_rounded,
            color: foreground,
            size: size * .52,
          ),
        ),
      );
}
