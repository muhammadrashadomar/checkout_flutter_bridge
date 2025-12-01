/// Payment error codes enum for type-safe error handling
enum PaymentErrorCode {
  // Card payment errors
  initError('INIT_ERROR'),
  cardNotReady('CARD_NOT_READY'),
  cardNotAvailable('CARD_NOT_AVAILABLE'),
  tokenError('TOKEN_ERROR'),
  sessionDataError('SESSION_DATA_ERROR'),
  launchError('LAUNCH_ERROR'),
  checkoutError('CHECKOUT_ERROR'),

  // Google Pay errors
  invalidConfig('INVALID_CONFIG'),
  initializationFailed('INITIALIZATION_FAILED'),
  timeout('TIMEOUT'),
  googlepayUnavailable('GOOGLEPAY_UNAVAILABLE'),
  googlepayNotAvailable('GOOGLEPAY_NOT_AVAILABLE'),
  invalidState('INVALID_STATE'),
  paymentError('PAYMENT_ERROR'),
  tokenizationFailed('TOKENIZATION_FAILED'),

  // Generic errors
  unknown('UNKNOWN');

  const PaymentErrorCode(this.code);

  /// The string code sent from native platforms
  final String code;

  /// Parse error code string from native to enum
  static PaymentErrorCode fromString(String code) {
    return PaymentErrorCode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => PaymentErrorCode.unknown,
    );
  }

  /// Check if this is a Google Pay specific error
  bool get isGooglePayError {
    return this == googlepayUnavailable ||
        this == googlepayNotAvailable ||
        this == invalidConfig ||
        this == initializationFailed ||
        this == timeout ||
        this == invalidState ||
        this == tokenizationFailed;
  }

  /// Check if this is a card payment specific error
  bool get isCardError {
    return this == cardNotReady ||
        this == cardNotAvailable ||
        this == tokenError ||
        this == sessionDataError;
  }

  /// Check if this is an initialization error
  bool get isInitializationError {
    return this == initError ||
        this == initializationFailed ||
        this == invalidConfig;
  }

  /// Check if error is retryable
  bool get isRetryable {
    return this == timeout ||
        this == launchError ||
        this == checkoutError ||
        this == paymentError;
  }

  /// Get user-friendly error message
  String get userMessage {
    switch (this) {
      case PaymentErrorCode.initError:
      case PaymentErrorCode.initializationFailed:
        return 'Failed to initialize payment. Please try again.';

      case PaymentErrorCode.cardNotReady:
      case PaymentErrorCode.cardNotAvailable:
        return 'Card payment is not available. Please try another payment method.';

      case PaymentErrorCode.tokenError:
      case PaymentErrorCode.tokenizationFailed:
        return 'Failed to process payment. Please check your card details.';

      case PaymentErrorCode.sessionDataError:
        return 'Failed to submit payment data. Please try again.';

      case PaymentErrorCode.timeout:
        return 'Payment request timed out. Please check your connection and try again.';

      case PaymentErrorCode.googlepayUnavailable:
      case PaymentErrorCode.googlepayNotAvailable:
        return 'Google Pay is not available on this device.';

      case PaymentErrorCode.invalidConfig:
        return 'Payment configuration error. Please contact support.';

      case PaymentErrorCode.invalidState:
        return 'Payment system not ready. Please wait a moment and try again.';

      case PaymentErrorCode.paymentError:
        return 'Payment failed. Please try again.';

      case PaymentErrorCode.launchError:
        return 'Failed to launch payment. Please try again.';

      case PaymentErrorCode.checkoutError:
        return 'Checkout error occurred. Please try again.';

      case PaymentErrorCode.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}
