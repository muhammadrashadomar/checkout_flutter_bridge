class SavedCardConfig {
  // Checkout.com payment source ID (required for CVV-only)
  final String paymentSourceId;
  final String last4;
  final String scheme; // visa, mastercard, amex, etc.
  final int expiryMonth;
  final int expiryYear;
  final String? cardholderName;
  final String? bin;

  SavedCardConfig({
    required this.paymentSourceId,
    required this.last4,
    required this.scheme,
    required this.expiryMonth,
    required this.expiryYear,
    this.cardholderName,
    this.bin,
  });

  Map<String, dynamic> toMap() => {
    'paymentSourceId': paymentSourceId,
    'last4': last4,
    'scheme': scheme,
    'expiryMonth': expiryMonth,
    'expiryYear': expiryYear,
    if (cardholderName != null) 'cardholderName': cardholderName,
    if (bin != null) 'bin': bin,
  };

  @override
  String toString() {
    return 'SavedCardConfig(sourceId: $paymentSourceId, scheme: $scheme, last4: $last4, expiry: $expiryMonth/$expiryYear)';
  }
}
