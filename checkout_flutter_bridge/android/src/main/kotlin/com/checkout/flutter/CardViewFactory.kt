package com.checkout.flutter.views

import android.app.Activity
import android.content.Context
import com.checkout.flutter.CardPlatformView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Factory for creating CardPlatformView instances Provides callback to capture view instance for
 * method channel operations
 */
class CardViewFactory(
        private val messenger: BinaryMessenger,
        private val activity: Activity,
        private val onViewCreated: ((CardPlatformView) -> Unit)? = null
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val view = CardPlatformView(activity, args, messenger)
        onViewCreated?.invoke(view)
        return view
    }
}
