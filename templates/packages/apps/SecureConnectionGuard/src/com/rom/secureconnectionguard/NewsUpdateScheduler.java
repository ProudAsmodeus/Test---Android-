package com.rom.secureconnectionguard;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;

final class NewsUpdateScheduler {
    static final String ACTION_UPDATE_NEWS = "com.rom.secureconnectionguard.action.UPDATE_NEWS";
    private static final int REQUEST_CODE = 78441;

    private NewsUpdateScheduler() {
    }

    static void scheduleHourly(Context context) {
        Context app = context.getApplicationContext();
        AlarmManager am = (AlarmManager) app.getSystemService(Context.ALARM_SERVICE);
        if (am == null) {
            return;
        }

        Intent intent = new Intent(app, NewsUpdateReceiver.class);
        intent.setAction(ACTION_UPDATE_NEWS);
        PendingIntent pi = PendingIntent.getBroadcast(
                app,
                REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        long triggerAt = System.currentTimeMillis() + 5L * 60L * 1000L;
        am.setInexactRepeating(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                AlarmManager.INTERVAL_HOUR,
                pi
        );
    }
}
