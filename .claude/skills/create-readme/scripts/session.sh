#!/usr/bin/env bash
# Eseguito DENTRO la tab di Windows Terminal: apre una sessione SSH interattiva
# e "digita" i comandi del file, uno ogni DELAY secondi. Dopo l'ultimo comando
# la sessione resta aperta finché non compare il file <cmdfile>.done.
# Uso: session.sh <mgmt-ip> <cmdfile> [delay] [user] [password]
ip=$1; cmds=$2; delay=${3:-2}; user=${4:-admin}; pass=${5:-admin}
feed() {
  sleep 4
  echo "terminal length 0"; echo "terminal width 0"; sleep 1
  printf '\033[2J\033[3J\033[H' > /dev/tty      # pulisce lo schermo prima dei comandi "veri"
  echo ""; sleep 1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "#sleep "*) sleep "${line#\#sleep }" ;;   # pausa extra: riga "#sleep N"
      *) echo "$line"; sleep "$delay" ;;
    esac
  done < "$cmds"
  touch "$cmds.ready"
  while [ ! -f "$cmds.done" ]; do sleep 1; done
  echo exit
}
feed | sshpass -p "$pass" ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$user@$ip"
