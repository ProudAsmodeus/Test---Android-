package com.rom.secureconnectionguard;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.net.VpnService;
import android.os.Build;
import android.os.Bundle;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ListView;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.Toast;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.List;

public final class MainActivity extends Activity {
    private static final int REQUEST_VPN_PERMISSION = 1023;
    private static final int COUNTRY_ENRICH_LIMIT = 40;

    private PolicyStore policyStore;
    private ProcNetScanner procNetScanner;
    private GeoIpResolver geoIpResolver;
    private NewsRepository newsRepository;

    private TextView statusView;
    private TextView newsStatusView;
    private Switch protectionSwitch;
    private Switch blockSuspiciousSwitch;
    private Switch systemBackendSwitch;
    private EditText ruleInput;
    private ListView rulesList;
    private ListView connectionsList;
    private ListView newsList;

    private ArrayAdapter<String> rulesAdapter;
    private ConnectionListAdapter connectionsAdapter;
    private NewsListAdapter newsAdapter;
    private final List<FirewallRule> currentRules = new ArrayList<>();

    private boolean listenersAttached;
    private boolean suppressSwitchCallbacks;
    private android.view.View firewallSection;
    private android.view.View newsSection;
    private Button tabFirewallButton;
    private Button tabNewsButton;
    private final Object refreshLock = new Object();
    private volatile boolean refreshingConnections;
    private volatile boolean refreshingNews;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        policyStore = new PolicyStore(this);
        procNetScanner = new ProcNetScanner();
        geoIpResolver = new GeoIpResolver(this);
        newsRepository = new NewsRepository(this);
        NewsUpdateScheduler.scheduleHourly(this);

        tabFirewallButton = findViewById(R.id.tab_firewall_button);
        tabNewsButton = findViewById(R.id.tab_news_button);
        firewallSection = findViewById(R.id.firewall_section);
        newsSection = findViewById(R.id.news_section);
        statusView = findViewById(R.id.status_text);
        newsStatusView = findViewById(R.id.news_status_text);
        protectionSwitch = findViewById(R.id.protection_switch);
        blockSuspiciousSwitch = findViewById(R.id.block_suspicious_switch);
        systemBackendSwitch = findViewById(R.id.system_backend_switch);
        ruleInput = findViewById(R.id.rule_input);
        rulesList = findViewById(R.id.rules_list);
        connectionsList = findViewById(R.id.connections_list);
        newsList = findViewById(R.id.news_list);
        Button addRuleButton = findViewById(R.id.add_rule_button);
        Button refreshButton = findViewById(R.id.refresh_button);
        Button refreshNewsButton = findViewById(R.id.refresh_news_button);

        rulesAdapter = new ArrayAdapter<>(this, android.R.layout.simple_list_item_1, new ArrayList<>());
        rulesList.setAdapter(rulesAdapter);

        connectionsAdapter = new ConnectionListAdapter(this);
        connectionsList.setAdapter(connectionsAdapter);

        newsAdapter = new NewsListAdapter(getLayoutInflater());
        newsList.setAdapter(newsAdapter);

        tabFirewallButton.setOnClickListener(v -> showFirewallSection());
        tabNewsButton.setOnClickListener(v -> showNewsSection());

        addRuleButton.setOnClickListener(v -> addRuleFromInput());
        refreshButton.setOnClickListener(v -> refreshConnectionList(true));
        refreshNewsButton.setOnClickListener(v -> refreshNewsNow());

        rulesList.setOnItemLongClickListener((parent, view, position, id) -> {
            if (position >= 0 && position < currentRules.size()) {
                FirewallRule rule = currentRules.get(position);
                policyStore.removeRule(rule);
                Toast.makeText(this, R.string.rule_removed, Toast.LENGTH_SHORT).show();
                refreshRulesList();
                restartProtectionIfEnabled();
            }
            return true;
        });

        connectionsList.setOnItemLongClickListener((parent, view, position, id) -> {
            ConnectionUiItem item = connectionsAdapter.getItemAt(position);
            String ip = item != null ? item.record.destinationIp : null;
            if (ip == null) {
                return true;
            }
            FirewallRule rule = FirewallRule.fromInput(ip);
            if (rule != null && policyStore.addRule(rule)) {
                Toast.makeText(this, getString(R.string.rule_added) + " " + ip, Toast.LENGTH_SHORT).show();
                refreshRulesList();
                restartProtectionIfEnabled();
            } else {
                Toast.makeText(this, R.string.rule_already_exists, Toast.LENGTH_SHORT).show();
            }
            return true;
        });

        newsList.setOnItemClickListener((parent, view, position, id) -> {
            NewsItem item = newsAdapter.getNewsItem(position);
            if (item == null || item.link == null || item.link.isEmpty()) {
                return;
            }
            try {
                Intent open = new Intent(Intent.ACTION_VIEW, Uri.parse(item.link));
                startActivity(open);
            } catch (Exception ignored) {
                // Ignore invalid deep links in upstream feeds.
            }
        });

        showFirewallSection();
    }

    @Override
    protected void onResume() {
        super.onResume();
        NewsUpdateScheduler.scheduleHourly(this);
        refreshUiFromStore();
        refreshNewsFromStore();
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != REQUEST_VPN_PERMISSION) {
            return;
        }
        if (resultCode == RESULT_OK) {
            startProtectionService();
        } else {
            protectionSwitch.setChecked(false);
            policyStore.setProtectionEnabled(false);
            updateStatus();
            Toast.makeText(this, R.string.vpn_permission_required, Toast.LENGTH_SHORT).show();
        }
    }

    private void refreshUiFromStore() {
        boolean protectionEnabled = policyStore.isProtectionEnabled();
        boolean blockSuspiciousEnabled = policyStore.isBlockSuspiciousEnabled();
        boolean systemBackendEnabled = policyStore.isSystemBackendEnabled();

        if (!listenersAttached) {
            protectionSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
                if (suppressSwitchCallbacks) {
                    return;
                }
                policyStore.setProtectionEnabled(isChecked);
                if (isChecked) {
                    if (policyStore.isSystemBackendEnabled()) {
                        startProtectionService();
                    } else {
                        requestVpnAndStart();
                    }
                } else {
                    stopProtectionService();
                }
                updateStatus();
            });

            blockSuspiciousSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
                if (suppressSwitchCallbacks) {
                    return;
                }
                policyStore.setBlockSuspiciousEnabled(isChecked);
                restartProtectionIfEnabled();
            });

            systemBackendSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
                if (suppressSwitchCallbacks) {
                    return;
                }
                policyStore.setSystemBackendEnabled(isChecked);
                restartProtectionIfEnabled();
                updateStatus();
            });

            listenersAttached = true;
        }

        suppressSwitchCallbacks = true;
        protectionSwitch.setChecked(protectionEnabled);
        blockSuspiciousSwitch.setChecked(blockSuspiciousEnabled);
        systemBackendSwitch.setChecked(systemBackendEnabled);
        suppressSwitchCallbacks = false;
        updateStatus();
        refreshRulesList();
        refreshConnectionList(false);
    }

    private void showFirewallSection() {
        firewallSection.setVisibility(android.view.View.VISIBLE);
        newsSection.setVisibility(android.view.View.GONE);
        tabFirewallButton.setEnabled(false);
        tabNewsButton.setEnabled(true);
    }

    private void showNewsSection() {
        firewallSection.setVisibility(android.view.View.GONE);
        newsSection.setVisibility(android.view.View.VISIBLE);
        tabFirewallButton.setEnabled(true);
        tabNewsButton.setEnabled(false);
    }

    private void updateStatus() {
        String status = policyStore.isProtectionEnabled()
                ? getString(R.string.status_protection_on)
                : getString(R.string.status_protection_off);
        String backendValue = policyStore.getLastActiveBackend();
        String backend;
        if (!policyStore.isProtectionEnabled()) {
            backend = getString(R.string.status_backend_inactive);
        } else if (PolicyStore.BACKEND_SYSTEM.equals(backendValue)) {
            backend = getString(R.string.status_backend_system);
        } else if (PolicyStore.BACKEND_VPN.equals(backendValue)) {
            backend = getString(R.string.status_backend_vpn);
        } else {
            backend = policyStore.isSystemBackendEnabled()
                    ? getString(R.string.status_backend_system)
                    : getString(R.string.status_backend_vpn);
        }
        statusView.setText(
                getString(R.string.status_prefix) + status + "\n"
                        + getString(R.string.status_backend_prefix) + backend);
    }

    private void addRuleFromInput() {
        String raw = ruleInput.getText() != null ? ruleInput.getText().toString() : "";
        FirewallRule rule = FirewallRule.fromInput(raw);
        if (rule == null) {
            Toast.makeText(this, R.string.invalid_rule, Toast.LENGTH_SHORT).show();
            return;
        }

        if (policyStore.addRule(rule)) {
            ruleInput.setText("");
            Toast.makeText(this, R.string.rule_added, Toast.LENGTH_SHORT).show();
            refreshRulesList();
            restartProtectionIfEnabled();
        } else {
            Toast.makeText(this, R.string.rule_already_exists, Toast.LENGTH_SHORT).show();
        }
    }

    private void refreshRulesList() {
        currentRules.clear();
        currentRules.addAll(policyStore.getRules());

        rulesAdapter.clear();
        if (currentRules.isEmpty()) {
            rulesAdapter.add("No blocking rules configured.");
        } else {
            for (FirewallRule rule : currentRules) {
                rulesAdapter.add(rule.displayValue());
            }
        }
        rulesAdapter.notifyDataSetChanged();
    }

    private void refreshConnectionList(boolean userRequestedRefresh) {
        synchronized (refreshLock) {
            if (refreshingConnections) {
                return;
            }
            refreshingConnections = true;
        }

        Thread worker = new Thread(() -> {
            List<ConnectionUiItem> items = new ArrayList<>();
            try {
                List<ConnectionRecord> history = policyStore.getConnections();
                int enrichCount = 0;
                for (ConnectionRecord record : history) {
                    ConnectionRecord enriched = record;
                    if ((record.countryCode == null || record.countryCode.isEmpty())
                            && enrichCount < COUNTRY_ENRICH_LIMIT
                            && FirewallRule.isValidIpv4(record.destinationIp)) {
                        GeoIpResolver.CountryInfo info = geoIpResolver.resolve(record.destinationIp);
                        enriched = new ConnectionRecord(
                                record.timestampMs,
                                record.destinationIp,
                                record.destinationPort,
                                record.protocol,
                                record.blocked,
                                record.reason,
                                record.sourceUid,
                                record.sourceApp,
                                info.countryCode,
                                info.countryName
                        );
                        enrichCount++;
                    }
                    items.add(toUiItem(enriched));
                }

                List<ProcNetScanner.ActiveConnection> active = procNetScanner.scanConnections();
                int activeEnrichCount = 0;
                for (ProcNetScanner.ActiveConnection conn : active) {
                    if (items.size() > 200) {
                        break;
                    }
                    GeoIpResolver.CountryInfo info = new GeoIpResolver.CountryInfo("", "");
                    if (activeEnrichCount < COUNTRY_ENRICH_LIMIT && FirewallRule.isValidIpv4(conn.destinationIp)) {
                        info = geoIpResolver.resolve(conn.destinationIp);
                        activeEnrichCount++;
                    }
                    String sourceApp = resolveSourceApp(conn.uid);
                    ConnectionRecord activeRecord = new ConnectionRecord(
                            System.currentTimeMillis(),
                            conn.destinationIp,
                            conn.destinationPort,
                            conn.protocol,
                            false,
                            conn.state,
                            conn.uid,
                            sourceApp,
                            info.countryCode,
                            info.countryName
                    );
                    items.add(toUiItem(activeRecord));
                }
            } finally {
                runOnUiThread(() -> {
                    connectionsAdapter.setItems(items);
                    if (userRequestedRefresh && items.isEmpty()) {
                        Toast.makeText(this, R.string.connections_refresh_failed, Toast.LENGTH_SHORT).show();
                    }
                    synchronized (refreshLock) {
                        refreshingConnections = false;
                    }
                });
            }
        }, "SecureConnectionGuardUiRefresh");
        worker.start();
    }

    private ConnectionUiItem toUiItem(ConnectionRecord record) {
        boolean sketchyApp = RiskIntelligence.isSketchyAppName(record.sourceApp);
        boolean highRiskCountry = RiskIntelligence.isHighRiskCountry(record.countryCode);

        ConnectionUiItem.Severity severity;
        String reason;
        if (record.blocked) {
            severity = ConnectionUiItem.Severity.HIGH;
            reason = record.reason == null || record.reason.isEmpty()
                    ? getString(R.string.severity_reason_blocked_default)
                    : record.reason;
        } else if (sketchyApp && highRiskCountry) {
            severity = ConnectionUiItem.Severity.HIGH;
            reason = getString(R.string.severity_reason_sketchy_app) + "; "
                    + getString(R.string.severity_reason_risk_country);
        } else if (sketchyApp || highRiskCountry) {
            severity = ConnectionUiItem.Severity.MEDIUM;
            reason = sketchyApp
                    ? getString(R.string.severity_reason_sketchy_app)
                    : getString(R.string.severity_reason_risk_country);
        } else {
            severity = ConnectionUiItem.Severity.LOW;
            reason = getString(R.string.severity_reason_normal);
        }
        return new ConnectionUiItem(record, severity, reason);
    }

    private String resolveSourceApp(int uid) {
        if (uid <= 0) {
            return "";
        }
        PackageManager pm = getPackageManager();
        String[] packages = pm.getPackagesForUid(uid);
        if (packages == null || packages.length == 0) {
            return "";
        }
        return packages[0];
    }

    private void refreshNewsFromStore() {
        List<NewsItem> items = newsRepository.loadItems();
        if (items.isEmpty()) {
            List<NewsItem> placeholder = new ArrayList<>();
            placeholder.add(new NewsItem(getString(R.string.news_empty), "", "", 0L));
            newsAdapter.setItems(placeholder);
        } else {
            newsAdapter.setItems(items);
        }
        long lastUpdated = newsRepository.getLastUpdateMs();
        if (lastUpdated <= 0L) {
            newsStatusView.setText(
                    getString(R.string.status_news_prefix) + getString(R.string.news_last_updated_unknown));
        } else {
            String formatted = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.US)
                    .format(new java.util.Date(lastUpdated));
            newsStatusView.setText(
                    getString(R.string.status_news_prefix)
                            + getString(R.string.news_last_updated_format, formatted));
        }
    }

    private void refreshNewsNow() {
        if (refreshingNews) {
            return;
        }
        refreshingNews = true;
        Toast.makeText(this, R.string.news_refresh_running, Toast.LENGTH_SHORT).show();
        Thread worker = new Thread(() -> {
            boolean ok = NewsSyncTask.run(getApplicationContext());
            runOnUiThread(() -> {
                refreshingNews = false;
                if (ok) {
                    refreshNewsFromStore();
                    Toast.makeText(this, R.string.news_refresh_ok, Toast.LENGTH_SHORT).show();
                } else {
                    Toast.makeText(this, R.string.news_refresh_failed, Toast.LENGTH_SHORT).show();
                }
            });
        }, "SecureConnectionGuardNewsRefresh");
        worker.start();
    }

    private void requestVpnAndStart() {
        if (policyStore.isSystemBackendEnabled()) {
            startProtectionService();
            return;
        }
        Intent vpnIntent = VpnService.prepare(this);
        if (vpnIntent != null) {
            startActivityForResult(vpnIntent, REQUEST_VPN_PERMISSION);
        } else {
            startProtectionService();
        }
    }

    private void restartProtectionIfEnabled() {
        if (!policyStore.isProtectionEnabled()) {
            return;
        }
        stopProtectionService();
        startProtectionService();
    }

    private void startProtectionService() {
        Intent startIntent = ConnectionFirewallService.buildStartIntent(this);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(startIntent);
        } else {
            startService(startIntent);
        }
        policyStore.setProtectionEnabled(true);
        Toast.makeText(this, R.string.service_started, Toast.LENGTH_SHORT).show();
        updateStatus();
    }

    private void stopProtectionService() {
        startService(ConnectionFirewallService.buildStopIntent(this));
        policyStore.setProtectionEnabled(false);
        Toast.makeText(this, R.string.service_stopped, Toast.LENGTH_SHORT).show();
        updateStatus();
    }

}
