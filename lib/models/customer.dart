// ignore_for_file: deprecated_member_use

import 'package:franando_shop_api/repositories/response_helper.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// Customer profile fields (stored on the `users` document).
class Customer {
  static const genders = ['male', 'female', 'other'];

  /// Validates a profile update and returns only allowed fields.
  /// Throws [FormatException] on invalid input.
  static Map<String, dynamic> parseUpdate(Map<String, dynamic> j) {
    final out = <String, dynamic>{};

    void text(String key, int max) {
      if (!j.containsKey(key)) return;
      final v = j[key];
      if (v == null) {
        out[key] = null;
        return;
      }
      if (v is! String || v.length > max) throw FormatException('$key is invalid');
      out[key] = v.trim();
    }

    text('name', 100);
    if (j.containsKey('name') && (out['name'] == null || (out['name'] as String).isEmpty)) {
      throw const FormatException('name cannot be empty');
    }
    text('phone', 20);
    text('avatar', 500);

    if (j.containsKey('gender') && j['gender'] != null) {
      if (!genders.contains(j['gender'])) {
        throw FormatException('gender must be one of ${genders.join(', ')}');
      }
      out['gender'] = j['gender'];
    }

    if (j.containsKey('birthDate') && j['birthDate'] != null) {
      final d = j['birthDate'] is String ? DateTime.tryParse(j['birthDate'] as String) : null;
      if (d == null) throw const FormatException('birthDate must be an ISO date (YYYY-MM-DD)');
      out['birthDate'] = d.toUtc();
    }

    if (j.containsKey('addresses')) {
      final list = j['addresses'];
      if (list is! List || list.length > 10) {
        throw const FormatException('addresses must be a list (max 10)');
      }
      final addrs = <Map<String, dynamic>>[];
      for (final a in list) {
        if (a is! Map || (a['address'] is! String) || (a['address'] as String).trim().isEmpty) {
          throw const FormatException('each address needs an "address" text');
        }
        addrs.add({
          'id': (a['id'] as String?) ?? ObjectId().toHexString(),
          'label': (a['label'] as String?) ?? 'Home',
          'name': a['name'],
          'phone': a['phone'],
          'address': (a['address'] as String).trim(),
          'isDefault': a['isDefault'] == true,
        });
      }
      // keep exactly one default
      if (addrs.isNotEmpty) {
        final first = addrs.indexWhere((a) => a['isDefault'] == true);
        for (var i = 0; i < addrs.length; i++) {
          addrs[i]['isDefault'] = i == (first < 0 ? 0 : first);
        }
      }
      out['addresses'] = addrs;
    }
    return out;
  }

  /// Safe parse used for wishlist ids.
  static ObjectId? productId(Object? v) => parseId(v);
}
