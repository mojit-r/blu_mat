package com.harshRajpurohit.blu_mat

import android.content.Intent
import android.view.Menu
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "a2dp_channel"
    private val EVENT_CHANNEL = "bluetooth_events"

    private lateinit var bluetoothManager: BluetoothManager
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        bluetoothManager = BluetoothManager(this)

        // A2DP channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "scanClassic" -> {
                    val devices = bluetoothManager.scanA2dp()
                    result.success(devices)
                }

                "connectA2dp" -> {
                    val address = call.argument<String>("address")
                    if (address == null) {
                        result.error("INVALID_ARGS", "Address missing", null)
                        return@setMethodCallHandler
                    }
                    val success = bluetoothManager.connectA2dp(address)

                    // if (success) {
                    //     startService(Intent(this, A2dpService::class.java))
                    // }
                    result.success(success)
                }

                "disconnectA2dp" -> {
                    val address = call.argument<String>("address")
                    if (address == null) {
                        result.error("INVALID_ARGS", "Address missing",null)
                        return@setMethodCallHandler
                    }
                    val success = bluetoothManager.disconnectA2dp(address)

                    // if (success) {
                    //     stopService(Intent(this, A2dpService::class.java))  
                    // }
                    result.success(success)
                }

                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        .setStreamHandler(object : EventChannel.StreamHandler {

            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                bluetoothManager.setEventSink(sink)
            }

            override fun onCancel(arguments: Any?) {
                bluetoothManager.setEventSink(null)
            }
        })
    }
    
    override fun onDestroy() {
        super.onDestroy()
        bluetoothManager.release()
    }
}