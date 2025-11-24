/// Google Pay Configuration Helper
///
/// Generates the payment configuration JSON for the pay package
String kGooglePaymentConfig({
  required String publicKey,
  required num totalPrice,
  required String currencyCode,
  required String envMode,
}) {
  return '''{
  "provider": "google_pay",
  "data": {
    "environment": "$envMode",
    "apiVersion": 2,
    "apiVersionMinor": 0,
    "allowedPaymentMethods": [
      {
        "type": "CARD",
        "tokenizationSpecification": {
          "type": "PAYMENT_GATEWAY",
          "parameters": {
            "gateway": "checkoutltd",
            "gatewayMerchantId": "$publicKey"
          }
        },
        "parameters": {
          "allowedCardNetworks": ["VISA", "MASTERCARD", "AMEX", "MADA"],
          "allowedAuthMethods": ["PAN_ONLY", "CRYPTOGRAM_3DS"],
          "billingAddressRequired": false,
          "billingAddressParameters": {
            "format": "FULL",
            "phoneNumberRequired": false
          }
        }
      }
    ],
    "merchantInfo": {
      "merchantName": "Mac Queen"
    },
    "transactionInfo": {
      "countryCode": "SA",
      "currencyCode": "$currencyCode",
      "totalPriceStatus": "FINAL",
      "totalPrice": "$totalPrice"
    }
  }
}''';
}
