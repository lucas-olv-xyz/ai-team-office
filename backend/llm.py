"""Cliente LLM unificado com camadas de modelo (tiers).

chat(tier, system, user) -> (texto, tokens_usados)
"""

import pathlib
import re

import yaml

CONFIG = yaml.safe_load(
    (pathlib.Path(__file__).parent / "config.yaml").read_text(encoding="utf-8")
)


def chat(tier: str, system: str, user: str, max_tokens: int = 300) -> tuple[str, int]:
    cfg = CONFIG["tiers"][tier]
    provider, model = cfg["provider"], cfg["model"]

    if provider == "anthropic":
        from anthropic import Anthropic

        client = Anthropic()
        resp = client.messages.create(
            model=model,
            max_tokens=max_tokens,
            system=system,
            messages=[{"role": "user", "content": user}],
        )
        used = resp.usage.input_tokens + resp.usage.output_tokens
        return resp.content[0].text.strip(), used

    # openai e ollama falam o mesmo protocolo
    from openai import OpenAI

    kwargs = {}
    if provider == "ollama":
        kwargs = {"base_url": CONFIG["ollama_url"], "api_key": "ollama"}
    client = OpenAI(**kwargs)
    resp = client.chat.completions.create(
        model=model,
        max_tokens=max_tokens,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    )
    used = resp.usage.total_tokens if resp.usage else 0
    text = resp.choices[0].message.content or ""
    # modelos de raciocínio (ex.: qwen3) emitem blocos <think> — descarta
    text = re.sub(r"<think>.*?</think>", "", text, flags=re.S)
    return text.strip(), used
