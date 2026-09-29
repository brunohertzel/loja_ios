import '../../core/network/api_client.dart';
import '../auth/auth_repository.dart';
import 'store_models.dart';

class StoreRepository {
  StoreRepository(this.api, {this.auth});
  final ApiClient api;
  final AuthRepository? auth;

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

  Future<StoreHomeData> home({StoreProductSort sort = StoreProductSort.standard}) async {
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
        .map((e) => StoreCategory.fromJson(
              e.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .toList();
  }

  Future<List<StoreProduct>> products({
    String? query,
    String? categoryId,
    int page = 1,
    StoreProductSort sort = StoreProductSort.standard,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'sort': sort.apiValue,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (categoryId != null && categoryId.trim().isNotEmpty)
        'category_id': categoryId.trim(),
    };
    final qs = Uri(queryParameters: params).query;
    final json = await _authenticated(() => api.get('/store/products.php?$qs'));
    final data = json['products'] ?? json['produtos'] ?? json['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => StoreProduct.fromJson(
              e.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .toList();
  }

  Future<Map<String, dynamic>> checkoutPrepare(
    List<Map<String, dynamic>> items, {
    String? addressId,
    String receiptType = 'ENTREGA',
  }) =>
      _authenticated(() => api.post('/checkout/prepare.php', <String, dynamic>{
        'items': items,
        'receipt_type': receiptType,
        if (addressId != null) 'address_id': addressId,
      }));

  Future<Map<String, dynamic>> checkoutFreight(
    List<Map<String, dynamic>> items, {
    required String addressId,
    required String receiptType,
  }) =>
      _authenticated(() => api.post('/checkout/freight.php', <String, dynamic>{
        'items': items,
        'address_id': addressId,
        'receipt_type': receiptType,
      }));

  Future<Map<String, dynamic>> checkoutCoupon(
    List<Map<String, dynamic>> items, {
    required String code,
    required String addressId,
    required String receiptType,
  }) =>
      _authenticated(() => api.post('/checkout/coupon.php', <String, dynamic>{
        'items': items,
        'code': code,
        'address_id': addressId,
        'receipt_type': receiptType,
      }));


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
      _authenticated(() => api.post('/checkout/submit.php', <String, dynamic>{
        'items': items,
        'address_id': addressId,
        'receipt_type': receiptType,
        'schedule_date': scheduleDate,
        'payment_id': paymentId,
        'idempotency_key': idempotencyKey,
        if (paymentTerm != null && paymentTerm.isNotEmpty) 'payment_term': paymentTerm,
        if (couponCode != null && couponCode.isNotEmpty) 'coupon_code': couponCode,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'needs_change': needsChange,
        if (needsChange && changeFor != null) 'change_for': changeFor,
        if (cardToken != null && cardToken.isNotEmpty) 'card_token': cardToken,
        if (installments != null && installments > 0) 'installments': installments,
        if (paymentMethodId != null && paymentMethodId.isNotEmpty) 'payment_method_id': paymentMethodId,
        if (paymentTypeId != null && paymentTypeId.isNotEmpty) 'payment_type_id': paymentTypeId,
        if (walletToken != null && walletToken.isNotEmpty) 'wallet_token': walletToken,
      }));

  Future<List<Map<String, dynamic>>> orders() async {
    final json = await _authenticated(() => api.post('/profile.php', <String, dynamic>{'resource': 'orders'}));
    return listValue(json['orders']);
  }

  Future<Map<String, dynamic>> orderDetail(int id) async {
    final json = await _authenticated(() => api.post('/profile.php', <String, dynamic>{'resource': 'order_detail', 'id': id}));
    return mapValue(json['order']);
  }

  Future<List<Map<String, dynamic>>> accountAddresses() async {
    final json = await _authenticated(() => api.post('/profile.php', <String, dynamic>{'resource': 'addresses'}));
    return listValue(json['addresses']);
  }

  Future<List<StoreProduct>> favorites() async {
    final json = await _authenticated(() => api.post('/profile.php', <String, dynamic>{'resource': 'favorites'}));
    return listValue(json['products']).map(StoreProduct.fromJson).toList();
  }

  Future<bool> toggleFavorite(String productId) async {
    final json = await _authenticated(() => api.post('/profile.php', <String, dynamic>{
      'resource': 'toggle_favorite',
      'product_id': int.tryParse(productId) ?? productId,
    }));
    return boolValue(json['favorite']);
  }



  Future<Map<String, dynamic>> accountProfile() async {
    final json = await _authenticated(() => api.post('/profile.php', <String, dynamic>{'resource': 'account'}));
    return mapValue(json['profile']);
  }

  Future<String?> uploadProfilePhoto({
    required String imageBase64,
    required String mimeType,
  }) async {
    final json = await _authenticated(() => api.post('/profile.php', <String, dynamic>{
      'resource': 'profile_photo',
      'action': 'upload',
      'image_base64': imageBase64,
      'mime_type': mimeType,
    }));
    return nullableString(json['photo_url']);
  }

  Future<void> deleteProfilePhoto() async {
    await _authenticated(() => api.post('/profile.php', <String, dynamic>{
      'resource': 'profile_photo',
      'action': 'delete',
    }));
  }

  Future<List<Map<String, dynamic>>> serverCart() async {
    final json = await _authenticated(() => api.post('/profile.php', <String, dynamic>{'resource': 'cart'}));
    return listValue(json['items']);
  }

  Future<List<Map<String, dynamic>>> syncServerCart(List<Map<String, dynamic>> items) async {
    final json = await _authenticated(() => api.post('/profile.php', <String, dynamic>{
      'resource': 'cart_sync',
      'items': items,
    }));
    return listValue(json['items']);
  }

  Future<bool> notificationPreference() async {
    final json = await _authenticated(() => api.post('/profile.php', <String, dynamic>{
      'resource': 'notification_preference',
    }));
    return boolValue(json['enabled']);
  }

  Future<bool> setNotificationPreference(bool enabled) async {
    final json = await _authenticated(() => api.post('/profile.php', <String, dynamic>{
      'resource': 'notification_preference',
      'enabled': enabled,
    }));
    return boolValue(json['enabled']);
  }

  Future<Map<String, dynamic>> paymentStatus(int orderId) =>
      _authenticated(() => api.get('/payment/status.php?order_id=$orderId'));

  Future<StoreProduct> product(String id) async {
    final qs = Uri(queryParameters: <String, String>{'id': id}).query;
    final json = await _authenticated(() => api.get('/store/product.php?$qs'));
    final data = json['product'] ?? json['produto'] ?? json['data'] ?? json;
    if (data is! Map) {
      throw const ApiException('Produto não localizado.', code: 'PRODUCT_NOT_FOUND');
    }
    return StoreProduct.fromJson(
      data.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}
