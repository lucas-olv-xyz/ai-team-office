# AI Team — a empresa fake operada por IAs 🏢🤖

Um time de agentes de IA opera uma software house fictícia (**NullPointer Inc.**) dentro de
um escritório 3D feito em Godot. A operação é real: a CEO-IA escreve a oferta, o SDR-IA
prospecta um mercado simulado, clientes-IA respondem (e recusam!), e os leads qualificados
caem na mesa do único humano do time — **Lucas, Head of Sales** — que negocia e fecha.

Tudo roda **100% local** (Ollama na GPU), custo zero de API.

## Estrutura

```
AI-team/
├── office3d/            # Visualizador 3D (Godot 4.7, GDScript)
│   ├── scenes/main.tscn
│   ├── scripts/
│   │   ├── main.gd          # cenário, HUD, modal CRM, telão, orquestração
│   │   ├── agent.gd         # funcionário-bot: status, movimento, clique
│   │   ├── orbit_camera.gd  # câmera cinematográfica (zoom-in + órbita)
│   │   └── ws_client.gd     # conexão com o backend (reconexão automática)
│   └── data/team.json       # elenco + tarefas de fallback offline
├── backend/             # A operação (Python)
│   ├── server.py            # WebSocket + rotação de status + orquestra o pipeline
│   ├── pipeline.py          # Dia 1: oferta → leads → outreach → CRM → briefings
│   ├── llm.py               # cliente unificado (ollama/openai/anthropic) por tier
│   ├── personas.py          # personas e tarefas literais dos bots
│   └── config.yaml          # modelos por tier, portas, orçamento de tokens
├── company/             # Artefatos REAIS produzidos pela operação
│   ├── oferta.md            # one-pager escrito pela Vera (CEO)
│   ├── leads.json           # mercado simulado gerado pelo Rui (SDR)
│   ├── crm.json             # funil: estágio de cada cliente (client journey)
│   ├── estado.json          # resume do pipeline (o que já foi feito)
│   ├── emails/<lead>.md     # threads reais: cold email ↔ resposta do cliente-IA
│   └── briefing-<lead>.md   # briefings entregues ao Head of Sales
└── docs/
    ├── OPERACAO.md          # plano de operação e decisões
    ├── ARQUITETURA.md       # componentes, protocolo WS, tiers de modelo
    └── MVP.md               # definição do MVP e o que falta
```

## Como rodar

```powershell
# 1. Backend (terminal 1) — precisa do Ollama rodando com qwen3:8b
cd backend
.venv\Scripts\python.exe server.py

# 2. Escritório — abra office3d/ no Godot 4.x e pressione F5
```

Sem backend o escritório funciona em modo fallback (tarefas locais, sem pipeline).

**Controles:** arrastar gira · scroll zoom · **R** órbita automática · **clique num agente** abre o modal de operações (dossiê + CRM) · **ESC** fecha.

## Status (Fases)

- [x] **Fase 1 — Escritório 3D**: cenário noturno com cidade, bots com status literal, telão de operações, painel EQUIPE em tempo real
- [x] **Fase 2a — Operação conectada**: backend via WebSocket; status reais; rotação sem custo de LLM
- [x] **Fase 2b — Pipeline do Dia 1**: oferta → leads → cold emails → respostas de clientes-IA céticos → briefings entregues; CRM com client journey; resume automático
- [ ] **Fase 2c — Humano no loop**: caixa de negociação do Head of Sales (ver `docs/MVP.md`)
- [ ] **Fase 3 — Delivery real**: contrato fechado vira projeto; devs-IA produzem código real
- [ ] **Fase 4 — Compartilhar**: export HTML5 + vídeo pro LinkedIn

## Time

| Nome  | Cargo           | Cérebro |
|-------|-----------------|---------|
| Vera  | CEO             | IA (qwen3:8b local) |
| Otto  | CTO             | IA |
| Davi  | Dev Backend     | IA |
| Nina  | Dev Frontend    | IA |
| Lia   | Designer        | IA |
| Pedro | Product Manager | IA |
| Rui   | SDR             | IA |
| ⭐ Lucas | Head of Sales | **Humano (Lucas Oliveira)** |
