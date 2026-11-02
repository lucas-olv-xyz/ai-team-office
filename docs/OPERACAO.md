# NullPointer Inc. — Plano de Operação

## Decisões tomadas

1. **Mercado simulado** — os clientes também são agentes de IA. Emails, respostas e
   negociações são reais (LLM ↔ LLM), mas nada sai pra internet. Zero risco legal/spam.
2. **Humano em vendas** — o usuário é o **Head of Sales** (avatar ⭐ no escritório).
   A IA prepara (leads, briefings, rascunhos); o humano negocia e fecha.
3. **Planejar caro, executar barato** — Fable (via OpenCode) é o conselho/arquiteto.
   Dentro do app, os agentes usam camadas de modelo conforme a tarefa.
4. **Tudo local por enquanto** — todos os tiers rodam no Ollama (qwen3:8b), custo zero.
5. **Sem antropomorfização** — bots não tomam café nem fofocam. O status acima de
   cada um mostra **literalmente a tarefa em execução** ("criando one-pager da oferta",
   "escrevendo cold email para X"). Movimento só quando significa algo: entregar
   trabalho na mesa de outro agente.

## O time (8 mesas)

| Nome  | Cargo           | Cérebro |
|-------|-----------------|---------|
| Vera  | CEO             | IA      |
| Otto  | CTO             | IA      |
| Davi  | Dev Backend     | IA      |
| Nina  | Dev Frontend    | IA      |
| Lia   | Designer        | IA      |
| Pedro | Product Manager | IA      |
| Rui   | SDR             | IA      |
| ⭐ Lucas | Head of Sales | **Humano (Lucas Oliveira)** |

## Pipeline da operação (Dia 1 em diante)

```
1. OFERTA      Vera define o que vendemos, pra quem (ICP) e por quanto  → one-pager
2. PROSPECÇÃO  Rui gera/garimpa leads do mercado simulado              → lista de leads
3. OUTREACH    Rui escreve cold emails personalizados                   → threads de email
4. VENDA       Lead qualificado cai na SUA caixa de entrada; você       → contrato fechado
               negocia com o cliente-IA e fecha (ou perde!)
5. DELIVERY    Otto, Davi, Nina, Lia e Pedro constroem o que foi vendido → software real
6. CAIXA       Receita (fake) entra; dashboard da empresa atualiza       → métricas
```

## Camadas de modelo (custo)

| Camada | Uso | Modelo (exemplos) | Custo estimado |
|--------|-----|-------------------|----------------|
| Ambiente | Status, papo de corredor, humor do escritório | Haiku / Flash / mini / **Ollama local** | ~centavos/hora (ou zero com Ollama) |
| Trabalho | Emails, leads, docs, respostas de clientes-IA | Modelo médio-barato | < US$1 por "dia" de operação |
| Decisão | Oferta, estratégia, retrospectivas | Modelo forte (raro, pontual) | pontual |

**Guarda-corpo:** teto de orçamento diário de tokens configurável. Estourou → o
escritório "fecha o expediente" e todo mundo vai pra casa até o dia seguinte. 😄

## Arquitetura da Fase 2

```
┌─────────────────────┐     WebSocket      ┌──────────────────────┐
│  Godot (office3d)   │ ◄────────────────► │  Backend de agentes  │
│  visualização + UI  │   eventos/ações    │  loop da operação    │
│  caixa de entrada   │                    │  chamadas LLM        │
│  do Head of Sales   │                    │  budget tracker      │
└─────────────────────┘                    └──────┬───────────────┘
                                                  │
                                      ┌───────────┴───────────┐
                                      │  company/  (artefatos) │
                                      │  oferta.md, leads.json │
                                      │  emails/, contratos/   │
                                      └───────────────────────┘
```

- O backend roda o loop da empresa e grava **artefatos reais** em `company/`.
- O Godot só visualiza e coleta input do humano (aprovar, responder, negociar).
- As falas do `team.json` viram fallback pra quando o backend está offline.

## Status

- [x] Avatar humano: Lucas Oliveira
- [x] Providers: Anthropic + OpenAI + Ollama local (ver `backend/config.yaml`) — operação 100% local por decisão
- [x] Stack do backend: Python (`backend/`)
- [x] Fase 2a: status dos bots via WebSocket (rotação literal sem custo + pipeline)
- [x] Fase 2b: pipeline do Dia 1 (oferta → leads → outreach cético → briefings) em `company/`
- [x] CRM com client journey no modal do Godot (`crm.json` + evento `crm`)
- [ ] Fase 2c: negociação do Head of Sales — ver `docs/MVP.md` (checklist completo do MVP)

## Resultado do primeiro Dia 1 (histórico)

4 leads gerados · 4 cold emails · **3 recusas, 1 qualificado** (CloudCare SaaS) ·
briefing entregue na mesa do Lucas · ~10.5k tokens · custo R$ 0,00 (qwen3:8b local).
