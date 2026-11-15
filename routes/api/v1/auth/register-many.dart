// ignore_for_file: file_names

import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/controllers/auth_controller.dart';
import 'package:franando_shop_api/repositories/response_helper.dart';

// POST /auth/register-many (admin) — body is a JSON array of users
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) return methodNotAllowed();
  return AuthController.registerMany(context);
}
