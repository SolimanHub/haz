#!/bin/bash
# Funciones para ejecutar comandos y guardar salida

inicializar_registro() {
    local archivo="$1"
    local query="$2"
    local modelo="$3"
    local tipo="$4"
    local comando="$5"
    cat > "$archivo" <<EOF
# Registro - $(date)
**Prompt:**
\`\`\`
$query
\`\`\`
**Modelo:** $modelo ($tipo)
## Comando
\`\`\`bash
$comando
\`\`\`
## Salida
\`\`\`text
EOF
}

ejecutar_y_registrar() {
    local cmd="$1"
    local archivo="$2"
    local ini=$(stat -c %s "$archivo" 2>/dev/null || echo 0)

    echo -e "\033[32m$cmd\033[0m"
    echo -e "\033[36m== Ejecutando =="
    eval "$cmd" 2>&1 | tee -a "$archivo"
    local ec=${PIPESTATUS[0]}

    # Si falla por permisos, ofrecer sudo
    if [[ $ec -ne 0 ]] && grep -qiE "permission denied|EACCES|EPERM|not root" "$archivo" 2>/dev/null; then
        echo -en "\033[33m⚠ ¿sudo? [s/N] \033[0m"
        read -r r
        if [[ "$r" =~ ^[Ss] ]]; then
            if ! sudo -v 2>/dev/null; then
                echo -e "\033[31m✖ Fallo auth\033[0m"
                return 1
            fi
            echo -e "\033[36m== Con sudo =="
            sudo $cmd 2>&1 | tee -a "$archivo" >/dev/null
            ec=$?
        else
            echo -e "\033[33m✖ Cancelado\033[0m"
            return 1
        fi
    fi

    local fin=$(stat -c %s "$archivo" 2>/dev/null || echo 0)
    if [[ "$fin" -gt "$ini" ]]; then
        return 2  # Hubo salida
    fi
    return $ec
}

mostrar_resultado() {
    local res=$1
    case $res in
        0) echo -e "\033[32m✔ OK\033[0m" ;;
        2) echo -e "\033[32m✔ Con salida\033[0m" ;;
        *) echo -e "\033[31m✖ Error $res\033[0m" ;;
    esac
}
