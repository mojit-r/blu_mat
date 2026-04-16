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

    private val scanner: BluetoothLeScanner? get() = bluetoothAdapter.bluetoothLeScanner
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
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        discoveredDevices.clear()
        scanner?.startScan(null, settings, scanCallback)
        sendEvent(mapOf("type" to "BLE_STATUS", "state" to "SCAN_STARTED"))
    }

    fun stopScan() {
        try {
            scanner?.stopScan(scanCallback)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun connect(deviceId: String) {
        stopScan()
        closeGattProperly()

        val device = bluetoothAdapter.getRemoteDevice(deviceId)
        sendEvent(mapOf(
                "type" to "BLE_CONNECTION",
                "state" to "CONNECTING",
                "id" to deviceId
            )
        )
        gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
        } else {
            device.connectGatt(context, false, gattCallback)
        }
    }

    private fun closeGattProperly() {
        gatt?.let { g ->
            try { g.disconnect() } catch (e: Exception) { e.printStackTrace() }
            try { g.close() } catch (e: Exception) { e.printStackTrace() }
            gatt = null
        }
    }

    private fun refreshDeviceCache(gatt: BluetoothGatt): Boolean {
        return try {
            val method = gatt.javaClass.getMethod("refresh")
            method.invoke(gatt) as Boolean
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            val deviceId = gatt.device.address

            if (status != BluetoothGatt.GATT_SUCCESS) {
                try { gatt.close() } catch (e: Exception) { e.printStackTrace() }
                this@BleManager.gatt = null
                sendEvent(
                    mapOf(
                        "type" to "BLE_CONNECTION",
                        "state" to "ERROR",
                        "id" to deviceId,
                        "status" to status
                    )
                )
                return
            }
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                refreshDeviceCache(gatt)
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    gatt.discoverServices()
                }, 500)
                sendEvent(
                    mapOf(
                        "type" to "BLE_CONNECTION",
                        "state" to "CONNECTED",
                        "id" to gatt.device.address
                    )
                )
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                try { gatt.close() } catch (e: Exception) { e.printStackTrace() }
                this@BleManager.gatt = null
                sendEvent(
                    mapOf(
                        "type" to "BLE_CONNECTION",
                        "state" to "DISCONNECTED",
                        "id" to gatt.device.address
                    )
                )
            } 
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                sendEvent(mapOf(
                    "type" to "BLE_CONNECTION",
                    "state" to "SERVICES_DISCOVERED",
                    "id" to gatt.device.address
                ))
            }
        }
    }

    fun disconnect() {
        val deviceAddress = gatt?.device?.address
        sendEvent(
            mapOf(
                "type" to "BLE_CONNECTION",
                "state" to "DISCONNECTING",
                "id" to deviceAddress
            )
        )
        closeGattProperly()
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