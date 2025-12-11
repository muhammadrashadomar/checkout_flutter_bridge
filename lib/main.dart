import 'package:checkout_flutter_bridge/checkout_flutter_bridge.dart';
import 'package:flutter/material.dart';

// Google Pay Configuration
const String paymentSessionId = 'ps_36WBBG7vz3KsGZFOdKsQQGNo0LJ';
const String paymentSessionSecret = 'pss_46ade997-622b-483c-a650-bc8deb4ad01a';
const String publicKey = 'pk_sbox_fjizign6afqbt3btt3ialiku74s';

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

  bool _canPay = false;

  @override
  void initState() {
    super.initState();
    _setupPaymentBridge();
  }

  void _setupPaymentBridge() {
    _paymentBridge.initialize();
    // _setupCallbacks();
  }

  // void _setupCallbacks() {
  //   _paymentBridge.onCardReady = () {
  //     ConsoleLogger.success("Ready");
  //   };
  //   _paymentBridge.onValidationChanged = (value) {
  //     ConsoleLogger.info("ValidationChanged: $value");
  //   };
  //   _paymentBridge.onSessionData = (value) {
  //     ConsoleLogger.success("SeesionData: $value");
  //   };

  //   _paymentBridge.onPaymentError = (error) {
  //     ConsoleLogger.error("PaymentError: $error");
  //   };
  // }

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

            ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder:
                      (context) => AddCardViewBody(
                        canPay: (value) => setState(() => _canPay = value),
                      ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey,
              ),
              child: Text('Add New Card'),
            ),

            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // if (!_canPay) return;
                // Payment will be triggered
                // If card is invalid, onError will be called
                final bridge = PaymentBridge();
                final result = await bridge.submit(CurrentPaymentType.card);

                ConsoleLogger.success("SessionData: ${result.sessionData}");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey,
              ),
              child: Text('Pay Now'),
            ),

            // Google Pay view
            // CheckoutGooglePayView(paymentConfig: _paymentConfig),
          ],
        ),
      ),
    );
  }
}

class CheckoutCardView extends StatefulWidget {
  const CheckoutCardView({
    super.key,
    required this.paymentConfig,
    this.onReady,
    this.onTokenized,
    this.onFetchedSessionData,
    this.onValidInput,
    this.onError,
  });

  final PaymentConfig paymentConfig;
  final void Function()? onReady;
  final void Function(CardTokenResult)? onTokenized;
  final void Function(String)? onFetchedSessionData;
  final void Function(bool)? onValidInput;
  final void Function(PaymentErrorResult)? onError;

  @override
  State<CheckoutCardView> createState() => _CheckoutCardViewState();
}

class _CheckoutCardViewState extends State<CheckoutCardView> {
  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 16,
      children: [
        CheckoutFlowCardView(
          paymentConfig: widget.paymentConfig,
          loader: const Center(child: CircularProgressIndicator()),
          onReady: () {
            widget.onReady?.call();
          },
          onValidInput: (bool valid) {
            // Note: This may not fire in real-time due to SDK limitations
            widget.onValidInput?.call(valid);
          },
          // onCardTokenized: (CardTokenResult result) {
          //   ConsoleLogger.success(
          //     '[Flow-Card] Card tokenized: ${result.token}',
          //   );
          //   widget.onTokenized?.call(result);
          // },
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

class AddCardViewBody extends StatefulWidget {
  const AddCardViewBody({super.key, required this.canPay});

  final Function(bool) canPay;

  @override
  State<AddCardViewBody> createState() => _AddCardViewBodyState();
}

class _AddCardViewBodyState extends State<AddCardViewBody> {
  // bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CheckoutCardView(
          paymentConfig: _paymentConfig,
          // onTokenized: (value) {
          //   // setState(() => _isLoading = false);
          //   widget.canPay(true);
          //   Navigator.pop(context);
          // },
        ),
        ElevatedButton(
          onPressed: () async {
            // setState(() => _isLoading = true);
            final result = await PaymentBridge().tokenizeCard();

            ConsoleLogger.success("Tokenized: ${result.token}");
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey,
          ),
          child: Text('Add Card'),
        ),
      ],
    );
  }
}
