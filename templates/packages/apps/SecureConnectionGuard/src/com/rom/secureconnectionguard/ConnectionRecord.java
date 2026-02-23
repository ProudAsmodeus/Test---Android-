package com.rom.secureconnectionguard;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import org.json.JSONException;
import org.json.JSONObject;

final class ConnectionRecord {
    private static final String JSON_TIMESTAMP = "timestamp";
    private static final String JSON_DESTINATION = "destination";
    private static final String JSON_PORT = "port";
    private static final String JSON_PROTOCOL = "protocol";
    private static final String JSON_BLOCKED = "blocked";
    private static final String JSON_REASON = "reason";
    private static final String JSON_SOURCE_UID = "source_uid";
    private static final String JSON_SOURCE_APP = "source_app";
    private static final String JSON_COUNTRY_CODE = "country_code";
    private static final String JSON_COUNTRY_NAME = "country_name";

    final long timestampMs;
    final String destinationIp;
    final int destinationPort;
    final String protocol;
    final boolean blocked;
    final String reason;
    final int sourceUid;
    final String sourceApp;
    final String countryCode;
    final String countryName;

    ConnectionRecord(long timestampMs, String destinationIp, int destinationPort, String protocol,
            boolean blocked, String reason, int sourceUid, String sourceApp,
            String countryCode, String countryName) {
        this.timestampMs = timestampMs;
        this.destinationIp = destinationIp;
        this.destinationPort = destinationPort;
        this.protocol = protocol;
        this.blocked = blocked;
        this.reason = reason;
        this.sourceUid = sourceUid;
        this.sourceApp = sourceApp;
        this.countryCode = countryCode;
        this.countryName = countryName;
    }

    JSONObject toJson() throws JSONException {
        JSONObject obj = new JSONObject();
        obj.put(JSON_TIMESTAMP, timestampMs);
        obj.put(JSON_DESTINATION, destinationIp);
        obj.put(JSON_PORT, destinationPort);
        obj.put(JSON_PROTOCOL, protocol);
        obj.put(JSON_BLOCKED, blocked);
        obj.put(JSON_REASON, reason);
        obj.put(JSON_SOURCE_UID, sourceUid);
        obj.put(JSON_SOURCE_APP, sourceApp);
        obj.put(JSON_COUNTRY_CODE, countryCode);
        obj.put(JSON_COUNTRY_NAME, countryName);
        return obj;
    }

    static ConnectionRecord fromJson(JSONObject obj) {
        if (obj == null) {
            return null;
        }
        long timestamp = obj.optLong(JSON_TIMESTAMP, 0L);
        String destination = obj.optString(JSON_DESTINATION, "");
        int port = obj.optInt(JSON_PORT, -1);
        String protocol = obj.optString(JSON_PROTOCOL, "UNKNOWN");
        boolean blocked = obj.optBoolean(JSON_BLOCKED, false);
        String reason = obj.optString(JSON_REASON, "");
        int sourceUid = obj.optInt(JSON_SOURCE_UID, -1);
        String sourceApp = obj.optString(JSON_SOURCE_APP, "");
        String countryCode = obj.optString(JSON_COUNTRY_CODE, "");
        String countryName = obj.optString(JSON_COUNTRY_NAME, "");
        if (destination.isEmpty()) {
            return null;
        }
        return new ConnectionRecord(
                timestamp,
                destination,
                port,
                protocol,
                blocked,
                reason,
                sourceUid,
                sourceApp,
                countryCode,
                countryName
        );
    }

    String displayLine() {
        SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US);
        String time = format.format(new Date(timestampMs));
        String status = blocked ? "BLOCK" : "ALLOW";
        StringBuilder line = new StringBuilder();
        line.append(time).append("  ");
        line.append(protocol).append(" ");
        line.append(destinationIp);
        if (destinationPort > 0) {
            line.append(":").append(destinationPort);
        }
        line.append("  ").append(status);
        if (reason != null && !reason.isEmpty()) {
            line.append(" (").append(reason).append(")");
        }
        if (sourceApp != null && !sourceApp.isEmpty()) {
            line.append(" ").append("src=").append(sourceApp);
        }
        if (countryCode != null && !countryCode.isEmpty()) {
            line.append(" ").append("country=").append(countryCode);
        }
        return line.toString();
    }
}
