#!/usr/bin/env bash
# Autostart qtile — lancé une fois au démarrage de session

# Clavier suisse romand (X11)
setxkbmap ch fr &

# Compositor (transparence, ombres, vsync)
picom -b &

# Wallpaper (dernier choisi via nitrogen)
nitrogen --restore &

# Notifications
dunst &

# Applets réseau + bluetooth
nm-applet &
blueman-applet 2>/dev/null &

# Screenshot daemon
flameshot &

# Curseur X propre
xsetroot -cursor_name left_ptr &
