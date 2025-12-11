import Flutter
import UIKit

public class CheckoutFlutterBridgePlugin: NSObject, FlutterPlugin {
    private static let channelName = "checkout_bridge"
    private var channel: FlutterMethodChannel?
    
    // Weak references to platform views
    private weak var cardPlatformView: CardPlatformView?
    private weak var applePayPlatformView: ApplePayPlatformView?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = CheckoutFlutterBridgePlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // Register platform view factories
        registerPlatformViews(with: registrar)
    }
    
    private static func registerPlatformViews(with registrar: FlutterPluginRegistrar) {
        // Register Card View Factory
        let cardViewFactory = CardViewFactory(messenger: registrar.messenger())
        registrar.register(
            cardViewFactory,
            withId: "flow_card_view"
        )
        
        // Register Apple Pay View Factory
        let applePayViewFactory = ApplePayViewFactory(messenger: registrar.messenger())
        registrar.register(
            applePayViewFactory,
            withId: "flow_applepay_view"
        )
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        // ==================== CARD METHODS ====================
        case "initCardView":
            // Card view initialization happens in PlatformView
            result(true)
            
        case "initStoredCardView":
            // Stored card view initialization happens in PlatformView
            result(true)
            
        case "validateCard":
            guard let cardView = cardPlatformView else {
                result(FlutterError(
                    code: "CARD_NOT_READY",
                    message: "Card view not initialized",
                    details: nil
                ))
                return
            }
            
            Task {
                let isValid = await cardView.validateCard()
                await MainActor.run {
                    result(isValid)
                }
            }
            
        case "tokenizeCard":
            guard let cardView = cardPlatformView else {
                result(FlutterError(
                    code: "CARD_NOT_READY",
                    message: "Card view not initialized",
                    details: nil
                ))
                return
            }
            cardView.tokenizeCard(result: result)
            
        case "getSessionData":
            guard let cardView = cardPlatformView else {
                result(FlutterError(
                    code: "CARD_NOT_READY",
                    message: "Card view not initialized",
                    details: nil
                ))
                return
            }
            cardView.getSessionData(result: result)
            
        // ==================== APPLE PAY METHODS ====================
        case "initApplePay":
            // Apple Pay initialization happens in PlatformView
            result(true)
            
        case "checkApplePayAvailability":
            guard let applePayView = applePayPlatformView else {
                result(false)
                return
            }
            
            Task {
                let isAvailable = await applePayView.checkAvailability()
                await MainActor.run {
                    result(isAvailable)
                }
            }
            
        case "getApplePaySessionData":
            // Session data is automatically sent via handleSubmit callback
            result(true)
            
        case "tokenizeApplePay":
            guard let applePayView = applePayPlatformView else {
                result(FlutterError(
                    code: "APPLEPAY_NOT_READY",
                    message: "Apple Pay view not initialized",
                    details: nil
                ))
                return
            }
            applePayView.tokenizeApplePay(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // Method to set card platform view reference
    func setCardPlatformView(_ view: CardPlatformView) {
        cardPlatformView = view
    }
    
    // Method to set Apple Pay platform view reference
    func setApplePayPlatformView(_ view: ApplePayPlatformView) {
        applePayPlatformView = view
    }
}
