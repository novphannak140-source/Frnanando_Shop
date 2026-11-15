// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, implicit_dynamic_list_literal

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import '../main.dart' as entrypoint;
import '../routes/index.dart' as index;
import '../routes/api/v1/products/index.dart' as api_v1_products_index;
import '../routes/api/v1/products/bulk.dart' as api_v1_products_bulk;
import '../routes/api/v1/products/[id].dart' as api_v1_products_$id;
import '../routes/api/v1/payments/paypal-capture.dart' as api_v1_payments_paypal_capture;
import '../routes/api/v1/payments/check.dart' as api_v1_payments_check;
import '../routes/api/v1/payments/bakong-qr.dart' as api_v1_payments_bakong_qr;
import '../routes/api/v1/orders/index.dart' as api_v1_orders_index;
import '../routes/api/v1/orders/[id].dart' as api_v1_orders_$id;
import '../routes/api/v1/notifications/index.dart' as api_v1_notifications_index;
import '../routes/api/v1/customers/wishlist.dart' as api_v1_customers_wishlist;
import '../routes/api/v1/customers/index.dart' as api_v1_customers_index;
import '../routes/api/v1/coupons/index.dart' as api_v1_coupons_index;
import '../routes/api/v1/coupons/apply.dart' as api_v1_coupons_apply;
import '../routes/api/v1/chat/index.dart' as api_v1_chat_index;
import '../routes/api/v1/categories/index.dart' as api_v1_categories_index;
import '../routes/api/v1/categories/[id].dart' as api_v1_categories_$id;
import '../routes/api/v1/cart/index.dart' as api_v1_cart_index;
import '../routes/api/v1/auth/register.dart' as api_v1_auth_register;
import '../routes/api/v1/auth/register-many.dart' as api_v1_auth_register_many;
import '../routes/api/v1/auth/login.dart' as api_v1_auth_login;

import '../routes/_middleware.dart' as middleware;
import '../routes/api/v1/payments/_middleware.dart' as api_v1_payments_middleware;
import '../routes/api/v1/orders/_middleware.dart' as api_v1_orders_middleware;
import '../routes/api/v1/notifications/_middleware.dart' as api_v1_notifications_middleware;
import '../routes/api/v1/customers/_middleware.dart' as api_v1_customers_middleware;
import '../routes/api/v1/chat/_middleware.dart' as api_v1_chat_middleware;
import '../routes/api/v1/cart/_middleware.dart' as api_v1_cart_middleware;

void main() async {
  final address = InternetAddress.tryParse('') ?? InternetAddress.anyIPv6;
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  hotReload(() => createServer(address, port));
}

Future<HttpServer> createServer(InternetAddress address, int port) {
  final handler = Cascade().add(buildRootHandler()).handler;
  return entrypoint.run(handler, address, port);
}

Handler buildRootHandler() {
  final pipeline = const Pipeline().addMiddleware(middleware.middleware);
  final router = Router()
    ..mount('/', (context) => buildHandler()(context))
    ..mount('/api/v1/products', (context) => buildApiV1ProductsHandler()(context))
    ..mount('/api/v1/payments', (context) => buildApiV1PaymentsHandler()(context))
    ..mount('/api/v1/orders', (context) => buildApiV1OrdersHandler()(context))
    ..mount('/api/v1/notifications', (context) => buildApiV1NotificationsHandler()(context))
    ..mount('/api/v1/customers', (context) => buildApiV1CustomersHandler()(context))
    ..mount('/api/v1/coupons', (context) => buildApiV1CouponsHandler()(context))
    ..mount('/api/v1/chat', (context) => buildApiV1ChatHandler()(context))
    ..mount('/api/v1/categories', (context) => buildApiV1CategoriesHandler()(context))
    ..mount('/api/v1/cart', (context) => buildApiV1CartHandler()(context))
    ..mount('/api/v1/auth', (context) => buildApiV1AuthHandler()(context));
  return pipeline.addHandler(router);
}

Handler buildHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1ProductsHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/bulk', (context) => api_v1_products_bulk.onRequest(context,))..all('/<id>', (context,id,) => api_v1_products_$id.onRequest(context,id,))..all('/', (context) => api_v1_products_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1PaymentsHandler() {
  final pipeline = const Pipeline().addMiddleware(api_v1_payments_middleware.middleware);
  final router = Router()
    ..all('/bakong-qr', (context) => api_v1_payments_bakong_qr.onRequest(context,))..all('/check', (context) => api_v1_payments_check.onRequest(context,))..all('/paypal-capture', (context) => api_v1_payments_paypal_capture.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1OrdersHandler() {
  final pipeline = const Pipeline().addMiddleware(api_v1_orders_middleware.middleware);
  final router = Router()
    ..all('/<id>', (context,id,) => api_v1_orders_$id.onRequest(context,id,))..all('/', (context) => api_v1_orders_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1NotificationsHandler() {
  final pipeline = const Pipeline().addMiddleware(api_v1_notifications_middleware.middleware);
  final router = Router()
    ..all('/', (context) => api_v1_notifications_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1CustomersHandler() {
  final pipeline = const Pipeline().addMiddleware(api_v1_customers_middleware.middleware);
  final router = Router()
    ..all('/wishlist', (context) => api_v1_customers_wishlist.onRequest(context,))..all('/', (context) => api_v1_customers_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1CouponsHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/apply', (context) => api_v1_coupons_apply.onRequest(context,))..all('/', (context) => api_v1_coupons_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1ChatHandler() {
  final pipeline = const Pipeline().addMiddleware(api_v1_chat_middleware.middleware);
  final router = Router()
    ..all('/', (context) => api_v1_chat_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1CategoriesHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/<id>', (context,id,) => api_v1_categories_$id.onRequest(context,id,))..all('/', (context) => api_v1_categories_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1CartHandler() {
  final pipeline = const Pipeline().addMiddleware(api_v1_cart_middleware.middleware);
  final router = Router()
    ..all('/', (context) => api_v1_cart_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1AuthHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/login', (context) => api_v1_auth_login.onRequest(context,))..all('/register', (context) => api_v1_auth_register.onRequest(context,))..all('/register-many', (context) => api_v1_auth_register_many.onRequest(context,));
  return pipeline.addHandler(router);
}

