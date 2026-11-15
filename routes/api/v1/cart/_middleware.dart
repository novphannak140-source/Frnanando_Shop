import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/repositories/auth_middleware.dart';

Handler middleware(Handler handler) => handler.use(requireAuth());
