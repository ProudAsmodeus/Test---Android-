package com.rom.secureconnectionguard;

import android.content.Context;
import android.content.SharedPreferences;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import org.json.JSONObject;

final class GeoIpResolver {
    static final class CountryInfo {
        final String countryCode;
        final String countryName;

        CountryInfo(String countryCode, String countryName) {
            this.countryCode = countryCode == null ? "" : countryCode;
            this.countryName = countryName == null ? "" : countryName;
        }
    }

    private static final String PREF_NAME = "secure_connection_guard_geo";
    private static final String KEY_CACHE_JSON = "cache_json";
    private static final long CACHE_TTL_MS = 24L * 60L * 60L * 1000L;

    private final SharedPreferences prefs;
    private final Map<String, CacheEntry> cache = new HashMap<>();

    private static final class CacheEntry {
        final CountryInfo info;
        final long timestampMs;

        CacheEntry(CountryInfo info, long timestampMs) {
            this.info = info;
            this.timestampMs = timestampMs;
        }
    }

    GeoIpResolver(Context context) {
        prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
        loadCache();
    }

    synchronized CountryInfo resolve(String ip) {
        if (FirewallRule.isPrivateOrReservedIpv4(ip)) {
            return new CountryInfo("", "");
        }
        long now = System.currentTimeMillis();
        CacheEntry cached = cache.get(ip);
        if (cached != null && now - cached.timestampMs <= CACHE_TTL_MS) {
            return cached.info;
        }

        CountryInfo fetched = fetchCountryInfo(ip);
        if (fetched != null) {
            cache.put(ip, new CacheEntry(fetched, now));
            persistCache();
            return fetched;
        }

        if (cached != null) {
            return cached.info;
        }
        return new CountryInfo("", "");
    }

    private CountryInfo fetchCountryInfo(String ip) {
        if (!FirewallRule.isValidIpv4(ip) || FirewallRule.isPrivateOrReservedIpv4(ip)) {
            return new CountryInfo("", "");
        }
        HttpURLConnection conn = null;
        try {
            URL url = new URL("https://ipwho.is/" + ip + "?fields=success,country,country_code");
            conn = (HttpURLConnection) url.openConnection();
            conn.setConnectTimeout(5000);
            conn.setReadTimeout(5000);
            conn.setRequestMethod("GET");
            conn.setRequestProperty("User-Agent", "SecureConnectionGuard/1.0");

            int code = conn.getResponseCode();
            if (code < 200 || code >= 300) {
                return null;
            }

            StringBuilder body = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(conn.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    body.append(line);
                }
            }
            JSONObject root = new JSONObject(body.toString());
            if (!root.optBoolean("success", false)) {
                return null;
            }
            String countryCode = root.optString("country_code", "");
            String countryName = root.optString("country", "");
            return new CountryInfo(countryCode, countryName);
        } catch (Exception e) {
            return null;
        } finally {
            if (conn != null) {
                conn.disconnect();
            }
        }
    }

    private synchronized void loadCache() {
        cache.clear();
        String raw = prefs.getString(KEY_CACHE_JSON, "{}");
        try {
            JSONObject root = new JSONObject(raw);
            Iterator<String> keys = root.keys();
            while (keys.hasNext()) {
                String ip = keys.next();
                JSONObject obj = root.optJSONObject(ip);
                if (obj == null) {
                    continue;
                }
                long ts = obj.optLong("ts", 0L);
                CountryInfo info = new CountryInfo(
                        obj.optString("country_code", ""),
                        obj.optString("country_name", "")
                );
                cache.put(ip, new CacheEntry(info, ts));
            }
        } catch (Exception ignored) {
            // Ignore malformed cache and rebuild over time.
        }
    }

    private synchronized void persistCache() {
        JSONObject root = new JSONObject();
        long now = System.currentTimeMillis();
        Iterator<Map.Entry<String, CacheEntry>> iterator = cache.entrySet().iterator();
        while (iterator.hasNext()) {
            Map.Entry<String, CacheEntry> entry = iterator.next();
            if (now - entry.getValue().timestampMs > CACHE_TTL_MS * 2) {
                iterator.remove();
                continue;
            }
            try {
                JSONObject obj = new JSONObject();
                obj.put("ts", entry.getValue().timestampMs);
                obj.put("country_code", entry.getValue().info.countryCode);
                obj.put("country_name", entry.getValue().info.countryName);
                root.put(entry.getKey(), obj);
            } catch (Exception ignored) {
                // Skip malformed entry.
            }
        }
        prefs.edit().putString(KEY_CACHE_JSON, root.toString()).apply();
    }
}
