#!/bin/bash

# Toggle dark/light.
#
# Zmeny pri prechodu na sway:
#   - vyhozen "export DISPLAY=:0" (pod Waylandem nic neznamena)
#   - pribylo prepnuti barev sway, waybaru a pozadi
#   - GTK aplikace se resi pres gsettings, KDE dal pres lookandfeeltool
#
# DBUS_SESSION_BUS_ADDRESS zustava - gsettings a notifikace ho potrebuji.
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus

#plexwawe.org/blog/auto-dark-mode

APPTAINER_PATH_ROS1=~/git/f4f/mrs_apptainer-ros1/
APPTAINER_PATH_ROS2=~/git/f4f/mrs_apptainer-ros2/
ALACRITTY_PATH=~/.config/alacritty/
SWAY_PATH=~/.config/sway/
WAYBAR_PATH=~/.config/waybar/

set_vim_colors() {
  sed -i "s/\(let g:airline_theme='\)[^']*\('\)/\1$1\2/" ~/.config/nvim/init.vim
  sed -i "s/\(colorscheme \)[a-z]*/\1$2/" ~/.config/nvim/init.vim
}
set_apptainer_ros1_vim_colors() {
  sed -i "s/\(let g:airline_theme='\)[^']*\('\)/\1$1\2/" $APPTAINER_PATH_ROS1/mount/apptainer_vimrc
  sed -i "s/\(colorscheme \)[a-z]*/\1$2/" $APPTAINER_PATH_ROS1/mount/apptainer_vimrc
}
set_apptainer_ros2_vim_colors() {
  sed -i "s/\(let g:airline_theme='\)[^']*\('\)/\1$1\2/" $APPTAINER_PATH_ROS2/mount/apptainer_vimrc
  sed -i "s/\(colorscheme \)[a-z]*/\1$2/" $APPTAINER_PATH_ROS2/mount/apptainer_vimrc
}
set_alacritty_colors() {
  sed -i "s/\(themes\/themes\/\)[^']*\(.toml\)/\1$1\2/" $ALACRITTY_PATH/alacritty.toml
}

# Prehodi symlinky s barvami a rekne sway a waybaru, at se prekresli.
# Dela se jen pokud sway skutecne bezi - pod Plasmou nema co delat.
set_sway_colors() {
  [ -n "$SWAYSOCK" ] || return 0

  ln -sf "$SWAY_PATH/colors.$1" "$SWAY_PATH/colors"
  ln -sf "$WAYBAR_PATH/colors-$1.css" "$WAYBAR_PATH/colors.css"

  swaymsg reload > /dev/null 2>&1
  pkill -SIGUSR2 waybar > /dev/null 2>&1
}

# GTK aplikace (Firefox, Brave, nautilus-like, GTK dialogy).
#
# Pozor na dve pasti, kvuli kterym drive prepnuti nefungovalo:
#
#  1) ~/.config/gtk-{3,4}.0/settings.ini (zapsal ho kde-gtk-config z Plasmy) ma
#     PREDNOST pred gsettings/dconf. Dokud v nem zustane natvrdo
#     gtk-application-prefer-dark-theme=true, zadne gsettings s tim nehne.
#     Proto se prepisuje i tenhle soubor.
#
#  2) Flatpaky (napr. Brave) na host dconf nedosahnou vubec - ridi se hodnotou
#     org.freedesktop.appearance color-scheme ze Settings portalu.
#     Tim padem musi bezet xdg-desktop-portal; to resi include
#     /etc/sway/config.d/* v sway configu.
#
# gtk-theme-name zustava porad "Adwaita" zamerne - tmavou variantu resi
# prepinac prefer-dark, samostatna tema "Adwaita-dark" na systemu neexistuje.
set_gtk_ini() {
  local file="$1" prefer_dark="$2" icons="$3"

  [ -f "$file" ] || return 0

  sed -i \
    -e "s/^gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=$prefer_dark/" \
    -e "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$icons/" \
    -e "s/^gtk-theme-name=.*/gtk-theme-name=Adwaita/" \
    "$file"
}

set_gtk_colors() {
  local variant="$1"
  local scheme prefer_dark icons

  if [ "$variant" == "dark" ]; then
    scheme="prefer-dark"; prefer_dark="true";  icons="breeze-dark"
  else
    scheme="prefer-light"; prefer_dark="false"; icons="breeze"
  fi

  set_gtk_ini ~/.config/gtk-3.0/settings.ini "$prefer_dark" "$icons"
  set_gtk_ini ~/.config/gtk-4.0/settings.ini "$prefer_dark" "$icons"

  gsettings set org.gnome.desktop.interface color-scheme "$scheme" 2>/dev/null
  gsettings set org.gnome.desktop.interface gtk-theme Adwaita 2>/dev/null
  gsettings set org.gnome.desktop.interface icon-theme "$icons" 2>/dev/null
}

detect_current_state() {
  if grep -q "solarized_dark" ~/.config/alacritty/alacritty.toml; then
    echo "dark"
  else
    echo "light"
  fi
}

CURRENT=$(detect_current_state)
if [ "$CURRENT" == "dark" ]; then
  THEME="light"
else
  THEME="dark"
fi

case $THEME in

dark)
  set_alacritty_colors solarized_dark
  set_apptainer_ros1_vim_colors jellybeans jellybeans
  set_apptainer_ros2_vim_colors jellybeans jellybeans
  kitty +kitten themes --reload-in=all "Solarized Dark"
  set_sway_colors dark
  set_gtk_colors dark
  lookandfeeltool -a org.kde.breezedark.desktop
  ;;
light)
  set_alacritty_colors solarized_light
  set_apptainer_ros1_vim_colors papercolor raggi
  set_apptainer_ros2_vim_colors papercolor raggi
  kitty +kitten themes --reload-in=all "Solarized Light"
  set_sway_colors light
  set_gtk_colors light
  lookandfeeltool -a org.kde.breeze.desktop
  ;;
*)
  echo "usage: set-theme <dark|light>"
  exit 1
  ;;
esac
