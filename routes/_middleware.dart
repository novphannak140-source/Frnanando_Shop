import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/repositories/response_helper.dart';

const _cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization, Accept',
};

Handler middleware(Handler handler) {
  return handler.use(requestLogger()).use(corsAndErrors());
}

Middleware corsAndErrors() => (handler) => (context) async {
      if (context.request.method == HttpMethod.options) {
        return Response(statusCode: 204, headers: _cors);
      }
      try {
        final res = await handler(context);
        return res.copyWith(headers: {...res.headers, ..._cors});
      } catch (e) {
        // ignore: avoid_print
        print('Unhandled error: $e');
        return fail('Internal server error', status: 500).copyWith(headers: _cors);
      }
    };
