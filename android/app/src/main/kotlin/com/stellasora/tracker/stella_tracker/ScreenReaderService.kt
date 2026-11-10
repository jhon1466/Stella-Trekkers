package com.stellasora.tracker.stella_tracker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.SystemClock
import android.util.DisplayMetrics
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.util.concurrent.atomic.AtomicBoolean
import java.util.regex.Pattern

class ScreenReaderService : Service() {
    private var projection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var workerThread: HandlerThread? = null
    private var worker: Handler? = null
    private val processing = AtomicBoolean(false)
    private val recognizer by lazy { TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS) }
    private var startedAt = 0L

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        val resultCode = intent?.getIntExtra(EXTRA_RESULT_CODE, 0) ?: 0
        val resultData = if (Build.VERSION.SDK_INT >= 33) {
            intent?.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent?.getParcelableExtra(EXTRA_RESULT_DATA)
        }
        if (resultCode == 0 || resultData == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        startForegroundCompat()
        startedAt = SystemClock.elapsedRealtime()
        workerThread = HandlerThread("StellaHudOcr").also { it.start() }
        worker = Handler(workerThread!!.looper)
        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        projection = manager.getMediaProjection(resultCode, resultData)
        projection?.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() = stopSelf()
        }, worker)

        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        (getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager)
            .defaultDisplay.getRealMetrics(metrics)
        createCaptureSurface(metrics.widthPixels, metrics.heightPixels, metrics.densityDpi)
        return START_NOT_STICKY
    }

    private fun createCaptureSurface(width: Int, height: Int, densityDpi: Int) {
        imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2).also { reader ->
            reader.setOnImageAvailableListener({ source -> onFrame(source) }, worker)
        }
        virtualDisplay = projection?.createVirtualDisplay(
            "StellaSoraHudReader",
            width,
            height,
            densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface,
            null,
            worker,
        )
    }

    private fun onFrame(source: ImageReader) {
        val image = try {
            source.acquireLatestImage()
        } catch (_: Exception) {
            null
        } ?: return
        if (SystemClock.elapsedRealtime() - startedAt > SCAN_TIMEOUT_MS) {
            image.close()
            showStatus("No se encontró el HUD. Mantén Stella Sora en primer plano e inténtalo otra vez.")
            stopSelf()
            return
        }
        if (!processing.compareAndSet(false, true)) {
            image.close()
            return
        }

        val bitmap = try {
            image.toBitmap()
        } catch (_: Exception) {
            null
        } finally {
            image.close()
        }
        if (bitmap == null) {
            processing.set(false)
            return
        }

        val input = InputImage.fromBitmap(bitmap, 0)
        recognizer.process(input)
            .addOnSuccessListener { result ->
                val parsed = parseEnergy(result.text)
                if (parsed != null && (parsed.fullMinutes != null || parsed.energy >= parsed.maximum)) {
                    saveReading(parsed)
                    showStatus("Energía leída y widget actualizado.")
                    stopSelf()
                }
            }
            .addOnFailureListener { showStatus("Leyendo la pantalla del juego…") }
            .addOnCompleteListener {
                bitmap.recycle()
                processing.set(false)
            }
    }

    private fun saveReading(value: Reading) {
        val minutesToFull = value.fullMinutes ?: 0
        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit()
            .putInt("flutter.account_energy", value.energy)
            .putInt("flutter.account_energy_max", value.maximum)
            .putInt("flutter.account_energy_full_minutes", minutesToFull)
            .putString("flutter.account_energy_source", "Lectura en vivo del HUD")
            .putBoolean("flutter.account_screen_reader_active", false)
            .apply()

        getSharedPreferences("account_widget", Context.MODE_PRIVATE).edit()
            .putInt("energy", value.energy)
            .putInt("maximum", value.maximum)
            .putInt("fullSeconds", minutesToFull * 60)
            .putLong("capturedAtMillis", System.currentTimeMillis())
            .apply()
        EnergyWidget.updateAll(this)
    }

    private fun showStatus(message: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, notification(message))
    }

    private fun startForegroundCompat() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Lectura de energía", NotificationManager.IMPORTANCE_LOW),
            )
        }
        val notification = notification("Abre Stella Sora y deja visible la energía")
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun notification(message: String): Notification {
        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_menu_view)
                .setContentTitle("Stella Sora Companion")
                .setContentText(message)
                .setContentIntent(openApp)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setSmallIcon(android.R.drawable.ic_menu_view)
                .setContentTitle("Stella Sora Companion")
                .setContentText(message)
                .setContentIntent(openApp)
                .setOngoing(true)
                .build()
        }
    }

    override fun onDestroy() {
        try {
            virtualDisplay?.release()
            imageReader?.close()
            projection?.stop()
            recognizer.close()
        } catch (_: Exception) {
        }
        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit()
            .putBoolean("flutter.account_screen_reader_active", false)
            .apply()
        workerThread?.quitSafely()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private data class Reading(val energy: Int, val maximum: Int, val fullMinutes: Int?)

    private fun parseEnergy(text: String): Reading? {
        val normalized = text.lowercase().replace('|', '/')
        val energyMatch = ENERGY_PATTERN.matcher(normalized)
        if (!energyMatch.find()) return null
        val energy = energyMatch.group(1)?.toIntOrNull() ?: return null
        val maximum = energyMatch.group(2)?.toIntOrNull() ?: return null
        if (maximum <= 0 || energy > maximum) return null

        val duration = DURATION_PATTERN.matcher(normalized)
        val clock = CLOCK_PATTERN.matcher(normalized)
        val fullMinutes = when {
            duration.find() -> (duration.group(1)?.toIntOrNull() ?: 0) * 60 +
                (duration.group(2)?.toIntOrNull() ?: 0)
            clock.find() -> (clock.group(1)?.toIntOrNull() ?: 0) * 60 +
                (clock.group(2)?.toIntOrNull() ?: 0)
            energy >= maximum -> 0
            else -> null
        }
        return Reading(energy, maximum, fullMinutes)
    }

    private fun Image.toBitmap(): Bitmap {
        val plane = planes[0]
        val pixelStride = plane.pixelStride
        val rowPixels = plane.rowStride / pixelStride
        val padded = Bitmap.createBitmap(rowPixels, height, Bitmap.Config.ARGB_8888)
        padded.copyPixelsFromBuffer(plane.buffer)
        if (rowPixels == width) return padded
        return Bitmap.createBitmap(padded, 0, 0, width, height).also { padded.recycle() }
    }

    companion object {
        const val ACTION_STOP = "com.stellasora.tracker.stella_tracker.STOP_SCREEN_READ"
        const val EXTRA_RESULT_CODE = "projection_result_code"
        const val EXTRA_RESULT_DATA = "projection_result_data"
        private const val CHANNEL_ID = "stella_screen_reader"
        private const val NOTIFICATION_ID = 8321
        private const val SCAN_TIMEOUT_MS = 180_000L
        private val ENERGY_PATTERN = Pattern.compile("(?<!\\d)(\\d{1,3})\\s*/\\s*(\\d{1,3})(?!\\d)")
        private val DURATION_PATTERN = Pattern.compile(
            "\\b(\\d{1,2})\\s*(?:h|hr|hrs|hour|hours)\\s*(\\d{1,2})\\s*(?:m|min|mins|minute|minutes)\\b",
            Pattern.CASE_INSENSITIVE,
        )
        private val CLOCK_PATTERN = Pattern.compile("\\b(\\d{1,2}):(\\d{2})\\b")
    }
}
