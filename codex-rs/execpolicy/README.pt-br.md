# codex-execpolicy

## Visão geral

- Mecanismo de políticas e interface de linha de comando (CLI) desenvolvidos com base em `prefix_rule(pattern=[...], decision?, justification?, match?, not_match?)` e `host_executable(name=..., paths=[...])`.
- Esta versão abrange o subconjunto de regras de prefixo da linguagem execpolicy, além dos metadados dos executáveis do host; uma linguagem mais abrangente será lançada posteriormente.
- Os tokens são comparados em ordem; qualquer elemento `pattern` pode ser uma lista para indicar alternativas. O valor padrão de `decision` é `allow`; valores válidos: `allow`, `prompt`, `forbidden`.
- `justification` é uma justificativa opcional, redigida em linguagem simples, que explica por que uma regra existe. Ela pode ser fornecida para qualquer `decision` e pode ser exibida em diferentes contextos (por exemplo, em solicitações de aprovação ou mensagens de rejeição). Quando `decision = "forbidden"` for utilizado, inclua uma alternativa recomendada em `justification`, quando apropriado (por exemplo, ``"Use `jj` instead of `git`."``).
- `match` / `not_match` fornecem exemplos de chamadas que são validados no momento do carregamento (pense neles como testes unitários); os exemplos podem ser matrizes de tokens ou strings (as strings são tokenizadas com `shlex`).
- A CLI sempre exibe a serialização em JSON do resultado da avaliação.

## Formas de políticas

- As regras de prefixo utilizam a sintaxe do Starlark:

```starlark
prefix_rule(
    pattern = ["cmd", ["alt1", "alt2"]], # ordered tokens; list entries denote alternatives
    decision = "prompt",                 # allow | prompt | forbidden; defaults to allow
    justification = "explain why this rule exists",
    match = [["cmd", "alt1"], "cmd alt2"],           # examples that must match this rule
    not_match = [["cmd", "oops"], "cmd alt3"],       # examples that must not match this rule
)
```

- Os metadados do executável do host podem, opcionalmente, restringir quais caminhos absolutos podem
  resolução por meio das regras de nome base:

```starlark
host_executable(
    name = "git",
    paths = [
        "/opt/homebrew/bin/git",
        "/usr/bin/git",
    ],
)
```

- Semântica de correspondência:
  - O execpolicy sempre tenta, em primeiro lugar, correspondências exatas do primeiro token.
  - Com a resolução de executáveis do host desativada, `/usr/bin/git status` corresponde apenas a uma regra cujo primeiro token seja `/usr/bin/git`.
  - Com a resolução de executáveis do host ativada, se nenhuma regra exata corresponder, o execpolicy poderá recorrer das regras `/usr/bin/git` às regras de nome-base para `git`.
  - Se `host_executable(name="git", ...)` existir, o recurso de substituição do nome base só será permitido para caminhos absolutos listados.
  - Se não houver nenhuma entrada `host_executable()` para um nome base, é permitido o uso de um nome base alternativo.

## Interface de linha de comando

- Na CLI do Codex, execute o subcomando `codex execpolicy check` com um ou mais arquivos de política (por exemplo, `src/default.rules`) para verificar um comando:

```bash
codex execpolicy check --rules path/to/policy.rules git status
```

- Para ativar o recurso de fallback do nome base para caminhos absolutos de programas, passe `--resolve-host-executables`:

```bash
codex execpolicy check \
  --rules path/to/policy.rules \
  --resolve-host-executables \
  /usr/bin/git status
```

- Passe vários parâmetros `--rules` para mesclar regras, avaliadas na ordem fornecida, e use `--pretty` para JSON formatado.
- Você também pode executar diretamente o binário de desenvolvimento independente durante o desenvolvimento:

```bash
cargo run -p codex-execpolicy -- check --rules path/to/policy.rules git status
```

- Exemplos de resultados:
  - Resultado: 0 a 0
  - Resultado: 0 a 1

## Forma da resposta

```json
{
  "matchedRules": [
    {
      "prefixRuleMatch": {
        "matchedPrefix": ["<token>", "..."],
        "decision": "allow|prompt|forbidden",
        "resolvedProgram": "/absolute/path/to/program",
        "justification": "..."
      }
    }
  ],
  "decision": "allow|prompt|forbidden"
}
```

- Quando nenhuma regra corresponde, `matchedRules` é uma matriz vazia e `decision` é omitido.
- `matchedRules` lista todas as regras cujo prefixo correspondeu ao comando; `matchedPrefix` é o prefixo exato que correspondeu.
- `resolvedProgram` é omitido, a menos que um caminho absoluto do executável tenha sido identificado por meio do recurso de fallback do basename.
- O valor efetivo `decision` representa o nível de gravidade mais rigoroso entre todas as correspondências (`forbidden` > `prompt` > `allow`).

Observação: os comandos `execpolicy` ainda estão em fase de pré-visualização. A API poderá sofrer alterações que causem incompatibilidade no futuro.
