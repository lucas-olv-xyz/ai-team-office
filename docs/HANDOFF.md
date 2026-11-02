# HANDOFF — leia isto primeiro

Estado do projeto em 02/11/2026, para quem (humano ou IA) continuar o trabalho.

## O que é

Empresa fake (NullPointer Inc.) operada por agentes de IA, visualizada num escritório
3D (Godot). Pipeline comercial real com LLM local; o usuário (Lucas Oliveira) é o
Head of Sales humano que negocia com clientes-IA. Objetivo: peça de portfólio + post
no LinkedIn. **MVP funcional está pronto e publicado.**

Repo: https://github.com/lucas-olv-xyz/ai-team-office (público, branch `master`)

## Leitura obrigatória (ordem)

1. `README.md` — visão geral e como rodar
2. `docs/ARQUITETURA.md` — componentes, protocolo WebSocket, **"detalhes que custaram caro"** (pegadinhas: qwen3 `<think>`, cp1252, emoji no Godot, z-fighting, SSR)
3. `docs/MVP.md` — checklist do que está pronto e do que falta
4. `docs/OPERACAO.md` — decisões de produto
5. `docs/POST_LINKEDIN.md` — roteiro do vídeo e rascunho do post

## Ambiente desta máquina (Windows)

| Coisa | Onde |
|-------|------|
| Godot 4.7.2 (Steam) | `D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe` |
| Python venv | `backend\.venv` (deps já instaladas) |
| Ollama | AMD AI Bundle, porta 11434, modelo em uso: **qwen3:8b** |
| Backend | `ws://127.0.0.1:8765` — rodar: `backend\.venv\Scripts\python.exe backend\server.py` |
| Launcher | `start.bat` na raiz (sobe backend + Godot) |

### Comandos de validação (usar sempre antes de entregar)

```powershell
# sintaxe Python
backend\.venv\Scripts\python.exe -m py_compile backend\pipeline.py backend\server.py

# Godot: importar (necessário após criar class_name novo) e rodar headless
& "D:\...\godot.windows.opt.tools.64.exe" --headless --path office3d --import
& "D:\...\godot.windows.opt.tools.64.exe" --headless --path office3d --quit-after 600
```

⚠️ **Reinicie o backend após editar qualquer .py** (matar processo na porta 8765 e subir de novo).
⚠️ O pipeline tem **resume**: apagar `company/estado.json` + `crm.json` + `emails/` + briefings força re-execução; `company/oferta.md` pode ser mantida.

## Estado da simulação agora

- Dia 1 executado: 4 leads, 3 recusas, 1 qualificado (**CloudCare SaaS**)
- Negociação em andamento: o cliente-IA (Rafael Silva) contra-propôs
  **R$ 8.000 parcelado em 3x OU R$ 10.500 (30% off)** — aguardando resposta do Lucas
  no card do CRM (estágio `em_negociacao`)
- Nenhum contrato fechado ainda (`company/contratos.json` não existe)
- Tecla **N** no Godot gera um novo dia (3 leads inéditos)

## Pendências (em ordem de prioridade)

1. **Usuário precisa fazer:** screenshot (`docs/screenshot.png`) + vídeo 45s + postar
   (roteiro completo em `docs/POST_LINKEDIN.md`). Quando o screenshot existir,
   adicionar ao README e dar push.
2. **Bug conhecido:** contrato fechado registra sempre R$ 15.000 (`CONTRACT_VALUE`
   em `pipeline.py`), mesmo se negociado por menos. Ideal: extrair o valor acordado
   da decisão do cliente-IA (pedir campo `"valor"` no JSON de `make_negotiation_reply`).
3. Polish opcional (ver `docs/MVP.md` §4-5): notificação visual de briefing novo,
   indicador de pipeline no HUD, revisar textos do qwen ("enrollação", "IPI").
4. Pós-MVP: Fase 3 (delivery real — devs-IA geram código) e Fase 4 (export HTML5).
   **Decisão de escopo: só começar a Fase 3 se o post tiver boa recepção.**

## Convenções do projeto

- Idioma: tudo em PT-BR (código, docs, UI, commits)
- Bots não são antropomorfizados: status = tarefa literal, movimento só com significado
- Godot: tudo construído proceduralmente em GDScript (sem assets externos, sem .tscn complexos)
- Custo zero: tiers em `backend/config.yaml` apontam pro Ollama local; não trocar
  pra API paga sem o usuário pedir
- O backend é a fonte da verdade; Godot só visualiza + coleta input do humano
