package com.checkout.flutter

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.compose.ui.platform.ComposeView
import com.checkout.components.core.CheckoutComponentsFactory
import com.checkout.components.interfaces.Environment
import com.checkout.components.interfaces.api.CheckoutComponents
import com.checkout.components.interfaces.api.PaymentMethodComponent
import com.checkout.components.interfaces.component.CardConfiguration
import com.checkout.components.interfaces.component.CheckoutComponentConfiguration
import com.checkout.components.interfaces.component.ComponentCallback
import com.checkout.components.interfaces.component.ComponentOption
import com.checkout.components.interfaces.component.PaymentButtonAction
import com.checkout.components.interfaces.error.CheckoutError
import com.checkout.components.interfaces.model.ApiCallResult
import com.checkout.components.interfaces.model.CallbackResult
import com.checkout.components.interfaces.model.CardholderNamePosition
import com.checkout.components.interfaces.model.PaymentMethodName
import com.checkout.components.interfaces.model.PaymentSessionResponse
import com.checkout.components.interfaces.uicustomisation.BorderRadius
import com.checkout.components.interfaces.uicustomisation.designtoken.ColorTokens
import com.checkout.components.interfaces.uicustomisation.designtoken.DesignTokens
import com.checkout.components.interfaces.uicustomisation.font.Font
import com.checkout.components.interfaces.uicustomisation.font.FontName
import com.checkout.components.interfaces.uicustomisation.font.FontStyle
import com.checkout.components.interfaces.uicustomisation.font.FontWeight
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import kotlinx.coroutines.*

/**
 * Card Platform View - Handles card input UI and tokenization Completely controlled by Flutter
 * layer via method channels
 *
 * Architecture:
 * - Renders card input fields via Checkout.com SDK
 * - No native payment button (controlled by Flutter)
 * - Exposes methods via MainActivity method channel
 * - Sends results back to Flutter via method channel callbacks
 */
class CardPlatformView(private val activity: Activity, args: Any?, messenger: BinaryMessenger) :
        PlatformView {

        private val container = android.widget.FrameLayout(activity)
        private val channel = MethodChannel(messenger, CHANNEL_NAME)
        private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
        private lateinit var checkoutComponents: CheckoutComponents
        private lateinit var cardComponent: PaymentMethodComponent

        @Volatile private var isInitialized = false
        @Volatile private var isCardValid = false

        companion object {
                private const val TAG = "CardPlatformView"
                private const val CHANNEL_NAME = "checkout_bridge"

                // Error Codes
                private const val ERR_INIT = "INIT_ERROR"
                private const val ERR_CARD_NOT_READY = "CARD_NOT_READY"
                private const val ERR_TOKEN = "TOKEN_ERROR"
                private const val ERR_SESSION_DATA = "SESSION_DATA_ERROR"
                private const val ERR_LAUNCH = "LAUNCH_ERROR"
                private const val ERR_CHECKOUT = "CHECKOUT_ERROR"
        }

        init {
                // Detect component type from arguments
                val params = args as? Map<*, *> ?: emptyMap<String, Any>()
                initializeComponent(params)
        }

        /* Initialize card component with configuration from Flutter */
        private fun initializeComponent(params: Map<*, *>) {
                // Extract required parameters
                val sessionId = params["paymentSessionID"] as? String ?: ""
                val sessionSecret = params["paymentSessionSecret"] as? String ?: ""
                val publicKey = params["publicKey"] as? String ?: ""
                val environmentStr = params["environment"] as? String ?: "sandbox"

                // Validate required parameters
                if (sessionId.isEmpty() || sessionSecret.isEmpty() || publicKey.isEmpty()) {
                        sendError(ERR_INIT, "Missing required payment session parameters")
                        return
                }

                // Parse environment
                val environment =
                        when (environmentStr.lowercase()) {
                                "production" -> Environment.PRODUCTION
                                else -> Environment.SANDBOX
                        }

                // Parse appearance configuration
                val appearance = params["appearance"] as? Map<*, *>
                val designTokens = buildDesignTokens(appearance)

                // Determine if this is a stored card or new card
                val hasSavedCardConfig = params.containsKey("savedCardConfig")
                val cardConfig = params["cardConfig"] as? Map<*, *>
                val showCardholderName = cardConfig?.get("showCardholderName") as? Boolean ?: false

                // Build component callback
                val componentCallback = createComponentCallback()

                // Build component options
                val componentOption =
                        if (hasSavedCardConfig) {
                                // Stored card options
                                ComponentOption(
                                        showPayButton = false,
                                        paymentButtonAction = PaymentButtonAction.TOKENIZE,
                                )
                        } else {
                                // New card options
                                ComponentOption(
                                        showPayButton =
                                                false, // ✅ Hide native button - controlled by
                                        // Flutter
                                        paymentButtonAction = PaymentButtonAction.TOKENIZE,
                                        cardConfiguration =
                                                CardConfiguration(
                                                        displayCardholderName =
                                                                if (showCardholderName)
                                                                        CardholderNamePosition.TOP
                                                                else CardholderNamePosition.HIDDEN
                                                )
                                )
                        }

                val componentOptionsMap = mapOf(PaymentMethodName.Card to componentOption)

                // Build configuration
                val configuration =
                        CheckoutComponentConfiguration(
                                context = activity,
                                paymentSession =
                                        PaymentSessionResponse(
                                                id = sessionId,
                                                secret = sessionSecret
                                        ),
                                publicKey = publicKey,
                                environment = environment,
                                componentCallback = componentCallback,
                                appearance = designTokens,
                                componentOptions = componentOptionsMap
                        )

                // Initialize component asynchronously
                scope.launch {
                        try {
                                checkoutComponents =
                                        CheckoutComponentsFactory(config = configuration).create()
                                cardComponent =
                                        checkoutComponents.create(
                                                PaymentMethodName.Card,
                                                componentOption,
                                        )

                                if (cardComponent.isAvailable()) {
                                        withContext(Dispatchers.Main) {
                                                val composeView = ComposeView(activity)
                                                composeView.setContent { cardComponent.Render() }
                                                container.addView(composeView)
                                                isInitialized = true
                                                Log.d(
                                                        TAG,
                                                        "Card component initialized successfully"
                                                )

                                                // Notify Flutter that card view is ready
                                                sendCardReady()

                                                // Start monitoring validation state
                                                startValidationMonitoring()
                                        }
                                } else {
                                        sendError(
                                                "CARD_NOT_AVAILABLE",
                                                "Card payment method is not available"
                                        )
                                }
                        } catch (e: CheckoutError) {
                                sendError(ERR_CHECKOUT, e.message)
                        } catch (e: Exception) {
                                sendError(
                                        ERR_INIT,
                                        e.message ?: "Failed to initialize card component"
                                )
                        }
                }
        }

        private fun createComponentCallback(): ComponentCallback {
                return ComponentCallback(
                        onReady = { component ->
                                Log.d(TAG, "Component ready: ${component.name}")
                                // Note: Actual ready notification is sent after view is added to
                                // container
                        },
                        handleSubmit = { sessionData ->
                                Log.d(TAG, "[Flow-Card]: sessionData fetched successfully")

                                // Send session data to Flutter for backend submission
                                sendSessionData(sessionData)

                                // Return Failure to prevent SDK from completing payment
                                // This allows us to get session data without
                                // auto-completing payment
                                ApiCallResult.Failure
                        },
                        onSubmit = { component -> Log.d(TAG, "[Flow-Card]: onSubmit called") },
                        onSuccess = { _, paymentID -> sendPaymentSuccess(paymentID) },
                        onTokenized = { result ->
                                Log.d(TAG, "[Flow-Card]: tokenized successfully")
                                sendCardTokenized(result.data)
                                CallbackResult.Accepted
                        },
                        onError = { _, checkoutError ->
                                Log.e(TAG, "[Flow-Card] Error: ${checkoutError.message}")
                                sendError(checkoutError.code.toString(), checkoutError.message)
                        },
                )
        }

        /* Build design tokens from appearance configuration */
        private fun buildDesignTokens(appearance: Map<*, *>?): DesignTokens {
                val colorTokensMap = appearance?.get("colorTokens") as? Map<*, *>
                val borderRadius = (appearance?.get("borderRadius") as? Number)?.toInt() ?: 8

                return DesignTokens(
                        colorTokens =
                                ColorTokens(
                                        colorAction =
                                                (colorTokensMap?.get("colorAction") as? Number)
                                                        ?.toLong()
                                                        ?: 0XFF00639E,
                                        colorFormBorder =
                                                (colorTokensMap?.get("colorFormBorder") as? Number)
                                                        ?.toLong()
                                                        ?: 0XFFCCCCCC,
                                        colorDisabled = 0XFF858585,
                                        colorSecondary = 0XFF858585,
                                        colorBorder =
                                                (colorTokensMap?.get("colorBorder") as? Number)
                                                        ?.toLong()
                                                        ?: 0XFFCCCCCC,
                                        colorPrimary =
                                                (colorTokensMap?.get("colorPrimary") as? Number)
                                                        ?.toLong()
                                                        ?: 0XFF111111,
                                        colorInverse = 0xFFFFFFFF,
                                        colorOutline = 0XFFB1B1B1,
                                        colorScrolledContainer = 0XFFE8E6E6
                                ),
                        borderButtonRadius = BorderRadius(all = borderRadius),
                        borderFormRadius = BorderRadius(all = borderRadius),
                        fonts =
                                mapOf(
                                        FontName.Input to
                                                Font(
                                                        fontStyle = FontStyle.Normal,
                                                        fontWeight = FontWeight.Normal,
                                                        fontSize = 14,
                                                ),
                                        FontName.Button to
                                                Font(
                                                        fontStyle = FontStyle.Normal,
                                                        fontWeight = FontWeight.SemiBold,
                                                        fontSize = 14,
                                                ),
                                        FontName.Label to
                                                Font(
                                                        fontStyle = FontStyle.Normal,
                                                        fontWeight = FontWeight.Normal,
                                                        fontSize = 14,
                                                ),
                                ),
                )
        }

        // ==================== PUBLIC METHODS (Called from MainActivity) ====================

        /**
         * Start monitoring card validation state Since SDK doesn't provide onValidation callback,
         * we poll for changes
         */
        private fun startValidationMonitoring() {
                scope.launch {
                        while (isInitialized) {
                                try {
                                        val currentValidity = checkCardValidity()
                                        if (currentValidity != isCardValid) {
                                                isCardValid = currentValidity
                                                sendValidationState(currentValidity)
                                        }
                                        delay(500) // Check every 500ms
                                } catch (e: Exception) {
                                        Log.e(TAG, "Error checking validation: ${e.message}")
                                        delay(1000) // Wait longer on error
                                }
                        }
                }
        }

        /**
         * Check if card input is currently valid
         * @return true if all card fields are valid
         */
        private suspend fun checkCardValidity(): Boolean {
                if (!isInitialized || !::cardComponent.isInitialized) {
                        return false
                }

                return try {
                        // Use SDK's validation method
                        cardComponent.isValid()
                } catch (e: Exception) {
                        Log.e(TAG, "Error checking card validity: ${e.message}", e)
                        false
                }
        }

        /**
         * Validate card input Note: This is a blocking method that calls the suspend function
         * @return true if card input is valid
         */
        fun validateCard(): Boolean {
                return runBlocking { checkCardValidity() }
        }

        /**
         * Tokenize the card - called from Flutter via method channel This is triggered exclusively
         * by Flutter button press
         */
        fun tokenizeCard(result: MethodChannel.Result) {
                if (!isInitialized || !::cardComponent.isInitialized) {
                        result.error(ERR_CARD_NOT_READY, "Card component not initialized", null)
                        return
                }

                scope.launch {
                        try {
                                Log.d(TAG, "Starting tokenization...")

                                // Tokenize on background thread
                                withContext(Dispatchers.Default) { cardComponent.tokenize() }

                                // Result will be sent via onTokenized callback
                                // Send success to acknowledge the call
                                withContext(Dispatchers.Main) {
                                        result.success(mapOf("status" to "processing"))
                                }
                        } catch (e: Exception) {
                                Log.e(TAG, "Tokenization error: ${e.message}", e)
                                withContext(Dispatchers.Main) {
                                        result.error(
                                                ERR_TOKEN,
                                                e.message ?: "Tokenization failed",
                                                null
                                        )
                                }
                        }
                }
        }

        fun getSessionData(result: MethodChannel.Result) {
                if (!isInitialized || !::cardComponent.isInitialized) {
                        val errorMsg = "Card component not initialized"
                        Log.e(TAG, errorMsg)
                        result.error(ERR_CARD_NOT_READY, errorMsg, null)
                        return
                }

                try {
                        // Use Main dispatcher and SupervisorJob to ensure coroutine executes
                        CoroutineScope(Dispatchers.Main + SupervisorJob()).launch {
                                try {
                                        Log.d(TAG, "Starting session data submission...")

                                        // Submit session data on background thread
                                        withContext(Dispatchers.Default) {
                                                try {
                                                        cardComponent.submit()
                                                        Log.d(
                                                                TAG,
                                                                "✅ cardComponent.submit() completed successfully"
                                                        )
                                                        true
                                                } catch (e: Exception) {
                                                        Log.e(
                                                                TAG,
                                                                "❌ cardComponent.submit() threw exception: ${e.message}",
                                                                e
                                                        )
                                                        throw e
                                                }
                                        }

                                        // Result will be sent via handleSubmit callback
                                        // Send success to acknowledge the call
                                        withContext(Dispatchers.Main) {
                                                result.success(mapOf("status" to "processing"))
                                        }
                                } catch (e: Exception) {
                                        Log.e(
                                                TAG,
                                                "❌ Session data submission error: ${e.message}",
                                                e
                                        )
                                        withContext(Dispatchers.Main) {
                                                result.error(
                                                        ERR_SESSION_DATA,
                                                        e.message
                                                                ?: "Session data submission failed",
                                                        null
                                                )
                                        }
                                }
                        }
                } catch (e: Exception) {
                        Log.e(TAG, "Failed to launch coroutine: ${e.message}", e)
                        result.error(ERR_LAUNCH, e.message ?: "Failed to launch coroutine", null)
                }
        }

        // ==================== CALLBACK METHODS (Send to Flutter) ====================

        /* Send card tokenized event to Flutter */
        private fun sendCardTokenized(tokenData: Any?) {
                runOnMainThread {
                        try {
                                // Convert TokenDetails to Map
                                val tokenDetailsMap =
                                        when (tokenData) {
                                                is com.checkout.components.interfaces.model.TokenDetails -> {
                                                        mapOf(
                                                                "type" to tokenData.type,
                                                                "token" to tokenData.token,
                                                                "expiresOn" to tokenData.expiresOn,
                                                                "expiryMonth" to
                                                                        tokenData.expiryMonth,
                                                                "expiryYear" to
                                                                        tokenData.expiryYear,
                                                                "scheme" to tokenData.scheme,
                                                                "last4" to tokenData.last4,
                                                                "bin" to tokenData.bin,
                                                                "cardType" to tokenData.cardType,
                                                                "cardCategory" to
                                                                        tokenData.cardCategory
                                                        )
                                                }
                                                else -> {
                                                        Log.w(
                                                                TAG,
                                                                "Unknown token data type: ${tokenData?.javaClass}"
                                                        )
                                                        mapOf("raw" to tokenData.toString())
                                                }
                                        }

                                val data = mapOf("tokenDetails" to tokenDetailsMap)
                                channel.invokeMethod("cardTokenized", data)
                                Log.d(TAG, "Card tokenized event sent to Flutter")
                        } catch (e: Exception) {
                                Log.e(TAG, "Failed to send tokenized event: ${e.message}", e)
                        }
                }
        }

        /* Send session data to Flutter for backend submission */
        private fun sendSessionData(sessionData: String) {
                runOnMainThread {
                        try {
                                val data = mapOf("sessionData" to sessionData)

                                channel.invokeMethod("sessionDataReady", data)
                                Log.d(TAG, "Session data sent ")
                        } catch (e: Exception) {
                                Log.e(TAG, "Failed to send session data: ${e.message}", e)
                                // Send error to Flutter
                                sendError(
                                        ERR_SESSION_DATA,
                                        e.message ?: "Failed to send session data"
                                )
                        }
                }
        }

        /* Send card ready event to Flutter */
        private fun sendCardReady() {
                runOnMainThread {
                        try {
                                channel.invokeMethod("cardReady", null)
                                Log.d(TAG, "Card ready event sent to Flutter")
                        } catch (e: Exception) {
                                Log.e(TAG, "Failed to send card ready event: ${e.message}", e)
                        }
                }
        }

        /* Send validation state change to Flutter */
        private fun sendValidationState(isValid: Boolean) {
                runOnMainThread {
                        try {
                                val data = mapOf("isValid" to isValid)
                                channel.invokeMethod("validationChanged", data)
                                Log.d(TAG, "Validation state sent to Flutter: $isValid")
                        } catch (e: Exception) {
                                Log.e(TAG, "Failed to send validation state: ${e.message}", e)
                        }
                }
        }

        /* Send payment success event to Flutter */
        private fun sendPaymentSuccess(paymentId: String) {
                runOnMainThread {
                        try {
                                channel.invokeMethod("paymentSuccess", paymentId)
                                Log.d(TAG, "Payment success event sent to Flutter")
                        } catch (e: Exception) {
                                Log.e(TAG, "Failed to send success event: ${e.message}", e)
                        }
                }
        }

        /* Send error event to Flutter */
        private fun sendError(code: String, message: String) {
                runOnMainThread {
                        try {
                                val error = mapOf("code" to code, "message" to message)
                                channel.invokeMethod("paymentError", error)
                                Log.d(TAG, "Error event sent to Flutter: $code - $message")
                        } catch (e: Exception) {
                                Log.e(TAG, "Failed to send error event: ${e.message}", e)
                        }
                }
        }

        /* Helper to run code on main thread */
        private fun runOnMainThread(block: () -> Unit) {
                if (Looper.myLooper() == Looper.getMainLooper()) {
                        block()
                } else {
                        Handler(Looper.getMainLooper()).post(block)
                }
        }

        // ==================== LIFECYCLE METHODS ====================

        override fun getView(): android.widget.FrameLayout = container

        override fun dispose() {
                scope.cancel()
                Log.d(TAG, "Card component disposed")
        }
}
