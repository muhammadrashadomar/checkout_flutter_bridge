/// Payment configuration models for platform channels
class PaymentConfig {
  final String paymentSessionId;
  final String paymentSessionSecret;
  final String publicKey;
  final PaymentEnvironment environment;
  final AppearanceConfig? appearance;

  PaymentConfig({
    required this.paymentSessionId,
    required this.paymentSessionSecret,
    required this.publicKey,
    this.environment = PaymentEnvironment.sandbox,
    this.appearance,
  });

  Map<String, dynamic> toMap() {
    return {
      'paymentSessionID': paymentSessionId,
      'paymentSessionSecret': paymentSessionSecret,
      'publicKey': publicKey,
      'environment': environment.name,
      if (appearance != null) 'appearance': appearance!.toMap(),
    };
  }
}

enum PaymentEnvironment { sandbox, production }

class AppearanceConfig {
  final ColorTokens? colorTokens;
  final int? borderRadius;
  final FontConfig? fontConfig;

  AppearanceConfig({this.colorTokens, this.borderRadius, this.fontConfig});

  Map<String, dynamic> toMap() {
    return {
      if (colorTokens != null) 'colorTokens': colorTokens!.toMap(),
      if (borderRadius != null) 'borderRadius': borderRadius,
      if (fontConfig != null) 'fontConfig': fontConfig!.toMap(),
    };
  }
}

class ColorTokens {
  final int? colorAction;
  final int? colorPrimary;
  final int? colorBorder;
  final int? colorFormBorder;
  final int? colorBackground;

  ColorTokens({
    this.colorAction,
    this.colorPrimary,
    this.colorBorder,
    this.colorFormBorder,
    this.colorBackground,
  });

  Map<String, dynamic> toMap() {
    return {
      if (colorAction != null) 'colorAction': colorAction,
      if (colorPrimary != null) 'colorPrimary': colorPrimary,
      if (colorBorder != null) 'colorBorder': colorBorder,
      if (colorFormBorder != null) 'colorFormBorder': colorFormBorder,
      if (colorBackground != null) 'colorBackground': colorBackground,
    };
  }
}

class FontConfig {
  final int? fontSize;
  final String? fontWeight;

  FontConfig({this.fontSize, this.fontWeight});

  Map<String, dynamic> toMap() {
    return {
      if (fontSize != null) 'fontSize': fontSize,
      if (fontWeight != null) 'fontWeight': fontWeight,
    };
  }
}

class CardConfig {
  final bool showCardholderName;
  final bool enableBillingAddress;

  CardConfig({
    this.showCardholderName = false,
    this.enableBillingAddress = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'showCardholderName': showCardholderName,
      'enableBillingAddress': enableBillingAddress,
    };
  }
}

class GooglePayConfig {
  final String merchantId;
  final String merchantName;
  final String countryCode;
  final String currencyCode;
  final int totalPrice;
  final String totalPriceLabel;

  GooglePayConfig({
    required this.merchantId,
    required this.merchantName,
    required this.countryCode,
    required this.currencyCode,
    required this.totalPrice,
    this.totalPriceLabel = 'Total',
  });

  Map<String, dynamic> toMap() {
    return {
      'merchantId': merchantId,
      'merchantName': merchantName,
      'countryCode': countryCode,
      'currencyCode': currencyCode,
      'totalPrice': totalPrice,
      'totalPriceLabel': totalPriceLabel,
    };
  }
}
