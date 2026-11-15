import 'package:franando_shop_api/repositories/response_helper.dart';

class Product {
  /// Validates and returns a clean map for MongoDB. Throws [FormatException].
  static Map<String, dynamic> parse(Map<String, dynamic> j, {bool partial = false}) {
    final out = <String, dynamic>{};

    void need(String k) {
      if (!partial && j[k] == null) throw FormatException('$k is required');
    }

    need('name');
    need('price');
    need('categoryId');

    if (j.containsKey('name')) {
      final v = j['name'];
      if (v is! String || v.trim().isEmpty) {
        throw const FormatException('name must be a non-empty string');
      }
      out['name'] = v.trim();
    }
    if (j.containsKey('price')) {
      final v = j['price'];
      if (v is! num || v < 0) throw const FormatException('price must be a number >= 0');
      out['price'] = v.toDouble();
    }
    if (j['discountPrice'] != null) {
      final v = j['discountPrice'];
      if (v is! num || v < 0) {
        throw const FormatException('discountPrice must be a number >= 0');
      }
      out['discountPrice'] = v.toDouble();
    }
    if (j.containsKey('categoryId')) {
      final id = parseId(j['categoryId']);
      if (id == null) throw const FormatException('categoryId is invalid');
      out['categoryId'] = id;
    }
    if (j.containsKey('stock') || !partial) {
      final v = j['stock'] ?? 0;
      if (v is! int || v < 0) throw const FormatException('stock must be an integer >= 0');
      out['stock'] = v;
    }
    if (j.containsKey('description') || !partial) {
      out['description'] = (j['description'] as String?) ?? '';
    }
    if (j.containsKey('images') || !partial) {
      final v = j['images'] ?? <String>[];
      if (v is! List) throw const FormatException('images must be a list of URLs');
      out['images'] = v.map((e) => e.toString()).toList();
    }
    if (j.containsKey('isActive') || !partial) {
      out['isActive'] = (j['isActive'] as bool?) ?? true;
    }
    return out;
  }

  /// Effective unit price (discount if present).
  static double unitPrice(Map<String, dynamic> p) =>
      ((p['discountPrice'] ?? p['price']) as num).toDouble();
}
