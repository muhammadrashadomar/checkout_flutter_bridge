package com.checkout.flutter

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.FrameLayout
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

        private val container = FrameLayout(activity)
        private val channel = MethodChannel(messenger, "checkout_bridge")
        private val scope = CoroutineScope(Dispatchers.IO)
        private lateinit var checkoutComponents: CheckoutComponents
        private lateinit var cardComponent: PaymentMethodComponent

        @Volatile private var isInitialized = false

        init {
                // Detect component type from arguments
                val params = args as? Map<*, *> ?: emptyMap<String, Any>()
                val hasSavedCardConfig = params.containsKey("savedCardConfig")

                if (hasSavedCardConfig) {
                        initializeStoredCardComponent(args)
                } else {
                        initializeCardComponent(args)
                }
        }

        /* Initialize card component with configuration from Flutter */
        private fun initializeCardComponent(args: Any?) {
                val params = args as? Map<*, *> ?: emptyMap<String, Any>()

                // Extract required parameters
                val sessionId = params["paymentSessionID"] as? String ?: ""
                val sessionSecret = params["paymentSessionSecret"] as? String ?: ""
                val publicKey = params["publicKey"] as? String ?: ""
                val environmentStr = params["environment"] as? String ?: "sandbox"

                // Validate required parameters
                if (sessionId.isEmpty() || sessionSecret.isEmpty() || publicKey.isEmpty()) {
                        // Log.e("CardPlatformView", "Missing required session parameters")
                        sendError("INIT_ERROR", "Missing required payment session parameters")
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

                // Parse card configuration
                val cardConfig = params["cardConfig"] as? Map<*, *>
                val showCardholderName = cardConfig?.get("showCardholderName") as? Boolean ?: false

                // Build component callback
                val componentCallback =
                        ComponentCallback(
                                onReady = { component ->
                                        Log.d(
                                                "CardPlatformView",
                                                "Component ready: ${component.name}"
                                        )
                                },
                                handleSubmit = { sessionData ->
                                        Log.d(
                                                "CardPlatformView",
                                                "handleSubmit called with sessionData: $sessionData"
                                        )

                                        // Send session data to Flutter for backend submission
                                        sendSessionData(sessionData)

                                        // Return Failure to prevent SDK from completing payment
                                        // This allows us to get session data without
                                        // auto-completing payment
                                        ApiCallResult.Failure
                                },
                                onSubmit = { component ->
                                        Log.d(
                                                "CardPlatformView",
                                                "Component submitted: ${component.name}"
                                        )
                                },
                                onSuccess = { _, paymentID ->
                                        // Log.d("CardPlatformView", "Payment success: $paymentID")
                                        sendPaymentSuccess(paymentID)
                                },
                                onTokenized = { result ->
                                        // Log.d("CardPlatformView", "Card tokenized:
                                        // ${result.data}")
                                        sendCardTokenized(result.data)
                                        CallbackResult.Accepted
                                },
                                onError = { _, checkoutError ->
                                        Log.e("CardPlatformView", "Error: ${checkoutError.message}")
                                        sendError(
                                                checkoutError.code.toString(),
                                                checkoutError.message
                                        )
                                },
                        )

                // Build component options - HIDE native pay button
                val componentOption =
                        ComponentOption(
                                showPayButton =
                                        false, // ✅ Hide native button - controlled by Flutter
                                paymentButtonAction = PaymentButtonAction.TOKENIZE,
                                cardConfiguration =
                                        CardConfiguration(
                                                displayCardholderName =
                                                        if (showCardholderName)
                                                                CardholderNamePosition.TOP
                                                        else CardholderNamePosition.HIDDEN
                                        )
                        )

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
                                                        "CardPlatformView",
                                                        "Card component initialized successfully"
                                                )
                                        }
                                } else {
                                        // Log.e("CardPlatformView", "Card component not available")
                                        sendError(
                                                "CARD_NOT_AVAILABLE",
                                                "Card payment method is not available"
                                        )
                                }
                        } catch (e: CheckoutError) {
                                // Log.e("CardPlatformView", "Checkout error: ${e.message}", e)
                                sendError("CHECKOUT_ERROR", e.message)
                        } catch (e: Exception) {
                                // Log.e("CardPlatformView", "Unexpected error: ${e.message}", e)
                                sendError(
                                        "INIT_ERROR",
                                        e.message ?: "Failed to initialize card component"
                                )
                        }
                }
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

        /* Initialize stored card component with saved card configuration */
        private fun initializeStoredCardComponent(args: Any?) {
                val params = args as? Map<*, *> ?: emptyMap<String, Any>()

                // Extract required parameters
                val sessionId = params["paymentSessionID"] as? String ?: ""
                val sessionSecret = params["paymentSessionSecret"] as? String ?: ""
                val publicKey = params["publicKey"] as? String ?: ""
                val environmentStr = params["environment"] as? String ?: "sandbox"

                // Extract saved card configuration
                val savedCardConfig = params["savedCardConfig"] as? Map<*, *>
                val paymentSourceId = savedCardConfig?.get("paymentSourceId") as? String ?: ""
                val last4 = savedCardConfig?.get("last4") as? String ?: ""
                val scheme = savedCardConfig?.get("scheme") as? String ?: ""
                val expiryMonth = (savedCardConfig?.get("expiryMonth") as? Number)?.toInt() ?: 1
                val expiryYear = (savedCardConfig?.get("expiryYear") as? Number)?.toInt() ?: 2025

                // Validate required parameters
                if (sessionId.isEmpty() || sessionSecret.isEmpty() || publicKey.isEmpty()) {
                        sendError("INIT_ERROR", "Missing required payment session parameters")
                        return
                }

                if (paymentSourceId.isEmpty()) {
                        sendError(
                                "INIT_ERROR",
                                "Missing payment source ID - required for saved card CVV-only input"
                        )
                        return
                }

                Log.d(
                        "CardPlatformView",
                        "Initializing stored card with source ID: $paymentSourceId"
                )

                // Parse environment
                val environment =
                        when (environmentStr.lowercase()) {
                                "production" -> Environment.PRODUCTION
                                else -> Environment.SANDBOX
                        }

                // Parse appearance configuration
                val appearance = params["appearance"] as? Map<*, *>
                val designTokens = buildDesignTokens(appearance)

                // Build component callback (same as card component)
                val componentCallback =
                        ComponentCallback(
                                onReady = { component ->
                                        Log.d(
                                                "CardPlatformView",
                                                "Stored card component ready: ${component.name}"
                                        )
                                },
                                handleSubmit = { sessionData ->
                                        Log.d(
                                                "CardPlatformView",
                                                "handleSubmit called with sessionData: $sessionData"
                                        )
                                        sendSessionData(sessionData)
                                        ApiCallResult.Failure
                                },
                                onSubmit = { component ->
                                        Log.d(
                                                "CardPlatformView",
                                                "Component submitted: ${component.name}"
                                        )
                                },
                                onSuccess = { _, paymentID -> sendPaymentSuccess(paymentID) },
                                onTokenized = { result ->
                                        sendCardTokenized(result.data)
                                        CallbackResult.Accepted
                                },
                                onError = { _, checkoutError ->
                                        Log.e("CardPlatformView", "Error: ${checkoutError.message}")
                                        sendError(
                                                checkoutError.code.toString(),
                                                checkoutError.message
                                        )
                                },
                        )

                // Build component options for stored card (uses Card component)
                val componentOption =
                        ComponentOption(
                                showPayButton = false,
                                paymentButtonAction = PaymentButtonAction.TOKENIZE,
                        )

                // NOTE: Checkout SDK doesn't have explicit StoredCard type
                // We use Card component which will render CVV-only input for stored cards
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

                                // Create Card component (SDK handles stored card rendering
                                // automatically)
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
                                                        "CardPlatformView",
                                                        "Stored card component initialized successfully"
                                                )
                                        }
                                } else {
                                        sendError(
                                                "STORED_CARD_NOT_AVAILABLE",
                                                "Stored card payment method is not available"
                                        )
                                }
                        } catch (e: CheckoutError) {
                                sendError("CHECKOUT_ERROR", e.message)
                        } catch (e: Exception) {
                                sendError(
                                        "INIT_ERROR",
                                        e.message ?: "Failed to initialize stored card component"
                                )
                        }
                }
        }

        // ==================== PUBLIC METHODS (Called from MainActivity) ====================

        /**
         * Validate card input
         * @return true if card input is valid
         */
        fun validateCard(): Boolean {
                if (!isInitialized || !::cardComponent.isInitialized) {
                        Log.w("CardPlatformView", "Card component not initialized for validation")
                        return false
                }

                // TODO: Implement actual validation if SDK provides method
                // For now, we'll assume it's valid if initialized
                return true
        }

        /**
         * Tokenize the card - called from Flutter via method channel This is triggered exclusively
         * by Flutter button press
         */
        fun tokenizeCard(result: MethodChannel.Result) {
                if (!isInitialized || !::cardComponent.isInitialized) {
                        result.error("CARD_NOT_READY", "Card component not initialized", null)
                        return
                }

                scope.launch {
                        try {
                                Log.d("CardPlatformView", "Starting tokenization...")

                                // Tokenize on background thread
                                withContext(Dispatchers.Default) { cardComponent.tokenize() }

                                // Result will be sent via onTokenized callback
                                // Send success to acknowledge the call
                                withContext(Dispatchers.Main) {
                                        result.success(mapOf("status" to "processing"))
                                }
                        } catch (e: Exception) {
                                Log.e("CardPlatformView", "Tokenization error: ${e.message}", e)
                                withContext(Dispatchers.Main) {
                                        result.error(
                                                "TOKEN_ERROR",
                                                e.message ?: "Tokenization failed",
                                                null
                                        )
                                }
                        }
                }
        }

        fun getSessionData(result: MethodChannel.Result) {
                Log.d("CardPlatformView", "getSessionData called - checking initialization...")
                Log.d("CardPlatformView", "isInitialized: $isInitialized")
                Log.d(
                        "CardPlatformView",
                        "cardComponent initialized: ${::cardComponent.isInitialized}"
                )

                if (!isInitialized || !::cardComponent.isInitialized) {
                        val errorMsg =
                                "Card component not initialized - isInitialized: $isInitialized, cardComponent: ${::cardComponent.isInitialized}"
                        Log.e("CardPlatformView", errorMsg)
                        result.error("CARD_NOT_READY", errorMsg, null)
                        return
                }

                try {
                        Log.d("CardPlatformView", "About to launch coroutine on Main dispatcher...")

                        // Use Main dispatcher and SupervisorJob to ensure coroutine executes
                        CoroutineScope(Dispatchers.Main + SupervisorJob()).launch {
                                Log.d(
                                        "CardPlatformView",
                                        "✅ Coroutine started on thread: ${Thread.currentThread().name}"
                                )

                                try {
                                        Log.d(
                                                "CardPlatformView",
                                                "Starting session data submission..."
                                        )

                                        // Submit session data on background thread
                                        withContext(Dispatchers.Default) {
                                                Log.d(
                                                        "CardPlatformView",
                                                        "Calling cardComponent.submit() on thread: ${Thread.currentThread().name}..."
                                                )
                                                try {
                                                        cardComponent.submit()
                                                        Log.d(
                                                                "CardPlatformView",
                                                                "✅ cardComponent.submit() completed successfully"
                                                        )
                                                        true
                                                } catch (e: Exception) {
                                                        Log.e(
                                                                "CardPlatformView",
                                                                "❌ cardComponent.submit() threw exception: ${e.message}",
                                                                e
                                                        )
                                                        throw e
                                                }
                                        }

                                        // Result will be sent via handleSubmit callback
                                        // Send success to acknowledge the call
                                        withContext(Dispatchers.Main) {
                                                Log.d(
                                                        "CardPlatformView",
                                                        "Sending 'processing' status to Flutter"
                                                )
                                                result.success(mapOf("status" to "processing"))
                                        }
                                } catch (e: Exception) {
                                        Log.e(
                                                "CardPlatformView",
                                                "❌ Session data submission error: ${e.message}",
                                                e
                                        )
                                        withContext(Dispatchers.Main) {
                                                result.error(
                                                        "SESSION_DATA_ERROR",
                                                        e.message
                                                                ?: "Session data submission failed",
                                                        null
                                                )
                                        }
                                }
                        }

                        Log.d("CardPlatformView", "Coroutine launched successfully")
                } catch (e: Exception) {
                        Log.e("CardPlatformView", "Failed to launch coroutine: ${e.message}", e)
                        result.error(
                                "LAUNCH_ERROR",
                                e.message ?: "Failed to launch coroutine",
                                null
                        )
                }
        }

        // ==================== CALLBACK METHODS (Send to Flutter) ====================

        /* Send card tokenized event to Flutter */
        private fun sendCardTokenized(tokenData: Any?) {
                runOnMainThread {
                        try {
                                // Convert TokenDetails to Map using model class
                                val tokenDetailsMap =
                                        when (tokenData) {
                                                is com.checkout.components.interfaces.model.TokenDetails -> {
                                                        com.example.flow_flutter_new.models
                                                                .TokenDetailsModel.fromTokenDetails(
                                                                        tokenData
                                                                )
                                                                .toMap()
                                                }
                                                else -> {
                                                        Log.w(
                                                                "CardPlatformView",
                                                                "Unknown token data type: ${tokenData?.javaClass}"
                                                        )
                                                        mapOf("raw" to tokenData.toString())
                                                }
                                        }

                                val data = mapOf("tokenDetails" to tokenDetailsMap)
                                channel.invokeMethod("cardTokenized", data)
                                Log.d("CardPlatformView", "Card tokenized event sent to Flutter")
                        } catch (e: Exception) {
                                Log.e(
                                        "CardPlatformView",
                                        "Failed to send tokenized event: ${e.message}",
                                        e
                                )
                        }
                }
        }

        /* Send session data to Flutter for backend submission */
        private fun sendSessionData(sessionData: String) {
                runOnMainThread {
                        try {
                                val data = mapOf("sessionData" to sessionData)

                                channel.invokeMethod("sessionDataReady", data)
                                Log.d("CardPlatformView", "Session data sent ")
                        } catch (e: Exception) {
                                Log.e(
                                        "CardPlatformView",
                                        "Failed to send session data: ${e.message}",
                                        e
                                )
                                // Send error to Flutter
                                sendError(
                                        "SESSION_DATA_ERROR",
                                        e.message ?: "Failed to send session data"
                                )
                        }
                }
        }

        /* Send payment success event to Flutter */
        private fun sendPaymentSuccess(paymentId: String) {
                runOnMainThread {
                        try {
                                channel.invokeMethod("paymentSuccess", paymentId)
                                Log.d("CardPlatformView", "Payment success event sent to Flutter")
                        } catch (e: Exception) {
                                Log.e(
                                        "CardPlatformView",
                                        "Failed to send success event: ${e.message}",
                                        e
                                )
                        }
                }
        }

        /* Send error event to Flutter */
        private fun sendError(code: String, message: String) {
                runOnMainThread {
                        try {
                                val error = mapOf("code" to code, "message" to message)
                                channel.invokeMethod("paymentError", error)
                                Log.d(
                                        "CardPlatformView",
                                        "Error event sent to Flutter: $code - $message"
                                )
                        } catch (e: Exception) {
                                Log.e(
                                        "CardPlatformView",
                                        "Failed to send error event: ${e.message}",
                                        e
                                )
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

        override fun getView(): FrameLayout = container

        override fun dispose() {
                scope.cancel()
                Log.d("CardPlatformView", "Card component disposed")
        }
}
