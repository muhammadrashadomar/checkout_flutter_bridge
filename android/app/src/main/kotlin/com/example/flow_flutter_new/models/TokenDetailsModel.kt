// package com.example.flow_flutter_new.models

// import com.checkout.components.interfaces.model.TokenDetails

// /**
//  * Wrapper for TokenDetails with serialization support for Flutter platform channels Converts
//  * TokenDetails object to Map for platform channel communication
//  */
// data class TokenDetailsModel(
//         val expiryMonth: Int?,
//         val expiryYear: Int?,
//         val last4: String?,
//         val bin: String?,
//         val type: String?,
//         val token: String,
//         val expiresOn: String?,
//         val scheme: String?,
//         val schemeLocal: String?,
//         val cardType: String?,
//         val cardCategory: String?,
//         val issuer: String?,
//         val issuerCountry: String?,
//         val productId: String?,
//         val productType: String?,
//         val billingAddress: BillingAddressModel?,
//         val phone: PhoneModel?,
//         val name: String?
// ) {
//     /** Convert to Map for platform channel serialization */
//     fun toMap(): Map<String, Any?> {
//         return mapOf(
//                 "expiryMonth" to expiryMonth,
//                 "expiryYear" to expiryYear,
//                 "last4" to last4,
//                 "bin" to bin,
//                 "type" to type,
//                 "token" to token,
//                 "expiresOn" to expiresOn,
//                 "scheme" to scheme,
//                 "schemeLocal" to schemeLocal,
//                 "cardType" to cardType,
//                 "cardCategory" to cardCategory,
//                 "issuer" to issuer,
//                 "issuerCountry" to issuerCountry,
//                 "productId" to productId,
//                 "productType" to productType,
//                 "billingAddress" to billingAddress?.toMap(),
//                 "phone" to phone?.toMap(),
//                 "name" to name
//         )
//     }

//     companion object {
//         /** Create TokenDetailsModel from Checkout.com TokenDetails */
//         fun fromTokenDetails(tokenDetails: TokenDetails): TokenDetailsModel {
//             return TokenDetailsModel(
//                     expiryMonth = tokenDetails.expiryMonth,
//                     expiryYear = tokenDetails.expiryYear,
//                     last4 = tokenDetails.last4,
//                     bin = tokenDetails.bin,
//                     type = tokenDetails.type,
//                     token = tokenDetails.token,
//                     expiresOn = tokenDetails.expiresOn.toString(),
//                     scheme = tokenDetails.scheme,
//                     schemeLocal = tokenDetails.schemeLocal,
//                     cardType = tokenDetails.cardType,
//                     cardCategory = tokenDetails.cardCategory,
//                     issuer = tokenDetails.issuer,
//                     issuerCountry = tokenDetails.issuerCountry,
//                     productId = tokenDetails.productId,
//                     productType = tokenDetails.productType,
//                     billingAddress =
//                             tokenDetails.billingAddress?.let {
//                                 BillingAddressModel.fromBillingAddress(it)
//                             },
//                     phone = tokenDetails.phone?.let { PhoneModel.fromPhone(it) },
//                     name = tokenDetails.name
//             )
//         }
//     }
// }

// /** Billing address model */
// data class BillingAddressModel(
//         val addressLine1: String?,
//         val addressLine2: String?,
//         val city: String?,
//         val state: String?,
//         val zip: String?,
//         val country: String?
// ) {
//     fun toMap(): Map<String, Any?> {
//         return mapOf(
//                 "addressLine1" to addressLine1,
//                 "addressLine2" to addressLine2,
//                 "city" to city,
//                 "state" to state,
//                 "zip" to zip,
//                 "country" to country
//         )
//     }

//     companion object {
//         fun fromBillingAddress(
//                 address: com.checkout.components.interfaces.model.BillingAddress
//         ): BillingAddressModel {
//             return BillingAddressModel(
//                     addressLine1 = address.addressLine1,
//                     addressLine2 = address.addressLine2,
//                     city = address.city,
//                     state = address.state,
//                     zip = address.zip,
//                     country = address.country
//             )
//         }
//     }
// }

// /** Phone model */
// data class PhoneModel(val number: String?, val countryCode: String?) {
//     fun toMap(): Map<String, Any?> {
//         return mapOf("number" to number, "countryCode" to countryCode)
//     }

//     companion object {
//         fun fromPhone(phone: com.checkout.components.interfaces.model.Phone): PhoneModel {
//             return PhoneModel(number = phone.number, countryCode = phone.countryCode)
//         }
//     }
// }
