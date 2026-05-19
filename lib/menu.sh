#!/bin/bash
# Muestra el menú y selecciona modelo

MODELOS_REMOTOS=(
    "nvidia/nemotron-3-super-120b-a12b:free"
    "poolside/laguna-m.1:free"
    "openai/gpt-oss-120b:free"
    "z-ai/glm-4.5-air:free"
    "deepseek/deepseek-v4-flash:free"
    "arcee-ai/trinity-large-thinking:free"
)

# Variables globales que se establecerán
modelo=""
tipo=""
script_consulta=""

seleccionar_modelo() {
    # Obtener modelos locales
    local modelos_locales=()
    if command -v ollama >/dev/null; then
        mapfile -t modelos_locales < <(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')
    fi

    # Mostrar menú
    echo -e "\033[1;36mLocales\033[0m"
    for i in "${!modelos_locales[@]}"; do
        printf "\033[1;32m[%d]\033[0m \033[0;36m%s\033[0m\n" $((i+1)) "${modelos_locales[$i]}"
    done
    echo -e "\033[1;36mRemotos\033[0m"
    for i in "${!MODELOS_REMOTOS[@]}"; do
        printf "\033[1;32m[%d]\033[0m \033[0;36m%s\033[0m\n" $((${#modelos_locales[@]}+i+1)) "${MODELOS_REMOTOS[$i]}"
    done

    read -p "$(echo -e '\033[1;33mModelo (número): \033[0m')" sel
    total=$((${#modelos_locales[@]} + ${#MODELOS_REMOTOS[@]}))
    if [[ ! "$sel" =~ ^[0-9]+$ ]] || [[ "$sel" -lt 1 ]] || [[ "$sel" -gt "$total" ]]; then
        echo -e "\033[31mInválido\033[0m"
        exit 1
    fi

    if [[ "$sel" -le "${#modelos_locales[@]}" ]]; then
        modelo="${modelos_locales[$((sel-1))]}"
        tipo="local"
        script_consulta="$DIR/consulta_local.sh"
    else
        local idx=$((sel - ${#modelos_locales[@]} - 1))
        modelo="${MODELOS_REMOTOS[$idx]}"
        tipo="remoto"
        script_consulta="$DIR/consulta_remota.sh"
    fi

    echo -e "\033[1;32mModelo:\033[0m \033[0;36m$modelo\033[0m ($tipo)"
}
