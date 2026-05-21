#!/bin/bash
# Lee ficheros mencionados en la consulta y devuelve una cadena con su contenido

leer_ficheros_de_consulta() {
    local query="$1"
    local dir_actual="$2"
    local contenidos=""
    local max_size_kb=100

    # Extraer palabras que parezcan rutas (muy simple, se puede mejorar)
    local palabras=($(echo "$query" | grep -oE '[a-zA-Z0-9_./-]+'))

    for word in "${palabras[@]}"; do
        # Solo procesar si contiene un punto o una barra (para evitar falsos positivos)
        [[ "$word" != *"."* && "$word" != *"/"* ]] && continue

        local ruta="$word"
        # Si es relativa, completar con el directorio actual
        [[ "$ruta" != /* ]] && ruta="$dir_actual/$ruta"

        if [ -f "$ruta" ]; then
            local mimetype=$(file -b --mime-type "$ruta" 2>/dev/null)
            # Ignorar binarios
            case "$mimetype" in
                text/*|application/json|application/xml|application/xhtml+xml|application/javascript|application/x-shellscript) ;;
                *) continue ;;
            esac

            local size_kb=$(du -k "$ruta" | cut -f1)
            if [ "$size_kb" -gt "$max_size_kb" ]; then
                echo -e "\033[33mAdvertencia: $ruta excede $max_size_kb KB, omitiendo\033[0m" >&2
                continue
            fi

            local content=$(cat "$ruta")
            contenidos+="## Contenido de $word

\`\`\`
$content
\`\`\`

"
        else
            echo -e "\033[31mFichero no encontrado: $ruta\033[0m" >&2
        fi
    done

    echo "$contenidos"
}
