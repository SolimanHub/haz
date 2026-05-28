#!/bin/bash

# Obtener el directorio donde está este script (haz)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Procesar argumentos -m, -t, -f, --depth y -r ---
model_flag=""
auto_model=false
recursion_depth=2
tree_flag=false
user_files_flag=false
USER_FILES=()

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
        -f)
            user_files_flag=true
            if [[ -n "$2" && "$2" != -* ]]; then
                # Aceptar lista separada por comas (ej: -f file1,file2)
                IFS=',' read -ra files <<< "$2"
                for f in "${files[@]}"; do
                    # Limpiar espacios alrededor
                    f_clean=$(echo "$f" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    [[ -n "$f_clean" ]] && USER_FILES+=("$f_clean")
                done
                shift 2
            else
                echo -e "\033[31mError: -f requiere una ruta de archivo\033[0m"
                exit 1
            fi
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
    echo "Uso: haz [-m <índice>] [-t] [-f <archivo[,archivo...]>] [--depth <n>|-r <n>] <consulta>"
    exit 1
fi

# --- Control de profundidad máxima ---
if [ "$recursion_depth" -gt 5 ]; then
    echo -e "\033[31m✖ Profundidad máxima de recursión alcanzada (5). Abortando.\033[0m"
    exit 1
fi

# Importar módulos (rutas absolutas)
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

# --- Archivos proporcionados por el usuario (-f) ---
if $user_files_flag && [ ${#USER_FILES[@]} -gt 0 ]; then
    echo -e "\033[36m📄 Procesando ${#USER_FILES[@]} archivo(s) proporcionado(s)...\033[0m"
    file_contents=""
    max_size_kb=100
    for file in "${USER_FILES[@]}"; do
        # Si es ruta relativa, completar con el directorio actual
        if [[ "$file" != /* && "$file" != ~* ]]; then
            file="$PWD/$file"
        fi
        # Expandir ~
        file="${file/#\~/$HOME}"
        if [ -f "$file" ]; then
            mimetype=$(file -b --mime-type "$file" 2>/dev/null)
            case "$mimetype" in
                text/*|application/json|application/xml|application/xhtml+xml|application/javascript|application/x-shellscript) ;;
                *) echo -e "\033[33m⚠  Omitido (tipo no soportado): $file\033[0m" >&2; continue ;;
            esac
            size_kb=$(du -k "$file" | cut -f1)
            if [ "$size_kb" -gt "$max_size_kb" ]; then
                echo -e "\033[33m⚠  Omitido (excede $max_size_kb KB): $file\033[0m" >&2
                continue
            fi
            content=$(cat "$file" 2>/dev/null)
            file_contents+="### ${file}
\`\`\`
${content}
\`\`\`

"
        else
            echo -e "\033[33m⚠  Archivo no encontrado: $file\033[0m" >&2
        fi
    done
    if [ -n "$file_contents" ]; then
        prompt+="

## Archivos proporcionados por el usuario
${file_contents}"
        echo -e "\033[35m✔  Contenido de archivos añadido al prompt\033[0m"
    else
        echo -e "\033[33m⚠  No se pudo añadir contenido de archivos\033[0m"
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
