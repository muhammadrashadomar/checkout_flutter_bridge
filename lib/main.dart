import 'dart:async';
import 'dart:convert';

import 'package:flow_flutter_new/utils/console_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pay/pay.dart';

import 'models/google_pay_config.dart';
import 'models/payment_config.dart';
import 'models/payment_result.dart';
import 'services/payment_bridge.dart';

// Debug flag - set to false in production
const bool _enableDebugLogging = kDebugMode;

// Google Pay Configuration
const String paymentSessionId = 'ps_35yfyWifVDMIRmbpdVrsBy5Gwb6';
const String paymentSessionSecret = 'pss_5345e898-e2d5-48ed-84fa-ce2d8b12fbf0';
const String publicKey = 'pk_sbox_fjizign6afqbt3btt3ialiku74s';
const String envMode = 'TEST';
const String currency = 'SAR';
const double totalPrice = 10.00;

//* Create a new payment session every time the open the card sheet

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
  PaymentConfig get _paymentConfig => PaymentConfig(
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

    // Optional debug logging (only in debug mode)
    if (_enableDebugLogging) {
      ConsoleLogger.success(
        'Token received - Type: ${result.type}, Network: ${result.cardNetwork ?? result.scheme}',
      );
    }

    // Build a more detailed message based on payment type
    String message;
    if (result.type?.toLowerCase() == 'googlepay') {
      // Google Pay tokenization
      message =
          'Payment Method: Google Pay\n'
          'Token: ${result.token}\n'
          'Card Network: ${result.cardNetwork ?? result.scheme ?? 'N/A'}';

      if (result.last4 != null && result.last4!.isNotEmpty) {
        message += '\nLast 4 Digits: ${result.last4}';
      }
    } else {
      // Card tokenization
      message =
          'Payment Method: Card\n'
          'Token: ${result.token}\n'
          'Last 4: ${result.last4 ?? 'N/A'}\n'
          'Brand: ${result.brand ?? 'N/A'}\n'
          'Expiry: ${result.expiryMonth ?? 'N/A'}/${result.expiryYear ?? 'N/A'}';
    }

    ConsoleLogger.success(message);
  }

  void _handlePaymentSuccess(PaymentSuccessResult result) {
    setState(() => _isProcessing = false);

    ConsoleLogger.success('Payment ID: ${result.paymentId}');
  }

  void _handlePaymentError(PaymentErrorResult result) {
    setState(() => _isProcessing = false);

    if (_enableDebugLogging) {
      ConsoleLogger.error(
        'Payment error: ${result.errorCode} - ${result.errorMessage}',
      );
    }

    // Provide user-friendly error messages based on error codes
    final userMessage = _getUserFriendlyErrorMessage(
      result.errorCode,
      result.errorMessage,
    );

    ConsoleLogger.error('Payment Error: $userMessage');
  }

  /// Convert technical error codes to user-friendly messages
  String _getUserFriendlyErrorMessage(
    String errorCode,
    String technicalMessage,
  ) {
    switch (errorCode) {
      case 'INVALID_CONFIG':
        return 'Payment configuration error. Please contact support.';
      case 'GOOGLEPAY_UNAVAILABLE':
      case 'GOOGLEPAY_NOT_AVAILABLE':
        return 'Google Pay is not available on this device. Please use another payment method.';
      case 'INITIALIZATION_FAILED':
      case 'INIT_ERROR':
        return 'Failed to initialize payment. Please try again.';
      case 'TOKENIZATION_FAILED':
      case 'TOKENIZATION_ERROR':
        return 'Payment processing failed. Please try again or use another payment method.';
      case 'TIMEOUT':
        return 'Payment request timed out. Please check your connection and try again.';
      case 'INVALID_STATE':
        return 'Payment system not ready. Please wait a moment and try again.';
      case 'PAYMENT_ERROR':
        return 'Payment failed: $technicalMessage';
      default:
        return 'An error occurred: $technicalMessage';
    }
  }

  void _handleSessionData(String result) {
    setState(() => _isProcessing = false);
    ConsoleLogger.success('Session Data: $result');
  }

  Future<void> _getSessionData(String method) async {
    setState(() => _isProcessing = true);
    await _paymentBridge.submit(method);
    setState(() => _isProcessing = false);
  }

  void _showCardSheet() async {
    try {
      debugPrint('[PaymentScreen] Initializing Google Pay for card sheet');

      final success = await _paymentBridge.initGooglePay(
        _paymentConfig,
        GooglePayConfig(
          merchantId: publicKey,
          merchantName: 'Mac Queen',
          countryCode: 'SA',
          currencyCode: currency,
          totalPrice: totalPrice.toInt(),
        ),
      );

      if (!success) {
        debugPrint('[PaymentScreen] Failed to initialize Google Pay');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to initialize payment system'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

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
    } catch (e, stackTrace) {
      debugPrint('[PaymentScreen] Error showing card sheet: $e');
      debugPrint('[PaymentScreen] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open payment sheet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

            const SizedBox(height: 50),
            //Submit Button
            ElevatedButton(
              onPressed: () => _getSessionData('card'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
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
    try {
      debugPrint('[GooglePayButton] Initializing Google Pay tokenizer');

      final success = await widget.paymentBridge.initGooglePay(
        widget.paymentConfig,
        GooglePayConfig(
          merchantId: publicKey,
          merchantName: 'Mac Queen',
          countryCode: 'SA',
          currencyCode: currency,
          totalPrice: totalPrice.toInt(),
        ),
      );

      if (success) {
        setState(() => _isInitialized = true);
        debugPrint(
          '[GooglePayButton] Google Pay tokenizer initialized successfully',
        );
      } else {
        debugPrint(
          '[GooglePayButton] Failed to initialize Google Pay tokenizer',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Pay is not available'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[GooglePayButton] Error initializing Google Pay: $e');
      debugPrint('[GooglePayButton] Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize Google Pay: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onGooglePayResult(Map<String, dynamic> result) async {
    widget.onProcessing(true);
    debugPrint('[GooglePayButton] Received Google Pay result');

    try {
      // Validate result
      if (result.isEmpty) {
        throw Exception('Empty payment result received');
      }

      // Extract payment data
      final paymentData = json.encode(result);
      debugPrint('[GooglePayButton] Sending payment data for tokenization');

      // Send to native platform for Checkout SDK tokenization with timeout
      await widget.paymentBridge
          .tokenizeGooglePayData(paymentData)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Tokenization timed out after 30 seconds');
            },
          );

      debugPrint('[GooglePayButton] Payment data sent successfully');
      widget.onProcessing(false);
      // Note: Actual result will come via callback
    } on TimeoutException catch (e) {
      debugPrint('[GooglePayButton] Timeout error: $e');
      widget.onProcessing(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment request timed out. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[GooglePayButton] Payment processing error: $e');
      debugPrint('[GooglePayButton] Stack trace: $stackTrace');
      widget.onProcessing(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment processing failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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
class _CardBottomSheet extends StatefulWidget {
  final PaymentConfig paymentConfig;
  final Function(bool) onProcessing;
  final VoidCallback onInitialized;

  const _CardBottomSheet({
    required this.paymentConfig,
    required this.onProcessing,
    required this.onInitialized,
  });

  @override
  State<_CardBottomSheet> createState() => _CardBottomSheetState();
}

class _CardBottomSheetState extends State<_CardBottomSheet> {
  final PaymentBridge _paymentBridge = PaymentBridge();
  bool _isProcessing = false;

  Future<void> _tokenizeCard() async {
    setState(() => _isProcessing = true);
    widget.onProcessing(true);

    // Validate card first
    final isValid = await _paymentBridge.validateCard();

    if (!isValid) {
      setState(() => _isProcessing = false);
      widget.onProcessing(false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please check your card details'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      return;
    }

    // Trigger tokenization
    await _paymentBridge.tokenizeCard();
    // The _isProcessing state will be reset by the callback in parent

    setState(() => _isProcessing = false);
    widget.onProcessing(false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
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
            child: _PlatformCardView(paymentConfig: widget.paymentConfig),
          ),

          const SizedBox(height: 16),

          // Tokenize Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _tokenizeCard,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Tokenize Card',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
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

    return const SizedBox.shrink();
  }
}
