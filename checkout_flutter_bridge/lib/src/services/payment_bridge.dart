import 'package:checkout_flutter_bridge/src/models/current_payment_type.dart';
import 'package:checkout_flutter_bridge/src/utils/console_logger.dart';
import 'package:flutter/services.dart';

import '../models/payment_config.dart';
import '../models/payment_result.dart';
import '../models/saved_card_config.dart';

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
    ConsoleLogger.info('Received method call: ${call.method}');

    switch (call.method) {
      case 'cardTokenized':
        _handleCardTokenized(call.arguments);
        break;

      case 'paymentSuccess':
        _handlePaymentSuccess(call.arguments);
        break;

      case 'paymentError':
        _handlePaymentError(call.arguments);
        break;

      case 'sessionDataReady':
        _handleSessionDataReady(call.arguments);
        break;

      default:
        ConsoleLogger.warning('Unknown method: ${call.method}');
    }
  }

  void _handleCardTokenized(dynamic arguments) {
    if (arguments == null) {
      ConsoleLogger.error('cardTokenized arguments are null!');
      return;
    }

    try {
      // Convert from Map<Object?, Object?> to Map<String, dynamic>
      final args = Map<String, dynamic>.from(arguments as Map);
      final result = CardTokenResult.fromMap(args);
      ConsoleLogger.success('Card tokenized successfully');
      onCardTokenized?.call(result);
    } catch (e) {
      ConsoleLogger.error('Error parsing tokenized result: $e');
    }
  }

  void _handlePaymentSuccess(dynamic arguments) {
    try {
      final result = PaymentSuccessResult.fromMap(arguments);
      ConsoleLogger.success('Payment completed successfully');
      onPaymentSuccess?.call(result);
    } catch (e) {
      ConsoleLogger.error('Error parsing payment success result: $e');
    }
  }

  void _handlePaymentError(dynamic arguments) {
    try {
      final result = PaymentErrorResult.fromMap(arguments);
      ConsoleLogger.error('Payment error: ${result.errorMessage}');
      onPaymentError?.call(result);
    } catch (e) {
      ConsoleLogger.error('Error parsing payment error result: $e');
    }
  }

  void _handleSessionDataReady(dynamic arguments) {
    ConsoleLogger.debug('Processing sessionDataReady...');

    if (arguments == null) {
      ConsoleLogger.error('sessionDataReady arguments are null!');
      return;
    }

    try {
      final args = Map<String, dynamic>.from(arguments as Map);

      // sessionData is sent as a String (JSON) from native
      final sessionData = args['sessionData'];

      if (sessionData is! String) {
        ConsoleLogger.error(
          'sessionData is not a String: ${sessionData.runtimeType}',
        );
        return;
      }

      ConsoleLogger.success('Session data ready');

      if (onSessionData != null) {
        onSessionData?.call(sessionData);
      } else {
        ConsoleLogger.warning('onSessionData callback is null!');
      }
    } catch (e) {
      ConsoleLogger.error('Error processing session data: $e');
    }
  }

  // ==================== CARD METHODS ====================

  /// Initialize card component with configuration
  Future<bool> initCardView(PaymentConfig config, CardConfig cardConfig) async {
    try {
      final params = {...config.toMap(), 'cardConfig': cardConfig.toMap()};
      final result = await _channel.invokeMethod('initCardView', params);

      // Track that we're using card payment
      if (result == true) {
        ConsoleLogger.debug('Payment type set to: card');
      }

      return result == true;
    } on PlatformException catch (e) {
      ConsoleLogger.error('Init card view failed: ${e.message}');
      return false;
    }
  }

  /// Validate card input (returns true if valid)
  Future<bool> validateCard() async {
    try {
      final result = await _channel.invokeMethod<bool>('validateCard');
      return result ?? false;
    } on PlatformException catch (e) {
      ConsoleLogger.error('Validate card failed: ${e.message}');
      return false;
    }
  }

  /// Tokenize the card (trigger from Flutter button)
  Future<void> tokenizeCard() async {
    try {
      ConsoleLogger.payment('Requesting card tokenization...');
      await _channel.invokeMethod('tokenizeCard');
      // Result will come via onCardTokenized callback
    } on PlatformException catch (e) {
      ConsoleLogger.error('Tokenize card failed: ${e.message}');
      onPaymentError?.call(
        PaymentErrorResult(
          errorCode: e.code,
          errorMessage: e.message ?? 'Tokenization failed',
        ),
      );
    }
  }

  // ==================== SAVED CARD METHODS ====================

  /// Initialize stored card component with saved card details
  Future<bool> initStoredCardView(
    PaymentConfig config,
    SavedCardConfig savedCardConfig,
  ) async {
    try {
      final params = {
        ...config.toMap(),
        'savedCardConfig': savedCardConfig.toMap(),
      };
      final result = await _channel.invokeMethod('initStoredCardView', params);

      // Track that we're using saved card payment
      if (result == true) {
        ConsoleLogger.debug('Payment type set to: saved_card');
      }

      return result == true;
    } on PlatformException catch (e) {
      ConsoleLogger.error('Init stored card view failed: ${e.message}');
      return false;
    }
  }

  /// Tokenize saved card (requires CVV input)
  Future<void> tokenizeSavedCard() async {
    try {
      ConsoleLogger.payment('Requesting saved card tokenization...');
      await _channel.invokeMethod(
        'tokenizeCard',
      ); // Same method, different component
      // Result will come via onCardTokenized callback
    } on PlatformException catch (e) {
      ConsoleLogger.error('Tokenize saved card failed: ${e.message}');
      onPaymentError?.call(
        PaymentErrorResult(
          errorCode: e.code,
          errorMessage: e.message ?? 'Tokenization failed',
        ),
      );
    }
  }

  /// Submit payment - works for both card and Google Pay
  /// Automatically determines which session data method to call based on payment type
  Future<void> submit(CurrentPaymentType paymentType) async {
    try {
      ConsoleLogger.payment('Submitting payment...');

      // Determine which session data method to call based on current payment type
      if (paymentType.isGooglePaySelected) {
        ConsoleLogger.debug('Calling Google Pay session data');
        await _channel.invokeMethod('getGooglePaySessionData');
      } else if (paymentType.isCardSelected) {
        ConsoleLogger.debug('Calling card session data');
        await _channel.invokeMethod('getSessionData');
      } else {
        // Default to card if type is unknown
        ConsoleLogger.warning('Payment type unknown, defaulting to card');
        await _channel.invokeMethod('getSessionData');
      }

      // Result will come via onSessionData callback
    } on PlatformException catch (e) {
      ConsoleLogger.error('Submit failed: ${e.message}');
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

      // Track that we're using Google Pay
      if (result == true) {
        ConsoleLogger.debug('Payment type set to: googlepay');
      }

      return result == true;
    } on PlatformException catch (e) {
      ConsoleLogger.error('Init Google Pay failed: ${e.message}');
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
      ConsoleLogger.error('Check Google Pay availability failed: ${e.message}');
      return false;
    }
  }

  /// Launch Google Pay payment sheet
  Future<void> launchGooglePaySheet(Map<String, dynamic> requestData) async {
    try {
      ConsoleLogger.payment('Launching Google Pay sheet...');
      await _channel.invokeMethod('launchGooglePaySheet', requestData);
      // Result will come via callbacks
    } on PlatformException catch (e) {
      ConsoleLogger.error('Launch Google Pay failed: ${e.message}');
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
      ConsoleLogger.payment('Tokenizing Google Pay data...');
      await _channel.invokeMethod('tokenizeGooglePayData', {
        'paymentData': paymentData,
      });
      // Token will come via cardTokenized callback
    } on PlatformException catch (e) {
      ConsoleLogger.error('Google Pay tokenization failed: ${e.message}');
      onPaymentError?.call(
        PaymentErrorResult(
          errorCode: e.code,
          errorMessage: e.message ?? 'Google Pay tokenization failed',
        ),
      );
    }
  }

  /// Tokenize Google Pay - triggers the native Google Pay component to tokenize
  /// The tokenization result will be sent via the onCardTokenized callback
  Future<void> tokenizeGooglePay() async {
    try {
      ConsoleLogger.payment('Requesting Google Pay tokenization...');
      await _channel.invokeMethod('tokenizeGooglePay');
      // Result will come via onCardTokenized callback
    } on PlatformException catch (e) {
      ConsoleLogger.error('Tokenize Google Pay failed: ${e.message}');
      onPaymentError?.call(
        PaymentErrorResult(
          errorCode: e.code,
          errorMessage: e.message ?? 'Google Pay tokenization failed',
        ),
      );
    }
  }

  /// Get Google Pay session data
  Future<void> getGooglePaySessionData() async {
    try {
      ConsoleLogger.payment('Getting Google Pay session data...');
      await _channel.invokeMethod('getGooglePaySessionData');
      // Session data will come via sessionDataReady callback
    } on PlatformException catch (e) {
      ConsoleLogger.error('Get Google Pay session data failed: ${e.message}');
      onPaymentError?.call(
        PaymentErrorResult(
          errorCode: e.code,
          errorMessage: e.message ?? 'Failed to get session data',
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
    onSessionData = null;
  }

  /// Clear payment type tracker
  void clearPaymentType() {
    ConsoleLogger.debug('Payment type cleared');
  }

  /// Dispose resources
  void dispose() {
    clearCallbacks();
  }
}
