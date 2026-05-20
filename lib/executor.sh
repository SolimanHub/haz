#!/bin/bash

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
## Script / Comando generado
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
    
    # Crear un script temporal
    local temp_script
    temp_script=$(mktemp)
    echo "$cmd" > "$temp_script"
    chmod +x "$temp_script"
    
    echo -e "\033[32mScript a ejecutar:\033[0m"
    echo -e "\033[90m$cmd\033[0m"
    echo -e "\033[36m== Ejecutando ==\033[0m"
    
    # Ejecutar y capturar salida
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
    
    # Cerrar bloque de código en el archivo
    echo -e "\n\`\`\`" >> "$archivo"
    
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
