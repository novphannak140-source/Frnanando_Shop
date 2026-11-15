// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/database/mongo_database.dart';
import 'package:franando_shop_api/repositories/auth_middleware.dart';
import 'package:franando_shop_api/repositories/response_helper.dart';
import 'package:mongo_dart/mongo_dart.dart';

class ChatController {
  static DbCollection get _col => Database.instance.collection('chat_messages');

  static Future<Response> handle(RequestContext context) async {
    final user = context.read<AuthUser>();
    final q = context.request.uri.queryParameters;

    switch (context.request.method) {
      // Customer: own thread. Admin: ?userId=<customer> (omit to list latest messages from all)
      case HttpMethod.get:
        final filter = <String, dynamic>{};
        if (!user.isAdmin) {
          filter['threadId'] = user.id;
        } else if (q['userId'] != null) {
          filter['threadId'] = q['userId'];
        }
        final since = DateTime.tryParse(q['since'] ?? '');
        if (since != null) filter['createdAt'] = {r'$gt': since.toUtc()};
        final msgs = await _col
            .modernFind(filter: filter, sort: {'createdAt': 1}, limit: 200)
            .toList();
        return ok(msgs);

      case HttpMethod.post:
        final b = await readJson(context);
        final text = (b['text'] as String?)?.trim() ?? '';
        if (text.isEmpty) return fail('text is required');
        final threadId = user.isAdmin ? b['userId'] as String? : user.id;
        if (threadId == null)
          return fail('userId is required for admin replies');
        final doc = {
          '_id': ObjectId(),
          'threadId': threadId,
          'senderId': user.id,
          'senderRole': user.role,
          'text': text,
          'createdAt': DateTime.now().toUtc(),
        };
        await _col.insertOne(doc);
        return ok(doc, status: 201);

      default:
        return methodNotAllowed();
    }
  }
}
