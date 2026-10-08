package com.chequea.chequea_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chequea/install")
            .setMethodCallHandler { call, result ->
                if (call.method != "marker") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val info = packageManager.getPackageInfo(packageName, 0)
                result.success("${info.firstInstallTime}:${info.lastUpdateTime}")
            }
    }
}
