// ignore_for_file: file_names
import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/controllers/payment_controller.dart';

Future<Response> onRequest(RequestContext context) =>
    PaymentController.checkPayment(context);
