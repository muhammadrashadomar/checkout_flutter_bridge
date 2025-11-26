import 'package:checkout_flutter_bridge/checkout_flutter_bridge.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Checkout Flutter Bridge Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PaymentExample(),
    );
  }
}

class PaymentExample extends StatefulWidget {
  const PaymentExample({super.key});

  @override
  State<PaymentExample> createState() => _PaymentExampleState();
}

class _PaymentExampleState extends State<PaymentExample> {
  final PaymentBridge _paymentBridge = PaymentBridge();
  bool _isProcessing = false;
  String _status = 'Not initialized';
  String? _tokenResult;

  @override
  void initState() {
    super.initState();
    _setupPaymentBridge();
  }

  /// Set up payment bridge and callbacks
  void _setupPaymentBridge() {
    // Initialize the bridge
    _paymentBridge.initialize();

    // Set up callback for successful tokenization
    _paymentBridge.onCardTokenized = (result) {
      setState(() {
        _isProcessing = false;
        _status = 'Card tokenized successfully!';
        _tokenResult = result.toString();
      });

      _showResultDialog(
        'Success',
        'Token: ${result.token}\n'
            'Card: ${result.scheme} •••• ${result.last4}\n'
            'Expiry: ${result.expiryMonth}/${result.expiryYear}',
        isSuccess: true,
      );
    };

    // Set up callback for errors
    _paymentBridge.onPaymentError = (error) {
      setState(() {
        _isProcessing = false;
        _status = 'Error: ${error.errorMessage}';
      });

      _showResultDialog(
        'Error',
        'Code: ${error.errorCode}\n'
            'Message: ${error.errorMessage}',
        isSuccess: false,
      );
    };

    // Set up callback for session data (optional)
    _paymentBridge.onSessionData = (data) {
      setState(() {
        _status = 'Session data received';
      });

      ConsoleLogger.info('Session data: $data');
      // Send this to your backend for payment processing
    };

    setState(() {
      _status = 'Payment bridge initialized';
    });
  }

  /// Initialize card view with payment configuration
  Future<void> _initializeCardView() async {
    setState(() {
      _isProcessing = true;
      _status = 'Initializing card view...';
    });

    try {
      // ⚠️ IMPORTANT: In production, get these values from your backend
      // Never hardcode session secrets in your app
      final config = PaymentConfig(
        paymentSessionId: "ps_your_session_id", // From backend
        paymentSessionSecret: "pss_your_secret", // From backend
        publicKey: "pk_sbox_your_public_key", // Your Checkout.com key
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

      final cardConfig = CardConfig(
        showCardholderName: false,
        enableBillingAddress: false,
      );

      final success = await _paymentBridge.initCardView(config, cardConfig);

      setState(() {
        _isProcessing = false;
        _status =
            success
                ? 'Card view initialized'
                : 'Failed to initialize card view';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _status = 'Error initializing: $e';
      });
    }
  }

  /// Validate card input
  Future<void> _validateCard() async {
    setState(() {
      _isProcessing = true;
      _status = 'Validating card...';
    });

    final isValid = await _paymentBridge.validateCard();

    setState(() {
      _isProcessing = false;
      _status = isValid ? 'Card is valid ✓' : 'Card is invalid ✗';
    });
  }

  /// Tokenize card
  Future<void> _tokenizeCard() async {
    setState(() {
      _isProcessing = true;
      _status = 'Tokenizing card...';
    });

    // Validate first
    final isValid = await _paymentBridge.validateCard();

    if (!isValid) {
      setState(() {
        _isProcessing = false;
        _status = 'Please enter valid card details';
      });
      return;
    }

    // Trigger tokenization (result comes via callback)
    await _paymentBridge.tokenizeCard();
  }

  /// Show result dialog
  void _showResultDialog(
    String title,
    String message, {
    required bool isSuccess,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(title),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout Flutter Bridge'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status indicator
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                    if (_isProcessing) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            const Text(
              'Payment Actions:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _initializeCardView,
              icon: const Icon(Icons.credit_card),
              label: const Text('Initialize Card View'),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _validateCard,
              icon: const Icon(Icons.check),
              label: const Text('Validate Card'),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _tokenizeCard,
              icon: const Icon(Icons.lock),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              label: const Text('Tokenize Card'),
            ),

            const SizedBox(height: 24),

            // Card display area (placeholder)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.credit_card, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'Card input component will be displayed here',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '(Use AndroidView widget in actual implementation)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            if (_tokenResult != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Last Token Result:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(_tokenResult!, style: const TextStyle(fontSize: 12)),
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

  @override
  void dispose() {
    _paymentBridge.dispose();
    super.dispose();
  }
}
