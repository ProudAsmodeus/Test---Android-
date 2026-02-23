package com.rom.secureconnectionguard;

import android.content.Context;
import android.content.SharedPreferences;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

final class PolicyStore {
    static final String BACKEND_SYSTEM = "system";
    static final String BACKEND_VPN = "vpn";
    static final String BACKEND_NONE = "none";

    private static final String PREF_NAME = "secure_connection_guard";
    private static final String KEY_RULES = "rules";
    private static final String KEY_CONNECTIONS = "connections";
    private static final String KEY_PROTECTION_ENABLED = "protection_enabled";
    private static final String KEY_BLOCK_SUSPICIOUS = "block_suspicious";
    private static final String KEY_SYSTEM_BACKEND_ENABLED = "system_backend_enabled";
    private static final String KEY_LAST_ACTIVE_BACKEND = "last_active_backend";
    private static final int MAX_CONNECTION_HISTORY = 300;

    private static final Set<Integer> SUSPICIOUS_PORTS = new HashSet<>();

    static {
        SUSPICIOUS_PORTS.add(23);
        SUSPICIOUS_PORTS.add(25);
        SUSPICIOUS_PORTS.add(135);
        SUSPICIOUS_PORTS.add(139);
        SUSPICIOUS_PORTS.add(445);
        SUSPICIOUS_PORTS.add(3389);
        SUSPICIOUS_PORTS.add(4444);
        SUSPICIOUS_PORTS.add(5555);
        SUSPICIOUS_PORTS.add(6667);
        SUSPICIOUS_PORTS.add(1900);
    }

    private final SharedPreferences prefs;

    PolicyStore(Context context) {
        prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
    }

    synchronized List<FirewallRule> getRules() {
        String raw = prefs.getString(KEY_RULES, "[]");
        List<FirewallRule> rules = new ArrayList<>();
        try {
            JSONArray array = new JSONArray(raw);
            for (int i = 0; i < array.length(); i++) {
                JSONObject obj = array.optJSONObject(i);
                FirewallRule rule = FirewallRule.fromJson(obj);
                if (rule != null) {
                    rules.add(rule);
                }
            }
        } catch (JSONException ignored) {
            // Invalid preference state should not crash the guard app.
        }
        return rules;
    }

    synchronized boolean addRule(FirewallRule candidate) {
        if (candidate == null) {
            return false;
        }
        List<FirewallRule> rules = getRules();
        if (rules.contains(candidate)) {
            return false;
        }
        rules.add(candidate);
        saveRules(rules);
        return true;
    }

    synchronized void removeRule(FirewallRule rule) {
        if (rule == null) {
            return;
        }
        List<FirewallRule> rules = getRules();
        rules.remove(rule);
        saveRules(rules);
    }

    synchronized boolean isProtectionEnabled() {
        return prefs.getBoolean(KEY_PROTECTION_ENABLED, false);
    }

    synchronized void setProtectionEnabled(boolean enabled) {
        prefs.edit().putBoolean(KEY_PROTECTION_ENABLED, enabled).apply();
    }

    synchronized boolean isBlockSuspiciousEnabled() {
        return prefs.getBoolean(KEY_BLOCK_SUSPICIOUS, true);
    }

    synchronized void setBlockSuspiciousEnabled(boolean enabled) {
        prefs.edit().putBoolean(KEY_BLOCK_SUSPICIOUS, enabled).apply();
    }

    synchronized boolean isSystemBackendEnabled() {
        return prefs.getBoolean(KEY_SYSTEM_BACKEND_ENABLED, true);
    }

    synchronized void setSystemBackendEnabled(boolean enabled) {
        prefs.edit().putBoolean(KEY_SYSTEM_BACKEND_ENABLED, enabled).apply();
    }

    synchronized String getLastActiveBackend() {
        return prefs.getString(KEY_LAST_ACTIVE_BACKEND, BACKEND_NONE);
    }

    synchronized void setLastActiveBackend(String backend) {
        String normalized = backend == null ? BACKEND_NONE : backend;
        prefs.edit().putString(KEY_LAST_ACTIVE_BACKEND, normalized).apply();
    }

    synchronized void addConnection(ConnectionRecord record) {
        if (record == null) {
            return;
        }
        List<ConnectionRecord> all = getConnections();
        all.add(0, record);
        if (all.size() > MAX_CONNECTION_HISTORY) {
            all = all.subList(0, MAX_CONNECTION_HISTORY);
        }
        saveConnections(all);
    }

    synchronized List<ConnectionRecord> getConnections() {
        String raw = prefs.getString(KEY_CONNECTIONS, "[]");
        List<ConnectionRecord> records = new ArrayList<>();
        try {
            JSONArray array = new JSONArray(raw);
            for (int i = 0; i < array.length(); i++) {
                JSONObject obj = array.optJSONObject(i);
                ConnectionRecord record = ConnectionRecord.fromJson(obj);
                if (record != null) {
                    records.add(record);
                }
            }
        } catch (JSONException ignored) {
            // Ignore corrupt state and return best-effort list.
        }
        return records;
    }

    synchronized void clearConnections() {
        prefs.edit().putString(KEY_CONNECTIONS, "[]").apply();
    }

    synchronized boolean shouldBlock(ConnectionRecord record) {
        if (record == null || !FirewallRule.isValidIpv4(record.destinationIp)) {
            return false;
        }

        List<FirewallRule> rules = getRules();
        for (FirewallRule rule : rules) {
            if (rule.matchesIp(record.destinationIp)) {
                return true;
            }
        }

        return isBlockSuspiciousEnabled() && isSuspicious(record);
    }

    synchronized String blockReason(ConnectionRecord record) {
        List<FirewallRule> rules = getRules();
        for (FirewallRule rule : rules) {
            if (rule.matchesIp(record.destinationIp)) {
                return "Matched rule " + rule.displayValue();
            }
        }
        if (isBlockSuspiciousEnabled() && isSuspicious(record)) {
            return "Suspicious destination/port";
        }
        return "";
    }

    static int[] suspiciousPortsArray() {
        int[] values = new int[SUSPICIOUS_PORTS.size()];
        int i = 0;
        for (Integer port : SUSPICIOUS_PORTS) {
            values[i++] = port.intValue();
        }
        return values;
    }

    private boolean isSuspicious(ConnectionRecord record) {
        if (record == null) {
            return false;
        }
        if (!"TCP".equals(record.protocol) && !"UDP".equals(record.protocol)) {
            return true;
        }
        return SUSPICIOUS_PORTS.contains(record.destinationPort);
    }

    private void saveRules(List<FirewallRule> rules) {
        JSONArray array = new JSONArray();
        for (FirewallRule rule : rules) {
            try {
                array.put(rule.toJson());
            } catch (JSONException ignored) {
                // Skip invalid item.
            }
        }
        prefs.edit().putString(KEY_RULES, array.toString()).apply();
    }

    private void saveConnections(List<ConnectionRecord> records) {
        JSONArray array = new JSONArray();
        for (ConnectionRecord record : records) {
            try {
                array.put(record.toJson());
            } catch (JSONException ignored) {
                // Skip invalid item.
            }
        }
        prefs.edit().putString(KEY_CONNECTIONS, array.toString()).apply();
    }
}
