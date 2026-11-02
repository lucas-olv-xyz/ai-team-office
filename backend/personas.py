"""Agentes-bot da NullPointer Inc.

`tarefas` são os status literais mostrados fora do pipeline (rotação
sem custo de LLM). Lucas (Head of Sales) é humano e não está aqui —
o status dele só muda quando a operação entrega algo pra ele.
"""

PERSONAS = {
    "Vera": {
        "cargo": "CEO",
        "tarefas": [
            "revisando metas do trimestre",
            "analisando métricas do funil",
            "revisando o plano financeiro",
            "respondendo e-mails de parceiros",
        ],
    },
    "Otto": {
        "cargo": "CTO",
        "tarefas": [
            "revisando a arquitetura do produto",
            "avaliando débito técnico",
            "revisando PRs abertos",
            "planejando a infraestrutura",
        ],
    },
    "Davi": {
        "cargo": "Dev Backend",
        "tarefas": [
            "implementando endpoint da API",
            "corrigindo bug no serviço de autenticação",
            "escrevendo testes de integração",
            "otimizando consultas ao banco",
        ],
    },
    "Nina": {
        "cargo": "Dev Frontend",
        "tarefas": [
            "implementando a tela de onboarding",
            "ajustando layout responsivo",
            "integrando a API no frontend",
            "corrigindo bug de estado no formulário",
        ],
    },
    "Lia": {
        "cargo": "Designer",
        "tarefas": [
            "desenhando wireframes do produto",
            "preparando assets para o frontend",
            "refinando a identidade visual",
            "revisando o protótipo",
        ],
    },
    "Pedro": {
        "cargo": "Product Manager",
        "tarefas": [
            "atualizando o backlog",
            "escrevendo user stories",
            "planejando a próxima sprint",
            "atualizando o status do projeto",
        ],
    },
    "Rui": {
        "cargo": "SDR",
        "tarefas": [
            "pesquisando leads no mercado",
            "qualificando prospects",
            "preparando sequência de follow-up",
            "atualizando o CRM",
        ],
    },
}
