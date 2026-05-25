package com.example.train_timer

import HomeWidgetGlanceStateDefinition
import HomeWidgetGlanceWidgetReceiver
import HomeWidgetGlanceState
import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.os.SystemClock
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.background
import androidx.glance.appwidget.AndroidRemoteViews
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import es.antonborri.home_widget.HomeWidgetPlugin
import kotlinx.coroutines.runBlocking
import org.json.JSONArray
import kotlin.math.max

class TrainTimerWidgetReceiver : HomeWidgetGlanceWidgetReceiver<TrainTimerGlanceWidget>() {
    override val glanceAppWidget = TrainTimerGlanceWidget()

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == TrainTimerRemoteViews.ACTION_REFRESH_DEPARTURE) {
            TrainTimerRemoteViews.advanceToNextDeparture(context)
            runBlocking {
                glanceAppWidget.updateAll(context)
            }
            return
        }
        super.onReceive(context, intent)
    }
}

class TrainTimerGlanceWidget : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            TrainTimerGlanceContent(context, currentState())
        }
    }
}

@Composable
private fun TrainTimerGlanceContent(context: Context, currentState: HomeWidgetGlanceState) {
    var state = TrainTimerWidgetState.from(currentState.preferences)
    if (state.isExpiredDeparture) {
        TrainTimerRemoteViews.advanceToNextDeparture(context)
        state = TrainTimerWidgetState.from(context, Bundle())
    }
    if (state.countdownMain == "運行終了" && state.remainingMillis > 3_600_000) {
        TrainTimerRemoteViews.scheduleOperationResume(context, state.departureEpochMillis)
    }
    TrainTimerWidgetContent(
        context = context,
        state = state,
        compact = true,
    )
}

@Composable
private fun TrainTimerWidgetContent(
    context: Context,
    state: TrainTimerWidgetState,
    compact: Boolean,
) {
    Box(
        modifier =
            GlanceModifier
                .fillMaxSize()
                .background(Color(0xE61B1F24))
                .clickable(actionStartActivity<MainActivity>())
                .padding(horizontal = 10.dp, vertical = 8.dp),
    ) {
        Column(modifier = GlanceModifier.fillMaxSize()) {
            Row(modifier = GlanceModifier.fillMaxWidth()) {
                Column(modifier = GlanceModifier.defaultWeight()) {
                    Text(
                        text = state.station,
                        maxLines = 1,
                        style =
                            TextStyle(
                                color = ColorProvider(Color(0xFFF7F8F8)),
                                fontSize =
                                    when {
                                        state.station.length >= 6 -> if (compact) 12.sp else 13.sp
                                        compact -> 14.sp
                                        else -> 15.sp
                                    },
                                fontWeight = FontWeight.Bold,
                            ),
                    )
                    Spacer(modifier = GlanceModifier.height(1.dp))
                    Text(
                        text = state.direction,
                        maxLines = 1,
                        style =
                            TextStyle(
                                color = ColorProvider(Color(0xFFC8CDD2)),
                                fontSize =
                                    when {
                                        state.direction.length >= 9 -> 9.sp
                                        compact -> 9.sp
                                        else -> 10.sp
                                    },
                            ),
                    )
                }
                if (state.isLastDeparture) {
                    Text(
                        text = "終電",
                        maxLines = 1,
                        style =
                            TextStyle(
                                color = ColorProvider(Color(0xFFFF6B6B)),
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                textAlign = TextAlign.End,
                            ),
                    )
                }
            }

            Spacer(modifier = GlanceModifier.defaultWeight())

            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.Bottom,
            ) {
                Text(
                    text = state.departure,
                    maxLines = 1,
                    style =
                        TextStyle(
                            color = ColorProvider(Color(0xFFDDE2E5)),
                            fontSize = if (compact) 12.sp else 13.sp,
                        ),
                )
                Spacer(modifier = GlanceModifier.width(4.dp))
                if (state.useChronometer) {
                    Spacer(modifier = GlanceModifier.defaultWeight())
                    Column(
                        modifier = GlanceModifier.width(if (compact) 78.dp else 92.dp),
                        horizontalAlignment = Alignment.End,
                    ) {
                        Text(
                            text = "あと",
                            maxLines = 1,
                            style =
                                TextStyle(
                                    color = ColorProvider(Color(0xFF68E0D2)),
                                    fontSize = 8.sp,
                                    fontWeight = FontWeight.Bold,
                                    textAlign = TextAlign.End,
                                ),
                        )
                        AndroidRemoteViews(
                            remoteViews = TrainTimerRemoteViews.chronometer(context, state, compact),
                            modifier = GlanceModifier.fillMaxWidth().height(24.dp),
                        )
                    }
                } else {
                    Column(
                        modifier = GlanceModifier.defaultWeight(),
                        horizontalAlignment = Alignment.End,
                    ) {
                        if (state.countdownLabel.isNotEmpty()) {
                            Text(
                                text = state.countdownLabel,
                                maxLines = 1,
                                style =
                                    TextStyle(
                                        color = ColorProvider(Color(0xFF68E0D2)),
                                        fontSize = 8.sp,
                                        fontWeight = FontWeight.Bold,
                                        textAlign = TextAlign.End,
                                    ),
                            )
                        }
                        Text(
                            text = state.countdownMain,
                            maxLines = 1,
                            style =
                                TextStyle(
                                    color = ColorProvider(Color.White),
                                    fontSize = state.countdownFontSize(compact).sp,
                                    fontWeight = FontWeight.Bold,
                                    textAlign = TextAlign.End,
                                ),
                        )
                    }
                }
            }
            Spacer(modifier = GlanceModifier.defaultWeight())
        }
    }
}

private object TrainTimerRemoteViews {
    const val ACTION_REFRESH_DEPARTURE = "com.example.train_timer.REFRESH_DEPARTURE"
    private const val REQUEST_REFRESH_DEPARTURE = 9101
    private val DEPARTURE_REFRESH_OFFSETS = longArrayOf(1_000L, 15_000L, 45_000L, 90_000L)

    fun chronometer(context: Context, state: TrainTimerWidgetState, compact: Boolean): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.train_timer_chronometer)
        views.setChronometer(
            R.id.widget_chronometer,
            SystemClock.elapsedRealtime() + state.remainingMillis,
            "%s",
            true,
        )
        views.setChronometerCountDown(R.id.widget_chronometer, true)
        views.setTextViewTextSize(
            R.id.widget_chronometer,
            TypedValue.COMPLEX_UNIT_SP,
            if (compact) 18f else 20f,
        )
        scheduleDepartureRefresh(context, state.departureEpochMillis)
        return views
    }

    fun build(context: Context, options: Bundle): RemoteViews {
        val state = TrainTimerWidgetState.from(context, options)
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 160)
        val compact = minWidth < 170

        val views = RemoteViews(context.packageName, R.layout.train_timer_widget)
        views.setTextViewText(R.id.widget_station, state.station)
        views.setTextViewText(R.id.widget_direction, state.direction)
        views.setTextViewText(R.id.widget_countdown_label, state.countdownLabel)
        views.setTextViewText(R.id.widget_countdown, state.countdownMain)
        views.setTextViewText(R.id.widget_departure, state.departure)
        views.setViewVisibility(
            R.id.widget_countdown_label,
            if (state.useChronometer || state.countdownLabel.isEmpty()) View.GONE else View.VISIBLE,
        )
        views.setViewVisibility(
            R.id.widget_countdown,
            if (state.useChronometer) View.GONE else View.VISIBLE,
        )
        views.setViewVisibility(
            R.id.widget_chronometer,
            if (state.useChronometer) View.VISIBLE else View.GONE,
        )
        if (state.useChronometer) {
            views.setChronometer(
                R.id.widget_chronometer,
                SystemClock.elapsedRealtime() + state.remainingMillis,
                "%s",
                true,
            )
            views.setChronometerCountDown(R.id.widget_chronometer, true)
            views.setTextViewTextSize(
                R.id.widget_chronometer,
                TypedValue.COMPLEX_UNIT_SP,
                if (compact) 18f else 20f,
            )
            scheduleDepartureRefresh(context, state.departureEpochMillis)
        } else if (state.countdownMain == "運行終了" && state.remainingMillis > 3_600_000) {
            scheduleOperationResume(context, state.departureEpochMillis)
        }
        views.setViewVisibility(
            R.id.widget_last_train,
            if (state.isLastDeparture) View.VISIBLE else View.GONE,
        )
        views.setTextViewTextSize(
            R.id.widget_station,
            TypedValue.COMPLEX_UNIT_SP,
            when {
                state.station.length >= 6 -> if (compact) 12f else 13f
                compact -> 14f
                else -> 15f
            },
        )
        views.setTextViewTextSize(
            R.id.widget_direction,
            TypedValue.COMPLEX_UNIT_SP,
            when {
                state.direction.length >= 9 -> 9f
                compact -> 9f
                else -> 10f
            },
        )
        views.setTextViewTextSize(
            R.id.widget_departure,
            TypedValue.COMPLEX_UNIT_SP,
            if (compact) 12f else 13f,
        )
        views.setTextViewTextSize(
            R.id.widget_countdown,
            TypedValue.COMPLEX_UNIT_SP,
            state.countdownFontSize(compact),
        )

        val launchIntent = Intent(context, MainActivity::class.java)
        val launchPendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_root, launchPendingIntent)
        return views
    }

    fun scheduleDepartureRefresh(context: Context, departureEpochMillis: Long) {
        DEPARTURE_REFRESH_OFFSETS.forEachIndexed { index, offset ->
            val requestCode = REQUEST_REFRESH_DEPARTURE + index
            cancelRefresh(context, requestCode)
            scheduleRefresh(
                context = context,
                triggerAt = departureEpochMillis + offset,
                requestCode = requestCode,
                useAlarmClock = false,
            )
        }
    }

    fun scheduleOperationResume(context: Context, departureEpochMillis: Long) {
        cancelRefresh(context, REQUEST_REFRESH_DEPARTURE + 100)
        scheduleRefresh(
            context = context,
            triggerAt = departureEpochMillis - 3_600_000,
            requestCode = REQUEST_REFRESH_DEPARTURE + 100,
            useAlarmClock = false,
        )
    }

    private fun scheduleRefresh(
        context: Context,
        triggerAt: Long,
        requestCode: Int,
        useAlarmClock: Boolean,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, TrainTimerWidgetReceiver::class.java).apply {
            action = ACTION_REFRESH_DEPARTURE
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val safeTriggerAt = max(triggerAt, System.currentTimeMillis() + 500)
        try {
            if (useAlarmClock) {
                alarmManager.setAlarmClock(
                    AlarmManager.AlarmClockInfo(safeTriggerAt, pendingIntent),
                    pendingIntent,
                )
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    safeTriggerAt,
                    pendingIntent,
                )
            }
        } catch (_: SecurityException) {
            alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                safeTriggerAt,
                pendingIntent,
            )
        }
    }

    private fun cancelRefresh(context: Context, requestCode: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, TrainTimerWidgetReceiver::class.java).apply {
            action = ACTION_REFRESH_DEPARTURE
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        )
        if (pendingIntent != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    fun advanceToNextDeparture(context: Context) {
        val prefs = HomeWidgetPlugin.getData(context)
        val next = nextDepartureFromCache(prefs)
        prefs.edit().apply {
            if (next == null) {
                putString("countdown", "運行終了")
                putString("departureTime", "--:--")
                putBoolean("isLastDeparture", false)
                putLong("departureEpochMillis", 0L)
                putString("departuresJson", "[]")
            } else {
                putString("station", next.station)
                putString("direction", next.direction)
                putString("departureTime", next.departureTime)
                putString(
                    "countdown",
                    if (next.shouldShowOperationEnded()) {
                        "運行終了"
                    } else {
                        formatCountdown(next.departureEpochMillis)
                    },
                )
                putBoolean("isLastDeparture", next.isLastDeparture)
                putLong("departureEpochMillis", next.departureEpochMillis)
                if (next.shouldShowOperationEnded()) {
                    scheduleOperationResume(context, next.departureEpochMillis)
                } else {
                    scheduleDepartureRefresh(context, next.departureEpochMillis)
                }
            }
        }.apply()
    }

    private fun nextDepartureFromCache(prefs: SharedPreferences): NativeDeparture? {
        val departures = JSONArray(prefs.getString("departuresJson", "[]") ?: "[]")
        val now = System.currentTimeMillis()
        var previousWasLastDeparture = false
        for (index in 0 until departures.length()) {
            val item = departures.getJSONObject(index)
            val epoch = item.optLong("departureEpochMillis", 0L)
            if (epoch > now) {
                return NativeDeparture(
                    station = item.optString("station", prefs.getString("station", "") ?: ""),
                    direction = item.optString("direction", prefs.getString("direction", "") ?: ""),
                    departureTime = item.optString(
                        "departureTime",
                        prefs.getString("departureTime", "--:--") ?: "--:--",
                    ),
                    departureEpochMillis = epoch,
                    isFirstDeparture = if (item.has("isFirstDeparture")) {
                        item.optBoolean("isFirstDeparture", false)
                    } else {
                        previousWasLastDeparture
                    },
                    isLastDeparture = item.optBoolean("isLastDeparture", false),
                )
            }
            previousWasLastDeparture = item.optBoolean("isLastDeparture", false)
        }
        return null
    }

    private fun formatCountdown(departureEpochMillis: Long): String {
        val remainingSeconds = max(0L, (departureEpochMillis - System.currentTimeMillis()) / 1_000)
        return if (remainingSeconds <= 300) {
            val minutes = remainingSeconds / 60
            val seconds = remainingSeconds % 60
            "$minutes:${seconds.toString().padStart(2, '0')}"
        } else {
            "あと ${remainingSeconds / 60}分"
        }
    }

    private data class NativeDeparture(
        val station: String,
        val direction: String,
        val departureTime: String,
        val departureEpochMillis: Long,
        val isFirstDeparture: Boolean,
        val isLastDeparture: Boolean,
    ) {
        fun shouldShowOperationEnded(): Boolean {
            return isFirstDeparture &&
                departureEpochMillis - System.currentTimeMillis() > 3_600_000
        }
    }
}

private data class TrainTimerWidgetState(
    val station: String,
    val direction: String,
    val countdownLabel: String,
    val countdownMain: String,
    val departure: String,
    val isLastDeparture: Boolean,
    val departureEpochMillis: Long,
) {
    val remainingMillis: Long = departureEpochMillis - System.currentTimeMillis()
    val isExpiredDeparture: Boolean =
        departureEpochMillis > 0 && remainingMillis <= 0 && countdownMain != "運行終了"
    val useChronometer: Boolean =
        remainingMillis > 0 && countdownMain != "運行終了"

    fun countdownFontSize(compact: Boolean): Float {
        return when {
            countdownMain == "運行終了" -> if (compact) 15f else 17f
            countdownMain.contains(":") -> if (compact) 21f else 24f
            countdownMain.length >= 5 -> if (compact) 16f else 18f
            countdownMain.length >= 4 -> if (compact) 19f else 21f
            compact -> 22f
            else -> 24f
        }
    }

    companion object {
        fun from(context: Context, options: Bundle): TrainTimerWidgetState {
            return from(HomeWidgetPlugin.getData(context))
        }

        fun from(prefs: SharedPreferences): TrainTimerWidgetState {
            val countdown = prefs.getString("countdown", "あと --分") ?: "あと --分"
            return TrainTimerWidgetState(
                station = prefs.getString("station", "舞浜") ?: "舞浜",
                direction = prefs.getString("direction", "東京方面") ?: "東京方面",
                countdownLabel = if (countdown.startsWith("あと ")) "あと" else "",
                countdownMain = countdown.removePrefix("あと "),
                departure = prefs.getString("departureTime", "--:--") ?: "--:--",
                isLastDeparture = prefs.getBoolean("isLastDeparture", false),
                departureEpochMillis = prefs.longValue("departureEpochMillis"),
            )
        }

        private fun SharedPreferences.longValue(key: String): Long {
            return when (val value = all[key]) {
                is Long -> value
                is Int -> value.toLong()
                is Number -> value.toLong()
                is String -> value.toLongOrNull() ?: 0L
                else -> 0L
            }
        }
    }
}
