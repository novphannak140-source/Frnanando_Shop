import 'dart:convert';

import 'package:franando_shop_api/repositories/env.dart';
import 'package:http/http.dart' as http;

class PayPalService {
  static String get _base => Env.get('PAYPAL_BASE', 'https://api-m.sandbox.paypal.com');

  static Future<String> _accessToken() async {
    final basic = base64Encode(
      utf8.encode('${Env.get('PAYPAL_CLIENT_ID')}:${Env.get('PAYPAL_SECRET')}'),
    );
    final res = await http.post(
      Uri.parse('$_base/v1/oauth2/token'),
      headers: {'Authorization': 'Basic $basic', 'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'grant_type=client_credentials',
    );
    if (res.statusCode != 200) throw Exception('PayPal auth failed: ${res.body}');
    return (jsonDecode(res.body) as Map<String, dynamic>)['access_token'] as String;
  }

  /// Captures an approved PayPal order. Returns the decoded PayPal response.
  static Future<Map<String, dynamic>> capture(String paypalOrderId) async {
    final token = await _accessToken();
    final res = await http.post(
      Uri.parse('$_base/v2/checkout/orders/$paypalOrderId/capture'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: '{}',
    );
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) throw Exception('PayPal capture failed: ${res.body}');
    return json;
  }
}
