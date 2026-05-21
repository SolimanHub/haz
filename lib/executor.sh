#!/bin/bash

inicializar_registro() {
    local archivo="$1"
    local query="$2"
    local modelo="$3"
    local tipo="$4"
    local comando="$5"

    if [ -z "$HAZ_LOG_FILE" ]; then
        # Primera llamada (nivel 0): crear nuevo log
        export HAZ_LOG_FILE="$archivo"
        cat > "$HAZ_LOG_FILE" <<EOF
# Registro - $(date)
**Prompt:**
\`\`\`
$query
\`\`\`
**Modelo:** $modelo ($tipo)
## Script / Comando generado
\`\`\`bash
$comando
\`\`\`
## Salida
\`\`\`text
EOF
    else
        # Subtarea recursiva: añadir al log existente
        cat >> "$HAZ_LOG_FILE" <<EOF

---
### Subtarea recursiva - $(date)
**Prompt:**
\`\`\`
$query
\`\`\`
**Modelo:** $modelo ($tipo) [profundidad: ${recursion_depth:-0}]
## Script / Comando generado
\`\`\`bash
$comando
\`\`\`
## Salida
\`\`\`text
EOF
    fi
}

ejecutar_y_registrar() {
    local cmd="$1"
    local archivo="${HAZ_LOG_FILE:-$2}"   # si no hay variable, usar el parámetro

    # Crear un script temporal, inyectando variables de entorno
    local temp_script
    temp_script=$(mktemp)
    cat > "$temp_script" <<EOF
RECURSION_DEPTH=${recursion_depth:-0}
MODEL_INDEX=${MODEL_INDEX:-}
$cmd
EOF
    chmod +x "$temp_script"

    echo -e "\033[32mScript a ejecutar:\033[0m"
    echo -e "\033[90m$cmd\033[0m"
    echo -e "\033[36m== Ejecutando ==\033[0m"

    # Ejecutar y capturar salida (se añade al log principal)
    "$temp_script" 2>&1 | tee -a "$archivo"
    local ec=${PIPESTATUS[0]}

    # Si falla por permisos, preguntar por sudo
    if [[ $ec -ne 0 ]] && grep -qiE "permission denied|EACCES|EPERM|not root" "$archivo" 2>/dev/null; then
        echo -en "\033[33m⚠ El script requiere permisos elevados. ¿Ejecutar con sudo? [s/N] \033[0m"
        read -r r
        if [[ "$r" =~ ^[Ss] ]]; then
            if ! sudo -v 2>/dev/null; then
                echo -e "\033[31m✖ Fallo autenticación\033[0m"
                rm -f "$temp_script"
                return 1
            fi
            echo -e "\033[36m== Ejecutando con sudo ==\033[0m"
            sudo "$temp_script" 2>&1 | tee -a "$archivo"
            ec=$?
        else
            echo -e "\033[33m✖ Cancelado\033[0m"
            rm -f "$temp_script"
            return 1
        fi
    fi

    rm -f "$temp_script"

    # Cerrar bloque de código en el archivo de log
    echo "\`\`\`" >> "$archivo"

    if [[ $ec -eq 0 ]]; then
        return 0
    else
        return 2  # Código 2 = error en ejecución
    fi
}

mostrar_resultado() {
    local res=$1
    case $res in
        0) echo -e "\033[32m✔ OK - Script ejecutado correctamente\033[0m" ;;
        2) echo -e "\033[31m✖ El script terminó con error (código distinto de 0)\033[0m" ;;
        *) echo -e "\033[31m✖ Error $res\033[0m" ;;
    esac
}
