package com.rom.secureconnectionguard;

import org.json.JSONException;
import org.json.JSONObject;

final class NewsItem {
    private static final String JSON_TITLE = "title";
    private static final String JSON_LINK = "link";
    private static final String JSON_SOURCE = "source";
    private static final String JSON_PUBLISHED = "published";

    final String title;
    final String link;
    final String source;
    final long publishedMs;

    NewsItem(String title, String link, String source, long publishedMs) {
        this.title = title == null ? "" : title;
        this.link = link == null ? "" : link;
        this.source = source == null ? "" : source;
        this.publishedMs = publishedMs;
    }

    JSONObject toJson() throws JSONException {
        JSONObject obj = new JSONObject();
        obj.put(JSON_TITLE, title);
        obj.put(JSON_LINK, link);
        obj.put(JSON_SOURCE, source);
        obj.put(JSON_PUBLISHED, publishedMs);
        return obj;
    }

    static NewsItem fromJson(JSONObject obj) {
        if (obj == null) {
            return null;
        }
        String title = obj.optString(JSON_TITLE, "");
        String link = obj.optString(JSON_LINK, "");
        String source = obj.optString(JSON_SOURCE, "");
        long published = obj.optLong(JSON_PUBLISHED, 0L);
        if (title.isEmpty() || link.isEmpty()) {
            return null;
        }
        return new NewsItem(title, link, source, published);
    }
}
