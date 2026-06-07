package com.example.study_manager

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.study_manager/study_service"
    private val CALL_STATE_CHANNEL = "com.example.study_manager/call_state"
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var callStateJob: Job? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        val subjectName = call.argument<String>("subjectName") ?: ""
                        val intent = Intent(this, StudyForegroundService::class.java).apply {
                            action = StudyForegroundService.ACTION_START
                            putExtra(StudyForegroundService.EXTRA_SUBJECT, subjectName)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
                        else startService(intent)
                        result.success(null)
                    }
                    "stopService" -> {
                        val intent = Intent(this, StudyForegroundService::class.java).apply {
                            action = StudyForegroundService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(null)
                    }
                    "updateTime" -> {
                        val seconds = call.argument<Int>("seconds") ?: 0
                        val intent = Intent(this, StudyForegroundService::class.java).apply {
                            action = StudyForegroundService.ACTION_UPDATE
                            putExtra(StudyForegroundService.EXTRA_SECONDS, seconds)
                        }
                        startService(intent)
                        result.success(null)
                    }
                    "startSensor" -> {
                        val intent = Intent(this, StudyForegroundService::class.java).apply {
                            action = StudyForegroundService.ACTION_START_SENSOR
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
                        else startService(intent)
                        result.success(null)
                    }
                    "stopSensor" -> {
                        val intent = Intent(this, StudyForegroundService::class.java).apply {
                            action = StudyForegroundService.ACTION_STOP_SENSOR
                        }
                        startService(intent)
                        result.success(null)
                    }
                    "getAccelZ" -> {
                        val prefs = getSharedPreferences(
                            StudyForegroundService.PREFS_NAME, Context.MODE_PRIVATE
                        )
                        result.success(prefs.getFloat(StudyForegroundService.KEY_ACCEL_Z, 0f).toDouble())
                    }
                    "isKeyguardLocked" -> {
                        val km = getSystemService(Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
                        result.success(km.isKeyguardLocked)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_STATE_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    callStateJob?.cancel()
                    callStateJob = scope.launch {
                        CallStateBridge.flow.collect { state -> events.success(state) }
                    }
                }
                override fun onCancel(arguments: Any?) {
                    callStateJob?.cancel()
                    callStateJob = null
                }
            })
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        callStateJob?.cancel()
        callStateJob = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
