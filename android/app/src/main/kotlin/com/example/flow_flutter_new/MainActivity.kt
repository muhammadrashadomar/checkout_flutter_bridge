package com.example.flow_flutter_new

import android.util.Log
import com.example.flow_flutter_new.views.CardViewFactory
import com.example.flow_flutter_new.views.GooglePayViewFactory
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformViewRegistry

/**
 * Main Activity - Handles platform view registration and method channel setup Follows clean
 * architecture with separation of concerns
 */
class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "checkout_bridge"
    private var cardPlatformView: CardPlatformView? = null
    private var googlePayPlatformView: GooglePayPlatformView? = null
    private var googlePayTokenizer: GooglePayTokenizer? = null
    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val registry: PlatformViewRegistry = flutterEngine.platformViewsController.registry

        // Register platform views with callback to capture instances
        registry.registerViewFactory(
                "flow_card_view",
                CardViewFactory(messenger, this) { view ->
                    cardPlatformView = view
                    Log.d("MainActivity", "Card view instance captured")
                }
        )

        registry.registerViewFactory(
                "flow_googlepay_view",
                GooglePayViewFactory(messenger, this) { view ->
                    googlePayPlatformView = view
                    Log.d("MainActivity", "Google Pay view instance captured")
                }
        )

        // Set up method channel for calls from Flutter
        channel = MethodChannel(messenger, CHANNEL)
        channel.setMethodCallHandler { call, result -> handleMethodCall(call, result) }

        // Initialize Google Pay tokenizer
        googlePayTokenizer = GooglePayTokenizer(this, channel)
        Log.d("MainActivity", "Google Pay tokenizer initialized")
    }

    /** Handle method calls from Flutter */
    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d("MainActivity", "Method call: ${call.method}")

        when (call.method) {
            // ==================== CARD METHODS ====================
            "initCardView" -> {
                // Card view initialization happens in PlatformView
                // This method can be used for additional setup if needed
                result.success(true)
            }
            "validateCard" -> {
                if (cardPlatformView == null) {
                    result.error("CARD_NOT_READY", "Card view not initialized", null)
                    return
                }
                val isValid = cardPlatformView?.validateCard() ?: false
                result.success(isValid)
            }
            "tokenizeCard" -> {
                if (cardPlatformView == null) {
                    result.error("CARD_NOT_READY", "Card view not initialized", null)
                    return
                }
                cardPlatformView?.tokenizeCard(result)
            }
            "getSessionData" -> {
                if (cardPlatformView == null) {
                    result.error("CARD_NOT_READY", "Card view not initialized", null)
                    return
                }
                cardPlatformView?.getSessionData(result)
            }

            // ==================== GOOGLE PAY METHODS ====================
            "initGooglePay" -> {
                @Suppress("UNCHECKED_CAST") val args = call.arguments as? Map<String, Any>

                val sessionId = args?.get("paymentSessionID") as? String ?: ""
                val sessionSecret = args?.get("paymentSessionSecret") as? String ?: ""
                val publicKey = args?.get("publicKey") as? String ?: ""
                val environment = args?.get("environment") as? String ?: "sandbox"

                googlePayTokenizer?.initialize(sessionId, sessionSecret, publicKey, environment)
                result.success(true)
            }
            "checkGooglePayAvailability" -> {
                // Pay package handles availability checks
                result.success(true)
            }
            "tokenizeGooglePayData" -> {
                if (googlePayTokenizer == null) {
                    result.error(
                            "GOOGLEPAY_NOT_READY",
                            "Google Pay tokenizer not initialized",
                            null
                    )
                    return
                }

                @Suppress("UNCHECKED_CAST") val args = call.arguments as? Map<String, Any>
                val paymentData = args?.get("paymentData") as? String

                if (paymentData == null) {
                    result.error("INVALID_ARGS", "Payment data is required", null)
                    return
                }

                googlePayTokenizer?.tokenizePaymentData(paymentData, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        googlePayTokenizer?.dispose()
        super.onDestroy()
    }
}
