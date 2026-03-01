package com.rom.secureconnectionguard;

import java.util.Arrays;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

final class RiskIntelligence {
    private static final Set<String> HIGH_RISK_COUNTRY_CODES = new HashSet<>(
            Arrays.asList("RU", "CN", "KP", "IR", "BY")
    );

    private static final String[] SKETCHY_APP_KEYWORDS = new String[] {
            "hack",
            "crack",
            "mod",
            "inject",
            "rat",
            "spy",
            "cheat",
            "exploit",
            "sniffer",
            "patcher"
    };

    private RiskIntelligence() {
    }

    static boolean isHighRiskCountry(String countryCode) {
        if (countryCode == null || countryCode.trim().isEmpty()) {
            return false;
        }
        return HIGH_RISK_COUNTRY_CODES.contains(countryCode.trim().toUpperCase(Locale.US));
    }

    static boolean isSketchyAppName(String appName) {
        if (appName == null || appName.trim().isEmpty()) {
            return false;
        }
        String normalized = appName.toLowerCase(Locale.US);
        for (String keyword : SKETCHY_APP_KEYWORDS) {
            if (normalized.contains(keyword)) {
                return true;
            }
        }
        return false;
    }
}
