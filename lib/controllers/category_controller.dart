import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/database/mongo_database.dart';
import 'package:franando_shop_api/models/category.dart';
import 'package:franando_shop_api/repositories/auth_middleware.dart';
import 'package:franando_shop_api/repositories/response_helper.dart';
import 'package:mongo_dart/mongo_dart.dart';

class CategoryController {
  static DbCollection get _col => Database.instance.collection('categories');

  static Future<Response> handleIndex(RequestContext context) async {
    switch (context.request.method) {
      case HttpMethod.get:
        final items = await _col.modernFind(sort: {'name': 1}).toList();
        return ok(items);
      case HttpMethod.post:
        final guard = adminGuard(context);
        if (guard != null) return guard;
        try {
          final doc = Category.parse(await readJson(context));
          if (await _col.findOne({'slug': doc['slug']}) != null) {
            return fail('Category already exists', status: 409);
          }
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
        return doc == null ? fail('Category not found', status: 404) : ok(doc);
      case HttpMethod.put:
      case HttpMethod.patch:
        final guard = adminGuard(context);
        if (guard != null) return guard;
        try {
          final changes = Category.parse(await readJson(context), partial: true);
          if (changes.isEmpty) return fail('Nothing to update');
          changes['updatedAt'] = DateTime.now().toUtc();
          await _col.updateOne({'_id': oid}, {r'$set': changes});
          return ok(await _col.findOne({'_id': oid}));
        } on FormatException catch (e) {
          return fail(e.message);
        }
      case HttpMethod.delete:
        final guard = adminGuard(context);
        if (guard != null) return guard;
        final used = await Database.instance.collection('products').count({'categoryId': oid});
        if (used > 0) return fail('Category still has $used product(s)', status: 409);
        await _col.deleteOne({'_id': oid});
        return ok({'deleted': true});
      default:
        return methodNotAllowed();
    }
  }
}
