import 'package:checkout_flutter_bridge/checkout_flutter_bridge.dart';
import 'package:flutter/material.dart';

/// CheckoutFlowCardView - Complete card payment widget with all callbacks
///
/// This widget provides a complete card payment solution with:
/// - Loading state management (shows loader until card view is ready)
/// - Payment success/error handling
/// - Token and session data callbacks
///
/// **Note on Validation:**
/// The Checkout.com SDK validates card input when you attempt to tokenize/submit.
/// The `onValidInput` callback will fire based on SDK feedback, but real-time
/// validation is not available. Enable your pay button after `onReady` fires,
/// then handle validation errors via the `onError` callback.
///
/// Example usage:
/// ```dart
/// bool _isReady = false;
///
/// CheckoutFlowCardView(
///   paymentConfig: config,
///   onReady: () => setState(() => _isReady = true),
///   onCardTokenized: (result) => print('Token: ${result.token}'),
///   onSessionData: (sessionData) => _submitToBackend(sessionData),
///   onPaymentSuccess: (result) => _showSuccess(result.paymentId),
///   onError: (error) => _showError(error.errorMessage),
/// )
///
/// Enable pay button after ready
/// ElevatedButton(
///   onPressed: _isReady ? _handlePayment : null,
///   child: Text('Pay'),
/// )
/// ```
class CheckoutFlowCardView extends StatefulWidget {
  /// Payment configuration for the card component
  final PaymentConfig paymentConfig;

  /// Callback when the card view is fully rendered and ready for input
  final Function()? onReady;

  /// Callback when validation state changes (true = valid, false = invalid)
  final Function(bool)? onValidInput;

  /// Callback when card is successfully tokenized
  final Function(CardTokenResult)? onCardTokenized;

  /// Callback when card bin is changed
  final Function(CardMetadata)? onCardBinChanged;

  /// Callback when payment succeeds
  final Function(PaymentSuccessResult)? onPaymentSuccess;

  /// Callback when session data is ready for backend submission
  final Function(String)? onSessionData;

  /// Callback when any payment error occurs
  final Function(PaymentErrorResult)? onError;

  /// Custom loader widget to show while card is initializing
  /// Defaults to CircularProgressIndicator if not provided
  final Widget? loader;

  final double height;

  const CheckoutFlowCardView({
    super.key,
    required this.paymentConfig,
    this.onReady,
    this.onValidInput,
    this.onCardTokenized,
    this.onCardBinChanged,
    this.onPaymentSuccess,
    this.onSessionData,
    this.onError,
    this.loader,
    this.height = 300,
  });

  @override
  State<CheckoutFlowCardView> createState() => _CheckoutFlowCardViewState();
}

class _CheckoutFlowCardViewState extends State<CheckoutFlowCardView> {
  bool _isReady = false;
  final PaymentBridge _paymentBridge = PaymentBridge();

  @override
  void initState() {
    super.initState();
    _setupCallbacks();
  }

  void _setupCallbacks() {
    // Card ready event
    _paymentBridge.onCardReady = () {
      if (mounted) {
        setState(() {
          _isReady = true;
        });
        widget.onReady?.call();
      }
    };

    // Validation changes
    if (widget.onValidInput != null) {
      _paymentBridge.onValidationChanged = (isValid) {
        if (mounted) {
          widget.onValidInput?.call(isValid);
        }
      };
    }

    // Card tokenized
    if (widget.onCardTokenized != null) {
      _paymentBridge.onCardTokenized = (result) {
        if (mounted) {
          widget.onCardTokenized?.call(result);
        }
      };
    }

    // Card bin changed
    if (widget.onCardBinChanged != null) {
      _paymentBridge.onCardBinChanged = (bin) {
        if (mounted) {
          widget.onCardBinChanged?.call(bin);
        }
      };
    }

    // Payment success
    if (widget.onPaymentSuccess != null) {
      _paymentBridge.onPaymentSuccess = (result) {
        if (mounted) {
          widget.onPaymentSuccess?.call(result);
        }
      };
    }

    // Session data ready
    if (widget.onSessionData != null) {
      _paymentBridge.onSessionData = (sessionData) {
        if (mounted) {
          widget.onSessionData?.call(sessionData);
        }
      };
    }

    // Payment error
    if (widget.onError != null) {
      _paymentBridge.onPaymentError = (error) {
        if (mounted) {
          widget.onError?.call(error);
        }
      };
    }
  }

  @override
  void dispose() {
    // Note: We don't clear callbacks here as PaymentBridge is a singleton
    // and may be used elsewhere. Callbacks will be cleared when needed.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Card is ready, show the native view
    return Stack(
      children: [
        SizedBox(
          height: widget.height,
          child: CardNativeView(paymentConfig: widget.paymentConfig),
        ),
        // Loader
        if (!_isReady && widget.loader != null) widget.loader!,
      ],
    );
  }
}
