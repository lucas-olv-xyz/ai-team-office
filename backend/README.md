# Backend — os cérebros da NullPointer Inc.

Servidor WebSocket que gera as falas dos agentes com LLMs reais.
O Godot conecta automaticamente; sem backend rodando, o escritório
cai no modo simulado (falas do `team.json`).

## Setup (uma vez)

```powershell
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

Keys (só dos providers que for usar):

```powershell
$env:ANTHROPIC_API_KEY = "sk-ant-..."
$env:OPENAI_API_KEY = "sk-..."
```

Ollama (opção custo zero pro papo ambiente):

```powershell
ollama pull llama3.2
```

## Rodar

```powershell
python server.py   # terminal 1
# e abra o office3d no Godot (F5) — o feed mostra "🧠 Cérebros conectados!"
```

Modelos, intervalo das falas e teto de tokens: `config.yaml`.
