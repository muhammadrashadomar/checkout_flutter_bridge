package com.example.flow_flutter_new

import android.util.Log
import androidx.activity.ComponentActivity
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.checkout.components.core.CheckoutComponentsFactory
import com.checkout.components.interfaces.Environment
import com.checkout.components.interfaces.component.CheckoutComponentConfiguration
import com.checkout.components.interfaces.component.ComponentCallback
import com.checkout.components.interfaces.error.CheckoutError
import com.checkout.components.interfaces.model.PaymentMethodName
import com.checkout.components.interfaces.model.PaymentSessionResponse
import com.checkout.components.wallet.wrapper.GooglePayFlowCoordinator
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Google Pay Tokenizer Service
 *
 * Handles Google Pay tokenization using Checkout SDK without UI components. Works with the pay
 * package for button rendering and native payment sheet.
 */
class GooglePayTokenizer(
        private val activity: ComponentActivity,
        private val channel: MethodChannel
) : LifecycleOwner {

    private val lifecycleRegistry = LifecycleRegistry(this)
    private val coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    private var googlePayFlowCoordinator: GooglePayFlowCoordinator? = null
    private var isInitialized = false

    override val lifecycle: Lifecycle
        get() = lifecycleRegistry

    /** Initialize the Checkout SDK for Google Pay tokenization */
    fun initialize(
            sessionId: String,
            sessionSecret: String,
            publicKey: String,
            environment: String
    ) {
        Log.d(TAG, "Initializing Google Pay tokenizer...")
        // Log.d(TAG, "Session ID: $sessionId")
        // Log.d(TAG, "Environment: $environment")

        val checkoutEnvironment =
                if (environment.lowercase() == "sandbox") {
                    Environment.SANDBOX
                } else {
                    Environment.PRODUCTION
                }

        // Create Google Pay coordinator
        val coordinator =
                GooglePayFlowCoordinator(
                        context = activity,
                        handleActivityResult = { resultCode, data ->
                            // Handle activity result if needed
                            Log.d(TAG, "Activity result: $resultCode")
                        }
                )

        // Create component callback
        val componentCallback =
                ComponentCallback(
                        onReady = { component -> Log.d(TAG, "Component ready: ${component.name}") },
                        onSubmit = { component ->
                            Log.d(TAG, "Component submitted: ${component.name}")
                        },
                        onSuccess = { _, paymentID ->
                            Log.d(TAG, "Payment success: $paymentID")
                            channel.invokeMethod("paymentSuccess", paymentID)
                        },
                        onError = { _, checkoutError ->
                            Log.e(TAG, "Payment error: ${checkoutError.message}")
                            channel.invokeMethod(
                                    "paymentError",
                                    mapOf(
                                            "errorCode" to checkoutError.code.toString(),
                                            "errorMessage" to checkoutError.message
                                    )
                            )
                        }
                )

        val flowCoordinators = mapOf(PaymentMethodName.GooglePay to coordinator)

        // Build configuration
        val configuration =
                CheckoutComponentConfiguration(
                        context = activity,
                        paymentSession =
                                PaymentSessionResponse(id = sessionId, secret = sessionSecret),
                        publicKey = publicKey,
                        environment = checkoutEnvironment,
                        flowCoordinators = flowCoordinators,
                        componentCallback = componentCallback
                )

        // Initialize Google Pay component asynchronously
        coroutineScope.launch {
            try {
                val checkoutComponents = CheckoutComponentsFactory(config = configuration).create()
                val googlePayComponent = checkoutComponents.create(PaymentMethodName.GooglePay)

                if (googlePayComponent.isAvailable()) {
                    googlePayFlowCoordinator = coordinator
                    isInitialized = true
                    Log.d(TAG, "Google Pay tokenizer initialized successfully")
                } else {
                    Log.e(TAG, "Google Pay not available on this device")
                    channel.invokeMethod(
                            "paymentError",
                            mapOf(
                                    "errorCode" to "GOOGLEPAY_NOT_AVAILABLE",
                                    "errorMessage" to "Google Pay is not available on this device"
                            )
                    )
                }
            } catch (e: CheckoutError) {
                Log.e(TAG, "Checkout error during initialization", e)
                channel.invokeMethod(
                        "paymentError",
                        mapOf("errorCode" to "INITIALIZATION_ERROR", "errorMessage" to e.message)
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize Google Pay tokenizer", e)
                channel.invokeMethod(
                        "paymentError",
                        mapOf("errorCode" to "INITIALIZATION_ERROR", "errorMessage" to e.message)
                )
            }
        }
    }

    /** Tokenize Google Pay payment data received from the pay package */
    fun tokenizePaymentData(paymentData: String, result: MethodChannel.Result) {
        Log.d(TAG, "Tokenizing Google Pay payment data...")

        if (!isInitialized) {
            Log.e(TAG, "Google Pay tokenizer not initialized")
            result.error("NOT_INITIALIZED", "Google Pay tokenizer not initialized", null)
            return
        }

        coroutineScope.launch {
            try {
                // Log.d(TAG, "Processing payment data: ${paymentData.take(100)}...")

                // For now, we'll pass the payment data as a token
                // In a full implementation, you would process this through Checkout SDK
                val tokenData =
                        mapOf(
                                "token" to paymentData,
                                "type" to "googlepay",
                                "scheme" to "GOOGLEPAY"
                        )

                Log.d(TAG, "Google Pay data processed successfully")

                // Send token back to Flutter
                channel.invokeMethod("cardTokenized", tokenData)
                result.success(true)
            } catch (e: Exception) {
                // Log.e(TAG, "Error tokenizing Google Pay data", e)
                result.error("TOKENIZATION_ERROR", "Failed to tokenize: ${e.message}", null)
            }
        }
    }

    /** Clean up resources */
    fun dispose() {
        Log.d(TAG, "Disposing Google Pay tokenizer")
        coroutineScope.cancel()
        googlePayFlowCoordinator = null
        isInitialized = false
    }

    companion object {
        private const val TAG = "GooglePayTokenizer"
    }
}
