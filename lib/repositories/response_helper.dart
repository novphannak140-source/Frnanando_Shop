// ignore_for_file: deprecated_member_use

import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';

Response ok(Object? data, {int status = 200}) => Response.json(
    statusCode: status, body: {'success': true, 'data': serialize(data)});

Response fail(String message, {int status = 400}) => Response.json(
    statusCode: status, body: {'success': false, 'message': message});

Response methodNotAllowed() => fail('Method not allowed', status: 405);

Future<Map<String, dynamic>> readJson(RequestContext context) async {
  try {
    final body = await context.request.json();
    if (body is Map) return Map<String, dynamic>.from(body);
  } catch (_) {}
  return {};
}

ObjectId? parseId(Object? value) {
  if (value is ObjectId) return value;
  if (value is! String) return null;
  try {
    return ObjectId.fromHexString(value);
  } catch (_) {
    return null;
  }
}

dynamic serialize(dynamic v) {
  if (v is ObjectId) return v.toHexString();
  if (v is DateTime) return v.toUtc().toIso8601String();
  if (v is List) return v.map(serialize).toList();
  if (v is Map) {
    final out = <String, dynamic>{};
    v.forEach(
        (k, val) => out[k == '_id' ? 'id' : k.toString()] = serialize(val));
    return out;
  }
  return v;
}

({int page, int limit}) paging(Map<String, String> q) => (
      page: (int.tryParse(q['page'] ?? '') ?? 1).clamp(1, 100000),
      limit: (int.tryParse(q['limit'] ?? '') ?? 20).clamp(1, 100),
    );
