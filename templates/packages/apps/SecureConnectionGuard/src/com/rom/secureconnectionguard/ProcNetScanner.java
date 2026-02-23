package com.rom.secureconnectionguard;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

final class ProcNetScanner {
    private static final int MAX_RESULTS = 200;

    static final class ActiveConnection {
        final String destinationIp;
        final int destinationPort;
        final String protocol;
        final String state;
        final int uid;

        ActiveConnection(String destinationIp, int destinationPort, String protocol, String state, int uid) {
            this.destinationIp = destinationIp;
            this.destinationPort = destinationPort;
            this.protocol = protocol;
            this.state = state;
            this.uid = uid;
        }

        String toDisplayLine() {
            return protocol + " " + destinationIp + ":" + destinationPort + " [" + state + "] uid=" + uid;
        }
    }

    List<ActiveConnection> scanConnections() {
        List<ActiveConnection> items = new ArrayList<>();
        scanFile(items, "/proc/net/tcp", "TCP");
        scanFile(items, "/proc/net/tcp6", "TCP6");
        scanFile(items, "/proc/net/udp", "UDP");
        scanFile(items, "/proc/net/udp6", "UDP6");
        Collections.sort(items, (a, b) -> a.toDisplayLine().compareToIgnoreCase(b.toDisplayLine()));
        return items;
    }

    List<String> scanConnectionLines() {
        List<ActiveConnection> items = scanConnections();

        List<String> lines = new ArrayList<>();
        for (int i = 0; i < items.size() && i < MAX_RESULTS; i++) {
            lines.add(items.get(i).toDisplayLine());
        }
        return lines;
    }

    int findUidForConnection(String protocol, String destinationIp, int destinationPort) {
        List<ActiveConnection> items = scanConnections();
        for (ActiveConnection item : items) {
            boolean protocolMatch = item.protocol.equalsIgnoreCase(protocol)
                    || item.protocol.startsWith(protocol);
            if (protocolMatch && destinationIp.equals(item.destinationIp)
                    && destinationPort == item.destinationPort) {
                return item.uid;
            }
        }
        return -1;
    }

    private void scanFile(List<ActiveConnection> out, String path, String protocol) {
        File file = new File(path);
        if (!file.exists() || !file.canRead()) {
            return;
        }

        try (BufferedReader reader = new BufferedReader(new FileReader(file))) {
            String line;
            boolean first = true;
            while ((line = reader.readLine()) != null) {
                if (first) {
                    first = false;
                    continue;
                }
                ActiveConnection item = parseLine(line, protocol);
                if (item != null) {
                    out.add(item);
                }
            }
        } catch (IOException ignored) {
            // Not all builds permit reading /proc/net tables for apps.
        }
    }

    private ActiveConnection parseLine(String line, String protocol) {
        String[] cols = line.trim().split("\\s+");
        if (cols.length < 8) {
            return null;
        }

        String remote = cols[2];
        String stateHex = cols[3];
        String uidText = cols[7];

        String[] remoteParts = remote.split(":");
        if (remoteParts.length != 2) {
            return null;
        }

        String ipHex = remoteParts[0];
        String portHex = remoteParts[1];

        int port;
        int uid;
        try {
            port = Integer.parseInt(portHex, 16);
            uid = Integer.parseInt(uidText);
        } catch (NumberFormatException e) {
            return null;
        }

        String ip = decodeAddress(ipHex, protocol.endsWith("6"));
        if (ip == null || "0.0.0.0".equals(ip) || "::".equals(ip)) {
            return null;
        }
        return new ActiveConnection(ip, port, protocol, decodeState(stateHex), uid);
    }

    private String decodeAddress(String hex, boolean ipv6) {
        if (ipv6) {
            if (hex.length() != 32) {
                return null;
            }
            StringBuilder builder = new StringBuilder();
            for (int i = 0; i < 8; i++) {
                if (i > 0) {
                    builder.append(':');
                }
                int idx = i * 4;
                builder.append(hex.substring(idx, idx + 4));
            }
            return builder.toString();
        }

        if (hex.length() != 8) {
            return null;
        }
        StringBuilder ip = new StringBuilder();
        for (int i = 0; i < 4; i++) {
            if (i > 0) {
                ip.append('.');
            }
            int idx = (3 - i) * 2;
            int octet = Integer.parseInt(hex.substring(idx, idx + 2), 16);
            ip.append(octet);
        }
        return ip.toString();
    }

    private String decodeState(String stateHex) {
        if ("01".equals(stateHex)) {
            return "ESTABLISHED";
        } else if ("02".equals(stateHex)) {
            return "SYN_SENT";
        } else if ("03".equals(stateHex)) {
            return "SYN_RECV";
        } else if ("04".equals(stateHex)) {
            return "FIN_WAIT1";
        } else if ("05".equals(stateHex)) {
            return "FIN_WAIT2";
        } else if ("06".equals(stateHex)) {
            return "TIME_WAIT";
        } else if ("07".equals(stateHex)) {
            return "CLOSE";
        } else if ("08".equals(stateHex)) {
            return "CLOSE_WAIT";
        } else if ("09".equals(stateHex)) {
            return "LAST_ACK";
        } else if ("0A".equals(stateHex)) {
            return "LISTEN";
        } else if ("0B".equals(stateHex)) {
            return "CLOSING";
        }
        return stateHex;
    }
}
