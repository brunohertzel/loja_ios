import '../../core/network/api_client.dart';
import '../auth/auth_repository.dart';
import 'store_models.dart';

class StoreProductsPage {
  const StoreProductsPage({
    required this.products,
    required this.page,
    required this.limit,
    required this.hasMore,
  });

  final List<StoreProduct> products;
  final int page;
  final int limit;
  final bool hasMore;
}

class StoreRepository {
  StoreRepository(this.api, {this.auth});
  final ApiClient api;
  final AuthRepository? auth;

  Future<Map<String, dynamic>> careGet(String path) =>
      _authenticated(() => api.get(path));
  Future<Map<String, dynamic>> carePost(
    String path,
    Map<String, dynamic> body,
  ) =>
      _authenticated(() => api.post(path, body));

  Future<T> _authenticated<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException catch (e) {
      if (!e.isUnauthorized || auth == null) rethrow;
      final ok = await auth!.refresh();
      if (!ok) {
        // O servidor confirmou que o refresh expirou/revogou. Somente nesse
        // caso limpamos a sessao e permitimos que a UI solicite novo login.
        await auth!.store.clearSession();
        rethrow;
      }
      // Aguarda a repeticao para que um eventual segundo 401 seja entregue
      // corretamente ao checkout, sem corrida entre gravacao e leitura do token.
      return await action();
    }
  }

  Future<StoreHomeData> home({
    StoreProductSort sort = StoreProductSort.standard,
  }) async {
    final qs = Uri(queryParameters: {'sort': sort.apiValue}).query;
    final json = await _authenticated(() => api.get('/store/home.php?$qs'));
    return StoreHomeData.fromJson(json);
  }

  Future<List<StoreCategory>> categories() async {
    final json = await _authenticated(() => api.get('/store/categories.php'));
    final data = json['categories'] ?? json['categorias'] ?? json['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(
          (e) => StoreCategory.fromJson(
            e.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  Future<StoreProductsPage> productsPage({
    String? query,
    String? categoryId,
    int page = 1,
    int limit = 20,
    StoreProductSort sort = StoreProductSort.standard,
    bool offersOnly = false,
    int? campaignId,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit < 1 ? 1 : (limit > 100 ? 100 : limit);
    final params = <String, String>{
      'page': '$safePage',
      'limit': '$safeLimit',
      'sort': sort.apiValue,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (categoryId != null && categoryId.trim().isNotEmpty)
        'category_id': categoryId.trim(),
      if (offersOnly) 'offers_only': '1',
      if (campaignId != null && campaignId > 0) 'campaign_id': '$campaignId',
    };
    final qs = Uri(queryParameters: params).query;
    final json = await _authenticated(() => api.get('/store/products.php?$qs'));
    final data = json['products'] ?? json['produtos'] ?? json['data'];
    final products = data is! List
        ? const <StoreProduct>[]
        : data
            .whereType<Map>()
            .map(
              (e) => StoreProduct.fromJson(
                e.map((key, value) => MapEntry(key.toString(), value)),
              ),
            )
            .toList(growable: false);
    return StoreProductsPage(
      products: products,
      page: numberValue(json['page'], fallback: safePage.toDouble()).toInt(),
      limit: numberValue(json['limit'], fallback: safeLimit.toDouble()).toInt(),
      hasMore: boolValue(json['has_more']),
    );
  }

  Future<List<StoreProduct>> products({
    String? query,
    String? categoryId,
    int page = 1,
    int limit = 20,
    StoreProductSort sort = StoreProductSort.standard,
  }) async {
    final result = await productsPage(
      query: query,
      categoryId: categoryId,
      page: page,
      limit: limit,
      sort: sort,
    );
    return result.products;
  }

  Future<Map<String, dynamic>> checkoutPrepare(
    List<Map<String, dynamic>> items, {
    String? addressId,
    String receiptType = 'ENTREGA',
  }) =>
      _authenticated(
        () => api.post('/checkout/prepare.php', <String, dynamic>{
          'items': items,
          'receipt_type': receiptType,
          if (addressId != null) 'address_id': addressId,
        }),
      );

  Future<Map<String, dynamic>> checkoutFreight(
    List<Map<String, dynamic>> items, {
    required String addressId,
    required String receiptType,
  }) =>
      _authenticated(
        () => api.post('/checkout/freight.php', <String, dynamic>{
          'items': items,
          'address_id': addressId,
          'receipt_type': receiptType,
        }),
      );

  Future<Map<String, dynamic>> checkoutCoupon(
    List<Map<String, dynamic>> items, {
    required String code,
    required String addressId,
    required String receiptType,
  }) =>
      _authenticated(
        () => api.post('/checkout/coupon.php', <String, dynamic>{
          'items': items,
          'code': code,
          'address_id': addressId,
          'receipt_type': receiptType,
        }),
      );

  Future<Map<String, dynamic>> checkoutSubmit(
    List<Map<String, dynamic>> items, {
    required String addressId,
    required String receiptType,
    required String scheduleDate,
    required String paymentId,
    String? paymentTerm,
    String? couponCode,
    String? notes,
    bool needsChange = false,
    double? changeFor,
    String? cardToken,
    int? installments,
    String? paymentMethodId,
    String? paymentTypeId,
    String? walletToken,
    required String idempotencyKey,
  }) =>
      _authenticated(
        () => api.post('/checkout/submit.php', <String, dynamic>{
          'items': items,
          'address_id': addressId,
          'receipt_type': receiptType,
          'schedule_date': scheduleDate,
          'payment_id': paymentId,
          'idempotency_key': idempotencyKey,
          if (paymentTerm != null && paymentTerm.isNotEmpty)
            'payment_term': paymentTerm,
          if (couponCode != null && couponCode.isNotEmpty)
            'coupon_code': couponCode,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          'needs_change': needsChange,
          if (needsChange && changeFor != null) 'change_for': changeFor,
          if (cardToken != null && cardToken.isNotEmpty)
            'card_token': cardToken,
          if (installments != null && installments > 0)
            'installments': installments,
          if (paymentMethodId != null && paymentMethodId.isNotEmpty)
            'payment_method_id': paymentMethodId,
          if (paymentTypeId != null && paymentTypeId.isNotEmpty)
            'payment_type_id': paymentTypeId,
          if (walletToken != null && walletToken.isNotEmpty)
            'wallet_token': walletToken,
        }),
      );

  Future<List<Map<String, dynamic>>> orders() async {
    final json = await _authenticated(
      () => api.post('/profile.php', <String, dynamic>{'resource': 'orders'}),
    );
    final data = mapValue(json['data']);
    return listValue(
      json['orders'] ??
          json['pedidos'] ??
          (json['data'] is List ? json['data'] : null) ??
          data['orders'] ??
          data['pedidos'],
    );
  }

  Future<Map<String, dynamic>> orderDetail(int id) async {
    if (id <= 0) {
      throw const ApiException(
        'Identificador do pedido não informado.',
        code: 'ORDER_ID_MISSING',
      );
    }

    Map<String, dynamic> result = const <String, dynamic>{};
    Object? firstError;

    // Endpoint consolidado usado pelas versões atuais do módulo Mobile.
    try {
      final json = await _authenticated(
        () => api.post('/profile.php', <String, dynamic>{
          'resource': 'order_detail',
          'id': id,
          'order_id': id,
          'pedido_id': id,
        }),
      );
      result = _normalizeOrderDetailResponse(json);
    } catch (e) {
      firstError = e;
    }

    // Alguns clientes possuem o endpoint dedicado mesmo quando profile.php está
    // em uma revisão antiga. Também usamos este fallback quando o cabeçalho veio,
    // mas os itens ficaram vazios.
    if (result.isEmpty || _normalizedOrderItems(result).isEmpty) {
      try {
        final json = await _authenticated(
          () => api.get('/orders/detail.php?id=$id'),
        );
        final direct = _normalizeOrderDetailResponse(json);
        if (direct.isNotEmpty) result = _mergeOrderDetail(result, direct);
      } catch (e) {
        firstError ??= e;
      }
    }

    if (result.isNotEmpty) return result;
    if (firstError != null) throw firstError;
    throw const ApiException(
      'O servidor não retornou os detalhes do pedido.',
      code: 'ORDER_DETAIL_EMPTY',
    );
  }

  Future<List<Map<String, dynamic>>> accountAddresses() async {
    final json = await _authenticated(
      () =>
          api.post('/profile.php', <String, dynamic>{'resource': 'addresses'}),
    );
    return listValue(json['addresses']);
  }

  Future<void> saveAddress(Map<String, dynamic> address) async {
    await _authenticated(() => api.post('/profile.php', {
          ...address,
          'resource': 'address_save',
        }));
  }

  Future<List<StoreProduct>> favorites() async {
    final json = await _authenticated(
      () =>
          api.post('/profile.php', <String, dynamic>{'resource': 'favorites'}),
    );
    return listValue(json['products']).map(StoreProduct.fromJson).toList();
  }

  Future<bool> toggleFavorite(String productId) async {
    final json = await _authenticated(
      () => api.post('/profile.php', <String, dynamic>{
        'resource': 'toggle_favorite',
        'product_id': int.tryParse(productId) ?? productId,
      }),
    );
    return boolValue(json['favorite']);
  }

  Future<Map<String, dynamic>> accountProfile() async {
    final json = await _authenticated(
      () => api.post('/profile.php', <String, dynamic>{'resource': 'account'}),
    );
    return mapValue(json['profile']);
  }

  Future<String?> uploadProfilePhoto({
    required String imageBase64,
    required String mimeType,
  }) async {
    final json = await _authenticated(
      () => api.post('/profile.php', <String, dynamic>{
        'resource': 'profile_photo',
        'action': 'upload',
        'image_base64': imageBase64,
        'mime_type': mimeType,
      }),
    );
    return nullableString(json['photo_url']);
  }

  Future<void> deleteProfilePhoto() async {
    await _authenticated(
      () => api.post('/profile.php', <String, dynamic>{
        'resource': 'profile_photo',
        'action': 'delete',
      }),
    );
  }

  Future<List<Map<String, dynamic>>> serverCart() async {
    final json = await _authenticated(
      () => api.post('/profile.php', <String, dynamic>{'resource': 'cart'}),
    );
    return listValue(json['items']);
  }

  Future<List<Map<String, dynamic>>> syncServerCart(
    List<Map<String, dynamic>> items,
  ) async {
    final json = await _authenticated(
      () => api.post('/profile.php', <String, dynamic>{
        'resource': 'cart_sync',
        'items': items,
      }),
    );
    return listValue(json['items']);
  }

  Future<Map<String, dynamic>> notificationPreference(
          {bool? enabled, String? permission, String? language}) =>
      _authenticated(() => api.post('/profile.php', <String, dynamic>{
            'resource': 'notification_preference',
            if (enabled != null) 'enabled': enabled,
            if (permission != null) 'permission_status': permission,
            if (language != null) 'language_code': language,
          }));

  Future<Map<String, dynamic>> paymentStatus(int orderId) =>
      _authenticated(() => api.get('/payment/status.php?order_id=$orderId'));

  Future<StoreProduct?> productByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    final qs = Uri(queryParameters: <String, String>{'code': code}).query;
    try {
      final json = await _authenticated(
        () => api.get('/store/barcode.php?$qs'),
      );
      final raw = mapValue(
        json['product'] ?? mapValue(json['data'])['product'],
      );
      return raw.isEmpty ? null : StoreProduct.fromJson(raw);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<StoreProduct> product(String id) async {
    final qs = Uri(queryParameters: <String, String>{'id': id}).query;
    final json = await _authenticated(() => api.get('/store/product.php?$qs'));
    final data = json['product'] ?? json['produto'] ?? json['data'] ?? json;
    if (data is! Map) {
      throw const ApiException(
        'Produto não localizado.',
        code: 'PRODUCT_NOT_FOUND',
      );
    }
    return StoreProduct.fromJson(
      data.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}

Map<String, dynamic> _normalizeOrderDetailResponse(Map<String, dynamic> json) {
  final data = mapValue(json['data']);
  Map<String, dynamic> order = const <String, dynamic>{};

  for (final raw in <dynamic>[
    json['order'],
    json['pedido'],
    data['order'],
    data['pedido'],
  ]) {
    final mapped = mapValue(raw);
    if (mapped.isNotEmpty) {
      order = mapped;
      break;
    }
  }

  if (order.isEmpty) {
    for (final raw in <dynamic>[
      json['orders'],
      json['pedidos'],
      data['orders'],
      data['pedidos'],
      json['data'] is List ? json['data'] : null,
    ]) {
      final list = listValue(raw);
      if (list.isNotEmpty) {
        order = list.first;
        break;
      }
    }
  }

  if (order.isEmpty &&
      (json.containsKey('id') ||
          json.containsKey('order_id') ||
          json.containsKey('pedido_id'))) {
    order = Map<String, dynamic>.from(json);
  }
  if (order.isEmpty &&
      (data.containsKey('id') ||
          data.containsKey('order_id') ||
          data.containsKey('pedido_id'))) {
    order = Map<String, dynamic>.from(data);
  }
  if (order.isEmpty) return const <String, dynamic>{};

  final out = <String, dynamic>{};
  _mergeOrderScalars(out, json);
  _mergeOrderScalars(out, data);
  out.addAll(order);

  final totals = _firstNonEmptyMap(<dynamic>[
    order['totals'],
    order['totais'],
    data['totals'],
    data['totais'],
    json['totals'],
    json['totais'],
  ]);
  if (totals.isNotEmpty) {
    out['subtotal'] ??= totals['subtotal'] ??
        totals['products'] ??
        totals['produtos'] ??
        totals['valor_produtos'];
    out['freight'] ??=
        totals['freight'] ?? totals['frete'] ?? totals['valor_frete'];
    out['discount'] ??=
        totals['discount'] ?? totals['desconto'] ?? totals['valor_desconto'];
    out['total'] ??=
        totals['total'] ?? totals['amount'] ?? totals['valor_total'];
  }

  final items = _firstNonEmptyList(<dynamic>[
    order['items'],
    order['itens'],
    order['order_items'],
    order['pedido_itens'],
    order['lines'],
    order['linhas'],
    order['products'],
    order['produtos'],
    data['items'],
    data['itens'],
    data['order_items'],
    data['pedido_itens'],
    data['lines'],
    data['linhas'],
    data['products'],
    data['produtos'],
    json['items'],
    json['itens'],
    json['order_items'],
    json['pedido_itens'],
    json['lines'],
    json['linhas'],
    json['products'],
    json['produtos'],
  ]);
  if (items.isNotEmpty) out['items'] = items;

  final payment = _firstNonEmptyMap(<dynamic>[
    order['payment'],
    order['pagamento'],
    data['payment'],
    data['pagamento'],
    json['payment'],
    json['pagamento'],
  ]);
  if (payment.isNotEmpty) out['payment'] = payment;

  final tracking = _firstNonEmptyMap(<dynamic>[
    order['tracking'],
    order['rastreio'],
    order['delivery_tracking'],
    data['tracking'],
    data['rastreio'],
    data['delivery_tracking'],
    json['tracking'],
    json['rastreio'],
    json['delivery_tracking'],
  ]);
  if (tracking.isNotEmpty) out['tracking'] = tracking;

  final delivery = _firstNonEmptyMap(<dynamic>[
    order['delivery'],
    order['address'],
    order['endereco'],
    order['entrega'],
    data['delivery'],
    data['address'],
    data['endereco'],
    data['entrega'],
    json['delivery'],
    json['address'],
    json['endereco'],
    json['entrega'],
  ]);
  if (delivery.isNotEmpty) out['delivery'] = delivery;

  return out;
}

Map<String, dynamic> _mergeOrderDetail(
  Map<String, dynamic> base,
  Map<String, dynamic> extra,
) {
  final out = <String, dynamic>{...base, ...extra};
  final baseItems = _normalizedOrderItems(base);
  final extraItems = _normalizedOrderItems(extra);
  if (extraItems.isNotEmpty) {
    out['items'] = extraItems;
  } else if (baseItems.isNotEmpty) {
    out['items'] = baseItems;
  }
  for (final key in const ['payment', 'tracking', 'delivery']) {
    final a = mapValue(base[key]);
    final b = mapValue(extra[key]);
    if (a.isNotEmpty || b.isNotEmpty) out[key] = <String, dynamic>{...a, ...b};
  }
  return out;
}

void _mergeOrderScalars(
  Map<String, dynamic> target,
  Map<String, dynamic> source,
) {
  source.forEach((key, value) {
    if (const {
      'order',
      'pedido',
      'orders',
      'pedidos',
      'data',
      'items',
      'itens',
      'products',
      'produtos',
    }.contains(key)) return;
    if (value is Map || value is List) return;
    target[key] = value;
  });
}

List<Map<String, dynamic>> _normalizedOrderItems(Map<String, dynamic> order) =>
    _firstNonEmptyList(<dynamic>[
      order['items'],
      order['itens'],
      order['order_items'],
      order['pedido_itens'],
      order['lines'],
      order['linhas'],
      order['products'],
      order['produtos'],
    ]);

List<Map<String, dynamic>> _firstNonEmptyList(List<dynamic> candidates) {
  for (final raw in candidates) {
    final value = listValue(raw);
    if (value.isNotEmpty) return value;
  }
  return const <Map<String, dynamic>>[];
}

Map<String, dynamic> _firstNonEmptyMap(List<dynamic> candidates) {
  for (final raw in candidates) {
    final value = mapValue(raw);
    if (value.isNotEmpty) return value;
  }
  return const <String, dynamic>{};
}
