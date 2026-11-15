import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/database/mongo_database.dart';
import 'package:franando_shop_api/models/product.dart';
import 'package:franando_shop_api/services/product_service.dart';
import 'package:franando_shop_api/repositories/auth_middleware.dart';
import 'package:franando_shop_api/repositories/response_helper.dart';
import 'package:mongo_dart/mongo_dart.dart';

class ProductController {
  static DbCollection get _col => Database.instance.collection('products');

  static Future<Response> handleIndex(RequestContext context) async {
    switch (context.request.method) {
      case HttpMethod.get:
        final q = context.request.uri.queryParameters;
        final p = paging(q);
        final result = await ProductService.search(
          category: q['category'],
          search: q['search'],
          minPrice: double.tryParse(q['minPrice'] ?? ''),
          maxPrice: double.tryParse(q['maxPrice'] ?? ''),
          sort: q['sort'],
          page: p.page,
          limit: p.limit,
        );
        return ok(result);
      case HttpMethod.post:
        final guard = adminGuard(context);
        if (guard != null) return guard;
        try {
          final doc = Product.parse(await readJson(context));
          final cat = await Database.instance
              .collection('categories')
              .findOne({'_id': doc['categoryId']});
          if (cat == null) return fail('Category not found', status: 404);
          doc['_id'] = ObjectId();
          doc['createdAt'] = DateTime.now().toUtc();
          await _col.insertOne(doc);
          return ok(doc, status: 201);
        } on FormatException catch (e) {
          return fail(e.message);
        }
      default:
        return methodNotAllowed();
    }
  }

  static Future<Response> handleItem(RequestContext context, String id) async {
    final oid = parseId(id);
    if (oid == null) return fail('Invalid id');

    switch (context.request.method) {
      case HttpMethod.get:
        final doc = await _col.findOne({'_id': oid});
        return doc == null ? fail('Product not found', status: 404) : ok(doc);
      case HttpMethod.put:
      case HttpMethod.patch:
        final guard = adminGuard(context);
        if (guard != null) return guard;
        try {
          final changes = Product.parse(await readJson(context), partial: true);
          if (changes.isEmpty) return fail('Nothing to update');
          changes['updatedAt'] = DateTime.now().toUtc();
          await _col.updateOne({'_id': oid}, {r'$set': changes});
          final doc = await _col.findOne({'_id': oid});
          return doc == null ? fail('Product not found', status: 404) : ok(doc);
        } on FormatException catch (e) {
          return fail(e.message);
        }
      case HttpMethod.delete:
        final guard = adminGuard(context);
        if (guard != null) return guard;
        await _col.deleteOne({'_id': oid});
        return ok({'deleted': true});
      default:
        return methodNotAllowed();
    }
  }
}
