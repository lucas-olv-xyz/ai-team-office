"""Backend da NullPointer Inc. — a operação da empresa.

Servidor WebSocket; o Godot conecta e espelha a operação:
- status: tarefa literal em execução de cada bot
- feed: eventos da operação (artefatos, leads, entregas)
- deliver: um bot leva trabalho até a mesa de outro

O pipeline do Dia 1 começa quando o primeiro Godot conecta.
Fora do pipeline, os bots rotacionam tarefas literais sem custo de LLM.

Uso:
    python server.py
"""

import asyncio
import json
import pathlib
import random
import sys

import websockets

from llm import CONFIG
from personas import PERSONAS
from pipeline import load_contracts, negotiate, run_day1, run_new_day

# console do Windows usa cp1252 (emojis derrubariam os prints) e o stdout
# é bufferizado quando redirecionado — utf-8 + flush por linha resolve os dois
sys.stdout.reconfigure(encoding="utf-8", errors="replace", line_buffering=True)

clients: set = set()
busy: set[str] = set()  # agentes controlados pelo pipeline agora
pipeline_started = False
cycle_running = False
day_counter = 1
latest_crm: list = []


async def broadcast(obj: dict) -> None:
    dead = []
    for ws in clients:
        try:
            await ws.send(json.dumps(obj, ensure_ascii=False))
        except websockets.ConnectionClosed:
            dead.append(ws)
    for ws in dead:
        clients.discard(ws)


async def status(agent: str, text: str, lock: bool = True) -> None:
    if lock:
        busy.add(agent)
    print(f"[status] {agent}: {text}")
    await broadcast({"type": "status", "agent": agent, "text": text})


async def free(agent: str, text: str) -> None:
    await status(agent, text, lock=False)
    busy.discard(agent)


async def feed(text: str) -> None:
    print(f"[feed] {text}")
    await broadcast({"type": "feed", "text": text})


async def deliver(frm: str, to: str, text: str) -> None:
    print(f"[deliver] {frm} -> {to}: {text}")
    await broadcast({"type": "deliver", "from": frm, "to": to, "text": text})
    await asyncio.sleep(7)  # tempo da caminhada no escritório


def compute_stats() -> dict:
    receita = sum(c.get("valor", 0) for c in load_contracts())
    qualificados = sum(
        1
        for c in latest_crm
        if c.get("stage") in ("interessado", "briefing_entregue", "em_negociacao", "fechado")
    )
    fechados = sum(1 for c in latest_crm if c.get("stage") == "fechado")
    return {
        "type": "stats",
        "receita": receita,
        "prospectados": len(latest_crm),
        "qualificados": qualificados,
        "fechados": fechados,
    }


async def crm(clients_list: list) -> None:
    global latest_crm
    latest_crm = clients_list
    await broadcast({"type": "crm", "clients": clients_list})
    await broadcast(compute_stats())


async def send_initial_statuses() -> None:
    for name, p in PERSONAS.items():
        if name not in busy:
            await status(name, random.choice(p["tarefas"]), lock=False)
    await status("Lucas", "aguardando briefings do Rui", lock=False)


async def run_pipeline_once() -> None:
    global pipeline_started, cycle_running
    if pipeline_started:
        return
    pipeline_started = True
    cycle_running = True
    await feed("🏁 Pipeline do Dia 1 iniciado")
    try:
        tokens = await run_day1(status, free, feed, deliver, crm)
        print(f"[pipeline] concluído — {tokens} tokens (local, custo zero)")
    except Exception as exc:
        print(f"[pipeline] erro: {exc}")
        await feed(f"⚠️ Pipeline falhou: {exc}")
    finally:
        cycle_running = False


async def start_new_day() -> None:
    global cycle_running, day_counter
    if cycle_running:
        await feed("⏳ A operação ainda está no meio de um ciclo — aguarde")
        return
    cycle_running = True
    day_counter += 1
    try:
        tokens = await run_new_day(status, free, feed, deliver, crm, day_counter)
        print(f"[dia {day_counter}] concluído — {tokens} tokens")
    except Exception as exc:
        print(f"[dia {day_counter}] erro: {exc}")
        await feed(f"⚠️ Dia {day_counter} falhou: {exc}")
    finally:
        cycle_running = False


async def handler(ws) -> None:
    clients.add(ws)
    print(f"[ws] Godot conectado ({len(clients)} cliente(s))")
    try:
        async for message in ws:
            try:
                data = json.loads(message)
            except json.JSONDecodeError:
                continue
            msg_type = data.get("type")
            if msg_type == "hello":
                print(f"[ws] hello: {data.get('agents', [])}")
                await send_initial_statuses()
                if latest_crm:
                    await ws.send(
                        json.dumps(
                            {"type": "crm", "clients": latest_crm}, ensure_ascii=False
                        )
                    )
                    await ws.send(json.dumps(compute_stats(), ensure_ascii=False))
                asyncio.create_task(run_pipeline_once())
            elif msg_type == "reply":
                slug = str(data.get("slug", ""))
                text = str(data.get("text", "")).strip()
                if slug and text:
                    print(f"[reply] Lucas -> {slug}: {text[:80]}")
                    asyncio.create_task(negotiate(slug, text, status, free, feed, crm))
            elif msg_type == "new_day":
                asyncio.create_task(start_new_day())
    except websockets.ConnectionClosed:
        pass  # Godot fechou a janela — desconexão normal
    finally:
        clients.discard(ws)
        print(f"[ws] Godot desconectou ({len(clients)} cliente(s))")


async def rotation_loop() -> None:
    """Rotaciona os status literais fora do pipeline — sem custo de LLM."""
    interval = CONFIG.get("status_rotation_interval", 15)
    while True:
        await asyncio.sleep(interval)
        if not clients:
            continue
        candidates = [n for n in PERSONAS if n not in busy]
        if not candidates:
            continue
        name = random.choice(candidates)
        await status(name, random.choice(PERSONAS[name]["tarefas"]), lock=False)


async def main() -> None:
    global latest_crm
    crm_path = pathlib.Path(__file__).resolve().parent.parent / "company" / "crm.json"
    if crm_path.exists():
        latest_crm = list(json.loads(crm_path.read_text(encoding="utf-8")).values())
        print(f"[crm] {len(latest_crm)} cliente(s) carregados do disco")
    host = CONFIG["server"]["host"]
    port = CONFIG["server"]["port"]
    async with websockets.serve(handler, host, port):
        print(f"NullPointer Inc. backend em ws://{host}:{port}")
        print(f"Tiers: {CONFIG['tiers']}")
        await rotation_loop()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nExpediente encerrado.")
