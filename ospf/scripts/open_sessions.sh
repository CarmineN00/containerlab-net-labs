#!/bin/bash
declare -A ROUTERS=(
    [R1]="172.20.20.10"
    [R2]="172.20.20.20"
    [R3]="172.20.20.30"
    [R4]="172.20.20.40"
    [R5]="172.20.20.50"
    [R6]="172.20.20.60"
    [R7]="172.20.20.70"
    [R8]="172.20.20.80"
)

PASS="admin"

CMD="wt.exe -w 0"
first=true
for name in "${!ROUTERS[@]}"; do
    ip=${ROUTERS[$name]}
    if $first; then
        CMD="$CMD new-tab --title \"$name\" wsl.exe sshpass -p $PASS ssh -o StrictHostKeyChecking=no admin@$ip"
        first=false
    else
        CMD="$CMD \; new-tab --title \"$name\" wsl.exe sshpass -p $PASS ssh -o StrictHostKeyChecking=no admin@$ip"
    fi
done
eval $CMD
