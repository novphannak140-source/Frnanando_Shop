import 'dart:convert';
import 'dart:io';

import 'package:franando_shop_api/repositories/env.dart';
import 'package:http/http.dart' as http;
import 'package:khqr_generator/khqr_generator.dart';

class BakongQr {
  const BakongQr({
    required this.qr,
    required this.md5,
    required this.expiresAt,
  });

  final String qr;
  final String md5;
  final DateTime expiresAt;
}

/// KHQR generation + Bakong Open API verification.
/// KHQR generation uses the community Dart package khqr_generator (not an
/// NBC-maintained SDK). Validate generated QR codes in Bakong SIT before go-live.
class BakongService {
  static const int maxQrLifetimeMinutes = 10; // NBC integration guide limit.

  static String get accountId => Env.get('BAKONG_ACCOUNT').trim();

  static BakongQr generateKhqr({
    required double amount,
    required String currency,
    required String billNumber,
  }) {
    if (accountId.isEmpty || accountId.toLowerCase().contains('your_') || accountId.toLowerCase().contains('yourname@')) {
      throw StateError('Set a real BAKONG_ACCOUNT in your private .env file.');
    }
    if (amount <= 0 || !amount.isFinite) {
      throw ArgumentError.value(amount, 'amount', 'Must be a positive amount.');
    }

    final currencyCode = currency.toUpperCase();
    final currencyValue = switch (currencyCode) {
      'USD' => KHQRCurrency.usd.code,
      'KHR' => KHQRCurrency.khr.code,
      _ => throw ArgumentError.value(currency, 'currency', 'Only USD and KHR are supported.'),
    };

    final now = DateTime.now().toUtc();
    final expiresAt = now.add(const Duration(minutes: maxQrLifetimeMinutes));
    final info = IndividualInfo(
      bakongAccountID: accountId,
      merchantName: Env.get('BAKONG_MERCHANT_NAME', 'Franando Shop'),
      merchantCity: Env.get('BAKONG_MERCHANT_CITY', 'Phnom Penh'),
      amount: currencyCode == 'KHR' ? amount.roundToDouble() : double.parse(amount.toStringAsFixed(2)),
      currency: currencyValue,
      expirationTimestamp: expiresAt.millisecondsSinceEpoch,
      billNumber: billNumber,
    );

    final result = KHQRGenerator.generateIndividual(info);
    if (result.status.code != 0 || result.data == null) {
      throw StateError('KHQR generation failed: ${result.status.message}');
    }

    return BakongQr(
      qr: result.data!.qr,
      md5: result.data!.md5,
      expiresAt: expiresAt,
    );
  }

  /// Returns verified transaction data, or null when Bakong has not found a
  /// successful transaction yet. Throws for transport/auth/server failures.
  static Future<Map<String, dynamic>?> checkTransactionByMd5(String md5) async {
    final token = Env.get('BAKONG_TOKEN').trim();
    if (token.isEmpty || token.toLowerCase().contains('replace_with') || token.toLowerCase().contains('your_private')) {
      throw StateError('Set a valid private BAKONG_TOKEN in your .env file.');
    }
    if (!RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(md5)) {
      throw ArgumentError.value(md5, 'md5', 'Invalid MD5 hash.');
    }

    final base = Env.get('BAKONG_API_BASE', 'https://api-bakong.nbc.gov.kh').replaceAll(RegExp(r'/+$'), '');
    final response = await http
        .post(
          Uri.parse('$base/v1/check_transaction_by_md5'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'md5': md5}),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('Bakong rejected the API token. Check or renew BAKONG_TOKEN.');
    }
    if (response.statusCode != 200) {
      throw HttpException('Bakong API returned HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected Bakong API response.');
    }
    if (decoded['responseCode'] != 0 || decoded['data'] is! Map) return null;
    final data = Map<String, dynamic>.from(decoded['data'] as Map);
    if ((data['hash'] ?? '').toString().isEmpty) {
      throw const FormatException('Bakong response did not contain a transaction hash.');
    }
    return data;
  }
}
