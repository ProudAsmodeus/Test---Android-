package com.rom.adguardcontrol;

import android.service.quicksettings.Tile;
import android.service.quicksettings.TileService;

public final class AdGuardFreeTileService extends TileService {
    @Override
    public void onStartListening() {
        super.onStartListening();
        refreshTile();
    }

    @Override
    public void onClick() {
        super.onClick();
        PrivateDnsController dns = new PrivateDnsController(this);
        boolean ok;
        if (dns.isFreeActive()) {
            ok = dns.disable();
        } else {
            ok = dns.enableFree();
        }
        if (!ok) {
            AdGuardTileUtils.showToast(this, R.string.enable_failed);
        }
        refreshTile();
    }

    private void refreshTile() {
        PrivateDnsController dns = new PrivateDnsController(this);
        boolean active = dns.isFreeActive();
        String subtitle = active
                ? getString(R.string.tile_subtitle_enabled)
                : getString(R.string.tile_subtitle_disabled);
        Tile tile = getQsTile();
        AdGuardTileUtils.updateTileState(tile, getString(R.string.tile_free_label), subtitle, active);
    }
}
