package com.harshRajpurohit.blu_mat

import android.Manifest
import android.bluetooth.*
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat

class A2dpManager(private val context: Context) {

    private var bluetoothA2dp: BluetoothA2dp? = null
    private val bluetoothAdapter: BluetoothAdapter? =
        BluetoothAdapter.getDefaultAdapter()
    private var lastConnectedAddress: String? = null

    private var isReady = false

    private val serviceListener = object : BluetoothProfile.ServiceListener {

        override fun onServiceConnected(profile: Int, proxy: BluetoothProfile?) {
            if (profile == BluetoothProfile.A2DP) {
                bluetoothA2dp = proxy as BluetoothA2dp
                isReady = true
                Log.d("A2DP", "A2DP service connected & ready")
            }
        }

        override fun onServiceDisconnected(profile: Int) {
            if (profile == BluetoothProfile.A2DP) {
                bluetoothA2dp = null
                isReady = false
                Log.d("A2DP", "A2DP service disconnected")
            }
        }
    }

    fun init() {
        bluetoothAdapter?.getProfileProxy(
            context,
            serviceListener,
            BluetoothProfile.A2DP
        )
    }

    fun scanDevices(): List<Map<String, String>> {
    val results = mutableListOf<Map<String, String>>()

    if (!hasPermission()) return results

    val bondedDevices = bluetoothAdapter?.bondedDevices ?: return results

    for (device in bondedDevices) {
        results.add(
            mapOf(
                "name" to (device.name ?: "Unknown"),
                "address" to device.address
            )
        )
    }

    return results
}

    fun connect(deviceAddress: String): Boolean {
        if (!isReady || bluetoothA2dp == null) {
            Log.e("A2DP", "A2DP not ready yet")
            return false
        }

        if (!hasPermission()) return false
        
        val device = bluetoothAdapter?.getRemoteDevice(deviceAddress) ?: return false

        val result = invokeHiddenMethod("connect", device)
        if (result) {
            lastConnectedAddress = deviceAddress
        }
        return result
    }

    fun disconnect(deviceAddress: String): Boolean {
        if (!isReady || bluetoothA2dp == null) return false
        if (!hasPermission()) return false

        val device = bluetoothAdapter?.getRemoteDevice(deviceAddress)
            ?: return false

        return invokeHiddenMethod("disconnect", device)
    }

    fun disconnectLast(): Boolean {
        val address = lastConnectedAddress ?: return false
        return disconnect(address)
    }

    private fun invokeHiddenMethod(
        methodName: String,
        device: BluetoothDevice
    ): Boolean {
        return try {
            val method = BluetoothA2dp::class.java.getDeclaredMethod(
                methodName,
                BluetoothDevice::class.java
            )
            method.isAccessible = true
            method.invoke(bluetoothA2dp, device) as Boolean
        } catch (e: Exception) {
            Log.e("A2DP", "Reflection failed: ${e.message}")
            false
        }
    }

    private fun hasPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.BLUETOOTH_CONNECT
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    fun release() {
        bluetoothAdapter?.closeProfileProxy(
            BluetoothProfile.A2DP,
            bluetoothA2dp
        )
        bluetoothA2dp = null
        isReady = false
    }
}