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
  final String? brand; // Card brand
  final String? cardNetwork; // Card network for Google Pay
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
    this.cardNetwork,
    this.brand, // Add to constructor
    this.rawData,
  });

  factory CardTokenResult.fromMap(Map<String, dynamic> map) {
    // Handle nested tokenDetails structure (from card component)
    // Need to convert Map<Object?, Object?> to Map<String, dynamic>
    final tokenDetailsRaw = map['tokenDetails'];
    final tokenDetails =
        tokenDetailsRaw != null
            ? Map<String, dynamic>.from(tokenDetailsRaw as Map)
            : null;

    // If tokenDetails exists, use it; otherwise use direct map (Google Pay)
    final data = tokenDetails ?? map;

    // Helper to safely convert nested maps
    Map<String, dynamic>? convertMap(dynamic value) {
      if (value == null) return null;
      if (value is Map) return Map<String, dynamic>.from(value);
      return null;
    }

    return CardTokenResult(
      token: data['token'] as String? ?? map['token'] as String? ?? '',
      last4: data['last4'] as String?,
      bin: data['bin'] as String?,
      scheme: data['scheme'] as String?,
      schemeLocal: data['schemeLocal'] as String?,
      expiryMonth: data['expiryMonth'] as int?,
      expiryYear: data['expiryYear'] as int?,
      expiresOn: data['expiresOn'] as String?,
      type: data['type'] as String?,
      cardType: data['cardType'] as String?,
      cardCategory: data['cardCategory'] as String?,
      issuer: data['issuer'] as String?,
      issuerCountry: data['issuerCountry'] as String?,
      productId: data['productId'] as String?,
      productType: data['productType'] as String?,
      billingAddress: convertMap(data['billingAddress']),
      phone: convertMap(data['phone']),
      name: data['name'] as String?,
      brand: data['brand'] as String?, // Add brand field
      cardNetwork: data['cardNetwork'] as String?, // Google Pay card network
      rawData: tokenDetails ?? data,
    );
  }

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
