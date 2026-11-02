# Kit de divulgação — LinkedIn

## Roteiro do vídeo (45s, grava com a órbita automática ligada)

| Tempo | Cena | Como gravar |
|-------|------|-------------|
| 0–8s | Escritório geral, câmera orbitando, bots trabalhando com status sobre a cabeça | Abrir o app e não tocar em nada (zoom-in de abertura + órbita) |
| 8–18s | Pipeline rodando: apertar **N** → feed mostra "Rui saiu pra prospectar", status do Rui mudando ("escrevendo cold email para...") | Deixar o telão visível no enquadramento |
| 18–30s | Clicar no Rui → modal CRM com o client journey (cards, chips, ✕ PERDIDO / ✓ QUALIFICADO) → "ver conversa" | Rolar devagar pelos cards |
| 30–40s | Card qualificado → digitar uma resposta como Head of Sales → enviar → cliente responde | Pode acelerar 2x na edição |
| 40–45s | Telão com 💰 receita + funil, zoom out final | ESC pra fechar o modal antes |

Dicas: gravar em 1080p (OBS ou Xbox Game Bar `Win+G`), cortar sem narração — legenda no próprio post. Música lo-fi discreta.

## Rascunho do post

---

Eu montei uma empresa onde **todos os funcionários são IAs** — menos um: eu, o vendedor.

A NullPointer Inc. é uma software house fake que opera de verdade:

🤖 A CEO-IA escreveu a oferta comercial
🔍 O SDR-IA prospecta um mercado simulado e escreve cold emails
📬 Os clientes também são IAs — e recusam! (3 de 4 disseram não)
🤝 Lead qualificado cai na mesa do único humano: eu, negociando pelo CRM dentro do jogo
💰 O cliente-IA avalia minha proposta e decide fechar ou desistir

Tudo visualizado num escritório 3D feito em Godot, com cada bot mostrando literalmente a tarefa que está executando em tempo real.

O detalhe que mais me orgulha: roda **100% local** na minha GPU (Ollama + qwen3:8b). Custo de API: R$ 0,00.

Stack: Godot 4 (GDScript) + Python (asyncio/WebSocket) + Ollama.

O que aprendi construindo:
→ Orquestração de agentes é 20% prompt e 80% engenharia de estado (resume, persistência, protocolo)
→ Modelos locais pequenos funcionam bem com tarefas estreitas e bem definidas
→ Human-in-the-loop não é limitação — é onde o sistema fica interessante

Código aberto no GitHub: [link nos comentários]

#IA #Agentes #GameDev #Godot #LLM #Ollama #BuildInPublic

---

## Checklist antes de postar

- [ ] Gravar o vídeo (roteiro acima)
- [ ] Tirar 1 screenshot bonito pro README (modal CRM aberto + escritório ao fundo)
- [ ] Salvar como `docs/screenshot.png` e referenciar no README
- [ ] Push no GitHub (repo público)
- [ ] Postar: vídeo no corpo, link do repo no primeiro comentário
