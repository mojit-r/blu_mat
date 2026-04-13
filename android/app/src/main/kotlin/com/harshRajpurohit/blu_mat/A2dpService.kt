package com.harshRajpurohit.blu_mat

import android.app.Service
import android.content.Intent
import android.os.IBinder

class A2dpService : Service() {

    private lateinit var a2dpManager: A2dpManager

    override fun onCreate() {
        super.onCreate()
        a2dpManager = A2dpManager(this)
        a2dpManager.init()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        a2dpManager.disconnectLast()
        stopSelf()
    }

    override fun onDestroy() {
        a2dpManager.release()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}