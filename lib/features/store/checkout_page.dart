import '../../core/localization/localized_widgets.dart';
import '../../core/config/platform_info.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pay/pay.dart';

import '../../core/config/generated_app_config.dart';
import '../../core/network/api_client.dart';
import '../cart/cart_controller.dart';
import 'store_models.dart';
import 'store_repository.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.repository,
    required this.cart,
    this.reauthenticate,
  });

  final StoreRepository repository;
  final CartController cart;
  final Future<bool> Function()? reauthenticate;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _couponController = TextEditingController();
  final _notesController = TextEditingController();
  final _changeForController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  bool _loading = true;
  bool _freightLoading = false;
  bool _couponLoading = false;
  bool _submitting = false;
  String? _error;
  String? _couponCode;
  String? _couponMessage;
  Map<String, dynamic> _data = <String, dynamic>{};
  String _receiptType = 'ENTREGA';
  String _addressId = 'principal';
  String? _paymentId;
  String? _paymentTerm;
  bool _needsChange = false;
  int _cardInstallments = 1;
  DateTime? _date;
  Map<String, dynamic>? _completed;
  late final String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _idempotencyKey =
        '${PlatformInfo.isIOS ? 'ios' : 'android'}-${DateTime.now().microsecondsSinceEpoch}';
    _prepare();
  }

  @override
  void dispose() {
    _couponController.dispose();
    _notesController.dispose();
    _changeForController.dispose();
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    super.dispose();
  }

  Future<void> _prepare({bool allowReauth = true}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final json = await widget.repository.checkoutPrepare(
        widget.cart.checkoutPayload(),
        addressId: _addressId,
        receiptType: _receiptType,
      );
      _data = mapValue(json['data']);
      _receiptType = stringValue(
        mapValue(_data['receipt'])['selected'],
        fallback: 'ENTREGA',
      );
      _addressId = stringValue(
        _data['selected_address_id'],
        fallback: 'principal',
      );
      final first = nullableString(mapValue(_data['schedule'])['first_date']);
      final firstDate = first == null
          ? DateTime.now()
          : DateTime.tryParse(first) ?? DateTime.now();
      if (_date == null || _date!.isBefore(firstDate)) _date = firstDate;
      final payments = listValue(_data['payment_methods']);
      final enabledPayments = payments
          .where(
            (p) =>
                _paymentLocallyEnabled(p) &&
                boolValue(p['mobile_enabled'], fallback: true),
          )
          .toList(growable: false);
      if (enabledPayments.isNotEmpty &&
          (_paymentId == null ||
              !enabledPayments.any(
                (p) => stringValue(p['id']) == _paymentId,
              ))) {
        _paymentId = stringValue(enabledPayments.first['id']);
      } else if (enabledPayments.isEmpty) {
        _paymentId = null;
      }
      if (_couponCode != null && _couponCode!.isNotEmpty) {
        await _applyCoupon(_couponCode!, silent: true);
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized && allowReauth && widget.reauthenticate != null) {
        final ok = await widget.reauthenticate!();
        if (ok && mounted) {
          await _prepare(allowReauth: false);
          return;
        }
      }
      _error = e.isUnauthorized
          ? 'Entre na sua conta para continuar a compra.'
          : e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _recalculateFreight({bool allowReauth = true}) async {
    if (mounted) setState(() => _freightLoading = true);
    try {
      final json = await widget.repository.checkoutFreight(
        widget.cart.checkoutPayload(),
        addressId: _addressId,
        receiptType: _receiptType,
      );
      final data = mapValue(json['data']);
      if (!mounted) return;
      setState(() {
        _data['freight'] = data['freight'];
        _data['summary'] = data['summary'];
        if (data['payment_methods'] != null)
          _data['payment_methods'] = data['payment_methods'];
      });
      if (_couponCode != null && _couponCode!.isNotEmpty) {
        await _applyCoupon(_couponCode!, silent: true);
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized && allowReauth && widget.reauthenticate != null) {
        final ok = await widget.reauthenticate!();
        if (ok && mounted) {
          await _recalculateFreight(allowReauth: false);
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: LText(
              e.isUnauthorized
                  ? 'Entre na sua conta para continuar.'
                  : e.message,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _freightLoading = false);
    }
  }

  Future<void> _applyCoupon(String rawCode, {bool silent = false}) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      if (!silent && mounted)
        setState(() => _couponMessage = 'Digite o código do cupom.');
      return;
    }
    if (mounted)
      setState(() {
        _couponLoading = true;
        if (!silent) _couponMessage = null;
      });
    try {
      final json = await widget.repository.checkoutCoupon(
        widget.cart.checkoutPayload(),
        code: code,
        addressId: _addressId,
        receiptType: _receiptType,
      );
      final data = mapValue(json['data']);
      if (!mounted) return;
      setState(() {
        _couponCode = code;
        _couponController.text = code;
        _couponMessage = stringValue(
          data['message'],
          fallback: 'Cupom aplicado.',
        );
        _data['summary'] = data['summary'];
        if (data['payment_methods'] != null)
          _data['payment_methods'] = data['payment_methods'];
        _data['coupon'] = data['coupon'];
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _couponCode = null;
        _data.remove('coupon');
        _couponMessage = e.message;
      });
    } finally {
      if (mounted) setState(() => _couponLoading = false);
    }
  }

  Future<void> _removeCoupon() async {
    setState(() {
      _couponCode = null;
      _couponMessage = null;
      _couponController.clear();
      _data.remove('coupon');
    });
    await _recalculateFreight();
  }

  Map<String, dynamic>? _selectedPayment(List<Map<String, dynamic>> payments) {
    if (_paymentId == null) return null;
    for (final payment in payments) {
      if (stringValue(payment['id']) == _paymentId) return payment;
    }
    return null;
  }

  Future<String> _tokenizePagarmeCard(Map<String, dynamic> payment) async {
    final publicKey = stringValue(payment['public_key']);
    if (publicKey.isEmpty) {
      throw const ApiException(
        'Public Key Pagar.me não configurada.',
        code: 'PAGARME_PUBLIC_KEY_MISSING',
      );
    }
    final number = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    final holder = _cardHolderController.text.trim();
    final expiry = _cardExpiryController.text.replaceAll(RegExp(r'\D'), '');
    final cvv = _cardCvvController.text.replaceAll(RegExp(r'\D'), '');
    if (number.length < 13 ||
        holder.isEmpty ||
        expiry.length != 4 ||
        cvv.length < 3) {
      throw const ApiException(
        'Confira os dados do cartão.',
        code: 'CARD_INVALID',
      );
    }
    final month = int.tryParse(expiry.substring(0, 2)) ?? 0;
    var year = int.tryParse(expiry.substring(2, 4)) ?? 0;
    if (month < 1 || month > 12)
      throw const ApiException(
        'Validade do cartão inválida.',
        code: 'CARD_EXPIRY_INVALID',
      );
    year += 2000;

    final uri = Uri.parse(
      'https://api.pagar.me/core/v5/tokens',
    ).replace(queryParameters: {'appId': publicKey});
    final response = await http
        .post(
          uri,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'type': 'card',
            'card': {
              'number': number,
              'holder_name': holder,
              'exp_month': month,
              'exp_year': year,
              'cvv': cvv,
            },
          }),
        )
        .timeout(const Duration(seconds: 25));
    Map<String, dynamic> data = <String, dynamic>{};
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map)
        data = decoded.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {}
    final token = stringValue(data['id']);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        token.isEmpty) {
      final message = stringValue(
        data['message'],
        fallback: 'Não foi possível validar o cartão no Pagar.me.',
      );
      throw ApiException(
        message,
        statusCode: response.statusCode,
        code: 'CARD_TOKENIZATION_FAILED',
      );
    }
    return token;
  }

  bool _paymentLocallyEnabled(Map<String, dynamic> payment) {
    final id = stringValue(payment['id']).toUpperCase();
    if (id == 'APPLE_PAY') return false;
    if (id == 'GOOGLE_PAY' &&
        (PlatformInfo.isIOS || !GeneratedAppConfig.googlePayEnabled))
      return false;
    return true;
  }

  Map<String, dynamic> _googlePayLocalizeConfig(Map<String, dynamic> raw) {
    final config = Map<String, dynamic>.from(raw);
    final data = mapValue(config['data']);
    if (data.isNotEmpty) {
      data['environment'] = GeneratedAppConfig.googlePayEnvironment;
      final merchant = mapValue(data['merchantInfo']);
      if (GeneratedAppConfig.googlePayMerchantId.trim().isNotEmpty) {
        merchant['merchantId'] = GeneratedAppConfig.googlePayMerchantId.trim();
      }
      if (GeneratedAppConfig.googlePayMerchantName.trim().isNotEmpty) {
        merchant['merchantName'] =
            GeneratedAppConfig.googlePayMerchantName.trim();
      }
      if (merchant.isNotEmpty) data['merchantInfo'] = merchant;
      config['data'] = data;
    }
    return config;
  }

  Future<String> _tokenizeGooglePay(
    Map<String, dynamic> payment,
    double total,
  ) async {
    if (!GeneratedAppConfig.googlePayEnabled) {
      throw const ApiException(
        'Google Pay não está habilitado nesta compilação do aplicativo.',
        code: 'GOOGLE_PAY_LOCAL_DISABLED',
      );
    }
    final configJson = _googlePayLocalizeConfig(
      mapValue(payment['google_pay_config']),
    );
    if (configJson.isEmpty) {
      throw const ApiException(
        'Google Pay ainda não está configurado para este HUB.',
        code: 'GOOGLE_PAY_CONFIG_MISSING',
      );
    }
    final configuration = PaymentConfiguration.fromJsonString(
      jsonEncode(configJson),
    );
    final client = Pay(<PayProvider, PaymentConfiguration>{
      PayProvider.google_pay: configuration,
    });
    final available = await client.userCanPay(PayProvider.google_pay);
    if (!available) {
      throw const ApiException(
        'Google Pay não está disponível neste aparelho/conta.',
        code: 'GOOGLE_PAY_UNAVAILABLE',
      );
    }
    final result =
        await client.showPaymentSelector(PayProvider.google_pay, <PaymentItem>[
      PaymentItem(
        label: 'Total',
        amount: total.toStringAsFixed(2),
        status: PaymentItemStatus.final_price,
      ),
    ]);
    return jsonEncode(result);
  }

  Future<void> _submit({bool allowReauth = true}) async {
    if (_submitting || _paymentId == null || _date == null) return;

    final payments = listValue(_data['payment_methods']);
    final summary = mapValue(_data['summary']);
    final selectedPayment = _selectedPayment(payments);
    final isCash = _isCashPayment(payments, _paymentId);
    double? changeFor;
    String? cardToken;
    String? walletToken;
    if (isCash && _needsChange) {
      changeFor = _parseMoney(_changeForController.text);
      if (changeFor == null || changeFor <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LText('Informe para quanto precisa de troco.'),
          ),
        );
        return;
      }
      final total = numberValue(summary['total']);
      if (changeFor + 0.0001 < total) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: LText(
              'O valor para troco não pode ser menor que ${_money(total)}.',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      if (_paymentId == 'CREDIT_CARD') {
        if (selectedPayment == null ||
            stringValue(selectedPayment['hub']).toUpperCase() != 'PAGARME') {
          throw const ApiException(
            'Cartão online ainda não está disponível para este HUB.',
            code: 'CARD_HUB_UNSUPPORTED',
          );
        }
        cardToken = await _tokenizePagarmeCard(selectedPayment);
      }
      if (_paymentId == 'GOOGLE_PAY') {
        if (selectedPayment == null) {
          throw const ApiException(
            'Google Pay não está disponível.',
            code: 'GOOGLE_PAY_UNAVAILABLE',
          );
        }
        walletToken = await _tokenizeGooglePay(
          selectedPayment,
          numberValue(summary['total']),
        );
      }
      final json = await widget.repository.checkoutSubmit(
        widget.cart.checkoutPayload(),
        addressId: _addressId,
        receiptType: _receiptType,
        scheduleDate: _dateSql(_date!),
        paymentId: _paymentId!,
        paymentTerm: _paymentTerm,
        couponCode: _couponCode,
        notes: _notesController.text.trim(),
        needsChange: isCash && _needsChange,
        changeFor: changeFor,
        cardToken: cardToken,
        installments: _paymentId == 'CREDIT_CARD' ? _cardInstallments : null,
        walletToken: walletToken,
        idempotencyKey: _idempotencyKey,
      );
      final data = mapValue(json['data']);
      await widget.cart.removeSelected();
      if (!mounted) return;
      setState(() => _completed = data);
    } on ApiException catch (e) {
      if (e.isUnauthorized && allowReauth && widget.reauthenticate != null) {
        final ok = await widget.reauthenticate!();
        if (ok && mounted) {
          setState(() => _submitting = false);
          await _submit(allowReauth: false);
          return;
        }
      }
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: LText(e.message)));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: LText('Não foi possível concluir o pedido: $e')),
        );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickDate() async {
    final schedule = mapValue(_data['schedule']);
    final firstDate = DateTime.tryParse(stringValue(schedule['first_date'])) ??
        DateTime.now();
    final allowed = listValue(schedule['allowed_weekdays'])
        .map((e) => int.tryParse(e.toString()))
        .whereType<int>()
        .where((e) => e >= 1 && e <= 7)
        .toSet();
    DateTime initial =
        _date != null && !_date!.isBefore(firstDate) ? _date! : firstDate;
    if (allowed.isNotEmpty && !allowed.contains(initial.weekday)) {
      for (var i = 0; i < 14; i++) {
        final candidate = firstDate.add(Duration(days: i));
        if (allowed.contains(candidate.weekday)) {
          initial = candidate;
          break;
        }
      }
    }
    final picked = await showDatePicker(
      context: context,
      locale: Localizations.localeOf(context),
      initialDate: initial,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 120)),
      selectableDayPredicate: allowed.isEmpty
          ? null
          : (day) => !day.isBefore(firstDate) && allowed.contains(day.weekday),
      helpText: _receiptType == 'RETIRADA'
          ? 'Escolha a data da retirada'
          : 'Escolha a data da entrega',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _showAddressPicker(List<Map<String, dynamic>> addresses) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LText(
                'Onde deseja receber?',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              const LText(
                'Os endereços fora da área atendida ficam desativados.',
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: addresses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final a = addresses[i];
                    final id = stringValue(a['id']);
                    final eligible = boolValue(a['eligible']);
                    final isSelected = id == _addressId;
                    final message = nullableString(a['validation_message']);
                    final distance = numberValue(
                      a['distance_km'],
                      fallback: -1,
                    );
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: eligible
                          ? () => Navigator.of(sheetContext).pop(id)
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: eligible
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected && eligible
                                ? Theme.of(context).colorScheme.primary
                                : eligible
                                    ? const Color(0xFF86EFAC)
                                    : const Color(0xFFD1D5DB),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              eligible ? Icons.check_circle : Icons.block,
                              color: eligible
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: LText(
                                          stringValue(
                                            a['label'],
                                            fallback: 'Endereço',
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      if (eligible)
                                        const LText(
                                          'Disponível',
                                          style: TextStyle(
                                            color: Color(0xFF15803D),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        )
                                      else
                                        LText(
                                          'Indisponível',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  LText(_addressLine(a)),
                                  if (distance >= 0) ...[
                                    const SizedBox(height: 4),
                                    LText(
                                      '${distance.toStringAsFixed(2).replaceAll('.', ',')} km',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                  if (message != null &&
                                      message.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    LText(
                                      message,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: eligible
                                            ? const Color(0xFF166534)
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != _addressId && mounted) {
      setState(() => _addressId = selected);
      await _recalculateFreight();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_completed != null) return _buildCompleted(context, _completed!);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const LText('Finalizar compra')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const LText('Finalizar compra')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56),
                const SizedBox(height: 12),
                LText(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _prepare(),
                  icon: const Icon(Icons.refresh),
                  label: const LText('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final addresses = listValue(_data['addresses']);
    final receipt = mapValue(_data['receipt']);
    final freight = mapValue(_data['freight']);
    final payments = listValue(_data['payment_methods']);
    final paymentTerms = listValue(_data['payment_terms']);
    final summary = mapValue(_data['summary']);
    final quote = mapValue(_data['quote']);
    final capabilities = mapValue(_data['capabilities']);
    final coupon = mapValue(_data['coupon']);
    final freightOk = boolValue(
      freight['ok'],
      fallback: _receiptType == 'RETIRADA',
    );
    final minimumReached = boolValue(quote['minimum_reached'], fallback: true);
    Map<String, dynamic>? currentAddress;
    for (final address in addresses) {
      if (stringValue(address['id']) == _addressId) {
        currentAddress = address;
        break;
      }
    }
    currentAddress ??= addresses.isNotEmpty ? addresses.first : null;

    return Scaffold(
      appBar: AppBar(title: const LText('Finalizar compra')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 130),
        children: [
          _CheckoutCard(
            title: 'Como deseja receber?',
            icon: Icons.shopping_bag_outlined,
            child: SegmentedButton<String>(
              segments: [
                const ButtonSegment(
                  value: 'ENTREGA',
                  icon: Icon(Icons.delivery_dining),
                  label: LText('Entrega'),
                ),
                if (boolValue(receipt['pickup_available']))
                  const ButtonSegment(
                    value: 'RETIRADA',
                    icon: Icon(Icons.storefront),
                    label: LText('Retirada'),
                  ),
              ],
              selected: <String>{_receiptType},
              onSelectionChanged: (value) async {
                setState(() => _receiptType = value.first);
                await _prepare();
              },
            ),
          ),
          if (_receiptType == 'ENTREGA') ...[
            const SizedBox(height: 10),
            _CheckoutCard(
              title: 'Endereço de entrega',
              icon: Icons.location_on_outlined,
              child: addresses.isEmpty
                  ? const LText(
                      'Nenhum endereço cadastrado. Cadastre um endereço na sua conta.',
                    )
                  : InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _showAddressPicker(addresses),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: freightOk
                                ? const Color(0xFF86EFAC)
                                : Theme.of(context).colorScheme.error,
                          ),
                          color: freightOk
                              ? const Color(0xFFF0FDF4)
                              : Theme.of(
                                  context,
                                ).colorScheme.errorContainer.withOpacity(.28),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              freightOk
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              color: freightOk
                                  ? const Color(0xFF15803D)
                                  : Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LText(
                                    currentAddress == null
                                        ? 'Escolha um endereço'
                                        : stringValue(
                                            currentAddress['label'],
                                            fallback: 'Endereço',
                                          ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (currentAddress != null)
                                    LText(
                                      _addressLine(currentAddress),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (nullableString(freight['message']) !=
                                      null) ...[
                                    const SizedBox(height: 3),
                                    LText(
                                      stringValue(freight['message']),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: freightOk
                                            ? const Color(0xFF166534)
                                            : Theme.of(
                                                context,
                                              ).colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
          const SizedBox(height: 10),
          _CheckoutCard(
            title: _receiptType == 'RETIRADA'
                ? 'Data da retirada'
                : 'Data da entrega',
            icon: Icons.calendar_month_outlined,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LText(
                            _date == null
                                ? 'Escolher data'
                                : '${_weekdayPt(_date!)} · ${_dateBr(_date!)}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          LText(
                            'Toque para abrir o calendário',
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
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          if (boolValue(capabilities['coupon'])) ...[
            const SizedBox(height: 10),
            _CheckoutCard(
              title: 'Cupom de desconto',
              icon: Icons.confirmation_number_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _couponController,
                          textCapitalization: TextCapitalization.characters,
                          enabled: _couponCode == null,
                          decoration: const LDecoration(
                            hintText: 'Digite o código',
                          ),
                          onSubmitted: _couponCode == null
                              ? (v) => _applyCoupon(v)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_couponCode == null)
                        FilledButton(
                          onPressed: _couponLoading
                              ? null
                              : () => _applyCoupon(_couponController.text),
                          child: const LText('Aplicar'),
                        )
                      else
                        OutlinedButton(
                          onPressed: _couponLoading ? null : _removeCoupon,
                          child: const LText('Remover'),
                        ),
                    ],
                  ),
                  if (_couponLoading) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                  if (_couponMessage != null) ...[
                    const SizedBox(height: 8),
                    LText(
                      _couponMessage!,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _couponCode == null
                            ? Theme.of(context).colorScheme.error
                            : const Color(0xFF15803D),
                      ),
                    ),
                  ],
                  if (coupon.isNotEmpty &&
                      numberValue(coupon['saving']) > 0) ...[
                    const SizedBox(height: 4),
                    LText(
                      'Economia: ${_money(numberValue(coupon['saving']))}',
                      style: const TextStyle(
                        color: Color(0xFF15803D),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          _CheckoutCard(
            title: 'Resumo do pedido',
            icon: Icons.receipt_long_outlined,
            child: Column(
              children: [
                _SummaryRow(
                  'Produtos (${widget.cart.selectedItemCount})',
                  numberValue(summary['subtotal']),
                ),
                _SummaryRow(
                  'Frete',
                  numberValue(summary['freight']),
                  suffix: _receiptType == 'RETIRADA' ||
                          numberValue(summary['freight']) <= 0
                      ? 'Grátis'
                      : null,
                ),
                if (numberValue(summary['discount']) > 0)
                  _SummaryRow(
                    'Desconto',
                    -numberValue(summary['discount']),
                    prefixMinus: true,
                  ),
                const Divider(height: 24),
                _SummaryRow(
                  'Total do pedido',
                  numberValue(summary['total']),
                  strong: true,
                ),
                if (_freightLoading) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(),
                ],
                if (!freightOk && _receiptType == 'ENTREGA') ...[
                  const SizedBox(height: 10),
                  LText(
                    stringValue(
                      freight['message'],
                      fallback: 'Endereço fora da área de entrega.',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (!minimumReached) ...[
                  const SizedBox(height: 10),
                  LText(
                    'Faltam ${_money(numberValue(quote['minimum_missing']))} para o pedido mínimo.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          _CheckoutCard(
            title: 'Pagamento',
            icon: Icons.payments_outlined,
            child: payments.isEmpty
                ? const LText(
                    'Nenhum meio de pagamento disponível para este pedido.',
                  )
                : Column(
                    children: [
                      ...payments.map((payment) {
                        final id = stringValue(payment['id']);
                        final enabled = _paymentLocallyEnabled(payment) &&
                            boolValue(
                              payment['mobile_enabled'],
                              fallback: true,
                            );
                        final hub = nullableString(payment['hub']);
                        final reason = id == 'GOOGLE_PAY' &&
                                (PlatformInfo.isIOS ||
                                    !GeneratedAppConfig.googlePayEnabled)
                            ? 'Google Pay não foi habilitado nesta compilação.'
                            : nullableString(payment['mobile_reason']);
                        return RadioListTile<String>(
                          value: id,
                          groupValue: _paymentId,
                          contentPadding: EdgeInsets.zero,
                          title: LText(
                            stringValue(payment['name'], fallback: id),
                          ),
                          subtitle: reason != null && !enabled
                              ? LText(reason)
                              : hub == null
                                  ? null
                                  : LText('Online · $hub'),
                          secondary: Icon(_paymentIcon(id)),
                          onChanged: enabled
                              ? (value) => setState(() {
                                    _paymentId = value;
                                    _paymentTerm = null;
                                    if (!_isCashPayment(payments, value)) {
                                      _needsChange = false;
                                      _changeForController.clear();
                                    }
                                  })
                              : null,
                        );
                      }),
                      if (_paymentId == 'CREDIT_CARD' &&
                          _selectedPayment(payments) != null) ...[
                        const SizedBox(height: 6),
                        _CardPaymentForm(
                          payment: _selectedPayment(payments)!,
                          numberController: _cardNumberController,
                          holderController: _cardHolderController,
                          expiryController: _cardExpiryController,
                          cvvController: _cardCvvController,
                          installments: _cardInstallments,
                          onInstallmentsChanged: (value) =>
                              setState(() => _cardInstallments = value),
                        ),
                      ],
                      if (_needsPaymentTerm(payments, _paymentId) &&
                          paymentTerms.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _paymentTerm != null &&
                                  paymentTerms.any(
                                    (e) =>
                                        stringValue(e['code']) == _paymentTerm,
                                  )
                              ? _paymentTerm
                              : null,
                          decoration: const LDecoration(
                            labelText: 'Condição / prazo',
                          ),
                          items: paymentTerms
                              .map(
                                (term) => DropdownMenuItem<String>(
                                  value: stringValue(term['code']),
                                  child: LText(
                                    '${stringValue(term['code'])} · ${stringValue(term['name'])}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _paymentTerm = value),
                        ),
                      ],
                      if (_isCashPayment(payments, _paymentId)) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withOpacity(.45),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile.adaptive(
                                value: _needsChange,
                                contentPadding: EdgeInsets.zero,
                                title: const LText(
                                  'Precisa de troco?',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: const LText(
                                  'Informe o valor que será entregue ao motorista.',
                                ),
                                onChanged: (value) => setState(() {
                                  _needsChange = value;
                                  if (!value) _changeForController.clear();
                                }),
                              ),
                              if (_needsChange) ...[
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _changeForController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.,]'),
                                    ),
                                  ],
                                  decoration: const LDecoration(
                                    labelText: 'Troco para quanto?',
                                    hintText: 'Ex.: 100,00',
                                    prefixText: 'R\$ ',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          _CheckoutCard(
            title: 'Observações do pedido',
            icon: Icons.notes_outlined,
            child: TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const LDecoration(
                hintText:
                    'Ex.: chamar no interfone, entregar na portaria, não substituir itens...',
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(14),
        child: FilledButton.icon(
          onPressed: boolValue(capabilities['order_submit']) &&
                  freightOk &&
                  minimumReached &&
                  _paymentId != null &&
                  !_submitting
              ? _submit
              : null,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_outline),
          label: LText(
            boolValue(capabilities['order_submit'])
                ? (_submitting
                    ? 'Confirmando pedido...'
                    : 'Confirmar pedido · ${_money(numberValue(summary['total']))}')
                : 'Confirmação do pedido indisponível',
          ),
        ),
      ),
    );
  }

  Widget _buildCompleted(BuildContext context, Map<String, dynamic> data) {
    final order = mapValue(data['order']);
    final payment = mapValue(data['payment']);
    final paymentError = nullableString(data['payment_error']);
    final number = stringValue(
      order['number'],
      fallback: '${order['id'] ?? ''}',
    );
    final pix = stringValue(payment['pix_code']);
    final boleto = stringValue(payment['boleto_barcode']);
    final boletoUrl = stringValue(payment['boleto_url']);
    return Scaffold(
      appBar: AppBar(title: const LText('Pedido realizado')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Icon(Icons.check_circle, size: 72, color: Color(0xFF15803D)),
          const SizedBox(height: 12),
          LText(
            'Pedido #$number recebido!',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          LText(
            'Total ${_money(numberValue(order['total']))}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          if (paymentError != null && paymentError.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: LText(
                  'O pedido foi criado, mas o pagamento precisa de atenção: $paymentError',
                ),
              ),
            ),
          ],
          if (pix.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LText(
                      'PIX copia e cola',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(pix),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: pix));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: LText('Código PIX copiado.')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const LText('Copiar PIX'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (boleto.isNotEmpty || boletoUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LText(
                      'Boleto',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    if (boleto.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SelectableText(boleto),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: boleto));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: LText('Código do boleto copiado.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const LText('Copiar código'),
                      ),
                    ],
                    if (boletoUrl.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SelectableText(boletoUrl),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LText('Continuar na loja'),
            ),
          ),
          const SizedBox(height: 6),
          LText(
            'Você pode acompanhar este pedido em Conta > Meus pedidos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardPaymentForm extends StatelessWidget {
  const _CardPaymentForm({
    required this.payment,
    required this.numberController,
    required this.holderController,
    required this.expiryController,
    required this.cvvController,
    required this.installments,
    required this.onInstallmentsChanged,
  });

  final Map<String, dynamic> payment;
  final TextEditingController numberController;
  final TextEditingController holderController;
  final TextEditingController expiryController;
  final TextEditingController cvvController;
  final int installments;
  final ValueChanged<int> onInstallmentsChanged;

  @override
  Widget build(BuildContext context) {
    final options = listValue(payment['installments']);
    final counts = options
        .map((e) => int.tryParse(stringValue(e['count'])) ?? 0)
        .where((e) => e > 0)
        .toSet();
    final effective = counts.contains(installments)
        ? installments
        : (counts.isNotEmpty ? counts.first : 1);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(.35),
      ),
      child: Column(
        children: [
          TextField(
            controller: numberController,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.creditCardNumber],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(19),
            ],
            decoration: const LDecoration(labelText: 'Número do cartão'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: holderController,
            textCapitalization: TextCapitalization.characters,
            autofillHints: const [AutofillHints.creditCardName],
            decoration: const LDecoration(
              labelText: 'Nome impresso no cartão',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: expiryController,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.creditCardExpirationDate],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const LDecoration(
                    labelText: 'Validade',
                    hintText: 'MM/AA',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: cvvController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  autofillHints: const [AutofillHints.creditCardSecurityCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const LDecoration(labelText: 'CVV'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (options.isNotEmpty)
            DropdownButtonFormField<int>(
              value: effective,
              decoration: const LDecoration(labelText: 'Parcelas'),
              items: options.map((item) {
                final count = int.tryParse(stringValue(item['count'])) ?? 1;
                final value = numberValue(item['value']);
                final total = numberValue(item['total']);
                final noInterest = boolValue(item['no_interest']);
                final label =
                    '$count x ${_money(value)}${noInterest ? ' sem juros' : ' · total ${_money(total)}'}';
                return DropdownMenuItem<int>(value: count, child: LText(label));
              }).toList(),
              onChanged: (value) {
                if (value != null) onInstallmentsChanged(value);
              },
            )
          else
            const Align(
              alignment: Alignment.centerLeft,
              child: LText('1x no cartão'),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: LText(
              'Os dados do cartão são tokenizados diretamente no Pagar.me; o número e o CVV não são enviados ao ecommerce.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutCard extends StatelessWidget {
  const _CheckoutCard({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LText(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(
    this.label,
    this.value, {
    this.strong = false,
    this.suffix,
    this.prefixMinus = false,
  });
  final String label;
  final double value;
  final bool strong;
  final String? suffix;
  final bool prefixMinus;
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
              suffix ?? '${prefixMinus ? '- ' : ''}${_money(value.abs())}',
              style: strong
                  ? const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)
                  : const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
}

String _addressLine(Map<String, dynamic> a) {
  final street = stringValue(a['street']);
  final number = stringValue(a['number']);
  final district = stringValue(a['district']);
  final city = stringValue(a['city']);
  final state = stringValue(a['state']);
  return '$street${number.isEmpty ? '' : ', $number'}${district.isEmpty ? '' : ' - $district'}${city.isEmpty ? '' : ' - $city/$state'}';
}

bool _isCashPayment(List<Map<String, dynamic>> payments, String? selectedId) {
  if (selectedId == null) return false;
  for (final p in payments) {
    if (stringValue(p['id']) != selectedId) continue;
    final name = stringValue(p['name']).toUpperCase();
    return name.contains('DINHEIRO') ||
        name.contains('ESPÉCIE') ||
        name.contains('ESPECIE');
  }
  return false;
}

double? _parseMoney(String raw) {
  var value = raw.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (value.isEmpty) return null;
  if (value.contains(',')) {
    value = value.replaceAll('.', '').replaceAll(',', '.');
  }
  value = value.replaceAll(RegExp(r'[^0-9.-]'), '');
  return double.tryParse(value);
}

bool _needsPaymentTerm(
  List<Map<String, dynamic>> payments,
  String? selectedId,
) {
  if (selectedId == null) return false;
  for (final p in payments) {
    if (stringValue(p['id']) != selectedId) continue;
    final name = stringValue(p['name']).toUpperCase();
    return name.contains('BOLETO') || name.contains('FATURADO');
  }
  return false;
}

String _dateSql(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

IconData _paymentIcon(String id) {
  switch (id.toUpperCase()) {
    case 'PIX':
      return Icons.qr_code_2;
    case 'CREDIT_CARD':
      return Icons.credit_card;
    case 'GOOGLE_PAY':
      return Icons.account_balance_wallet_outlined;
    case 'BOLETO':
      return Icons.receipt_long;
    default:
      return Icons.wallet_outlined;
  }
}

String _weekdayPt(DateTime value) =>
    const ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'][value.weekday - 1];
String _dateBr(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String _money(double value) =>
    'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
