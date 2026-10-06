import '../lib/features/store/store_models.dart';

void check(bool ok, String message) {
  if (!ok) throw StateError(message);
}

void main() {
  for (final customer in ['B2C', 'B2B']) {
    for (final places in [1, 2, 3]) {
      final rules = QuantityRules.fromJson({
        'customer_type': customer,
        'unit': 'KG',
        'decimals': places,
        'fractional_enabled': true,
        'decimal_input_mode': 'SHIFT',
        'minimum': places == 1
            ? 0.1
            : places == 2
            ? 0.01
            : 0.001,
      });
      check(
        rules.inputDecimals == places && rules.usesShiftInput,
        'server decimals/mask $customer $places',
      );
      final sample = places == 1
          ? 1.2
          : places == 2
          ? 1.23
          : 1.234;
      check(
        (rules.normalize(1.234) - sample).abs() < 1e-8,
        'precision $customer $places',
      );
      check(rules.normalize(0) > 0, 'minimum');
      check(rules.normalize(1.8, hasMultiplier: true) == 1, 'portion count');
      check(
        QuantityRules.fromJson(rules.toJson()).inputDecimals == places,
        'cache preserves policy',
      );
      check(
        rules.shiftText('500') ==
            (places == 1
                ? '50,0'
                : places == 2
                ? '5,00'
                : '0,500'),
        'automatic separator',
      );
      check(rules.shiftText('') == '', 'empty edit');
    }
    final off = QuantityRules.fromJson({
      'customer_type': customer,
      'decimals': 3,
      'fractional_enabled': false,
    });
    check(
      off.inputDecimals == 0 &&
          !off.usesShiftInput &&
          off.normalize(.5) == 1 &&
          off.normalize(2.9) == 2,
      'disabled rule overrides customer/decimals',
    );
  }
  final legacy = QuantityRules.fromJson({'customer_type': 'B2B'});
  check(
    legacy.inputDecimals == 0 && legacy.normalize(.5) == 1,
    'no hardcoded B2B decimals',
  );
  print(
    'PASS Dart: B2C/B2B, disabled/enabled, 1/2/3 places, minimum, rounding, portions, cache and SHIFT.',
  );
}
