#!/usr/bin/env bash
# Rende un diagramma di topologia (HTML con SVG inline) in PNG con Chrome headless di Windows.
# Uso: render_topology.sh <in.html> <out.png> <width> <height>
set -e
in=$1; out=$2; w=$3; h=$4
chrome="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
tmp=/mnt/c/Users/Public/clab_topo_$$
cp "$in" "$tmp.html"
"$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --window-size="$w,$h" --screenshot="C:\\Users\\Public\\clab_topo_$$.png" \
  "file:///C:/Users/Public/clab_topo_$$.html" >/dev/null 2>&1
mkdir -p "$(dirname "$out")"
cp "$tmp.png" "$out"
rm -f "$tmp.html" "$tmp.png"
echo "$w x $h -> $out"
