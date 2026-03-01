package com.rom.secureconnectionguard;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.VpnService;
import android.os.Build;
import android.os.ParcelFileDescriptor;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

public final class ConnectionFirewallService extends VpnService {
    static final String ACTION_START = "com.rom.secureconnectionguard.action.START";
    static final String ACTION_STOP = "com.rom.secureconnectionguard.action.STOP";

    private static final String NOTIFICATION_CHANNEL_ID = "secure_connection_guard";
    private static final int NOTIFICATION_ID = 47021;

    private final Object vpnLock = new Object();
    private volatile boolean running;
    private Thread workerThread;
    private ParcelFileDescriptor vpnInterface;
    private PolicyStore policyStore;
    private ProcNetScanner procNetScanner;
    private SystemFirewallBackend systemFirewallBackend;
    private final Map<Integer, String> uidToPackageCache = new HashMap<>();
    private final Map<String, Long> systemSeenConnections = new HashMap<>();
    private boolean usingSystemBackend;

    static Intent buildStartIntent(Context context) {
        Intent intent = new Intent(context, ConnectionFirewallService.class);
        intent.setAction(ACTION_START);
        return intent;
    }

    static Intent buildStopIntent(Context context) {
        Intent intent = new Intent(context, ConnectionFirewallService.class);
        intent.setAction(ACTION_STOP);
        return intent;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        policyStore = new PolicyStore(this);
        procNetScanner = new ProcNetScanner();
        systemFirewallBackend = new SystemFirewallBackend();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String action = intent != null ? intent.getAction() : ACTION_START;
        if (ACTION_STOP.equals(action)) {
            policyStore.setProtectionEnabled(false);
            policyStore.setLastActiveBackend(PolicyStore.BACKEND_NONE);
            stopProtection();
            stopForeground(Service.STOP_FOREGROUND_REMOVE);
            stopSelf();
            return START_NOT_STICKY;
        }

        startForeground(NOTIFICATION_ID, buildNotification());
        policyStore.setProtectionEnabled(true);
        startProtection();
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        stopProtection();
        super.onDestroy();
    }

    private void startProtection() {
        synchronized (vpnLock) {
            if (running) {
                return;
            }

            boolean preferSystemBackend = policyStore.isSystemBackendEnabled();
            if (preferSystemBackend && systemFirewallBackend.isAvailable()) {
                List<FirewallRule> rules = policyStore.getRules();
                boolean blockSuspiciousPorts = policyStore.isBlockSuspiciousEnabled();
                if (systemFirewallBackend.enable(rules, blockSuspiciousPorts)) {
                    usingSystemBackend = true;
                    running = true;
                    policyStore.setLastActiveBackend(PolicyStore.BACKEND_SYSTEM);
                    workerThread = new Thread(this::systemMonitorLoop, "SecureConnectionGuardSystemMonitor");
                    workerThread.start();
                    return;
                } else {
                    // Ensure partial iptables state is removed before fallback.
                    systemFirewallBackend.disable();
                }
            }

            usingSystemBackend = false;
            boolean vpnOk = startVpnProtectionLocked();
            if (vpnOk) {
                policyStore.setLastActiveBackend(PolicyStore.BACKEND_VPN);
            } else {
                policyStore.setLastActiveBackend(PolicyStore.BACKEND_NONE);
            }
        }
    }

    private void stopProtection() {
        synchronized (vpnLock) {
            running = false;

            if (workerThread != null) {
                workerThread.interrupt();
                workerThread = null;
            }

            if (usingSystemBackend) {
                systemFirewallBackend.disable();
                usingSystemBackend = false;
                systemSeenConnections.clear();
            }

            if (vpnInterface != null) {
                try {
                    vpnInterface.close();
                } catch (IOException ignored) {
                    // Ignore close errors during shutdown.
                }
                vpnInterface = null;
            }
        }
    }

    private boolean startVpnProtectionLocked() {
        Builder builder = new Builder();
        builder.setSession("Secure Connection Guard");
        builder.setMtu(1500);
        builder.addAddress("10.33.0.1", 32);

        List<FirewallRule> rules = policyStore.getRules();
        if (rules.isEmpty()) {
            // Keep VPN viable while minimizing routing impact when no explicit rule exists.
            builder.addRoute("203.0.113.255", 32);
        } else {
            for (FirewallRule rule : rules) {
                builder.addRoute(rule.targetIp, rule.prefixLength);
            }
        }

        vpnInterface = builder.establish();
        if (vpnInterface == null) {
            return false;
        }

        running = true;
        workerThread = new Thread(this::captureLoop, "SecureConnectionGuardCapture");
        workerThread.start();
        return true;
    }

    private void systemMonitorLoop() {
        while (running) {
            long now = System.currentTimeMillis();
            List<ProcNetScanner.ActiveConnection> activeConnections = procNetScanner.scanConnections();
            for (ProcNetScanner.ActiveConnection conn : activeConnections) {
                String key = conn.protocol + "|" + conn.destinationIp + "|" + conn.destinationPort + "|" + conn.uid;
                Long lastSeen = systemSeenConnections.get(key);
                if (lastSeen != null && now - lastSeen < 15000L) {
                    continue;
                }
                systemSeenConnections.put(key, now);

                String sourceApp = resolveSourceApp(conn.uid);
                ConnectionRecord base = new ConnectionRecord(
                        now,
                        conn.destinationIp,
                        conn.destinationPort,
                        conn.protocol,
                        false,
                        conn.state,
                        conn.uid,
                        sourceApp,
                        "",
                        ""
                );
                boolean blocked = policyStore.shouldBlock(base);
                String reason = blocked ? policyStore.blockReason(base) : conn.state;
                ConnectionRecord record = new ConnectionRecord(
                        base.timestampMs,
                        base.destinationIp,
                        base.destinationPort,
                        base.protocol,
                        blocked,
                        reason,
                        base.sourceUid,
                        base.sourceApp,
                        base.countryCode,
                        base.countryName
                );
                policyStore.addConnection(record);
            }

            trimSystemSeenMap(now);

            try {
                Thread.sleep(5000L);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
    }

    private void trimSystemSeenMap(long now) {
        Iterator<Map.Entry<String, Long>> iterator = systemSeenConnections.entrySet().iterator();
        while (iterator.hasNext()) {
            Map.Entry<String, Long> entry = iterator.next();
            if (now - entry.getValue() > 60000L) {
                iterator.remove();
            }
        }
    }

    private void captureLoop() {
        ParcelFileDescriptor currentInterface;
        synchronized (vpnLock) {
            currentInterface = vpnInterface;
        }
        if (currentInterface == null) {
            return;
        }

        try (FileInputStream input = new FileInputStream(currentInterface.getFileDescriptor())) {
            byte[] packet = new byte[32767];
            while (running) {
                int length = input.read(packet);
                if (length <= 0) {
                    continue;
                }

                ParsedPacket parsed = ParsedPacket.fromIpv4(packet, length);
                if (parsed == null || !FirewallRule.isValidIpv4(parsed.destinationIp)) {
                    continue;
                }

                int sourceUid = procNetScanner.findUidForConnection(
                        parsed.protocol,
                        parsed.destinationIp,
                        parsed.destinationPort
                );

                ConnectionRecord tentative = new ConnectionRecord(
                        System.currentTimeMillis(),
                        parsed.destinationIp,
                        parsed.destinationPort,
                        parsed.protocol,
                        false,
                        "",
                        sourceUid,
                        resolveSourceApp(sourceUid),
                        "",
                        ""
                );

                boolean policyBlock = policyStore.shouldBlock(tentative);
                String reason = policyStore.blockReason(tentative);
                if (!policyBlock) {
                    // This template service currently enforces by routing blocked targets into the
                    // local VPN interface; packets captured here are intentionally dropped.
                    reason = "Captured by enforcement route";
                }

                ConnectionRecord finalRecord = new ConnectionRecord(
                        tentative.timestampMs,
                        tentative.destinationIp,
                        tentative.destinationPort,
                        tentative.protocol,
                        true,
                        reason,
                        tentative.sourceUid,
                        tentative.sourceApp,
                        tentative.countryCode,
                        tentative.countryName
                );
                policyStore.addConnection(finalRecord);
            }
        } catch (IOException ignored) {
            // Expected during interface teardown.
        }
    }

    private String resolveSourceApp(int uid) {
        if (uid <= 0) {
            return "";
        }
        String cached = uidToPackageCache.get(uid);
        if (cached != null) {
            return cached;
        }

        PackageManager pm = getPackageManager();
        String[] packages = pm.getPackagesForUid(uid);
        if (packages == null || packages.length == 0) {
            uidToPackageCache.put(uid, "");
            return "";
        }

        String selected = packages[0];
        uidToPackageCache.put(uid, selected);
        return selected;
    }

    private Notification buildNotification() {
        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    getString(R.string.app_name),
                    NotificationManager.IMPORTANCE_LOW
            );
            nm.createNotificationChannel(channel);
        }

        Intent openIntent = new Intent(this, MainActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(
                this,
                0,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        Notification.Builder builder = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? new Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
                : new Notification.Builder(this);

        return builder
                .setSmallIcon(android.R.drawable.stat_sys_warning)
                .setContentTitle(getString(R.string.notification_title))
                .setContentText(getString(R.string.notification_text))
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build();
    }

    private static final class ParsedPacket {
        final String destinationIp;
        final int destinationPort;
        final String protocol;

        ParsedPacket(String destinationIp, int destinationPort, String protocol) {
            this.destinationIp = destinationIp;
            this.destinationPort = destinationPort;
            this.protocol = protocol;
        }

        static ParsedPacket fromIpv4(byte[] packet, int length) {
            if (length < 20) {
                return null;
            }

            int version = (packet[0] >> 4) & 0x0f;
            if (version != 4) {
                return null;
            }

            int ihl = (packet[0] & 0x0f) * 4;
            if (ihl < 20 || length < ihl) {
                return null;
            }

            int protocolCode = packet[9] & 0xff;
            String protocol = "OTHER";
            int port = -1;

            if (protocolCode == 6) {
                protocol = "TCP";
            } else if (protocolCode == 17) {
                protocol = "UDP";
            }

            if ((protocolCode == 6 || protocolCode == 17) && length >= ihl + 4) {
                port = ((packet[ihl + 2] & 0xff) << 8) | (packet[ihl + 3] & 0xff);
            }

            String destinationIp = (packet[16] & 0xff)
                    + "." + (packet[17] & 0xff)
                    + "." + (packet[18] & 0xff)
                    + "." + (packet[19] & 0xff);
            return new ParsedPacket(destinationIp, port, protocol);
        }
    }
}
