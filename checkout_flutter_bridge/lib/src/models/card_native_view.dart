import 'package:checkout_flutter_bridge/checkout_flutter_bridge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CardNativeView extends StatelessWidget {
  final PaymentConfig paymentConfig;

  const CardNativeView({super.key, required this.paymentConfig});

  @override
  Widget build(BuildContext context) {
    const viewType = NativePlatformViewType.flowCardView;
    final creationParams = paymentConfig.toMap();

    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: viewType.name,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: viewType.name,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }

    return const SizedBox.shrink();
  }
}
