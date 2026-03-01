package com.rom.adguardcontrol;

import android.content.Context;
import android.content.SharedPreferences;

final class AdGuardSettingsStore {
    private static final String PREF_NAME = "adguard_control_prefs";
    private static final String KEY_PAID_ENDPOINT = "paid_endpoint";

    private final SharedPreferences prefs;

    AdGuardSettingsStore(Context context) {
        prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
    }

    synchronized String getPaidEndpoint() {
        return prefs.getString(KEY_PAID_ENDPOINT, "").trim();
    }

    synchronized void setPaidEndpoint(String endpoint) {
        String normalized = endpoint == null ? "" : endpoint.trim();
        prefs.edit().putString(KEY_PAID_ENDPOINT, normalized).apply();
    }
}
