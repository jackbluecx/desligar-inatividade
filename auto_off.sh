#!/bin/bash
# /usr/local/bin/auto-shutdown.sh
set -uo pipefail

# --- CONFIGURAÇÕES ---
LIMITE_PC=600       # 10 minutos para desligar o PC
LIMITE_TELA=60      # 1 minuto para desligar a TELA
INTERVALO=2         # Intervalo de checagem (segundos)
GPU_THRESHOLD=10    # Tolerância de uso da GPU (%)

USER_DISPLAY_ENV_SET=false

# --- FUNÇÃO: Detectar Sessão Gráfica ---
get_display_env() {
    if [ -n "${DISPLAY:-}" ] && [ -n "${XAUTHORITY:-}" ]; then
        USER_DISPLAY_ENV_SET=true
        return 0
    fi
    local xuser=""
    xuser=$(ps -eo user,cmd | awk '/[X]org|xwayland/ {print $1}' | head -n 1)
    if [ -z "$xuser" ]; then
        xuser=$(who | grep -E 'tty|:0' | head -n 1 | awk '{print $1}')
    fi
    if [ -n "$xuser" ]; then
        export DISPLAY=:0
        export XAUTHORITY="/home/$xuser/.Xauthority"
        USER_DISPLAY_ENV_SET=true
        return 0
    fi
    return 1
}

# --- FUNÇÃO: Verificar Áudio (Via Hardware/ALSA) ---
is_audio_playing() {
    # Verifica diretamente nos arquivos do driver se a placa de som está com status RUNNING
    # Isso ignora softwares de áudio e problemas de tradução.
    if grep -q "RUNNING" /proc/asound/card*/pcm*/sub*/status 2>/dev/null; then
        return 0 # Áudio tocando (True)
    fi
    return 1 # Silêncio (False)
}

# --- FUNÇÃO: Verificar GPU ---
is_gpu_busy() {
    local uso=0
    for gpu_file in /sys/class/drm/card*/device/gpu_busy_percent; do
        if [ -f "$gpu_file" ]; then
            read -r uso < "$gpu_file" 2>/dev/null || uso=0
            if ! [[ "$uso" =~ ^[0-9]+$ ]]; then uso=0; fi
            if (( uso > GPU_THRESHOLD )); then
                return 0 # Ocupada
            fi
        fi
    done
    return 1 # Ociosa
}

# --- FUNÇÃO: Tempo Ocioso ---
get_idle_time() {
    if [ "$USER_DISPLAY_ENV_SET" = true ] && command -v xprintidle >/dev/null 2>&1; then
        echo $(($(xprintidle 2>/dev/null) / 1000))
    else
        echo 0
    fi
}

desligar_monitor() {
    if [ "$USER_DISPLAY_ENV_SET" = true ]; then
        xset dpms force off 2>/dev/null
    fi
}

# --- INICIALIZAÇÃO ---
get_display_env

if [ "$USER_DISPLAY_ENV_SET" = false ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO FATAL: Ambiente gráfico não detectado."
    exit 1
fi

# --- LOOP PRINCIPAL ---
while true; do
    IDLE_SEC=$(get_idle_time)
    
    # Verifica bloqueadores: GPU ou Áudio
    BLOCK_SHUTDOWN=0
    
    if is_gpu_busy; then
        BLOCK_SHUTDOWN=1
    elif is_audio_playing; then
        BLOCK_SHUTDOWN=1
    fi

    # --- Lógica da TELA ---
    # Só desliga tela se: mouse parado > limite E (gpu ociosa E áudio parado)
    if (( IDLE_SEC >= LIMITE_TELA )); then
        if (( BLOCK_SHUTDOWN == 0 )); then
             # Evita spam do comando
             if (( IDLE_SEC < (LIMITE_TELA + INTERVALO + 10) )); then
                desligar_monitor
             fi
        fi
    fi

    # --- Lógica do PC ---
    if (( IDLE_SEC >= LIMITE_PC )); then
        if (( BLOCK_SHUTDOWN == 0 )); then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Inatividade total (Input/GPU/Audio). Desligando..."
            shutdown -h now
            exit 0
        fi
    fi

    sleep $INTERVALO
done
