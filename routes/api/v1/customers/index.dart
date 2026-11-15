import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/controllers/customer_controller.dart';

// GET profile · PUT|PATCH edit profile / change password
Future<Response> onRequest(RequestContext context) => CustomerController.profile(context);
