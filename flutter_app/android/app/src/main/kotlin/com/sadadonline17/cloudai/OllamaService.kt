package com.sadadonline17.cloudai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * Foreground service for managing Ollama daemon in proot environment
 */
class OllamaService : Service() {
    
    companion object {
        const val TAG = "OllamaService"
        const val CHANNEL_ID = "ollama_service_channel"
        const val NOTIFICATION_ID = 1002
        
        const val ACTION_START = "com.sadadonline17.cloudai.OLLAMA_START"
        const val ACTION_STOP = "com.sadadonline17.cloudai.OLLAMA_STOP"
        const val ACTION_STATUS = "com.sadadonline17.cloudai.OLLAMA_STATUS"
        
        private var isRunning = false
        private var ollamaProcess: Process? = null
        
        fun isRunning(): Boolean = isRunning
    }
    
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var statusCheckJob: Job? = null
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startOllamaDaemon()
            ACTION_STOP -> stopOllamaDaemon()
            ACTION_STATUS -> checkStatus()
        }
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Ollama AI Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Ollama local LLM inference service"
                setShowBadge(false)
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun startOllamaDaemon() {
        if (isRunning) {
            Log.i(TAG, "Ollama daemon already running")
            return
        }
        
        val notification = createNotification("Starting Ollama daemon...")
        startForeground(NOTIFICATION_ID, notification)
        
        serviceScope.launch {
            try {
                // Start Ollama in proot environment
                val command = """
                    export PROOT_SERVICE=ollama
                    export OLLAMA_HOST=127.0.0.1:11434
                    export OLLAMA_MODELS=/root/.ollama/models
                    cd /root && ollama serve
                """.trimIndent()
                
                val processBuilder = ProcessBuilder()
                    .command("proot-distro", "login", "ubuntu", "--", "/bin/bash", "-c", command)
                    .redirectErrorStream(true)
                
                ollamaProcess = processBuilder.start()
                isRunning = true
                
                // Read output in background
                launch {
                    val reader = BufferedReader(InputStreamReader(ollamaProcess?.inputStream))
                    var line: String?
                    while (reader.readLine().also { line = it } != null) {
                        Log.d(TAG, "Ollama: $line")
                    }
                }
                
                // Wait for Ollama to be ready
                delay(3000)
                
                // Start status checking
                startStatusCheck()
                
                updateNotification("Ollama daemon running")
                Log.i(TAG, "Ollama daemon started successfully")
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start Ollama daemon", e)
                isRunning = false
                updateNotification("Ollama failed: ${e.message}")
            }
        }
    }
    
    private fun stopOllamaDaemon() {
        serviceScope.launch {
            try {
                statusCheckJob?.cancel()
                
                ollamaProcess?.destroy()
                ollamaProcess?.waitFor(5, java.util.concurrent.TimeUnit.SECONDS)
                ollamaProcess = null
                isRunning = false
                
                Log.i(TAG, "Ollama daemon stopped")
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping Ollama daemon", e)
            }
        }
    }
    
    private fun startStatusCheck() {
        statusCheckJob = serviceScope.launch {
            while (isRunning) {
                checkStatus()
                delay(10000) // Check every 10 seconds
            }
        }
    }
    
    private fun checkStatus() {
        serviceScope.launch {
            try {
                val process = ProcessBuilder()
                    .command("curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", 
                             "http://127.0.0.1:11434/api/tags")
                    .start()
                
                process.waitFor(5, java.util.concurrent.TimeUnit.SECONDS)
                val exitCode = process.exitValue()
                
                if (exitCode == 0) {
                    Log.d(TAG, "Ollama health check passed")
                } else {
                    Log.w(TAG, "Ollama health check failed")
                }
            } catch (e: Exception) {
                Log.w(TAG, "Ollama health check error: ${e.message}")
            }
        }
    }
    
    private fun createNotification(message: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Ollama AI Service")
            .setContentText(message)
            .setSmallIcon(R.drawable.ic_notification)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }
    
    private fun updateNotification(message: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notification = createNotification(message)
        manager.notify(NOTIFICATION_ID, notification)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
        ollamaProcess?.destroy()
        isRunning = false
    }
}