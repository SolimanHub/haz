El siguiente readme fue generado por el mismo comando :)
╔══════════════════════════════════════════════════════════════════════╗
║                         ██╗░░██╗ █████╗ ███████╗                ║
║                        ██║░░██║██╔══██╗╚════██╗                ║
║                        ███████║███████║░░███╔═╝                ║
║                        ██╔══██║██╔══██║██╔══╝                 ║
║                        ██║░░██║██║░░██║███████╗                ║
║                        ╚═╝░░╚═╝╚═╝░░╚═╝╚══════╝                ║
╚══════════════════════════════════════════════════════════════════════╝

                    AI-Powered Command Line Assistant
                         para Linux/Unix Systems

┌──────────────────────────────────────────────────────────────────┐
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                 │
│  │   💡      │  │   🔒      │  │   📋      │                 │
│  │ Inteligente│  │ Seguro     │  │ Registro   │                 │
│  └────────────┘  └────────────┘  └────────────┘                 │
└──────────────────────────────────────────────────────────────────┘

────────────────────────────────────────────────────────────────────
                              🚀 QUICK START
────────────────────────────────────────────────────────────────────

  $ ./haz.sh "muestra procesos usando más CPU"

  $ ./haz.sh -m 3 "busca archivos grandes en home"

  $ ./haz.sh -t -f config.json "analiza esta configuración"

────────────────────────────────────────────────────────────────────
                          🛠️ ARQUITECTURA
────────────────────────────────────────────────────────────────────

```
```bash
# Modelos remotos (requiere API key)
export OPENROUTER_API_KEY='tu_clave_aqui'

# Modelos locales
ollama pull llama3  # Ejemplo
```
```bash
# Consulta simple
haz "crea backup de /etc en formato tar.gz"

# Con modelo específico
haz -m 5 "explica qué hace este script"

# Con archivos
haz -f ./script.sh "optimiza este código"

# Análisis profundo
haz -t --depth 3 "refactoriza toda la estructura"
