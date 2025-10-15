#!/bin/bash
#PU2UJN
LOG_FILE="/var/log/svxlink"
#GPIO selecionar para acionar a fan
COOLER_GPIO=26
#Tempo em segundos para manter acionado apos final do cambio
COOLER_TIMEOUT=60  # ou 30 segundos na versão final
TIME_FILE="/tmp/svxlink_last_tx_off"
STATUS_FILE="/tmp/svxlink_cooler_on"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Monitoramento iniciado (baseado em log SVXLink)..."

# Funções
ligar_cooler() {
    if [ ! -f "$STATUS_FILE" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] TX ON – Cooler LIGADO"
        gpioset --mode=exit gpiochip0 $COOLER_GPIO=1
        touch "$STATUS_FILE"
    fi
    rm -f "$TIME_FILE" 2>/dev/null
}

desligar_cooler() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cooler DESLIGADO após $COOLER_TIMEOUT segundos sem TX"
    gpioset --mode=exit gpiochip0 $COOLER_GPIO=0
    rm -f "$STATUS_FILE" "$TIME_FILE" 2>/dev/null
}

# Processo 1: monitora o log
monitor_log() {
    stdbuf -oL tail -F "$LOG_FILE" | while read -r line; do
        if echo "$line" | grep -q "Tx1: Turning the transmitter ON"; then
            ligar_cooler
        elif echo "$line" | grep -q "Tx1: Turning the transmitter OFF"; then
#            echo "[$(date '+%Y-%m-%d %H:%M:%S')] TX OFF – Aguardando $COOLER_TIMEOUT segundos para desligar cooler"
            date +%s > "$TIME_FILE"
        fi
    done
}

# Processo 2: checa o tempo e desliga se necessário
monitor_timeout() {
    while true; do
        if [ -f "$STATUS_FILE" ] && [ -f "$TIME_FILE" ]; then
            last_off=$(cat "$TIME_FILE")
            now=$(date +%s)
            diff=$((now - last_off))
            if [ "$diff" -ge "$COOLER_TIMEOUT" ]; then
                desligar_cooler
            fi
        fi
        sleep 1
    done
}

# Inicia os dois processos em paralelo
monitor_log &
monitor_timeout &

wait
