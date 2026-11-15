import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/database/mongo_database.dart';
import 'package:franando_shop_api/models/coupon.dart';
import 'package:franando_shop_api/repositories/auth_middleware.dart';
import 'package:franando_shop_api/repositories/response_helper.dart';
import 'package:mongo_dart/mongo_dart.dart';

typedef CouponResult = ({Map<String, dynamic>? coupon, double discount, String? error});

class CouponController {
  static DbCollection get _col => Database.instance.collection('coupons');

  /// Validates a coupon code for a given subtotal and computes the discount.
  static Future<CouponResult> evaluate(String code, double subtotal) async {
    final c = await _col.findOne({'code': code.trim().toUpperCase()});
    if (c == null || c['active'] != true) return (coupon: null, discount: 0.0, error: 'Invalid coupon');

    final exp = c['expiresAt'];
    if (exp is DateTime && exp.isBefore(DateTime.now().toUtc())) {
      return (coupon: null, discount: 0.0, error: 'Coupon expired');
    }
    final limit = c['usageLimit'];
    if (limit is int && (c['usedCount'] as int) >= limit) {
      return (coupon: null, discount: 0.0, error: 'Coupon usage limit reached');
    }
    final minOrder = (c['minOrder'] as num).toDouble();
    if (subtotal < minOrder) {
      return (coupon: null, discount: 0.0, error: 'Minimum order is \$${minOrder.toStringAsFixed(2)}');
    }

    var discount = c['type'] == 'percent'
        ? subtotal * (c['value'] as num).toDouble() / 100
        : (c['value'] as num).toDouble();
    final max = c['maxDiscount'];
    if (max is num && discount > max) discount = max.toDouble();
    if (discount > subtotal) discount = subtotal;
    return (coupon: c, discount: double.parse(discount.toStringAsFixed(2)), error: null);
  }

  /// GET /coupons (list active) · POST /coupons (admin create)
  static Future<Response> handleIndex(RequestContext context) async {
    switch (context.request.method) {
      case HttpMethod.get:
        final now = DateTime.now().toUtc();
        final all = await _col.modernFind(filter: {'active': true}, sort: {'createdAt': -1}).toList();
        final valid = all.where((c) {
          final exp = c['expiresAt'];
          return !(exp is DateTime && exp.isBefore(now));
        }).toList();
        return ok(valid);
      case HttpMethod.post:
        final guard = adminGuard(context);
        if (guard != null) return guard;
        try {
          final doc = Coupon.parse(await readJson(context));
          if (await _col.findOne({'code': doc['code']}) != null) {
            return fail('Coupon code already exists', status: 409);
          }
          doc['_id'] = ObjectId();
          await _col.insertOne(doc);
          return ok(doc, status: 201);
        } on FormatException catch (e) {
          return fail(e.message);
        }
      default:
        return methodNotAllowed();
    }
  }

  /// POST /coupons/apply  { code, subtotal }
  static Future<Response> apply(RequestContext context) async {
    if (context.request.method != HttpMethod.post) return methodNotAllowed();
    if (authenticate(context) == null) return fail('Unauthorized', status: 401);

    final b = await readJson(context);
    final code = b['code'] as String? ?? '';
    final subtotal = b['subtotal'];
    if (code.isEmpty || subtotal is! num) return fail('code and subtotal are required');

    final r = await evaluate(code, subtotal.toDouble());
    if (r.error != null) return fail(r.error!);
    return ok({
      'code': r.coupon!['code'],
      'discount': r.discount,
      'total': double.parse((subtotal - r.discount).toStringAsFixed(2)),
    });
  }
}
