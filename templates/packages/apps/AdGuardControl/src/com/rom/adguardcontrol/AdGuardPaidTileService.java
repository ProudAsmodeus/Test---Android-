package com.rom.adguardcontrol;

import android.content.Intent;
import android.service.quicksettings.Tile;
import android.service.quicksettings.TileService;

public final class AdGuardPaidTileService extends TileService {
    @Override
    public void onStartListening() {
        super.onStartListening();
        refreshTile();
    }

    @Override
    public void onClick() {
        super.onClick();
        AdGuardSettingsStore store = new AdGuardSettingsStore(this);
        PrivateDnsController dns = new PrivateDnsController(this);
        String paidHost = store.getPaidEndpoint();

        if (paidHost.isEmpty()) {
            AdGuardTileUtils.showToast(this, R.string.paid_endpoint_missing);
            openConfigActivity();
            refreshTile();
            return;
        }

        boolean ok;
        if (dns.isPaidActive(paidHost)) {
            ok = dns.disable();
        } else {
            ok = dns.enablePaid(paidHost);
        }
        if (!ok) {
            AdGuardTileUtils.showToast(this, R.string.enable_failed);
        }
        refreshTile();
    }

    private void openConfigActivity() {
        Intent intent = new Intent(this, AdGuardConfigActivity.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        startActivityAndCollapse(intent);
    }

    private void refreshTile() {
        AdGuardSettingsStore store = new AdGuardSettingsStore(this);
        PrivateDnsController dns = new PrivateDnsController(this);
        String paidHost = store.getPaidEndpoint();
        boolean configured = !paidHost.isEmpty();
        boolean active = configured && dns.isPaidActive(paidHost);
        String subtitle;
        if (!configured) {
            subtitle = getString(R.string.tile_subtitle_needs_setup);
        } else if (active) {
            subtitle = getString(R.string.tile_subtitle_enabled);
        } else {
            subtitle = getString(R.string.tile_subtitle_disabled);
        }
        Tile tile = getQsTile();
        AdGuardTileUtils.updateTileState(tile, getString(R.string.tile_paid_label), subtitle, active);
    }
}
