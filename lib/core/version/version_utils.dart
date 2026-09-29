class VersionUtils {
  static bool isLowerThan(String current, String minimum) {
    final a = _parts(current);
    final b = _parts(minimum);
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av < bv) return true;
      if (av > bv) return false;
    }
    return false;
  }

  static List<int> _parts(String value) => value
      .split('.')
      .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9].*$'), '')) ?? 0)
      .toList();
}
