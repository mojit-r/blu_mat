package com.harshRajpurohit.blu_mat

import android.os.Handler
import android.os.Looper
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Build
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import java.util.UUID
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
            discoveredDevices.clear()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun connect(deviceId: String) {
        closeGattProperly()
        if (!hasBleScanPermission()) {
            sendEvent(mapOf("type" to "ERROR", "message" to "Permission missing"))
            return
        }

        val device = bluetoothAdapter.getRemoteDevice(deviceId)
        sendEvent(mapOf(
                "type" to "BLE_CONNECTION",
                "state" to "CONNECTING",
                "id" to deviceId
            )
        )
        Handler(Looper.getMainLooper()).postDelayed({
            gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
            } else {
                device.connectGatt(context, false, gattCallback)
            }
        }, 300)
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
                    android.util.Log.d("BLE", "Connected. Starting service discovery...")
                    gatt.discoverServices()
                }, 1200)
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
            android.util.Log.d("BLE", "onServicesDiscovered called, status=$status")
            if (status == BluetoothGatt.GATT_SUCCESS) {
                val servicesList = gatt.services.map { service ->
                    mapOf(
                        "uuid" to service.uuid.toString(),
                        "characteristics" to service.characteristics.map { char ->
                            mapOf(
                                "uuid" to char.uuid.toString(),
                                "properties" to char.properties
                            )
                        }
                    )
                }
                Handler(Looper.getMainLooper()).postDelayed({
                    sendEvent(
                        mapOf(
                            "type" to "BLE_SERVICES",
                            "services" to servicesList
                        )
                    )
                }, 600)
            }
        }

        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                sendEvent(
                    mapOf(
                        "type" to "BLE_READ",
                        "uuid" to characteristic.uuid.toString(),
                        "value" to characteristic.value
                    )
                )
            }
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            android.util.Log.d("BLE_WRITE", "Written: ${characteristic.value?.toList()}")
            sendEvent(
                mapOf(
                    "type" to "BLE_WRITE",
                    "uuid" to characteristic.uuid.toString(),
                    "status" to if (status == BluetoothGatt.GATT_SUCCESS) "SUCCESS" else "FAILED",
                    "code" to status
                )
            )
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            sendEvent(
                mapOf(
                    "type" to "BLE_NOTIFY",
                    "uuid" to characteristic.uuid.toString(),
                    "value" to characteristic.value // "value" to characteristic.value?.toList()
                )
            )
        }

        override fun onDescriptorWrite(
            gatt: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            status: Int
        ) {
            sendEvent(
                mapOf(
                    "type" to "NOTIFY_ENABLED",
                    "status" to status
                )
            )
        }
    }

    fun readCharacteristic(serviceUUID: String, charUUID: String) {
        val service = gatt?.getService(UUID.fromString(serviceUUID))
        val characteristic = service?.getCharacteristic(UUID.fromString(charUUID))

        if (characteristic != null) {
            gatt?.readCharacteristic(characteristic)
        }
    }

    fun writeCharacteristic(
        serviceUUID: String,
        charUUID: String,
        value: ByteArray
    ) {
        if (gatt == null) {
            sendEvent(mapOf("type" to "ERROR", "message" to "Not connected to device"))
            return
        }
        val service = gatt?.getService(UUID.fromString(serviceUUID))
        val characteristic = service?.getCharacteristic(UUID.fromString(charUUID))

        if (characteristic == null) {
            sendEvent(
                mapOf(
                    "type" to "ERROR",
                    "message" to "Characteristic not found for write"
                )
            )
            return
        }
        characteristic.value = value

        val props = characteristic.properties
        characteristic.writeType =
            if ((props and BluetoothGattCharacteristic.PROPERTY_WRITE) != 0) {
                BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            } else {
                BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            gatt?.writeCharacteristic(
                characteristic,
                value,
                characteristic.writeType
            )
        } else {
            gatt?.writeCharacteristic(characteristic)
        }

        sendEvent(
            mapOf(
                "type" to "BLE_WRITE_SENT",
                "uuid" to charUUID,
                "value" to value.toList()
            )
        )
    } 
    

    fun enableNotifications(serviceUUID: String, charUUID: String) {
        val service = gatt?.getService(UUID.fromString(serviceUUID))
        val characteristic = service?.getCharacteristic(UUID.fromString(charUUID))

        if (characteristic == null) {
            sendEvent(mapOf("type" to "ERROR", "message" to "Characteristic not found"))
            return
        }

        // val props = characteristic.properties
        // if ((props and BluetoothGattCharacteristic.PROPERTY_NOTIFY) == 0 &&
        //     (props and BluetoothGattCharacteristic.PROPERTY_INDICATE) == 0) {
        //     sendEvent(mapOf("type" to "ERROR", "message" to "Characteristic does not support notify/indicate"))
        //     return
        // }

        gatt?.setCharacteristicNotification(characteristic, true)

        sendEvent(mapOf(
            "type" to "NOTIFY_ENABLED",
            "status" to "SUCCESS_MANUAL"
        ))

        // val descriptor = characteristic.getDescriptor(
        //     UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        // )

        // if (descriptor == null) {
        //     android.util.Log.e("BLE", "⚠️ CCCD NOT FOUND, using fallback")
        //     // STILL enable notification locally
        //     gatt?.setCharacteristicNotification(characteristic, true)
        //     // Manually trigger success so Flutter continues
        //     sendEvent(
        //         mapOf(
        //             "type" to "NOTIFY_ENABLED",
        //             "status" to "NO_DESCRIPTOR_FALLBACK"
        //         )
        //     )
        //     return
        // }
        // descriptor.value =
        //     if ((props and BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0) {
        //         BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        //     } else {
        //         BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
        //     }
        // gatt?.writeDescriptor(descriptor)
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