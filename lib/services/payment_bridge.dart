import 'dart:developer';

import 'package:flutter/services.dart';

import '../models/payment_config.dart';
import '../models/payment_result.dart';

/// Unified Payment Bridge - handles all communication with native platforms
class PaymentBridge {
  static const MethodChannel _channel = MethodChannel('checkout_bridge');

  // Singleton pattern
  static final PaymentBridge _instance = PaymentBridge._internal();
  factory PaymentBridge() => _instance;
  PaymentBridge._internal();

  // Callbacks for payment events
  Function(CardTokenResult)? onCardTokenized;
  Function(PaymentSuccessResult)? onPaymentSuccess;
  Function(PaymentErrorResult)? onPaymentError;
  Function(String)? onSessionData;

  /// Initialize the payment bridge and set up method call handler
  void initialize() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Handle incoming calls from native platforms
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    log('📱 Received method call: ${call.method}');

    switch (call.method) {
      case 'cardTokenized':
        final result = CardTokenResult.fromMap(
          call.arguments as Map<String, dynamic>,
        );
        log('[Checkout]: ✅ Card tokenized: $result');
        onCardTokenized?.call(result);
        break;

      case 'paymentSuccess':
        final result = PaymentSuccessResult.fromMap(call.arguments);
        log('[Checkout]: ✅ Payment success: $result');
        onPaymentSuccess?.call(result);
        break;

      case 'paymentError':
        final result = PaymentErrorResult.fromMap(call.arguments);
        log('[Checkout]: ❌ Payment error: $result');
        onPaymentError?.call(result);
        break;

      case 'sessionDataReady':
        final args = call.arguments as Map<String, dynamic>;
        final result = args['sessionData'] as String;
        log('[Checkout]: ✅ Session data: $result');
        onSessionData?.call(result);
        break;

      default:
        log('⚠️ Unknown method: ${call.method}');
    }
  }

  // ==================== CARD METHODS ====================

  /// Initialize card component with configuration
  Future<bool> initCardView(PaymentConfig config, CardConfig cardConfig) async {
    try {
      final params = {...config.toMap(), 'cardConfig': cardConfig.toMap()};

      final result = await _channel.invokeMethod('initCardView', params);
      return result == true;
    } on PlatformException catch (e) {
      log('[Checkout]: ❌ Init card view failed: ${e.message}');
      return false;
    }
  }

  /// Validate card input (returns true if valid)
  Future<bool> validateCard() async {
    try {
      final result = await _channel.invokeMethod<bool>('validateCard');
      return result ?? false;
    } on PlatformException catch (e) {
      log('[Checkout]: ❌ Validate card failed: ${e.message}');
      return false;
    }
  }

  /// Tokenize the card (trigger from Flutter button)
  Future<void> tokenizeCard() async {
    try {
      log('[Checkout]: 🔄 Requesting card tokenization...');
      await _channel.invokeMethod('tokenizeCard');
      // Result will come via onCardTokenized callback
    } on PlatformException catch (e) {
      log('[Checkout]: ❌ Tokenize card failed: ${e.message}');
      onPaymentError?.call(
        PaymentErrorResult(
          errorCode: e.code,
          errorMessage: e.message ?? 'Tokenization failed',
        ),
      );
    }
  }

  Future<void> submit() async {
    try {
      log('[Checkout]: 🔄 Submitting...');
      await _channel.invokeMethod('getSessionData');
      // Result will come via onCardTokenized callback
    } on PlatformException catch (e) {
      log('[Checkout]: ❌ Submit failed: ${e.message}');
      onPaymentError?.call(
        PaymentErrorResult(
          errorCode: e.code,
          errorMessage: e.message ?? 'Submit failed',
        ),
      );
    }
  }

  // ==================== GOOGLE PAY METHODS ====================

  /// Initialize Google Pay
  Future<bool> initGooglePay(
    PaymentConfig config,
    GooglePayConfig googlePayConfig,
  ) async {
    try {
      final params = {
        ...config.toMap(),
        'googlePayConfig': googlePayConfig.toMap(),
      };

      final result = await _channel.invokeMethod('initGooglePay', params);
      return result == true;
    } on PlatformException catch (e) {
      log('[Checkout]: ❌ Init Google Pay failed: ${e.message}');
      return false;
    }
  }

  /// Check if Google Pay is available on this device
  Future<bool> checkGooglePayAvailability() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'checkGooglePayAvailability',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      log('[Checkout]: ❌ Check Google Pay availability failed: ${e.message}');
      return false;
    }
  }

  /// Launch Google Pay payment sheet
  Future<void> launchGooglePaySheet(Map<String, dynamic> requestData) async {
    try {
      log('[Checkout]: 🔄 Launching Google Pay sheet...');
      await _channel.invokeMethod('launchGooglePaySheet', requestData);
      // Result will come via callbacks
    } on PlatformException catch (e) {
      log('[Checkout]: ❌ Launch Google Pay failed: ${e.message}');
      onPaymentError?.call(
        PaymentErrorResult(
          errorCode: e.code,
          errorMessage: e.message ?? 'Google Pay failed',
        ),
      );
    }
  }

  /// Tokenize Google Pay payment data using Checkout SDK
  Future<void> tokenizeGooglePayData(String paymentData) async {
    try {
      log('[Checkout]: 🔄 Tokenizing Google Pay data...');
      await _channel.invokeMethod('tokenizeGooglePayData', {
        'paymentData': paymentData,
      });
      // Token will come via cardTokenized callback
    } on PlatformException catch (e) {
      log('[Checkout]: ❌ Google Pay tokenization failed: ${e.message}');
      onPaymentError?.call(
        PaymentErrorResult(
          errorCode: e.code,
          errorMessage: e.message ?? 'Google Pay tokenization failed',
        ),
      );
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Reset/clear all callbacks
  void clearCallbacks() {
    onCardTokenized = null;
    onPaymentSuccess = null;
    onPaymentError = null;
  }

  /// Dispose resources
  void dispose() {
    clearCallbacks();
  }
}
