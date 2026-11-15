// ignore_for_file: curly_braces_in_flow_control_structures

class Coupon {
  /// Validates and returns a clean map. Throws [FormatException].
  static Map<String, dynamic> parse(Map<String, dynamic> j) {
    final code = j['code'];
    if (code is! String || code.trim().isEmpty)
      throw const FormatException('code is required');
    final type = j['type'];
    if (type != 'percent' && type != 'fixed') {
      throw const FormatException("type must be 'percent' or 'fixed'");
    }
    final value = j['value'];
    if (value is! num || value <= 0)
      throw const FormatException('value must be > 0');
    if (type == 'percent' && value > 100)
      throw const FormatException('percent must be <= 100');

    return {
      'code': code.trim().toUpperCase(),
      'type': type,
      'value': value.toDouble(),
      'minOrder': ((j['minOrder'] as num?) ?? 0).toDouble(),
      'maxDiscount': (j['maxDiscount'] as num?)?.toDouble(),
      'usageLimit': j['usageLimit'] as int?,
      'usedCount': 0,
      'expiresAt': j['expiresAt'] is String
          ? DateTime.tryParse(j['expiresAt'] as String)?.toUtc()
          : null,
      'active': (j['active'] as bool?) ?? true,
      'createdAt': DateTime.now().toUtc(),
    };
  }
}
