enum NativePlatformViewType {
  flowCardView('flow_card_view'),
  flowGooglePayView('flow_googlepay_view'),
  flowApplePayView('flow_view_applepay');

  final String name;

  const NativePlatformViewType(this.name);
}
