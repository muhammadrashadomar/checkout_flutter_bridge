// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// NOTE: This Package.swift is for reference only.
// The actual SPM dependency should be added through Xcode:
// File > Add Package Dependencies > https://github.com/checkout/checkout-ios-components

import PackageDescription

let package = Package(
    name: "CheckoutFlutterBridge",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "CheckoutFlutterBridge",
            targets: ["CheckoutFlutterBridge"])
    ],
    dependencies: [
        // Checkout.com iOS Components SDK
        // Add via Xcode: https://github.com/checkout/checkout-ios-components
        .package(url: "https://github.com/checkout/checkout-ios-components", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "CheckoutFlutterBridge",
            dependencies: [
                .product(name: "CheckoutIOSComponents", package: "checkout-ios-components")
            ],
            path: "Classes"
        )
    ]
)
