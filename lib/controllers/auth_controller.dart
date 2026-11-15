// ignore_for_file: deprecated_member_use

import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/database/mongo_database.dart';
import 'package:franando_shop_api/models/user.dart';
import 'package:franando_shop_api/repositories/auth_middleware.dart';
import 'package:franando_shop_api/repositories/jwt_helper.dart';
import 'package:franando_shop_api/repositories/password_helper.dart';
import 'package:franando_shop_api/repositories/response_helper.dart';
import 'package:mongo_dart/mongo_dart.dart';

class AuthController {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static Future<Response> register(RequestContext context) async {
    final b = await readJson(context);
    final name = (b['name'] as String?)?.trim() ?? '';
    final email = (b['email'] as String?)?.trim().toLowerCase() ?? '';
    final password = b['password'] as String? ?? '';

    if (name.isEmpty) return fail('name is required');
    if (!_emailRe.hasMatch(email)) return fail('A valid email is required');
    if (password.length < 6) return fail('password must be at least 6 characters');

    final users = Database.instance.collection('users');
    if (await users.findOne({'email': email}) != null) {
      return fail('Email already registered', status: 409);
    }

    final doc = User(
      name: name,
      email: email,
      passwordHash: hashPassword(password),
      phone: b['phone'] as String?,
    ).toMap();
    final id = ObjectId();
    doc['_id'] = id;
    await users.insertOne(doc);

    final token = signToken(userId: id.toHexString(), role: 'user');
    return ok({'user': User.publicView(doc), 'token': token}, status: 201);
  }

  static Future<Response> login(RequestContext context) async {
    final b = await readJson(context);
    final email = (b['email'] as String?)?.trim().toLowerCase() ?? '';
    final password = b['password'] as String? ?? '';

    final user = await Database.instance.collection('users').findOne({'email': email});
    if (user == null || !verifyPassword(password, user['passwordHash'] as String)) {
      return fail('Invalid email or password', status: 401);
    }
    final token = signToken(
      userId: (user['_id'] as ObjectId).toHexString(),
      role: (user['role'] as String?) ?? 'user',
    );
    return ok({'user': User.publicView(user), 'token': token});
  }

  /// POST /auth/register-many  (admin only)
  /// Body: JSON array of {name, email, password, phone?} (max 200).
  static Future<Response> registerMany(RequestContext context) async {
    final guard = adminGuard(context);
    if (guard != null) return guard;

    dynamic body;
    try {
      body = await context.request.json();
    } catch (_) {}
    final list = body is List
        ? body
        : (body is Map && body['users'] is List ? body['users'] as List : null);
    if (list == null || list.isEmpty) return fail('Body must be a JSON array of users');
    if (list.length > 200) return fail('Maximum 200 users per request');

    final users = Database.instance.collection('users');
    final results = <Map<String, dynamic>>[];
    var created = 0;

    for (var i = 0; i < list.length; i++) {
      final b = list[i];
      if (b is! Map) {
        results.add({'index': i, 'status': 'invalid', 'message': 'not an object'});
        continue;
      }
      final name = (b['name'] as String?)?.trim() ?? '';
      final email = (b['email'] as String?)?.trim().toLowerCase() ?? '';
      final password = b['password'] as String? ?? '';
      if (name.isEmpty || !_emailRe.hasMatch(email) || password.length < 6) {
        results.add({'index': i, 'email': email, 'status': 'invalid',
            'message': 'name, valid email and password (>= 6) are required'});
        continue;
      }
      if (await users.findOne({'email': email}) != null) {
        results.add({'index': i, 'email': email, 'status': 'duplicate'});
        continue;
      }
      final doc = User(
        name: name,
        email: email,
        passwordHash: hashPassword(password),
        phone: b['phone'] as String?,
      ).toMap()
        ..['_id'] = ObjectId();
      await users.insertOne(doc);
      created++;
      results.add({'index': i, 'email': email, 'status': 'created'});
    }

    return ok(
      {'total': list.length, 'created': created, 'results': results},
      status: created > 0 ? 201 : 200,
    );
  }
}
