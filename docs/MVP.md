# MVP — definição e o que falta

## O que é o MVP

> **Um ciclo comercial completo, assistível e jogável:** a IA prospecta e qualifica,
> o humano negocia e fecha, a empresa registra o resultado — tudo visível no
> escritório 3D, rodando 100% local, pronto pra gravar um vídeo de 45s que faça
> alguém no LinkedIn dizer "uau".

O MVP **não** inclui delivery real de software (Fase 3) nem export web (Fase 4).
Fecha no contrato assinado + placar de receita.

## ✅ Pronto

| # | Item |
|---|------|
| 1 | Escritório 3D (noite, cidade, glow) sem flickers |
| 2 | 8 agentes com status literal em tempo real + painel EQUIPE |
| 3 | Modal estilo software: dossiê do agente + CRM com client journey |
| 4 | Pipeline Dia 1: oferta → leads → cold emails → respostas céticas → briefings |
| 5 | Threads de email reais visíveis no modal ("ver conversa") |
| 6 | Resume do pipeline + CRM persistido (`estado.json`, `crm.json`) |
| 7 | 100% local (qwen3:8b via Ollama) com fallback offline no Godot |

## 🔲 Falta para o MVP

### 1. Negociação humana (Fase 2c) — o coração do MVP ✅
- [x] Caixa de resposta no card de cliente qualificado/em negociação (modal)
- [x] Godot → backend: `{"type": "reply", "slug": ..., "text": ...}`
- [x] Backend: cliente-IA responde à negociação (thread inteira + dor + orçamento)
- [x] Decisão do cliente-IA: `continuar`, `fechar` ou `desistir`
- [x] Novos estágios no journey: `EM NEGOCIAÇÃO → 🏆 FECHADO / ✕ PERDIDO`
- [x] Thread atualiza no card em tempo real (evento `crm`)

### 2. Placar da empresa ✅
- [x] Contrato fechado soma receita — `company/contratos.json`
- [x] Telão mostra: 💰 receita · funil (prospectados → qualificados → fechados)
- [x] Celebração no feed ("🎉 CONTRATO FECHADO: ... — R$ 15.000")

### 3. Dias seguintes (loop mínimo) ✅
- [x] Tecla **N** = novo dia: Rui gera 3 leads inéditos (sem repetir empresas do CRM) e o ciclo recomeça
- [ ] Follow-up: leads `recusado` podem receber 1 follow-up no dia seguinte (opcional, pós-MVP)

### 4. Experiência de rodar
- [x] `start.bat` — sobe backend + Godot com dois cliques
- [ ] Notificação visual no escritório quando um briefing chega pro Lucas (hoje só muda o status)
- [ ] Indicador de conexão/pipeline no HUD (rodando / concluído / offline)

### 5. Qualidade (antes de gravar o vídeo)
- [ ] Revisar textos da oferta/emails (qwen às vezes escorrega: "IPI", "enrollação")
- [ ] Testar sessão longa (30+ min) sem travar
- [ ] Passada final de câmera/enquadramento pro vídeo

## Ordem sugerida

**1 → 2** (negociação + placar = MVP jogável) **→ 4** (launcher) **→ 3** (loop de dias) **→ 5** (polish).

Estimativa: a Fase 2c é ~1 sessão de trabalho; placar e launcher são rápidos.

## Depois do MVP (visão)

- **Fase 3**: contrato fechado vira projeto → devs-IA geram código real num repo → telão mostra progresso do delivery
- **Fase 4**: export HTML5 (itch.io) com backend demo/replay + vídeo LinkedIn
- Métricas de longo prazo: churn, caixa mensal, contratação de novos bots 😄
