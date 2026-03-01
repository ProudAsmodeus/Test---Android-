package com.rom.secureconnectionguard;

import android.util.Xml;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.xmlpull.v1.XmlPullParser;

final class NewsFetcher {
    private static final int CONNECT_TIMEOUT_MS = 8000;
    private static final int READ_TIMEOUT_MS = 10000;

    private static final String[] FEED_URLS = new String[] {
            "https://news.google.com/rss/search?q=Android+app+vulnerability+OR+Android+malware&hl=en-US&gl=US&ceid=US:en",
            "https://news.google.com/rss/search?q=Android+zero-day+attack+OR+Android+banking+trojan&hl=en-US&gl=US&ceid=US:en"
    };

    List<NewsItem> fetchLatest() {
        Map<String, NewsItem> dedupeByLink = new HashMap<>();
        for (String feedUrl : FEED_URLS) {
            List<NewsItem> items = fetchFeed(feedUrl);
            for (NewsItem item : items) {
                if (!dedupeByLink.containsKey(item.link)) {
                    dedupeByLink.put(item.link, item);
                }
            }
        }

        List<NewsItem> all = new ArrayList<>(dedupeByLink.values());
        Collections.sort(all, (a, b) -> Long.compare(b.publishedMs, a.publishedMs));
        if (all.size() > 80) {
            return new ArrayList<>(all.subList(0, 80));
        }
        return all;
    }

    private List<NewsItem> fetchFeed(String feedUrl) {
        HttpURLConnection conn = null;
        InputStream input = null;
        try {
            URL url = new URL(feedUrl);
            conn = (HttpURLConnection) url.openConnection();
            conn.setConnectTimeout(CONNECT_TIMEOUT_MS);
            conn.setReadTimeout(READ_TIMEOUT_MS);
            conn.setRequestMethod("GET");
            conn.setRequestProperty("User-Agent", "SecureConnectionGuard/1.0");

            int code = conn.getResponseCode();
            if (code < 200 || code >= 300) {
                return Collections.emptyList();
            }

            input = conn.getInputStream();
            XmlPullParser parser = Xml.newPullParser();
            parser.setInput(input, null);
            return parseRss(parser);
        } catch (Exception e) {
            return Collections.emptyList();
        } finally {
            if (input != null) {
                try {
                    input.close();
                } catch (Exception ignored) {
                    // Ignore close errors.
                }
            }
            if (conn != null) {
                conn.disconnect();
            }
        }
    }

    private List<NewsItem> parseRss(XmlPullParser parser) throws Exception {
        List<NewsItem> items = new ArrayList<>();
        boolean insideItem = false;
        String title = "";
        String link = "";
        String source = "";
        long published = 0L;

        int eventType = parser.getEventType();
        while (eventType != XmlPullParser.END_DOCUMENT) {
            if (eventType == XmlPullParser.START_TAG) {
                String tag = parser.getName();
                if ("item".equalsIgnoreCase(tag)) {
                    insideItem = true;
                    title = "";
                    link = "";
                    source = "";
                    published = 0L;
                } else if (insideItem && "title".equalsIgnoreCase(tag)) {
                    title = safeNextText(parser);
                } else if (insideItem && "link".equalsIgnoreCase(tag)) {
                    link = safeNextText(parser);
                } else if (insideItem && "source".equalsIgnoreCase(tag)) {
                    source = safeNextText(parser);
                } else if (insideItem && "pubDate".equalsIgnoreCase(tag)) {
                    published = parsePubDate(safeNextText(parser));
                }
            } else if (eventType == XmlPullParser.END_TAG) {
                String tag = parser.getName();
                if ("item".equalsIgnoreCase(tag)) {
                    insideItem = false;
                    if (!title.isEmpty() && !link.isEmpty()) {
                        items.add(new NewsItem(
                                title,
                                link,
                                source,
                                published > 0 ? published : System.currentTimeMillis()));
                    }
                }
            }
            eventType = parser.next();
        }
        return items;
    }

    private String safeNextText(XmlPullParser parser) {
        try {
            return parser.nextText().trim();
        } catch (Exception e) {
            return "";
        }
    }

    private long parsePubDate(String value) {
        if (value == null || value.isEmpty()) {
            return 0L;
        }
        String[] formats = new String[] {
                "EEE, dd MMM yyyy HH:mm:ss z",
                "EEE, dd MMM yyyy HH:mm z"
        };
        for (String format : formats) {
            try {
                Date date = new SimpleDateFormat(format, Locale.US).parse(value);
                if (date != null) {
                    return date.getTime();
                }
            } catch (ParseException ignored) {
                // Try next format.
            }
        }
        return 0L;
    }
}
