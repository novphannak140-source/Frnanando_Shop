// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures

import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/database/mongo_database.dart';
import 'package:franando_shop_api/models/product.dart';
import 'package:franando_shop_api/repositories/auth_middleware.dart';
import 'package:franando_shop_api/repositories/response_helper.dart';
import 'package:mongo_dart/mongo_dart.dart';

class CartController {
  static DbCollection get _carts => Database.instance.collection('carts');

  static Future<Map<String, dynamic>> view(String uid) async {
    final cart = await _carts.findOne({'userId': uid});
    final raw = List<Map<String, dynamic>>.from(
      ((cart?['items'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final ids = raw.map((e) => e['productId']).toList();
    final products = ids.isEmpty
        ? <Map<String, dynamic>>[]
        : await Database.instance.collection('products').find({
            '_id': {r'$in': ids}
          }).toList();
    final byId = {
      for (final p in products) (p['_id'] as ObjectId).toHexString(): p
    };

    var subtotal = 0.0;
    final lines = <Map<String, dynamic>>[];
    for (final it in raw) {
      final p = byId[(it['productId'] as ObjectId).toHexString()];
      if (p == null) continue;
      final qty = it['quantity'] as int;
      final price = Product.unitPrice(p);
      subtotal += price * qty;
      lines.add({
        'productId': it['productId'],
        'name': p['name'],
        'image': (p['images'] as List).isNotEmpty
            ? (p['images'] as List).first
            : null,
        'price': price,
        'quantity': qty,
        'stock': p['stock'],
        'lineTotal': double.parse((price * qty).toStringAsFixed(2)),
      });
    }
    return {
      'items': lines,
      'itemCount': lines.fold<int>(0, (s, l) => s + (l['quantity'] as int)),
      'subtotal': double.parse(subtotal.toStringAsFixed(2)),
    };
  }

  static Future<void> _save(
      String uid, List<Map<String, dynamic>> items) async {
    final existing = await _carts.findOne({'userId': uid});
    final now = DateTime.now().toUtc();
    if (existing == null) {
      await _carts.insertOne(
          {'_id': ObjectId(), 'userId': uid, 'items': items, 'updatedAt': now});
    } else {
      await _carts.updateOne({
        'userId': uid
      }, {
        r'$set': {'items': items, 'updatedAt': now}
      });
    }
  }

  static Future<List<Map<String, dynamic>>> _items(String uid) async {
    final cart = await _carts.findOne({'userId': uid});
    return ((cart?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Empties a user's cart (used after checkout).
  static Future<void> handleClear(String uid) => _save(uid, []);

  static Future<Response> handle(RequestContext context) async {
    final user = context.read<AuthUser>();
    final uid = user.id;

    switch (context.request.method) {
      case HttpMethod.get:
        return ok(await view(uid));

      // Add item (increments quantity if already in cart)
      case HttpMethod.post:
        final b = await readJson(context);
        final pid = parseId(b['productId']);
        final qty = (b['quantity'] as int?) ?? 1;
        if (pid == null) return fail('productId is required');
        if (qty < 1) return fail('quantity must be >= 1');
        final product = await Database.instance
            .collection('products')
            .findOne({'_id': pid});
        if (product == null) return fail('Product not found', status: 404);

        final items = await _items(uid);
        final i = items.indexWhere((e) => (e['productId'] as ObjectId) == pid);
        final newQty = (i >= 0 ? items[i]['quantity'] as int : 0) + qty;
        if (newQty > (product['stock'] as int)) return fail('Not enough stock');
        if (i >= 0) {
          items[i]['quantity'] = newQty;
        } else {
          items.add({'productId': pid, 'quantity': qty});
        }
        await _save(uid, items);
        return ok(await view(uid), status: 201);

      // Set exact quantity (0 removes)
      case HttpMethod.put:
      case HttpMethod.patch:
        final b = await readJson(context);
        final pid = parseId(b['productId']);
        final qty = b['quantity'];
        if (pid == null || qty is! int || qty < 0) {
          return fail('productId and quantity (>= 0) are required');
        }
        final items = await _items(uid);
        final i = items.indexWhere((e) => (e['productId'] as ObjectId) == pid);
        if (i < 0) return fail('Item not in cart', status: 404);
        if (qty == 0) {
          items.removeAt(i);
        } else {
          final product = await Database.instance
              .collection('products')
              .findOne({'_id': pid});
          if (product == null || qty > (product['stock'] as int))
            return fail('Not enough stock');
          items[i]['quantity'] = qty;
        }
        await _save(uid, items);
        return ok(await view(uid));

      // DELETE ?productId=xxx removes one item; no param clears the cart
      case HttpMethod.delete:
        final pid = parseId(context.request.uri.queryParameters['productId']);
        final items = pid == null
            ? <Map<String, dynamic>>[]
            : (await _items(uid))
                .where((e) => (e['productId'] as ObjectId) != pid)
                .toList();
        await _save(uid, items);
        return ok(await view(uid));

      default:
        return methodNotAllowed();
    }
  }
}
