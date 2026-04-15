package com.harshRajpurohit.blu_mat

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import io.flutter.plugin.common.EventChannel

class BleManager(private val context: Context) {
    private var eventSink: EventChannel.EventSink? = null
    private val bluetoothAdapter: BluetoothAdapter = BluetoothAdapter.getDefaultAdapter()

    private val scanner: BluetoothLeScanner? = bluetoothAdapter.bluetoothLeScanner
    private val discoveredDevices = mutableSetOf<String>()

    private var gatt: BluetoothGatt? = null


    fun init() {
        // future use if needed
    }

    private fun sendEvent(data: Map<String, Any?>) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            eventSink?.success(data)
        }
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device
            val address = device.address
            if (discoveredDevices.contains(address)) return

            discoveredDevices.add(address)

            sendEvent(
                mapOf(
                    "type" to "BLE_SCAN",
                    "name" to (device.name ?: "Unknown"),
                    "id" to address
                )
            )
        }
    }

    fun startScan() {
        discoveredDevices.clear()
        scanner?.startScan(scanCallback)
    }

    fun stopScan() {
        scanner?.stopScan(scanCallback)
    }

    fun connect(deviceId: String) {
        stopScan()
        val device = bluetoothAdapter.getRemoteDevice(deviceId)
        sendEvent(
            mapOf(
                "type" to "BLE_CONNECTION",
                "state" to "CONNECTING",
                "id" to deviceId
            )
        )
        gatt = device.connectGatt(context, false, gattCallback)
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(
            gatt: BluetoothGatt,
            status: Int,
            newState: Int
        ) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                sendEvent(
                    mapOf(
                        "type" to "BLE_CONNECTION",
                        "state" to "CONNECTED",
                        "id" to gatt.device.address
                    )
                )
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                sendEvent(
                    mapOf(
                        "type" to "BLE_CONNECTION",
                        "state" to "DISCONNECTED",
                        "id" to gatt.device.address
                    )
                )
            }
        }
    }

    fun disconnect() {
        if (gatt == null) return
        val deviceAddress = gatt?.device?.address
        sendEvent(
            mapOf(
                "type" to "BLE_CONNECTION",
                "state" to "DISCONNECTING",
                "id" to deviceAddress
            )
        )
        try {
            gatt?.disconnect()
            gatt?.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        gatt = null
    }

    fun release() {
        stopScan()
        disconnect()
    }
}