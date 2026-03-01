package com.rom.secureconnectionguard;

import android.content.Context;
import android.content.SharedPreferences;
import java.util.ArrayList;
import java.util.List;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

final class NewsRepository {
    private static final String PREF_NAME = "secure_connection_guard_news";
    private static final String KEY_ITEMS = "news_items";
    private static final String KEY_LAST_UPDATE = "news_last_update";
    private static final int MAX_ITEMS = 80;

    private final SharedPreferences prefs;

    NewsRepository(Context context) {
        prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
    }

    synchronized List<NewsItem> loadItems() {
        String raw = prefs.getString(KEY_ITEMS, "[]");
        List<NewsItem> items = new ArrayList<>();
        try {
            JSONArray arr = new JSONArray(raw);
            for (int i = 0; i < arr.length(); i++) {
                NewsItem item = NewsItem.fromJson(arr.optJSONObject(i));
                if (item != null) {
                    items.add(item);
                }
            }
        } catch (JSONException ignored) {
            // Ignore bad store data and return an empty list.
        }
        return items;
    }

    synchronized void saveItems(List<NewsItem> items) {
        JSONArray arr = new JSONArray();
        int max = Math.min(items.size(), MAX_ITEMS);
        for (int i = 0; i < max; i++) {
            try {
                arr.put(items.get(i).toJson());
            } catch (JSONException ignored) {
                // Skip invalid item.
            }
        }
        prefs.edit()
                .putString(KEY_ITEMS, arr.toString())
                .putLong(KEY_LAST_UPDATE, System.currentTimeMillis())
                .apply();
    }

    synchronized long getLastUpdateMs() {
        return prefs.getLong(KEY_LAST_UPDATE, 0L);
    }
}
