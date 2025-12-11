import Flutter
import UIKit
import SwiftUI
import PassKit
import CheckoutIOSComponents

/// Apple Pay Platform View - Handles Apple Pay payment sheet and tokenization
/// Completely controlled by Flutter layer via method channels
///
/// Architecture:
/// - Wraps SwiftUI Apple Pay component in UIView for Flutter Platform View
/// - No native payment button (controlled by Flutter)
/// - Exposes methods via method channel
/// - Sends results back to Flutter via method channel callbacks
class ApplePayPlatformView: NSObject, FlutterPlatformView {
    private let frame: CGRect
    private let viewId: Int64
    private let channel: FlutterMethodChannel
    private let args: [String: Any]?
    
    private var hostingController: UIHostingController<AnyView>?
    private var checkoutComponents: Any? // CheckoutComponents instance
    private var applePayComponent: Any? // PaymentMethodComponent instance
    private var isInitialized = false
    
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
            sendError(code: "INVALID_CONFIG", message: "Missing initialization parameters")
            return
        }
        
        // Extract required parameters
        guard let sessionId = params["paymentSessionID"] as? String,
              let sessionSecret = params["paymentSessionSecret"] as? String,
              let publicKey = params["publicKey"] as? String else {
            sendError(code: "INVALID_CONFIG", message: "Missing required payment session parameters")
            return
        }
        
        // Extract Apple Pay specific configuration
        let applePayConfig = params["applePayConfig"] as? [String: Any]
        let merchantIdentifier = applePayConfig?["merchantIdentifier"] as? String ?? ""
        
        if merchantIdentifier.isEmpty {
            sendError(code: "INVALID_CONFIG", message: "Apple Pay merchant identifier is required")
            return
        }
        
        let environmentStr = params["environment"] as? String ?? "sandbox"
        
        // Parse environment
        let environment: CheckoutIOSComponents.Environment = environmentStr.lowercased() == "production"
            ? .production
            : .sandbox
        
        // Initialize CheckoutComponents with Apple Pay Configuration
        Task { @MainActor in
            do {
                // Create payment session
                let paymentSession = PaymentSessionResponse(
                    id: sessionId,
                    secret: sessionSecret
                )
                
                // Create component callback
                let callbacks = ComponentCallback(
                    onReady: { component in
                        print("Apple Pay component ready")
                    },
                    onTokenized: { [weak self] result in
                        self?.sendTokenizationResult(tokenData: result.data)
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
                
                // Create configuration with Apple Pay merchant identifier
                let configuration = try await CheckoutComponents.Configuration(
                    paymentSession: paymentSession,
                    publicKey: publicKey,
                    environment: environment,
                    merchantIdentifier: merchantIdentifier,  // Required for Apple Pay
                    callbacks: callbacks
                )
                
                // Create CheckoutComponents
                let checkoutComponentsSDK = try await CheckoutComponentsFactory(config: configuration).create()
                self.checkoutComponents = checkoutComponentsSDK
                
                // Create Apple Pay component
                let component = try checkoutComponentsSDK.create(.applePay)
                self.applePayComponent = component
                
                // Check if component is available
                if component.isAvailable() {
                    // Render the Apple Pay button
                    let swiftUIView = component.render()
                    self.embedSwiftUIView(swiftUIView)
                    self.isInitialized = true
                } else {
                    self.sendError(
                        code: "APPLEPAY_NOT_AVAILABLE",
                        message: "Apple Pay is not available on this device"
                    )
                }
            } catch let error as CheckoutError {
                self.sendError(code: "CHECKOUT_ERROR", message: error.message)
            } catch {
                self.sendError(
                    code: "INITIALIZATION_FAILED",
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
    
    func checkAvailability() async -> Bool {
        guard isInitialized,
              let component = applePayComponent as? PaymentMethodComponent else {
            return false
        }
        
        do {
            return try await component.isAvailable()
        } catch {
            return false
        }
    }
    
    func tokenizeApplePay(result: @escaping FlutterResult) {
        guard isInitialized,
              let component = applePayComponent as? PaymentMethodComponent else {
            result(FlutterError(
                code: "INVALID_STATE",
                message: "Apple Pay component not initialized",
                details: nil
            ))
            return
        }
        
        Task {
            do {
                // Submit Apple Pay - this will present the payment sheet
                try await component.submit()
                
                // Result will be sent via onTokenized callback
                await MainActor.run {
                    result(true)
                }
            } catch {
                await MainActor.run {
                    result(FlutterError(
                        code: "TOKENIZATION_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }
    
    // MARK: - Callbacks to Flutter
    
    private func sendTokenizationResult(tokenData: Any) {
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
