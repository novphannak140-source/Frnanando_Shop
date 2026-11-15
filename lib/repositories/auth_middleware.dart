import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/repositories/jwt_helper.dart';
import 'package:franando_shop_api/repositories/response_helper.dart';

class AuthUser {
  AuthUser(this.id, this.role);
  final String id;
  final String role;
  bool get isAdmin => role == 'admin';
}

/// Reads `Authorization: Bearer <token>`; returns null if missing/invalid.
AuthUser? authenticate(RequestContext context) {
  final header = context.request.headers['authorization'];
  if (header == null || !header.startsWith('Bearer ')) return null;
  final payload = verifyToken(header.substring(7).trim());
  if (payload == null) return null;
  return AuthUser(payload['sub'] as String, (payload['role'] as String?) ?? 'user');
}

/// Folder-level middleware: requires a valid token and provides [AuthUser].
Middleware requireAuth() => (handler) => (context) async {
      final user = authenticate(context);
      if (user == null) return fail('Unauthorized: missing or invalid token', status: 401);
      return handler(context.provide<AuthUser>(() => user));
    };

/// For handlers: returns an error [Response] unless the caller is an admin.
Response? adminGuard(RequestContext context) {
  final user = authenticate(context);
  if (user == null) return fail('Unauthorized: missing or invalid token', status: 401);
  if (!user.isAdmin) return fail('Forbidden: admin only', status: 403);
  return null;
}
