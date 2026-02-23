package com.rom.adguardcontrol;

import android.service.quicksettings.Tile;
import android.widget.Toast;

final class AdGuardTileUtils {
    private AdGuardTileUtils() {
    }

    static void updateTileState(Tile tile, String label, String subtitle, boolean active) {
        if (tile == null) {
            return;
        }
        tile.setLabel(label);
        tile.setSubtitle(subtitle);
        tile.setState(active ? Tile.STATE_ACTIVE : Tile.STATE_INACTIVE);
        tile.updateTile();
    }

    static void showToast(android.content.Context context, int stringId) {
        Toast.makeText(context, stringId, Toast.LENGTH_SHORT).show();
    }
}
