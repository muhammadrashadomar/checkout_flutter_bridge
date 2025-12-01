import 'package:checkout_flutter_bridge/checkout_flutter_bridge.dart';
import 'package:flutter/material.dart';

/// CheckoutFlowGooglePayView - Complete Google Pay payment widget with all callbacks
///
/// This widget provides a complete Google Pay payment solution with:
/// - Availability checking
/// - Payment success/error handling
/// - Token and session data callbacks
/// - Built-in Google Pay button rendering
///
/// Example usage:
/// ```dart
/// CheckoutFlowGooglePayView(
///   paymentConfig: config,
///   onCardTokenized: (result) => print('Token: ${result.token}'),
///   onSessionData: (sessionData) => _submitToBackend(sessionData),
///   onPaymentSuccess: (result) => _showSuccess(result.paymentId),
///   onError: (error) => _showError(error.errorMessage),
///   onUnavailable: () => _showAlternativePayments(),
/// )
/// ```
class CheckoutFlowGooglePayView extends StatefulWidget {
  /// Payment configuration for the Google Pay component
  final PaymentConfig paymentConfig;

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

  final double height;

  const CheckoutFlowGooglePayView({
    super.key,
    required this.paymentConfig,
    this.onCardTokenized,
    this.onPaymentSuccess,
    this.onSessionData,
    this.onError,
    this.onUnavailable,
    this.unavailableWidget,
    this.height = 50,
  });

  @override
  State<CheckoutFlowGooglePayView> createState() =>
      _CheckoutFlowGooglePayViewState();
}

class _CheckoutFlowGooglePayViewState extends State<CheckoutFlowGooglePayView> {
  bool _isAvailable = true; // Assume available until checked
  final PaymentBridge _paymentBridge = PaymentBridge();

  @override
  void initState() {
    super.initState();
    _setupCallbacks();
    _checkAvailability();
  }

  void _setupCallbacks() {
    // Google Pay tokenized
    _paymentBridge.onCardTokenized = (result) {
      if (mounted) {
        widget.onCardTokenized?.call(result);
      }
    };

    // Payment success
    _paymentBridge.onPaymentSuccess = (result) {
      if (mounted) {
        widget.onPaymentSuccess?.call(result);
      }
    };

    // Session data ready
    _paymentBridge.onSessionData = (sessionData) {
      if (mounted) {
        widget.onSessionData?.call(sessionData);
      }
    };

    // Payment error
    _paymentBridge.onPaymentError = (error) {
      if (mounted) {
        widget.onError?.call(error);
      }
    };
  }

  Future<void> _checkAvailability() async {
    final isAvailable = await _paymentBridge.checkGooglePayAvailability();

    if (mounted) {
      setState(() {
        _isAvailable = isAvailable;
      });

      if (!isAvailable) {
        widget.onUnavailable?.call();
      }
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
    if (!_isAvailable) {
      // Google Pay not available
      return widget.unavailableWidget ?? const SizedBox.shrink();
    }

    // Google Pay is available, show the native view
    return SizedBox(
      height: widget.height,
      child: GooglePayNativeView(paymentConfig: widget.paymentConfig),
    );
  }
}
