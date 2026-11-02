# Arquitetura

```
┌──────────────────────────┐    WebSocket (ws://127.0.0.1:8765)    ┌───────────────────────────┐
│   Godot (office3d)       │ ◄───────────────────────────────────► │   Backend (Python)        │
│   · cenário 3D           │   status / feed / deliver / crm       │   · server.py (asyncio)   │
│   · painel EQUIPE        │                                       │   · pipeline.py (Dia 1)   │
│   · modal dossiê + CRM   │                                       │   · rotação de status     │
│   · telão de operações   │                                       │   · chamadas LLM (tiers)  │
└──────────────────────────┘                                       └────────────┬──────────────┘
                                                                                │ escreve
                                                                   ┌────────────┴──────────────┐
                                                                   │  company/  (artefatos)    │
                                                                   │  oferta, leads, crm,      │
                                                                   │  emails/, briefings       │
                                                                   └───────────────────────────┘
```

## Princípios

1. **Sem antropomorfização** — bots não tomam café nem fofocam. Status = tarefa literal.
   Movimento só com significado (entregar briefing na mesa de alguém).
2. **O backend é a verdade** — o Godot apenas visualiza e coleta input humano.
   Artefatos em `company/` são a memória persistente; o pipeline tem *resume*
   (nada pronto é refeito; `estado.json` + `crm.json` guardam o progresso).
3. **Planejar caro, executar barato** — tiers de modelo em `config.yaml`:

| Tier | Uso | Modelo atual |
|------|-----|--------------|
| `work` | emails, leads, respostas de clientes-IA, briefings | ollama · qwen3:8b |
| `decision` | oferta, estratégia | ollama · qwen3:8b |
| (rotação de status) | tarefas visuais dos bots | **sem LLM** (listas em personas.py) |

Trocar para nuvem = editar `config.yaml` (anthropic/openai) + exportar a API key.

## Protocolo WebSocket (backend → Godot)

| type | Payload | Efeito no Godot |
|------|---------|-----------------|
| `status` | `agent`, `text` | Atualiza o balão do bot, painel EQUIPE e histórico |
| `feed` | `text` | Linha no feed (HUD) e no telão de operações |
| `deliver` | `from`, `to`, `text` | Agente caminha até a mesa do outro e entrega (🤝) |
| `crm` | `clients: [{empresa, contato, cargo, setor, dor, orcamento_mensal, stage, thread, slug}]` | Atualiza os cards do CLIENT JOURNEY no modal |

Godot → backend: `{"type": "hello", "agents": [...]}` ao conectar.

### Estágios do client journey (`stage`)

`prospectado → contactado → interessado | recusado → briefing_entregue`

(Fase 2c adiciona: `em_negociacao → fechado | perdido`.)

## Detalhes que custaram caro (não repetir)

- **qwen3 pensa** — blocos `<think>` comem o budget de tokens. Mitigação: `/no_think`
  no system prompt + strip por regex em `llm.py` + retry quando vier vazio.
- **Windows console é cp1252** — `sys.stdout.reconfigure(utf-8, line_buffering)` no
  server, senão emojis derrubam prints e logs somem no buffer.
- **Emoji em UI do Godot** — a fonte padrão não tem glifos; usar `SystemFont` com
  `fallbacks = [Segoe UI Emoji]` em Labels, RichTextLabels e Label3D.
- **Z-fighting** — Label3D colado numa parede cintila; desloque alguns cm.
- **SSR flicker** — reflexo screen-space tremia na órbita; removido.
- **class_name novo** — rodar `godot --headless --import` antes de validar, senão
  o parser não encontra a classe.
