package com.rom.adguardcontrol;

import android.content.ContentResolver;
import android.content.Context;
import android.provider.Settings;
import java.util.Locale;

final class PrivateDnsController {
    static final String FREE_ENDPOINT = "dns.adguard-dns.com";

    private static final String KEY_PRIVATE_DNS_MODE = "private_dns_mode";
    private static final String KEY_PRIVATE_DNS_SPECIFIER = "private_dns_specifier";
    private static final String MODE_OFF = "off";
    private static final String MODE_HOSTNAME = "hostname";

    private final Context context;

    PrivateDnsController(Context context) {
        this.context = context.getApplicationContext();
    }

    boolean enableFree() {
        return setHostname(FREE_ENDPOINT);
    }

    boolean enablePaid(String host) {
        if (!isValidHostname(host)) {
            return false;
        }
        return setHostname(host.trim().toLowerCase(Locale.US));
    }

    boolean disable() {
        ContentResolver cr = context.getContentResolver();
        boolean ok1 = Settings.Global.putString(cr, KEY_PRIVATE_DNS_MODE, MODE_OFF);
        boolean ok2 = Settings.Global.putString(cr, KEY_PRIVATE_DNS_SPECIFIER, "");
        return ok1 && ok2;
    }

    boolean isFreeActive() {
        return MODE_HOSTNAME.equals(getCurrentMode())
                && FREE_ENDPOINT.equalsIgnoreCase(getCurrentSpecifier());
    }

    boolean isPaidActive(String paidHost) {
        if (!isValidHostname(paidHost)) {
            return false;
        }
        return MODE_HOSTNAME.equals(getCurrentMode())
                && paidHost.trim().equalsIgnoreCase(getCurrentSpecifier());
    }

    String getCurrentMode() {
        String mode = Settings.Global.getString(context.getContentResolver(), KEY_PRIVATE_DNS_MODE);
        return mode == null ? MODE_OFF : mode;
    }

    String getCurrentSpecifier() {
        String spec = Settings.Global.getString(context.getContentResolver(), KEY_PRIVATE_DNS_SPECIFIER);
        return spec == null ? "" : spec.trim();
    }

    static boolean isValidHostname(String host) {
        if (host == null) {
            return false;
        }
        String value = host.trim();
        if (value.isEmpty() || value.length() > 253 || !value.contains(".")) {
            return false;
        }
        String[] labels = value.split("\\.");
        for (String label : labels) {
            if (label.isEmpty() || label.length() > 63) {
                return false;
            }
            for (int i = 0; i < label.length(); i++) {
                char c = label.charAt(i);
                boolean ok = (c >= 'a' && c <= 'z')
                        || (c >= 'A' && c <= 'Z')
                        || (c >= '0' && c <= '9')
                        || c == '-';
                if (!ok) {
                    return false;
                }
            }
            if (label.charAt(0) == '-' || label.charAt(label.length() - 1) == '-') {
                return false;
            }
        }
        return true;
    }

    private boolean setHostname(String host) {
        if (!isValidHostname(host)) {
            return false;
        }
        ContentResolver cr = context.getContentResolver();
        String normalized = host.trim().toLowerCase(Locale.US);
        boolean ok1 = Settings.Global.putString(cr, KEY_PRIVATE_DNS_SPECIFIER, normalized);
        boolean ok2 = Settings.Global.putString(cr, KEY_PRIVATE_DNS_MODE, MODE_HOSTNAME);
        return ok1 && ok2;
    }
}
