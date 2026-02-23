package com.rom.secureconnectionguard;

final class ConnectionUiItem {
    enum Severity {
        LOW,
        MEDIUM,
        HIGH
    }

    final ConnectionRecord record;
    final Severity severity;
    final String severityReason;

    ConnectionUiItem(ConnectionRecord record, Severity severity, String severityReason) {
        this.record = record;
        this.severity = severity;
        this.severityReason = severityReason;
    }
}
