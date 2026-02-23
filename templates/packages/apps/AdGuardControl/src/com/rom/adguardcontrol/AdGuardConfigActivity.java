package com.rom.adguardcontrol;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

public final class AdGuardConfigActivity extends Activity {
    private TextView statusText;
    private EditText paidEndpointInput;
    private AdGuardSettingsStore settingsStore;
    private PrivateDnsController dnsController;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_config);

        settingsStore = new AdGuardSettingsStore(this);
        dnsController = new PrivateDnsController(this);

        statusText = findViewById(R.id.status_text);
        paidEndpointInput = findViewById(R.id.paid_endpoint_input);

        Button saveButton = findViewById(R.id.save_paid_endpoint_button);
        Button enableFreeButton = findViewById(R.id.enable_free_button);
        Button togglePaidButton = findViewById(R.id.toggle_paid_button);
        Button disableAllButton = findViewById(R.id.disable_all_button);
        Button openAppButton = findViewById(R.id.open_adguard_app_button);
        Button openSiteButton = findViewById(R.id.open_adguard_site_button);

        paidEndpointInput.setText(settingsStore.getPaidEndpoint());

        saveButton.setOnClickListener(v -> savePaidEndpoint());
        enableFreeButton.setOnClickListener(v -> {
            if (!dnsController.enableFree()) {
                Toast.makeText(this, R.string.enable_failed, Toast.LENGTH_SHORT).show();
            }
            refreshStatus();
        });
        togglePaidButton.setOnClickListener(v -> togglePaidMode());
        disableAllButton.setOnClickListener(v -> {
            if (!dnsController.disable()) {
                Toast.makeText(this, R.string.enable_failed, Toast.LENGTH_SHORT).show();
            }
            refreshStatus();
        });
        openAppButton.setOnClickListener(v -> openAdGuardApp());
        openSiteButton.setOnClickListener(v -> {
            Intent browser = new Intent(Intent.ACTION_VIEW, Uri.parse("https://adguard.com/"));
            startActivity(browser);
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        paidEndpointInput.setText(settingsStore.getPaidEndpoint());
        refreshStatus();
    }

    private void savePaidEndpoint() {
        String host = paidEndpointInput.getText() == null ? "" : paidEndpointInput.getText().toString().trim();
        if (!host.isEmpty() && !PrivateDnsController.isValidHostname(host)) {
            Toast.makeText(this, R.string.invalid_host, Toast.LENGTH_SHORT).show();
            return;
        }
        settingsStore.setPaidEndpoint(host);
        Toast.makeText(this, R.string.saved, Toast.LENGTH_SHORT).show();
        refreshStatus();
    }

    private void togglePaidMode() {
        String host = paidEndpointInput.getText() == null ? "" : paidEndpointInput.getText().toString().trim();
        if (host.isEmpty()) {
            host = settingsStore.getPaidEndpoint();
        }

        if (!PrivateDnsController.isValidHostname(host)) {
            Toast.makeText(this, R.string.paid_endpoint_missing, Toast.LENGTH_SHORT).show();
            return;
        }

        settingsStore.setPaidEndpoint(host);

        boolean ok;
        if (dnsController.isPaidActive(host)) {
            ok = dnsController.disable();
        } else {
            ok = dnsController.enablePaid(host);
        }
        if (!ok) {
            Toast.makeText(this, R.string.enable_failed, Toast.LENGTH_SHORT).show();
        }
        refreshStatus();
    }

    private void openAdGuardApp() {
        Intent launch = getPackageManager().getLaunchIntentForPackage("com.adguard.android");
        if (launch == null) {
            Toast.makeText(this, R.string.adguard_app_not_found, Toast.LENGTH_SHORT).show();
            return;
        }
        startActivity(launch);
    }

    private void refreshStatus() {
        String mode = dnsController.getCurrentMode();
        String specifier = dnsController.getCurrentSpecifier();
        String text;
        if ("hostname".equals(mode)) {
            if (PrivateDnsController.FREE_ENDPOINT.equalsIgnoreCase(specifier)) {
                text = getString(R.string.status_free);
            } else {
                String paid = settingsStore.getPaidEndpoint();
                if (!paid.isEmpty() && paid.equalsIgnoreCase(specifier)) {
                    text = getString(R.string.status_paid);
                } else {
                    text = getString(R.string.status_custom) + " (" + specifier + ")";
                }
            }
        } else {
            text = getString(R.string.status_off);
        }
        statusText.setText(getString(R.string.status_prefix) + text);
    }
}
