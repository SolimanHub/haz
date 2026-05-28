#!/bin/bash
# =============================================================================
# lib/preanalysis.sh — Módulo de preanálisis de contexto
# =============================================================================
# Antes de enviar el prompt al modelo principal, este módulo analiza la
# petición de forma iterativa para recopilar el contexto necesario:
#   · Itera hasta PREANALISIS_MAX_RECURSION veces (máx. 5).
#   · Cada iteración genera un script bash que puede:
#       exit 100 → necesita más datos (tree, cat, etc.)
#       exit 0   → contexto completo, termina el bucle
#   · Retorna el contexto acumulado para añadirlo al prompt principal.
# =============================================================================

# ------------------------------------------------------------------
# _cargar_config_preanalisis
# Lee config.json y exporta las variables de configuración.
# ------------------------------------------------------------------
_cargar_config_preanalisis() {
    local config_file="$DIR/config/config.json"

    if [[ ! -f "$config_file" ]]; then
        PREANALISIS_ENABLED="false"
        return 0
    fi

    PREANALISIS_ENABLED=$(jq -r '.preanalysis.enabled // false'    "$config_file" 2>/dev/null)
    PREANALISIS_MODEL=$(jq -r   '.preanalysis.model   // "liquid/lfm-2.5-1.2b-instruct:free"' "$config_file" 2>/dev/null)
    PREANALISIS_TYPE=$(jq -r    '.preanalysis.type    // "remote"' "$config_file" 2>/dev/null)
    PREANALISIS_MAX_RECURSION=$(jq -r '.preanalysis.max_recursion // 5' "$config_file" 2>/dev/null)
    PREANALISIS_EXCLUDE=$(jq -r '.exclude_patterns // ".git,node_modules,.env,.gitignore"' "$config_file" 2>/dev/null)

    if [[ "$PREANALISIS_TYPE" == "local" ]]; then
        PREANALISIS_SCRIPT="$DIR/consulta_local.sh"
    else
        PREANALISIS_SCRIPT="$DIR/consulta_remota.sh"
    fi

    export PREANALISIS_ENABLED PREANALISIS_MODEL PREANALISIS_TYPE \
           PREANALISIS_MAX_RECURSION PREANALISIS_EXCLUDE PREANALISIS_SCRIPT
}

# ------------------------------------------------------------------
# preanalisis_habilitado
# Retorna 0 (true) si el preanálisis está activo en config.json.
# ------------------------------------------------------------------
preanalisis_habilitado() {
    _cargar_config_preanalisis
    [[ "$PREANALISIS_ENABLED" == "true" ]]
}

# ------------------------------------------------------------------
# _inferir_dir_base  <query>  <default_dir>
# Intenta extraer una ruta del query del usuario.
# Si el usuario escribió ~/.config/waybar/config.jsonc, usa ese dir.
# Si solo puso el nombre del fichero, usa $PWD (default_dir).
# ------------------------------------------------------------------
_inferir_dir_base() {
    local query="$1"
    local default_dir="$2"

    # Buscar rutas absolutas (~/ o /)
    local path
    path=$(echo "$query" | grep -oE '~/[a-zA-Z0-9_./-]+|/[a-zA-Z0-9_./-]+' | head -1)

    if [[ -n "$path" ]]; then
        # Expandir ~
        path="${path/#\~/$HOME}"
        if [[ -f "$path" ]]; then
            dirname "$path"
            return
        elif [[ -d "$path" ]]; then
            echo "$path"
            return
        fi
    fi

    echo "$default_dir"
}

# ------------------------------------------------------------------
# _validar_script_preanalisis  <script>
# Rechaza scripts que contengan comandos destructivos o de escritura.
# Solo se permiten: tree cat ls find grep pwd echo printf head tail
#                   wc realpath dirname basename exit
# ------------------------------------------------------------------
_validar_script_preanalisis() {
    local script="$1"

    # Lista de comandos prohibidos en scripts de preanálisis
    local bloqueados=(
        "rm" "mv" "cp" "chmod" "chown"
        "curl" "wget" "fetch"
        "sudo" "su"
        "eval" "exec"
        "dd" "mkfs" "fdisk" "parted" "shred"
        "tee" "mktemp"
        "source" "python" "python3" "perl" "ruby" "node" "php"
        "npm" "pip" "pip3" "apt" "apt-get" "dpkg" "yum" "dnf"
        "systemctl" "service" "kill" "killall" "pkill"
        "crontab" "at" "batch"
    )

    # Eliminar líneas de comentario para el análisis
    local script_sin_comentarios
    script_sin_comentarios=$(echo "$script" | grep -v '^\s*#')

    for cmd in "${bloqueados[@]}"; do
        # Detectar el comando como token (evitar falsos positivos en nombres)
        if echo "$script_sin_comentarios" | grep -qE "(^|[[:space:];|&\`\(])${cmd}([[:space:];|&\`\)\$]|$)"; then
            echo -e "\033[33m⚠  Preanálisis: comando bloqueado → ${cmd}\033[0m" >&2
            return 1
        fi
    done

    # Detectar redirecciones de escritura (> y >>) fuera de echo/printf
    local sin_echo
    sin_echo=$(echo "$script_sin_comentarios" | grep -vE '^\s*(echo|printf)')
    if echo "$sin_echo" | grep -qE '[^<2&1]>[^>]|[^<2&1]>>'; then
        echo -e "\033[33m⚠  Preanálisis: redirección de escritura bloqueada\033[0m" >&2
        return 1
    fi

    return 0
}

# ------------------------------------------------------------------
# _generar_prompt_preanalisis
# Construye el prompt ligero que se envía al modelo de preanálisis.
# ------------------------------------------------------------------
_generar_prompt_preanalisis() {
    local query="$1"
    local dir_base="$2"
    local accumulated_context="$3"
    local iteration="$4"
    local max_recursion="$5"
    local exclude_raw="$6"

    # Convertir "a,b,c" → "a|b|c" para tree -I
    local tree_exclude
    tree_exclude=$(echo "$exclude_raw" | sed 's/,/|/g')

    cat <<PROMPT
# Rol
Eres un analizador de contexto para un asistente CLI Linux/Unix.
Tu ÚNICA tarea es recopilar información de archivos del sistema para que la IA principal pueda completar la petición del usuario.
NO debes resolver la tarea. Solo identificas y lees los archivos relevantes.

# Reglas de respuesta
1. Responde ÚNICAMENTE con un bloque de código bash delimitado por \`\`\`bash y \`\`\`.
2. Comandos permitidos SOLAMENTE: tree, cat, ls, find, grep, pwd, echo, printf, head, tail, wc, realpath, dirname, basename, exit
3. ABSOLUTAMENTE PROHIBIDO: rm, mv, cp, chmod, chown, curl, wget, sudo, eval, exec, dd, tee, mktemp, source, python, node, npm, apt, systemctl, ni cualquier otro comando destructivo o de escritura.
4. No uses redirecciones de escritura (> o >>).
5. Código de salida del script:
   - exit 100 → has recopilado datos parciales, necesitas más información en la siguiente iteración
   - exit 0   → tienes toda la información necesaria (o deja terminar el script sin exit explícito)
6. La salida estándar (stdout) del script se captura como contexto.

# Entorno
- Directorio de trabajo del usuario: ${dir_base}
- Iteración actual: ${iteration} de ${max_recursion}
- Exclusiones para tree: ${tree_exclude}

# Petición del usuario
${query}

# Contexto recopilado hasta ahora
${accumulated_context:-"(ninguno todavía)"}

# Instrucciones por iteración
Iteración 1: Haz tree del directorio relevante para entender la estructura.
  Usa: tree -L 4 -I '${tree_exclude}' --noreport <directorio>
  Si el usuario mencionó una ruta como ~/.config/waybar/, usa ese directorio; si no, usa: ${dir_base}
  Termina con: exit 100

Iteración 2 en adelante: Con la estructura ya visible, identifica y lee los archivos relevantes con cat.
  Si aún faltan archivos, termina con exit 100.
  Cuando tengas todo lo necesario, no pongas exit (o pon exit 0).

Genera ahora el script bash para la iteración ${iteration}.
PROMPT
}

# ------------------------------------------------------------------
# ejecutar_preanalisis  <query>  <dir_base>
# Bucle principal. Retorna por stdout el contexto acumulado.
# Retorna código 0 si obtuvo contexto, 1 si falló completamente.
# ------------------------------------------------------------------
ejecutar_preanalisis() {
    local query="$1"
    local dir_base="$2"

    _cargar_config_preanalisis

    if [[ ! -x "$PREANALISIS_SCRIPT" ]]; then
        echo -e "\033[33m⚠  Script de preanálisis no ejecutable: $PREANALISIS_SCRIPT\033[0m" >&2
        return 1
    fi

    # Inferir directorio base a partir del query (si el usuario puso una ruta)
    dir_base=$(_inferir_dir_base "$query" "$dir_base")

    local accumulated_context=""
    local iteration=0

    echo -e "\033[35m🔍 Preanálisis activado — modelo: ${PREANALISIS_MODEL}\033[0m" >&2

    while [[ $iteration -lt $PREANALISIS_MAX_RECURSION ]]; do
        iteration=$((iteration + 1))
        echo -e "\033[35m   ↳ Iteración ${iteration}/${PREANALISIS_MAX_RECURSION}\033[0m" >&2

        # ── 1. Generar prompt para el modelo de preanálisis ─────────────
        local prompt_preanalisis
        prompt_preanalisis=$(_generar_prompt_preanalisis \
            "$query" \
            "$dir_base" \
            "$accumulated_context" \
            "$iteration" \
            "$PREANALISIS_MAX_RECURSION" \
            "$PREANALISIS_EXCLUDE")

        # ── 2. Consultar el modelo de preanálisis ───────────────────────
        local respuesta
        respuesta=$("$PREANALISIS_SCRIPT" "$PREANALISIS_MODEL" "$prompt_preanalisis" 2>&1)
        local rc_consulta=$?

        if [[ $rc_consulta -ne 0 ]]; then
            echo -e "\033[33m⚠  Fallo en consulta de preanálisis (it. ${iteration})\033[0m" >&2
            # Continuar con el contexto que tengamos, no abortar todo
            break
        fi

        # ── 3. Extraer bloque bash de la respuesta ──────────────────────
        local script_bash
        script_bash=$(echo "$respuesta" | sed -n '/^```bash$/,/^```$/p' | sed '1d;$d')

        # Si no encontró el delimitador con "bash", probar sin lenguaje
        if [[ -z "$script_bash" ]]; then
            script_bash=$(echo "$respuesta" | sed -n '/^```$/,/^```$/p' | sed '1d;$d')
        fi

        # Como último recurso, usar la respuesta cruda
        if [[ -z "$script_bash" ]]; then
            script_bash="$respuesta"
        fi

        # ── 4. Validar el script por seguridad ──────────────────────────
        if ! _validar_script_preanalisis "$script_bash"; then
            echo -e "\033[33m⚠  Script de preanálisis rechazado (it. ${iteration})\033[0m" >&2
            break
        fi

        # ── 5. Ejecutar el script en el directorio base del usuario ─────
        local temp_script
        temp_script=$(mktemp /tmp/haz_preanalisis_XXXXXX.sh)
        printf '#!/bin/bash\ncd %q 2>/dev/null || true\n%s\n' \
            "$dir_base" "$script_bash" > "$temp_script"
        chmod +x "$temp_script"

        local script_output
        script_output=$("$temp_script" 2>/dev/null)
        local exit_code=$?
        rm -f "$temp_script"

        # ── 6. Acumular la salida ────────────────────────────────────────
        if [[ -n "$script_output" ]]; then
            accumulated_context+="
---
#### Datos recopilados — iteración ${iteration}
\`\`\`
${script_output}
\`\`\`
"
        fi

        # ── 7. Decidir si continuar o terminar ──────────────────────────
        if [[ $exit_code -eq 0 ]]; then
            echo -e "\033[35m✔  Preanálisis completado en ${iteration} iteración(es)\033[0m" >&2
            echo "$accumulated_context"
            return 0
        elif [[ $exit_code -eq 100 ]]; then
            # Necesita más datos → continuar el bucle
            continue
        else
            echo -e "\033[33m⚠  Script de preanálisis terminó con código ${exit_code} (it. ${iteration})\033[0m" >&2
            break
        fi
    done

    # Si llegamos aquí con algo de contexto, úsalo de todos modos
    if [[ -n "$accumulated_context" ]]; then
        echo -e "\033[35m✔  Preanálisis finalizado (iteraciones agotadas)\033[0m" >&2
        echo "$accumulated_context"
        return 0
    fi

    echo -e "\033[33m⚠  Preanálisis no pudo recopilar contexto útil\033[0m" >&2
    return 1
}
