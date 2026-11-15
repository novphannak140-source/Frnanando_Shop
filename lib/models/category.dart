// ignore_for_file: curly_braces_in_flow_control_structures

class Category {
  static String slugify(String s) => s
      .toLowerCase()
      .trim()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  static Map<String, dynamic> parse(Map<String, dynamic> j,
      {bool partial = false}) {
    final out = <String, dynamic>{};
    if (!partial && j['name'] == null)
      throw const FormatException('name is required');
    if (j.containsKey('name')) {
      final n = j['name'];
      if (n is! String || n.trim().isEmpty) {
        throw const FormatException('name must be a non-empty string');
      }
      out['name'] = n.trim();
      out['slug'] = slugify(n);
    }
    if (j['description'] is String) out['description'] = j['description'];
    if (j['image'] is String) out['image'] = j['image'];
    return out;
  }
}
