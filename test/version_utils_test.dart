import 'package:flutter_test/flutter_test.dart';
import 'package:soft_ecommerce_mobile/core/version/version_utils.dart';

void main() {
  test('compara versoes simples', () {
    expect(VersionUtils.isLowerThan('1.0.0', '1.0.1'), isTrue);
    expect(VersionUtils.isLowerThan('1.2.0', '1.1.9'), isFalse);
    expect(VersionUtils.isLowerThan('2.0', '2.0.0'), isFalse);
  });
}
