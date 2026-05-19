#!/bin/bash
# Funciones esenciales: nombres, seguridad, prompt, etc.

generar_nombre_archivo_md() {
    date +"log_haz_command_%Y-%m-%d_%H-%M-%S.md"
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
}

mostrar_uso() {
    echo -e "\033[31mUso: haz <consulta>\033[0m"
}

generar_prompt() {
    local my_system="$1"
    local query="$2"
    cat <<EOF
Eres un asistente técnico en $my_system. Genera **exactamente un comando de terminal válido**.

REGLAS:
1. SOLO el comando, sin explicaciones.
2. Prohibido: \$(...), backticks, \$HOME, \$USER, comillas con \$, texto explicativo.
3. Para info del sistema usa el comando directo (date, ls, pwd).
4. Para archivos: echo 'contenido' > archivo (comillas simples).
5. Rutas relativas. Usa sudo solo si es necesario.
6. Si es ambigua/peligrosa: ERROR: solicitud no segura

Contexto: $my_system

Ejemplos:
- 'dime la fecha' → date
- 'crea saludo.txt con Hola' → echo 'Hola' > saludo.txt

Responde **solo con el comando exacto** para: haz $query
EOF
}

limpiar_comando() {
    local cmd="$1"
    printf '%s' "$cmd" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

validar_comando() {
    local comando="$1"
    # Bloquear subcomandos
    if [[ "$comando" == *'$('* ]] || [[ "$comando" == *'`'* ]]; then
        echo -e "\033[31m✖ Subcomandos rechazados\033[0m"
        return 1
    fi
    # Seguridad
    if ! es_comando_seguro "$comando"; then
        echo -e "\033[31m✖ Bloqueado por seguridad\033[0m"
        return 1
    fi
    # Manejar error explícito del modelo
    if [[ "$comando" == ERROR:* ]]; then
        echo -e "\033[31m✖ $comando\033[0m"
        return 1
    fi
    return 0
}
