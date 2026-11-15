import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:franando_shop_api/repositories/env.dart';

String signToken({required String userId, required String role}) =>
    JWT({'sub': userId, 'role': role})
        .sign(SecretKey(Env.jwtSecret), expiresIn: const Duration(days: 7));

Map<String, dynamic>? verifyToken(String token) {
  try {
    final jwt = JWT.verify(token, SecretKey(Env.jwtSecret));
    return Map<String, dynamic>.from(jwt.payload as Map);
  } catch (_) {
    return null;
  }
}
