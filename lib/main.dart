import 'package:checkout_flutter_bridge/checkout_flutter_bridge.dart';
import 'package:flutter/material.dart';

// Google Pay Configuration
const String paymentSessionId = 'ps_36EnX37ba2rnCrXyjd3i3VYVJT9';
const String paymentSessionSecret = 'pss_51352b45-9839-47a9-92b4-c7aa272f3b67';
const String publicKey = 'pk_sbox_abveb2d5jdvf5sompdwbgyndjm5';

// Payment configuration
final _paymentConfig = PaymentConfig(
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
  var currentPaymentType = CurrentPaymentType.card;

  final PaymentBridge _paymentBridge = PaymentBridge();

  @override
  void initState() {
    super.initState();
    _setupPaymentBridge();
  }

  void _setupPaymentBridge() {
    _paymentBridge.initialize();
  }

  // void _handleCardTokenized(CardTokenResult result) {
  //   ConsoleLogger.success(
  //     'Token received - Type: ${result.type}, Network: ${result.cardNetwork ?? result.scheme}',
  //   );

  //   // Build a more detailed message based on payment type
  //   String message;
  //   if (result.type?.toLowerCase() == 'googlepay') {
  //     // Google Pay tokenization
  //     message =
  //         'Payment Method: Google Pay\n'
  //         'Token: ${result.token}\n'
  //         'Card Network: ${result.cardNetwork ?? result.scheme ?? 'N/A'}';

  //     if (result.last4 != null && result.last4!.isNotEmpty) {
  //       message += '\nLast 4 Digits: ${result.last4}';
  //     }
  //   } else {
  //     // Card tokenization
  //     message =
  //         'Payment Method: Card\n'
  //         'Token: ${result.token}\n'
  //         'Last 4: ${result.last4 ?? 'N/A'}\n'
  //         'Brand: ${result.brand ?? 'N/A'}\n'
  //         'Expiry: ${result.expiryMonth ?? 'N/A'}/${result.expiryYear ?? 'N/A'}';
  //   }

  //   ConsoleLogger.success(message);
  // }

  // void _handlePaymentSuccess(PaymentSuccessResult result) {
  //   ConsoleLogger.success('Payment ID: ${result.paymentId}');
  // }

  // void _handlePaymentError(PaymentErrorResult result) {
  //   if (_enableDebugLogging) {
  //     ConsoleLogger.error(
  //       'Payment error: ${result.errorCode} - ${result.errorMessage}',
  //     );
  //   }

  //   // Provide user-friendly error messages based on error codes
  //   final userMessage = _getUserFriendlyErrorMessage(
  //     result.errorCode,
  //     result.errorMessage,
  //   );

  //   ConsoleLogger.error('Payment Error: $userMessage');
  // }

  /// Convert technical error codes to user-friendly messages
  // String _getUserFriendlyErrorMessage(
  //   String errorCode,
  //   String technicalMessage,
  // ) {
  //   switch (errorCode) {
  //     case 'INVALID_CONFIG':
  //       return 'Payment configuration error. Please contact support.';
  //     case 'GOOGLEPAY_UNAVAILABLE':
  //     case 'GOOGLEPAY_NOT_AVAILABLE':
  //       return 'Google Pay is not available on this device. Please use another payment method.';
  //     case 'INITIALIZATION_FAILED':
  //     case 'INIT_ERROR':
  //       return 'Failed to initialize payment. Please try again.';
  //     case 'TOKENIZATION_FAILED':
  //     case 'TOKENIZATION_ERROR':
  //       return 'Payment processing failed. Please try again or use another payment method.';
  //     case 'TIMEOUT':
  //       return 'Payment request timed out. Please check your connection and try again.';
  //     case 'INVALID_STATE':
  //       return 'Payment system not ready. Please wait a moment and try again.';
  //     case 'PAYMENT_ERROR':
  //       return 'Payment failed: $technicalMessage';
  //     default:
  //       return 'An error occurred: $technicalMessage';
  //   }
  // }

  // void _handleSessionData(String result) {
  //   ConsoleLogger.success('Session Data: $result');
  // }

  // Future<void> _getSessionData(CurrentPaymentType paymentType) async {
  //   await _paymentBridge.submit(paymentType);
  // }

  // Future<void> _tokenizeCard() async {
  //   // Validate card first
  //   final isValid = await _paymentBridge.validateCard();

  //   if (!isValid) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Please check your card details'),
  //           backgroundColor: Colors.orange,
  //         ),
  //       );
  //     }
  //     return;
  //   }

  //   // Trigger tokenization
  //   await _paymentBridge.tokenizeCard();
  // }

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
          spacing: 16,
          children: [
            // Title
            const Center(
              child: Text(
                'Choose Payment Method',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),

            // Card payment view
            CheckoutCardView(paymentConfig: _paymentConfig),

            // Google Pay view
            // CheckoutGooglePayView(paymentConfig: _paymentConfig),
          ],
        ),
      ),
    );
  }
}

class CheckoutCardView extends StatefulWidget {
  const CheckoutCardView({super.key, required this.paymentConfig});

  final PaymentConfig paymentConfig;

  @override
  State<CheckoutCardView> createState() => _CheckoutCardViewState();
}

class _CheckoutCardViewState extends State<CheckoutCardView> {
  bool _canPay = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 16,
      children: [
        CheckoutFlowCardView(
          paymentConfig: widget.paymentConfig,
          loader: const Center(child: CircularProgressIndicator()),
          onReady: () {
            ConsoleLogger.success('[Flow-Card] is ready');
          },
          onValidInput: (bool valid) {
            // Note: This may not fire in real-time due to SDK limitations
            ConsoleLogger.success('[Flow-Card] Valid Card input: $valid');
            setState(() => _canPay = valid);
          },
          onCardTokenized: (CardTokenResult result) {
            ConsoleLogger.success(
              '[Flow-Card] Card tokenized: ${result.token}',
            );
          },
          onSessionData: (String sessionData) {
            ConsoleLogger.success('[Flow-Card] Session data ready');
          },
          onError: (PaymentErrorResult error) {
            ConsoleLogger.error(
              '[Flow-Card] Payment error: ${error.errorCode} - ${error.errorMessage}',
            );
            // Show error to user
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(error.errorMessage),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),

        // Pay button - enabled after card view is ready
        ElevatedButton(
          onPressed:
              _canPay
                  ? () {
                    // Payment will be triggered
                    // If card is invalid, onError will be called
                    final bridge = PaymentBridge();
                    bridge.submit(CurrentPaymentType.card);
                  }
                  : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey,
          ),
          child: Text(_canPay ? 'Pay Now' : 'Loading...'),
        ),
      ],
    );
  }
}

class CheckoutGooglePayView extends StatelessWidget {
  const CheckoutGooglePayView({super.key, required this.paymentConfig});

  final PaymentConfig paymentConfig;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 16,
      children: [
        CheckoutFlowGooglePayView(
          paymentConfig: paymentConfig,
          onCardTokenized: (CardTokenResult result) {
            ConsoleLogger.success(
              '[Flow-Card] Card tokenized: ${result.token}',
            );
          },
          onSessionData: (String sessionData) {
            ConsoleLogger.success('[Flow-Card] Session data ready');
          },
          onError: (PaymentErrorResult error) {
            // Example: Using the error type enum for better error handling
            ConsoleLogger.error(
              '[Flow-GPay] ${error.errorType.name}: ${error.errorMessage}',
            );

            // Type-safe error handling
            String errorTitle = 'Payment Error';
            String errorMessage = error.userFriendlyMessage;
            Color backgroundColor = Colors.red;

            // Categorize errors using the enum
            if (error.isGooglePayError) {
              errorTitle = 'Google Pay Error';
              backgroundColor = Colors.orange;
            } else if (error.isInitializationError) {
              errorTitle = 'Initialization Error';
              errorMessage = 'Failed to initialize payment. Please try again.';
            } else if (error.isRetryable) {
              errorMessage += '\nPlease try again.';
            }

            // Show error to user with enhanced information
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        errorTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(errorMessage),
                    ],
                  ),
                  backgroundColor: backgroundColor,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
