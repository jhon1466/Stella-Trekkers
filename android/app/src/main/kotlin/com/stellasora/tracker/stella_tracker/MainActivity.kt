package com.stellasora.tracker.stella_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.dart.DartExecutor
import android.os.Handler
import android.os.Looper
import androidx.core.content.res.ResourcesCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale
import android.app.AlarmManager
import android.os.Bundle
import android.os.SystemClock
import java.text.SimpleDateFormat
import java.util.Date

class MainActivity : FlutterActivity() {
    private var projectionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stella/account_widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateEnergy" -> {
                        val energy = call.argument<Int>("energy")
                        val maximum = call.argument<Int>("maximum")
                        val fullSeconds = call.argument<Int>("fullSeconds")
                        if (energy == null || maximum == null || fullSeconds == null || maximum <= 0) {
                            result.error("invalid_energy", "Datos de energía incompletos", null)
                            return@setMethodCallHandler
                        }
                        EnergyWidget.saveEnergy(this, energy, maximum, fullSeconds)
                        EnergyWidget.saveProfile(this, call)
                        result.success(true)
                    }
                    "clearWidget" -> {
                        EnergyWidget.clear(this)
                        result.success(true)
                    }
                    "updateWidgetBackground" -> {
                        val imagePath = call.argument<String>("imagePath")
                        val characterName = call.argument<String>("characterName") ?: ""
                        val prefs = getSharedPreferences("account_widget", MODE_PRIVATE).edit()
                        if (imagePath.isNullOrEmpty()) {
                            prefs.remove("character_bg_path")
                            prefs.remove("character_name")
                        } else {
                            prefs.putString("character_bg_path", imagePath)
                            prefs.putString("character_name", characterName)
                        }
                        prefs.apply()
                        EnergyWidget.updateAll(this)
                        result.success(true)
                    }
                    "startLiveRead" -> {
                        if (projectionResult != null) {
                            result.error("already_waiting", "Ya se está solicitando permiso de captura.", null)
                            return@setMethodCallHandler
                        }
                        projectionResult = result
                        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                        startActivityForResult(manager.createScreenCaptureIntent(), SCREEN_CAPTURE_REQUEST)
                    }
                    "openGame" -> {
                        val game = packageManager.getLaunchIntentForPackage("com.YoStarEN.StellaSora")
                        if (game == null) result.error("game_missing", "Stella Sora no está instalada.", null)
                        else {
                            startActivity(game)
                            result.success(true)
                        }
                    }
                    "stopLiveRead" -> {
                        stopService(Intent(this, ScreenReaderService::class.java))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Android API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SCREEN_CAPTURE_REQUEST) return
        val pending = projectionResult
        projectionResult = null
        if (resultCode != RESULT_OK || data == null) {
            pending?.success(false)
            return
        }
        val service = Intent(this, ScreenReaderService::class.java)
            .putExtra(ScreenReaderService.EXTRA_RESULT_CODE, resultCode)
            .putExtra(ScreenReaderService.EXTRA_RESULT_DATA, data)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(service)
            else startService(service)
            getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE).edit()
                .putBoolean("flutter.account_screen_reader_active", true)
                .apply()
            pending?.success(true)
        } catch (e: Exception) {
            pending?.error("screen_reader_start_failed", e.message, null)
        }
    }

    companion object {
        private const val SCREEN_CAPTURE_REQUEST = 7304
    }
}

class EnergyWidget : android.appwidget.AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(context, manager, it) }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_REFRESH -> refreshInBackground(context.applicationContext)
            ACTION_TICK -> updateAll(context)
        }
    }

    // Al cambiar el tamaño del widget se rehace con el diseño adecuado.
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        update(context, manager, id)
    }

    companion object {
        private const val TAG = "EnergyWidget"
        const val ACTION_REFRESH = "com.stellasora.tracker.WIDGET_REFRESH"
        const val ACTION_TICK = "com.stellasora.tracker.WIDGET_TICK"

        fun saveProfile(context: Context, call: io.flutter.plugin.common.MethodCall) {
            val e = context.getSharedPreferences("account_widget", Context.MODE_PRIVATE).edit()
            call.argument<String>("nickname")?.let { e.putString("nickname", it) }
            call.argument<String>("uid")?.let { e.putString("uid", it) }
            call.argument<Int>("level")?.let { e.putInt("level", it) }
            call.argument<Int>("characters")?.let { e.putInt("characters", it) }
            call.argument<Int>("discs")?.let { e.putInt("discs", it) }
            e.apply()
            updateAll(context)
        }

        /** Cierre de sesión: borra energía, perfil e imagen, y deja el widget vacío. */
        fun clear(context: Context) {
            val prefs = context.getSharedPreferences("account_widget", Context.MODE_PRIVATE)
            prefs.getString("character_bg_path", null)?.let { try { File(it).delete() } catch (_: Exception) {} }
            prefs.edit().clear().apply()
            cancelTick(context)
            updateAll(context)
        }

        private fun tickIntent(context: Context) = PendingIntent.getBroadcast(
            context, 2, Intent(context, EnergyWidget::class.java).setAction(ACTION_TICK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        private fun cancelTick(context: Context) {
            (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(tickIntent(context))
        }

        /** Programa el próximo refresco del número de energía (cuando suba el siguiente punto). */
        private fun scheduleTick(context: Context, inMillis: Long) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.set(AlarmManager.ELAPSED_REALTIME, SystemClock.elapsedRealtime() + inMillis.coerceAtLeast(60_000), tickIntent(context))
        }
        private var refreshing = false
        private var engine: FlutterEngine? = null

        fun saveEnergy(context: Context, energy: Int, maximum: Int, fullSeconds: Int) {
            // Permite energía desbordada (p. ej. 400/240) sin recortar al máximo
            context.getSharedPreferences("account_widget", Context.MODE_PRIVATE).edit()
                .putInt("energy", energy.coerceAtLeast(0))
                .putInt("maximum", maximum)
                .putInt("fullSeconds", fullSeconds.coerceAtLeast(0))
                .putLong("capturedAtMillis", System.currentTimeMillis())
                .apply()
            updateAll(context)
        }

        /** Arranca un motor Flutter sin interfaz que sincroniza la energía y actualiza el widget. */
        private fun refreshInBackground(context: Context) {
            if (refreshing) return
            refreshing = true
            context.getSharedPreferences("account_widget", Context.MODE_PRIVATE).edit()
                .putBoolean("refreshing", true).apply()
            updateAll(context)
            val handler = Handler(Looper.getMainLooper())
            val finish = Runnable {
                if (!refreshing) return@Runnable
                refreshing = false
                context.getSharedPreferences("account_widget", Context.MODE_PRIVATE).edit()
                    .putBoolean("refreshing", false).apply()
                try { engine?.destroy() } catch (_: Exception) {}
                engine = null
                updateAll(context)
            }
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(context)
                loader.ensureInitializationComplete(context, null)
                val e = FlutterEngine(context)
                engine = e
                MethodChannel(e.dartExecutor.binaryMessenger, "stella/account_widget").setMethodCallHandler { call, result ->
                    if (call.method == "updateEnergy") {
                        val energy = call.argument<Int>("energy")
                        val maximum = call.argument<Int>("maximum")
                        val fullSeconds = call.argument<Int>("fullSeconds")
                        if (energy != null && maximum != null && fullSeconds != null && maximum > 0) {
                            saveEnergy(context, energy, maximum, fullSeconds)
                        }
                        result.success(true)
                    } else result.success(null)
                }
                MethodChannel(e.dartExecutor.binaryMessenger, "stella/widget_refresh").setMethodCallHandler { _, result ->
                    result.success(true)
                    handler.post(finish)
                }
                e.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "widgetRefreshMain")
                )
                handler.postDelayed(finish, 30_000)
            } catch (ex: Exception) {
                Log.e(TAG, "Widget refresh failed", ex)
                finish.run()
            }
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, EnergyWidget::class.java)
            manager.getAppWidgetIds(component).forEach { update(context, manager, it) }
        }

        private fun renderVectorBitmap(context: Context, resId: Int, sizePx: Int): Bitmap? {
            return try {
                val drawable = ResourcesCompat.getDrawable(context.resources, resId, context.theme) ?: return null
                val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)
                drawable.setBounds(0, 0, sizePx, sizePx)
                drawable.draw(canvas)
                bitmap
            } catch (e: Exception) {
                Log.e(TAG, "Error rendering vector $resId", e)
                null
            }
        }

        private fun update(context: Context, manager: AppWidgetManager, id: Int) {
            try {
                val views = RemoteViews(context.packageName, R.layout.energy_widget)
                val prefs = context.getSharedPreferences("account_widget", Context.MODE_PRIVATE)

                // Render vector drawables as safe bitmaps for launcher compatibility (prevents XML inflation crash)
                val density = context.resources.displayMetrics.density
                val moonPx = (32 * density).toInt().coerceAtLeast(24)
                val refreshPx = (20 * density).toInt().coerceAtLeast(16)
                val sparklePx = (14 * density).toInt().coerceAtLeast(12)

                renderVectorBitmap(context, R.drawable.ic_stamina_moon, moonPx)?.let {
                    views.setImageViewBitmap(R.id.widget_stamina_icon, it)
                }
                renderVectorBitmap(context, R.drawable.ic_refresh_arrow, refreshPx)?.let {
                    views.setImageViewBitmap(R.id.widget_refresh_button, it)
                }
                renderVectorBitmap(context, R.drawable.ic_sparkle, sparklePx)?.let {
                    views.setImageViewBitmap(R.id.widget_chip_icon, it)
                }

                // Character Background Artwork
                val bgPath = prefs.getString("character_bg_path", null)
                val charName = prefs.getString("character_name", null)

                if (!charName.isNullOrEmpty()) {
                    views.setTextViewText(R.id.widget_chip_title, charName)
                } else {
                    views.setTextViewText(R.id.widget_chip_title, prefs.getString("nickname", null) ?: "Stella Trekkers")
                }

                if (!bgPath.isNullOrEmpty()) {
                    val file = File(bgPath)
                    if (file.exists()) {
                        try {
                            val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                            BitmapFactory.decodeFile(file.absolutePath, opts)
                            var inSampleSize = 1
                            val targetSize = 512
                            if (opts.outHeight > targetSize || opts.outWidth > targetSize) {
                                val halfH = opts.outHeight / 2
                                val halfW = opts.outWidth / 2
                                while ((halfH / inSampleSize) >= targetSize && (halfW / inSampleSize) >= targetSize) {
                                    inSampleSize *= 2
                                }
                            }
                            val decOpts = BitmapFactory.Options().apply {
                                this.inSampleSize = inSampleSize
                                inPreferredConfig = Bitmap.Config.RGB_565
                            }
                            val bmp = BitmapFactory.decodeFile(file.absolutePath, decOpts)
                            if (bmp != null) {
                                views.setImageViewBitmap(R.id.widget_bg, bmp)
                                views.setViewVisibility(R.id.widget_bg, View.VISIBLE)
                            } else {
                                views.setViewVisibility(R.id.widget_bg, View.GONE)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error loading character bg", e)
                            views.setViewVisibility(R.id.widget_bg, View.GONE)
                        }
                    } else {
                        views.setViewVisibility(R.id.widget_bg, View.GONE)
                    }
                } else {
                    views.setViewVisibility(R.id.widget_bg, View.GONE)
                }

                // Tamaño actual del widget (dp) → qué secciones se muestran
                val opts = manager.getAppWidgetOptions(id)
                val w = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 180)
                val h = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 110)
                val small = w < 150 || h < 100
                val large = h >= 200 && w >= 180
                views.setViewVisibility(R.id.widget_top_chip, if (small) View.GONE else View.VISIBLE)
                views.setViewVisibility(R.id.widget_refresh_button, if (w < 120) View.GONE else View.VISIBLE)

                val nickname = prefs.getString("nickname", null)
                val hasProfile = !nickname.isNullOrEmpty()
                views.setViewVisibility(R.id.widget_profile, if (large && hasProfile) View.VISIBLE else View.GONE)
                if (hasProfile) {
                    views.setTextViewText(R.id.widget_nickname, nickname)
                    val level = prefs.getInt("level", 0)
                    val uid = prefs.getString("uid", "") ?: ""
                    views.setTextViewText(R.id.widget_level, "Nv. $level" + if (uid.isNotEmpty()) "  ·  UID $uid" else "")
                    views.setTextViewText(
                        R.id.widget_collection,
                        "${prefs.getInt("characters", 0)} trekkers  ·  ${prefs.getInt("discs", 0)} discos"
                    )
                }

                // Energía calculada en vivo a partir de la última sincronización
                val energy = prefs.getInt("energy", -1)
                val maximum = prefs.getInt("maximum", 0)
                val fullSecondsAtCapture = prefs.getInt("fullSeconds", 0)
                val capturedAtMillis = prefs.getLong("capturedAtMillis", System.currentTimeMillis())
                views.setViewVisibility(R.id.widget_countdown, View.GONE)
                views.setViewVisibility(R.id.widget_timer, View.VISIBLE)
                views.setViewVisibility(R.id.widget_full_at, View.GONE)

                if (energy < 0 || maximum <= 0) {
                    views.setTextViewText(R.id.widget_energy, "--/--")
                    views.setTextViewText(R.id.widget_timer, if (small) "Sin datos" else "Vincula tu cuenta en la app")
                    cancelTick(context)
                } else if (energy >= maximum) {
                    views.setTextViewText(R.id.widget_energy, "$energy/$maximum")
                    views.setTextViewText(R.id.widget_timer, if (energy > maximum) "¡Energía desbordada!" else "¡Energía completa!")
                    cancelTick(context)
                } else {
                    val elapsedSeconds = ((System.currentTimeMillis() - capturedAtMillis) / 1000).coerceAtLeast(0)
                    val fullSeconds = (fullSecondsAtCapture - elapsedSeconds).coerceAtLeast(0)
                    val missingAtCapture = (maximum - energy).coerceAtLeast(1)
                    val regenSeconds = (fullSecondsAtCapture.toDouble() / missingAtCapture).coerceAtLeast(1.0)
                    val restored = if (fullSecondsAtCapture > 0) (elapsedSeconds / regenSeconds).toInt() else 0
                    val currentEnergy = (energy + restored).coerceAtMost(maximum)

                    if (currentEnergy >= maximum || fullSeconds <= 0) {
                        views.setTextViewText(R.id.widget_energy, "$maximum/$maximum")
                        views.setTextViewText(R.id.widget_timer, "¡Energía completa!")
                        cancelTick(context)
                    } else {
                        views.setTextViewText(R.id.widget_energy, "$currentEnergy/$maximum")
                        // Cuenta atrás que corre sola hasta llenarse
                        views.setViewVisibility(R.id.widget_timer, View.GONE)
                        views.setViewVisibility(R.id.widget_countdown, View.VISIBLE)
                        val base = SystemClock.elapsedRealtime() + fullSeconds * 1000L
                        views.setChronometer(R.id.widget_countdown, base, if (small) "%s" else "Llena en %s", true)
                        views.setChronometerCountDown(R.id.widget_countdown, true)
                        if (large) {
                            val fullAt = Date(System.currentTimeMillis() + fullSeconds * 1000L)
                            views.setTextViewText(
                                R.id.widget_full_at,
                                "Completa a las " + SimpleDateFormat("HH:mm", Locale.getDefault()).format(fullAt) +
                                    " · +1 cada ${(regenSeconds / 60).toInt()} min"
                            )
                            views.setViewVisibility(R.id.widget_full_at, View.VISIBLE)
                        }
                        // Próximo punto de energía: se actualiza el número entonces
                        val sinceLast = (elapsedSeconds % regenSeconds.toLong())
                        scheduleTick(context, ((regenSeconds.toLong() - sinceLast) * 1000L))
                    }
                }

                if (prefs.getBoolean("refreshing", false)) {
                    views.setViewVisibility(R.id.widget_countdown, View.GONE)
                    views.setViewVisibility(R.id.widget_timer, View.VISIBLE)
                    views.setTextViewText(R.id.widget_timer, "Actualizando…")
                }
                // Tocar el widget abre la app
                val appIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("action", "sync_energy")
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    appIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                // El botón de recarga sincroniza en segundo plano, sin abrir la app
                val refreshIntent = Intent(context, EnergyWidget::class.java).setAction(ACTION_REFRESH)
                val refreshPending = PendingIntent.getBroadcast(
                    context, 1, refreshIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_refresh_button, refreshPending)

                manager.updateAppWidget(id, views)
            } catch (e: Exception) {
                Log.e(TAG, "Fatal widget update error", e)
            }
        }
    }
}
