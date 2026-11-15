import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/controllers/product_controller.dart';

// GET  /products?category=&search=&minPrice=&maxPrice=&sort=&page=&limit=
// POST /products (admin)
Future<Response> onRequest(RequestContext context) => ProductController.handleIndex(context);
