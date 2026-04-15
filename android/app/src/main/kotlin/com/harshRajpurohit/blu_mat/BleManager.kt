package com.harshRajpurohit.blu_mat

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Build
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
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
        if (!bluetoothAdapter.isEnabled) {
            sendEvent(mapOf("type" to "ERROR", "message" to "Bluetooth is OFF"))
            return
        }
        if (!hasBleScanPermission()) {
            sendEvent(mapOf("type" to "ERROR", "message" to "BLE scan permission missing"))
            return
        }
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY) // 🔥 IMPORTANT
            .build()
        discoveredDevices.clear()
        scanner?.startScan(null, settings, scanCallback)
        sendEvent(mapOf("type" to "BLE_STATUS", "state" to "SCAN_STARTED"))
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

    private fun hasBleScanPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.BLUETOOTH_SCAN
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        }
    }

    fun release() {
        stopScan()
        disconnect()
    }
}