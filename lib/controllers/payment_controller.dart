// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/database/mongo_database.dart';
import 'package:franando_shop_api/models/order.dart';
import 'package:franando_shop_api/services/bakong_service.dart';
import 'package:franando_shop_api/services/paypal_service.dart';
import 'package:franando_shop_api/repositories/auth_middleware.dart';
import 'package:franando_shop_api/repositories/env.dart';
import 'package:franando_shop_api/repositories/response_helper.dart';
import 'package:mongo_dart/mongo_dart.dart';

class PaymentController {
  static DbCollection get _orders => Database.instance.collection('orders');
  static DbCollection get _payments => Database.instance.collection('payments');

  static Future _ownedOrder(AuthUser user, Object? orderId) async {
    final oid = parseId(orderId);
    if (oid == null) return null;
    final o = await _orders.findOne({'_id': oid});
    if (o == null || (!user.isAdmin && o['userId'] != user.id)) return null;
    return o;
  }

  static Future<bool> _markPaid(ObjectId orderId,
      [Map<String, dynamic>? tx, ObjectId? paymentId]) async {
    final transaction = tx ?? <String, dynamic>{};
    final now = DateTime.now().toUtc();
    final orderSet = <String, dynamic>{
      'status': OrderStatus.paid,
      'paymentStatus': 'paid',
      'paidAt': now,
      'updatedAt': now,
    };
    if (transaction['hash'] != null) {
      orderSet['bakongTransactionHash'] = transaction['hash'];
    }
    final result = await _orders.updateOne(
      {
        '_id': orderId,
        'paymentStatus': {r'$ne': 'paid'}
      },
      {
        r'$set': {
          ...orderSet,
        },
        r'$push': {
          'history': {
            'status': OrderStatus.paid,
            'at': now,
            'note': 'Payment confirmed'
          }
        },
      },
    );

    final paidOrder = await _orders.findOne({'_id': orderId});
    if (paidOrder == null) return false;
    final transitionedNow = result.nModified == 1;
    final alreadyPaid = paidOrder['paymentStatus'] == 'paid';
    if (!transitionedNow && !alreadyPaid) return false;

    final notifications = Database.instance.collection('notifications');
    if (paymentId != null &&
        await notifications.findOne({'paymentId': paymentId}) != null) {
      return true;
    }
    if (transitionedNow || paymentId != null) {
      await notifications.insertOne({
        '_id': ObjectId(),
        'userId': paidOrder['userId'],
        'title': 'Payment received',
        'body':
            'Your payment for order ${paidOrder['orderNo'] ?? orderId.oid} was confirmed successfully.',
        'type': 'payment_success',
        'orderId': orderId,
        'paymentId': paymentId,
        'transactionHash': transaction['hash'],
        'readBy': <String>[],
        'createdAt': now,
      });
    }
    return true;
  }

  static bool _matchesExpectedPayment({
    required Map<String, dynamic> transaction,
    required Map<String, dynamic> payment,
  }) {
    final receiver =
        (transaction['toAccountId'] ?? '').toString().trim().toLowerCase();
    final expectedReceiver = BakongService.accountId.toLowerCase();
    final currency = (transaction['currency'] ?? '').toString().toUpperCase();
    final expectedCurrency =
        (payment['currency'] ?? '').toString().toUpperCase();
    final actualAmount = num.tryParse('${transaction['amount']}');
    final expectedAmount = num.tryParse('${payment['amount']}');
    if (receiver.isEmpty ||
        expectedReceiver.isEmpty ||
        receiver != expectedReceiver) return false;
    if (currency != expectedCurrency ||
        actualAmount == null ||
        expectedAmount == null) return false;
    final tolerance = currency == 'KHR' ? 0.0 : 0.005;
    return (actualAmount - expectedAmount).abs() <= tolerance;
  }

  static Future<Response> bakong(RequestContext context) async {
    final user = context.read<AuthUser>();

    if (context.request.method == HttpMethod.get) {
      final md5 = context.request.uri.queryParameters['md5'];
      if (md5 == null || md5.isEmpty) return fail('md5 is required');
      if (!RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(md5)) {
        return fail('Invalid md5 value.');
      }
      final payment = await _payments.findOne({'md5': md5, 'method': 'bakong'});
      if (payment == null) return fail('Payment not found', status: 404);
      if (!user.isAdmin && payment['userId'] != user.id) {
        return fail('Forbidden', status: 403);
      }
      if (payment['status'] == 'successfully' || payment['status'] == 'paid') {
        return ok({'status': 'successfully'});
      }

      final expiresAt = payment['expiresAt'];
      if (expiresAt is DateTime &&
          DateTime.now().toUtc().isAfter(expiresAt.toUtc())) {
        await _payments.updateOne({
          '_id': payment['_id'],
          'status': 'pending'
        }, {
          r'$set': {'status': 'expired', 'updatedAt': DateTime.now().toUtc()},
        });
        return ok({'status': 'expired'});
      }

      try {
        final transaction = await BakongService.checkTransactionByMd5(md5);
        if (transaction == null) return ok({'status': 'pending'});
        if (!_matchesExpectedPayment(
            transaction: transaction, payment: payment)) {
          return fail(
              'Bakong transaction does not match this order. Contact support.',
              status: 409);
        }

        await _markPaid(payment['orderId'] as ObjectId, transaction,
            payment['_id'] as ObjectId);
        await _payments.updateOne({
          '_id': payment['_id']
        }, {
          r'$set': {
            'status': 'successfully', // <--- ដូរជា successfully
            'transactionHash': transaction['hash'],
            'transaction': transaction,
            'paidAt': DateTime.now().toUtc(),
          },
        });
        return ok(
            {'status': 'successfully', 'transactionHash': transaction['hash']});
      } on StateError catch (e) {
        return fail(e.message, status: 503);
      } on Exception {
        return fail('Could not verify payment with Bakong. Please retry.',
            status: 502);
      }
    }

    if (context.request.method != HttpMethod.post) return methodNotAllowed();

    final b = await readJson(context);
    final order = await _ownedOrder(user, b['orderId']);
    if (order == null) return fail('Order not found', status: 404);
    if (order['paymentStatus'] == 'paid') {
      return fail('Order already paid', status: 409);
    }
    if (order['status'] == OrderStatus.cancelled) {
      return fail('Cancelled orders cannot be paid.', status: 409);
    }

    final currency =
        ((b['currency'] as String?) ?? (order['currency'] as String?) ?? 'USD')
            .toUpperCase();
    if (currency != 'USD' && currency != 'KHR') {
      return fail('currency must be USD or KHR');
    }
    final orderCurrency =
        ((order['currency'] as String?) ?? 'USD').toUpperCase();
    var amount = (order['total'] as num).toDouble();
    if (currency != orderCurrency) {
      final rate = double.tryParse(Env.get('BAKONG_USD_KHR_RATE'));
      if (currency == 'KHR' &&
          orderCurrency == 'USD' &&
          rate != null &&
          rate > 0) {
        amount = (amount * rate).roundToDouble();
      } else {
        return fail(
            'Currency conversion is not configured. Set BAKONG_USD_KHR_RATE or use $orderCurrency.');
      }
    }

    try {
      final qr = BakongService.generateKhqr(
        amount: amount,
        currency: currency,
        billNumber:
            (order['orderNo'] as String?) ?? (order['_id'] as ObjectId).oid,
      );
      final paymentId = ObjectId();
      await _payments.insertOne({
        '_id': paymentId,
        'orderId': order['_id'],
        'userId': order['userId'],
        'method': 'bakong',
        'qr': qr.qr,
        'md5': qr.md5,
        'amount': amount,
        'currency': currency,
        'status': 'pending',
        'expiresAt': qr.expiresAt,
        'createdAt': DateTime.now().toUtc(),
      });
      return ok({
        'paymentId': paymentId.oid,
        'qr': qr.qr,
        'md5': qr.md5,
        'amount': amount,
        'currency': currency,
        'expiresAt': qr.expiresAt.toIso8601String(),
        'expiresInSeconds': BakongService.maxQrLifetimeMinutes * 60,
        'status': 'pending',
        'checkPaymentUrl': '/payments/bakong-qr?md5=${qr.md5}',
      }, status: 201);
    } on StateError catch (e) {
      return fail(e.message, status: 503);
    } on ArgumentError catch (e) {
      return fail(e.message?.toString() ?? 'Invalid payment request.');
    } on Exception {
      return fail(
          'Could not generate KHQR. Check Bakong merchant configuration.',
          status: 500);
    }
  }

  static Future<Response> paypalCapture(RequestContext context) async {
    if (context.request.method != HttpMethod.post) return methodNotAllowed();
    final user = context.read<AuthUser>();
    final b = await readJson(context);
    final paypalOrderId = b['paypalOrderId'] as String?;
    final order = await _ownedOrder(user, b['orderId']);
    if (order == null || paypalOrderId == null) {
      return fail('orderId and paypalOrderId are required');
    }
    if (order['paymentStatus'] == 'paid') {
      return fail('Order already paid', status: 409);
    }

    try {
      final result = await PayPalService.capture(paypalOrderId);
      final capture = (((result['purchase_units'] as List).first
          as Map)['payments'] as Map)['captures'] as List;
      final c = capture.first as Map;
      final paid = double.tryParse('${(c['amount'] as Map)['value']}') ?? 0;
      if (c['status'] != 'COMPLETED' ||
          paid + 0.001 < (order['total'] as num).toDouble()) {
        return fail('Payment not completed or amount mismatch', status: 402);
      }
      await _payments.insertOne({
        '_id': ObjectId(),
        'orderId': order['_id'],
        'userId': order['userId'],
        'method': 'paypal',
        'paypalOrderId': paypalOrderId,
        'amount': paid,
        'status': 'successfully', // <--- ដូរជា successfully
        'createdAt': DateTime.now().toUtc(),
      });
      await _markPaid(order['_id'] as ObjectId);
      return ok({'status': 'successfully', 'paypalOrderId': paypalOrderId});
    } catch (e) {
      return fail('PayPal error: $e', status: 502);
    }
  }

  static Future<Response> checkPayment(RequestContext context) async {
    final queryParams = context.request.url.queryParameters;
    final md5 = queryParams['md5'];

    if (md5 == null || md5.isEmpty) {
      return fail('md5 query parameter is required', status: 400);
    }

    final paymentsCollection = Database.instance.collection('payments');
    final payment = await paymentsCollection.findOne({'md5': md5});

    if (payment == null) {
      return fail('Payment record not found', status: 404);
    }

    final dbStatus = payment['status'] ?? 'pending';
    final displayStatus = (dbStatus == 'paid' || dbStatus == 'successfully')
        ? 'successfully'
        : dbStatus;

    return ok({
      'success': true,
      'data': {
        'paymentId': payment['_id']?.toString(),
        'status': displayStatus,
        'amount': payment['amount'],
        'currency': payment['currency'],
        'checkPaymentUrl': payment['checkPaymentUrl'],
      },
    });
  }
}
