package com.checkout.flutter.views

import android.content.Context
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import com.checkout.flutter.CardPlatformView
import android.app.Activity
import com.checkout.flutter.FlowPlatformView
import io.flutter.plugin.common.StandardMessageCodec

class FlowViewFactory(
    private val messenger: BinaryMessenger,
    private val activity: Activity // 🔥 Add the real Activity
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return FlowPlatformView(activity, args, messenger)
    }
}
