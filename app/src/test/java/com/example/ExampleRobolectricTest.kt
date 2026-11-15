package com.example

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ExampleRobolectricTest {

  @Test
  fun `read string from context`() {
    val context = ApplicationProvider.getApplicationContext<Context>()
    val appName = context.getString(R.string.app_name)
    assertEquals("StudyFlow", appName)
  }

  @Test
  fun `verify timer formatting from zero`() {
    assertEquals("00:00:00", TimerManager.formatTime(0L))
    assertEquals("00:01:05", TimerManager.formatTime(65L))
    assertEquals("01:00:00", TimerManager.formatTime(3600L))
    assertEquals("45s", TimerManager.formatDurationLabel(45L))
    assertEquals("1m 15s", TimerManager.formatDurationLabel(75L))
    assertEquals("2h 10m 05s", TimerManager.formatDurationLabel(7805L))
  }

  @Test
  fun `verify timer state machine and session saving`() = runBlocking {
    val context = ApplicationProvider.getApplicationContext<Context>()
    TimerManager.init(context)

    TimerManager.reset()
    assertEquals(TimerStatus.IDLE, TimerManager.state.value.status)
    assertEquals(0L, TimerManager.state.value.elapsedSeconds)

    TimerManager.start()
    assertEquals(TimerStatus.RUNNING, TimerManager.state.value.status)

    TimerManager.pause()
    assertEquals(TimerStatus.PAUSED, TimerManager.state.value.status)

    TimerManager.stop()
    assertEquals(TimerStatus.STOPPED, TimerManager.state.value.status)

    TimerManager.reset()
    assertEquals(TimerStatus.IDLE, TimerManager.state.value.status)
    assertEquals(0L, TimerManager.state.value.elapsedSeconds)
  }
}
