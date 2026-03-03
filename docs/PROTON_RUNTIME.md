# Proton Runtime Notes (Linux)

This project can run the Windows Direct3D11 executable via Proton.

## Recommended Usage

1. Set a dedicated prefix:

```bash
export WINEPREFIX="$PWD/.wine-matter-to-count"
```

2. Point to Proton explicitly if `proton` is not on PATH:

```bash
export PROTON_BIN="/path/to/proton"
```

For your current setup, this path is valid:

```bash
export PROTON_BIN="/usr/share/steam/compatibilitytools.d/proton-cachyos/proton"
```

3. Run smoke script:

```bash
SMOKE_EXE="/abs/path/to/matter-to-count.exe" \
MTC_FRAMES=120 \
MTC_SEED=1 \
./scripts/run_windows_smoke.sh
```

If not set, the script defaults:

```bash
STEAM_COMPAT_DATA_PATH="$PWD/.steam-compat/matter-to-count"
```

Proton standalone also needs a Steam client path:

```bash
export STEAM_COMPAT_CLIENT_INSTALL_PATH="/usr/share/steam"
```

The script tries `/usr/share/steam`, `/usr/lib/steam`, and `$HOME/.steam/steam` automatically.

To force Wine fallback even when Proton is installed:

```bash
export MTC_DISABLE_PROTON=1
```

## Fallback
If Proton is unavailable, the script falls back to `wine` automatically.

## Determinism Guidance
For stable comparisons across runs:
- use a fixed `WINEPREFIX`;
- keep `MTC_SEED` fixed;
- keep `MTC_FRAMES` fixed;
- avoid changing GPU/driver/runtime during baseline capture.
