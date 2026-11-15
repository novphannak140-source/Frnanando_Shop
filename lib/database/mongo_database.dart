import 'package:franando_shop_api/repositories/env.dart';
import 'package:mongo_dart/mongo_dart.dart';

class Database {
  Database._();
  static final Database instance = Database._();

  Db? _db;

  Future<void> connect() async {
    if (_db != null && _db!.isConnected) return;
    final uri = Env.get('MONGO_URI', 'mongodb://localhost:27017/franando_shop');
    final db = await Db.create(uri);
    await db.open();
    _db = db;
    await _ensureIndexes();
    print(' MongoDB connected');
  }

  Future<void> close() async => _db?.close();

  DbCollection collection(String name) {
    final db = _db;
    if (db == null) throw StateError('Database not connected');
    return db.collection(name);
  }

  Future<void> _ensureIndexes() async {
    await collection('users').createIndex(keys: {'email': 1}, unique: true);
    await collection('products').createIndex(keys: {'categoryId': 1});
    await collection('categories').createIndex(keys: {'slug': 1}, unique: true);
    await collection('coupons').createIndex(keys: {'code': 1}, unique: true);
    await collection('orders').createIndex(keys: {'userId': 1});
    await collection('payments').createIndex(keys: {'md5': 1});
    await collection('payments').createIndex(keys: {'orderId': 1, 'status': 1});
    await collection('notifications')
        .createIndex(keys: {'userId': 1, 'createdAt': -1});
    await collection('notifications').createIndex(keys: {'paymentId': 1});
    await collection('carts').createIndex(keys: {'userId': 1}, unique: true);
    await collection('wishlists')
        .createIndex(keys: {'userId': 1}, unique: true);
  }
}
