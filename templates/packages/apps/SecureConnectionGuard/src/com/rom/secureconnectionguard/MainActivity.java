package com.rom.secureconnectionguard;

import android.app.Activity;
import android.content.Intent;
import android.net.VpnService;
import android.os.Build;
import android.os.Bundle;
import android.text.TextUtils;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ListView;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.Toast;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class MainActivity extends Activity {
    private static final int REQUEST_VPN_PERMISSION = 1023;
    private static final Pattern IPV4_PATTERN = Pattern.compile("\\b(\\d{1,3}(?:\\.\\d{1,3}){3})\\b");

    private PolicyStore policyStore;
    private ProcNetScanner procNetScanner;

    private TextView statusView;
    private Switch protectionSwitch;
    private Switch blockSuspiciousSwitch;
    private EditText ruleInput;
    private ListView rulesList;
    private ListView connectionsList;

    private ArrayAdapter<String> rulesAdapter;
    private ArrayAdapter<String> connectionsAdapter;
    private final List<FirewallRule> currentRules = new ArrayList<>();

    private boolean listenersAttached;
    private boolean suppressSwitchCallbacks;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        policyStore = new PolicyStore(this);
        procNetScanner = new ProcNetScanner();

        statusView = findViewById(R.id.status_text);
        protectionSwitch = findViewById(R.id.protection_switch);
        blockSuspiciousSwitch = findViewById(R.id.block_suspicious_switch);
        ruleInput = findViewById(R.id.rule_input);
        rulesList = findViewById(R.id.rules_list);
        connectionsList = findViewById(R.id.connections_list);
        Button addRuleButton = findViewById(R.id.add_rule_button);
        Button refreshButton = findViewById(R.id.refresh_button);

        rulesAdapter = new ArrayAdapter<>(this, android.R.layout.simple_list_item_1, new ArrayList<>());
        rulesList.setAdapter(rulesAdapter);

        connectionsAdapter = new ArrayAdapter<>(this, android.R.layout.simple_list_item_1, new ArrayList<>());
        connectionsList.setAdapter(connectionsAdapter);

        addRuleButton.setOnClickListener(v -> addRuleFromInput());
        refreshButton.setOnClickListener(v -> refreshConnectionList(true));

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
            String line = connectionsAdapter.getItem(position);
            String ip = extractFirstIpv4(line);
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
    }

    @Override
    protected void onResume() {
        super.onResume();
        refreshUiFromStore();
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

        if (!listenersAttached) {
            protectionSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
                if (suppressSwitchCallbacks) {
                    return;
                }
                policyStore.setProtectionEnabled(isChecked);
                if (isChecked) {
                    requestVpnAndStart();
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

            listenersAttached = true;
        }

        suppressSwitchCallbacks = true;
        protectionSwitch.setChecked(protectionEnabled);
        blockSuspiciousSwitch.setChecked(blockSuspiciousEnabled);
        suppressSwitchCallbacks = false;
        updateStatus();
        refreshRulesList();
        refreshConnectionList(false);
    }

    private void updateStatus() {
        String status = policyStore.isProtectionEnabled()
                ? getString(R.string.status_protection_on)
                : getString(R.string.status_protection_off);
        statusView.setText(getString(R.string.status_prefix) + status);
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
        List<String> lines = new ArrayList<>();
        for (ConnectionRecord record : policyStore.getConnections()) {
            lines.add(record.displayLine());
        }

        List<String> active = procNetScanner.scanConnectionLines();
        if (!active.isEmpty()) {
            lines.add("---- Active socket snapshot ----");
            lines.addAll(active);
        } else if (userRequestedRefresh && lines.isEmpty()) {
            Toast.makeText(this, R.string.connections_refresh_failed, Toast.LENGTH_SHORT).show();
        }

        if (lines.isEmpty()) {
            lines.add("No captured connections yet.");
        }

        connectionsAdapter.clear();
        connectionsAdapter.addAll(lines);
        connectionsAdapter.notifyDataSetChanged();
    }

    private void requestVpnAndStart() {
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

    private String extractFirstIpv4(String line) {
        if (TextUtils.isEmpty(line)) {
            return null;
        }
        Matcher matcher = IPV4_PATTERN.matcher(line);
        if (matcher.find()) {
            String ip = matcher.group(1);
            if (FirewallRule.isValidIpv4(ip)) {
                return ip;
            }
        }
        return null;
    }
}
