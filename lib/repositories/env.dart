import 'package:dotenv/dotenv.dart';

class Env {
  static final DotEnv _env = DotEnv(includePlatformEnvironment: true)..load();

  static String get(String key, [String fallback = '']) {
    final v = _env[key];
    return (v == null || v.isEmpty) ? fallback : v;
  }

  static String get jwtSecret => get('JWT_SECRET', 'change-me-in-production');
}
