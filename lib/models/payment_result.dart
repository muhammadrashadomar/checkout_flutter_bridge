/// Payment result models from platform channels
class CardTokenResult {
  final String token;
  final String? last4;
  final String? bin;
  final String? scheme;
  final String? schemeLocal;
  final int? expiryMonth;
  final int? expiryYear;
  final String? expiresOn;
  final String? type;
  final String? cardType;
  final String? cardCategory;
  final String? issuer;
  final String? issuerCountry;
  final String? productId;
  final String? productType;
  final Map<String, dynamic>? billingAddress;
  final Map<String, dynamic>? phone;
  final String? name;
  final Map<String, dynamic>? rawData;

  CardTokenResult({
    required this.token,
    this.last4,
    this.bin,
    this.scheme,
    this.schemeLocal,
    this.expiryMonth,
    this.expiryYear,
    this.expiresOn,
    this.type,
    this.cardType,
    this.cardCategory,
    this.issuer,
    this.issuerCountry,
    this.productId,
    this.productType,
    this.billingAddress,
    this.phone,
    this.name,
    this.rawData,
  });

  factory CardTokenResult.fromMap(Map<String, dynamic> map) {
    // Handle nested tokenDetails structure
    final tokenDetails = map['tokenDetails'] as Map<String, dynamic>?;

    return CardTokenResult(
      token: tokenDetails?['token'] as String? ?? '',
      last4: tokenDetails?['last4'] as String?,
      bin: tokenDetails?['bin'] as String?,
      scheme: tokenDetails?['scheme'] as String?,
      schemeLocal: tokenDetails?['schemeLocal'] as String?,
      expiryMonth: tokenDetails?['expiryMonth'] as int?,
      expiryYear: tokenDetails?['expiryYear'] as int?,
      expiresOn: tokenDetails?['expiresOn'] as String?,
      type: tokenDetails?['type'] as String?,
      cardType: tokenDetails?['cardType'] as String?,
      cardCategory: tokenDetails?['cardCategory'] as String?,
      issuer: tokenDetails?['issuer'] as String?,
      issuerCountry: tokenDetails?['issuerCountry'] as String?,
      productId: tokenDetails?['productId'] as String?,
      productType: tokenDetails?['productType'] as String?,
      billingAddress: tokenDetails?['billingAddress'] as Map<String, dynamic>?,
      phone: tokenDetails?['phone'] as Map<String, dynamic>?,
      name: tokenDetails?['name'] as String?,
      rawData: tokenDetails,
    );
  }

  /// Convenience getter for brand (alias for scheme)
  String? get brand => scheme;

  @override
  String toString() {
    return 'CardTokenResult(token: $token, last4: $last4, brand: $scheme, expiry: $expiryMonth/$expiryYear, cardType: $cardType, issuer: $issuer)';
  }
}

class PaymentSuccessResult {
  final String paymentId;
  final Map<String, dynamic>? metadata;

  PaymentSuccessResult({required this.paymentId, this.metadata});

  factory PaymentSuccessResult.fromMap(dynamic data) {
    if (data is String) {
      return PaymentSuccessResult(paymentId: data);
    } else if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      return PaymentSuccessResult(
        paymentId: map['paymentId'] as String? ?? '',
        metadata: map,
      );
    }
    return PaymentSuccessResult(paymentId: '');
  }

  @override
  String toString() {
    return 'PaymentSuccessResult(paymentId: $paymentId)';
  }
}

class PaymentErrorResult {
  final String errorCode;
  final String errorMessage;
  final Map<String, dynamic>? details;

  PaymentErrorResult({
    required this.errorCode,
    required this.errorMessage,
    this.details,
  });

  factory PaymentErrorResult.fromMap(dynamic data) {
    if (data is String) {
      return PaymentErrorResult(errorCode: 'UNKNOWN', errorMessage: data);
    } else if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      return PaymentErrorResult(
        errorCode: map['code'] as String? ?? 'UNKNOWN',
        errorMessage: map['message'] as String? ?? 'Unknown error',
        details: map,
      );
    }
    return PaymentErrorResult(
      errorCode: 'UNKNOWN',
      errorMessage: 'Unknown error',
    );
  }

  @override
  String toString() {
    return 'PaymentErrorResult(code: $errorCode, message: $errorMessage)';
  }
}

class GooglePayResult {
  final bool success;
  final String? paymentData;
  final String? error;

  GooglePayResult({required this.success, this.paymentData, this.error});

  factory GooglePayResult.fromMap(Map<String, dynamic> map) {
    return GooglePayResult(
      success: map['success'] as bool? ?? false,
      paymentData: map['paymentData'] as String?,
      error: map['error'] as String?,
    );
  }

  @override
  String toString() {
    return 'GooglePayResult(success: $success, error: $error)';
  }
}

class SessionDataResult {
  final Map<String, dynamic>? data;

  SessionDataResult({this.data});

  factory SessionDataResult.fromMap(dynamic data) {
    if (data is Map) {
      return SessionDataResult(data: Map<String, dynamic>.from(data));
    }
    return SessionDataResult();
  }

  @override
  String toString() {
    return 'SessionDataResult(data: $data)';
  }
}
