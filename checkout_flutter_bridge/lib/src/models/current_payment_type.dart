enum CurrentPaymentType {
  card,
  savedCard,
  googlepay,
  applepay,
  unknown;

  bool get isCardSelected => this == CurrentPaymentType.card;
  bool get isSavedCardSelected => this == CurrentPaymentType.savedCard;
  bool get isGooglePaySelected => this == CurrentPaymentType.googlepay;
  bool get isApplePaySelected => this == CurrentPaymentType.applepay;
  bool get isUnknown => this == CurrentPaymentType.unknown;
}
