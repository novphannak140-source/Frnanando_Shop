import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) {
  return Response.json(body: {
    'name': 'Franando Shop API',
    'version': '1.0.0',
    'status': 'ok',
    'endpoints': [
      '/auth/register', '/auth/register-many', '/auth/login', '/customers', '/customers/wishlist', '/products', '/categories', '/cart',
      '/orders', '/coupons', '/coupons/apply', '/notifications', '/chat',
      '/payments/bakong-qr', '/payments/paypal-capture',
    ],
  });
}
