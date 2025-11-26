# Checkout Flutter Bridge Example

This is an example Flutter application demonstrating how to use the `checkout_flutter_bridge` package.

## Features Demonstrated

- Initializing the PaymentBridge
- Setting up payment callbacks
- Configuring payment sessions dynamically
- Validating card input
- Tokenizing cards
- Error handling

## Getting Started

### 1. Configure Payment Credentials

Before running the example, you need to update the payment credentials in `lib/main.dart`:

```dart
final config = Payment Config(
  paymentSessionId: "ps_your_session_id",      // From your backend
  paymentSessionSecret: "pss_your_secret",      // From your backend
  publicKey: "pk_sbox_your_public_key",        // Your Checkout.com key
  environment: PaymentEnvironment.sandbox,
);
```

⚠️ **Important**: In production, these values should come from your backend API, not hardcoded.

### 2. Run the Example

```bash
cd example
flutter pub get
flutter run
```

## Code Structure

- `main.dart` - Main example demonstrating:
  - Payment bridge initialization
  - Callback setup
  - Card validation
  - Tokenization flow
  - Error handling

## Key Concepts

### Initialization

```dart
final PaymentBridge _paymentBridge = PaymentBridge();

_paymentBridge.initialize();
```

### Setting Up Callbacks

```dart
_paymentBridge.onCardTokenized = (result) {
  print('Token: ${result.token}');
  // Send to your backend
};

_paymentBridge.onPaymentError = (error) {
  print('Error: ${error.errorMessage}');
};
```

### Tokenizing Cards

```dart
// Validate first
final isValid = await _paymentBridge.validateCard();

if (isValid) {
  // Trigger tokenization
  await _paymentBridge.tokenizeCard();
  // Result comes via onCardTokenized callback
}
```

## Testing

Use Checkout.com test cards:
- Visa: `4242 4242 4242 4242`
- Mastercard: `5436 0310 3060 6378`
- Any future expiry date and CVV

## Production Checklist

- [ ] Fetch session credentials from backend
- [ ] Use `PaymentEnvironment.production`
- [ ] Implement proper error handling
- [ ] Add loading states
- [ ] Test with real test credentials
- [ ] Never log sensitive data

##  Notes

This example shows only the method calls and listeners. In a real app, you would:
1. Display the native card input using `AndroidView`
2. Implement proper UI/UX
3. Handle payment flow with your backend
4. Show loading states and error messages

## Learn More

For more detailed documentation, see the main package [README](../README.md).
