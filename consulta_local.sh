#!/bin/bash

# Uso: consulta_local.sh <modelo> <prompt>

if [ $# -ne 2 ]; then
    echo "ERROR: uso: consulta_local.sh <modelo> <prompt>" >&2
    exit 1
fi

modelo="$1"
prompt="$2"

# Escapar el prompt para JSON
escaped_prompt=$(printf "%s" "$prompt" | jq -Rs .)

# Construir payload
payload=$(jq -n --arg m "$modelo" --argjson p "$escaped_prompt" '{model:$m, prompt:$p, stream:false}')

# Consultar Ollama
response=$(curl -s --max-time 120 -X POST -H "Content-Type: application/json" -d "$payload" http://localhost:11434/api/generate)

# Extraer respuesta
comando=$(echo "$response" | jq -r '.response // empty')

if [ -z "$comando" ]; then
    echo "ERROR: No se recibió respuesta válida de Ollama" >&2
    exit 1
fi

echo "$comando"
exit 0
