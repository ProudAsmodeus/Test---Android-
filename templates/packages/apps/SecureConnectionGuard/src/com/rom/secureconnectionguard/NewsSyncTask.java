package com.rom.secureconnectionguard;

import android.content.Context;
import java.util.List;

final class NewsSyncTask {
    private NewsSyncTask() {
    }

    static boolean run(Context context) {
        NewsFetcher fetcher = new NewsFetcher();
        List<NewsItem> items = fetcher.fetchLatest();
        if (items.isEmpty()) {
            return false;
        }
        NewsRepository repo = new NewsRepository(context.getApplicationContext());
        repo.saveItems(items);
        return true;
    }
}
