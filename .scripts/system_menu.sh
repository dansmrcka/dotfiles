#!/bin/bash
# Portovano z ~/git/linux-setup/scripts/system_menu.sh pro sway.
# Sloucen sem i zaniknuty shutdown_menu (submodul i3blocks-contrib nebyl stazeny).
#
# Zmeny proti i3 verzi:
#   i3lock-fancy --pixelate  ->  swaylock
#   i3-msg exit              ->  swaymsg exit
# Zbytek (systemctl) je beze zmeny.

LOCK_CMD="swaylock -f -c 000000"

ACTION=$( echo "lock
shutdown
reboot
logout
suspend
hibernate" | rofi -dmenu -p "Select desired action:")

case "$ACTION" in
    lock)
        $LOCK_CMD
        ;;
    logout)
        swaymsg exit
        ;;
    suspend)
        $LOCK_CMD && systemctl suspend
        ;;
    hibernate)
        $LOCK_CMD && systemctl hibernate
        ;;
    reboot)
        systemctl reboot
        ;;
    shutdown)
        systemctl poweroff
        ;;
    *)
        ;;
esac
