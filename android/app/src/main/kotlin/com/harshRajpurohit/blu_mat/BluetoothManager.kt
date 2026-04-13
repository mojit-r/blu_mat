package com.harshRajpurohit.blu_mat

import android.content.Context
import io.flutter.plugin.common.EventChannel

class BluetoothManager(private val context: Context) {
    private var eventSink: EventChannel.EventSink? = null

    // private val bleManager = BleManager(context, eventSink)
    private val a2dpManager = A2dpManager(context, eventSink)

    init {
        a2dpManager.init()
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        a2dpManager.setEventSink(sink)
    }

    // fun scanBle() = bleManager.startScan()
    // fun stopBleScan() = bleManager.stopScan()

    // fun connectBle(deviceId: String) = bleManager.connect(deviceId)
    // fun disconnectBle() = bleManager.disconnect()

    fun scanA2dp() = a2dpManager.scanDevices()
    fun connectA2dp(address: String) = a2dpManager.connect(address)
    fun disconnectA2dp(address: String) = a2dpManager.disconnect(address)

    fun release() {
        a2dpManager.release()
        // bleManager.release()
    }
}