# haz

Asistente de IA CLI para generar comandos y scripts de Linux/Unix.

## ¿Qué es haz?

haz es un asistente de línea de comandos que utiliza modelos de IA (localmente con Ollama o remotamente con OpenRouter) para generar comandos, scripts o secuencias de comandos bash según la consulta del usuario.

## Características

- Soporta modelos locales (a través de Ollama) y remotos (a través de OpenRouter).
- Permite especificar el modelo y la profundidad de recursión para subtareas.
- Incluye un sistema de registro para rastrear las consultas y los comandos generados.
- Diseñado con seguridad en mente: evita comandos peligrosos y permite la ejecución controlada.

## Instalación y configuración

1. Asegúrate de tener instalados `curl` y `jq`.
2. Para usar modelos locales, instala Ollama y descarga un modelo (por ejemplo, `ollama pull llama3`).
3. Para usar modelos remotos, obtén una API key de OpenRouter y exportarla:
   ```bash
   export OPENROUTER_API_KEY='tu_api_key_aqui'
   ```
4. El script `haz` es ejecutable y está en el directorio raíz del proyecto.

## Uso básico

Ejecuta `haz` seguido de tu consulta en lenguaje natural:

```bash
haz "muestra la fecha y lista los archivos"
```
```bash
haz -m 1 --depth 0 "consulta aquí"
```
