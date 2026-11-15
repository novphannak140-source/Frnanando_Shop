// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/database/mongo_database.dart';
import 'package:franando_shop_api/repositories/auth_middleware.dart';
import 'package:franando_shop_api/repositories/response_helper.dart';
import 'package:mongo_dart/mongo_dart.dart';

class NotificationController {
  static DbCollection get _col => Database.instance.collection('notifications');

  static Map<String, dynamic> _mine(String uid) => {
        r'$or': [
          {'userId': uid},
          {'userId': null}, // broadcast
        ],
      };

  static Future<Response> handle(RequestContext context) async {
    final user = context.read<AuthUser>();

    switch (context.request.method) {
      case HttpMethod.get:
        final docs = await _col
            .modernFind(
                filter: _mine(user.id), sort: {'createdAt': -1}, limit: 100)
            .toList();
        final items = docs.map((d) {
          final readBy = (d['readBy'] as List?) ?? [];
          return {...d, 'read': readBy.contains(user.id)}..remove('readBy');
        }).toList();
        return ok({
          'items': items,
          'unread': items.where((e) => e['read'] == false).length
        });

      // Admin: create (userId omitted = broadcast to everyone)
      case HttpMethod.post:
        final guard = adminGuard(context);
        if (guard != null) return guard;
        final b = await readJson(context);
        final title = b['title'] as String?;
        final body = b['body'] as String?;
        if (title == null || body == null)
          return fail('title and body are required');
        final doc = {
          '_id': ObjectId(),
          'userId': b['userId'],
          'title': title,
          'body': body,
          'type': b['type'] ?? 'general',
          'readBy': <String>[],
          'createdAt': DateTime.now().toUtc(),
        };
        await _col.insertOne(doc);
        return ok(doc, status: 201);

      // Mark read: { "id": "..." } or { "all": true }
      case HttpMethod.put:
      case HttpMethod.patch:
        final b = await readJson(context);
        final upd = {
          r'$addToSet': {'readBy': user.id}
        };
        if (b['all'] == true) {
          await _col.updateMany(_mine(user.id), upd);
          return ok({'updated': 'all'});
        }
        final id = parseId(b['id']);
        if (id == null) return fail('id or all=true is required');
        await _col.updateOne({'_id': id, ..._mine(user.id)}, upd);
        return ok({'updated': id.toHexString()});

      default:
        return methodNotAllowed();
    }
  }
}
