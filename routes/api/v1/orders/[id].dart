// ignore_for_file: file_names

import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/controllers/order_controller.dart';

// GET track order · PUT|PATCH update status
Future<Response> onRequest(RequestContext context, String id) =>
    OrderController.handleItem(context, id);
