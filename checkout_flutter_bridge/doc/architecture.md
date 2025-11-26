# Payment Integration Architecture

## Overview

This document describes the refactored payment integration architecture for the Flutter application with Android native code using Checkout.com SDK.

## Key Principles

1. **Flutter Controls Everything**: All payment logic, UI buttons, and flow control happen in Flutter
2. **Native Provides Components**: Android native code only renders payment input components (card fields, etc.)
3. **Clean API Layer**: Well-defined method channel contract between Dart and Kotlin
4. **Dynamic Configuration**: All configuration passed from Flutter (no hardcoded values in native)
5. **Event-Driven Results**: Async payment results via callbacks on method channel

---

## Architecture Layers

### 1. Flutter Layer (Dart)

#### **Models** (`lib/models/`)

- `payment_config.dart`: Configuration models for payment initialization
  - `PaymentConfig`: Session credentials, environment, appearance
  - `CardConfig`: Card-specific settings
  - `GooglePayConfig`: Google Pay settings
  - `AppearanceConfig`: UI customization (colors, fonts, borders)

- `payment_result.dart`: Result models from native platforms
  - `CardTokenResult`: Tokenized card data
  - `PaymentSuccessResult`: Successful payment info
  - `PaymentErrorResult`: Error details
  - `GooglePayResult`: Google Pay result

#### **Services** (`lib/services/`)

- `payment_bridge.dart`: Unified payment bridge service
  - Singleton pattern
  - Method channel communication
  - Callback registration for payment events
  - Clean API methods:
    - `initCardView(config, cardConfig)`: Initialize card component
    - `validateCard()`: Validate card input
    - `tokenizeCard()`: Trigger card tokenization
    - `initGooglePay(config, googlePayConfig)`: Initialize Google Pay
    - `checkGooglePayAvailability()`: Check device support
    - `launchGooglePaySheet(requestData)`: Launch payment sheet

#### **UI** (`lib/main.dart`)

- `PaymentScreen`: Main payment screen
- `_CardBottomSheet`: Bottom sheet with card input + Flutter button
- `_PlatformCardView`: Platform view wrapper for native card component

---

### 2. Android Native Layer (Kotlin)

#### **MainActivity** (`MainActivity.kt`)

- Registers platform views (card, Google Pay)
- Sets up method channel handler
- Captures platform view instances for method calls
- Routes method calls to appropriate component

**Method Channel Contract:**

```kotlin
// Card Methods
"initCardView" -> Initialize card view (optional, done in PlatformView)
"validateCard" -> Returns bool: is card input valid
"tokenizeCard" -> Triggers tokenization, result via callback

// Google Pay Methods
"initGooglePay" -> Initialize Google Pay (optional)
"checkGooglePayAvailability" -> Returns bool: is Google Pay available
"launchGooglePaySheet" -> Launch payment sheet, result via callback
```

#### **CardPlatformView** (`CardPlatformView.kt`)

**Responsibilities:**
- Renders card input fields (no button)
- Receives configuration from Flutter
- Handles tokenization when triggered by Flutter button
- Sends events back to Flutter via method channel

**Key Features:**
- `showPayButton = false`: Hides native pay button
- `paymentButtonAction = PaymentButtonAction.TOKENIZE`: Set to tokenize mode
- Dynamic configuration (colors, fonts, borders, environment)
- Proper error handling and logging

**Callbacks to Flutter:**
```kotlin
channel.invokeMethod("cardTokenized", tokenData)
channel.invokeMethod("paymentSuccess", paymentId)
channel.invokeMethod("paymentError", errorData)
```

#### **GooglePayPlatformView** (`GooglePayPlatformView.kt`)

**Responsibilities:**
- Provides Google Pay payment sheet logic only
- NO native button (Flutter uses `flutter_pay` or renders custom button)
- Handles activity results from Google Pay sheet
- Sends results back to Flutter

**Note**: In future iterations, you may remove this entirely and use `flutter_pay` package directly. This exists for Checkout.com SDK integration compatibility.

#### **Factory Classes**

- `CardViewFactory`: Creates `CardPlatformView` instances
- `GooglePayViewFactory`: Creates `GooglePayPlatformView` instances
- Both provide callbacks to capture instances for method channel operations

---

## Flow Diagrams

### Card Tokenization Flow

```
[Flutter UI]
    |
    | 1. User enters card details
    v
[Native Card Input Component]
    |
    | 2. User presses Flutter "Pay" button
    v
[PaymentBridge.tokenizeCard()]
    |
    | 3. Method channel call: "tokenizeCard"
    v
[MainActivity.handleMethodCall()]
    |
    | 4. Route to CardPlatformView
    v
[CardPlatformView.tokenizeCard()]
    |
    | 5. Call SDK: cardComponent.tokenize()
    v
[Checkout.com SDK]
    |
    | 6. Tokenization result
    v
[ComponentCallback.onTokenized]
    |
    | 7. Method channel callback: "cardTokenized"
    v
[PaymentBridge.onCardTokenized]
    |
    | 8. Display result to user
    v
[Flutter UI]
```

### Google Pay Flow (Future with flutter_pay)

```
[Flutter UI]
    |
    | 1. User presses Flutter Google Pay button
    v
[flutter_pay package]
    |
    | 2. Check availability
    |
    | 3. Launch Google Pay sheet
    v
[Google Pay SDK]
    |
    | 4. Payment completion
    v
[flutter_pay result]
    |
    | 5. Process payment with backend
    v
[Flutter UI]
```

---

## Configuration Examples

### Flutter Side

```dart
// Create payment configuration
final config = PaymentConfig(
  paymentSessionId: "ps_xxx",
  paymentSessionSecret: "pss_xxx",
  publicKey: "pk_sbox_xxx",
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

// Initialize card view
final cardConfig = CardConfig(
  showCardholderName: false,
  enableBillingAddress: false,
);
await paymentBridge.initCardView(config, cardConfig);

// Set up callbacks
paymentBridge.onCardTokenized = (result) {
  print('Token: ${result.token}');
  print('Last 4: ${result.last4}');
  print('Brand: ${result.brand}');
};

// Trigger tokenization
await paymentBridge.tokenizeCard();
```

### Android Side

Configuration is automatically parsed from Flutter params:

```kotlin
// Received from Flutter as Map
val sessionId = params["paymentSessionID"] as? String
val environment = params["environment"] as? String // "sandbox" or "production"
val appearance = params["appearance"] as? Map<*, *>

// Converted to SDK types
val env = when (environment) {
  "production" -> Environment.PRODUCTION
  else -> Environment.SANDBOX
}
```

---

## Improvements Over Previous Architecture

### Before:
- ❌ Hardcoded values in Android code
- ❌ Native buttons mixed with Flutter UI
- ❌ Unclear control flow between Flutter and native
- ❌ Mixed responsibilities (UI, logic, callbacks)
- ❌ Difficult to test and maintain
- ❌ Poor error handling

### After:
- ✅ All configuration from Flutter (dynamic)
- ✅ Clear separation: Flutter UI, native components
- ✅ Well-defined method channel API
- ✅ Single responsibility per class
- ✅ Easy to test and maintain
- ✅ Comprehensive error handling and logging
- ✅ Production-ready architecture
- ✅ Extensible for future payment methods

---

## Safety Recommendations

1. **Environment Validation**: Always validate environment in production builds
2. **Session Security**: Never log or display session secrets
3. **Error Handling**: Always handle PlatformException in Flutter
4. **Timeout Handling**: Implement timeouts for async operations
5. **State Management**: Consider using proper state management (Bloc, Riverpod) for production
6. **Testing**: Add unit tests for PaymentBridge and integration tests for flows
7. **Logging**: Remove sensitive data from logs in production
8. **Token Storage**: Never store tokens in SharedPreferences without encryption

---

## Future Enhancements

1. **Replace Google Pay native with flutter_pay**:
   - Remove `GooglePayPlatformView` entirely
   - Use pure Dart implementation
   - Simpler integration

2. **Add validation methods**:
   - `validateCardNumber()`
   - `validateExpiry()`
   - `validateCVV()`

3. **Add payment method detection**:
   - Auto-detect card brand as user types
   - Show appropriate card logo

4. **Add 3DS handling**:
   - Handle 3D Secure authentication flow
   - Proper challenge handling

5. **Add stored cards**:
   - List saved payment methods
   - One-tap payments

6. **Analytics integration**:
   - Track payment events
   - Monitor success/failure rates

---

## Troubleshooting

### Card component not showing
- Check that `paymentSessionID`, `paymentSessionSecret`, and `publicKey` are valid
- Check Android logs for initialization errors
- Verify environment setting matches your credentials

### Tokenization not working
- Ensure card component is fully initialized before calling `tokenizeCard()`
- Check that card input is valid
- Verify callbacks are properly set in PaymentBridge

### Method channel errors
- Ensure MainActivity properly captures platform view instances
- Check method names match exactly between Dart and Kotlin
- Verify method channel name is consistent: `"checkout_bridge"`

### Google Pay not available
- Check device supports Google Pay
- Verify Google Play Services is installed and up-to-date
- Check merchant configuration in Checkout.com dashboard

---

## Contact & Support

For issues with:
- **Flutter integration**: Check `lib/services/payment_bridge.dart`
- **Android native**: Check `CardPlatformView.kt` and `MainActivity.kt`
- **Checkout.com SDK**: Consult official Checkout.com documentation
- **Architecture questions**: Refer to this document

---

## Conclusion

This refactored architecture provides a clean, maintainable, and production-ready payment integration. All logic is controlled from Flutter, with native code serving only as a rendering layer for payment input components. The clear API contract makes it easy to add new payment methods or modify existing behavior.
