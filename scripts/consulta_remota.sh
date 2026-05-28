#!/bin/bash

# Uso: consulta_remota.sh <modelo> <prompt>

if [ $# -ne 2 ]; then
    echo "ERROR: uso: consulta_remota.sh <modelo> <prompt>" >&2
    exit 1
fi

modelo="$1"
prompt="$2"

#echo "================================================="
#echo "================================================="
#echo "================================================="
#echo "================================================="
#echo "================================================="
#
#echo $prompt
#
#echo "================================================="
#echo "================================================="
#echo "================================================="
#echo "================================================="
#echo "================================================="
#exit 1


# Validar API key
if [ -z "${OPENROUTER_API_KEY:-}" ]; then
    echo "ERROR: Variable OPENROUTER_API_KEY no definida" >&2
    echo "Obtén una clave en https://openrouter.ai/workspaces/default/keys y expórtala:" >&2
    echo "  export OPENROUTER_API_KEY='tu_clave'" >&2
    exit 1
fi

url="https://openrouter.ai/api/v1/chat/completions"

# Escapar prompt para JSON
escaped_prompt=$(printf "%s" "$prompt" | jq -Rs .)

# Construir payload
payload=$(jq -n \
    --arg model "$modelo" \
    --argjson prompt "$escaped_prompt" \
    '{model: $model, messages: [{role: "user", content: $prompt}], stream: false}')

# Headers
headers=(-H "Content-Type: application/json")
headers+=(-H "Authorization: Bearer $OPENROUTER_API_KEY")
headers+=(-H "HTTP-Referer: https://github.com/haz" -H "X-Title: haz")

# Archivo temporal
response_file=$(mktemp)

# Realizar petición
http_code=$(curl -s --max-time 140 -w "%{http_code}" -X POST "$url" "${headers[@]}" -d "$payload" -o "$response_file")

if [ "$http_code" -ne 200 ]; then
    echo "ERROR: OpenRouter respondió con HTTP $http_code" >&2
    cat "$response_file" >&2
    rm -f "$response_file"
    exit 1
fi

# Extraer contenido
content=$(jq -r '.choices[0].message.content // empty' "$response_file")
rm -f "$response_file"

if [ -z "$content" ]; then
    echo "ERROR: Respuesta vacía o sin contenido de OpenRouter" >&2
    exit 1
fi

echo "$content"
exit 0
