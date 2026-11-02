#!/bin/bash
# Waybar modul pro integrovanou AMD grafiku (ThinkPad T14 Gen 6, Radeon 840M).
#
# Vse ze sysfs ovladace amdgpu, bez externich nastroju. iGPU se na rozdil od
# drivejsi NVIDIA dGPU neuspava a cteni sysfs ji nebudi, takze se ptame vzdy.
#
# Karta se hleda podle ovladace, ne podle cisla - card0/card1 se muze
# mezi jadry/bootem prehodit.

dev=""
for d in /sys/class/drm/card[0-9]*; do
    [[ "$(basename "$(readlink -f "$d/device/driver")")" == amdgpu ]] && { dev="$d/device"; break; }
done

if [[ -z "$dev" || ! -r "$dev/gpu_busy_percent" ]]; then
    printf '{"text":"","tooltip":"amdgpu nenalezena","class":"error"}\n'
    exit 0
fi

util=$(<"$dev/gpu_busy_percent")
mib() { echo $(( $(<"$1") / 1048576 )); }
vram_used=$(mib "$dev/mem_info_vram_used")
vram_total=$(mib "$dev/mem_info_vram_total")
gtt_used=$(mib "$dev/mem_info_gtt_used")

hw=$(ls -d "$dev"/hwmon/hwmon* 2>/dev/null | head -1)
temp="?"; power="?"
[[ -r "$hw/temp1_input" ]] && temp=$(( $(<"$hw/temp1_input") / 1000 ))
# power1_average je u APU prikon cele baterie cipu (PPT), ne jen grafiky
[[ -r "$hw/power1_average" ]] && power=$(awk '{printf "%.1f", $1/1e6}' "$hw/power1_average")

printf '{"text":"󰢮 %s%%","tooltip":"Radeon iGPU\\nZatez: %s%%\\nVRAM: %s / %s MiB (+ GTT %s MiB)\\nTeplota: %s°C\\nPrikon APU: %s W","class":"active","percentage":%s}\n' \
    "$util" "$util" "$vram_used" "$vram_total" "$gtt_used" "$temp" "$power" "$util"
