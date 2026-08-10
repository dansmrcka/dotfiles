#!/bin/bash

# wmenu launcher - jednoradkovy pruh nahore, ve stylu puvodniho dmenu.
#
# Nahrazuje "rofi -show combi -combi-modes drun,run". Duvod pro vlastni wrapper
# misto holeho wmenu-run: wmenu-run umi jen binarky z $PATH, takze by vubec
# nenasel flatpaky (Brave, Signal) - /var/lib/flatpak/exports/bin v $PATH neni.
# Tenhle skript proto sam projde .desktop soubory (drun) a prida k nim $PATH (run),
# cimz replikuje puvodni combi rezim.
#
# Barvy se ctou ze symlinku ~/.config/sway/colors, ktery prehazuje set-theme.sh,
# takze se menu prepina spolu se zbytkem systemu bez dalsi konfigurace.
#
# Pouziti:
#   menu.sh              - launcher (drun + run)
#   menu.sh --dmenu [p]  - cte polozky ze stdin, vypise vyber (pro cliphist ap.)

set -u

COLORS=~/.config/sway/colors
FONT='Monospace 12'

# Vytahne "set $nazev #rrggbb" ze sway barevneho schematu. wmenu chce hex
# bez mrizky, sway ji ma - proto se ustrihne.
sway_color() {
  local value
  value=$(sed -n "s/^set \\\$$1[[:space:]]\\+#\\([0-9a-fA-F]\\{6\\}\\).*/\\1/p" "$COLORS" 2>/dev/null | head -1)
  echo "${value:-$2}"
}

# Fallbacky odpovidaji colors.dark - pouziji se, jen kdyz symlink chybi.
NORMAL_BG=$(sway_color background_color 121212)
NORMAL_FG=$(sway_color inactive_text_color eeeeee)
SELECT_BG=$(sway_color active_background 005faf)
SELECT_FG=$(sway_color active_text_color ffffff)

# Prompt dostava stejne barvy jako vyber, at je vlevo videt souvisly blok.
wmenu_args=(
  -i
  -f "$FONT"
  -N "$NORMAL_BG" -n "$NORMAL_FG"
  -M "$SELECT_BG" -m "$SELECT_FG"
  -S "$SELECT_BG" -s "$SELECT_FG"
)

if [ "${1-}" = "--dmenu" ]; then
  exec wmenu "${wmenu_args[@]}" -p "${2-}"
fi

# --- drun: nacteni .desktop souboru -----------------------------------------

# Poradi je od nejnizsi priority po nejvyssi, aby uzivatelske .desktop prepsaly
# systemove (asociativni pole si drzi posledni zapis).
desktop_dirs=(
  /usr/share/applications
  /usr/local/share/applications
  /var/lib/flatpak/exports/share/applications
  ~/.local/share/flatpak/exports/share/applications
  ~/.local/share/applications
)

declare -A APPS

while IFS=$'\t' read -r name file; do
  [ -n "$name" ] && APPS["$name"]="$file"
done < <(
  for dir in "${desktop_dirs[@]}"; do
    [ -d "$dir" ] || continue
    awk -F= '
      FNR == 1 { name = ""; type = ""; skip = 0; section = "" }
      /^\[/    { section = $0; next }
      section != "[Desktop Entry]" { next }
      $1 == "Name"      && name == "" { name = substr($0, index($0, "=") + 1) }
      $1 == "Type"                    { type = $2 }
      ($1 == "NoDisplay" || $1 == "Hidden") && $2 == "true" { skip = 1 }
      ENDFILE {
        if (!skip && name != "" && type == "Application")
          printf "%s\t%s\n", name, FILENAME
      }
    ' "$dir"/*.desktop 2>/dev/null
  done
)

choice=$(
  {
    printf '%s\n' "${!APPS[@]}" | sort
    # run cast - binarky z $PATH, stejne jako to delal dmenu_run
    IFS=: read -ra path_dirs <<<"$PATH"
    find "${path_dirs[@]}" -maxdepth 1 -type f -executable -printf '%f\n' 2>/dev/null | sort -u
  } | wmenu "${wmenu_args[@]}" -p 'run:'
) || exit 0

[ -n "$choice" ] || exit 0

if [ -n "${APPS[$choice]-}" ]; then
  # gio launch respektuje Exec= vcetne argumentu, Terminal= i StartupNotify.
  exec gio launch "${APPS[$choice]}"
else
  # swaymsg exec odpoji proces od tohohle skriptu, aby prezil jeho konec.
  exec swaymsg -q exec -- "$choice"
fi
