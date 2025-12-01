# Payment Error Code Enum

Type-safe error handling for Checkout Flutter Bridge using the `PaymentErrorCode` enum.

## Overview

The `PaymentErrorCode` enum provides type-safe error handling for all payment errors from both Card and Google Pay implementations. Instead of checking error strings, you can now use the enum for cleaner, more maintainable error handling.

## Features

✅ **Type-safe error handling** - Use enum values instead of string comparisons  
✅ **Error categorization** - Helper properties to identify error types  
✅ **User-friendly messages** - Built-in user-facing error messages  
✅ **Retryable detection** - Identify which errors can be retried  
✅ **Exhaustive switch statements** - Compiler-enforced error handling

## Error Types

### Card Payment Errors
- `initError` - Initialization error
- `cardNotReady` - Card component not ready
- `cardNotAvailable` - Card payment not available
- `tokenError` - Token generation error
- `sessionDataError` - Session data error
- `launchError` - Launch error
- `checkoutError` - Checkout SDK error

### Google Pay Errors
- `invalidConfig` - Invalid configuration
- `initializationFailed` - Initialization failed
- `timeout` - Request timeout
- `googlepayUnavailable` - Google Pay not available
- `googlepayNotAvailable` - Google Pay not supported
- `invalidState` - Invalid state
- `paymentError` - Payment processing error
- `tokenizationFailed` - Tokenization failed

### Generic Errors
- `unknown` - Unknown error

## Usage

### Basic Error Handling

```dart
CheckoutFlowCardView(
  paymentConfig: config,
  onError: (PaymentErrorResult error) {
    // Access the error type enum
    print('Error type: ${error.errorType.name}');
    print('Error code: ${error.errorCode}');
    print('Error message: ${error.errorMessage}');
    
    // Get user-friendly message
    print('User message: ${error.userFriendlyMessage}');
  },
);
```

### Type-Safe Switch Statement

```dart
void handleError(PaymentErrorResult error) {
  switch (error.errorType) {
    case PaymentErrorCode.googlepayUnavailable:
      // Handle Google Pay unavailable
      showAlternativePayment();
      break;
      
    case PaymentErrorCode.timeout:
      // Handle timeout
      showRetryButton();
      break;
      
    case PaymentErrorCode.tokenError:
    case PaymentErrorCode.tokenizationFailed:
      // Handle tokenization errors
      askUserToCheckCardDetails();
      break;
      
    default:
      // Handle other errors
      showGenericError(error.userFriendlyMessage);
  }
}
```

### Using Helper Properties

```dart
void handleError(PaymentErrorResult error) {
  // Check if Google Pay error
  if (error.isGooglePayError) {
    print('This is a Google Pay error');
    // Maybe switch to card payment
  }
  
  // Check if card error
  if (error.isCardError) {
    print('This is a card error');
    // Maybe ask user to verify card details
  }
  
  // Check if initialization error
  if (error.isInitializationError) {
    print('Failed to initialize payment');
    // Maybe retry initialization
  }
  
  // Check if retryable
  if (error.isRetryable) {
    print('This error can be retried');
    showRetryButton();
  }
}
```

### Enhanced Error UI

```dart
void showError(BuildContext context, PaymentErrorResult error) {
  String title = 'Payment Error';
  String message = error.userFriendlyMessage;
  Color color = Colors.red;
  
  // Customize based on error category
  if (error.isGooglePayError) {
    title = 'Google Pay Error';
    color = Colors.orange;
  } else if (error.isInitializationError) {
    title = 'Initialization Error';
  }
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
          Text(message),
          if (error.isRetryable)
            TextButton(
              onPressed: () => retryPayment(),
              child: Text('Retry'),
            ),
        ],
      ),
      backgroundColor: color,
    ),
  );
}
```

## PaymentErrorResult Properties

```dart
class PaymentErrorResult {
  // String values (backward compatible)
  final String errorCode;           // e.g., "INITIALIZATION_FAILED"
  final String errorMessage;        // Native error message
  
  // Enum type (NEW!)
  final PaymentErrorCode errorType; // Enum value
  
  // Helper properties
  bool get isGooglePayError;        // Is Google Pay error
  bool get isCardError;             // Is card error
  bool get isInitializationError;   // Is init error
  bool get isRetryable;             // Can be retried
  String get userFriendlyMessage;   // User-friendly message
}
```

## Migration Guide

### Before (String comparison)

```dart
onError: (error) {
  if (error.errorCode == 'GOOGLEPAY_UNAVAILABLE') {
    // Handle Google Pay unavailable
  } else if (error.errorCode == 'TIMEOUT') {
    // Handle timeout
  }
}
```

### After (Type-safe enum)

```dart
onError: (error) {
  switch (error.errorType) {
    case PaymentErrorCode.googlepayUnavailable:
      // Handle Google Pay unavailable
      break;
    case PaymentErrorCode.timeout:
      // Handle timeout
      break;
    default:
      // Handle other errors
  }
}
```

## Benefits

1. **Type Safety** - Compiler catches typos and missing cases
2. **Autocomplete** - IDE suggests all available error types
3. **Maintainability** - Easier to refactor and update error handling
4. **Readability** - Code is more self-documenting
5. **Backward Compatible** - String properties still available

## Complete Example

See `payment_error_handling_example.dart` for a comprehensive example showing all error handling patterns.

## Error Code Reference

| Enum Value | String Code | Description |
|------------|-------------|-------------|
| `initError` | `INIT_ERROR` | Initialization error |
| `cardNotReady` | `CARD_NOT_READY` | Card component not ready |
| `cardNotAvailable` | `CARD_NOT_AVAILABLE` | Card payment unavailable |
| `tokenError` | `TOKEN_ERROR` | Token generation error |
| `sessionDataError` | `SESSION_DATA_ERROR` | Session data error |
| `launchError` | `LAUNCH_ERROR` | Launch error |
| `checkoutError` | `CHECKOUT_ERROR` | Checkout SDK error |
| `invalidConfig` | `INVALID_CONFIG` | Invalid configuration |
| `initializationFailed` | `INITIALIZATION_FAILED` | Initialization failed |
| `timeout` | `TIMEOUT` | Request timeout |
| `googlepayUnavailable` | `GOOGLEPAY_UNAVAILABLE` | Google Pay unavailable |
| `googlepayNotAvailable` | `GOOGLEPAY_NOT_AVAILABLE` | Google Pay not supported |
| `invalidState` | `INVALID_STATE` | Invalid state |
| `paymentError` | `PAYMENT_ERROR` | Payment error |
| `tokenizationFailed` | `TOKENIZATION_FAILED` | Tokenization failed |
| `unknown` | `UNKNOWN` | Unknown error |
