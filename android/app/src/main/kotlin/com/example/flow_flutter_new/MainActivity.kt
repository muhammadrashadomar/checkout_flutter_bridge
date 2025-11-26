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

    companion object {
        private const val TAG = "MainActivity"
    }

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
            "initStoredCardView" -> {
                // Stored card view initialization happens in PlatformView
                // The CardPlatformView detects savedCardConfig and initializes accordingly
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
                try {
                    Log.d(TAG, "Initializing Google Pay")

                    if (googlePayTokenizer == null) {
                        Log.e(TAG, "Google Pay tokenizer instance is null")
                        result.error(
                                "GOOGLEPAY_NOT_READY",
                                "Google Pay tokenizer not initialized",
                                null
                        )
                        return
                    }

                    @Suppress("UNCHECKED_CAST") val args = call.arguments as? Map<String, Any>

                    if (args == null) {
                        Log.e(TAG, "Google Pay init: Missing arguments")
                        result.error("INVALID_ARGS", "Configuration parameters are required", null)
                        return
                    }

                    val sessionId = args["paymentSessionID"] as? String
                    val sessionSecret = args["paymentSessionSecret"] as? String
                    val publicKey = args["publicKey"] as? String
                    val environment = args["environment"] as? String ?: "sandbox"

                    // Validate required parameters
                    when {
                        sessionId.isNullOrBlank() -> {
                            Log.e(TAG, "Google Pay init: Missing session ID")
                            result.error("INVALID_ARGS", "Session ID is required", null)
                            return
                        }
                        sessionSecret.isNullOrBlank() -> {
                            Log.e(TAG, "Google Pay init: Missing session secret")
                            result.error("INVALID_ARGS", "Session secret is required", null)
                            return
                        }
                        publicKey.isNullOrBlank() -> {
                            Log.e(TAG, "Google Pay init: Missing public key")
                            result.error("INVALID_ARGS", "Public key is required", null)
                            return
                        }
                    }

                    googlePayTokenizer?.initialize(
                            sessionId!!,
                            sessionSecret!!,
                            publicKey!!,
                            environment
                    )
                    result.success(true)
                    Log.d(TAG, "Google Pay initialization request sent")
                } catch (e: Exception) {
                    Log.e(TAG, "Error in initGooglePay", e)
                    result.error(
                            "INIT_ERROR",
                            "Failed to initialize Google Pay: ${e.message}",
                            null
                    )
                }
            }
            "checkGooglePayAvailability" -> {
                try {
                    Log.d(TAG, "Checking Google Pay availability")
                    // Pay package handles availability checks on Flutter side
                    // This is a placeholder for future native availability checks
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "Error checking Google Pay availability", e)
                    result.error(
                            "AVAILABILITY_CHECK_FAILED",
                            "Failed to check availability: ${e.message}",
                            null
                    )
                }
            }
            "tokenizeGooglePayData" -> {
                try {
                    Log.d(TAG, "Tokenizing Google Pay data")

                    if (googlePayTokenizer == null) {
                        Log.e(TAG, "Google Pay tokenizer instance is null")
                        result.error(
                                "GOOGLEPAY_NOT_READY",
                                "Google Pay tokenizer not initialized",
                                null
                        )
                        return
                    }

                    @Suppress("UNCHECKED_CAST") val args = call.arguments as? Map<String, Any>

                    if (args == null) {
                        Log.e(TAG, "Tokenize: Missing arguments")
                        result.error("INVALID_ARGS", "Payment data is required", null)
                        return
                    }

                    val paymentData = args["paymentData"] as? String

                    if (paymentData.isNullOrBlank()) {
                        Log.e(TAG, "Tokenize: Payment data is empty")
                        result.error("INVALID_ARGS", "Payment data cannot be empty", null)
                        return
                    }

                    // Delegate to tokenizer (it will handle the result callback)
                    googlePayTokenizer?.tokenizePaymentData(paymentData, result)
                } catch (e: Exception) {
                    Log.e(TAG, "Error tokenizing Google Pay data", e)
                    result.error("TOKENIZATION_ERROR", "Failed to tokenize: ${e.message}", null)
                }
            }
            "getGooglePaySessionData" -> {
                try {
                    Log.d(TAG, "Getting Google Pay session data")

                    if (googlePayTokenizer == null) {
                        Log.e(TAG, "Google Pay tokenizer instance is null")
                        result.error(
                                "GOOGLEPAY_NOT_READY",
                                "Google Pay tokenizer not initialized",
                                null
                        )
                        return
                    }

                    // Delegate to tokenizer (it will handle the result callback)
                    googlePayTokenizer?.getGooglePaySessionData(result)
                } catch (e: Exception) {
                    Log.e(TAG, "Error getting Google Pay session data", e)
                    result.error(
                            "SESSION_DATA_ERROR",
                            "Failed to get session data: ${e.message}",
                            null
                    )
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            Log.d(TAG, "Cleaning up resources")
            googlePayTokenizer?.dispose()
            cardPlatformView = null
            googlePayPlatformView = null
            googlePayTokenizer = null
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup", e)
        }
        super.onDestroy()
    }
}
