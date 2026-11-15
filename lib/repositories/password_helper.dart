import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

String _derive(String password, String salt) {
  List<int> bytes = utf8.encode('$salt:$password');
  final key = utf8.encode(salt);
  for (var i = 0; i < 10000; i++) {
    bytes = Hmac(sha256, key).convert(bytes).bytes;
  }
  return base64Url.encode(bytes);
}

String hashPassword(String password) {
  final r = Random.secure();
  final salt = base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  return '$salt:${_derive(password, salt)}';
}

bool verifyPassword(String password, String stored) {
  final i = stored.indexOf(':');
  if (i < 0) return false;
  final salt = stored.substring(0, i);
  return _derive(password, salt) == stored.substring(i + 1);
}
