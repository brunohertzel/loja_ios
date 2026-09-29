import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../store/store_models.dart';

class CartLine {
  CartLine({
    required this.lineId,
    required this.product,
    required this.quantityVisual,
    required this.quantityReal,
    this.quantityMultiplier,
    this.selectedVariationIds = const <int>[],
    this.numberValues = const <String, double>{},
    this.observation = '',
    this.observationSummary = '',
    this.selected = true,
  });

  final String lineId;
  final StoreProduct product;
  double quantityVisual;
  double quantityReal;
  final double? quantityMultiplier;
  final List<int> selectedVariationIds;
  final Map<String, double> numberValues;
  final String observation;
  final String observationSummary;
  bool selected;

  CampaignPriceResult get pricing => calculateCampaign(product, quantityReal);
  double get subtotal => pricing.subtotal;

  Map<String, dynamic> toJson() => {
        'line_id': lineId,
        'product': product.toJson(),
        'quantity_visual': quantityVisual,
        'quantity_real': quantityReal,
        'quantity_multiplier': quantityMultiplier,
        'selected_variation_ids': selectedVariationIds,
        'number_values': numberValues,
        'observation': observation,
        'observation_summary': observationSummary,
        'selected': selected,
      };

  factory CartLine.fromJson(Map<String, dynamic> json) {
    final product = StoreProduct.fromJson(mapValue(json['product']));
    final numberValues = <String, double>{};
    final rawNumbers = json['number_values'];
    if (rawNumbers is Map) {
      rawNumbers.forEach((key, value) {
        numberValues[key.toString()] = numberValue(value);
      });
    }
    final ids = <int>[];
    final rawIds = json['selected_variation_ids'];
    if (rawIds is List) {
      for (final value in rawIds) {
        final id = int.tryParse(value.toString());
        if (id != null && id > 0) ids.add(id);
      }
    }
    return CartLine(
      lineId: stringValue(json['line_id'], fallback: product.id),
      product: product,
      quantityVisual: numberValue(json['quantity_visual'], fallback: 1),
      quantityReal: numberValue(json['quantity_real'], fallback: 1),
      quantityMultiplier: json['quantity_multiplier'] == null
          ? null
          : numberValue(json['quantity_multiplier']),
      selectedVariationIds: ids,
      numberValues: numberValues,
      observation: stringValue(json['observation']),
      observationSummary: stringValue(json['observation_summary']),
      selected: boolValue(json['selected'], fallback: true),
    );
  }

  Map<String, dynamic> toCheckoutJson() => {
        'product_id': int.tryParse(product.id) ?? product.id,
        'quantity_visual': quantityVisual,
        'selected_variation_ids': selectedVariationIds,
        'number_values': numberValues,
        'observation': observation,
      };

  Map<String, dynamic> toServerJson() => {
        'product_id': int.tryParse(product.id) ?? product.id,
        'quantity_real': quantityReal,
        'observation': observation,
      };
}

class CartController extends ChangeNotifier {
  static const _storageKey = 'soft_mobile_cart_v2';
  final Map<String, CartLine> _items = <String, CartLine>{};
  bool _loaded = false;

  List<CartLine> get items => _items.values.toList(growable: false);
  List<CartLine> get selectedItems => _items.values.where((line) => line.selected).toList(growable: false);
  int get itemCount => _items.length;
  int get selectedItemCount => selectedItems.length;
  double get total => _items.values.fold<double>(0.0, (sum, line) => sum + line.subtotal);
  double get selectedTotal => selectedItems.fold<double>(0.0, (sum, line) => sum + line.subtotal);
  bool get allSelected => _items.isNotEmpty && _items.values.every((line) => line.selected);
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final line = CartLine.fromJson(item.map((k, v) => MapEntry(k.toString(), v)));
              if (line.lineId.isNotEmpty && line.product.id.isNotEmpty) _items[line.lineId] = line;
            }
          }
        }
      }
    } catch (_) {
      _items.clear();
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_items.values.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> replaceFromServer(List<Map<String, dynamic>> rawItems) async {
    final previous = _items.values.toList(growable: false);
    final server = <String, CartLine>{};
    final usedPrevious = <String>{};
    for (final raw in rawItems) {
      try {
        final incoming = CartLine.fromJson(raw);
        if (incoming.product.id.isEmpty) continue;

        CartLine? existing;
        for (final candidate in previous) {
          if (usedPrevious.contains(candidate.lineId)) continue;
          if (candidate.product.id == incoming.product.id &&
              candidate.observation.trim() == incoming.observation.trim()) {
            existing = candidate;
            usedPrevious.add(candidate.lineId);
            break;
          }
        }

        // Se a linha nasceu no app, preserva variacoes/multiplicador locais.
        // O servidor continua autoritativo para produto e quantidade.
        final key = existing?.lineId ??
            'server:${incoming.product.id}|${incoming.observation.trim()}';
        server[key] = CartLine(
          lineId: key,
          product: incoming.product,
          quantityVisual: existing?.quantityMultiplier != null &&
                  existing!.quantityMultiplier! > 0
              ? incoming.quantityReal / existing.quantityMultiplier!
              : incoming.quantityVisual,
          quantityReal: incoming.quantityReal,
          quantityMultiplier: existing?.quantityMultiplier,
          selectedVariationIds: existing?.selectedVariationIds ??
              incoming.selectedVariationIds,
          numberValues: existing?.numberValues ?? incoming.numberValues,
          observation: incoming.observation,
          observationSummary: existing?.observationSummary ??
              incoming.observationSummary,
          selected: existing?.selected ?? incoming.selected,
        );
      } catch (_) {}
    }
    _items
      ..clear()
      ..addAll(server);
    _loaded = true;
    notifyListeners();
    await _persist();
  }

  List<Map<String, dynamic>> serverPayload() =>
      items.map((line) => line.toServerJson()).toList(growable: false);

  String buildLineId({
    required StoreProduct product,
    required List<int> selectedVariationIds,
    required Map<String, double> numberValues,
    required String observation,
  }) {
    final ids = [...selectedVariationIds]..sort();
    final keys = numberValues.keys.toList()..sort();
    final numbers = keys.map((k) => '$k=${numberValues[k]}').join('&');
    return '${product.id}|${ids.join(',')}|$numbers|${observation.trim()}';
  }

  void addConfigured({
    required StoreProduct product,
    required double quantityVisual,
    required double quantityReal,
    required List<int> selectedVariationIds,
    required Map<String, double> numberValues,
    required String observation,
    required String observationSummary,
    double? quantityMultiplier,
  }) {
    if (!product.available) return;
    final lineId = buildLineId(
      product: product,
      selectedVariationIds: selectedVariationIds,
      numberValues: numberValues,
      observation: observation,
    );
    final current = _items[lineId];
    if (current == null) {
      _items[lineId] = CartLine(
        lineId: lineId,
        product: product,
        quantityVisual: quantityVisual,
        quantityReal: quantityReal,
        quantityMultiplier: quantityMultiplier,
        selectedVariationIds: [...selectedVariationIds],
        numberValues: {...numberValues},
        observation: observation,
        observationSummary: observationSummary,
        selected: true,
      );
    } else {
      current.quantityVisual += quantityVisual;
      current.quantityReal += quantityReal;
      current.selected = true;
    }
    notifyListeners();
    _persist();
  }

  void setVisualQuantity(String lineId, double visual) {
    final line = _items[lineId];
    if (line == null) return;
    final rules = line.product.quantityRules;
    final multiplier = line.quantityMultiplier;
    double normalized = visual;
    if (multiplier != null && multiplier > 0) {
      normalized = normalized.floorToDouble();
      if (normalized < 1) normalized = 1;
      line.quantityReal = normalized * multiplier;
    } else if (rules?.isB2b == true) {
      if (normalized < 0.001) normalized = 0.001;
      line.quantityReal = normalized;
    } else {
      normalized = normalized.floorToDouble();
      if (normalized < 1) normalized = 1;
      line.quantityReal = normalized;
    }
    line.quantityVisual = normalized;
    notifyListeners();
    _persist();
  }

  void increment(String lineId, double direction) {
    final line = _items[lineId];
    if (line == null) return;
    // Exatamente como a loja web: botão +/- altera 1 unidade visual.
    setVisualQuantity(lineId, line.quantityVisual + direction);
  }

  void toggleSelected(String lineId, bool value) {
    final line = _items[lineId];
    if (line == null) return;
    line.selected = value;
    notifyListeners();
    _persist();
  }

  void toggleAll(bool value) {
    for (final line in _items.values) {
      line.selected = value;
    }
    notifyListeners();
    _persist();
  }

  void remove(String lineId) {
    _items.remove(lineId);
    notifyListeners();
    _persist();
  }

  Future<void> removeSelected() async {
    final selectedIds = _items.values.where((line) => line.selected).map((line) => line.lineId).toList(growable: false);
    for (final id in selectedIds) {
      _items.remove(id);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    _items.clear();
    notifyListeners();
    await _persist();
  }

  List<Map<String, dynamic>> checkoutPayload() =>
      selectedItems.map((line) => line.toCheckoutJson()).toList(growable: false);
}
