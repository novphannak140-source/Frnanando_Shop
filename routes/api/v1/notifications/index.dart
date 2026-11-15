import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/controllers/notification_controller.dart';

Future<Response> onRequest(RequestContext context) => NotificationController.handle(context);
