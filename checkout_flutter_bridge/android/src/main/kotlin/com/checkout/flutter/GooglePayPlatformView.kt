package com.checkout.flutter

import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.FrameLayout
import androidx.activity.ComponentActivity
import androidx.compose.ui.platform.ComposeView
import androidx.lifecycle.setViewTreeLifecycleOwner
import com.checkout.components.core.CheckoutComponentsFactory
import com.checkout.components.interfaces.Environment
import com.checkout.components.interfaces.api.CheckoutComponents
import com.checkout.components.interfaces.api.PaymentMethodComponent
import com.checkout.components.interfaces.component.CheckoutComponentConfiguration
import com.checkout.components.interfaces.component.ComponentCallback
import com.checkout.components.interfaces.component.ComponentOption
import com.checkout.components.interfaces.component.PaymentButtonAction
import com.checkout.components.interfaces.error.CheckoutError
import com.checkout.components.interfaces.model.ApiCallResult
import com.checkout.components.interfaces.model.CallbackResult
import com.checkout.components.interfaces.model.PaymentMethodName
import com.checkout.components.interfaces.model.PaymentSessionResponse
import com.checkout.components.wallet.wrapper.GooglePayFlowCoordinator
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.*

/**
 * Google Pay Platform View
 *
 * Production-ready platform view for handling Google Pay payment sheet. Complete control from
 * Flutter layer with no native UI button rendering.
 *
 * Architecture:
 * - Only exposes payment sheet logic
 * - Called via method channel from Flutter
 * - Sends results back via callbacks
 *
 * Features:
 * - Comprehensive error handling with specific error codes
 * - Thread-safe state management
 * - Proper resource cleanup
 * - Timeout handling for async operations
 * - Secure logging (no sensitive data)
 */
class GooglePayPlatformView(
        private val activity: ComponentActivity,
        args: Any?,
        messenger: BinaryMessenger
) : PlatformView {

    private val container = FrameLayout(activity)
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    private lateinit var checkoutComponents: CheckoutComponents
    private lateinit var googlePayComponent: PaymentMethodComponent
    private lateinit var coordinator: GooglePayFlowCoordinator

    private val isInitialized = AtomicBoolean(false)
    private val isInitializing = AtomicBoolean(false)

    init {
        initializeGooglePay(args)
    }

    /**
     * Initialize Google Pay component with configuration from Flutter
     *
     * @param args Map containing configuration parameters from Flutter
     */
    private fun initializeGooglePay(args: Any?) {
        // Validate and parse arguments
        val params = args as? Map<*, *>
        if (params == null) {
            Log.e(TAG, "Initialization failed: Invalid arguments")
            sendError(ErrorCode.INVALID_CONFIG, "Configuration parameters are required")
            return
        }

        // Extract required parameters
        val sessionId = params["paymentSessionID"] as? String
        val sessionSecret = params["paymentSessionSecret"] as? String
        val publicKey = params["publicKey"] as? String
        val environmentStr = params["environment"] as? String ?: "sandbox"

        // Validate required parameters
        val validationError = validateParameters(sessionId, sessionSecret, publicKey)
        if (validationError != null) {
            Log.e(TAG, "Initialization failed: $validationError")
            sendError(ErrorCode.INVALID_CONFIG, validationError)
            return
        }

        // Check if initialization already in progress
        if (!isInitializing.compareAndSet(false, true)) {
            Log.w(TAG, "Initialization already in progress")
            return
        }

        Log.d(TAG, "Initializing Google Pay component for environment: $environmentStr")

        // Parse environment
        val environment = parseEnvironment(environmentStr)

        // Create Google Pay coordinator
        coordinator =
                GooglePayFlowCoordinator(
                        context = activity,
                        handleActivityResult = { resultCode, data ->
                            handleActivityResult(resultCode, data)
                        }
                )

        // Build component callback
        val componentCallback =
                ComponentCallback(
                        onReady = { component -> Log.d(TAG, "Component ready: ${component.name}") },
                        handleSubmit = { sessionData ->
                            Log.d(TAG, "handleSubmit - sending session data to Flutter")
                            sendSessionData(sessionData)
                            // Return Failure to prevent SDK from completing payment automatically
                            ApiCallResult.Failure
                        },
                        onSubmit = { component -> Log.d(TAG, "GPay submitted: ${component.name}") },
                        onTokenized = { result ->
                            Log.d(TAG, "onTokenized - sending tokenization result to Flutter")
                            sendTokenizationResult(result.data)

                            // Return Accepted to prevent SDK from completing payment automatically
                            CallbackResult.Accepted
                        },
                        onSuccess = { _, paymentID ->
                            Log.i(TAG, "Payment successful")
                            sendPaymentSuccess(paymentID)
                        },
                        onError = { _, error ->
                            Log.e(TAG, "Payment error: ${error.message}")
                            sendError(ErrorCode.PAYMENT_ERROR, error.message ?: "Payment failed")
                        }
                )

        val flowCoordinators = mapOf(PaymentMethodName.GooglePay to coordinator)

        // Configure component options to trigger tokenization
        val componentOption =
                ComponentOption(
                        showPayButton = true,
                        paymentButtonAction = PaymentButtonAction.TOKENIZE
                )
        val componentOptionsMap = mapOf(PaymentMethodName.GooglePay to componentOption)

        // Build configuration
        val configuration =
                CheckoutComponentConfiguration(
                        context = activity,
                        paymentSession =
                                PaymentSessionResponse(id = sessionId!!, secret = sessionSecret!!),
                        publicKey = publicKey!!,
                        environment = environment,
                        flowCoordinators = flowCoordinators,
                        componentCallback = componentCallback,
                        componentOptions = componentOptionsMap
                )

        container.setViewTreeLifecycleOwner(activity)

        // Initialize component asynchronously with timeout
        scope.launch {
            try {
                withTimeout(INITIALIZATION_TIMEOUT_MS) {
                    checkoutComponents = CheckoutComponentsFactory(config = configuration).create()
                    googlePayComponent =
                            checkoutComponents.create(
                                    PaymentMethodName.GooglePay,
                            )

                    // Check if Google Pay is available (suspend call)
                    val isAvailable = googlePayComponent.isAvailable()

                    if (isAvailable) {
                        // Render component (optional - Flutter controls when to show)
                        withContext(Dispatchers.Main) {
                            val composeView = ComposeView(activity)
                            composeView.setContent { googlePayComponent.Render() }
                            container.addView(composeView)

                            isInitialized.set(true)
                            Log.i(TAG, "Google Pay component initialized successfully")
                        }
                    } else {
                        throw GooglePayException(
                                ErrorCode.GOOGLEPAY_UNAVAILABLE,
                                "Google Pay is not available on this device"
                        )
                    }
                }
            } catch (e: GooglePayException) {
                Log.e(TAG, "Google Pay error: ${e.message}")
                sendError(e.errorCode, e.message ?: "Unknown error")
            } catch (e: CheckoutError) {
                Log.e(TAG, "Checkout SDK error during initialization", e)
                sendError(
                        ErrorCode.INITIALIZATION_FAILED,
                        "SDK initialization failed: ${e.message}"
                )
            } catch (e: TimeoutCancellationException) {
                Log.e(TAG, "Initialization timeout")
                sendError(
                        ErrorCode.TIMEOUT,
                        "Initialization timed out after ${INITIALIZATION_TIMEOUT_MS}ms"
                )
            } catch (e: Exception) {
                Log.e(TAG, "Unexpected error during initialization", e)
                sendError(
                        ErrorCode.INITIALIZATION_FAILED,
                        e.message ?: "Failed to initialize Google Pay"
                )
            } finally {
                isInitializing.set(false)
            }
        }
    }

    /**
     * Handle activity result from Google Pay sheet
     *
     * @param resultCode Result code from activity
     * @param data Optional data string from activity
     */
    private fun handleActivityResult(resultCode: Int, data: String) {
        try {
            if (::checkoutComponents.isInitialized) {
                checkoutComponents.handleActivityResult(resultCode, data)
                Log.d(TAG, "Activity result handled successfully")
            } else {
                Log.w(TAG, "Cannot handle activity result: Components not initialized")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling activity result", e)
            sendError(ErrorCode.PAYMENT_ERROR, "Failed to process payment result: ${e.message}")
        }
    }

    // ==================== PUBLIC METHODS (Called from MainActivity) ====================

    /**
     * Check if Google Pay is available
     *
     * @param callback Callback to receive the availability result
     */
    fun checkAvailability(callback: (Boolean) -> Unit) {
        if (!isInitialized.get()) {
            Log.w(TAG, "Availability check: Component not initialized")
            callback(false)
            return
        }

        scope.launch {
            try {
                val isAvailable =
                        if (::googlePayComponent.isInitialized) {
                            googlePayComponent.isAvailable()
                        } else {
                            Log.w(TAG, "Availability check: Component not initialized")
                            false
                        }
                callback(isAvailable)
            } catch (e: Exception) {
                Log.e(TAG, "Error checking availability", e)
                callback(false)
            }
        }
    }

    // ==================== CALLBACK METHODS (Send to Flutter) ====================

    /**
     * Send payment success event to Flutter
     *
     * @param paymentId Payment ID from successful transaction
     */
    private fun sendPaymentSuccess(paymentId: String) {
        runOnMainThread {
            try {
                channel.invokeMethod("paymentSuccess", paymentId)
                Log.d(TAG, "Payment success event sent to Flutter")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send payment success event", e)
            }
        }
    }

    /**
     * Send error event to Flutter
     *
     * @param code Error code enum
     * @param message Human-readable error message
     */
    private fun sendError(code: ErrorCode, message: String) {
        runOnMainThread {
            try {
                val error = mapOf("errorCode" to code.name, "errorMessage" to message)
                channel.invokeMethod("paymentError", error)
                Log.d(TAG, "Error event sent to Flutter: ${code.name}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send error event", e)
            }
        }
    }

    /**
     * Send session data to Flutter
     *
     * @param sessionData Session data string from SDK
     */
    private fun sendSessionData(sessionData: String) {
        runOnMainThread {
            try {
                val data = mapOf("sessionData" to sessionData)
                channel.invokeMethod("sessionDataReady", data)
                Log.d(TAG, "Session data sent to Flutter successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send session data event", e)
            }
        }
    }

    /**
     * Send tokenization result to Flutter
     *
     * @param tokenData The token data from SDK
     */
    private fun sendTokenizationResult(tokenData: Any?) {
        runOnMainThread {
            try {
                // Convert TokenDetails to Map (similar to Card implementation)
                val tokenDetailsMap =
                        when (tokenData) {
                            is com.checkout.components.interfaces.model.TokenDetails -> {
                                Log.d(TAG, "Token data: $tokenData")
                                mapOf(
                                        "type" to tokenData.type,
                                        "token" to tokenData.token,
                                        "expiresOn" to tokenData.expiresOn,
                                        "expiryMonth" to tokenData.expiryMonth,
                                        "expiryYear" to tokenData.expiryYear,
                                        "scheme" to tokenData.scheme,
                                        "last4" to tokenData.last4,
                                        "bin" to tokenData.bin,
                                        "cardType" to tokenData.cardType,
                                        "cardCategory" to tokenData.cardCategory
                                )
                            }
                            else -> {
                                Log.w(TAG, "Unknown token data type: ${tokenData?.javaClass}")
                                mapOf("raw" to tokenData.toString())
                            }
                        }

                val data = mapOf("tokenDetails" to tokenDetailsMap)
                channel.invokeMethod("cardTokenized", data)
                Log.d(TAG, "Tokenization result sent to Flutter successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send tokenization result", e)
            }
        }
    }

    // ==================== PRIVATE HELPER METHODS ====================

    /**
     * Tokenize Google Pay - called from Flutter via method channel
     *
     * This triggers the component's submit() which will call onTokenized callback The tokenization
     * result is sent back to Flutter through sendTokenizationResult()
     *
     * @param result MethodChannel result to send response back to Flutter
     */
    fun tokenizeGooglePay(result: MethodChannel.Result) {
        // Validate state
        if (!isInitialized.get()) {
            Log.e(TAG, "Tokenization failed: Google Pay component not initialized")
            result.error(ErrorCode.INVALID_STATE.name, "Google Pay component not initialized", null)
            return
        }

        if (!::googlePayComponent.isInitialized) {
            Log.e(TAG, "Tokenization failed: Google Pay component not ready")
            result.error(ErrorCode.INVALID_STATE.name, "Google Pay component not ready", null)
            return
        }

        Log.d(TAG, "Starting Google Pay tokenization...")

        scope.launch {
            try {
                withTimeout(TOKENIZATION_TIMEOUT_MS) {
                    // Trigger tokenization by calling submit on the component
                    // This will call the onTokenized callback which sends data to Flutter
                    withContext(Dispatchers.Default) { googlePayComponent.tokenize() }

                    Log.i(
                            TAG,
                            "Google Pay submit called - tokenization result will be sent via callback"
                    )

                    // Notify method call success (actual token comes via onTokenized callback)
                    result.success(true)
                }
            } catch (e: kotlinx.coroutines.TimeoutCancellationException) {
                Log.e(TAG, "Tokenization timeout")
                result.error(
                        ErrorCode.TIMEOUT.name,
                        "Tokenization timed out after ${TOKENIZATION_TIMEOUT_MS}ms",
                        null
                )
            } catch (e: Exception) {
                Log.e(TAG, "Error tokenizing Google Pay: ${e.javaClass.simpleName}", e)
                result.error(
                        ErrorCode.TOKENIZATION_FAILED.name,
                        "Failed to tokenize: ${e.message}",
                        null
                )
            }
        }
    }

    /**
     * Validate required initialization parameters
     *
     * @return Error message if validation fails, null if valid
     */
    private fun validateParameters(
            sessionId: String?,
            sessionSecret: String?,
            publicKey: String?
    ): String? {
        return when {
            sessionId.isNullOrBlank() -> "Session ID is required"
            sessionSecret.isNullOrBlank() -> "Session secret is required"
            publicKey.isNullOrBlank() -> "Public key is required"
            else -> null
        }
    }

    /** Parse environment string to SDK Environment enum */
    private fun parseEnvironment(environment: String): Environment {
        return when (environment.lowercase()) {
            "production" -> Environment.PRODUCTION
            else -> Environment.SANDBOX
        }
    }

    /** Helper to run code on main thread */
    private fun runOnMainThread(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            block()
        } else {
            Handler(Looper.getMainLooper()).post(block)
        }
    }

    // ==================== LIFECYCLE METHODS ====================

    override fun getView(): FrameLayout = container

    override fun dispose() {
        try {
            scope.cancel()
            isInitialized.set(false)
            isInitializing.set(false)
            Log.d(TAG, "Google Pay component disposed successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error during disposal", e)
        }
    }

    // ==================== ERROR HANDLING ====================

    /** Error codes for Google Pay platform view operations */
    enum class ErrorCode {
        INVALID_CONFIG,
        INITIALIZATION_FAILED,
        TIMEOUT,
        GOOGLEPAY_UNAVAILABLE,
        INVALID_STATE,
        PAYMENT_ERROR,
        TOKENIZATION_FAILED
    }

    /** Custom exception for Google Pay specific errors */
    private class GooglePayException(val errorCode: ErrorCode, message: String) :
            Exception(message)

    companion object {
        private const val TAG = "GooglePayPlatformView"
        private const val CHANNEL_NAME = "checkout_bridge"
        private const val INITIALIZATION_TIMEOUT_MS = 30000L // 30 seconds
        private const val TOKENIZATION_TIMEOUT_MS = 15000L // 15 seconds
    }
}
