import '../../core/localization/localized_widgets.dart';
import '../../core/localization/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../cart/cart_controller.dart';
import 'product_detail_page.dart';
import 'store_models.dart';
import 'store_repository.dart';
import 'customer_care_pages.dart';
import 'address_edit_page.dart';

enum _OrderFilter { all, pending, inProgress, finished, cancelled }

extension on _OrderFilter {
  String get label => switch (this) {
        _OrderFilter.pending => 'Pendentes',
        _OrderFilter.inProgress => 'Em andamento',
        _OrderFilter.finished => 'Finalizados',
        _OrderFilter.cancelled => 'Cancelados',
        _ => 'Todos',
      };
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, required this.repository, required this.cart});
  final StoreRepository repository;
  final CartController cart;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = const [];
  _OrderFilter _filter = _OrderFilter.all;
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final orders = await widget.repository.orders();
      if (mounted) setState(() => _orders = orders);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  _OrderFilter _group(Map<String, dynamic> order) {
    final id = int.tryParse('${order['status_id'] ?? ''}') ?? 0;
    final raw = _firstText(order, const [
      'status',
      'situacao',
      'status_nome',
    ]).toLowerCase();
    if ({4, 7, 10}.contains(id) ||
        raw.contains('cancel') ||
        raw.contains('recus') ||
        raw.contains('falha')) return _OrderFilter.cancelled;
    if ({3, 9}.contains(id) ||
        raw.contains('conclu') ||
        raw.contains('fatur') ||
        raw.contains('entregue') ||
        raw.contains('finaliz')) return _OrderFilter.finished;
    if (id == 1 ||
        raw.contains('pend') ||
        raw.contains('aguard') ||
        raw.contains('novo') ||
        raw.contains('receb')) return _OrderFilter.pending;
    return _OrderFilter.inProgress;
  }

  List<Map<String, dynamic>> get _visibleOrders {
    final q = _search.text.trim().toLowerCase();
    return _orders.where((order) {
      if (_filter != _OrderFilter.all && _group(order) != _filter) return false;
      if (q.isEmpty) return true;
      final number = _firstText(
              order,
              const [
                'number',
                'numero',
                'order_number',
                'pedido_numero',
              ],
              fallback: '${_orderId(order)}')
          .toLowerCase();
      final status = _firstText(order, const [
        'status',
        'situacao',
        'status_nome',
      ]).toLowerCase();
      return number.contains(q) || status.contains(q);
    }).toList(growable: false);
  }

  Color _statusColor(BuildContext context, Map<String, dynamic> order) {
    final parsed = AppTheme.parseColor(
      _firstText(order, const ['status_color', 'cor_status']),
    );
    if (parsed != null) return parsed;
    final scheme = Theme.of(context).colorScheme;
    return switch (_group(order)) {
      _OrderFilter.pending => Colors.orange,
      _OrderFilter.inProgress => scheme.primary,
      _OrderFilter.finished => Colors.green,
      _OrderFilter.cancelled => scheme.error,
      _ => scheme.outline,
    };
  }

  int _count(_OrderFilter filter) => filter == _OrderFilter.all
      ? _orders.length
      : _orders.where((o) => _group(o) == filter).length;

  @override
  Widget build(BuildContext context) {
    final visible = _visibleOrders;
    return Scaffold(
      appBar: AppBar(title: const LText('Meus pedidos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, retry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: LDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Buscar pedido ou status',
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _search.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _OrderFilter.values
                              .map(
                                (filter) => Padding(
                                  padding: const EdgeInsets.only(right: 7),
                                  child: ChoiceChip(
                                    selected: _filter == filter,
                                    onSelected: (_) =>
                                        setState(() => _filter = filter),
                                    label: LText(
                                      '${filter.label} (${_count(filter)})',
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_orders.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 70),
                          child: Center(
                            child: LText('Você ainda não possui pedidos.'),
                          ),
                        )
                      else if (visible.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 50),
                          child: Center(
                              child: LText('Nenhum pedido neste filtro.')),
                        )
                      else
                        ...visible.map((order) {
                          final orderId = _orderId(order);
                          final number = _firstText(
                              order,
                              const [
                                'number',
                                'numero',
                                'order_number',
                                'pedido_numero',
                              ],
                              fallback: orderId > 0 ? '$orderId' : '');
                          final status = _firstText(
                              order,
                              const [
                                'status',
                                'situacao',
                                'status_nome',
                              ],
                              fallback: 'Pedido recebido');
                          final paymentStatus = _firstText(order, const [
                            'payment_status',
                            'status_pagamento',
                            'situacao_financeira',
                          ]);
                          final paymentMethod = _paymentMethodSummary(order);
                          final color = _statusColor(context, order);
                          final onColor = color.computeLuminance() > .50
                              ? Colors.black
                              : Colors.white;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              margin: EdgeInsets.zero,
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => OrderDetailPage(
                                      repository: widget.repository,
                                      cart: widget.cart,
                                      orderId: orderId,
                                      initialOrder: order,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                        width: 6, height: 120, color: color),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(13),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: LText(
                                                    'Pedido #$number',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                LText(
                                                  _money(
                                                    numberValue(
                                                      order['total'] ??
                                                          order[
                                                              'valor_total'] ??
                                                          order['amount'],
                                                    ),
                                                  ),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 7),
                                            Wrap(
                                              spacing: 7,
                                              runSpacing: 5,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 9,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: color,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            99),
                                                  ),
                                                  child: LText(
                                                    status,
                                                    style: TextStyle(
                                                      color: onColor,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                                if (paymentMethod.isNotEmpty)
                                                  LText(
                                                    paymentMethod,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                if (paymentStatus.isNotEmpty)
                                                  LText(
                                                    ' · ${_friendlyPaymentStatus(paymentStatus)}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 7),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.schedule,
                                                  size: 15,
                                                  color: Theme.of(
                                                    context,
                                                  )
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: LText(
                                                    _formatDate(
                                                      order['created_at'] ??
                                                          order[
                                                              'data_criacao'] ??
                                                          order['data'] ??
                                                          order['emissao'],
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                ),
                                                const Icon(Icons.chevron_right),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({
    super.key,
    required this.repository,
    required this.cart,
    required this.orderId,
    this.initialOrder,
  });
  final StoreRepository repository;
  final CartController cart;
  final int orderId;
  final Map<String, dynamic>? initialOrder;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  bool _loading = true;
  bool _repeating = false;
  String? _error;
  Map<String, dynamic> _order = const {};

  @override
  void initState() {
    super.initState();
    _order = Map<String, dynamic>.from(
      widget.initialOrder ?? const <String, dynamic>{},
    );
    _load();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    if (widget.orderId <= 0) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'O servidor não informou o identificador interno deste pedido. Exibindo os dados disponíveis na listagem.';
        });
      }
      return;
    }
    try {
      final order = await widget.repository.orderDetail(widget.orderId);
      if (mounted) {
        setState(() => _order = <String, dynamic>{..._order, ...order});
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openExternal(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    final resolved = widget.repository.api.resolvePublicUrl(text) ?? text;
    final uri = Uri.tryParse(resolved);
    if (uri == null || !uri.hasScheme) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: LText('Link inválido.')));
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LText('Não foi possível abrir o link.')),
      );
    }
  }

  Future<void> _repeatOrder() async {
    if (_repeating) return;
    final items = _orderItems(_order);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LText('Este pedido não possui itens para repetir.'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LText('Repetir pedido'),
        content: const LText(
          'Os produtos serão consultados novamente com preço e disponibilidade atuais. '
          'O carrinho atual será substituído pelos itens que ainda puderem ser comprados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const LText('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.replay),
            label: const LText('Repetir pedido'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _repeating = true);
    final prepared = <_RepeatOrderLine>[];
    final skipped = <String>[];

    for (final item in items) {
      final productId = _firstText(item, const [
        'product_id',
        'produto_id',
        'item_id',
        'id',
      ]);
      final itemName = _firstText(
          item,
          const [
            'name',
            'product_name',
            'nome',
            'descricao',
          ],
          fallback: 'Produto');
      if (productId.isEmpty) {
        skipped.add('$itemName: produto sem identificação.');
        continue;
      }
      try {
        final product = await widget.repository.product(productId);
        if (!product.available) {
          skipped.add('${product.name}: indisponível.');
          continue;
        }

        final selectedIds = _intList(
          item['selected_variation_ids'] ??
              item['variation_ids'] ??
              item['opcionais_ids'],
        );
        final numberValues = _numberMap(
          item['number_values'] ?? item['option_number_values'],
        );

        // Quando o pedido antigo não traz os IDs dos opcionais, reaplica os padrões atuais.
        for (final block in product.optionBlocks) {
          if (block.type == 'number') {
            if (block.isRequired &&
                !block.options.any(
                  (o) => numberValues.containsKey('${o.id}'),
                )) {
              skipped.add(
                '${product.name}: precisa configurar “${block.name}”.',
              );
              continue;
            }
            continue;
          }
          final hasSelected = block.options.any(
            (o) => selectedIds.contains(o.id),
          );
          if (hasSelected) continue;
          final defaults =
              block.options.where((o) => o.isDefault).toList(growable: false);
          if (block.type == 'checkbox') {
            selectedIds.addAll(defaults.map((e) => e.id));
          } else if (defaults.isNotEmpty) {
            selectedIds.add(defaults.first.id);
          } else if (block.isRequired && block.options.isNotEmpty) {
            selectedIds.add(block.options.first.id);
          }
        }

        bool missingRequiredNumber = false;
        for (final block in product.optionBlocks.where(
          (b) => b.type == 'number' && b.isRequired,
        )) {
          if (!block.options.any((o) => numberValues.containsKey('${o.id}'))) {
            missingRequiredNumber = true;
            break;
          }
        }
        if (missingRequiredNumber) continue;

        double? multiplier;
        for (final block in product.optionBlocks) {
          for (final option in block.options) {
            if (selectedIds.contains(option.id) &&
                option.affectsQuantity &&
                (option.quantityMultiplier ?? 0) > 0) {
              multiplier = option.quantityMultiplier;
              break;
            }
          }
          if (multiplier != null) break;
        }

        var quantityReal = numberValue(
          item['quantity_real'] ?? item['quantity'] ?? item['quantidade'],
          fallback: 1,
        );
        if (quantityReal <= 0) quantityReal = 1;
        var quantityVisual = numberValue(item['quantity_visual'], fallback: 0);
        if (quantityVisual <= 0) {
          quantityVisual = multiplier != null && multiplier > 0
              ? quantityReal / multiplier
              : quantityReal;
        }

        prepared.add(
          _RepeatOrderLine(
            product: product,
            quantityVisual: quantityVisual,
            quantityReal: quantityReal,
            quantityMultiplier: multiplier,
            selectedVariationIds: selectedIds,
            numberValues: numberValues,
            observation: _firstText(item, const [
              'observation',
              'observacao',
              'notes',
            ]),
            observationSummary: _firstText(item, const [
              'complement',
              'complemento',
              'observation_summary',
            ]),
          ),
        );
      } catch (_) {
        skipped.add('$itemName: não foi possível consultar o produto atual.');
      }
    }

    if (!mounted) return;
    if (prepared.isEmpty) {
      setState(() => _repeating = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const LText('Não foi possível repetir'),
          content: LText(
            skipped.isEmpty
                ? 'Nenhum item pôde ser adicionado.'
                : skipped.join('\n'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const LText('Fechar'),
            ),
          ],
        ),
      );
      return;
    }

    await widget.cart.clear();
    for (final line in prepared) {
      widget.cart.addConfigured(
        product: line.product,
        quantityVisual: line.quantityVisual,
        quantityReal: line.quantityReal,
        quantityMultiplier: line.quantityMultiplier,
        selectedVariationIds: line.selectedVariationIds,
        numberValues: line.numberValues,
        observation: line.observation,
        observationSummary: line.observationSummary,
      );
    }
    if (mounted) setState(() => _repeating = false);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LText('Pedido colocado no carrinho'),
        content: LText(
          skipped.isEmpty
              ? '${prepared.length} item(ns) foram adicionados com os dados atuais.'
              : '${prepared.length} item(ns) foram adicionados.\n\nNão adicionados:\n${skipped.join('\n')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const LText('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _order.isEmpty)
      return Scaffold(
        appBar: AppBar(title: const LText('Pedido')),
        body: const Center(child: CircularProgressIndicator()),
      );
    if (_error != null && _order.isEmpty)
      return Scaffold(
        appBar: AppBar(title: const LText('Pedido')),
        body: _ErrorView(message: _error!, retry: _load),
      );
    final items = _orderItems(_order);
    final payment = mapValue(_order['payment'] ?? _order['pagamento']);
    final paymentEntries = _paymentEntries(_order, payment);
    final paymentMethod = _paymentMethodSummary(_order);
    final pix = _firstText(payment, const [
      'pix_code',
      'pix_copia_cola',
      'qr_code_text',
    ]);
    final boleto = _firstText(payment, const [
      'boleto_barcode',
      'barcode',
      'linha_digitavel',
    ]);
    final boletoUrl = _firstText(payment, const ['boleto_url', 'url']);
    final tracking = _trackingData(_order);
    final trackingCode = _firstText(tracking, const [
      'code',
      'tracking_code',
      'codigo',
      'codigo_rastreio',
    ]);
    final trackingUrl = _firstText(tracking, const [
      'url',
      'tracking_url',
      'link',
      'rastreio_url',
    ]);
    final trackingEvents = listValue(
      tracking['events'] ??
          _order['tracking_events'] ??
          _order['timeline'] ??
          _order['history'] ??
          _order['historico'],
    );
    final delivery = _orderDeliveryData(_order);
    final receiptType = _firstText(_order, const [
      'receipt_type',
      'tipo_entrega',
      'delivery_type',
    ]);
    final coupon = _firstText(_order, const [
      'coupon',
      'cupom',
      'coupon_code',
      'cupom_codigo',
    ]);
    final notes = _firstText(_order, const [
      'notes',
      'observacoes',
      'observation',
      'observacao',
    ]);
    final origin = _firstText(_order, const [
      'origin',
      'origem',
      'origem_pedido',
    ]);
    final erpNumber = _firstText(_order, const [
      'erp_order_number',
      'erp_pedido_numero',
      'pedido_erp',
    ]);
    final invoiceNumber = _firstText(_order, const [
      'invoice_number',
      'numero_nf',
      'nf_numero',
    ]);
    final number = _firstText(
        _order,
        const [
          'number',
          'numero',
          'order_number',
          'pedido_numero',
        ],
        fallback: widget.orderId > 0 ? '${widget.orderId}' : '');
    final statusColor = AppTheme.parseColor(
          _firstText(_order, const ['status_color', 'cor_status']),
        ) ??
        Theme.of(context).colorScheme.primary;
    final statusTextColor =
        statusColor.computeLuminance() > .50 ? Colors.black : Colors.white;
    return Scaffold(
      appBar: AppBar(
        title: LText('Pedido #$number'),
        actions: [
          IconButton(
            tooltip: tr('Repetir pedido'),
            onPressed: _repeating ? null : _repeatOrder,
            icon: _repeating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.replay),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              _InlineWarningCard(message: _error!, onRetry: _load),
              const SizedBox(height: 10),
            ],
            Card(
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: statusColor, width: 6),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: LText(
                        _firstText(
                            _order,
                            const [
                              'status',
                              'situacao',
                              'status_nome',
                            ],
                            fallback: 'Pedido recebido'),
                        style: TextStyle(
                          color: statusTextColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LText(
                      'Realizado em ${_formatDate(_order['created_at'] ?? _order['data_criacao'] ?? _order['data'] ?? _order['emissao'])}',
                    ),
                    if (_firstText(_order, const [
                      'scheduled_at',
                      'data_agendada',
                      'agendamento',
                    ]).isNotEmpty)
                      LText(
                        'Previsão: ${_formatDate(_firstText(_order, const [
                              'scheduled_at',
                              'data_agendada',
                              'agendamento'
                            ]))}',
                      ),
                    if (paymentMethod.isNotEmpty)
                      LText('Pago com: $paymentMethod'),
                    if (_firstText(_order, const [
                      'payment_status',
                      'status_pagamento',
                      'situacao_financeira',
                    ]).isNotEmpty)
                      LText(
                        'Situação financeira: ${_friendlyPaymentStatus(_firstText(_order, const [
                              'payment_status',
                              'status_pagamento',
                              'situacao_financeira'
                            ]))}',
                      ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _repeating ? null : _repeatOrder,
                        icon: const Icon(Icons.replay),
                        label: const LText('Repetir pedido'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.orderId <= 0
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OrderIssuePage(
                            repository: widget.repository,
                            orderId: widget.orderId,
                          ),
                        ),
                      ),
              icon: const Icon(Icons.support_agent),
              label: const LText('Informar problema / Abrir disputa'),
            ),
            const SizedBox(height: 10),
            _TrackingCard(
              status: _firstText(
                  _order,
                  const [
                    'status',
                    'situacao',
                    'status_nome',
                  ],
                  fallback: 'Pedido recebido'),
              code: trackingCode,
              url: trackingUrl,
              events: trackingEvents,
              onOpenUrl:
                  trackingUrl.isEmpty ? null : () => _openExternal(trackingUrl),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LText(
                      'Detalhes do pedido',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 9),
                    if (receiptType.isNotEmpty)
                      _DetailTextLine(
                        'Modalidade',
                        _friendlyReceiptType(receiptType),
                      ),
                    if (_firstText(_order, const [
                      'scheduled_at',
                      'data_agendada',
                      'agendamento',
                      'data_previsao_entrega',
                    ]).isNotEmpty)
                      _DetailTextLine(
                        'Agendamento',
                        _formatDate(
                          _firstText(_order, const [
                            'scheduled_at',
                            'data_agendada',
                            'agendamento',
                            'data_previsao_entrega',
                          ]),
                        ),
                      ),
                    if (delivery.isNotEmpty &&
                        _orderAddressLine(delivery).isNotEmpty)
                      _DetailTextLine(
                        'Endereço de entrega',
                        _orderAddressLine(delivery),
                      ),
                    if (coupon.isNotEmpty) _DetailTextLine('Cupom', coupon),
                    if (notes.isNotEmpty) _DetailTextLine('Observações', notes),
                    if (erpNumber.isNotEmpty)
                      _DetailTextLine('Pedido ERP', erpNumber),
                    if (invoiceNumber.isNotEmpty)
                      _DetailTextLine('Nota fiscal', invoiceNumber),
                    if (origin.isNotEmpty)
                      _DetailTextLine('Origem', origin.toUpperCase()),
                    if (receiptType.isEmpty &&
                        delivery.isEmpty &&
                        coupon.isEmpty &&
                        notes.isEmpty &&
                        erpNumber.isEmpty &&
                        invoiceNumber.isEmpty &&
                        origin.isEmpty)
                      LText(
                        'Nenhum detalhe adicional foi retornado pela API.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LText(
                      'Itens',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: LText(
                          'A API não retornou os itens deste pedido. Puxe a tela para baixo para tentar novamente.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LText(
                                    _firstText(
                                        item,
                                        const [
                                          'name',
                                          'nome',
                                          'product_name',
                                          'descricao',
                                        ],
                                        fallback: 'Produto'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  LText(
                                    '${formatQuantity(numberValue(item['quantity'] ?? item['quantidade'] ?? item['quantity_real']), 3)} × ${_money(numberValue(item['unit_price'] ?? item['preco_unitario'] ?? item['valor_unitario'] ?? item['price']))}',
                                  ),
                                  if (_firstText(item, const [
                                    'complement',
                                    'complemento',
                                    'observation_summary',
                                    'observacao',
                                  ]).isNotEmpty)
                                    LText(
                                      _firstText(item, const [
                                        'complement',
                                        'complemento',
                                        'observation_summary',
                                        'observacao',
                                      ]),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            LText(
                              _money(
                                numberValue(
                                  item['total'] ??
                                      item['valor_total'] ??
                                      item['subtotal'],
                                ),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _SummaryLine(
                      'Produtos',
                      numberValue(
                        _order['subtotal'] ?? _order['valor_produtos'],
                      ),
                    ),
                    _SummaryLine(
                      'Frete',
                      numberValue(_order['freight'] ?? _order['frete']),
                    ),
                    if (numberValue(_order['discount'] ?? _order['desconto']) >
                        0)
                      _SummaryLine(
                        'Desconto',
                        -numberValue(_order['discount'] ?? _order['desconto']),
                      ),
                    const Divider(),
                    _SummaryLine(
                      'Total',
                      numberValue(
                        _order['total'] ??
                            _order['valor_total'] ??
                            _order['amount'],
                      ),
                      strong: true,
                    ),
                  ],
                ),
              ),
            ),
            if (paymentEntries.isNotEmpty ||
                paymentMethod.isNotEmpty ||
                pix.isNotEmpty ||
                boleto.isNotEmpty ||
                boletoUrl.isNotEmpty ||
                _firstText(_order, const [
                  'payment_status',
                  'status_pagamento',
                  'situacao_financeira',
                ]).isNotEmpty) ...[
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const LText(
                        'Como foi pago',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (paymentEntries.isNotEmpty)
                        ...paymentEntries.map(
                          (entry) => _PaymentEntryView(entry: entry),
                        )
                      else if (paymentMethod.isNotEmpty)
                        LText(
                          paymentMethod,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      if (_firstText(_order, const [
                        'payment_status',
                        'status_pagamento',
                        'situacao_financeira',
                      ]).isNotEmpty) ...[
                        const SizedBox(height: 6),
                        LText(
                          'Situação: ${_friendlyPaymentStatus(_firstText(_order, const [
                                'payment_status',
                                'status_pagamento',
                                'situacao_financeira'
                              ]))}',
                        ),
                      ],
                      if (pix.isNotEmpty) ...[
                        const Divider(height: 24),
                        const LText(
                          'PIX copia e cola',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        SelectableText(pix),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _copy(context, pix, 'Código PIX copiado.'),
                          icon: const Icon(Icons.copy),
                          label: const LText('Copiar PIX'),
                        ),
                      ],
                      if (boleto.isNotEmpty) ...[
                        const Divider(height: 24),
                        const LText(
                          'Código do boleto',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        SelectableText(boleto),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _copy(
                            context,
                            boleto,
                            'Código do boleto copiado.',
                          ),
                          icon: const Icon(Icons.copy),
                          label: const LText('Copiar código'),
                        ),
                      ],
                      if (boletoUrl.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _openExternal(boletoUrl),
                          icon: const Icon(Icons.open_in_new),
                          label: const LText('Abrir boleto'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RepeatOrderLine {
  const _RepeatOrderLine({
    required this.product,
    required this.quantityVisual,
    required this.quantityReal,
    required this.quantityMultiplier,
    required this.selectedVariationIds,
    required this.numberValues,
    required this.observation,
    required this.observationSummary,
  });
  final StoreProduct product;
  final double quantityVisual;
  final double quantityReal;
  final double? quantityMultiplier;
  final List<int> selectedVariationIds;
  final Map<String, double> numberValues;
  final String observation;
  final String observationSummary;
}

class _PaymentEntryView extends StatelessWidget {
  const _PaymentEntryView({required this.entry});
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final method = _paymentEntryLabel(entry);
    final status = _firstText(entry, const [
      'status',
      'payment_status',
      'situacao',
    ]);
    final provider = _firstText(entry, const [
      'provider',
      'gateway',
      'hub',
      'acquirer',
    ]);
    final brand = _firstText(entry, const ['brand', 'card_brand', 'bandeira']);
    final installments =
        int.tryParse(_firstText(entry, const ['installments', 'parcelas'])) ??
            0;
    final amount = numberValue(
      entry['amount'] ?? entry['value'] ?? entry['valor'],
    );
    final details = <String>[
      if (provider.isNotEmpty &&
          !method.toLowerCase().contains(provider.toLowerCase()))
        provider,
      if (brand.isNotEmpty) brand,
      if (installments > 0) '${installments}x',
      if (status.isNotEmpty) _friendlyPaymentStatus(status),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.payments_outlined, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LText(
                  method.isEmpty ? 'Pagamento' : method,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (details.isNotEmpty)
                  LText(
                    details.join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (amount > 0)
            LText(
              _money(amount),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
        ],
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({
    required this.status,
    required this.code,
    required this.url,
    required this.events,
    this.onOpenUrl,
  });
  final String status;
  final String code;
  final String url;
  final List<Map<String, dynamic>> events;
  final VoidCallback? onOpenUrl;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.local_shipping_outlined),
                  SizedBox(width: 8),
                  LText(
                    'Rastreio do pedido',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              LText(status,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              if (code.isNotEmpty) ...[
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(child: SelectableText(tr('Código: $code'))),
                    IconButton(
                      tooltip: tr('Copiar código'),
                      onPressed: () =>
                          _copy(context, code, 'Código de rastreio copiado.'),
                      icon: const Icon(Icons.copy, size: 19),
                    ),
                  ],
                ),
              ],
              if (events.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...events.take(6).map((event) {
                  final title = _firstText(
                      event,
                      const [
                        'title',
                        'status',
                        'description',
                        'descricao',
                      ],
                      fallback: 'Atualização');
                  final date = _firstText(event, const [
                    'created_at',
                    'date',
                    'data',
                    'datetime',
                  ]);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Icon(Icons.circle, size: 8),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LText(
                            date.isEmpty
                                ? title
                                : '$title\n${_formatDate(date)}',
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ] else ...[
                const SizedBox(height: 5),
                LText(
                  'Puxe a tela para baixo para atualizar o andamento. Quando houver código ou link da transportadora, ele aparece aqui.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (onOpenUrl != null) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: onOpenUrl,
                  icon: const Icon(Icons.open_in_new),
                  label: const LText('Acompanhar rastreio'),
                ),
              ],
            ],
          ),
        ),
      );
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({
    super.key,
    required this.repository,
    required this.cart,
  });
  final StoreRepository repository;
  final CartController cart;
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  bool _loading = true;
  String? _error;
  List<StoreProduct> _products = const [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final p = await widget.repository.favorites();
      if (mounted) setState(() => _products = p);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const LText('Favoritos')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(message: _error!, retry: _load)
                : _products.isEmpty
                    ? const _EmptyView(
                        icon: Icons.favorite_border,
                        text: 'Nenhum produto favorito.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _products.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final p = _products[i];
                            return Card(
                              child: ListTile(
                                leading: SizedBox(
                                  width: 54,
                                  height: 54,
                                  child: p.imageUrl == null
                                      ? const Icon(Icons.image_outlined)
                                      : Image.network(
                                          widget.repository.api
                                                  .resolvePublicUrl(
                                                p.imageUrl,
                                              ) ??
                                              p.imageUrl!,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                            Icons.image_not_supported_outlined,
                                          ),
                                        ),
                                ),
                                title: LText(
                                  p.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                                subtitle: LText(_money(p.price)),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailPage(
                                      product: p,
                                      repository: widget.repository,
                                      cart: widget.cart,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      );
}

class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key, required this.repository});
  final StoreRepository repository;

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _addresses = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final addresses = await widget.repository.accountAddresses();
      if (mounted) setState(() => _addresses = addresses);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? address]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) =>
            AddressEditPage(repository: widget.repository, address: address)));
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: LText('Endereço salvo.')));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const LText('Meus Endereços')),
        floatingActionButton: FloatingActionButton(
            tooltip: tr('Adicionar endereço'),
            onPressed: () => _edit(),
            child: const Icon(Icons.add)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(message: _error!, retry: _load)
                : _addresses.isEmpty
                    ? const _EmptyView(
                        icon: Icons.location_on_outlined,
                        text: 'Nenhum endereço cadastrado.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                          itemCount: _addresses.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final address = _addresses[i];
                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(14),
                                leading: Icon(
                                  boolValue(address['is_default'])
                                      ? Icons.home
                                      : Icons.location_on_outlined,
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: LText(
                                        stringValue(address['label'],
                                            fallback: 'Endereço'),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: LText(_addressLine(address)),
                                trailing: IconButton(
                                    tooltip: tr('Editar endereço'),
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _edit(address)),
                                onTap: () => _edit(address),
                              ),
                            );
                          },
                        ),
                      ),
      );
}

class _InlineWarningCard extends StatelessWidget {
  const _InlineWarningCard({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: LText(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  onRetry();
                },
                child: const LText('Atualizar'),
              ),
            ],
          ),
        ),
      );
}

class _DetailTextLine extends StatelessWidget {
  const _DetailTextLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 105,
              child: LText(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: LText(value)),
          ],
        ),
      );
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.label, this.value, {this.strong = false});
  final String label;
  final double value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: LText(
                label,
                style: strong
                    ? const TextStyle(fontWeight: FontWeight.w900)
                    : null,
              ),
            ),
            LText(
              _money(value),
              style: strong
                  ? const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)
                  : const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.retry});
  final String message;
  final Future<void> Function() retry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 10),
              LText(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  retry();
                },
                icon: const Icon(Icons.refresh),
                label: const LText('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 54,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              LText(text, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

String _firstText(
  Map<String, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = map[key];
    if (value == null || value is Map || value is List) continue;
    final text = stringValue(value).trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

int _orderId(Map<String, dynamic> order) {
  for (final key in const ['id', 'order_id', 'pedido_id', 'venda_id']) {
    final value = int.tryParse('${order[key] ?? ''}');
    if (value != null && value > 0) return value;
  }
  return 0;
}

List<Map<String, dynamic>> _orderItems(Map<String, dynamic> order) {
  for (final raw in <dynamic>[
    order['items'],
    order['itens'],
    order['order_items'],
    order['pedido_itens'],
    order['lines'],
    order['linhas'],
    order['products'],
    order['produtos'],
  ]) {
    final list = listValue(raw);
    if (list.isNotEmpty) return list;
  }
  return const <Map<String, dynamic>>[];
}

Map<String, dynamic> _orderDeliveryData(Map<String, dynamic> order) {
  for (final raw in <dynamic>[
    order['delivery'],
    order['address'],
    order['endereco'],
    order['entrega'],
  ]) {
    final value = mapValue(raw);
    if (value.isNotEmpty) return value;
  }
  return const <String, dynamic>{};
}

String _orderAddressLine(Map<String, dynamic> address) {
  final street = _firstText(address, const [
    'street',
    'endereco',
    'logradouro',
    'address',
  ]);
  final number = _firstText(address, const ['number', 'numero']);
  final complement = _firstText(address, const ['complement', 'complemento']);
  final district = _firstText(address, const ['district', 'bairro']);
  final city = _firstText(address, const ['city', 'cidade']);
  final state = _firstText(address, const ['state', 'uf']);
  final parts = <String>[];
  if (street.isNotEmpty)
    parts.add(number.isEmpty ? street : '$street, $number');
  if (complement.isNotEmpty) parts.add(complement);
  if (district.isNotEmpty) parts.add(district);
  if (city.isNotEmpty) parts.add(state.isEmpty ? city : '$city/$state');
  final zip = _firstText(address, const ['zip', 'cep']);
  if (zip.isNotEmpty) parts.add('CEP $zip');
  return parts.join(' - ');
}

String _friendlyReceiptType(String value) {
  switch (value.trim().toUpperCase()) {
    case 'RETIRADA':
    case 'PICKUP':
      return 'Retirada na loja';
    case 'ENTREGA':
    case 'DELIVERY':
      return 'Entrega';
    default:
      return value;
  }
}

List<int> _intList(dynamic raw) {
  final out = <int>[];
  if (raw is List) {
    for (final value in raw) {
      final id = int.tryParse(value.toString());
      if (id != null && id > 0 && !out.contains(id)) out.add(id);
    }
  } else if (raw != null) {
    for (final part in raw.toString().split(RegExp(r'[,;|\s]+'))) {
      final id = int.tryParse(part);
      if (id != null && id > 0 && !out.contains(id)) out.add(id);
    }
  }
  return out;
}

Map<String, double> _numberMap(dynamic raw) {
  final out = <String, double>{};
  if (raw is Map) {
    raw.forEach((key, value) {
      final parsed = double.tryParse(value.toString().replaceAll(',', '.'));
      if (parsed != null) out[key.toString()] = parsed;
    });
  }
  return out;
}

Map<String, dynamic> _trackingData(Map<String, dynamic> order) {
  final nested = mapValue(
    order['tracking'] ?? order['rastreio'] ?? order['delivery_tracking'],
  );
  if (nested.isNotEmpty) return nested;
  return <String, dynamic>{
    'code': _firstText(order, const [
      'tracking_code',
      'codigo_rastreio',
      'rastreio_codigo',
    ]),
    'url': _firstText(order, const [
      'tracking_url',
      'rastreio_url',
      'tracking_link',
    ]),
    'events': order['tracking_events'] ??
        order['timeline'] ??
        order['history'] ??
        order['historico'],
  };
}

List<Map<String, dynamic>> _paymentEntries(
  Map<String, dynamic> order,
  Map<String, dynamic> payment,
) {
  final candidates = [
    payment['payments'],
    payment['methods'],
    payment['payment_methods'],
    order['payments'],
    order['pagamentos'],
    order['payment_methods'],
  ];
  for (final raw in candidates) {
    final list = listValue(raw);
    if (list.isNotEmpty) return list;
  }
  if (payment.isNotEmpty) return [payment];
  final method = _paymentMethodSummary(order);
  if (method.isEmpty) return const [];
  return [
    <String, dynamic>{
      'name': method,
      'status': order['payment_status'],
      'amount': order['total'],
    },
  ];
}

String _paymentEntryLabel(Map<String, dynamic> entry) {
  final nestedMethod = mapValue(entry['method'] ?? entry['payment_method']);
  final nestedName = _firstText(nestedMethod, const [
    'name',
    'label',
    'description',
    'type',
  ]);
  if (nestedName.isNotEmpty) return nestedName;
  return _firstText(entry, const [
    'name',
    'method_name',
    'payment_name',
    'payment_method_name',
    'payment_method',
    'method',
    'type',
    'payment_type',
    'forma_pagamento',
    'descricao',
  ]);
}

String _paymentMethodSummary(Map<String, dynamic> order) {
  final payment = mapValue(order['payment'] ?? order['pagamento']);
  final entries = _paymentEntriesShallow(order, payment);
  final names = <String>[];
  for (final entry in entries) {
    final name = _paymentEntryLabel(entry);
    if (name.isNotEmpty && !names.contains(name)) names.add(name);
  }
  if (names.isNotEmpty) return names.join(' + ');
  return _firstText(order, const [
    'payment_method_name',
    'payment_method',
    'payment_name',
    'forma_pagamento',
    'forma_pagamento_nome',
    'payment_type',
  ]);
}

List<Map<String, dynamic>> _paymentEntriesShallow(
  Map<String, dynamic> order,
  Map<String, dynamic> payment,
) {
  for (final raw in [
    payment['payments'],
    payment['methods'],
    payment['payment_methods'],
    payment['pagamentos'],
    order['payments'],
    order['pagamentos'],
    order['payment_methods'],
  ]) {
    final list = listValue(raw);
    if (list.isNotEmpty) return list;
  }
  if (payment.isNotEmpty) return [payment];
  return const [];
}

void _copy(BuildContext context, String value, String message) {
  Clipboard.setData(ClipboardData(text: value));
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: LText(message)));
}

String _addressLine(Map<String, dynamic> a) => [
      [stringValue(a['street']), stringValue(a['number'])]
          .where((v) => v.isNotEmpty)
          .join(', '),
      stringValue(a['complement']),
      stringValue(a['district']),
      [stringValue(a['city']), stringValue(a['state'])]
          .where((v) => v.isNotEmpty)
          .join('/'),
      stringValue(a['zip']).isEmpty ? '' : 'CEP ${stringValue(a['zip'])}',
    ].where((v) => v.isNotEmpty).join(' - ');

String _formatDate(dynamic raw) {
  final text = stringValue(raw);
  if (text.isEmpty) return '';
  final value = DateTime.tryParse(text);
  if (value == null) return text;
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

String _friendlyPaymentStatus(String v) {
  switch (v.toUpperCase()) {
    case 'PAGO':
      return 'Pago';
    case 'PENDENTE':
      return 'Pendente';
    case 'RECUSADO':
      return 'Recusado';
    case 'CANCELADO':
      return 'Cancelado';
    case 'NAO_APLICAVEL':
      return 'Pagamento na entrega/retirada';
    default:
      return v;
  }
}

String _money(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
