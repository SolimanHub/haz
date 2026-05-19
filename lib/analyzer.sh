#!/bin/bash
# Análisis de la salida del comando

analizar_si_es_necesario() {
    local comando="$1"
    local archivo="$2"
    local modelo="$3"
    local tipo="$4"
    local script_consulta="$5"

    echo -en "\033[36m¿Analizar? [s/N] \033[0m"
    read -r a
    if [[ ! "$a" =~ ^[SsYy] ]]; then
        return
    fi

    # Extraer la salida del archivo (texto entre ```text y ```)
    local salida
    salida=$(awk '/^```text$/,/^```$/{if(!/^```/&&!/^##/&&!/^#/)print}' "$archivo" | head -n -1)

    local pexp="Explica en ESPAÑOL (3 líneas máx) qué pasó con '$comando'. Salida: \"\"\"$salida\"\"\""
    local exp
    exp=$("$script_consulta" "$modelo" "$pexp" 2>/dev/null)

    if [[ -n "$exp" && "$exp" != "null" ]]; then
        echo -e "\n## Análisis\n$exp" >> "$archivo"
        echo -e "\033[37m$exp\033[0m"
    else
        echo -e "\033[31mNo se pudo obtener análisis\033[0m"
    fi
}
