package com.rom.secureconnectionguard;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.TextView;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

final class NewsListAdapter extends BaseAdapter {
    private final LayoutInflater inflater;
    private final List<NewsItem> items = new ArrayList<>();

    NewsListAdapter(LayoutInflater inflater) {
        this.inflater = inflater;
    }

    void setItems(List<NewsItem> values) {
        items.clear();
        if (values != null) {
            items.addAll(values);
        }
        notifyDataSetChanged();
    }

    NewsItem getNewsItem(int position) {
        if (position < 0 || position >= items.size()) {
            return null;
        }
        return items.get(position);
    }

    @Override
    public int getCount() {
        return items.size();
    }

    @Override
    public Object getItem(int position) {
        return getNewsItem(position);
    }

    @Override
    public long getItemId(int position) {
        return position;
    }

    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        View view = convertView;
        if (view == null) {
            view = inflater.inflate(R.layout.item_news, parent, false);
        }

        TextView title = view.findViewById(R.id.news_title);
        TextView meta = view.findViewById(R.id.news_meta);

        NewsItem item = items.get(position);
        title.setText(item.title);

        String date = "unknown-time";
        if (item.publishedMs > 0) {
            date = new SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US)
                    .format(new Date(item.publishedMs));
        }
        String source = item.source == null || item.source.isEmpty() ? "unknown-source" : item.source;
        meta.setText(date + "  " + source + "\n" + item.link);
        return view;
    }
}
