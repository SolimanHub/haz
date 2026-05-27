#!/bin/bash

# Directorio de logs (expande ~ correctamente)
LOGS_DIR="$HOME/.haz/logs_haz"
export LOGS_DIR
export HAZ_LOG_FILE=""

# Crear directorio de logs si no existe
if [ ! -d "$LOGS_DIR" ]; then
    mkdir -p "$LOGS_DIR"
fi

generar_nombre_archivo_md() {
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
    if [[ ! -f "$DIR/config/prompt.md" ]]; then
        echo -e "\033[31mError: No se encuentra config/prompt.md\033[0m"
        echo "Crea el archivo con el contenido base."
        exit 1
    fi
}

mostrar_uso() {
    echo -e "\033[31mUso: haz [-m <índice>] [--depth <n>] <consulta>\033[0m"
}

leer_prompt_base() {
    local prompt_file="$DIR/config/prompt.md"
    if [[ ! -f "$prompt_file" ]]; then
        echo "ERROR: No se encuentra $prompt_file" >&2
        exit 1
    fi
    cat "$prompt_file"
}

generar_prompt() {
    local my_system="$1"
    local query="$2"
    local depth="$3"
    local model_index="$4"
    local base_prompt
    base_prompt=$(leer_prompt_base)
    base_prompt="${base_prompt//'{{system_info}}'/$my_system}"
    base_prompt="${base_prompt//'{{query}}'/$query}"

    # Leer ficheros mencionados en la consulta
    source "$DIR/lib/file_reader.sh"
    local ficheros_contenido=$(leer_ficheros_de_consulta "$query" "$PWD")
    if [ -n "$ficheros_contenido" ]; then
        base_prompt+="

## Ficheros proporcionados para esta tarea
$ficheros_contenido"
    fi

    # Inyectar información de recursividad
    base_prompt+="
**Índice del modelo actual**: $model_index
**Profundidad de recursión actual**: $depth (máx: 5)
"

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
