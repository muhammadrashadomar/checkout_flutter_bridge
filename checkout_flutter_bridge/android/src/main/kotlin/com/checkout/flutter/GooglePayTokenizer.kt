// package com.checkout.flutter

// import android.util.Log
// import androidx.activity.ComponentActivity
// import androidx.lifecycle.Lifecycle
// import androidx.lifecycle.LifecycleOwner
// import androidx.lifecycle.LifecycleRegistry
// import com.checkout.components.core.CheckoutComponentsFactory
// import com.checkout.components.interfaces.Environment
// import com.checkout.components.interfaces.api.PaymentMethodComponent
// import com.checkout.components.interfaces.component.CheckoutComponentConfiguration
// import com.checkout.components.interfaces.component.ComponentCallback
// import com.checkout.components.interfaces.error.CheckoutError
// import com.checkout.components.interfaces.model.ApiCallResult
// import com.checkout.components.interfaces.model.PaymentMethodName
// import com.checkout.components.interfaces.model.PaymentSessionResponse
// import com.checkout.components.wallet.wrapper.GooglePayFlowCoordinator
// import io.flutter.plugin.common.MethodChannel
// import java.util.concurrent.atomic.AtomicBoolean
// import kotlinx.coroutines.CoroutineScope
// import kotlinx.coroutines.Dispatchers
// import kotlinx.coroutines.SupervisorJob
// import kotlinx.coroutines.cancel
// import kotlinx.coroutines.launch
// import kotlinx.coroutines.withContext
// import kotlinx.coroutines.withTimeout

// /**
//  * Google Pay Tokenizer Service
//  *
//  * Production-ready service for handling Google Pay tokenization using Checkout SDK. Works with
// the
//  * pay package for button rendering and native payment sheet.
//  *
//  * Features:
//  * - Comprehensive error handling with specific error codes
//  * - Thread-safe state management
//  * - Proper resource cleanup
//  * - Secure logging (no sensitive data)
//  * - Timeout handling for async operations
//  */
// class GooglePayTokenizer(
//         private val activity: ComponentActivity,
//         private val channel: MethodChannel
// ) : LifecycleOwner {

//     private val lifecycleRegistry = LifecycleRegistry(this)
//     private val coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

//     private var googlePayFlowCoordinator: GooglePayFlowCoordinator? = null
//     private lateinit var googlePayComponent: PaymentMethodComponent

//     private val isInitialized = AtomicBoolean(false)
//     private val isInitializing = AtomicBoolean(false)

//     override val lifecycle: Lifecycle
//         get() = lifecycleRegistry

//     companion object {
//         private const val TAG = "GooglePayTokenizer"

//         // Timeout constants (in milliseconds)
//         private const val INITIALIZATION_TIMEOUT_MS = 30000L // 30 seconds
//         private const val TOKENIZATION_TIMEOUT_MS = 15000L // 15 seconds
//     }

//     /**
//      * Initialize the Checkout SDK for Google Pay tokenization
//      *
//      * @param sessionId Payment session ID from backend
//      * @param sessionSecret Payment session secret from backend
//      * @param publicKey Checkout.com public key
//      * @param environment Environment mode ("sandbox" or "production")
//      */
//     fun initialize(
//             sessionId: String,
//             sessionSecret: String,
//             publicKey: String,
//             environment: String
//     ) {
//         // Validate parameters
//         val validationError =
//                 validateInitParameters(sessionId, sessionSecret, publicKey, environment)
//         if (validationError != null) {
//             Log.e(TAG, "Initialization failed: Invalid parameters - $validationError")
//             sendError(ErrorCode.INVALID_CONFIG, validationError)
//             return
//         }

//         // Check if already initialized
//         if (isInitialized.get()) {
//             Log.w(TAG, "Google Pay tokenizer already initialized")
//             return
//         }

//         // Check if initialization is in progress
//         if (!isInitializing.compareAndSet(false, true)) {
//             Log.w(TAG, "Initialization already in progress")
//             return
//         }

//         Log.d(TAG, "Initializing Google Pay tokenizer for environment: $environment")

//         val checkoutEnvironment = parseEnvironment(environment)

//         // Create Google Pay coordinator
//         val coordinator =
//                 GooglePayFlowCoordinator(
//                         context = activity,
//                         handleActivityResult = { resultCode, _ ->
//                             Log.d(TAG, "Activity result received with code: $resultCode")
//                         }
//                 )

//         // Create component callback
//         val componentCallback =
//                 ComponentCallback(
//                         onReady = { component ->
//                             Log.d(TAG, "Google Pay component ready: ${component.name}")
//                         },
//                         handleSubmit = { sessionData ->
//                             Log.d(TAG, "handleSubmit called with sessionData: $sessionData")
//                             // Send session data to Flutter
//                             sendSessionData(sessionData)
//                             // Tokenize Google Pay data
//                             tokenizeGooglePayData(sessionData)
//                             // Return Failure to prevent SDK from completing payment
// automatically
//                             ApiCallResult.Failure
//                         },
//                         onSubmit = { component ->
//                             Log.d(TAG, "Google Pay component submitted: ${component.name}")
//                         },
//                         onSuccess = { _, paymentID ->
//                             Log.i(TAG, "Payment successful")
//                             sendPaymentSuccess(paymentID)
//                         },
//                         onError = { _, checkoutError ->
//                             Log.e(
//                                     TAG,
//                                     "Payment error: ${checkoutError.code} -
// ${checkoutError.message}"
//                             )
//                             sendError(ErrorCode.PAYMENT_ERROR, checkoutError.message)
//                         }
//                 )

//         val flowCoordinators = mapOf(PaymentMethodName.GooglePay to coordinator)

//         // Build configuration
//         val configuration =
//                 CheckoutComponentConfiguration(
//                         context = activity,
//                         paymentSession =
//                                 PaymentSessionResponse(id = sessionId, secret = sessionSecret),
//                         publicKey = publicKey,
//                         environment = checkoutEnvironment,
//                         flowCoordinators = flowCoordinators,
//                         componentCallback = componentCallback
//                 )

//         // Initialize Google Pay component asynchronously with timeout
//         coroutineScope.launch {
//             try {
//                 withTimeout(INITIALIZATION_TIMEOUT_MS) {
//                     val checkoutComponents =
//                             CheckoutComponentsFactory(config = configuration).create()
//                     googlePayComponent = checkoutComponents.create(PaymentMethodName.GooglePay)

//                     if (googlePayComponent.isAvailable()) {
//                         googlePayFlowCoordinator = coordinator
//                         isInitialized.set(true)
//                         Log.i(TAG, "Google Pay tokenizer initialized successfully")
//                     } else {
//                         throw GooglePayException(
//                                 ErrorCode.GOOGLEPAY_UNAVAILABLE,
//                                 "Google Pay is not available on this device"
//                         )
//                     }
//                 }
//             } catch (e: GooglePayException) {
//                 Log.e(TAG, "Google Pay specific error: ${e.message}")
//                 sendError(e.errorCode, e.message ?: "Unknown error")
//             } catch (e: CheckoutError) {
//                 Log.e(TAG, "Checkout SDK error during initialization", e)
//                 sendError(
//                         ErrorCode.INITIALIZATION_FAILED,
//                         "SDK initialization failed: ${e.message}"
//                 )
//             } catch (e: kotlinx.coroutines.TimeoutCancellationException) {
//                 Log.e(TAG, "Initialization timeout")
//                 sendError(
//                         ErrorCode.TIMEOUT,
//                         "Initialization timed out after ${INITIALIZATION_TIMEOUT_MS}ms"
//                 )
//             } catch (e: Exception) {
//                 Log.e(TAG, "Unexpected error during initialization", e)
//                 sendError(ErrorCode.INITIALIZATION_FAILED, "Initialization failed: ${e.message}")
//             } finally {
//                 isInitializing.set(false)
//             }
//         }
//     }

//     /**
//      * Get Google Pay session data without completing payment Triggers submit() which calls
//      * handleSubmit callback to return session data to Flutter
//      *
//      * @param result MethodChannel result to send response back to Flutter
//      */
//     fun getGooglePaySessionData(result: MethodChannel.Result) {
//         // Validate state
//         if (!isInitialized.get() || !::googlePayComponent.isInitialized) {
//             Log.e(TAG, "Get session data failed: Google Pay tokenizer not initialized")
//             result.error(ErrorCode.INVALID_STATE.name, "Google Pay tokenizer not initialized",
// null)
//             return
//         }

//         Log.d(TAG, "Retrieving Google Pay session data...")

//         coroutineScope.launch {
//             try {
//                 withTimeout(TOKENIZATION_TIMEOUT_MS) {
//                     // Call submit() on the component to trigger handleSubmit callback
//                     withContext(Dispatchers.Default) { googlePayComponent.submit() }

//                     Log.i(TAG, "Google Pay submit called - session data will be sent via
// callback")

//                     // Notify method call success (actual data comes via callback)
//                     result.success(true)
//                 }
//             } catch (e: kotlinx.coroutines.TimeoutCancellationException) {
//                 Log.e(TAG, "Session data retrieval timeout")
//                 result.error(
//                         ErrorCode.TIMEOUT.name,
//                         "Session data retrieval timed out after ${TOKENIZATION_TIMEOUT_MS}ms",
//                         null
//                 )
//             } catch (e: Exception) {
//                 Log.e(TAG, "Error retrieving session data: ${e.javaClass.simpleName}", e)
//                 result.error(
//                         ErrorCode.TOKENIZATION_FAILED.name,
//                         "Failed to retrieve session data: ${e.message}",
//                         null
//                 )
//             }
//         }
//     }

//     /** Clean up resources and reset state */
//     fun dispose() {
//         Log.d(TAG, "Disposing Google Pay tokenizer")

//         try {
//             coroutineScope.cancel()
//             googlePayFlowCoordinator = null
//             isInitialized.set(false)
//             isInitializing.set(false)

//             Log.d(TAG, "Google Pay tokenizer disposed successfully")
//         } catch (e: Exception) {
//             Log.e(TAG, "Error during disposal", e)
//         }
//     }

//     // ==================== PRIVATE HELPER METHODS ====================

//     /**
//      * Validate initialization parameters
//      * @return Error message if validation fails, null if valid
//      */
//     private fun validateInitParameters(
//             sessionId: String,
//             sessionSecret: String,
//             publicKey: String,
//             environment: String
//     ): String? {
//         return when {
//             sessionId.isBlank() -> "Session ID is required"
//             sessionSecret.isBlank() -> "Session secret is required"
//             publicKey.isBlank() -> "Public key is required"
//             environment.isBlank() -> "Environment is required"
//             !isValidEnvironment(environment) ->
//                     "Invalid environment: $environment (must be 'sandbox' or 'production')"
//             else -> null
//         }
//     }

//     /** Check if environment string is valid */
//     private fun isValidEnvironment(environment: String): Boolean {
//         return environment.lowercase() in listOf("sandbox", "production")
//     }

//     /** Parse environment string to SDK Environment enum */
//     private fun parseEnvironment(environment: String): Environment {
//         return if (environment.lowercase() == "production") {
//             Environment.PRODUCTION
//         } else {
//             Environment.SANDBOX
//         }
//     }

//     /** Send payment success event to Flutter */
//     private fun sendPaymentSuccess(paymentId: String) {
//         try {
//             channel.invokeMethod("paymentSuccess", paymentId)
//             Log.d(TAG, "Payment success event sent to Flutter")
//         } catch (e: Exception) {
//             Log.e(TAG, "Failed to send payment success event", e)
//         }
//     }

//     /** Send session data event to Flutter */
//     private fun sendSessionData(sessionData: String) {
//         try {
//             Log.d(TAG, "Sending session data to Flutter: $sessionData")

//             // Send the map directly wrapped in sessionData key
//             val data = mapOf("sessionData" to sessionData)

//             channel.invokeMethod("sessionDataReady", data)
//             Log.d(TAG, "Session data sent to Flutter successfully")
//         } catch (e: Exception) {
//             Log.e(TAG, "Failed to send session data event", e)
//         }
//     }

//     /** Send error event to Flutter */
//     private fun sendError(errorCode: ErrorCode, message: String) {
//         try {
//             val errorData = mapOf("errorCode" to errorCode.name, "errorMessage" to message)
//             channel.invokeMethod("paymentError", errorData)
//             Log.d(TAG, "Error event sent to Flutter: ${errorCode.name}")
//         } catch (e: Exception) {
//             Log.e(TAG, "Failed to send error event", e)
//         }
//     }

//     // ==================== ERROR HANDLING ====================

//     /** Error codes for Google Pay operations */
//     enum class ErrorCode {
//         INVALID_CONFIG,
//         INITIALIZATION_FAILED,
//         TOKENIZATION_FAILED,
//         TIMEOUT,
//         GOOGLEPAY_UNAVAILABLE,
//         INVALID_STATE,
//         PAYMENT_ERROR
//     }

//     /** Custom exception for Google Pay specific errors */
//     private class GooglePayException(val errorCode: ErrorCode, message: String) :
//             Exception(message)
// }
