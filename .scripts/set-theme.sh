#!/bin/bash

export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus

#plexwawe.org/blog/auto-dark-mode

set_vim_colors() {
    sed -i "s/\(let g:airline_theme='\)[^']*\('\)/\1$1\2/" ~/.config/nvim/init.vim
    sed -i "s/\(colorscheme \)[a-z]*/\1$2/" ~/.config/nvim/init.vim
}
set_apptainer_vim_colors() {
    sed -i "s/\(let g:airline_theme='\)[^']*\('\)/\1$1\2/" ~/git/f4f/mrs_apptainer/mount/apptainer_vimrc
    sed -i "s/\(colorscheme \)[a-z]*/\1$2/" ~/git/f4f/mrs_apptainer/mount/apptainer_vimrc
}
set_alacritty_colors() {
    sed -i "s/\(themes\/themes\/\)[^']*\(.toml\)/\1$1\2/" ~/.config/alacritty/alacritty.toml
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
        set_vim_colors jellybeans jellybeans
        set_apptainer_vim_colors jellybeans jellybeans
	lookandfeeltool -a org.kde.breezedark.desktop 
	;;
    light)
        set_alacritty_colors solarized_light
        set_vim_colors papercolor raggi
        set_apptainer_vim_colors papercolor raggi
	lookandfeeltool -a org.kde.breeze.desktop 
	;;
    *)
        echo "usage: set-theme <dark|light>"
        exit 1
        ;;
esac
