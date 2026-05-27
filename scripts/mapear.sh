#!/bin/bash

# =============================================================================
# Script: mapear.sh
# Descripción: Genera un árbol de directorios y archivos, similar a 'tree',
#              excluyendo automáticamente numerosos elementos innecesarios.
# Exclusiones automáticas (siempre activas):
#   - Cualquier elemento que empiece con .git (.git, .gitignore, ...)
#   - Archivos o directorios llamados exactamente .env
#   - Archivos .env.local, .env.production, etc.
#   - Directorios comunes: node_modules, vendor, __pycache__, .venv, venv, env,
#                           dist, build, target, .gradle, .mvn, .idea, .vscode,
#                           .cache, coverage, .pytest_cache, .tox, .nox, htmlcov,
#                           .nyc_output, .DS_Store, Thumbs.db
#   - Archivos por extensión: *.pyc, *.pyo, *.log, *.tmp, *.temp, *.swp, *.swo,
#                             *.bak, *.old, *~, *.pem, *.key, *.crt, *.secrets
#   - Archivos de imagen y vídeo (formatos más comunes)
#   - El propio script (si está dentro del directorio mapeado)
# Uso: ./mapear.sh [directorio] [-I excl1 excl2 ...]
#      Si no se especifica directorio, usa el actual.
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Función para determinar si una ruta debe ser excluida
# -----------------------------------------------------------------------------
debe_excluir() {
    local rel="$1"
    local base_name=$(basename "$rel")

    # --- Exclusiones automáticas (siempre activas) ---

    # 1. Todo .git*
    [[ "$rel" == .git* ]] && return 0

    # 2. Archivos .env exactos o con punto ( .env, .env.local, .env.production, etc.)
    if [[ "$base_name" == ".env" ]] || [[ "$base_name" == .env.* ]]; then
        return 0
    fi

    # 3. Directorios comunes de dependencias, caché y build
    case "$base_name" in
        node_modules|vendor|__pycache__|.venv|venv|env|dist|build|target|\
        .gradle|.mvn|.idea|.vscode|.cache|coverage|.pytest_cache|.tox|.nox|\
        htmlcov|.nyc_output|.DS_Store|Thumbs.db)
            return 0
            ;;
    esac

    # 4. Archivos por extensión o patrón (incluye logs, temporales, respaldos,
    #    imágenes, vídeos, etc.)
    # Convertir el nombre a minúsculas para comparar extensiones de forma insensible
    lower_name=$(echo "$base_name" | tr '[:upper:]' '[:lower:]')
    case "$lower_name" in
        *.pyc|*.pyo|*.log|*.tmp|*.temp|*.swp|*.swo|*.bak|*.old|*~|\
        *.pem|*.key|*.crt|*.secrets|\
        *.jpg|*.jpeg|*.png|*.gif|*.bmp|*.tiff|*.tif|*.webp|*.svg|*.ico|*.heic|\
        *.mp4|*.mkv|*.avi|*.mov|*.wmv|*.flv|*.webm|*.mpeg|*.mpg|*.m4v|*.3gp|\
        *.ogv|*.ts|*.mts|*.vob)
            return 0
            ;;
    esac

    # 5. Excluir el propio script (si está dentro del árbol)
    if [[ -n "$SCRIPT_REL" && "$rel" == "$SCRIPT_REL" ]]; then
        return 0
    fi

    # --- Exclusiones especificadas por el usuario con -I ---
    for excl in "${EXCLUDE_ITEMS[@]}"; do
        excl_clean="${excl%/}"
        if [[ -d "$excl_clean" ]]; then
            # Si es directorio, excluir la ruta igual o dentro
            if [[ "$rel" == "$excl_clean" || "$rel" == "$excl_clean"/* ]]; then
                return 0
            fi
        else
            # Exclusión exacta para archivo (puede ser también un patrón simple)
            if [[ "$rel" == "$excl_clean" ]]; then
                return 0
            fi
        fi
    done

    return 1
}

# -----------------------------------------------------------------------------
# Generar árbol a partir de una lista de rutas (stdin: una ruta por línea)
# -----------------------------------------------------------------------------
generar_arbol_desde_lista() {
    awk '
    BEGIN {
        indent = "    "
    }
    {
        path = $0
        gsub(/^\.\//, "", path)
        if (path == "") path = "."

        n = split(path, parts, "/")
        prefix = ""
        for (i = 1; i < n; i++) {
            prefix = prefix indent
        }
        # Determinar si es directorio
        is_dir = (system("[ -d \"" $0 "\" ]") == 0)
        suffix = (is_dir && path != ".") ? "/" : ""
        last = parts[n]
        if (path == ".") {
            print "."
        } else {
            printf "%s├── %s%s\n", prefix, last, suffix
        }
    }'
}

# -----------------------------------------------------------------------------
# Recolectar todas las rutas (archivos y directorios) dentro del directorio base
# aplicando exclusiones
# -----------------------------------------------------------------------------
recolectar_rutas() {
    find . \( -type f -o -type d \) -print0 2>/dev/null | while IFS= read -r -d '' r; do
        rel="${r#./}"
        debe_excluir "$rel" && continue
        echo "$rel"
    done | sort -u
}

# -----------------------------------------------------------------------------
# Inicialización y parseo de argumentos
# -----------------------------------------------------------------------------

BASE_DIR="."
EXCLUDE_ITEMS=()

args=("$@")
i=0
while [[ $i -lt ${#args[@]} ]]; do
    case "${args[$i]}" in
        -I)
            i=$((i+1))
            while [[ $i -lt ${#args[@]} && "${args[$i]}" != "-I" ]]; do
                EXCLUDE_ITEMS+=("${args[$i]}")
                i=$((i+1))
            done
            ;;
        -*)
            echo "Error: Opción desconocida '${args[$i]}'" >&2
            exit 1
            ;;
        *)
            if [[ -d "${args[$i]}" ]]; then
                BASE_DIR="${args[$i]}"
            else
                echo "Error: '${args[$i]}' no es un directorio válido" >&2
                exit 1
            fi
            i=$((i+1))
            ;;
    esac
done

# Cambiar al directorio base
cd "$BASE_DIR" || { echo "Error: No se pudo acceder a '$BASE_DIR'"; exit 1; }

# Ruta relativa del script (si está dentro del directorio actual)
SCRIPT_ABS=$(realpath "$0" 2>/dev/null || readlink -f "$0")
SCRIPT_REL=""
if [[ "$SCRIPT_ABS" == "$(pwd)"* ]]; then
    SCRIPT_REL="${SCRIPT_ABS#$(pwd)/}"
fi

# -----------------------------------------------------------------------------
# Generar y mostrar el árbol
# -----------------------------------------------------------------------------
recolectar_rutas | generar_arbol_desde_lista
