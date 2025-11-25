package com.example.flow_flutter_new.views

import android.content.Context
import android.util.Log
import androidx.activity.ComponentActivity
import com.example.flow_flutter_new.GooglePayPlatformView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Factory for creating GooglePayPlatformView instances
 *
 * Production-ready factory with proper error handling and logging. Provides callback to capture
 * view instance for method channel operations.
 */
class GooglePayViewFactory(
        private val messenger: BinaryMessenger,
        private val activity: ComponentActivity,
        private val onViewCreated: ((GooglePayPlatformView) -> Unit)? = null
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    /**
     * Create a new GooglePayPlatformView instance
     *
     * @param context Android context
     * @param viewId Unique identifier for the platform view
     * @param args Creation arguments from Flutter
     * @return PlatformView instance
     */
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return try {
            Log.d(TAG, "Creating GooglePayPlatformView with ID: $viewId")

            // Validate inputs
            if (viewId < 0) {
                Log.w(TAG, "Invalid view ID: $viewId")
            }

            // Create view instance
            val view = GooglePayPlatformView(activity, args, messenger)

            // Notify callback
            onViewCreated?.invoke(view)

            Log.d(TAG, "GooglePayPlatformView created successfully")
            view
        } catch (e: Exception) {
            Log.e(TAG, "Error creating GooglePayPlatformView", e)
            throw e // Re-throw to let Flutter know creation failed
        }
    }

    companion object {
        private const val TAG = "GooglePayViewFactory"
    }
}
