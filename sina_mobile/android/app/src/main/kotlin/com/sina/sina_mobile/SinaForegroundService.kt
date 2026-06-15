package com.sina.sina_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/// A minimal foreground service that keeps SINA running at foreground priority
/// while detection is active, so the OS does not reclaim the process and the
/// voice loop / GPS / SOS keep working when the app is backgrounded.
///
/// Started/stopped from Dart via the "com.sina.mobility/service" MethodChannel
/// when the camera (detection) turns on/off.
class SinaForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "sina_foreground"
        const val NOTIF_ID = 4242
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SINA active")
            .setContentText("Detecting obstacles and listening for voice commands.")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        // IMPORTANT: only use the CAMERA type. On Android 14+ each declared FGS
        // type requires its runtime permission at startForeground() time; the
        // LOCATION/MICROPHONE types would throw SecurityException (and crash the
        // app) when those permissions aren't granted. Camera permission is
        // always granted by the time detection starts. Wrapped defensively so a
        // failure stops the service instead of crashing the app.
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIF_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA,
                )
            } else {
                startForeground(NOTIF_ID, notification)
            }
        } catch (e: Exception) {
            stopSelf()
        }
        // Don't auto-restart as a zombie if the app process is gone.
        return START_NOT_STICKY
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SINA background",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps SINA running while detecting obstacles."
            }
            val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            mgr.createNotificationChannel(channel)
        }
    }
}
