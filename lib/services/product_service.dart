import 'package:franando_shop_api/database/mongo_database.dart';
import 'package:franando_shop_api/repositories/response_helper.dart';

class ProductService {
  static Future<Map<String, dynamic>> search({
    String? category,
    String? search,
    double? minPrice,
    double? maxPrice,
    String? sort,
    int page = 1,
    int limit = 20,
    bool onlyActive = true,
  }) async {
    final filter = <String, Object>{};
    if (onlyActive) filter['isActive'] = true;

    if (category != null && category.isNotEmpty) {
      var catId = parseId(category);
      if (catId == null) {
        // allow filtering by slug
        final cat = await Database.instance
            .collection('categories')
            .findOne({'slug': category});
        catId = parseId(cat?['_id']);
      }
      if (catId == null) {
        return {
          'items': <Map<String, dynamic>>[],
          'total': 0,
          'page': page,
          'limit': limit,
        };
      }
      filter['categoryId'] = catId;
    }
    if (search != null && search.isNotEmpty) {
      filter['name'] = {r'$regex': RegExp.escape(search), r'$options': 'i'};
    }
    if (minPrice != null || maxPrice != null) {
      filter['price'] = {
        if (minPrice != null) r'$gte': minPrice,
        if (maxPrice != null) r'$lte': maxPrice,
      };
    }

    final sortMap = switch (sort) {
      'price_asc' => {'price': 1},
      'price_desc' => {'price': -1},
      _ => {'createdAt': -1},
    };

    final skip = (page - 1) * limit;
    final col = Database.instance.collection('products');

    final items = await col
        .modernFind(
          filter: filter,
          sort: sortMap,
          // mongo_dart rejects skip: 0, so only pass skip when it is > 0
          skip: skip > 0 ? skip : null,
          limit: limit,
        )
        .toList();

    int total;
    try {
      total = await col.count(filter);
    } catch (_) {
      // fallback if count() is unavailable in the installed mongo_dart version
      total = (await col.modernFind(filter: filter).toList()).length;
    }
    return {'items': items, 'total': total, 'page': page, 'limit': limit};
  }
}
