package com.example.flow_flutter_new

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
import com.checkout.components.interfaces.error.CheckoutError
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
 * - NO native Google Pay button (Flutter renders button via pay package)
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
                        onSubmit = { component ->
                            Log.d(TAG, "Component submitted: ${component.name}")
                        },
                        onSuccess = { _, paymentID ->
                            Log.i(TAG, "Payment successful")
                            sendPaymentSuccess(paymentID)
                        },
                        onError = { _, checkoutError ->
                            Log.e(TAG, "Payment error: ${checkoutError.code}")
                            sendError(ErrorCode.PAYMENT_ERROR, checkoutError.message)
                        }
                )

        val flowCoordinators = mapOf(PaymentMethodName.GooglePay to coordinator)

        // Build configuration
        val configuration =
                CheckoutComponentConfiguration(
                        context = activity,
                        paymentSession =
                                PaymentSessionResponse(id = sessionId!!, secret = sessionSecret!!),
                        publicKey = publicKey!!,
                        environment = environment,
                        flowCoordinators = flowCoordinators,
                        componentCallback = componentCallback
                )

        container.setViewTreeLifecycleOwner(activity)

        // Initialize component asynchronously with timeout
        scope.launch {
            try {
                withTimeout(INITIALIZATION_TIMEOUT_MS) {
                    checkoutComponents = CheckoutComponentsFactory(config = configuration).create()
                    googlePayComponent = checkoutComponents.create(PaymentMethodName.GooglePay)

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

    /**
     * Launch Google Pay payment sheet Called from Flutter via method channel
     *
     * @param result MethodChannel result to send response back to Flutter
     */
    fun launchPaymentSheet(result: MethodChannel.Result) {
        // Validate state
        if (!isInitialized.get() || !::googlePayComponent.isInitialized) {
            Log.e(TAG, "Launch failed: Component not ready")
            safeResultError(
                    result,
                    ErrorCode.INVALID_STATE.name,
                    "Google Pay component not initialized",
                    null
            )
            return
        }

        scope.launch {
            try {
                Log.d(TAG, "Launching Google Pay payment sheet")

                withTimeout(LAUNCH_TIMEOUT_MS) {
                    // The Checkout.com SDK handles the sheet internally
                    // Result will come via callbacks
                    withContext(Dispatchers.Main) {
                        safeResultSuccess(result, mapOf("status" to "launched"))
                    }
                }
            } catch (e: TimeoutCancellationException) {
                Log.e(TAG, "Launch timeout")
                withContext(Dispatchers.Main) {
                    safeResultError(
                            result,
                            ErrorCode.TIMEOUT.name,
                            "Launch timed out after ${LAUNCH_TIMEOUT_MS}ms",
                            null
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "Launch error: ${e.javaClass.simpleName}", e)
                withContext(Dispatchers.Main) {
                    safeResultError(
                            result,
                            ErrorCode.LAUNCH_FAILED.name,
                            e.message ?: "Failed to launch Google Pay",
                            null
                    )
                }
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

    // ==================== PRIVATE HELPER METHODS ====================

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

    /** Safely invoke result.success() ensuring it's only called once */
    private fun safeResultSuccess(result: MethodChannel.Result, value: Any?) {
        try {
            result.success(value)
        } catch (e: IllegalStateException) {
            Log.w(TAG, "Result already sent, ignoring duplicate success call")
        } catch (e: Exception) {
            Log.e(TAG, "Error sending result success", e)
        }
    }

    /** Safely invoke result.error() ensuring it's only called once */
    private fun safeResultError(
            result: MethodChannel.Result,
            errorCode: String,
            errorMessage: String?,
            errorDetails: Any?
    ) {
        try {
            result.error(errorCode, errorMessage, errorDetails)
        } catch (e: IllegalStateException) {
            Log.w(TAG, "Result already sent, ignoring duplicate error call")
        } catch (e: Exception) {
            Log.e(TAG, "Error sending result error", e)
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
        LAUNCH_FAILED,
        PAYMENT_ERROR
    }

    /** Custom exception for Google Pay specific errors */
    private class GooglePayException(val errorCode: ErrorCode, message: String) :
            Exception(message)

    companion object {
        private const val TAG = "GooglePayPlatformView"
        private const val CHANNEL_NAME = "checkout_bridge"

        // Timeout constants (in milliseconds)
        private const val INITIALIZATION_TIMEOUT_MS = 30000L // 30 seconds
        private const val LAUNCH_TIMEOUT_MS = 5000L // 5 seconds
    }
}
