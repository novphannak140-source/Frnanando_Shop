// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures

import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/database/mongo_database.dart';
import 'package:franando_shop_api/models/category.dart';
import 'package:franando_shop_api/models/product.dart';
import 'package:franando_shop_api/repositories/auth_middleware.dart';
import 'package:franando_shop_api/repositories/response_helper.dart';
import 'package:mongo_dart/mongo_dart.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) return methodNotAllowed();
  final guard = adminGuard(context);
  if (guard != null) return guard;

  dynamic body;
  try {
    body = await context.request.json();
  } catch (_) {}
  final list = body is List
      ? body
      : (body is Map && body['products'] is List
          ? body['products'] as List
          : null);
  if (list == null || list.isEmpty)
    return fail('Body must be a JSON array of products');
  if (list.length > 200) return fail('Maximum 200 products per request');

  final cats = Database.instance.collection('categories');
  final products = Database.instance.collection('products');
  final catCache = <String, ObjectId>{};

  Future<ObjectId> categoryId(String name) async {
    final cached = catCache[name.toLowerCase()];
    if (cached != null) return cached;
    final slug = Category.slugify(name);
    var c = await cats.findOne({'slug': slug});
    if (c == null) {
      c = {
        '_id': ObjectId(),
        'name': name,
        'slug': slug,
        'createdAt': DateTime.now().toUtc(),
      };
      await cats.insertOne(c);
    }
    return catCache[name.toLowerCase()] = c['_id'] as ObjectId;
  }

  final results = <Map<String, dynamic>>[];
  var created = 0;

  for (var i = 0; i < list.length; i++) {
    final item = list[i];
    if (item is! Map) {
      results
          .add({'index': i, 'status': 'invalid', 'message': 'not an object'});
      continue;
    }
    final data = Map<String, dynamic>.from(item);
    try {
      final catName = data['category'];
      if (catName is String &&
          catName.trim().isNotEmpty &&
          data['categoryId'] == null) {
        data['categoryId'] = (await categoryId(catName.trim())).toHexString();
      }
      final doc = Product.parse(data);
      if (await products.findOne({'name': doc['name']}) != null) {
        results.add({'index': i, 'name': doc['name'], 'status': 'duplicate'});
        continue;
      }
      doc['_id'] = ObjectId();
      doc['createdAt'] = DateTime.now().toUtc();
      await products.insertOne(doc);
      created++;
      results.add({'index': i, 'name': doc['name'], 'status': 'created'});
    } on FormatException catch (e) {
      results.add({'index': i, 'status': 'invalid', 'message': e.message});
    }
  }

  return ok(
    {'total': list.length, 'created': created, 'results': results},
    status: created > 0 ? 201 : 200,
  );
}
