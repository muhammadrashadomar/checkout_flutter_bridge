import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pay/pay.dart';

import 'models/google_pay_config.dart';
import 'models/payment_config.dart';
import 'models/payment_result.dart';
import 'services/payment_bridge.dart';

// Google Pay Configuration
const String paymentSessionId = 'ps_35wCHgsxgeZBc8QHGtl7Y3tiTSN';
const String paymentSessionSecret = 'pss_c089f9cc-236b-4f9b-a139-adc863c96113';
const String publicKey = 'pk_sbox_fjizign6afqbt3btt3ialiku74s';
const String envMode = 'TEST';
const String currency = 'SAR';
const double totalPrice = 10.00;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Payment Integration',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const PaymentScreen(),
    );
  }
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentBridge _paymentBridge = PaymentBridge();

  bool _isProcessing = false;

  // Payment configuration
  final PaymentConfig _paymentConfig = PaymentConfig(
    paymentSessionId: paymentSessionId,
    paymentSessionSecret: paymentSessionSecret,
    publicKey: publicKey,
    environment: PaymentEnvironment.sandbox,
    appearance: AppearanceConfig(
      borderRadius: 8,
      colorTokens: ColorTokens(
        colorAction: 0XFF00639E,
        colorPrimary: 0XFF111111,
        colorBorder: 0XFFCCCCCC,
        colorFormBorder: 0XFFCCCCCC,
      ),
    ),
  );

  @override
  void initState() {
    super.initState();
    _setupPaymentBridge();
  }

  void _setupPaymentBridge() {
    _paymentBridge.initialize();

    // Set up payment callbacks
    _paymentBridge.onCardTokenized = _handleCardTokenized;
    _paymentBridge.onPaymentSuccess = _handlePaymentSuccess;
    _paymentBridge.onPaymentError = _handlePaymentError;
    _paymentBridge.onSessionData = _handleSessionData;
  }

  void _handleCardTokenized(CardTokenResult result) {
    setState(() => _isProcessing = false);
    _showResultDialog(
      'Card Tokenized',
      'Token: ${result.token}\n'
          'Last 4: ${result.last4 ?? 'N/A'}\n'
          'Brand: ${result.brand ?? 'N/A'}\n'
          'Expiry: ${result.expiryMonth ?? 'N/A'}/${result.expiryYear ?? 'N/A'}',
      isSuccess: true,
    );
  }

  void _handlePaymentSuccess(PaymentSuccessResult result) {
    setState(() => _isProcessing = false);
    _showResultDialog(
      'Payment Successful',
      'Payment ID: ${result.paymentId}',
      isSuccess: true,
    );
  }

  void _handlePaymentError(PaymentErrorResult result) {
    setState(() => _isProcessing = false);
    _showResultDialog(
      'Payment Error',
      'Error: ${result.errorMessage}\nCode: ${result.errorCode}',
      isSuccess: false,
    );
  }

  void _handleSessionData(String result) {
    setState(() => _isProcessing = false);
    _showResultDialog(
      'Session Data Retrieved',
      'Session Data received - ready to send to backend',
      isSuccess: true,
    );
  }

  void _showResultDialog(
    String title,
    String message, {
    required bool isSuccess,
  }) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(title)),
              ],
            ),
            content: SingleChildScrollView(child: Text(message)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showCardSheet() async {
    await _paymentBridge.initGooglePay(
      _paymentConfig,
      GooglePayConfig(
        merchantId: publicKey,
        merchantName: 'Mac Queen',
        countryCode: 'SA',
        currencyCode: currency,
        totalPrice: totalPrice.toInt(),
      ),
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _CardBottomSheet(
            paymentConfig: _paymentConfig,
            onProcessing: (processing) {
              setState(() => _isProcessing = processing);
            },
            onInitialized: () {
              // No longer setting _cardInitialized
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Integration Demo'),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            const Center(
              child: Text(
                'Choose Payment Method',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),

            // Card Payment Button
            _PaymentMethodButton(
              icon: Icons.credit_card,
              label: 'Pay with Card',
              description: 'Enter card details securely',
              onTap: _showCardSheet,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),

            // Google Pay Button
            _GooglePayButton(
              paymentBridge: _paymentBridge,
              paymentConfig: _paymentConfig,
              onProcessing: (processing) {
                setState(() => _isProcessing = processing);
              },
            ),

            if (_isProcessing) ...[
              const SizedBox(height: 24),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Processing payment...'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Payment Method Button Widget
class _PaymentMethodButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final Color color;

  const _PaymentMethodButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// Google Pay Button Widget using pay package
class _GooglePayButton extends StatefulWidget {
  final PaymentBridge paymentBridge;
  final PaymentConfig paymentConfig;
  final Function(bool) onProcessing;

  const _GooglePayButton({
    required this.paymentBridge,
    required this.paymentConfig,
    required this.onProcessing,
  });

  @override
  State<_GooglePayButton> createState() => _GooglePayButtonState();
}

class _GooglePayButtonState extends State<_GooglePayButton> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeGooglePayTokenizer();
  }

  Future<void> _initializeGooglePayTokenizer() async {
    // Initialize the Checkout SDK Google Pay tokenizer
    try {
      await widget.paymentBridge.initGooglePay(
        widget.paymentConfig,
        GooglePayConfig(
          merchantId: publicKey,
          merchantName: 'Mac Queen',
          countryCode: 'SA',
          currencyCode: currency,
          totalPrice: totalPrice.toInt(),
        ),
      );
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Failed to initialize Google Pay tokenizer: $e');
    }
  }

  void _onGooglePayResult(Map<String, dynamic> result) async {
    widget.onProcessing(true);

    try {
      // Extract payment data
      final paymentData = json.encode(result);

      // Send to native platform for Checkout SDK tokenization
      await widget.paymentBridge.tokenizeGooglePayData(paymentData);

      widget.onProcessing(false);
    } catch (e) {
      widget.onProcessing(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment processing failed: $e')),
        );
      }
    }
  }

  PaymentConfiguration _getGooglePaymentConfig() {
    return PaymentConfiguration.fromJsonString(
      kGooglePaymentConfig(
        publicKey: publicKey,
        totalPrice: totalPrice,
        currencyCode: currency,
        envMode: envMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Google Pay',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '$currency $totalPrice',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GooglePayButton(
              paymentConfiguration: _getGooglePaymentConfig(),
              paymentItems: [
                PaymentItem(
                  label: 'Total',
                  amount: totalPrice.toString(),
                  status: PaymentItemStatus.final_price,
                ),
              ],
              width: double.infinity,
              height: 50,
              type: GooglePayButtonType.pay,
              onPaymentResult: _onGooglePayResult,
              loadingIndicator: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Card Bottom Sheet
class _CardBottomSheet extends StatelessWidget {
  final PaymentConfig paymentConfig;
  final Function(bool) onProcessing;
  final VoidCallback onInitialized;

  const _CardBottomSheet({
    required this.paymentConfig,
    required this.onProcessing,
    required this.onInitialized,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Card Payment',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),

          // Card view
          SizedBox(
            height: 350,
            child: _PlatformCardView(paymentConfig: paymentConfig),
          ),
        ],
      ),
    );
  }
}

// Platform Card View
class _PlatformCardView extends StatelessWidget {
  final PaymentConfig paymentConfig;

  const _PlatformCardView({required this.paymentConfig});

  @override
  Widget build(BuildContext context) {
    const viewType = 'flow_card_view';
    final creationParams = paymentConfig.toMap();

    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: viewType,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'flow_view_card',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }

    return const Center(child: Text('Platform not supported'));
  }
}
