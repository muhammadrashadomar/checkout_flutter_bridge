package com.checkout.flutter

import android.util.Log
import androidx.activity.ComponentActivity
import com.checkout.flutter.views.CardViewFactory
import com.checkout.flutter.views.GooglePayViewFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * CheckoutFlutterBridgePlugin - Main plugin class Registers platform views and handles method
 * channel communication
 */
class CheckoutFlutterBridgePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var activity: ComponentActivity? = null
    private var cardPlatformView: CardPlatformView? = null
    private var googlePayPlatformView: GooglePayPlatformView? = null
    private var googlePayTokenizer: GooglePayTokenizer? = null

    companion object {
        private const val CHANNEL = "checkout_bridge"
        private const val TAG = "CheckoutPlugin"
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "Plugin attached to engine")

        // Store the binding for later use when activity is attached
        this.flutterPluginBinding = flutterPluginBinding

        val messenger = flutterPluginBinding.binaryMessenger
        channel = MethodChannel(messenger, CHANNEL)
        channel.setMethodCallHandler(this)

        // Platform views will be registered when activity is attached
        Log.d(TAG, "Waiting for activity to register platform views")
    }

    private fun registerPlatformViews() {
        val binding = flutterPluginBinding ?: return
        val currentActivity = activity ?: return

        Log.d(TAG, "Registering platform views with activity")

        // Register platform views
        binding.platformViewRegistry.registerViewFactory(
                "flow_card_view",
                CardViewFactory(binding.binaryMessenger, currentActivity) { view ->
                    cardPlatformView = view
                    Log.d(TAG, "Card view instance captured")
                }
        )

        binding.platformViewRegistry.registerViewFactory(
                "flow_googlepay_view",
                GooglePayViewFactory(binding.binaryMessenger, currentActivity) { view ->
                    googlePayPlatformView = view
                    Log.d(TAG, "Google Pay view instance captured")
                }
        )

        Log.d(TAG, "Platform views registered successfully")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d(TAG, "Method call: ${call.method}")

        when (call.method) {
            // ==================== CARD METHODS ====================
            "initCardView" -> {
                // Card view initialization happens in PlatformView
                result.success(true)
            }
            "initStoredCardView" -> {
                // Stored card view initialization happens in PlatformView
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
                        // Initialize on first call
                        if (activity != null) {
                            googlePayTokenizer = GooglePayTokenizer(activity!!, channel)
                        } else {
                            result.error("NO_ACTIVITY", "Activity not available", null)
                            return
                        }
                    }

                    @Suppress("UNCHECKED_CAST") val args = call.arguments as? Map<String, Any>

                    if (args == null) {
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
                            result.error("INVALID_ARGS", "Session ID is required", null)
                            return
                        }
                        sessionSecret.isNullOrBlank() -> {
                            result.error("INVALID_ARGS", "Session secret is required", null)
                            return
                        }
                        publicKey.isNullOrBlank() -> {
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
                    // Native check can be implemented here if needed
                    result.success(true)
                } catch (e: Exception) {
                    result.error(
                            "AVAILABILITY_CHECK_FAILED",
                            "Failed to check availability: ${e.message}",
                            null
                    )
                }
            }
            "tokenizeGooglePayData" -> {
                try {
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

                    if (paymentData.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "Payment data cannot be empty", null)
                        return
                    }

                    googlePayTokenizer?.tokenizePaymentData(paymentData, result)
                } catch (e: Exception) {
                    result.error("TOKENIZATION_ERROR", "Failed to tokenize: ${e.message}", null)
                }
            }
            "getGooglePaySessionData" -> {
                try {
                    if (googlePayTokenizer == null) {
                        result.error(
                                "GOOGLEPAY_NOT_READY",
                                "Google Pay tokenizer not initialized",
                                null
                        )
                        return
                    }
                    googlePayTokenizer?.getGooglePaySessionData(result)
                } catch (e: Exception) {
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

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "Plugin detached from engine")
        channel.setMethodCallHandler(null)
        cleanup()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d(TAG, "Plugin attached to activity")
        activity =
                binding.activity as? ComponentActivity
                        ?: throw IllegalStateException("Activity must be a ComponentActivity")

        // Now that we have the activity, register platform views
        registerPlatformViews()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "Plugin detached from activity for config changes")
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.d(TAG, "Plugin reattached to activity after config changes")
        activity = binding.activity as? ComponentActivity
    }

    override fun onDetachedFromActivity() {
        Log.d(TAG, "Plugin detached from activity")
        activity = null
        cleanup()
    }

    private fun cleanup() {
        try {
            Log.d(TAG, "Cleaning up resources")
            googlePayTokenizer?.dispose()
            cardPlatformView?.dispose()
            googlePayPlatformView?.dispose()

            cardPlatformView = null
            googlePayPlatformView = null
            googlePayTokenizer = null
            flutterPluginBinding = null
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup", e)
        }
    }
}
