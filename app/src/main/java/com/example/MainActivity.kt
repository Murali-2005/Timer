package com.example

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.HourglassTop
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.outlined.History
import androidx.compose.material.icons.outlined.HourglassTop
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.example.data.StudySession
import com.example.ui.theme.ButtonDisabledText
import com.example.ui.theme.ButtonLightGrey
import com.example.ui.theme.ButtonLightGreyDisabled
import com.example.ui.theme.ButtonLightText
import com.example.ui.theme.DarkGrey700
import com.example.ui.theme.DarkGrey800
import com.example.ui.theme.DarkGrey850
import com.example.ui.theme.DarkGrey900
import com.example.ui.theme.LightGrey400
import com.example.ui.theme.MyApplicationTheme
import com.example.ui.theme.PureWhite
import com.example.ui.theme.SilverGrey200
import com.example.ui.theme.TrueBlack

enum class AppScreen {
    TIMER,
    STUDY_LOG
}

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        TimerManager.init(applicationContext)

        // Show over lockscreen and turn screen on
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }

        enableEdgeToEdge()

        setContent {
            MyApplicationTheme {
                val timerState by TimerManager.state.collectAsState()

                // Keep screen awake while timer is running
                LaunchedEffect(timerState.status) {
                    if (timerState.status == TimerStatus.RUNNING) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                }

                // Check & request notification permission for lockscreen controls
                val context = LocalContext.current
                val permissionLauncher = rememberLauncherForActivityResult(
                    contract = ActivityResultContracts.RequestPermission()
                ) {}

                LaunchedEffect(Unit) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (ContextCompat.checkSelfPermission(
                                context,
                                Manifest.permission.POST_NOTIFICATIONS
                            ) != PackageManager.PERMISSION_GRANTED
                        ) {
                            permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                        }
                    }
                }

                MainNavigationContainer()
            }
        }
    }
}

@Composable
fun MainNavigationContainer() {
    var currentScreen by rememberSaveable { mutableStateOf(AppScreen.TIMER) }

    BackHandler(enabled = currentScreen != AppScreen.TIMER) {
        currentScreen = AppScreen.TIMER
    }

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        bottomBar = {
            NavigationBar(
                containerColor = DarkGrey900,
                tonalElevation = 8.dp,
                modifier = Modifier.testTag("app_navigation_bar")
            ) {
                NavigationBarItem(
                    selected = currentScreen == AppScreen.TIMER,
                    onClick = { currentScreen = AppScreen.TIMER },
                    icon = {
                        Icon(
                            imageVector = if (currentScreen == AppScreen.TIMER) Icons.Filled.HourglassTop else Icons.Outlined.HourglassTop,
                            contentDescription = "Timer"
                        )
                    },
                    label = {
                        Text(
                            text = "Timer",
                            style = MaterialTheme.typography.labelSmall.copy(
                                fontWeight = if (currentScreen == AppScreen.TIMER) FontWeight.Bold else FontWeight.Normal
                            )
                        )
                    },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = TrueBlack,
                        selectedTextColor = PureWhite,
                        indicatorColor = PureWhite,
                        unselectedIconColor = LightGrey400,
                        unselectedTextColor = LightGrey400
                    ),
                    modifier = Modifier.testTag("nav_tab_timer")
                )

                NavigationBarItem(
                    selected = currentScreen == AppScreen.STUDY_LOG,
                    onClick = { currentScreen = AppScreen.STUDY_LOG },
                    icon = {
                        Icon(
                            imageVector = if (currentScreen == AppScreen.STUDY_LOG) Icons.Filled.History else Icons.Outlined.History,
                            contentDescription = "Study Log"
                        )
                    },
                    label = {
                        Text(
                            text = "Study Log",
                            style = MaterialTheme.typography.labelSmall.copy(
                                fontWeight = if (currentScreen == AppScreen.STUDY_LOG) FontWeight.Bold else FontWeight.Normal
                            )
                        )
                    },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = TrueBlack,
                        selectedTextColor = PureWhite,
                        indicatorColor = PureWhite,
                        unselectedIconColor = LightGrey400,
                        unselectedTextColor = LightGrey400
                    ),
                    modifier = Modifier.testTag("nav_tab_log")
                )
            }
        },
        containerColor = TrueBlack
    ) { innerPadding ->
        AnimatedContent(
            targetState = currentScreen,
            transitionSpec = { fadeIn() togetherWith fadeOut() },
            label = "screen_transition",
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) { screen ->
            when (screen) {
                AppScreen.TIMER -> FirstDisplayTimerOnlyScreen()
                AppScreen.STUDY_LOG -> SecondDisplayStudyLogScreen()
            }
        }
    }
}

/**
 * First Display: ONLY the Timer and Buttons.
 * Distraction-free, pure black, grey, and white.
 */
@Composable
fun FirstDisplayTimerOnlyScreen() {
    val timerState by TimerManager.state.collectAsState()

    val isIdle = timerState.status == TimerStatus.IDLE
    val isRunning = timerState.status == TimerStatus.RUNNING
    val isPaused = timerState.status == TimerStatus.PAUSED

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 24.dp, vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        // Top breathing room
        Spacer(modifier = Modifier.height(36.dp))

        // Center: Primary Visual Focus - Prominent White Digital Clock
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(
                text = TimerManager.formatTime(timerState.elapsedSeconds),
                style = MaterialTheme.typography.displayLarge.copy(
                    fontSize = 74.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    letterSpacing = (-2).sp
                ),
                color = PureWhite,
                modifier = Modifier.testTag("timer_display")
            )
        }

        // Bottom: The 4 Buttons (Start, Pause, Stop, Reset)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Row 1: START and PAUSE
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                TimerActionButton(
                    text = if (isPaused) "RESUME" else "START",
                    icon = Icons.Default.PlayArrow,
                    enabled = !isRunning,
                    onClick = { TimerManager.start() },
                    testTag = "start_button",
                    modifier = Modifier.weight(1f)
                )

                TimerActionButton(
                    text = "PAUSE",
                    icon = Icons.Default.Pause,
                    enabled = isRunning,
                    onClick = { TimerManager.pause() },
                    testTag = "pause_button",
                    modifier = Modifier.weight(1f)
                )
            }

            // Row 2: STOP and RESET
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                TimerActionButton(
                    text = "STOP",
                    icon = Icons.Default.Stop,
                    enabled = isRunning || isPaused,
                    onClick = { TimerManager.stop() },
                    testTag = "stop_button",
                    modifier = Modifier.weight(1f)
                )

                TimerActionButton(
                    text = "RESET",
                    icon = Icons.Default.Refresh,
                    enabled = !isIdle && !isRunning,
                    onClick = { TimerManager.reset() },
                    testTag = "reset_button",
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

/**
 * Consistent Grey Action Button:
 * - Steady base grey color
 * - Lighter when clicked / pressed
 * - Dull when not usable (disabled)
 */
@Composable
fun TimerActionButton(
    text: String,
    icon: ImageVector,
    enabled: Boolean,
    onClick: () -> Unit,
    testTag: String,
    modifier: Modifier = Modifier
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()

    // Steady grey base, lighter when clicked, slightly dull when disabled
    val bgColor = when {
        !enabled -> Color(0xFF222225) // Dull when not usable
        isPressed -> Color(0xFF54545C) // A little bit lighter on click
        else -> Color(0xFF333338)      // Uniform steady grey
    }

    val contentColor = when {
        !enabled -> Color(0xFF66666E) // Dull text/icon
        isPressed -> PureWhite        // Lighter highlight
        else -> SilverGrey200         // Clean off-white
    }

    val borderColor = if (enabled) Color(0xFF45454C) else Color(0xFF28282D)

    Button(
        onClick = onClick,
        enabled = enabled,
        interactionSource = interactionSource,
        colors = ButtonDefaults.buttonColors(
            containerColor = bgColor,
            contentColor = contentColor,
            disabledContainerColor = bgColor,
            disabledContentColor = contentColor
        ),
        border = androidx.compose.foundation.BorderStroke(1.dp, borderColor),
        shape = RoundedCornerShape(14.dp),
        modifier = modifier
            .height(52.dp)
            .testTag(testTag)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
                tint = contentColor
            )
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                text = text,
                style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                color = contentColor
            )
        }
    }
}

/**
 * Second Display: All remaining info.
 * - Total time studied today
 * - How many times timer was started today
 * - Log of each session with start time, stop time, and duration
 */
@Composable
fun SecondDisplayStudyLogScreen() {
    val timerState by TimerManager.state.collectAsState()

    val todaySessions by TimerManager.getTodaySessionsFlow().collectAsState(initial = emptyList())
    val todayTotalSeconds by TimerManager.getTodayTotalSecondsFlow().collectAsState(initial = 0L)
    val todaySessionCount by TimerManager.getTodaySessionCountFlow().collectAsState(initial = 0)

    val isRunning = timerState.status == TimerStatus.RUNNING
    val isPaused = timerState.status == TimerStatus.PAUSED

    // Includes currently running session in today's total
    val liveTotalSeconds = (todayTotalSeconds ?: 0L) + if (isRunning || isPaused) timerState.elapsedSeconds else 0L

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        item {
            Spacer(modifier = Modifier.height(20.dp))

            // Header Title
            Text(
                text = "STUDY LOG",
                style = MaterialTheme.typography.titleMedium.copy(
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 2.sp
                ),
                color = LightGrey400,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp)
            )

            // Total Studied Today Summary Card
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("daily_total_card"),
                shape = RoundedCornerShape(18.dp),
                colors = CardDefaults.cardColors(containerColor = DarkGrey900),
                border = androidx.compose.foundation.BorderStroke(1.dp, DarkGrey800)
            ) {
                Column(modifier = Modifier.padding(20.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.CalendarToday,
                                contentDescription = null,
                                tint = LightGrey400,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "TOTAL STUDIED TODAY",
                                style = MaterialTheme.typography.labelSmall.copy(
                                    fontWeight = FontWeight.Bold,
                                    letterSpacing = 1.sp
                                ),
                                color = LightGrey400
                            )
                        }

                        // Times Started Counter Badge
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .background(DarkGrey800)
                                .padding(horizontal = 10.dp, vertical = 4.dp)
                        ) {
                            Text(
                                text = "$todaySessionCount started",
                                style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                                color = SilverGrey200
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    Text(
                        text = TimerManager.formatDurationLabel(liveTotalSeconds),
                        style = MaterialTheme.typography.headlineMedium.copy(
                            fontWeight = FontWeight.Bold,
                            fontSize = 34.sp
                        ),
                        color = PureWhite
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Section Label
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = "TODAY'S SESSIONS (${todaySessions.size})",
                    style = MaterialTheme.typography.labelMedium.copy(
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.sp
                    ),
                    color = LightGrey400
                )
            }

            Spacer(modifier = Modifier.height(12.dp))
        }

        // Sessions List Items
        if (todaySessions.isEmpty()) {
            item {
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 12.dp),
                    shape = RoundedCornerShape(14.dp),
                    color = DarkGrey900,
                    border = androidx.compose.foundation.BorderStroke(1.dp, DarkGrey800)
                ) {
                    Column(
                        modifier = Modifier.padding(28.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(
                            imageVector = Icons.Default.AccessTime,
                            contentDescription = null,
                            tint = DarkGrey700,
                            modifier = Modifier.size(40.dp)
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        Text(
                            text = "No study sessions recorded today yet",
                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                            color = LightGrey400
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Start and stop the timer to log your study times.",
                            style = MaterialTheme.typography.bodySmall,
                            color = DarkGrey700
                        )
                    }
                }
            }
        } else {
            itemsIndexed(todaySessions, key = { _, s -> s.id }) { index, session ->
                val sessionNumber = todaySessions.size - index
                val startTimeFormatted = TimerManager.formatTimeOfDay(session.startTimeMillis)
                val stopTimeFormatted = TimerManager.formatTimeOfDay(session.stopTimeMillis)
                val durationFormatted = TimerManager.formatDurationLabel(session.durationSeconds)

                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("session_record_${session.id}"),
                    shape = RoundedCornerShape(14.dp),
                    color = DarkGrey900,
                    border = androidx.compose.foundation.BorderStroke(1.dp, DarkGrey800)
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.weight(1f)
                        ) {
                            // Session index badge
                            Box(
                                modifier = Modifier
                                    .size(38.dp)
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(DarkGrey800),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = "#$sessionNumber",
                                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                                    color = SilverGrey200
                                )
                            }

                            Spacer(modifier = Modifier.width(14.dp))

                            Column {
                                Text(
                                    text = "Started: $startTimeFormatted",
                                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                    color = PureWhite
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = "Stopped: $stopTimeFormatted",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = LightGrey400
                                )
                            }
                        }

                        // Duration Pill
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .background(DarkGrey850)
                                .border(1.dp, DarkGrey700, RoundedCornerShape(8.dp))
                                .padding(horizontal = 12.dp, vertical = 6.dp)
                        ) {
                            Text(
                                text = durationFormatted,
                                style = MaterialTheme.typography.labelMedium.copy(
                                    fontWeight = FontWeight.Bold,
                                    fontFamily = FontFamily.Monospace
                                ),
                                color = PureWhite
                            )
                        }
                    }
                }
                Spacer(modifier = Modifier.height(10.dp))
            }
        }

        item {
            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}
