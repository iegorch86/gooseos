#!/usr/bin/env bash
set -euo pipefail

config_dir="/usr/share/cosmic/com.system76.CosmicBackground/v1"
wallpaper="/usr/share/backgrounds/gooseos/gooseos-space-v2.png"

if [[ ! -f "$wallpaper" ]]; then
    echo "ERROR: GooseOS wallpaper not found: $wallpaper" >&2
    exit 1
fi

install -d -m 0755 "$config_dir"

cat > "${config_dir}/all" <<EOF
(
    output: "all",
    source: Path("${wallpaper}"),
    filter_by_theme: false,
    rotation_frequency: 3600,
    filter_method: Lanczos,
    scaling_mode: Zoom,
    sampling_method: Alphanumeric,
)
EOF

printf '[All]\n' > "${config_dir}/backgrounds"
printf 'true\n' > "${config_dir}/same-on-all"

chmod 0644 \
    "${config_dir}/all" \
    "${config_dir}/backgrounds" \
    "${config_dir}/same-on-all"

echo "GooseOS default wallpaper configured: $wallpaper"
