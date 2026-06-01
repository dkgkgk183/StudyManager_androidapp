package com.example.study_manager

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.study_manager/study_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val subjectName = call.argument<String>("subjectName") ?: ""
                    val intent = Intent(this, StudyForegroundService::class.java).apply {
                        action = StudyForegroundService.ACTION_START
                        putExtra(StudyForegroundService.EXTRA_SUBJECT, subjectName)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
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
                else -> result.notImplemented()
            }
        }
    }
}
