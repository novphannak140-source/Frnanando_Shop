import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/controllers/cart_controller.dart';

// GET view · POST add · PUT set qty · DELETE (?productId=) remove/clear
Future<Response> onRequest(RequestContext context) => CartController.handle(context);
