# Integration Guide

Complete guide for integrating the Checkout Flutter Bridge into your Flutter application.

## Table of Contents

1. [Installation](#installation)
2. [Android Setup](#android-setup)
3. [Basic Integration](#basic-integration)
4. [Advanced Features](#advanced-features)
5. [Best Practices](#best-practices)

## Installation

### 1. Add Package Dependency

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  checkout_flutter_bridge:
    path: path/to/checkout_flutter_bridge
    # Or use git:
    # checkout_flutter_bridge:
    #   git:
    #     url: https://github.com/your-repo/checkout_flutter_bridge.git
    #     ref: main
```

### 2. Install Dependencies

```bash
flutter pub get
```

## Android Setup

### Prerequisites

- Minimum SDK: 21
- Compile SDK: 35
- Kotlin: 2.1.0+

### 1. Update gradle.properties

Add to `android/gradle.properties`:

```properties
checkout_version=1.2.0
```

### 2. Update AndroidManifest.xml

Add Google Wallet metadata to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
    <application>
        <!-- ... other configurations ... -->
        
        <meta-data 
            android:name="com.google.android.gms.wallet.api.enabled" 
            android:value="true" />
    </application>
</manifest>
```

### 3. Update build.gradle (if needed)

Ensure your `android/app/build.gradle` has:

```gradle
android {
    compileSdk 35
    
    defaultConfig {
        minSdk 21
        targetSdk 35
    }
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_11
        targetCompatibility JavaVersion.VERSION_11
    }
    
    kotlinOptions {
        jvmTarget = '11'
    }
}
```

## Basic Integration

### Step 1: Import the Package

```dart
import 'package:checkout_flutter_bridge/checkout_flutter_bridge.dart';
```

### Step 2: Create a Payment Service

```dart
class PaymentService {
  final PaymentBridge _bridge = PaymentBridge();
  
  // Callbacks
  Function(CardTokenResult)? onSuccess;
  Function(PaymentErrorResult)? onError;
  
  void initialize() {
    _bridge.initialize();
    
    _bridge.onCardTokenized = (result) {
      print('✅ Token: ${result.token}');
      onSuccess?.call(result);
    };
    
    _bridge.onPaymentError = (error) {
      print('❌ Error: ${error.errorMessage}');
      onError?.call(error);
    };
  }
  
  Future<void> tokenizeCard() async {
    final isValid = await _bridge.validateCard();
    if (isValid) {
      await _bridge.tokenizeCard();
    }
  }
  
  void dispose() {
    _bridge.dispose();
  }
}
```

### Step 3: Get Payment Session from Backend

**Never hardcode session credentials in your app!**

```dart
// Example backend API call
Future<PaymentConfig> fetchPaymentSession(int amountInCents) async {
  final response = await http.post(
    Uri.parse('https://your-backend.com/api/payment/session'),
    body: json.encode({'amount': amountInCents}),
  );
  
  final data = json.decode(response.body);
  
  return PaymentConfig(
    paymentSessionId: data['sessionId'],
    paymentSessionSecret: data['sessionSecret'],
    publicKey: data['publicKey'],
    environment: PaymentEnvironment.production,
  );
}
```

### Step 4: Display Card Input

```dart
class PaymentScreen extends StatefulWidget {
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  PaymentConfig? _config;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _paymentService.initialize();
    _loadPaymentSession();
  }
  
  Future<void> _loadPaymentSession() async {
    final config = await fetchPaymentSession(1000); // $10.00
    
    final cardConfig = CardConfig(
      showCardholderName: false,
      enableBillingAddress: false,
    );
    
    await _paymentService._bridge.initCardView(config, cardConfig);
    
    setState(() {
      _config = config;
      _isLoading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    return Column(
      children: [
        // Native card input
        SizedBox(
          height: 200,
          child: AndroidView(
            viewType: 'flow_card_view',
            creationParams: _config!.toMap(),
            creationParamsCodec: StandardMessageCodec(),
          ),
        ),
        
        SizedBox(height: 16),
        
        // Pay button
        ElevatedButton(
          onPressed: () => _paymentService.tokenizeCard(),
          child: Text('Pay \$10.00'),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }
}
```

## Advanced Features

### Custom Appearance

```dart
final appearance = AppearanceConfig(
  borderRadius: 12,
  colorTokens: ColorTokens(
    colorAction: 0XFF4CAF50,      // Button color
    colorPrimary: 0XFF212121,     // Text color
    colorBorder: 0XFFE0E0E0,      // Border color
    colorFormBorder: 0XFF9E9E9E,  // Input border
    colorBackground: 0XFFFFFFFF,  // Background
  ),
  fontConfig: FontConfig(
    fontSize: 16,
    fontWeight: "semibold",
  ),
);

final config = PaymentConfig(
  // ... other params
  appearance: appearance,
);
```

### Saved Cards

```dart
// Load saved card from your backend
final savedCard = SavedCardConfig(
  paymentSourceId: "src_xxx",  // From Checkout.com
  last4: "4242",
  scheme: "visa",
  expiryMonth: 12,
  expiryYear: 2025,
);

// Initialize stored card view
await _bridge.initStoredCardView(config, savedCard);

// Tokenize (only CVV required)
await _bridge.tokenizeSavedCard();
```

### Google Pay

```dart
// Check availability
final isAvailable = await _bridge.checkGooglePayAvailability();

if (isAvailable) {
  // Initialize
  final googlePayConfig = GooglePayConfig(
    merchantId: "your_merchant_id",
    merchantName: "Your Store",
    countryCode: "US",
    currencyCode: "USD",
    totalPrice: 1000,
  );
  
  await _bridge.initGooglePay(config, googlePayConfig);
  
  // After collecting payment data from Google Pay:
  await _bridge.tokenizeGooglePayData(paymentDataString);
}
```

## Best Practices

### 1. Security

✅ **DO:**
- Fetch session credentials from your secure backend
- Use HTTPS for all API calls
- Validate tokens on your backend before processing
- Use `PaymentEnvironment.production` in production

❌ **DON'T:**
- Hardcode session secrets in your app
- Store tokens in SharedPreferences without encryption
- Log sensitive payment data
- Trust client-side validation alone

### 2. Error Handling

```dart
_bridge.onPaymentError = (error) {
  switch (error.errorCode) {
    case 'CARD_NOT_READY':
      showSnackBar('Please wait for card input to load');
      break;
    case 'INVALID_ARGS':
      showSnackBar('Invalid configuration');
      break;
    case 'TOKENIZATION_ERROR':
      showSnackBar('Payment failed. Please check your card details.');
      break;
    default:
      showSnackBar('An error occurred. Please try again.');
  }
};
```

### 3. Loading States

```dart
class PaymentButton extends StatefulWidget {
  @override
  State<PaymentButton> createState() => _PaymentButtonState();
}

class _PaymentButtonState extends State<PaymentButton> {
  bool _isProcessing = false;
  
  Future<void> _handlePayment() async {
    setState(() => _isProcessing = true);
    
    try {
      await paymentService.tokenizeCard();
    } finally {
      setState(() => _isProcessing = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isProcessing ? null : _handlePayment,
      child: _isProcessing
          ? CircularProgressIndicator()
          : Text('Pay Now'),
    );
  }
}
```

### 4. Backend Integration

Your backend should:

1. **Create Payment Session:**
```python
# Python example
@app.route('/api/payment/session', methods=['POST'])
def create_payment_session():
    amount = request.json['amount']
    
    # Call Checkout.com API
    response = checkout_client.sessions.create({
        'amount': amount,
        'currency': 'USD',
        'success_url': 'https://your-app.com/success',
        'failure_url': 'https://your-app.com/failure',
    })
    
    return jsonify({
        'sessionId': response.id,
        'sessionSecret': response.secret,
        'publicKey': PUBLIC_KEY,
    })
```

2. **Process Token:**
```python
@app.route('/api/payment/process', methods=['POST'])
def process_payment():
    token = request.json['token']
    amount = request.json['amount']
    
    # Use token to create payment
    payment = checkout_client.payments.request({
        'source': {
            'type': 'token',
            'token': token,
        },
        'amount': amount,
        'currency': 'USD',
    })
    
    return jsonify({
        'success': payment.approved,
        'paymentId': payment.id,
    })
```

### 5. Testing

Use Checkout.com test cards:

| Brand | Number | CVV | Expiry |
|-------|--------|-----|--------|
| Visa | 4242 4242 4242 4242 | Any | Future |
| Mastercard | 5436 0310 3060 6378 | Any | Future |
| Amex | 3782 822463 10005 | Any | Future |

### 6. Production Checklist

- [ ] All credentials from backend
- [ ] Using `PaymentEnvironment.production`
- [ ] Proper error handling implemented
- [ ] Loading states for all async operations
- [ ] Tested with real test credentials
- [ ] Backend validates all tokens
- [ ] HTTPS for all API calls
- [ ] No sensitive data in logs

## Troubleshooting

### Issue: Card view not showing

**Solution:**
1. Check that `initCardView()` was called successfully
2. Verify session credentials are valid
3. Check Android logs: `flutter logs | grep Checkout`

### Issue: Tokenization fails silently

**Solution:**
1. Ensure `onCardTokenized` callback is set before tokenizing
2. Check that card details are valid
3. Verify component is fully initialized

### Issue: Build errors on Android

**Solution:**
1. Ensure `minSdk >= 21`
2. Run `flutter clean && flutter pub get`
3. Check Kotlin version is 2.0+

## Next Steps

- Review the [Architecture Guide](architecture.md)
- See the [Example App](../example/README.md)
- Check the [API Reference](../README.md#api-reference)

## Support

For issues:
- GitHub: [Report an issue](https://github.com/muhammadrashadomar/checkout_flutter_bridge/issues)
- Documentation: [Full docs](../README.md)
