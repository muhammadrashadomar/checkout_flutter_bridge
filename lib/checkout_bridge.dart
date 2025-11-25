import 'package:flutter/foundation.dart';

/// Error result from payment operations
class PaymentError {
  final String code;
  final String message;

  const PaymentError({required this.code, required this.message});

  factory PaymentError.fromMap(Map<dynamic, dynamic> map) {
    return PaymentError(
      code: map['errorCode']?.toString() ?? 'UNKNOWN_ERROR',
      message: map['errorMessage']?.toString() ?? 'An unknown error occurred',
    );
  }

  @override
  String toString() => 'PaymentError(code: $code, message: $message)';
}

/// Callback types for payment events
enum PaymentEvent {
  paymentSuccess,
  paymentError,
  cardTokenized,
  getSessionData,
}

/// Simple bridge for handling checkout payment callbacks
///
/// This class is a lightweight service that receives callbacks from native
/// code and passes them to registered Dart callbacks. It does NOT handle UI.
///
/// Usage:
/// 1. Create instance of CheckoutBridge
/// 2. Set callback handlers (onPaymentSuccess, onPaymentError, etc.)
/// 3. Call setupMethodCallHandler() to start listening for native events
class CheckoutBridge {
  // Callbacks for payment events
  Function(String paymentId)? onPaymentSuccess;
  Function(PaymentError error)? onPaymentError;
  Function(Map<String, dynamic> tokenData)? onCardTokenized;
  Function(String sessionData)? onSessionData;

  /// Setup method call handler to listen for native events
  ///
  /// Note: This should be called once during app initialization or when
  /// the payment screen is shown. The actual method channel setup is done
  /// by the PaymentBridge service.
  void setupMethodCallHandler() {
    debugPrint('[CheckoutBridge] Setting up method call handler');
    // Note: Actual method channel handling is done by PaymentBridge
    // This is kept for backward compatibility but may be deprecated
  }

  /// Handle a payment event from native code
  ///
  /// This is called internally by the PaymentBridge when it receives
  /// callbacks from the native platform.
  void handlePaymentEvent(PaymentEvent event, dynamic data) {
    try {
      switch (event) {
        case PaymentEvent.paymentSuccess:
          final paymentId = data?.toString() ?? '';
          debugPrint('[CheckoutBridge] Payment successful: $paymentId');
          onPaymentSuccess?.call(paymentId);
          break;

        case PaymentEvent.paymentError:
          final error =
              data is Map
                  ? PaymentError.fromMap(data)
                  : PaymentError(
                    code: 'UNKNOWN_ERROR',
                    message: data?.toString() ?? 'Unknown error occurred',
                  );
          debugPrint('[CheckoutBridge] Payment error: $error');
          onPaymentError?.call(error);
          break;

        case PaymentEvent.cardTokenized:
          if (data is Map<String, dynamic>) {
            debugPrint('[CheckoutBridge] Card tokenized successfully');
            onCardTokenized?.call(data);
          } else {
            debugPrint('[CheckoutBridge] Invalid tokenization data format');
            onPaymentError?.call(
              const PaymentError(
                code: 'INVALID_DATA',
                message: 'Invalid tokenization data received',
              ),
            );
          }
          break;

        case PaymentEvent.getSessionData:
          final sessionData = data?.toString() ?? '';
          debugPrint('[CheckoutBridge] Session data received');
          onSessionData?.call(sessionData);
          break;
      }
    } catch (e, stackTrace) {
      debugPrint('[CheckoutBridge] Error handling payment event: $e');
      debugPrint('[CheckoutBridge] Stack trace: $stackTrace');
      onPaymentError?.call(
        PaymentError(
          code: 'CALLBACK_ERROR',
          message: 'Error handling payment callback: $e',
        ),
      );
    }
  }

  /// Dispose and clean up resources
  void dispose() {
    debugPrint('[CheckoutBridge] Disposing CheckoutBridge');
    onPaymentSuccess = null;
    onPaymentError = null;
    onCardTokenized = null;
    onSessionData = null;
  }
}
