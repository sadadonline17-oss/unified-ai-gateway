package com.sadadonline17.cloudai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import io.flutter.plugin.common.EventChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.File

class GatewayService : Service() {
    companion object {
        const val CHANNEL_ID = "unified_ai_gateway"
        const val NOTIFICATION_ID = 1
        var isRunning = false
            private set
        var logSink: EventChannel.EventSink? = null
        private var instance: GatewayService? = null

        fun start(context: Context) {
            val intent = Intent(context, GatewayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, GatewayService::class.java)
            context.stopService(intent)
        }
    }

    private var gatewayProcess: Process? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var restartCount = 0
    private val maxRestarts = 3
    private var startTime: Long = 0
    private var uptimeThread: Thread? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification("Starting..."))
        acquireWakeLock()
        startGateway()
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        instance = null
        uptimeThread?.interrupt()
        uptimeThread = null
        stopGateway()
        releaseWakeLock()
        super.onDestroy()
    }

    private fun startGateway() {
        isRunning = true
        instance = this
        startTime = System.currentTimeMillis()

        Thread {
            try {
                val filesDir = applicationContext.filesDir.absolutePath
                val gatewayDir = File(filesDir, "unified-gateway")

                // Copy gateway files from assets if needed
                if (!File(gatewayDir, "lib/index.js").exists()) {
                    emitLog("Copying unified-gateway files from assets...")
                    copyAssetsToDirectory("gateway", gatewayDir)
                }

                // Install dependencies if needed
                val nodeModulesDir = File(gatewayDir, "node_modules")
                if (!nodeModulesDir.exists()) {
                    emitLog("Installing Node.js dependencies...")
                    val pm = ProcessManager(filesDir, applicationContext.applicationInfo.nativeLibraryDir)
                    val installProcess = pm.startProotProcess("cd $gatewayDir && npm install --production")
                    installProcess.waitFor()
                }

                // Start the unified gateway
                val pm = ProcessManager(filesDir, applicationContext.applicationInfo.nativeLibraryDir)
                gatewayProcess = pm.startProotProcess("cd $gatewayDir && export NODE_OPTIONS='--require /root/.openclaw/bionic-bypass.js' && node lib/index.js")

                updateNotificationRunning()
                emitLog("Unified AI Gateway started on port 18789")
                startUptimeTicker()

                // Read stdout
                val stdoutReader = BufferedReader(InputStreamReader(gatewayProcess!!.inputStream))
                Thread {
                    try {
                        var line: String?
                        while (stdoutReader.readLine().also { line = it } != null) {
                            val l = line ?: continue
                            emitLog(l)
                        }
                    } catch (_: Exception) {}
                }.start()

                // Read stderr
                val stderrReader = BufferedReader(InputStreamReader(gatewayProcess!!.errorStream))
                Thread {
                    try {
                        var line: String?
                        while (stderrReader.readLine().also { line = it } != null) {
                            val l = line ?: continue
                            if (!l.contains("proot warning") && !l.contains("can't sanitize")) {
                                emitLog("[ERR] $l")
                            }
                        }
                    } catch (_: Exception) {}
                }.start()

                val exitCode = gatewayProcess!!.waitFor()
                emitLog("Gateway exited with code $exitCode")

                if (isRunning && restartCount < maxRestarts) {
                    restartCount++
                    val delayMs = 2000L * (1 shl (restartCount - 1))
                    emitLog("Auto-restarting in ${delayMs / 1000}s (attempt $restartCount/$maxRestarts)...")
                    updateNotification("Restarting in ${delayMs / 1000}s (attempt $restartCount)...")
                    Thread.sleep(delayMs)
                    startGateway()
                } else if (restartCount >= maxRestarts) {
                    emitLog("Max restarts reached. Gateway stopped.")
                    updateNotification("Gateway stopped (crashed)")
                    isRunning = false
                }
            } catch (e: Exception) {
                emitLog("Gateway error: ${e.message}")
                isRunning = false
                updateNotification("Gateway error")
            }
        }.start()
    }

    private fun copyAssetsToDirectory(assetPath: String, targetDir: File) {
        try {
            if (!targetDir.exists()) {
                targetDir.mkdirs()
            }

            val assetManager = applicationContext.assets
            val files = assetManager.list(assetPath) ?: return

            for (file in files) {
                val subPath = if (assetPath.isEmpty()) file else "$assetPath/$file"
                val targetFile = File(targetDir, file)

                try {
                    val subFiles = assetManager.list(subPath)
                    if (subFiles != null && subFiles.isNotEmpty()) {
                        copyAssetsToDirectory(subPath, targetFile)
                    } else {
                        assetManager.open(subPath).use { input ->
                            targetFile.outputStream().use { output ->
                                input.copyTo(output)
                            }
                        }
                    }
                } catch (e: Exception) {
                    // Skip directories that can't be listed
                    assetManager.open(subPath).use { input ->
                        targetFile.outputStream().use { output ->
                            input.copyTo(output)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            emitLog("Error copying assets: ${e.message}")
        }
    }

    private fun stopGateway() {
        restartCount = maxRestarts // Prevent auto-restart
        uptimeThread?.interrupt()
        uptimeThread = null
        gatewayProcess?.let {
            it.destroyForcibly()
            gatewayProcess = null
        }
        emitLog("Gateway stopped by user")
    }

    private fun startUptimeTicker() {
        uptimeThread?.interrupt()
        uptimeThread = Thread {
            try {
                while (!Thread.interrupted() && isRunning) {
                    Thread.sleep(60_000) // Update every minute
                    if (isRunning) {
                        updateNotificationRunning()
                    }
                }
            } catch (_: InterruptedException) {}
        }.apply { isDaemon = true; start() }
    }

    private fun formatUptime(): String {
        val elapsed = System.currentTimeMillis() - startTime
        val seconds = elapsed / 1000
        val minutes = seconds / 60
        val hours = minutes / 60
        return when {
            hours > 0 -> "${hours}h ${minutes % 60}m"
            minutes > 0 -> "${minutes}m"
            else -> "${seconds}s"
        }
    }

    private fun updateNotificationRunning() {
        updateNotification("Running on port 18789 \u2022 ${formatUptime()}")
    }

    private fun emitLog(message: String) {
        try {
            logSink?.success(message)
        } catch (_: Exception) {}
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "UnifiedAI::GatewayWakeLock"
        )
        wakeLock?.acquire(24 * 60 * 60 * 1000L) // 24 hours max
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Unified AI Gateway",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the Unified AI Gateway running in the background"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder.setContentTitle("Unified AI Gateway")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(pendingIntent)
            .setOngoing(true)

        // Show elapsed time chronometer when running
        if (isRunning && startTime > 0) {
            builder.setWhen(startTime)
            builder.setShowWhen(true)
            builder.setUsesChronometer(true)
        }

        return builder.build()
    }

    private fun updateNotification(text: String) {
        try {
            val manager = getSystemService(NotificationManager::class.java)
            manager.notify(NOTIFICATION_ID, buildNotification(text))
        } catch (_: Exception) {}
    }
}
