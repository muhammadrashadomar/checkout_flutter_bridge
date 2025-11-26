# Checkout Flutter Bridge

A Flutter plugin for integrating Checkout.com payment gateway with support for card tokenization, saved cards, and Google Pay.

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Kotlin](https://img.shields.io/badge/Kotlin-2.1.0-7F52FF?logo=kotlin)](https://kotlinlang.org)
[![Checkout.com](https://img.shields.io/badge/Checkout.com-SDK-00D632)](https://www.checkout.com)

## Features

- 🎯 **Card Tokenization** - Tokenize cards securely using Checkout.com SDK
- 💾 **Saved Cards** - Support for stored payment methods with CVV verification
- 💳 **Google Pay** - Native Google Pay integration with tokenization
- 🎨 **Customizable UI** - Full control over card input appearance
- 🔧 **Dynamic Configuration** - All parameters passed at runtime
- 🔒 **Secure** - PCI DSS compliant with best practices
- 📱 **Production Ready** - Comprehensive error handling and logging

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  checkout_flutter_bridge:
    path: ../checkout_flutter_bridge  # Or your package path
```

Then run:

```bash
flutter pub get
```

## Android Setup

### 1. Update `build.gradle`

Add the Checkout.com SDK version to your `android/gradle.properties`:

```properties
checkout_version=1.2.0
```

### 2. Update `AndroidManifest.xml`

Add the Google Wallet API metadata:

```xml
<application>
    <meta-data 
        android:name="com.google.android.gms.wallet.api.enabled" 
        android:value="true" />
</application>
```

### 3. Minimum SDK

Ensure your app's `minSdk` is at least 21 in `android/app/build.gradle`:

```gradle
defaultConfig {
    minSdk 21
}
```

## Quick Start

### 1. Import the Package

```dart
import 'package:checkout_flutter_bridge/checkout_flutter_bridge.dart';
```

### 2. Initialize Payment Bridge

```dart
class PaymentService {
  final PaymentBridge _paymentBridge = PaymentBridge();

  void initialize() {
    _paymentBridge.initialize();
    
    // Set up callbacks
    _paymentBridge.onCardTokenized = (result) {
      print('✅ Token: ${result.token}');
      print('Card: ${result.scheme} •••• ${result.last4}');
      // Send token to your backend
    };
    
    _paymentBridge.onPaymentError = (error) {
      print('❌ Error: ${error.errorMessage}');
    };
    
    _paymentBridge.onSessionData = (data) {
      print('📊 Session data: $data');
      // Send to backend for payment processing
    };
  }
}
```

### 3. Configure Payment Session

Create a payment configuration with credentials from your backend:

```dart
final config = PaymentConfig(
  paymentSessionId: "ps_xxx",        // From your backend
  paymentSessionSecret: "pss_xxx",    // From your backend
  publicKey: "pk_sbox_xxx",          // Checkout.com public key
  environment: PaymentEnvironment.sandbox,
  appearance: AppearanceConfig(
    borderRadius: 8,
    colorTokens: ColorTokens(
      colorAction: 0XFF00639E,
      colorPrimary: 0XFF111111,
      colorBorder: 0XFFCCCCCC,
    ),
  ),
);
```

### 4. Display Card Input

```dart
import 'package:flutter/services.dart';

class CardInputWidget extends StatelessWidget {
  final PaymentConfig config;

  const CardInputWidget({required this.config});

  @override
  Widget build(BuildContext context) {
    final cardConfig = CardConfig(
      showCardholderName: false,
      enableBillingAddress: false,
    );

    // Initialize card view when widget is ready
    PaymentBridge().initCardView(config, cardConfig);

    return SizedBox(
      height: 200,
      child: AndroidView(
        viewType: 'flow_card_view',
        creationParams: config.toMap(),
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}
```

### 5. Tokenize Card

```dart
ElevatedButton(
  onPressed: () async {
    // Validate card first
    final isValid = await _paymentBridge.validateCard();
    
    if (isValid) {
      // Trigger tokenization
      await _paymentBridge.tokenizeCard();
      // Result will come via onCardTokenized callback
    } else {
      print('❌ Invalid card details');
    }
  },
  child: Text('Pay Now'),
)
```

## API Reference

### PaymentBridge

Main service class for payment operations.

#### Methods

| Method | Description | Returns |
|--------|-------------|---------|
| `initialize()` | Initialize the payment bridge | `void` |
| `initCardView(config, cardConfig)` | Initialize card input component | `Future<bool>` |
| `validateCard()` | Validate card input | `Future<bool>` |
| `tokenizeCard()` | Trigger card tokenization | `Future<void>` |
| `initStoredCardView(config, savedCardConfig)` | Initialize saved card component | `Future<bool>` |
| `tokenizeSavedCard()` | Tokenize saved card with CVV | `Future<void>` |
| `initGooglePay(config, googlePayConfig)` | Initialize Google Pay | `Future<bool>` |
| `checkGooglePayAvailability()` | Check if Google Pay is available | `Future<bool>` |
| `tokenizeGooglePayData(paymentData)` | Tokenize Google Pay data | `Future<void>` |
| `dispose()` | Clean up resources | `void` |

#### Callbacks

```dart
Function(CardTokenResult)? onCardTokenized;
Function(PaymentSuccessResult)? onPaymentSuccess;
Function(PaymentErrorResult)? onPaymentError;
Function(String)? onSessionData;
```

### Models

#### PaymentConfig

```dart
PaymentConfig({
  required String paymentSessionId,
  required String paymentSessionSecret,
  required String publicKey,
  PaymentEnvironment environment = PaymentEnvironment.sandbox,
  AppearanceConfig? appearance,
})
```

#### CardTokenResult

```dart
class CardTokenResult {
  final String token;           // Checkout.com token
  final String? last4;          // Last 4 digits
  final String? scheme;         // Card scheme (visa, mastercard, etc.)
  final int? expiryMonth;       // Expiry month
  final int? expiryYear;        // Expiry year
  final String? cardType;       // Card type
  // ... and more fields
}
```

## Advanced Usage

### Saved Cards

```dart
// Initialize with saved card
final savedCardConfig = SavedCardConfig(
  paymentSourceId: "src_xxx",  // From Checkout.com
  last4: "4242",
  scheme: "visa",
  expiryMonth: 12,
  expiryYear: 2025,
);

await _payment Bridge.initStoredCardView(config, savedCardConfig);

// Tokenize (requires CVV input)
await _paymentBridge.tokenizeSavedCard();
```

### Custom Appearance

```dart
final appearance = AppearanceConfig(
  borderRadius: 12,
  colorTokens: ColorTokens(
    colorAction: 0XFF4CAF50,       // Green action color
    colorPrimary: 0XFF212121,      // Dark text
    colorBorder: 0XFFE0E0E0,       // Light border
    colorFormBorder: 0XFF9E9E9E,   // Form border
    colorBackground: 0XFFFFFFFF,   // White background
  ),
  fontConfig: FontConfig(
    fontSize: 16,
    fontWeight: "normal",
  ),
);
```

### Google Pay Integration

```dart
// Initialize Google Pay
final googlePayConfig = GooglePayConfig(
  merchantId: "your_merchant_id",
  merchantName: "Your Store",
  countryCode: "US",
  currencyCode: "USD",
  totalPrice: 1000,  // Amount in cents
);

await _paymentBridge.initGooglePay(config, googlePayConfig);

// Check availability
final isAvailable = await _paymentBridge.checkGooglePayAvailability();

// Launch Google Pay sheet (implement with your UI)
// After receiving payment data from Google Pay:
await _paymentBridge.tokenizeGooglePayData(paymentData);
```

## Error Handling

```dart
_paymentBridge.onPaymentError = (error) {
  switch (error.errorCode) {
    case 'CARD_NOT_READY':
      // Card view not initialized
      break;
    case 'INVALID_ARGS':
      // Invalid configuration
      break;
    case 'TOKENIZATION_ERROR':
      // Tokenization failed
      break;
    default:
      print('Error: ${error.errorMessage}');
  }
};
```

## Security Best Practices

1. **Never hardcode credentials** - Always fetch session ID and secret from your backend
2. **Use HTTPS** - All communication with your backend should be encrypted
3. **Validate on backend** - Always verify tokens on your server before processing payments
4. **Handle errors gracefully** - Don't expose sensitive error details to users
5. **Use production environment** - Only use `PaymentEnvironment.production` in production builds

## Example

See the `example/` directory for a complete working example.

## Troubleshooting

### Card view not showing
- Verify session credentials are valid and not expired
- Check that `initCardView()` was called before displaying the view
- Inspect Android logs for initialization errors

### Tokenization fails
- Ensure card details are valid
- Verify the component is fully initialized
- Check that callbacks are properly set up

### Build errors
- Ensure `minSdk` is at least 21
- Verify all dependencies are correctly added
- Run `flutter clean` and rebuild

## Platform Support

- ✅ Android (21+)
- ⏳ iOS (coming soon)

## License

MIT License - see LICENSE file for details

## Support

For issues and questions:
- GitHub Issues: [Report a bug](https://github.com/muhammadrashadomar/checkout_flutter_bridge/issues)
- Documentation: See `doc/` directory for detailed guides

---

**Built with ❤️ for Flutter developers**
