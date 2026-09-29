import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../cart/cart_controller.dart';
import 'product_detail_page.dart';
import 'store_models.dart';
import 'store_repository.dart';

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
  const OrdersPage({super.key, required this.repository});
  final StoreRepository repository;

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
    if (mounted) setState(() { _loading = true; _error = null; });
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
    final raw = stringValue(order['status']).toLowerCase();
    if ({4, 7, 10}.contains(id) || raw.contains('cancel') || raw.contains('recus') || raw.contains('falha')) return _OrderFilter.cancelled;
    if ({3, 9}.contains(id) || raw.contains('conclu') || raw.contains('fatur') || raw.contains('entregue') || raw.contains('finaliz')) return _OrderFilter.finished;
    if (id == 1 || raw.contains('pend') || raw.contains('aguard') || raw.contains('novo') || raw.contains('receb')) return _OrderFilter.pending;
    return _OrderFilter.inProgress;
  }

  List<Map<String, dynamic>> get _visibleOrders {
    final q = _search.text.trim().toLowerCase();
    return _orders.where((order) {
      if (_filter != _OrderFilter.all && _group(order) != _filter) return false;
      if (q.isEmpty) return true;
      final number = stringValue(order['number'], fallback: '${order['id'] ?? ''}').toLowerCase();
      final status = stringValue(order['status']).toLowerCase();
      return number.contains(q) || status.contains(q);
    }).toList(growable: false);
  }

  Color _statusColor(BuildContext context, Map<String, dynamic> order) {
    final parsed = AppTheme.parseColor(stringValue(order['status_color']));
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

  int _count(_OrderFilter filter) => filter == _OrderFilter.all ? _orders.length : _orders.where((o) => _group(o) == filter).length;

  @override
  Widget build(BuildContext context) {
    final visible = _visibleOrders;
    return Scaffold(
      appBar: AppBar(title: const Text('Meus pedidos')),
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
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Buscar pedido ou status',
                          suffixIcon: _search.text.isEmpty ? null : IconButton(onPressed: () { _search.clear(); setState(() {}); }, icon: const Icon(Icons.close)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _OrderFilter.values.map((filter) => Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: ChoiceChip(
                              selected: _filter == filter,
                              onSelected: (_) => setState(() => _filter = filter),
                              label: Text('${filter.label} (${_count(filter)})'),
                            ),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_orders.isEmpty)
                        const Padding(padding: EdgeInsets.symmetric(vertical: 70), child: Center(child: Text('Você ainda não possui pedidos.')))
                      else if (visible.isEmpty)
                        const Padding(padding: EdgeInsets.symmetric(vertical: 50), child: Center(child: Text('Nenhum pedido neste filtro.')))
                      else
                        ...visible.map((order) {
                          final number = stringValue(order['number'], fallback: '${order['id'] ?? ''}');
                          final status = stringValue(order['status'], fallback: 'Pedido recebido');
                          final paymentStatus = stringValue(order['payment_status']);
                          final color = _statusColor(context, order);
                          final onColor = color.computeLuminance() > .50 ? Colors.black : Colors.white;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              margin: EdgeInsets.zero,
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailPage(repository: widget.repository, orderId: int.tryParse('${order['id']}') ?? 0))),
                                child: Row(
                                  children: [
                                    Container(width: 6, height: 120, color: color),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(13),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Expanded(child: Text('Pedido #$number', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                                              Text(_money(numberValue(order['total'])), style: const TextStyle(fontWeight: FontWeight.w900)),
                                            ]),
                                            const SizedBox(height: 7),
                                            Wrap(spacing: 7, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                              Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)), child: Text(status, style: TextStyle(color: onColor, fontSize: 11, fontWeight: FontWeight.w800))),
                                              if (paymentStatus.isNotEmpty) Text('Pagamento: ${_friendlyPaymentStatus(paymentStatus)}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                            ]),
                                            const SizedBox(height: 7),
                                            Row(children: [
                                              Icon(Icons.schedule, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                              const SizedBox(width: 4),
                                              Expanded(child: Text(_formatDate(order['created_at']), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                                              const Icon(Icons.chevron_right),
                                            ]),
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
  const OrderDetailPage({super.key, required this.repository, required this.orderId});
  final StoreRepository repository;
  final int orderId;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _order = const {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final order = await widget.repository.orderDetail(widget.orderId);
      if (mounted) setState(() => _order = order);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(appBar: AppBar(title: const Text('Pedido')), body: const Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Pedido')), body: _ErrorView(message: _error!, retry: _load));
    final items = listValue(_order['items']);
    final payment = mapValue(_order['payment']);
    final pix = stringValue(payment['pix_code']);
    final boleto = stringValue(payment['boleto_barcode']);
    final boletoUrl = stringValue(payment['boleto_url']);
    final number = stringValue(_order['number'], fallback: '${_order['id'] ?? ''}');
    final statusColor = AppTheme.parseColor(stringValue(_order['status_color'])) ?? Theme.of(context).colorScheme.primary;
    final statusTextColor = statusColor.computeLuminance() > .50 ? Colors.black : Colors.white;
    return Scaffold(
      appBar: AppBar(title: Text('Pedido #$number')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(width: 6, color: statusColor),
                Expanded(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(99)), child: Text(stringValue(_order['status'], fallback: 'Pedido recebido'), style: TextStyle(color: statusTextColor, fontWeight: FontWeight.w900))),
              const SizedBox(height: 8),
              Text('Realizado em ${_formatDate(_order['created_at'])}'),
              if (stringValue(_order['scheduled_at']).isNotEmpty) Text('Previsão: ${_formatDate(_order['scheduled_at'])}'),
              if (stringValue(_order['payment_status']).isNotEmpty) Text('Pagamento: ${_friendlyPaymentStatus(stringValue(_order['payment_status']))}'),
            ]))),
              ]),
            ),
            const SizedBox(height: 10),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Itens', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 8),
              ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(stringValue(item['name'], fallback: 'Produto'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${formatQuantity(numberValue(item['quantity']), 3)} × ${_money(numberValue(item['unit_price']))}'),
                    if (stringValue(item['complement']).isNotEmpty) Text(stringValue(item['complement']), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ])),
                  Text(_money(numberValue(item['total'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              )),
            ]))),
            const SizedBox(height: 10),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              _SummaryLine('Produtos', numberValue(_order['subtotal'])),
              _SummaryLine('Frete', numberValue(_order['freight'])),
              if (numberValue(_order['discount']) > 0) _SummaryLine('Desconto', -numberValue(_order['discount'])),
              const Divider(),
              _SummaryLine('Total', numberValue(_order['total']), strong: true),
            ]))),
            if (pix.isNotEmpty || boleto.isNotEmpty || boletoUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Pagamento', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                if (pix.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('PIX copia e cola'),
                  const SizedBox(height: 5),
                  SelectableText(pix),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: () => _copy(context, pix, 'Código PIX copiado.'), icon: const Icon(Icons.copy), label: const Text('Copiar PIX')),
                ],
                if (boleto.isNotEmpty) ...[
                  const SizedBox(height: 8), const Text('Código do boleto'), const SizedBox(height: 5), SelectableText(boleto),
                  const SizedBox(height: 8), OutlinedButton.icon(onPressed: () => _copy(context, boleto, 'Código do boleto copiado.'), icon: const Icon(Icons.copy), label: const Text('Copiar código')),
                ],
                if (boletoUrl.isNotEmpty) ...[const SizedBox(height: 6), SelectableText(boletoUrl)],
              ]))),
            ],
          ],
        ),
      ),
    );
  }
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key, required this.repository, required this.cart});
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
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try { final p = await widget.repository.favorites(); if (mounted) setState(() => _products = p); }
    catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Favoritos')),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : _error != null ? _ErrorView(message: _error!, retry: _load)
      : _products.isEmpty ? const _EmptyView(icon: Icons.favorite_border, text: 'Nenhum produto favorito.')
      : RefreshIndicator(onRefresh: _load, child: ListView.separated(
          padding: const EdgeInsets.all(16), itemCount: _products.length, separatorBuilder: (_,__) => const SizedBox(height: 8),
          itemBuilder: (_,i) { final p=_products[i]; return Card(child: ListTile(
            leading: SizedBox(width: 54,height:54, child: p.imageUrl==null ? const Icon(Icons.image_outlined) : Image.network(widget.repository.api.resolvePublicUrl(p.imageUrl) ?? p.imageUrl!, fit: BoxFit.contain, errorBuilder: (_,__,___)=>const Icon(Icons.image_not_supported_outlined))),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(_money(p.price)),
            trailing: const Icon(Icons.chevron_right),
            onTap: ()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>ProductDetailPage(product:p,repository:widget.repository,cart:widget.cart))),
          )); },
        )),
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
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final addresses = await widget.repository.accountAddresses();
      if (mounted) setState(() => _addresses = addresses);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Meus endereços')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(message: _error!, retry: _load)
                : _addresses.isEmpty
                    ? const _EmptyView(icon: Icons.location_on_outlined, text: 'Nenhum endereço cadastrado.')
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _addresses.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final address = _addresses[i];
                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(14),
                                leading: Icon(boolValue(address['is_default']) ? Icons.home : Icons.location_on_outlined),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        stringValue(address['label'], fallback: 'Endereço'),
                                        style: const TextStyle(fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                    if (boolValue(address['is_default'])) const Chip(label: Text('Padrão')),
                                  ],
                                ),
                                subtitle: Text(_addressLine(address)),
                              ),
                            );
                          },
                        ),
                      ),
      );
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.label,this.value,{this.strong=false}); final String label; final double value; final bool strong;
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[Expanded(child:Text(label,style:strong?const TextStyle(fontWeight:FontWeight.w900):null)),Text(_money(value),style:strong?const TextStyle(fontSize:18,fontWeight:FontWeight.w900):const TextStyle(fontWeight:FontWeight.w700))]));
}
class _ErrorView extends StatelessWidget { const _ErrorView({required this.message,required this.retry}); final String message; final Future<void> Function() retry; @override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.error_outline,size:48),const SizedBox(height:10),Text(message,textAlign:TextAlign.center),const SizedBox(height:12),FilledButton.icon(onPressed:(){ retry(); },icon:const Icon(Icons.refresh),label:const Text('Tentar novamente'))]))); }
class _EmptyView extends StatelessWidget { const _EmptyView({required this.icon,required this.text}); final IconData icon; final String text; @override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(32),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:54,color:Theme.of(context).colorScheme.onSurfaceVariant),const SizedBox(height:12),Text(text,textAlign:TextAlign.center)]))); }

void _copy(BuildContext context,String value,String message){ Clipboard.setData(ClipboardData(text:value)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message))); }
String _addressLine(Map<String,dynamic> a){final street=stringValue(a['street']);final number=stringValue(a['number']);final district=stringValue(a['district']);final city=stringValue(a['city']);final state=stringValue(a['state']);return '$street${number.isEmpty?'':', $number'}${district.isEmpty?'':' - $district'}${city.isEmpty?'':' - $city/$state'}';}
String _formatDate(dynamic raw){final text=stringValue(raw);if(text.isEmpty)return '';final value=DateTime.tryParse(text);if(value==null)return text;return '${value.day.toString().padLeft(2,'0')}/${value.month.toString().padLeft(2,'0')}/${value.year} ${value.hour.toString().padLeft(2,'0')}:${value.minute.toString().padLeft(2,'0')}';}
String _friendlyPaymentStatus(String v){switch(v.toUpperCase()){case'PAGO':return'Pago';case'PENDENTE':return'Pendente';case'RECUSADO':return'Recusado';case'CANCELADO':return'Cancelado';case'NAO_APLICAVEL':return'Pagamento na entrega/retirada';default:return v;}}
String _money(double v)=>'R\$ ${v.toStringAsFixed(2).replaceAll('.',',')}';
