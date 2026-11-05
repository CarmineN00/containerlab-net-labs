#!/usr/bin/env bash
# Screenshot reale di una sessione SSH in Windows Terminal.
# Uso: shot.sh <TITOLO_TAB> <mgmt-ip> <out.png> <cols> <rows> <cmdfile> [delay]
# <cmdfile>: un comando per riga; "#sleep N" = pausa di N secondi.
set -e
title=$1; ip=$2; out=$3; cols=$4; rows=$5; cmds=$(realpath "$6"); delay=${7:-2}
here=$(cd "$(dirname "$0")" && pwd)
ps() { powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$here/$1")" "${@:2}" | tr -d '\r'; }
rm -f "$cmds.ready" "$cmds.done"
before=$(ps list_wt.ps1 | cut -f1)
wt.exe -w new --size "$cols,$rows" new-tab --title "$title" --suppressApplicationTitle \
  wsl.exe -d "$WSL_DISTRO_NAME" bash "$here/session.sh" "$ip" "$cmds" "$delay" >/dev/null 2>&1
for i in $(seq 1 180); do [ -f "$cmds.ready" ] && break; sleep 1; done
[ -f "$cmds.ready" ] || { echo "timeout: la sessione non ha finito i comandi" >&2; touch "$cmds.done"; exit 1; }
sleep 2
hwnd=$(ps list_wt.ps1 | awk -F'\t' -v t="$title" '$2==t{print $1}' | grep -vxF -f <(echo "$before") | head -1)
[ -n "$hwnd" ] || { echo "finestra '$title' non trovata" >&2; touch "$cmds.done"; exit 1; }
mkdir -p "$(dirname "$out")"
ps capture.ps1 -Hwnd "$hwnd" -Out "$(wslpath -w "$(realpath -m "$out")")"
touch "$cmds.done"
