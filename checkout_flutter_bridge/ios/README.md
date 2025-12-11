# iOS Integration Guide

## Requirements

- **iOS**: 15.0+
- **Xcode**: 16.0+
- **Swift**: 6.0
- **Architecture**: arm64 only

## Setup

### 1. Add Checkout.com iOS SDK via Swift Package Manager

1. Open your iOS project in Xcode (located in `ios/Runner.xcodeproj`)
2. Go to **File > Add Package Dependencies**
3. Add the following URL:
   ```
   https://github.com/checkout/checkout-ios-components
   ```
4. Select the latest version and add to your main target

### 2. Configure Apple Pay (if using)

#### A. Create Apple Merchant ID

1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles > Identifiers**
3. Click **+** and select **Merchant IDs**
4. Register a new Merchant ID (e.g., `merchant.com.yourcompany.yourapp`)

#### B. Generate and Upload Apple Pay Certificate

1. Generate a certificate signing request from Checkout.com:

   **Sandbox:**
   ```bash
   curl --location --request POST 'https://api.sandbox.checkout.com/applepay/signing-requests' \
   --header 'Authorization: Bearer pk_sbox_xxx' \
   | jq -r '.content' > ~/Desktop/cko.csr
   ```

   **Production:**
   ```bash
   curl --location --request POST 'https://api.checkout.com/applepay/signing-requests' \
   --header 'Authorization: Bearer pk_xxx' \
   | jq -r '.content' > ~/Desktop/cko.csr
   ```

2. In Apple Developer Portal, go to your Merchant ID
3. Under **Apple Pay Payment Processing Certificate**, click **Create Certificate**
4. Upload the `cko.csr` file
5. Download the generated certificate (`apple_pay.cer`)

6. Upload the certificate to Checkout.com:

   **Sandbox:**
   ```bash
   curl --location --request POST 'https://api.sandbox.checkout.com/applepay/certificates' \
   --header 'Authorization: Bearer pk_sbox_xxx' \
   --header 'Content-Type: application/json' \
   --data-raw '{
     "content": "'"$(openssl x509 -inform der -in apple_pay.cer | base64)"'"
   }'
   ```

   **Production:**
   ```bash
   curl --location --request POST 'https://api.checkout.com/applepay/certificates' \
   --header 'Authorization: Bearer pk_xxx' \
   --header 'Content-Type: application/json' \
   --data-raw '{
     "content": "'"$(openssl x509 -inform der -in apple_pay.cer | base64)"'"
   }'
   ```

#### C. Add Entitlements

1. In Xcode, select your app target
2. Go to **Signing & Capabilities**
3. Click **+ Capability** and add **Apple Pay**
4. Add your Merchant ID to the list

Alternatively, create/edit `ios/Runner/Runner.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.in-app-payments</key>
    <array>
        <string>merchant.com.yourcompany.yourapp</string>
    </array>
</dict>
</plist>
```

#### D. Update Info.plist

Add Apple Pay usage description to `ios/Runner/Info.plist`:

```xml
<key>NSApplePayUsageDescription</key>
<string>This app uses Apple Pay to process secure payments</string>
```

## Usage

### Card Payment

```dart
import 'package:checkout_flutter_bridge/checkout_flutter_bridge.dart';

// Initialize
final paymentBridge = PaymentBridge();
paymentBridge.initialize();

// Configure
final config = PaymentConfig(
  paymentSessionId: "ps_xxx",
  paymentSessionSecret: "pss_xxx",
  publicKey: "pk_sbox_xxx",
  environment: PaymentEnvironment.sandbox,
);

final cardConfig = CardConfig(
  showCardholderName: false,
);

// Initialize card view
await paymentBridge.initCardView(config, cardConfig);

// Display card input (iOS)
UiKitView(
  viewType: 'flow_card_view',
  creationParams: config.toMap(),
  creationParamsCodec: const StandardMessageCodec(),
)

// Tokenize
final token = await paymentBridge.tokenizeCard();
```

### Apple Pay

```dart
// Configure Apple Pay
final applePayConfig = ApplePayConfig(
  merchantIdentifier: 'merchant.com.yourcompany.yourapp',
  merchantName: 'Your Store',
  countryCode: 'US',
  currencyCode: 'USD',
);

// Initialize
await paymentBridge.initApplePay(config, applePayConfig);

// Check availability
final isAvailable = await paymentBridge.checkApplePayAvailability();

if (isAvailable) {
  // Display Apple Pay button
  UiKitView(
    viewType: 'flow_applepay_view',
    creationParams: {...config.toMap(), 'applePayConfig': applePayConfig.toMap()},
    creationParamsCodec: const StandardMessageCodec(),
  )
  
  // Tokenize
  final token = await paymentBridge.tokenizeApplePay();
}
```

## Testing

- **Card payments**: Can be tested in iOS Simulator
- **Apple Pay**: Requires a physical device with Apple Pay set up
- Use [Checkout.com test cards](https://www.checkout.com/docs/testing/test-cards)

## Troubleshooting

### SPM Cache Issues

If you encounter SPM caching issues, run:

```bash
cd ios
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/org.swift.swiftpm
rm -rf .build
rm -f Package.resolved
xcodebuild -resolvePackageDependencies
```

### Apple Pay Not Available

- Ensure you're testing on a physical device
- Verify Apple Pay is set up in Wallet app
- Check that your Merchant ID is correctly configured
- Verify entitlements file includes your Merchant ID

### Build Errors

- Ensure Xcode 16+ is installed
- Verify iOS deployment target is set to 15.0+
- Check that Swift 6 is selected in build settings

## Notes

- The iOS implementation mirrors the Android architecture
- All payment flows are controlled from Flutter
- No native payment buttons are rendered (Flutter controls UI)
- Callbacks are used for all async operations
