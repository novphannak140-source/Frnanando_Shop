// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/controllers/cart_controller.dart';
import 'package:franando_shop_api/controllers/coupon_controller.dart';
import 'package:franando_shop_api/database/mongo_database.dart';
import 'package:franando_shop_api/models/order.dart';
// import 'package:franando_shop_api/models/product.dart';
import 'package:franando_shop_api/repositories/auth_middleware.dart';
import 'package:franando_shop_api/repositories/env.dart';
import 'package:franando_shop_api/repositories/response_helper.dart';
import 'package:mongo_dart/mongo_dart.dart';

class OrderController {
  static DbCollection get _col => Database.instance.collection('orders');
  static DbCollection get _products => Database.instance.collection('products');

  static Future<Response> handleIndex(RequestContext context) async {
    final user = context.read<AuthUser>();
    switch (context.request.method) {
      case HttpMethod.get:
        final q = context.request.uri.queryParameters;
        final p = paging(q);
        final filter = <String, dynamic>{};
        if (!user.isAdmin) {
          filter['userId'] = user.id;
        } else if (q['userId'] != null) {
          filter['userId'] = q['userId'];
        }
        if (q['status'] != null) filter['status'] = q['status'];
        final items = await _col
            .modernFind(
                filter: filter,
                sort: {'createdAt': -1},
                skip: (p.page - 1) * p.limit,
                limit: p.limit)
            .toList();
        final total = await _col.count(filter);
        return ok(
            {'items': items, 'total': total, 'page': p.page, 'limit': p.limit});
      case HttpMethod.post:
        return _create(context, user);
      default:
        return methodNotAllowed();
    }
  }

  /// Creates an order from the user's cart.
  static Future<Response> _create(RequestContext context, AuthUser user) async {
    final b = await readJson(context);
    final address = b['shippingAddress'];
    final method = (b['paymentMethod'] as String?) ?? 'cod';
    if (address is! Map) return fail('shippingAddress is required');
    if (!PaymentMethod.all.contains(method)) {
      return fail(
          'paymentMethod must be one of ${PaymentMethod.all.join(', ')}');
    }

    final cart = await CartController.view(user.id);
    final lines = (cart['items'] as List).cast<Map<String, dynamic>>();
    if (lines.isEmpty) return fail('Cart is empty');

    final subtotal = (cart['subtotal'] as num).toDouble();

    // coupon
    var discount = 0.0;
    String? couponCode;
    final code = b['couponCode'] as String?;
    if (code != null && code.isNotEmpty) {
      final r = await CouponController.evaluate(code, subtotal);
      if (r.error != null) return fail(r.error!);
      discount = r.discount;
      couponCode = r.coupon!['code'] as String;
    }

    // reserve stock atomically (roll back on failure)
    final reserved = <Map<String, dynamic>>[];
    for (final l in lines) {
      final qty = l['quantity'] as int;
      final res = await _products.updateOne(
        {
          '_id': l['productId'],
          'stock': {r'$gte': qty}
        },
        {
          r'$inc': {'stock': -qty}
        },
      );
      if (res.nModified != 1) {
        for (final r in reserved) {
          await _products.updateOne({
            '_id': r['productId']
          }, {
            r'$inc': {'stock': r['quantity']}
          });
        }
        return fail('Insufficient stock for "${l['name']}"', status: 409);
      }
      reserved.add(l);
    }

    final shipping = double.tryParse(Env.get('SHIPPING_FEE', '0')) ?? 0;
    final total =
        double.parse((subtotal - discount + shipping).toStringAsFixed(2));
    final now = DateTime.now().toUtc();
    final orderId = ObjectId();
    final order = {
      '_id': orderId,
      'orderNo': 'FR${now.millisecondsSinceEpoch}',
      'userId': user.id,
      'items': lines,
      'subtotal': subtotal,
      'discount': discount,
      'shippingFee': shipping,
      'total': total,
      'currency': 'USD',
      'couponCode': couponCode,
      'shippingAddress': address,
      'note': b['note'],
      'paymentMethod': method,
      'paymentStatus': 'unpaid',
      'status': OrderStatus.pending,
      'history': [
        {'status': OrderStatus.pending, 'at': now},
      ],
      'createdAt': now,
    };
    await _col.insertOne(order);

    if (couponCode != null) {
      await Database.instance.collection('coupons').updateOne({
        'code': couponCode
      }, {
        r'$inc': {'usedCount': 1}
      });
    }
    await CartController.handleClear(user.id);
    return ok(order, status: 201);
  }

  static Future<Response> handleItem(RequestContext context, String id) async {
    final user = context.read<AuthUser>();
    final oid = parseId(id);
    if (oid == null) return fail('Invalid id');

    final order = await _col.findOne({'_id': oid});
    if (order == null) return fail('Order not found', status: 404);
    if (!user.isAdmin && order['userId'] != user.id)
      return fail('Forbidden', status: 403);

    switch (context.request.method) {
      case HttpMethod.get:
        return ok(order); // includes `status` + `history` for tracking

      case HttpMethod.put:
      case HttpMethod.patch:
        final b = await readJson(context);
        final status = b['status'] as String?;
        if (status == null || !OrderStatus.all.contains(status)) {
          return fail('status must be one of ${OrderStatus.all.join(', ')}');
        }
        // customers may only cancel their own pending orders
        if (!user.isAdmin &&
            !(status == OrderStatus.cancelled &&
                order['status'] == OrderStatus.pending)) {
          return fail('Forbidden: you can only cancel a pending order',
              status: 403);
        }
        if (order['status'] == OrderStatus.cancelled)
          return fail('Order already cancelled');

        if (status == OrderStatus.cancelled) {
          for (final it in (order['items'] as List).cast<Map>()) {
            await _products.updateOne(
              {'_id': it['productId']},
              {
                r'$inc': {'stock': it['quantity']}
              },
            );
          }
        }
        final set = <String, dynamic>{
          'status': status,
          'updatedAt': DateTime.now().toUtc()
        };
        if (status == OrderStatus.paid) set['paymentStatus'] = 'paid';
        await _col.updateOne({
          '_id': oid
        }, {
          r'$set': set,
          r'$push': {
            'history': {
              'status': status,
              'at': DateTime.now().toUtc(),
              'note': b['note']
            }
          },
        });
        return ok(await _col.findOne({'_id': oid}));

      default:
        return methodNotAllowed();
    }
  }
}
