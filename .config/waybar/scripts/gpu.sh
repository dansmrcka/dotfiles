#!/bin/bash
# Waybar modul pro NVIDIA T550.
#
# Nahrazuje show_gpu_load.sh / show_gpu_temp.sh / show_gpu_mem.sh z i3blocks.
#
# Dulezite: na Optimus laptopu nvidia-smi probudi uspanou dGPU a zere baterii.
# Proto se nejdriv ptame sysfs na runtime_status a kdyz GPU spi, mlcime.

GPU_PCI="0000:03:00.0"
STATE_FILE="/sys/bus/pci/devices/${GPU_PCI}/power/runtime_status"

state=$(cat "$STATE_FILE" 2>/dev/null)

if [[ "$state" != "active" ]]; then
    printf '{"text":"","tooltip":"NVIDIA T550: %s","class":"suspended"}\n' "${state:-neznamy stav}"
    exit 0
fi

read -r util mem_used mem_total temp < <(
    nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu \
               --format=csv,noheader,nounits 2>/dev/null | tr -d ','
)

if [[ -z "$util" ]]; then
    printf '{"text":"","tooltip":"nvidia-smi neodpovida","class":"error"}\n'
    exit 0
fi

printf '{"text":"󰢮 %s%%","tooltip":"NVIDIA T550\\nZatez: %s%%\\nVRAM: %s / %s MiB\\nTeplota: %s°C","class":"active"}\n' \
    "$util" "$util" "$mem_used" "$mem_total" "$temp"
