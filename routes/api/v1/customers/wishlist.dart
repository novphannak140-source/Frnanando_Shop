import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/controllers/customer_controller.dart';

// GET wishlist · POST add · DELETE (?productId=) remove / clear
Future<Response> onRequest(RequestContext context) => CustomerController.wishlist(context);
