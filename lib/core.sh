#!/bin/bash

# Directorio de logs (expande ~ correctamente)
LOGS_DIR="$HOME/logs_haz"

# Crear directorio de logs si no existe
if [ ! -d "$LOGS_DIR" ]; then
    mkdir -p "$LOGS_DIR"
fi

generar_nombre_archivo_md() {
    # Devuelve la ruta completa dentro de LOGS_DIR
    echo "$LOGS_DIR/log_haz_command_$(date +'%Y-%m-%d_%H-%M-%S').md"
}

es_comando_seguro() {
    local cmd="$1"
    local peligrosos=(
        "rm -rf /" "rm -rf ~" "dd if=" "mkfs" "fdisk" "parted"
        ":(){ :|:& };:" "shutdown -h now" "reboot" "mv / /dev/null"
        "chmod -R 777 /" "chown -R root:root /" "> /dev/sda" "dd of=/dev/sda"
    )
    for p in "${peligrosos[@]}"; do
        [[ "$cmd" == *"$p"* ]] && return 1
    done
    return 0
}

verificar_dependencias() {
    command -v curl >/dev/null && command -v jq >/dev/null || {
        echo -e "\033[31mError: instala curl y jq\033[0m"
        exit 1
    }
    # Verificar que exista el archivo de prompt
    if [[ ! -f "$DIR/config/prompt.md" ]]; then
        echo -e "\033[31mError: No se encuentra config/prompt.md\033[0m"
        echo "Crea el archivo con el contenido base."
        exit 1
    fi
}

mostrar_uso() {
    echo -e "\033[31mUso: haz <consulta>\033[0m"
}

# Lee el archivo de prompt markdown
leer_prompt_base() {
    local prompt_file="$DIR/config/prompt.md"
    if [[ ! -f "$prompt_file" ]]; then
        echo "ERROR: No se encuentra $prompt_file" >&2
        exit 1
    fi
    cat "$prompt_file"
}

# Genera el prompt final reemplazando {{system_info}} y {{query}}
generar_prompt() {
    local my_system="$1"
    local query="$2"
    local base_prompt
    base_prompt=$(leer_prompt_base)
    base_prompt="${base_prompt//'{{system_info}}'/$my_system}"
    base_prompt="${base_prompt//'{{query}}'/$query}"
    echo "$base_prompt"
}

limpiar_comando() {
    local cmd="$1"
    printf '%s' "$cmd" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

validar_comando() {
    local comando="$1"
    if [[ "$comando" == ERROR:* ]]; then
        echo -e "\033[31m✖ $comando\033[0m"
        return 1
    fi
    while IFS= read -r line; do
        line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        # Validación específica para rm -rf
        if [[ "$line" =~ rm[[:space:]]+-rf[[:space:]]+([^[:space:]]+) ]]; then
            local path="${BASH_REMATCH[1]}"
            if [[ "$path" == /* || "$path" == *"*"* || "$path" == *"~"* || "$path" == "" ]]; then
                echo -e "\033[31m✖ rm -rf con ruta absoluta o patrón peligroso: $line\033[0m"
                return 1
            fi
        fi

        if ! es_comando_seguro "$line"; then
            echo -e "\033[31m✖ Comando inseguro: $line\033[0m"
            return 1
        fi
    done <<< "$comando"
    return 0
}

extraer_bloque_bash() {
    local respuesta="$1"
    local bloque
    bloque=$(echo "$respuesta" | sed -n '/^```bash$/,/^```$/p' | sed '1d;$d')
    if [[ -n "$bloque" ]]; then
        echo "$bloque"
    else
        echo "$respuesta"
    fi
}
