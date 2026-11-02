"""Pipeline do Dia 1 — a operação de verdade, toda local.

Oferta → leads do mercado simulado → cold emails → respostas dos
clientes-IA → briefings dos leads qualificados entregues ao Lucas.
Todos os artefatos ficam em company/.
"""

import asyncio
import json
import pathlib
import re

from llm import chat

ROOT = pathlib.Path(__file__).resolve().parent.parent
COMPANY = ROOT / "company"

NO_THINK = " /no_think"
CONTRACT_VALUE = 15000  # valor da oferta (company/oferta.md)


def _ask(tier: str, system: str, user: str, max_tokens: int = 1200) -> tuple[str, int]:
    total = 0
    for _ in range(2):  # retry se o raciocínio comer o budget
        text, used = chat(tier, system + NO_THINK, user, max_tokens=max_tokens)
        total += used
        if text:
            return text, total
    return "(falha ao gerar)", total


def _json_from(text: str):
    text = re.sub(r"```(?:json)?", "", text).replace("```", "")
    match = re.search(r"[\[{].*[\]}]", text, re.S)
    if not match:
        return None
    try:
        return json.loads(match.group(0))
    except json.JSONDecodeError:
        return None


def _slug(name: str) -> str:
    return re.sub(r"\W+", "-", name.lower()).strip("-") or "lead"


def _strip_fences(text: str) -> str:
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```[a-zA-Z]*\n?", "", text)
        text = re.sub(r"\n?```$", "", text)
    return text.strip()


# ---------- geradores (síncronos, rodam em thread) ----------

def make_offer() -> tuple[str, int]:
    system = (
        "Você é Vera, CEO da NullPointer Inc., uma software house brasileira "
        "recém-fundada. Escreva em português do Brasil, direto e específico."
    )
    user = (
        "Escreva o one-pager da nossa oferta em Markdown com as seções: "
        "## O que vendemos, ## Para quem (ICP), ## Dores que resolvemos, "
        "## Preço, ## Diferenciais.\n"
        "Oferta: desenvolvimento de MVPs de software para pequenas empresas "
        "brasileiras em 4 semanas, preço fechado. Sem enrolação."
    )
    return _ask("decision", system, user, 1800)


def make_leads(offer_md: str):
    system = (
        "Você é Rui, SDR da NullPointer Inc. Responda APENAS com JSON válido, "
        "sem comentários nem markdown."
    )
    user = (
        f"Nossa oferta:\n{offer_md[:1500]}\n\n"
        "Gere 4 empresas brasileiras FICTÍCIAS que seriam bons leads. "
        "Formato: "
        '[{"empresa":"...","contato":"nome","cargo":"...","setor":"...",'
        '"dor":"problema concreto que a empresa tem","orcamento_mensal":8000}]'
    )
    text, used = _ask("work", system, user, 1600)
    return _json_from(text), used


def make_new_leads(offer_md: str, existing: list):
    system = (
        "Você é Rui, SDR da NullPointer Inc. Responda APENAS com JSON válido, "
        "sem comentários nem markdown."
    )
    user = (
        f"Nossa oferta:\n{offer_md[:1200]}\n\n"
        f"Empresas que JÁ estão no nosso CRM (NÃO repita nenhuma): {', '.join(existing)}\n\n"
        "Gere 3 empresas brasileiras FICTÍCIAS NOVAS que seriam bons leads, de "
        "setores variados. Formato: "
        '[{"empresa":"...","contato":"nome","cargo":"...","setor":"...",'
        '"dor":"problema concreto que a empresa tem","orcamento_mensal":8000}]'
    )
    text, used = _ask("work", system, user, 1400)
    return _json_from(text), used


def make_cold_email(offer_md: str, lead: dict) -> tuple[str, int]:
    system = (
        "Você é Rui, SDR da NullPointer Inc. Escreva em português do Brasil, "
        "tom profissional e direto, sem clichês de vendedor."
    )
    user = (
        f"Nossa oferta:\n{offer_md[:1200]}\n\n"
        f"Lead: {json.dumps(lead, ensure_ascii=False)}\n\n"
        "Escreva um cold email curto (máx. 120 palavras) para o contato, "
        "personalizado pela dor dele, com uma call-to-action clara "
        "(call de 20 minutos). Inclua linha de assunto no formato "
        "'Assunto: ...' na primeira linha."
    )
    return _ask("work", system, user, 700)


def make_client_reply(lead: dict, email: str):
    system = (
        f"Você é {lead.get('contato', 'o contato')}, {lead.get('cargo', 'gestor')} "
        f"da {lead.get('empresa', 'empresa')} ({lead.get('setor', '')}). "
        "Você é um cliente realista: ocupado, cético com cold emails, mas tem "
        "uma dor real. A maioria dos cold emails que você recebe não merece "
        "resposta positiva: só demonstre interesse se a proposta resolver sua "
        "dor DENTRO do seu orçamento; caso contrário recuse ou faça objeção "
        "dura. Responda APENAS com JSON válido."
    )
    user = (
        f"Sua dor: {lead.get('dor', '')}\n"
        f"Orçamento mensal disponível: R$ {lead.get('orcamento_mensal', '?')}\n\n"
        f"Você recebeu este cold email:\n{email}\n\n"
        "Responda ao email como essa pessoa responderia de verdade (pode ser "
        "recusa, pedido de mais informações ou aceite da call). Formato: "
        '{"resposta":"texto do email de resposta","interessado":true}'
    )
    text, used = _ask("work", system, user, 900)
    return _json_from(text), used


def make_briefing(offer_md: str, lead: dict, thread: str) -> tuple[str, int]:
    system = (
        "Você é Rui, SDR da NullPointer Inc. Escreva em português do Brasil, "
        "objetivo, em Markdown."
    )
    user = (
        f"Lead qualificado: {json.dumps(lead, ensure_ascii=False)}\n\n"
        f"Thread de emails:\n{thread[:2000]}\n\n"
        "Escreva um briefing de 1 página para o Head of Sales (Lucas) com: "
        "## Quem é o lead, ## A dor, ## Sinais de interesse, "
        "## Objeções prováveis, ## Próximo passo sugerido."
    )
    return _ask("work", system, user, 1200)


# ---------- CRM / contratos (estado em disco) ----------

def load_crm() -> dict:
    p = COMPANY / "crm.json"
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}


def save_crm_state(crm_state: dict) -> None:
    (COMPANY / "crm.json").write_text(
        json.dumps(crm_state, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def load_contracts() -> list:
    p = COMPANY / "contratos.json"
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else []


def add_contract(empresa: str, valor: int) -> None:
    contratos = load_contracts()
    contratos.append({"empresa": empresa, "valor": valor})
    (COMPANY / "contratos.json").write_text(
        json.dumps(contratos, ensure_ascii=False, indent=2), encoding="utf-8"
    )


# ---------- negociação (humano ↔ cliente-IA) ----------

def make_negotiation_reply(client: dict, thread: str):
    system = (
        f"Você é {client.get('contato', 'o contato')}, {client.get('cargo', 'gestor')} "
        f"da {client.get('empresa', 'empresa')} ({client.get('setor', '')}). "
        f"Sua dor: {client.get('dor', '')}. "
        f"Seu orçamento mensal: R$ {client.get('orcamento_mensal', '?')}. "
        "Você está negociando com o Head of Sales da NullPointer Inc. "
        "Seja um negociador realista: duro mas justo. Peça concessões quando fizer "
        "sentido. FECHE o negócio apenas se a proposta resolver sua dor dentro do "
        "orçamento (parcelamento e escopo reduzido contam). DESISTA se o vendedor "
        "não resolver suas objeções. Responda APENAS com JSON válido."
    )
    user = (
        f"Negociação até agora:\n{thread[-3000:]}\n\n"
        "Responda à última mensagem do Head of Sales como essa pessoa. Formato: "
        '{"resposta":"texto do seu email","decisao":"continuar"}'
        ' — decisao deve ser "continuar", "fechar" ou "desistir".'
    )
    text, used = _ask("work", system, user, 900)
    return _json_from(text), used


async def negotiate(slug: str, human_text: str, status, free, feed, crm) -> None:
    """O Lucas (humano) respondeu um cliente; o cliente-IA reage e decide."""
    crm_state = load_crm()
    client = crm_state.get(slug)
    if client is None:
        return
    nome = str(client.get("empresa", slug))
    contato = str(client.get("contato", "cliente"))

    thread = client.get("thread", "") + f"\n## Lucas (Head of Sales)\n\n{human_text}\n"
    client["thread"] = thread
    client["stage"] = "em_negociacao"
    crm_state[slug] = client
    save_crm_state(crm_state)
    (COMPANY / "emails" / f"{slug}.md").write_text(thread, encoding="utf-8")
    await crm(list(crm_state.values()))
    await feed(f"✉️ Lucas respondeu {nome} — aguardando o cliente")
    await status("Lucas", f"negociando com {nome}")

    reply, _ = await asyncio.to_thread(make_negotiation_reply, client, thread)
    reply = reply or {"resposta": "(sem resposta)", "decisao": "continuar"}
    thread += f"\n## {contato}\n\n{reply.get('resposta', '')}\n"
    client["thread"] = thread

    decisao = str(reply.get("decisao", "continuar")).lower()
    if decisao == "fechar":
        client["stage"] = "fechado"
        add_contract(nome, CONTRACT_VALUE)
        await feed(f"🎉 CONTRATO FECHADO: {nome} — R$ {CONTRACT_VALUE:_}".replace("_", "."))
        await free("Lucas", f"contrato fechado com {nome} 🏆")
    elif decisao == "desistir":
        client["stage"] = "perdido"
        await feed(f"❌ {nome} desistiu da negociação")
        await free("Lucas", "aguardando briefings do Rui")
    else:
        await feed(f"✉️ {nome} respondeu — negociação continua")
        await free("Lucas", f"negociando com {nome}")

    crm_state[slug] = client
    save_crm_state(crm_state)
    (COMPANY / "emails" / f"{slug}.md").write_text(thread, encoding="utf-8")
    await crm(list(crm_state.values()))


# ---------- orquestração ----------

async def run_day1(status, free, feed, deliver, crm) -> int:
    """Executa o Dia 1 com resume: artefatos existentes não são refeitos.

    Callbacks: status/free(agent, text), feed(text), deliver(from, to, text),
    crm(clients: list) — snapshot do funil para a UI.
    """
    tokens = 0
    COMPANY.mkdir(exist_ok=True)
    (COMPANY / "emails").mkdir(exist_ok=True)
    state_path = COMPANY / "estado.json"
    state: dict = (
        json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {}
    )
    crm_path = COMPANY / "crm.json"
    crm_state: dict = (
        json.loads(crm_path.read_text(encoding="utf-8")) if crm_path.exists() else {}
    )

    def save_state() -> None:
        state_path.write_text(
            json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    async def push_crm() -> None:
        crm_path.write_text(
            json.dumps(crm_state, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        await crm(list(crm_state.values()))

    # 1. Oferta
    offer_path = COMPANY / "oferta.md"
    if offer_path.exists() and offer_path.stat().st_size > 100:
        offer = offer_path.read_text(encoding="utf-8")
        await feed("📄 Oferta existente reutilizada — company/oferta.md")
    else:
        await status("Vera", "criando one-pager da oferta")
        offer, used = await asyncio.to_thread(make_offer)
        tokens += used
        offer = _strip_fences(offer)
        offer_path.write_text(offer, encoding="utf-8")
        await feed("📄 Vera publicou a oferta — company/oferta.md")
    await free("Vera", "acompanhando o funil de vendas")

    # 2. Leads do mercado simulado
    leads_path = COMPANY / "leads.json"
    leads = None
    if leads_path.exists():
        leads = json.loads(leads_path.read_text(encoding="utf-8"))
        await feed(f"🗂️ Lista de leads existente reutilizada ({len(leads)})")
    else:
        await status("Rui", "gerando lista de leads do mercado")
        for attempt in range(3):
            leads, used = await asyncio.to_thread(make_leads, offer)
            tokens += used
            if leads:
                break
            await status("Rui", f"refazendo a lista de leads (tentativa {attempt + 2})")
        if not leads:
            await feed("⚠️ Falha ao gerar leads após 3 tentativas — pipeline interrompido")
            await free("Rui", "pesquisando leads no mercado")
            return tokens
        leads_path.write_text(
            json.dumps(leads, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        await feed(f"🗂️ Rui levantou {len(leads)} leads — company/leads.json")

    # registra todos no CRM (com backfill a partir de execuções anteriores)
    for lead in leads:
        slug = _slug(str(lead.get("empresa", "lead")))
        if slug in crm_state:
            continue
        entry = {**lead, "slug": slug, "stage": "prospectado", "thread": ""}
        thread_file = COMPANY / "emails" / f"{slug}.md"
        if thread_file.exists():
            entry["thread"] = thread_file.read_text(encoding="utf-8")
        if slug in state:
            entry["stage"] = "interessado" if state[slug].get("interessado") else "recusado"
        if (COMPANY / f"briefing-{slug}.md").exists():
            entry["stage"] = "briefing_entregue"
        crm_state[slug] = entry
    await push_crm()

    # 3 + 4. Outreach, respostas e briefings
    used, qualified_count = await _sales_cycle(
        offer, leads, state, crm_state, save_state, push_crm,
        status, free, feed, deliver,
    )
    tokens += used
    await feed(f"✅ Dia 1 concluído: {qualified_count} lead(s) qualificado(s) para o Lucas")
    return tokens


async def _sales_cycle(
    offer, leads, state, crm_state, save_state, push_crm,
    status, free, feed, deliver,
) -> tuple[int, int]:
    """Outreach + respostas dos clientes-IA + briefings para um lote de leads."""
    tokens = 0
    qualified = []
    for lead in leads:
        nome = str(lead.get("empresa", "lead"))
        slug = _slug(nome)
        thread_path = COMPANY / "emails" / f"{slug}.md"

        if slug in state:
            if state[slug].get("interessado") and thread_path.exists():
                qualified.append((lead, thread_path.read_text(encoding="utf-8")))
            continue

        await status("Rui", f"escrevendo cold email para {nome}")
        email, used = await asyncio.to_thread(make_cold_email, offer, lead)
        tokens += used
        email = _strip_fences(email)
        crm_state[slug]["stage"] = "contactado"
        await push_crm()

        await status("Rui", f"aguardando resposta de {nome}")
        reply, used = await asyncio.to_thread(make_client_reply, lead, email)
        tokens += used
        reply = reply or {"resposta": "(sem resposta)", "interessado": False}

        thread = (
            f"# Thread — {nome}\n\n## Cold email (Rui)\n\n{email}\n\n"
            f"## Resposta ({lead.get('contato', 'cliente')})\n\n{reply.get('resposta', '')}\n"
        )
        thread_path.write_text(thread, encoding="utf-8")
        state[slug] = {"interessado": bool(reply.get("interessado"))}
        save_state()
        crm_state[slug]["stage"] = (
            "interessado" if reply.get("interessado") else "recusado"
        )
        crm_state[slug]["thread"] = thread
        await push_crm()

        if reply.get("interessado"):
            qualified.append((lead, thread))
            await feed(f"✉️ {nome} respondeu com interesse!")
        else:
            await feed(f"✉️ {nome} não demonstrou interesse")

    for lead, thread in qualified:
        nome = str(lead.get("empresa", "lead"))
        path = COMPANY / f"briefing-{_slug(nome)}.md"
        if not path.exists():
            await status("Rui", f"preparando briefing de {nome}")
            briefing, used = await asyncio.to_thread(make_briefing, offer, lead, thread)
            tokens += used
            path.write_text(_strip_fences(briefing), encoding="utf-8")
        await deliver("Rui", "Lucas", f"entregando briefing de {nome}")
        await status("Lucas", f"revisando briefing de {nome}")
        await feed(f"🤝 Briefing de {nome} na mesa do Lucas — {path.name}")
        crm_state[_slug(nome)]["stage"] = "briefing_entregue"
        await push_crm()

    await free("Rui", "monitorando novas oportunidades")
    return tokens, len(qualified)


async def run_new_day(status, free, feed, deliver, crm, day: int) -> int:
    """Um novo dia de prospecção: Rui traz leads inéditos e roda o ciclo."""
    tokens = 0
    offer_path = COMPANY / "oferta.md"
    if not offer_path.exists():
        await feed("⚠️ Sem oferta — rode o Dia 1 primeiro")
        return 0
    offer = offer_path.read_text(encoding="utf-8")

    state_path = COMPANY / "estado.json"
    state: dict = (
        json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {}
    )
    crm_state = load_crm()

    def save_state() -> None:
        state_path.write_text(
            json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    async def push_crm() -> None:
        save_crm_state(crm_state)
        await crm(list(crm_state.values()))

    await feed(f"🌅 Dia {day} — Rui saiu pra prospectar")
    await status("Rui", "prospectando novos leads")
    existing = [str(c.get("empresa", "")) for c in crm_state.values()]
    new_leads = None
    for _ in range(3):
        new_leads, used = await asyncio.to_thread(make_new_leads, offer, existing)
        tokens += used
        if new_leads:
            break
    if not new_leads:
        await feed("⚠️ Rui voltou de mãos vazias — tenta de novo (N)")
        await free("Rui", "pesquisando leads no mercado")
        return tokens

    leads_path = COMPANY / "leads.json"
    all_leads: list = (
        json.loads(leads_path.read_text(encoding="utf-8")) if leads_path.exists() else []
    )
    all_leads.extend(new_leads)
    leads_path.write_text(
        json.dumps(all_leads, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    for lead in new_leads:
        slug = _slug(str(lead.get("empresa", "lead")))
        if slug not in crm_state:
            crm_state[slug] = {**lead, "slug": slug, "stage": "prospectado", "thread": ""}
    await push_crm()
    await feed(f"🗂️ Rui trouxe {len(new_leads)} leads novos")

    used, qualified_count = await _sales_cycle(
        offer, new_leads, state, crm_state, save_state, push_crm,
        status, free, feed, deliver,
    )
    tokens += used
    await feed(f"✅ Dia {day} concluído: {qualified_count} lead(s) qualificado(s)")
    return tokens
