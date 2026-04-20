import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/stripe_config.dart';

class StripeServices {
  static const Map<String, String> _testTokens = {
    '': 'tok_visa',
    '1234567890987654': 'tok_visa_debit',
    '3456554344567656': 'tok_mastercard',
    '3333445544554567': 'tok_master_debit',
    '3445567656788876': 'tok_chargeDeclined',
    '3433344212112345': 'tok_chargeDeclinedInsufficientFunds',
  };

  static Future<Map<String, dynamic>> processPayment({
    required double amount,
    required String cardNumber,
    required String expMonth,
    required String expYear,
    required String cvc,
  }) async {
    // 1. Properly clean the card number (remove spaces/dashes)
    final cleanCard = cardNumber.replaceAll(RegExp(r'\D'), '');
    final token = _testTokens[cleanCard];

    if (token == null) {
      return <String, dynamic>{
        'success': false,
        'error': 'Unknown test card number. Please use a valid test card.'
      };
    }

    // Stripe expects amounts in the smallest currency unit (centavos for PHP)
    final amountInCentavos = (amount * 100).round().toString();

    try {
      final response = await http.post(
        Uri.parse('${StripeConfig.apiUrl}/payment_intents'),
        headers: <String, String>{
          'Authorization': 'Bearer ${StripeConfig.secretKey}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: <String, String>{
          'amount': amountInCentavos,
          'currency': 'php',
          'confirm': 'true',

          // FIX: Wrap the token in payment_method_data
          'payment_method_data[type]': 'card',
          'payment_method_data[card][token]': token,

          // Required for server-side confirmation without 3D Secure/Browser redirects
          'automatic_payment_methods[enabled]': 'true',
          'automatic_payment_methods[allow_redirects]': 'never',
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['status'] == 'succeeded') {
        return <String, dynamic>{
          'success': true,
          'id': data['id'].toString(),
          'amount': (data['amount'] as num) / 100,
          'status': data['status'].toString(),
        };
      } else {
        // Handle Stripe specific errors
        String errorMsg = 'Payment Failed';
        if (data['error'] != null && data['error'] is Map) {
          errorMsg = data['error']['message'] ?? errorMsg;
        }
        return <String, dynamic>{
          'success': false,
          'error': errorMsg
        };
      }
    } catch (e) {
      return <String, dynamic>{
        'success': false,
        'error': 'Connection Error: ${e.toString()}',
      };
    }
  }
}