package com.rom.secureconnectionguard;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.List;
import java.util.concurrent.TimeUnit;

final class SystemFirewallBackend {
    private static final String CHAIN_NAME = "SCG_BLOCK4";
    private static final long COMMAND_TIMEOUT_SECONDS = 8L;

    boolean isAvailable() {
        return runShell("iptables -L OUTPUT -n >/dev/null 2>&1", false);
    }

    boolean enable(List<FirewallRule> rules, boolean blockSuspiciousPorts) {
        if (!isAvailable()) {
            return false;
        }

        boolean ok = true;
        runShell("iptables -N " + CHAIN_NAME, true);
        ok &= runShell("iptables -F " + CHAIN_NAME, false);

        if (!runShell("iptables -C OUTPUT -j " + CHAIN_NAME, true)) {
            ok &= runShell("iptables -I OUTPUT 1 -j " + CHAIN_NAME, false);
        }

        if (rules != null) {
            for (FirewallRule rule : rules) {
                if (rule == null) {
                    continue;
                }
                String destination = rule.displayValue();
                ok &= runShell("iptables -A " + CHAIN_NAME + " -d " + destination + " -j REJECT", false);
            }
        }

        if (blockSuspiciousPorts) {
            int[] suspiciousPorts = PolicyStore.suspiciousPortsArray();
            for (int port : suspiciousPorts) {
                ok &= runShell("iptables -A " + CHAIN_NAME + " -p tcp --dport " + port + " -j REJECT", false);
                ok &= runShell("iptables -A " + CHAIN_NAME + " -p udp --dport " + port + " -j REJECT", false);
            }
        }

        return ok;
    }

    boolean disable() {
        boolean ok = true;
        ok &= runShell("iptables -D OUTPUT -j " + CHAIN_NAME, true);
        ok &= runShell("iptables -F " + CHAIN_NAME, true);
        ok &= runShell("iptables -X " + CHAIN_NAME, true);
        return ok;
    }

    private boolean runShell(String command, boolean ignoreFailure) {
        boolean success = execute(new String[] {"su", "0", "sh", "-c", command});
        if (!success) {
            success = execute(new String[] {"sh", "-c", command});
        }
        return success || ignoreFailure;
    }

    private boolean execute(String[] command) {
        Process process = null;
        try {
            process = new ProcessBuilder(command).redirectErrorStream(true).start();
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(process.getInputStream()))) {
                while (reader.readLine() != null) {
                    // Consume process output to avoid blocking.
                }
            }
            boolean finished = process.waitFor(COMMAND_TIMEOUT_SECONDS, TimeUnit.SECONDS);
            if (!finished) {
                process.destroyForcibly();
                return false;
            }
            return process.exitValue() == 0;
        } catch (Exception e) {
            return false;
        } finally {
            if (process != null) {
                process.destroy();
            }
        }
    }

}
