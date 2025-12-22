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
                val isValid = cardPlatformView!!.validateCard()
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
                // Google Pay initialization happens in PlatformView
                result.success(true)
            }
            "getGooglePaySessionData" -> {
                // Session data is automatically sent via handleSubmit callback
                result.success(true)
            }
            "tokenizeGooglePay" -> {
                if (googlePayPlatformView == null) {
                    result.error("GOOGLEPAY_NOT_READY", "Google Pay view not initialized", null)
                    return
                }
                googlePayPlatformView?.tokenizeGooglePay(result)
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
            cardPlatformView?.dispose()
            googlePayPlatformView?.dispose()

            cardPlatformView = null
            googlePayPlatformView = null
            flutterPluginBinding = null
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup", e)
        }
    }
}
