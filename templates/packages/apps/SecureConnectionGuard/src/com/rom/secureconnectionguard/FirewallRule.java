package com.rom.secureconnectionguard;

import org.json.JSONException;
import org.json.JSONObject;

final class FirewallRule {
    private static final String JSON_TARGET = "target";
    private static final String JSON_PREFIX = "prefix";

    final String targetIp;
    final int prefixLength;

    FirewallRule(String targetIp, int prefixLength) {
        this.targetIp = targetIp;
        this.prefixLength = prefixLength;
    }

    static FirewallRule fromInput(String input) {
        if (input == null) {
            return null;
        }
        String normalized = input.trim();
        if (normalized.isEmpty()) {
            return null;
        }

        String ipPart = normalized;
        int prefix = 32;
        int slash = normalized.indexOf('/');
        if (slash >= 0) {
            ipPart = normalized.substring(0, slash).trim();
            String prefixPart = normalized.substring(slash + 1).trim();
            if (prefixPart.isEmpty()) {
                return null;
            }
            try {
                prefix = Integer.parseInt(prefixPart);
            } catch (NumberFormatException e) {
                return null;
            }
        }

        if (!isValidIpv4(ipPart) || prefix < 0 || prefix > 32) {
            return null;
        }

        return new FirewallRule(ipPart, prefix);
    }

    boolean matchesIp(String destinationIp) {
        if (!isValidIpv4(destinationIp)) {
            return false;
        }
        long destination = ipv4ToLong(destinationIp);
        long target = ipv4ToLong(targetIp);
        long mask = prefixToMask(prefixLength);
        return (destination & mask) == (target & mask);
    }

    String displayValue() {
        if (prefixLength == 32) {
            return targetIp;
        }
        return targetIp + "/" + prefixLength;
    }

    JSONObject toJson() throws JSONException {
        JSONObject obj = new JSONObject();
        obj.put(JSON_TARGET, targetIp);
        obj.put(JSON_PREFIX, prefixLength);
        return obj;
    }

    static FirewallRule fromJson(JSONObject obj) {
        if (obj == null) {
            return null;
        }
        String target = obj.optString(JSON_TARGET, "");
        int prefix = obj.optInt(JSON_PREFIX, -1);
        if (!isValidIpv4(target) || prefix < 0 || prefix > 32) {
            return null;
        }
        return new FirewallRule(target, prefix);
    }

    @Override
    public boolean equals(Object other) {
        if (!(other instanceof FirewallRule)) {
            return false;
        }
        FirewallRule o = (FirewallRule) other;
        return targetIp.equals(o.targetIp) && prefixLength == o.prefixLength;
    }

    @Override
    public int hashCode() {
        return (targetIp + "#" + prefixLength).hashCode();
    }

    static boolean isValidIpv4(String ip) {
        String[] parts = ip.split("\\.");
        if (parts.length != 4) {
            return false;
        }
        for (String part : parts) {
            if (part.isEmpty() || part.length() > 3) {
                return false;
            }
            try {
                int value = Integer.parseInt(part);
                if (value < 0 || value > 255) {
                    return false;
                }
            } catch (NumberFormatException e) {
                return false;
            }
        }
        return true;
    }

    private static long ipv4ToLong(String ip) {
        String[] parts = ip.split("\\.");
        long result = 0;
        for (int i = 0; i < 4; i++) {
            result = (result << 8) | (Integer.parseInt(parts[i]) & 0xffL);
        }
        return result;
    }

    private static long prefixToMask(int prefixLength) {
        if (prefixLength == 0) {
            return 0L;
        }
        return 0xffffffffL << (32 - prefixLength) & 0xffffffffL;
    }
}
