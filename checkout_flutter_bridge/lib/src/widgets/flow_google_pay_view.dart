import 'package:checkout_flutter_bridge/checkout_flutter_bridge.dart';
import 'package:flutter/material.dart';

/// CheckoutFlowGooglePayView - Complete Google Pay payment widget with all callbacks
///
/// This widget provides a complete Google Pay payment solution with:
/// - Loading state management (shows loader until Google Pay button is ready)
/// - Availability checking
/// - Payment success/error handling
/// - Token and session data callbacks
/// - Built-in Google Pay button rendering
///
/// Example usage:
/// ```dart
/// CheckoutFlowGooglePayView(
///   paymentConfig: config,
///   onReady: () => print('Google Pay button ready'),
///   onCardTokenized: (result) => print('Token: ${result.token}'),
///   onSessionData: (sessionData) => _submitToBackend(sessionData),
///   onPaymentSuccess: (result) => _showSuccess(result.paymentId),
///   onError: (error) => _showError(error.errorMessage),
///   onUnavailable: () => _showAlternativePayments(),
///   loader: CircularProgressIndicator(), // Optional custom loader
/// )
/// ```
class CheckoutFlowGooglePayView extends StatefulWidget {
  /// Payment configuration for the Google Pay component
  final PaymentConfig paymentConfig;

  /// Callback when Google Pay button is ready for interaction
  final Function()? onReady;

  /// Callback when Google Pay is successfully tokenized
  final Function(CardTokenResult)? onCardTokenized;

  /// Callback when payment succeeds
  final Function(PaymentSuccessResult)? onPaymentSuccess;

  /// Callback when session data is ready for backend submission
  final Function(String)? onSessionData;

  /// Callback when any payment error occurs
  final Function(PaymentErrorResult)? onError;

  /// Callback when Google Pay is not available on this device
  final Function()? onUnavailable;

  /// Widget to show when Google Pay is not available
  /// If not provided and Google Pay is unavailable, widget returns SizedBox.shrink()
  final Widget? unavailableWidget;

  /// Custom loader widget to show while Google Pay button is loading
  /// If not provided, no loader is shown
  final Widget? loader;

  final double height;

  const CheckoutFlowGooglePayView({
    super.key,
    required this.paymentConfig,
    this.onReady,
    this.onCardTokenized,
    this.onPaymentSuccess,
    this.onSessionData,
    this.onError,
    this.onUnavailable,
    this.unavailableWidget,
    this.loader,
    this.height = 50,
  });

  @override
  State<CheckoutFlowGooglePayView> createState() =>
      _CheckoutFlowGooglePayViewState();
}

class _CheckoutFlowGooglePayViewState extends State<CheckoutFlowGooglePayView> {
  bool _isReady = false;
  final PaymentBridge _paymentBridge = PaymentBridge();

  @override
  void initState() {
    super.initState();
    _setupCallbacks();
  }

  void _setupCallbacks() {
    // Google Pay ready event
    _paymentBridge.onGooglePayReady = () {
      if (mounted) {
        setState(() {
          _isReady = true;
        });
        widget.onReady?.call();
      }
    };

    _paymentBridge.onCardTokenized = (result) {
      if (mounted) widget.onCardTokenized?.call(result);
    };

    _paymentBridge.onPaymentSuccess = (result) {
      if (mounted) widget.onPaymentSuccess?.call(result);
    };

    _paymentBridge.onSessionData = (sessionData) {
      if (mounted) widget.onSessionData?.call(sessionData);
    };

    // Error callback handles unavailability - SDK sends GOOGLEPAY_UNAVAILABLE error
    _paymentBridge.onPaymentError = (error) {
      if (mounted) {
        // If Google Pay is unavailable, call the onUnavailable callback
        if (error.errorCode == 'GOOGLEPAY_UNAVAILABLE' ||
            error.errorCode == 'GOOGLEPAY_NOT_AVAILABLE') {
          widget.onUnavailable?.call();
        }
        widget.onError?.call(error);
      }
    };
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Google Pay button with loader overlay
    return Stack(
      children: [
        SizedBox(
          height: widget.height,
          child: GooglePayNativeView(paymentConfig: widget.paymentConfig),
        ),
        // Loader - shown until Google Pay button is ready
        if (!_isReady && widget.loader != null) widget.loader!,
      ],
    );
  }
}
