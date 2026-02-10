package com.nxg.openclawproot

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.nxg.openclawproot/native"
    private val EVENT_CHANNEL = "com.nxg.openclawproot/gateway_logs"

    private lateinit var bootstrapManager: BootstrapManager
    private lateinit var processManager: ProcessManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val filesDir = applicationContext.filesDir.absolutePath
        val nativeLibDir = applicationContext.applicationInfo.nativeLibraryDir

        bootstrapManager = BootstrapManager(applicationContext, filesDir, nativeLibDir)
        processManager = ProcessManager(filesDir, nativeLibDir)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getProotPath" -> {
                    result.success(processManager.getProotPath())
                }
                "getArch" -> {
                    result.success(ArchUtils.getArch())
                }
                "getFilesDir" -> {
                    result.success(filesDir)
                }
                "getNativeLibDir" -> {
                    result.success(nativeLibDir)
                }
                "isBootstrapComplete" -> {
                    result.success(bootstrapManager.isBootstrapComplete())
                }
                "getBootstrapStatus" -> {
                    result.success(bootstrapManager.getBootstrapStatus())
                }
                "extractRootfs" -> {
                    val tarPath = call.argument<String>("tarPath")
                    if (tarPath != null) {
                        Thread {
                            try {
                                bootstrapManager.extractRootfs(tarPath)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("EXTRACT_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "tarPath required", null)
                    }
                }
                "runInProot" -> {
                    val command = call.argument<String>("command")
                    val timeout = call.argument<Int>("timeout")?.toLong() ?: 900L
                    if (command != null) {
                        Thread {
                            try {
                                val output = processManager.runInProotSync(command, timeout)
                                runOnUiThread { result.success(output) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("PROOT_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "command required", null)
                    }
                }
                "startGateway" -> {
                    try {
                        GatewayService.start(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "stopGateway" -> {
                    try {
                        GatewayService.stop(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "isGatewayRunning" -> {
                    result.success(GatewayService.isRunning)
                }
                "startTerminalService" -> {
                    try {
                        TerminalSessionService.start(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "stopTerminalService" -> {
                    try {
                        TerminalSessionService.stop(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "isTerminalServiceRunning" -> {
                    result.success(TerminalSessionService.isRunning)
                }
                "requestBatteryOptimization" -> {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:${packageName}")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BATTERY_ERROR", e.message, null)
                    }
                }
                "isBatteryOptimized" -> {
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(!pm.isIgnoringBatteryOptimizations(packageName))
                }
                "setupDirs" -> {
                    Thread {
                        try {
                            bootstrapManager.setupDirectories()
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SETUP_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "installBionicBypass" -> {
                    Thread {
                        try {
                            bootstrapManager.installBionicBypass()
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("BYPASS_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "writeResolv" -> {
                    Thread {
                        try {
                            bootstrapManager.writeResolvConf()
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("RESOLV_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "extractDebPackages" -> {
                    Thread {
                        try {
                            val count = bootstrapManager.extractDebPackages()
                            runOnUiThread { result.success(count) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("DEB_EXTRACT_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "extractNodeTarball" -> {
                    val tarPath = call.argument<String>("tarPath")
                    if (tarPath != null) {
                        Thread {
                            try {
                                bootstrapManager.extractNodeTarball(tarPath)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("NODE_EXTRACT_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "tarPath required", null)
                    }
                }
                "createBinWrappers" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        Thread {
                            try {
                                bootstrapManager.createBinWrappers(packageName)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("BIN_WRAPPER_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "packageName required", null)
                    }
                }
                "startSetupService" -> {
                    try {
                        SetupService.start(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "updateSetupNotification" -> {
                    val text = call.argument<String>("text")
                    val progress = call.argument<Int>("progress") ?: -1
                    if (text != null) {
                        SetupService.updateNotification(text, progress)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "text required", null)
                    }
                }
                "stopSetupService" -> {
                    try {
                        SetupService.stop(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "showUrlNotification" -> {
                    val url = call.argument<String>("url")
                    val title = call.argument<String>("title") ?: "URL Detected"
                    if (url != null) {
                        showUrlNotification(url, title)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "url required", null)
                    }
                }
                "copyToClipboard" -> {
                    val text = call.argument<String>("text")
                    if (text != null) {
                        val clipboard = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
                        clipboard.setPrimaryClip(ClipData.newPlainText("URL", text))
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "text required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        createUrlNotificationChannel()

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    GatewayService.logSink = events
                }
                override fun onCancel(arguments: Any?) {
                    GatewayService.logSink = null
                }
            }
        )
    }

    private fun createUrlNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                URL_CHANNEL_ID,
                "OpenClaw URLs",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for detected URLs"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private var urlNotificationId = 100

    private fun showUrlNotification(url: String, title: String) {
        val openIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        val openPending = PendingIntent.getActivity(
            this, urlNotificationId, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, URL_CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(url)
                .setSmallIcon(android.R.drawable.ic_menu_share)
                .setContentIntent(openPending)
                .setAutoCancel(true)
                .setStyle(Notification.BigTextStyle().bigText(url))
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle(title)
                .setContentText(url)
                .setSmallIcon(android.R.drawable.ic_menu_share)
                .setContentIntent(openPending)
                .setAutoCancel(true)
                .build()
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(urlNotificationId++, notification)
    }

    companion object {
        const val URL_CHANNEL_ID = "openclaw_urls"
    }
}
