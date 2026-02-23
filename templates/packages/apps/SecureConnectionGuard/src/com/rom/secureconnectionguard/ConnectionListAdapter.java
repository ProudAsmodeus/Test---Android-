package com.rom.secureconnectionguard;

import android.content.Context;
import android.graphics.Color;
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

final class ConnectionListAdapter extends BaseAdapter {
    private final LayoutInflater inflater;
    private final List<ConnectionUiItem> items = new ArrayList<>();
    private final Context context;

    ConnectionListAdapter(Context context) {
        this.context = context;
        this.inflater = LayoutInflater.from(context);
    }

    void setItems(List<ConnectionUiItem> values) {
        items.clear();
        if (values != null) {
            items.addAll(values);
        }
        notifyDataSetChanged();
    }

    ConnectionUiItem getItemAt(int position) {
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
        return getItemAt(position);
    }

    @Override
    public long getItemId(int position) {
        return position;
    }

    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        View view = convertView;
        if (view == null) {
            view = inflater.inflate(R.layout.item_connection, parent, false);
        }

        TextView primary = view.findViewById(R.id.connection_primary);
        TextView secondary = view.findViewById(R.id.connection_secondary);

        ConnectionUiItem item = items.get(position);
        ConnectionRecord record = item.record;

        String severityText;
        int color;
        if (item.severity == ConnectionUiItem.Severity.HIGH) {
            severityText = context.getString(R.string.severity_high);
            color = Color.parseColor("#C62828");
        } else if (item.severity == ConnectionUiItem.Severity.MEDIUM) {
            severityText = context.getString(R.string.severity_medium);
            color = Color.parseColor("#EF6C00");
        } else {
            severityText = context.getString(R.string.severity_low);
            color = Color.parseColor("#2E7D32");
        }

        String endpoint = record.protocol + " " + record.destinationIp;
        if (record.destinationPort > 0) {
            endpoint += ":" + record.destinationPort;
        }

        String sourceApp = record.sourceApp == null || record.sourceApp.isEmpty()
                ? context.getString(R.string.source_app_unknown)
                : record.sourceApp;
        String country = record.countryCode == null || record.countryCode.isEmpty()
                ? context.getString(R.string.risk_country_unknown)
                : (record.countryCode + " " + record.countryName);

        SimpleDateFormat sdf = new SimpleDateFormat("MM-dd HH:mm:ss", Locale.US);
        String time = sdf.format(new Date(record.timestampMs));

        primary.setText("[" + severityText + "] " + endpoint);
        primary.setTextColor(color);
        secondary.setText(time + "  src=" + sourceApp + "  dst-country=" + country
                + "  " + item.severityReason);
        secondary.setTextColor(color);
        return view;
    }
}
