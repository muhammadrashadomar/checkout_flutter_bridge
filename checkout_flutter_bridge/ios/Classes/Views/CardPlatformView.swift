import Flutter
import UIKit
import SwiftUI
import CheckoutIOSComponents

/// Card Platform View - Handles card input UI and tokenization
/// Completely controlled by Flutter layer via method channels
///
/// Architecture:
/// - Wraps SwiftUI card component in UIView for Flutter Platform View
/// - No native payment button (controlled by Flutter)
/// - Exposes methods via method channel
/// - Sends results back to Flutter via method channel callbacks
class CardPlatformView: NSObject, FlutterPlatformView {
    private let frame: CGRect
    private let viewId: Int64
    private let channel: FlutterMethodChannel
    private let args: [String: Any]?
    
    private var hostingController: UIHostingController<AnyView>?
    private var checkoutComponents: Any? // CheckoutComponents instance
    private var cardComponent: Any? // PaymentMethodComponent instance
    private var isInitialized = false
    private var isCardValid = false
    
    private let containerView: UIView
    
    init(
        frame: CGRect,
        viewId: Int64,
        args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        self.frame = frame
        self.viewId = viewId
        self.args = args as? [String: Any]
        self.channel = FlutterMethodChannel(
            name: "checkout_bridge",
            binaryMessenger: messenger
        )
        self.containerView = UIView(frame: frame)
        
        super.init()
        
        initializeComponent()
    }
    
    func view() -> UIView {
        return containerView
    }
    
    // MARK: - Initialization
    
    private func initializeComponent() {
        guard let params = args else {
            sendError(code: "INIT_ERROR", message: "Missing initialization parameters")
            return
        }
        
        // Extract required parameters
        guard let sessionId = params["paymentSessionID"] as? String,
              let sessionSecret = params["paymentSessionSecret"] as? String,
              let publicKey = params["publicKey"] as? String else {
            sendError(code: "INIT_ERROR", message: "Missing required payment session parameters")
            return
        }
        
        let environmentStr = params["environment"] as? String ?? "sandbox"
        
        // Parse environment
        let environment: CheckoutIOSComponents.Environment = environmentStr.lowercased() == "production" 
            ? .production 
            : .sandbox
        
        // Determine if this is a stored card
        let hasSavedCardConfig = params["savedCardConfig"] != nil
        let cardConfig = params["cardConfig"] as? [String: Any]
        let showCardholderName = cardConfig?["showCardholderName"] as? Bool ?? false
        
        // Initialize CheckoutComponents with configuration
        Task { @MainActor in
            do {
                // Create payment session
                let paymentSession = PaymentSessionResponse(
                    id: sessionId,
                    secret: sessionSecret
                )
                
                // Create component callback
                let callbacks = ComponentCallback(
                    onReady: { [weak self] component in
                        self?.sendCardReady()
                    },
                    onTokenized: { [weak self] result in
                        self?.sendCardTokenized(tokenData: result.data)
                        return .accepted
                    },
                    handleSubmit: { [weak self] sessionData in
                        self?.sendSessionData(sessionData: sessionData)
                        return .failure
                    },
                    onSuccess: { [weak self] _, paymentID in
                        self?.sendPaymentSuccess(paymentId: paymentID)
                    },
                    onError: { [weak self] _, error in
                        self?.sendError(code: error.code, message: error.message)
                    }
                )
                
                // Create configuration
                let configuration = try await CheckoutComponents.Configuration(
                    paymentSession: paymentSession,
                    publicKey: publicKey,
                    environment: environment,
                    callbacks: callbacks
                )
                
                // Create CheckoutComponents
                let checkoutComponentsSDK = try await CheckoutComponentsFactory(config: configuration).create()
                self.checkoutComponents = checkoutComponentsSDK
                
                // Create card component
                let component = try checkoutComponentsSDK.create(.card)
                self.cardComponent = component
                
                // Check if component is available
                if component.isAvailable() {
                    // Render the component
                    let swiftUIView = component.render()
                    self.embedSwiftUIView(swiftUIView)
                    self.isInitialized = true
                    
                    // Start validation monitoring
                    self.startValidationMonitoring()
                } else {
                    self.sendError(
                        code: "CARD_NOT_AVAILABLE",
                        message: "Card payment method is not available"
                    )
                }
            } catch let error as CheckoutError {
                self.sendError(code: "CHECKOUT_ERROR", message: error.message)
            } catch {
                self.sendError(
                    code: "INIT_ERROR",
                    message: error.localizedDescription
                )
            }
        }
    }
    
    private func embedSwiftUIView<Content: View>(_ view: Content) {
        let hostingController = UIHostingController(rootView: AnyView(view))
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = containerView.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        containerView.addSubview(hostingController.view)
        self.hostingController = hostingController
    }
    
    // MARK: - Public Methods (Called from Plugin)
    
    func validateCard() async -> Bool {
        guard isInitialized,
              let component = cardComponent as? PaymentMethodComponent else {
            return false
        }
        
        do {
            return try await component.isValid()
        } catch {
            return false
        }
    }
    
    func tokenizeCard(result: @escaping FlutterResult) {
        guard isInitialized,
              let component = cardComponent as? PaymentMethodComponent else {
            result(FlutterError(
                code: "CARD_NOT_READY",
                message: "Card component not initialized",
                details: nil
            ))
            return
        }
        
        Task {
            do {
                // Tokenize the card
                try await component.tokenize()
                
                // Result will be sent via onTokenized callback
                await MainActor.run {
                    result(["status": "processing"])
                }
            } catch {
                await MainActor.run {
                    result(FlutterError(
                        code: "TOKEN_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }
    
    func getSessionData(result: @escaping FlutterResult) {
        guard isInitialized,
              let component = cardComponent as? PaymentMethodComponent else {
            result(FlutterError(
                code: "CARD_NOT_READY",
                message: "Card component not initialized",
                details: nil
            ))
            return
        }
        
        Task {
            do {
                // Submit to get session data
                try await component.submit()
                
                // Result will be sent via handleSubmit callback
                await MainActor.run {
                    result(["status": "processing"])
                }
            } catch {
                await MainActor.run {
                    result(FlutterError(
                        code: "SESSION_DATA_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }
    
    // MARK: - Validation Monitoring
    
    private func startValidationMonitoring() {
        Task {
            while isInitialized {
                do {
                    // Check card validity
                    guard let component = cardComponent as? PaymentMethodComponent else {
                        break
                    }
                    
                    let currentValidity = try await component.isValid()
                    
                    if currentValidity != isCardValid {
                        isCardValid = currentValidity
                        await MainActor.run {
                            sendValidationState(isValid: currentValidity)
                        }
                    }
                    
                    try await Task.sleep(nanoseconds: 500_000_000) // 500ms
                } catch {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s on error
                }
            }
        }
    }
    
    // MARK: - Callbacks to Flutter
    
    private func sendCardTokenized(tokenData: Any) {
        // Convert TokenDetails to dictionary
        var tokenDetailsMap: [String: Any] = [:]
        
        if let tokenDetails = tokenData as? TokenDetails {
            tokenDetailsMap = [
                "type": tokenDetails.type,
                "token": tokenDetails.token,
                "expiresOn": tokenDetails.expiresOn ?? "",
                "expiryMonth": tokenDetails.expiryMonth ?? 0,
                "expiryYear": tokenDetails.expiryYear ?? 0,
                "scheme": tokenDetails.scheme ?? "",
                "last4": tokenDetails.last4 ?? "",
                "bin": tokenDetails.bin ?? "",
                "cardType": tokenDetails.cardType ?? "",
                "cardCategory": tokenDetails.cardCategory ?? ""
            ]
        } else {
            tokenDetailsMap = ["raw": String(describing: tokenData)]
        }
        
        channel.invokeMethod("cardTokenized", arguments: ["tokenDetails": tokenDetailsMap])
    }
    
    private func sendSessionData(sessionData: String) {
        channel.invokeMethod("sessionDataReady", arguments: ["sessionData": sessionData])
    }
    
    private func sendCardReady() {
        channel.invokeMethod("cardReady", arguments: nil)
    }
    
    private func sendValidationState(isValid: Bool) {
        channel.invokeMethod("validationChanged", arguments: ["isValid": isValid])
    }
    
    private func sendPaymentSuccess(paymentId: String) {
        channel.invokeMethod("paymentSuccess", arguments: paymentId)
    }
    
    private func sendError(code: String, message: String) {
        let error = [
            "errorCode": code,
            "errorMessage": message
        ]
        channel.invokeMethod("paymentError", arguments: error)
    }
    
    // MARK: - Cleanup
    
    deinit {
        isInitialized = false
    }
}
