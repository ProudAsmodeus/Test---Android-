package com.rom.secureconnectionguard;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public final class NewsUpdateReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null) {
            return;
        }
        String action = intent.getAction();
        if (!NewsUpdateScheduler.ACTION_UPDATE_NEWS.equals(action)) {
            return;
        }

        final PendingResult pendingResult = goAsync();
        final Context app = context.getApplicationContext();
        Thread worker = new Thread(() -> {
            try {
                NewsSyncTask.run(app);
            } finally {
                pendingResult.finish();
            }
        }, "SecureConnectionGuardNewsUpdate");
        worker.start();
    }
}
