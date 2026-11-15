import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/controllers/order_controller.dart';

// GET my orders · POST create order from cart
Future<Response> onRequest(RequestContext context) => OrderController.handleIndex(context);
