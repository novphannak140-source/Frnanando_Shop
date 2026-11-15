import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/controllers/coupon_controller.dart';

Future<Response> onRequest(RequestContext context) => CouponController.handleIndex(context);
