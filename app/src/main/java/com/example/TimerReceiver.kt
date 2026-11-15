package com.example

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class TimerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        TimerManager.init(context)
        when (intent?.action) {
            TimerManager.ACTION_START -> TimerManager.start()
            TimerManager.ACTION_PAUSE -> TimerManager.pause()
            TimerManager.ACTION_STOP -> TimerManager.stop()
            TimerManager.ACTION_RESET -> TimerManager.reset()
        }
    }
}
