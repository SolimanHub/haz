#!/bin/bash

# Obtener el directorio donde está este script (haz)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Procesar argumentos -m, -t, --depth y -r ---
model_flag=""
auto_model=false
recursion_depth=2          # Valor por defecto cambiado a 2
tree_flag=false

while [[ "$1" =~ ^- ]]; do
    case "$1" in
        -m)
            if [[ "$2" =~ ^[0-9]+$ ]]; then
                model_flag="$2"
                shift 2
            else
                auto_model=true
                shift
            fi
            ;;
        -t)
            tree_flag=true
            shift
            ;;
        --depth)
            recursion_depth="$2"
            shift 2
            ;;
        -r)
            recursion_depth="$2"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

query="$*"
if [ -z "$query" ]; then
    echo -e "\033[31mError: falta la consulta\033[0m"
    echo "Uso: haz [-m <índice>] [-t] [--depth <n>|-r <n>] <consulta>"
    echo "  -m <índice>   Seleccionar modelo por número"
    echo "  -m            Usar automáticamente el modelo por defecto"
    echo "  -t            Generar mapa del proyecto y añadirlo al prompt"
    exit 1
fi

# --- Control de profundidad máxima ---
if [ "$recursion_depth" -gt 5 ]; then
    echo -e "\033[31m✖ Profundidad máxima de recursión alcanzada (5). Abortando.\033[0m"
    exit 1
fi

# Importar módulos (rutas absolutas) – se elimina preanalysis
source "$DIR/lib/core.sh"
source "$DIR/lib/menu.sh"
source "$DIR/lib/executor.sh"
source "$DIR/lib/analyzer.sh"

# Verificar dependencias básicas
verificar_dependencias

# --- Selección de modelo principal ---
if [ -n "$model_flag" ]; then
    asignar_modelo_por_indice "$model_flag"
elif $auto_model; then
    if [[ -f "$LAST_MODEL_FILE" ]]; then
        default_index=$(cat "$LAST_MODEL_FILE")
        if [[ "$default_index" =~ ^[0-9]+$ ]]; then
            asignar_modelo_por_indice "$default_index"
        else
            echo -e "\033[31mError: archivo de modelo por defecto inválido\033[0m"
            exit 1
        fi
    else
        echo -e "\033[31mError: no hay modelo por defecto. Ejecute 'haz' sin -m para seleccionar uno.\033[0m"
        exit 1
    fi
else
    seleccionar_modelo
fi

export MODEL_INDEX

# --- Mensaje de recursión ---
if [ "$recursion_depth" -gt 0 ]; then
    echo -e "\033[35m↳ Nivel $recursion_depth: ejecutando subtarea...\033[0m"
    echo -e "\033[35m   Consulta: $query\033[0m"
fi

# Obtener información del sistema
my_system=$(hostnamectl | grep -E "Operating System|Kernel|Architecture" | head -n 3)

# Generar prompt base (sin preanálisis)
prompt=$(generar_prompt "$my_system" "$query" "$recursion_depth" "$MODEL_INDEX")

# --- Mapa del proyecto (opción -t) ---
if $tree_flag; then
    map_script="$DIR/scripts/mapear.sh"
    if [[ -x "$map_script" ]]; then
        echo -e "\033[36m🗺  Generando mapa del proyecto...\033[0m"
        mapa=$("$map_script" "$PWD" 2>&1)
        if [[ -n "$mapa" ]]; then
            prompt+="

## Mapa del proyecto
\`\`\`
${mapa}
\`\`\`"
            echo -e "\033[35m✔  Mapa añadido al prompt\033[0m"
        else
            echo -e "\033[33m⚠  El mapa está vacío\033[0m"
        fi
    else
        echo -e "\033[33m⚠  No se encuentra o no es ejecutable: $map_script\033[0m"
    fi
fi

# Obtener respuesta cruda del modelo principal
respuesta_cruda=$("$script_consulta" "$modelo" "$prompt" 2>&1)
if [ $? -ne 0 ] || [ -z "$respuesta_cruda" ]; then
    echo -e "\033[31m✖ Fallo en la consulta al modelo\033[0m"
    echo "Debug: script_consulta=$script_consulta"
    echo "Debug: respuesta_cruda=$respuesta_cruda"
    exit 1
fi

# Extraer bloque bash
comando=$(extraer_bloque_bash "$respuesta_cruda")
if [ -z "$comando" ]; then
    echo -e "\033[31m✖ El modelo no devolvió un bloque de código válido\033[0m"
    exit 1
fi

# Validar seguridad
validar_comando "$comando" || exit 1

# Archivo de registro
archivo=$(generar_nombre_archivo_md)
inicializar_registro "$archivo" "$query" "$modelo" "$tipo" "$comando"

# Ejecutar
ejecutar_y_registrar "$comando" "$archivo"
resultado=$?
mostrar_resultado $resultado

# Análisis opcional si hubo error
if [ $resultado -ne 0 ]; then
    analizar_si_es_necesario "$comando" "$archivo" "$modelo" "$tipo" "$script_consulta"
fi

exit 0
