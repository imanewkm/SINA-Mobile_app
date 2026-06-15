package com.sina.sina_mobile

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// - Detects a triple-press of volume-down (within 1.5s) and notifies Flutter to
///   fire an SOS. The key event is still passed through, so volume keeps working.
/// - Starts/stops the foreground service on request from Flutter.
class MainActivity : FlutterActivity() {
    private val sosChannelName = "com.sina.mobility/sos"
    private val serviceChannelName = "com.sina.mobility/service"
    private val depthChannelName = "com.sina.mobility/depth"
    private val smsChannelName = "com.sina.mobility/sms"
    private val callChannelName = "com.sina.mobility/call"
    private var sosChannel: MethodChannel? = null
    private val pressTimes = ArrayDeque<Long>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        sosChannel = MethodChannel(messenger, sosChannelName)

        MethodChannel(messenger, serviceChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val intent = Intent(this, SinaForegroundService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stop" -> {
                    stopService(Intent(this, SinaForegroundService::class.java))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Autonomous SOS SMS. Sends directly via SmsManager (no app switch, no
        // internet) so a blind user never has to tap "send". SEND_SMS runtime
        // permission is requested from Dart before this is called.
        MethodChannel(messenger, smsChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "send" -> {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")
                    if (phone.isNullOrBlank() || message.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val sms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            getSystemService(SmsManager::class.java)
                        } else {
                            @Suppress("DEPRECATION") SmsManager.getDefault()
                        }
                        val parts = sms.divideMessage(message)
                        if (parts.size > 1) {
                            sms.sendMultipartTextMessage(phone, null, parts, null, null)
                        } else {
                            sms.sendTextMessage(phone, null, message, null, null)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Autonomous phone call (ACTION_CALL, not the dialer) so a successful SOS
        // can ring the contact directly to make sure they notice. Requires
        // CALL_PHONE, requested from Dart; falls back to the dialer on failure.
        MethodChannel(messenger, callChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "call" -> {
                    val phone = call.argument<String>("phone")
                    if (phone.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$phone"))
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Depth provider hook. Returns "unavailable" until an ARCore depth
        // session is wired up — see docs/arcore_depth.md for the full approach.
        MethodChannel(messenger, depthChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(false)
                "queryDepth" -> result.success(emptyList<Double>())
                else -> result.notImplemented()
            }
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            val now = System.currentTimeMillis()
            pressTimes.addLast(now)
            while (pressTimes.isNotEmpty() && now - pressTimes.first() > 1500L) {
                pressTimes.removeFirst()
            }
            if (pressTimes.size >= 3) {
                pressTimes.clear()
                sosChannel?.invokeMethod("sos", null)
            }
        }
        return super.onKeyDown(keyCode, event)
    }
}
