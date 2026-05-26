#!/bin/sh
# Called from hyprland.conf exec-once. Waits 1s for awww-daemon, then sets wallpaper.
# (CachyOS renamed swww → awww — same API.)
# If default wallpaper missing, fall back to solid Gruvbox bg color.
sleep 1
if [ -f "$HOME/Pictures/Wallpapers/gruvbox-default.png" ]; then
  awww img "$HOME/Pictures/Wallpapers/gruvbox-default.png" --transition-type any
else
  # Fallback: solid Gruvbox bg0_h via awww's color
  awww clear "1d2021"
fi
