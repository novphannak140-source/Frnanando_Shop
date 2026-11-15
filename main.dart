import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:franando_shop_api/database/mongo_database.dart';

/// Custom entrypoint: connect to MongoDB before the server starts.
Future<HttpServer> run(Handler handler, InternetAddress ip, int port) async {
  await Database.instance.connect();
  return serve(handler, ip, port);
}
