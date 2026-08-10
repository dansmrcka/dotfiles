#!/bin/bash
# Odsune kurzor do rohu aktivniho okna - odstrani rusici sipku pres text.
#
# Puvodni ~/.i3/banishMouse.sh stal na xwininfo + xdotool (X11).
# Ve sway to same zvladne swaymsg: souradnice z get_tree, presun pres seat.

read -r x y < <(
    swaymsg -t get_tree \
        | jq -r 'recurse(.nodes[]?, .floating_nodes[]?) | select(.focused == true) | "\(.rect.x) \(.rect.y)"'
)

if [[ -z "$x" || -z "$y" ]]; then
    exit 0
fi

swaymsg "seat - cursor set $x $y" > /dev/null
