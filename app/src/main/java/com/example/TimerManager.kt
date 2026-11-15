package com.example

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.example.data.StudyDatabase
import com.example.data.StudySession
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

enum class TimerStatus {
    IDLE,
    RUNNING,
    PAUSED,
    STOPPED
}

data class TimerState(
    val elapsedSeconds: Long = 0L,
    val status: TimerStatus = TimerStatus.IDLE
)

object TimerManager {

    private const val CHANNEL_ID = "lockscreen_timer_channel"
    private const val NOTIFICATION_ID = 2001

    const val ACTION_START = "com.example.ACTION_START"
    const val ACTION_PAUSE = "com.example.ACTION_PAUSE"
    const val ACTION_STOP = "com.example.ACTION_STOP"
    const val ACTION_RESET = "com.example.ACTION_RESET"

    private val scope = CoroutineScope(Dispatchers.Main)
    private var tickerJob: Job? = null
    private var appContext: Context? = null
    private var database: StudyDatabase? = null

    private val _state = MutableStateFlow(TimerState())
    val state: StateFlow<TimerState> = _state.asStateFlow()

    private var currentSessionStartTime: Long = 0L
    private var hasSavedCurrentSession: Boolean = false

    fun init(context: Context) {
        appContext = context.applicationContext
        database = StudyDatabase.getInstance(context.applicationContext)
        createNotificationChannel()
    }

    fun getTodaySessionsFlow(): Flow<List<StudySession>> {
        val dao = database?.studyDao() ?: return emptyFlow()
        return dao.getSessionsForDay(getStartOfToday(), getEndOfToday())
    }

    fun getTodayTotalSecondsFlow(): Flow<Long?> {
        val dao = database?.studyDao() ?: return emptyFlow()
        return dao.getTodayTotalSeconds(getStartOfToday(), getEndOfToday())
    }

    fun getTodaySessionCountFlow(): Flow<Int> {
        val dao = database?.studyDao() ?: return emptyFlow()
        return dao.getTodaySessionCount(getStartOfToday(), getEndOfToday())
    }

    private fun createNotificationChannel() {
        val context = appContext ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Timer Controls",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows live timer controls on lockscreen"
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun start() {
        if (_state.value.status == TimerStatus.RUNNING) return

        if (currentSessionStartTime == 0L || hasSavedCurrentSession) {
            currentSessionStartTime = System.currentTimeMillis()
            hasSavedCurrentSession = false
        }

        _state.update { it.copy(status = TimerStatus.RUNNING) }
        startTicker()
        updateNotification()
    }

    fun pause() {
        if (_state.value.status != TimerStatus.RUNNING) return

        tickerJob?.cancel()
        _state.update { it.copy(status = TimerStatus.PAUSED) }
        updateNotification()
    }

    fun stop() {
        if (_state.value.status == TimerStatus.IDLE) return

        tickerJob?.cancel()
        saveCurrentSessionIfEligible()
        _state.update { it.copy(status = TimerStatus.STOPPED) }
        updateNotification()
    }

    fun reset() {
        tickerJob?.cancel()
        saveCurrentSessionIfEligible()
        _state.update { TimerState(elapsedSeconds = 0L, status = TimerStatus.IDLE) }
        currentSessionStartTime = 0L
        hasSavedCurrentSession = false
        clearNotification()
    }

    private fun saveCurrentSessionIfEligible() {
        val elapsed = _state.value.elapsedSeconds
        if (!hasSavedCurrentSession && elapsed > 0L && currentSessionStartTime > 0L) {
            hasSavedCurrentSession = true
            val startMs = currentSessionStartTime
            val stopMs = System.currentTimeMillis()
            scope.launch(Dispatchers.IO) {
                database?.studyDao()?.insertSession(
                    StudySession(
                        startTimeMillis = startMs,
                        stopTimeMillis = stopMs,
                        durationSeconds = elapsed
                    )
                )
            }
        }
    }

    private fun startTicker() {
        tickerJob?.cancel()
        tickerJob = scope.launch {
            while (isActive) {
                delay(1000L)
                if (_state.value.status == TimerStatus.RUNNING) {
                    _state.update { it.copy(elapsedSeconds = it.elapsedSeconds + 1L) }
                    updateNotification()
                } else {
                    break
                }
            }
        }
    }

    fun formatTime(totalSeconds: Long): String {
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60
        return "%02d:%02d:%02d".format(hours, minutes, seconds)
    }

    fun formatDurationLabel(totalSeconds: Long): String {
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60
        return when {
            hours > 0 -> "%dh %02dm %02ds".format(hours, minutes, seconds)
            minutes > 0 -> "%dm %02ds".format(minutes, seconds)
            else -> "${seconds}s"
        }
    }

    fun formatTimeOfDay(timestampMillis: Long): String {
        val sdf = SimpleDateFormat("h:mm a", Locale.getDefault())
        return sdf.format(Date(timestampMillis))
    }

    private fun updateNotification() {
        val context = appContext ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    context,
                    android.Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                return
            }
        }

        val currentState = _state.value
        val formattedTime = formatTime(currentState.elapsedSeconds)
        val statusLabel = when (currentState.status) {
            TimerStatus.RUNNING -> "Running"
            TimerStatus.PAUSED -> "Paused"
            TimerStatus.STOPPED -> "Stopped"
            TimerStatus.IDLE -> "Ready"
        }

        // Tap notification to open MainActivity
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            context,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(formattedTime)
            .setContentText("Timer: $statusLabel")
            .setContentIntent(contentPendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC) // Shows directly on lockscreen
            .setOngoing(currentState.status == TimerStatus.RUNNING || currentState.status == TimerStatus.PAUSED)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)

        // Action buttons based on status for lockscreen
        when (currentState.status) {
            TimerStatus.RUNNING -> {
                builder.addAction(createAction(context, ACTION_PAUSE, "Pause", 1))
                builder.addAction(createAction(context, ACTION_STOP, "Stop", 2))
            }
            TimerStatus.PAUSED -> {
                builder.addAction(createAction(context, ACTION_START, "Start", 3))
                builder.addAction(createAction(context, ACTION_STOP, "Stop", 4))
                builder.addAction(createAction(context, ACTION_RESET, "Reset", 5))
            }
            TimerStatus.STOPPED -> {
                builder.addAction(createAction(context, ACTION_START, "Start", 6))
                builder.addAction(createAction(context, ACTION_RESET, "Reset", 7))
            }
            TimerStatus.IDLE -> {
                builder.addAction(createAction(context, ACTION_START, "Start", 8))
            }
        }

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        try {
            notificationManager.notify(NOTIFICATION_ID, builder.build())
        } catch (_: SecurityException) {
        }
    }

    private fun createAction(
        context: Context,
        actionString: String,
        label: String,
        requestCode: Int
    ): NotificationCompat.Action {
        val intent = Intent(context, TimerReceiver::class.java).apply {
            action = actionString
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Action.Builder(0, label, pendingIntent).build()
    }

    fun clearNotification() {
        val context = appContext ?: return
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
    }

    fun getStartOfToday(): Long {
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    fun getEndOfToday(): Long {
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 23)
            set(Calendar.MINUTE, 59)
            set(Calendar.SECOND, 59)
            set(Calendar.MILLISECOND, 999)
        }.timeInMillis
    }
}
