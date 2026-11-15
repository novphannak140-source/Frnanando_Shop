// ignore_for_file: deprecated_member_use

import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/database/mongo_database.dart';
import 'package:franando_shop_api/models/customer.dart';
import 'package:franando_shop_api/models/user.dart';
import 'package:franando_shop_api/repositories/auth_middleware.dart';
import 'package:franando_shop_api/repositories/password_helper.dart';
import 'package:franando_shop_api/repositories/response_helper.dart';
import 'package:mongo_dart/mongo_dart.dart';

class CustomerController {
  static DbCollection get _users => Database.instance.collection('users');
  static DbCollection get _wishlists =>
      Database.instance.collection('wishlists');

  static Future<Response> profile(RequestContext context) async {
    final me = context.read<AuthUser>();

    switch (context.request.method) {
      case HttpMethod.get:
        var targetId = parseId(me.id);
        final other = context.request.uri.queryParameters['id'];
        if (other != null) {
          if (!me.isAdmin) return fail('Forbidden: admin only', status: 403);
          targetId = parseId(other);
        }
        if (targetId == null) return fail('Invalid id');
        final user = await _users.findOne({'_id': targetId});
        if (user == null) return fail('Customer not found', status: 404);
        final wl = await _wishlists.findOne({'userId': targetId.toHexString()});
        final orders = await Database.instance
            .collection('orders')
            .count({'userId': targetId.toHexString()});
        return ok({
          ...User.publicView(user),
          'wishlistCount': ((wl?['productIds'] as List?) ?? []).length,
          'orderCount': orders,
        });

      case HttpMethod.put:
      case HttpMethod.patch:
        final uid = parseId(me.id);
        if (uid == null) return fail('Invalid token', status: 401);
        final body = await readJson(context);
        try {
          final changes = Customer.parseUpdate(body);

          final newPw = body['newPassword'];
          if (newPw != null) {
            if (newPw is! String || newPw.length < 6) {
              return fail('newPassword must be at least 6 characters');
            }
            final user = await _users.findOne({'_id': uid});
            final current = body['currentPassword'] as String? ?? '';
            if (user == null ||
                !verifyPassword(current, user['passwordHash'] as String)) {
              return fail('currentPassword is incorrect', status: 401);
            }
            changes['passwordHash'] = hashPassword(newPw);
          }

          if (changes.isEmpty) return fail('Nothing to update');
          changes['updatedAt'] = DateTime.now().toUtc();
          await _users.updateOne({'_id': uid}, {r'$set': changes});
          final updated = await _users.findOne({'_id': uid});
          return ok(User.publicView(updated!));
        } on FormatException catch (e) {
          return fail(e.message);
        }

      default:
        return methodNotAllowed();
    }
  }

  /// GET    /customers/wishlist               -> wishlist with product details
  /// POST   /customers/wishlist {productId}   -> add
  /// DELETE /customers/wishlist?productId=    -> remove (no param = clear all)
  static Future<Response> wishlist(RequestContext context) async {
    final uid = context.read<AuthUser>().id;

    Future<Map<String, dynamic>> view() async {
      final wl = await _wishlists.findOne({'userId': uid});
      final ids = ((wl?['productIds'] as List?) ?? []).toList();
      final products = ids.isEmpty
          ? <Map<String, dynamic>>[]
          : await Database.instance.collection('products').find({
              '_id': {r'$in': ids}
            }).toList();
      return {'items': products, 'count': products.length};
    }

    switch (context.request.method) {
      case HttpMethod.get:
        return ok(await view());

      case HttpMethod.post:
        final b = await readJson(context);
        final pid = Customer.productId(b['productId']);
        if (pid == null) return fail('productId is required');
        if (await Database.instance
                .collection('products')
                .findOne({'_id': pid}) ==
            null) {
          return fail('Product not found', status: 404);
        }
        final existing = await _wishlists.findOne({'userId': uid});
        if (existing == null) {
          await _wishlists.insertOne({
            '_id': ObjectId(),
            'userId': uid,
            'productIds': [pid],
            'updatedAt': DateTime.now().toUtc(),
          });
        } else {
          await _wishlists.updateOne(
            {'userId': uid},
            {
              r'$addToSet': {'productIds': pid},
              r'$set': {'updatedAt': DateTime.now().toUtc()}
            },
          );
        }
        return ok(await view(), status: 201);

      case HttpMethod.delete:
        final pid = Customer.productId(
            context.request.uri.queryParameters['productId']);
        final update = pid == null
            ? {
                r'$set': {'productIds': <ObjectId>[]}
              }
            : {
                r'$pull': {'productIds': pid}
              };
        await _wishlists.updateOne({'userId': uid}, update);
        return ok(await view());

      default:
        return methodNotAllowed();
    }
  }
}
