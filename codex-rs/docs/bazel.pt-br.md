# Bazel no codex-rs

Este repositório usa o Bazel para compilar o espaço de trabalho do Rust na diretoria `codex-rs`.
O Cargo continua sendo a fonte de referência para crates e recursos, enquanto o Bazel
oferece compilações herméticas, cadeias de ferramentas e artefatos multiplataforma.

Em 1º de junho de 2026, essa configuração ainda é experimental, pois estamos trabalhando para estabilizá-la.

## Esboço geral

- `../MODULE.bazel` define as dependências do Bazel e as cadeias de ferramentas do Rust.
- `rules_rs` importa crates de terceiros do `codex-rs/Cargo.toml` e
  `codex-rs/Cargo.lock` por meio de `crate.from_cargo(...)` e os expõe sob
  `@crates`.
- `../defs.bzl` fornece `codex_rust_crate`, que envolve `rust_library`,
  `rust_binary` e `rust_test`, para que os alvos do Bazel estejam alinhados com as convenções do Cargo.
  Ele oferece um conjunto sensato de configurações padrão que funcionam para a maioria dos crates originais, mas pode
  em alguns casos, é preciso fazer alguns ajustes.
- Cada caixa em `codex-rs/*/BUILD.bazel` normalmente utiliza `codex_rust_crate` e
  faz alguns ajustes caso o crate precise de dados adicionais em tempo de compilação ou em tempo de execução,
  ou outras personalizações.

## Executando o Bazel localmente

A raiz do repositório `justfile` expõe os pontos de entrada comuns do Bazel:

```bash
just bazel-test
just bazel-clippy
```

As chamadas locais comuns `bazel` e `just` são executadas localmente. Cache do BuildBuddy,
O upload de eventos de compilação, os downloads e a execução remota são configurações opcionais.

## BuildBuddy

O Codex utiliza o BuildBuddy para um cache compartilhado do Bazel e para compilações e testes remotos. Para utilizá-lo
Para acelerar suas compilações e testes, você precisará fornecer uma chave de API e selecionar um
configuração.

### Chave da API do BuildBuddy

Se você é funcionário da OpenAI, faça login no https://openai.buildbuddy.io e use o login do Google.

Crie uma chave de API do BuildBuddy conforme descrito no [Authentication Guide][bb-auth-guide] do BuildBuddy,
em seguida, adicione-o a `~/.bazelrc`:

```bazelrc
# Local machine only; this file contains a BuildBuddy credential.
common --remote_header=x-buildbuddy-api-key=<your-buildbuddy-api-key>
```

Manter a credencial fora do local de trabalho reduz o risco de, acidentalmente,
cometer esse ato.

Se você precisar de chaves de API diferentes para projetos distintos, insira a chave de API em
`%workspace%/user.bazelrc`, em vez disso. O `.bazelrc` registrado importa, opcionalmente,
esse arquivo, e `.gitignore` o exclui. Não faça o commit nem compartilhe um arquivo que contenha
a credencial.

[bb-auth-guide]: https://www.buildbuddy.io/docs/guide-auth/#managing-keys

### Seleção de uma configuração de compilação remota

Os funcionários da OpenAI devem, por padrão, utilizar o servidor da OpenAI com execução remota, a menos que
eles têm um motivo para escolher outra configuração. Adicione a seguinte configuração
até `%workspace%/user.bazelrc`:

```bazelrc
common --config=buildbuddy-openai-rbe
```

Os funcionários da OpenAI que não desejam a execução remota podem usar `buildbuddy-openai`. Usuários externos
deve-se usar `buildbuddy-generic-rbe` ou `buildbuddy-generic`. Veja abaixo mais detalhes sobre esses valores
configurações.

### Todas as configurações remotas

O GitHub Actions encaminha os comandos de compilação e resolução de saída do Bazel por meio de
`.github/scripts/run_bazel_with_buildbuddy.py`. Auxiliares de nível superior, tais como
`.github/scripts/run-bazel-ci.sh` e `.github/scripts/rusty_v8_bazel.py`
delegar a seleção da configuração remota a esse wrapper. O wrapper lê o
Repositório do GitHub Actions e carga útil do evento, em vez de depender do fluxo de trabalho
arquivos para duplicar a lógica de seleção de locatário. Além disso, normaliza o GitHub Actions
opções de inicialização para que todas as instâncias do Bazel iniciadas em uma tarefa reutilizem o mesmo servidor e
cache de análise na memória. Os auxiliares de descoberta de alvos e de arquivos de bloqueio delegam a tarefa ao
o mesmo wrapper, para que seus chamadores não precisem selecionar opções de inicialização específicas do CI.

Os comandos de descoberta de alvos na fase de carregamento `bazel query` são executados localmente porque eles
apenas enumeram rótulos e não precisam de caches remotos nem de execução remota.

O servidor `Cache/BES` também é usado para downloads remotos.

| Invocação/configuração | É necessária uma chave | Cache/BES | Executar compilação | Executar teste |
| --- | --- | --- | --- | --- |
| `bazel ...` | De | Nenhum | Local | Local |
| `bazel ... --config=buildbuddy-generic` | Sim | `remote.buildbuddy.io` | Local | Local |
| `bazel ... --config=buildbuddy-generic-rbe` | Sim | `remote.buildbuddy.io` | Remoto | Remoto |
| `bazel ... --config=buildbuddy-openai` | Sim | `openai.buildbuddy.io` | Local | Local |
| `bazel ... --config=buildbuddy-openai-rbe` | Sim | `openai.buildbuddy.io` | Remoto | Remoto |

Sem uma chave de API, o wrapper remove as configurações remotas de CI e executa
localmente. Com uma chave, os fluxos de trabalho selecionam o host da seguinte forma:

| Correr | Chave | Utiliza o OpenAI BuildBuddy Host |
| --- | --- | --- |
| Enviar para `main` em `openai/codex` | Sim | Sim |
| `workflow_dispatch` em `openai/codex` | Sim | Sim |
| Pull request no mesmo repositório em `openai/codex` | Sim | Sim |
| Fazer um fork do pull request para o repositório `openai/codex` | De | Não; local |
| Fazer um push ou chamar `workflow_dispatch` em um fork com uma chave | Sim | Não; host genérico |
| Pull request executada em um repositório fork com uma chave | Sim | Não; host genérico |

As configurações de CI determinam se as compilações e os testes são executados remotamente:

| Configuração do CI | Configuração remota | Executar compilação | Executar teste |
| --- | --- | --- | --- |
| `ci-linux` | `*-rbe` | Host remoto | Host remoto |
| `ci-v8` | `*-rbe` | Host remoto | Host remoto |
| Ctrl-Shift-Delete | `*-rbe` | Host remoto | Local |
| `ci-windows-cross` | `*-rbe` | Host remoto | Local |
| `ci-windows` | não-RBE | Local | Local |
| Modo alternativo do CI sem chave | nenhum | Local | Local |

Para realizar a configuração remota genérica com sua chave:

```bash
BUILDBUDDY_API_KEY=... GITHUB_REPOSITORY=my-fork/codex \
  ./.github/scripts/run_bazel_with_buildbuddy.py \
  build --config=ci-linux //codex-rs/cli:codex
```

O wrapper seleciona o host da OpenAI apenas dentro do GitHub Actions para um
executado em `openai/codex`. Um evento de pull request ausente ou com formato incorreto
A carga útil falha ao se conectar ao host genérico. Para acessar o host local da OpenAI, use
a configuração `user.bazelrc` acima.

## Aprimorando a configuração

Ao adicionar ou alterar dependências do Rust, atualize o arquivo Cargo.toml/Cargo.lock como de costume.
Em seguida, atualize o arquivo de bloqueio do Bzlmod a partir da raiz do repositório:

```bash
just bazel-lock-update
```

Isso executa `bazel mod deps --lockfile_mode=update` e atualiza `MODULE.bazel.lock`, se necessário.
Envie as alterações no arquivo de bloqueio junto com a atualização do seu arquivo de bloqueio do Cargo.

Para verificar o alinhamento do arquivo de bloqueio localmente (a mesma verificação que o CI executa), use:

```bash
just bazel-lock-check
```

Em alguns casos, um crate upstream pode precisar de um patch ou de um `crate.annotation` em `../MODULE.bzl`
para compilá-lo na sandbox do Bazel ou torná-lo compatível com a compilação cruzada. Se você encontrar algum problema,
Fique à vontade para entrar em contato com o zbarsky ou o mbolin.

Ao adicionar um novo crate ou binário:

1. Adicione-o à área de trabalho do Cargo como de costume.
2. Crie um `BUILD.bazel` que chame `codex_rust_crate` (consulte as caixas próximas para
   (exemplos).
3. Se uma dependência exigir um tratamento especial (dados de compilação/tempo de execução, binários adicionais
   (para testes de integração, variáveis de ambiente etc.), talvez seja necessário ajustar os parâmetros para
   `codex_rust_crate` para configurá-lo.
   Uma personalização comum é definir `test_tags = ["no-sandbox]` para executar o teste
   fora da sandbox. É preferível evitá-lo, mas é necessário em alguns casos, como quando o
   O próprio teste utiliza o Seatbelt (a sandbox também o utiliza, e não é possível aninhá-los).
   Para limitar o alcance do dano, considere isolar esses testes em um contêiner separado.

Se você encontrar algum problema na compilação e não souber como aplicar as personalizações adequadas, fique à vontade para entrar em contato com o zbarsky ou o mbolin.

## Referências

- Visão geral de Bazel: https://bazel.build/
- Bzlmod (sistema de módulos): https://bazel.build/external/overview
- rules_rust: https://github.com/bazelbuild/rules_rust
- rules_rs: https://github.com/bazelbuild/rules_rs
