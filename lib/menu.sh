#!/bin/bash

MODELOS_REMOTOS=(
    "nvidia/nemotron-3-super-120b-a12b:free"
    "poolside/laguna-m.1:free"
    "openai/gpt-oss-120b:free"
    "z-ai/glm-4.5-air:free"
    "deepseek/deepseek-v4-flash:free"
    "arcee-ai/trinity-large-thinking:free"
)

modelo=""
tipo=""
script_consulta=""
LAST_MODEL_FILE="$HOME/.haz/haz_last_model"

seleccionar_modelo() {
    local modelos_locales=()
    if command -v ollama >/dev/null; then
        mapfile -t modelos_locales < <(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')
    fi

    local total_locales=${#modelos_locales[@]}
    local total_remotos=${#MODELOS_REMOTOS[@]}
    local total=$((total_locales + total_remotos))

    # Leer última selección
    local last_sel=""
    if [[ -f "$LAST_MODEL_FILE" ]]; then
        last_sel=$(cat "$LAST_MODEL_FILE")
        # Validar que el número esté en rango (por si cambió la lista)
        if [[ ! "$last_sel" =~ ^[0-9]+$ ]] || [[ "$last_sel" -lt 1 ]] || [[ "$last_sel" -gt "$total" ]]; then
            last_sel=""
        fi
    fi

    # Mostrar menú
    echo -e "\033[1;36mLocales\033[0m"
    for i in "${!modelos_locales[@]}"; do
        local num=$((i+1))
        if [[ -n "$last_sel" && "$num" -eq "$last_sel" ]]; then
            printf "\033[1;32m[%d]\033[0m \033[0;36m%s\033[0m \033[33m(default)\033[0m\n" "$num" "${modelos_locales[$i]}"
        else
            printf "\033[1;32m[%d]\033[0m \033[0;36m%s\033[0m\n" "$num" "${modelos_locales[$i]}"
        fi
    done
    echo -e "\033[1;36mRemotos\033[0m"
    for i in "${!MODELOS_REMOTOS[@]}"; do
        local num=$((total_locales + i + 1))
        if [[ -n "$last_sel" && "$num" -eq "$last_sel" ]]; then
            printf "\033[1;32m[%d]\033[0m \033[0;36m%s\033[0m \033[33m(default)\033[0m\n" "$num" "${MODELOS_REMOTOS[$i]}"
        else
            printf "\033[1;32m[%d]\033[0m \033[0;36m%s\033[0m\n" "$num" "${MODELOS_REMOTOS[$i]}"
        fi
    done

    local prompt_msg="\033[1;33mModelo (número) [Enter para usar default${last_sel:+ $last_sel}]: \033[0m"
    read -p "$(echo -e "$prompt_msg")" sel

    # Si no ingresa nada y tenemos default, usar ese
    if [[ -z "$sel" && -n "$last_sel" ]]; then
        sel="$last_sel"
    fi

    if [[ ! "$sel" =~ ^[0-9]+$ ]] || [[ "$sel" -lt 1 ]] || [[ "$sel" -gt "$total" ]]; then
        echo -e "\033[31mInválido\033[0m"
        exit 1
    fi

    # Guardar selección
    echo "$sel" > "$LAST_MODEL_FILE"

    if [[ "$sel" -le "$total_locales" ]]; then
        modelo="${modelos_locales[$((sel-1))]}"
        tipo="local"
        script_consulta="$DIR/consulta_local.sh"
    else
        local idx=$((sel - total_locales - 1))
        modelo="${MODELOS_REMOTOS[$idx]}"
        tipo="remoto"
        script_consulta="$DIR/consulta_remota.sh"
    fi

    # Verificar que el script existe y es ejecutable
    if [[ ! -x "$script_consulta" ]]; then
        echo -e "\033[31mError: $script_consulta no existe o no es ejecutable\033[0m"
        exit 1
    fi

    echo -e "\033[1;32mModelo:\033[0m \033[0;36m$modelo\033[0m ($tipo)"
}
