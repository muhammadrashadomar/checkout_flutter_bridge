import 'package:checkout_flutter_bridge/checkout_flutter_bridge.dart';
import 'package:flutter/material.dart';

/// Example showing how to use PaymentErrorCode enum for type-safe error handling
class PaymentErrorHandlingExample extends StatelessWidget {
  const PaymentErrorHandlingExample({super.key});

  @override
  Widget build(BuildContext context) {
    return CheckoutFlowCardView(
      paymentConfig: PaymentConfig(
        paymentSessionId: 'your_session_id',
        paymentSessionSecret: 'your_session_secret',
        publicKey: 'your_public_key',
        environment: PaymentEnvironment.sandbox,
      ),
      onError: (PaymentErrorResult error) {
        // Type-safe error handling using the enum
        handlePaymentError(context, error);
      },
      onCardTokenized: (result) {
        ConsoleLogger.success('Card tokenized: ${result.token}');
      },
    );
  }

  void handlePaymentError(BuildContext context, PaymentErrorResult error) {
    // Access the error type enum
    final errorType = error.errorType;

    // Use switch statement for exhaustive error handling
    switch (errorType) {
      case PaymentErrorCode.googlepayUnavailable:
      case PaymentErrorCode.googlepayNotAvailable:
        _showErrorDialog(
          context,
          'Google Pay Not Available',
          'Please use card payment instead.',
          showRetry: false,
        );
        break;

      case PaymentErrorCode.initError:
      case PaymentErrorCode.initializationFailed:
        _showErrorDialog(
          context,
          'Initialization Failed',
          error.userFriendlyMessage,
          showRetry: true,
        );
        break;

      case PaymentErrorCode.timeout:
        _showErrorDialog(
          context,
          'Request Timed Out',
          'Please check your internet connection and try again.',
          showRetry: true,
        );
        break;

      case PaymentErrorCode.tokenError:
      case PaymentErrorCode.tokenizationFailed:
        _showErrorDialog(
          context,
          'Payment Failed',
          'Please check your card details and try again.',
          showRetry: true,
        );
        break;

      default:
        // Handle all other errors
        _showErrorDialog(
          context,
          'Error',
          error.userFriendlyMessage,
          showRetry: error.isRetryable,
        );
    }

    // Or use helper properties for categorization
    if (error.isGooglePayError) {
      ConsoleLogger.error('This is a Google Pay specific error');
      // Maybe switch to card payment
    }

    if (error.isCardError) {
      ConsoleLogger.error('This is a card payment error');
      // Maybe ask user to verify card details
    }

    if (error.isRetryable) {
      ConsoleLogger.error('This error can be retried');
      // Show retry button
    }

    // Access raw error details
    ConsoleLogger.error('Error code: ${error.errorCode}');
    ConsoleLogger.error('Error message: ${error.errorMessage}');
    ConsoleLogger.error('Error type: ${error.errorType.name}');
  }

  void _showErrorDialog(
    BuildContext context,
    String title,
    String message, {
    bool showRetry = false,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              if (showRetry)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Implement retry logic
                  },
                  child: const Text('Retry'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}

// Quick reference for all error types
void errorHandlingQuickReference(PaymentErrorResult error) {
  // Check error category
  if (error.isGooglePayError) {
    // Google Pay specific error
  } else if (error.isCardError) {
    // Card payment specific error
  } else if (error.isInitializationError) {
    // Initialization error
  }

  // Check if retryable
  if (error.isRetryable) {
    // Show retry button
  }

  // Get user-friendly message
  // final message = error.userFriendlyMessage;

  // Use enum for switch statement
  switch (error.errorType) {
    case PaymentErrorCode.initError:
    case PaymentErrorCode.initializationFailed:
    case PaymentErrorCode.invalidConfig:
    case PaymentErrorCode.cardNotReady:
    case PaymentErrorCode.cardNotAvailable:
    case PaymentErrorCode.tokenError:
    case PaymentErrorCode.tokenizationFailed:
    case PaymentErrorCode.sessionDataError:
    case PaymentErrorCode.timeout:
    case PaymentErrorCode.googlepayUnavailable:
    case PaymentErrorCode.googlepayNotAvailable:
    case PaymentErrorCode.invalidState:
    case PaymentErrorCode.paymentError:
    case PaymentErrorCode.launchError:
    case PaymentErrorCode.checkoutError:
    case PaymentErrorCode.unknown:
      // Handle each error type
      break;
  }
}
