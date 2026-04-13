package com.harshRajpurohit.blu_mat

import android.content.Intent
import android.view.Menu
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "a2dp_channel"
    private lateinit var a2dpManager: A2dpManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        a2dpManager = A2dpManager(this)
        a2dpManager.init()

        // A2DP channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "scanClassic" -> {
                    val devices = a2dpManager.scanDevices()
                    result.success(devices)
                }

                "connectA2dp" -> {
                    val address = call.argument<String>("address")
                    if (address == null) {
                        result.error("INVALID_ARGS", "Address missing", null)
                        return@setMethodCallHandler
                    }
                    val success = a2dpManager.connect(address)

                    if (success) {
                        startService(
                            Intent(this, A2dpService::class.java)
                        )
                    }
                    result.success(success)
                }

                "disconnectA2dp" -> {
                    val address = call.argument<String>("address")
                    if (address == null) {
                        result.error("INVALID_ARGS", "Address missing",null)
                        return@setMethodCallHandler
                    }
                    val success = a2dpManager.disconnect(address)

                    if (success) {
                        stopService(Intent(this, A2dpService::class.java))  
                    }
                    result.success(success)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        a2dpManager.release()
    }
}