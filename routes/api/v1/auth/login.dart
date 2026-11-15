import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/controllers/auth_controller.dart';
import 'package:franando_shop_api/repositories/response_helper.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) return methodNotAllowed();
  return AuthController.login(context);
}
