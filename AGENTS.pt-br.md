# Rust/codex-rs

Na pasta `codex-rs`, onde fica o código em Rust:

- Os nomes das crates são precedidos pelo prefixo `codex-`. Por exemplo, a crate da pasta `core` se chama `codex-core`
- Ao usar o comando `format!` e puder inserir variáveis diretamente entre {}, faça isso sempre.
- Instale quaisquer comandos dos quais o repositório dependa (por exemplo, `just`, `rg` ou `cargo-insta`), caso ainda não estejam disponíveis, antes de executar as instruções aqui.
- Nunca adicione nem altere nenhum código relacionado a `CODEX_SANDBOX_NETWORK_DISABLED_ENV_VAR` ou `CODEX_SANDBOX_ENV_VAR`.
  - Você opera em um ambiente de teste (sandbox) no qual `CODEX_SANDBOX_NETWORK_DISABLED=1` será definido sempre que você usar a ferramenta `shell`. Qualquer código existente que utilize `CODEX_SANDBOX_NETWORK_DISABLED_ENV_VAR` foi escrito levando esse fato em consideração. Ele costuma ser usado para encerrar antecipadamente testes que o autor sabia que você não conseguiria executar, devido às limitações do seu ambiente de teste.
  - Da mesma forma, quando você inicia um processo usando o Seatbelt (`/usr/bin/sandbox-exec`), o valor `CODEX_SANDBOX=seatbelt` será definido no processo filho. Testes de integração que precisam executar o próprio Seatbelt não podem ser executados sob o Seatbelt; portanto, verificações de `CODEX_SANDBOX=seatbelt` também são frequentemente usadas para encerrar os testes antecipadamente, conforme apropriado.
- Sempre ocultar as instruções `if` de acordo com https://rust-lang.github.io/rust-clippy/master/index.html#collapsible_if
- Sempre no formato inline! Arguments, sempre que possível, conforme https://rust-lang.github.io/rust-clippy/master/index.html#uninlined_format_args
- Sempre que possível, utilize referências a métodos em vez de closures, conforme https://rust-lang.github.io/rust-clippy/master/index.html#redundant_closure_for_method_calls
- Evite parâmetros do tipo bool ou ambíguos como `Option`, que obrigam quem faz a chamada a escrever código de difícil leitura, como `foo(false)` ou `bar(None)`. Dê preferência a enums, métodos nomeados, newtypes ou outras formas idiomáticas de API do Rust quando elas mantiverem o local da chamada autoexplicativo.
- Quando não for possível fazer essa alteração na API e você ainda precisar de um pequeno ponto de chamada com literal posicional em Rust, siga a convenção `argument_comment_lint`:
  - Utilize um comentário exato `/*param_name*/` antes de argumentos literais opacos, como `None`, valores booleanos e literais numéricos, ao passá-los por posição.
  - O único argumento não-próprio de um método é isento quando os nomes do método e do parâmetro coincidem, como `.enabled(false)` para `fn enabled(&self, enabled: bool)`.
  - Não adicione esses comentários a literais de string ou char, a menos que o comentário traga clareza real; esses literais estão isentos intencionalmente da verificação do lint.
  - O nome do parâmetro no comentário deve corresponder exatamente à assinatura da função chamada.
  - Você pode executar `just argument-comment-lint` para realizar a verificação de lint localmente. Como isso é feito pelo Bazel, a primeira execução pode ser lenta se o Bazel ainda não estiver aquecido, embora as chamadas incrementais devam levar menos de 15s. Na maioria das vezes, é melhor atualizar o PR e deixar que a CI se encarregue dessa verificação (ou executá-la de forma assíncrona em segundo plano após enviar o PR). Observe que a CI verifica todas as três plataformas, o que não ocorre na execução local.
- Sempre que possível, procure que as instruções `match` sejam exaustivas e evite braços com caracteres curinga.
- As características recém-adicionadas devem incluir comentários de documentação que expliquem sua função e como se espera que as implementações as utilizem.
- Desencoraje o uso tanto de `#[async_trait]` quanto de `#[allow(async_fn_in_trait)]` em traits do Rust.
  - Dê preferência a métodos nativos de características RPITIT com limites explícitos `Send` no futuro retornado, como em `3c7f013f9735` / `#16630`.
  - Forma preferida do traço:
    `fn foo(&self, ...) -> impl std::future::Future<Output = T> + Send;`
  - As implementações ainda podem usar `async fn foo(&self, ...) -> T` quando cumprirem esse contrato.
  - Não use `#[allow(async_fn_in_trait)]` como atalho para evitar escrever explicitamente o contrato futuro.
- Ao escrever testes, é preferível comparar a igualdade de objetos inteiros em vez de campos, um por um.
- Não adicione testes para valores definidos estaticamente.
- Não adicione testes negativos para a lógica que foi removida.
- Não adicione documentação geral sobre o produto ou destinada aos usuários à pasta `docs/`. A documentação oficial do Codex está localizada em outro local. A exceção é a documentação da API do servidor de aplicativos, que é abordada nas orientações sobre o servidor de aplicativos a seguir.
- Dê preferência a módulos privados e a uma API pública do crate explicitamente exportada.
- Se você alterar `ConfigToml` ou tipos de configuração aninhados, execute `just write-config-schema` para atualizar `codex-rs/core/config.schema.json`.
- Ao trabalhar com chamadas de ferramentas MCP, dê preferência ao uso de `codex-rs/codex-mcp/src/mcp_connection_manager.rs` para lidar com a mutação de ferramentas e chamadas de ferramentas. Procure minimizar o impacto das alterações e aproveitar as abstrações existentes, em vez de criar código de ligação entre vários níveis de chamadas de função.
- Não chame `reset_client_session` desnecessariamente; deixe que a lógica de verificação incremental decida se a solicitação anterior deve ser reutilizada.
- Se você alterar as dependências do Rust (`Cargo.toml` ou `Cargo.lock`), execute `just bazel-lock-update` a partir do
  Atualizar a raiz do repositório para `MODULE.bazel.lock` e incluir essa atualização do arquivo de bloqueio na mesma alteração. CI
  verifica o deslocamento do arquivo de bloqueio.
- O Bazel não disponibiliza automaticamente os arquivos da árvore de código-fonte para acesso em Rust durante a compilação. Se
  você adiciona `include_str!`, `include_bytes!`, `sqlx::migrate!` ou um arquivo semelhante de compilação ou
  ao ler o diretório, atualize o `BUILD.bazel` do crate (`compile_data`, `build_script_data` ou test
  dados) ou o Bazel pode falhar mesmo quando o Cargo for bem-sucedido.
- Não crie pequenos métodos auxiliares que sejam chamados apenas uma vez.
- Para rastrear tarefas assíncronas, insira o código de rastreamento na definição da função ou do método com
  `#[tracing::instrument(...)]` em vez de associar intervalos aos futuros com
  `.instrument(...)` nos locais de chamada. Antes de adicionar instrumentação, verifique se o destinatário da chamada — ou
  o método de implementação ao qual ele delega imediatamente — já está instrumentado.
- Evite módulos grandes:
  - É preferível adicionar novos módulos em vez de ampliar os já existentes.
  - Módulos Rust com menos de 500 LoC, excluindo os testes.
  - Se um arquivo ultrapassar cerca de 800 LoC, adicione novas funcionalidades em um novo módulo, em vez de estender o atual
    o arquivo existente, a menos que haja um motivo sólido e documentado para não fazê-lo.
  - Essa regra se aplica especialmente a arquivos muito modificados, que já atraem alterações não relacionadas, como
    as `codex-rs/tui/src/app.rs`, `codex-rs/tui/src/bottom_pane/chat_composer.rs`,
    `codex-rs/tui/src/bottom_pane/footer.rs`, `codex-rs/tui/src/chatwidget.rs`,
    `codex-rs/tui/src/bottom_pane/mod.rs` e, da mesma forma, módulos centrais de orquestração.
  - Ao extrair código de um módulo grande, transfira os testes relacionados e a documentação do módulo/tipo para
    a nova implementação, de modo que as invariantes permaneçam próximas ao código ao qual pertencem.
  - Evite adicionar novos métodos independentes ao `codex-rs/tui/src/chatwidget.rs`, a menos que a alteração seja
    trivial; prefira novos módulos/arquivos e mantenha o `chatwidget.rs` focado na orquestração.
- Ao executar comandos do Rust (por exemplo, `just fix` ou `just test`), seja paciente com o comando e nunca tente encerrá-lo usando o PID. O bloqueio do Rust pode tornar a execução lenta; isso é esperado.

Execute o `just fmt` (no diretório `codex-rs`) automaticamente após concluir as alterações no código em qualquer parte deste repositório; não solicite aprovação para executá-lo. Além disso, execute os testes:

1. Não execute `cargo test` diretamente. Use `just test` para que a execução do teste siga as configurações padrão do repositório.
2. Execute o teste para o projeto específico que sofreu alterações. Por exemplo, se foram feitas alterações no `codex-rs/tui`, execute o `just test -p codex-tui`.
3. Depois que esses testes forem aprovados, caso tenham sido feitas alterações nos módulos common, core ou protocol, execute o conjunto completo de testes com `just test`. Evite usar `--all-features` em execuções locais de rotina, pois isso amplia a matriz de compilação e pode aumentar significativamente o uso de disco `target/`; use-o apenas quando precisar especificamente de cobertura completa dos recursos. Testes específicos do projeto ou individuais podem ser executados sem solicitar a confirmação do usuário, mas peça a confirmação do usuário antes de executar o conjunto completo de testes.

Antes de finalizar uma grande alteração no `codex-rs`, execute o `just fix -p <project>` (no diretório `codex-rs`) para corrigir quaisquer problemas de linter no código. Prefira definir o escopo com `-p` para evitar compilações lentas do Clippy em todo o espaço de trabalho; só execute `just fix` sem `-p` se você tiver alterado crates compartilhados. Não reexecute os testes após executar `fix` ou `fmt`.

## A caixa `codex-core`

Com o tempo, o crate `codex-core` (definido em `codex-rs/core/`) ficou muito inchado, pois é o maior crate, por isso, muitas vezes é mais fácil adicionar algo novo ao `codex-core` do que refatorar o código da biblioteca necessário para que seu novo código não dependa nem contribua para o tamanho do `codex-core`.

Para isso: **evite adicionar código ao codex-core**!

Especialmente ao introduzir um novo conceito/recurso/API, antes de adicioná-lo ao `codex-core`, considere se:

- Existe um crate, além do `codex-core`, que é o local adequado para hospedar seu novo código.
- É hora de introduzir um novo crate no espaço de trabalho do Cargo para sua nova funcionalidade. Refatore o código existente conforme necessário para que isso aconteça.

Da mesma forma, ao revisar o código, não hesite em rejeitar PRs que adicionariam código desnecessário ao `codex-core`.

## Regras para revisão de código

### Interface da API do Crate

Mantenha as interfaces da API do crate o mais reduzidas possível. Evite a proliferação de funções auxiliares destinadas exclusivamente a testes.

### Modelo de contexto visível

O Codex mantém um contexto (histórico de mensagens) que é enviado ao modelo nas solicitações de inferência.

1. Não se deve reescrever a história — o contexto deve ser construído de forma incremental.
2. Evite mudanças frequentes no contexto que causem erros de cache.
3. Não há itens sem limite — tudo o que for injetado no contexto do modelo deve ter um tamanho limitado e um limite máximo rígido.
4. Não são permitidos itens com mais de 10 mil tokens.
5. Destaque os novos itens individuais que possam ultrapassar >1 mil tokens como P0. Esses itens precisam de uma revisão manual adicional.
6. Todos os fragmentos injetados devem ser definidos como estruturas em `core/context` e implementar a característica ContextualUserFragment

### Alterações que exigem atualização

Pesquise alterações que causam incompatibilidade em interfaces de integração externas:

- APIs do servidor de aplicativos
- eventos de itens de resposta brutos (`rawResponseItem/*`), mesmo em fase experimental
- Parâmetros da CLI
- carregamento da configuração
- retomando sessões de implantações existentes

### Orientações para a elaboração de provas

Para alterações no agente, dê preferência aos testes de integração em vez dos testes unitários. Os testes de integração estão em `core/suite` e utilizam `test_codex` para configurar uma instância de teste do Codex.

Recursos que alteram a lógica do agente DEVEM incluir um teste de integração:

- Forneça uma lista das principais alterações na lógica e dos comportamentos visíveis ao usuário que precisam ser testados.

Se forem necessários testes unitários, coloque-os em um arquivo de teste específico (\*\_tests.rs).
Evite funções destinadas exclusivamente a testes na implementação principal.

Verifique se já existem funções auxiliares que tornem os testes mais eficientes e legíveis.

### Orientação sobre alteração de tamanho (800 linhas)

A menos que a alteração seja de natureza mecânica, o número total de linhas alteradas não deve exceder 800 linhas.
No caso de alterações complexas na lógica, o tamanho deve ser inferior a 500 linhas.

Se a mudança for mais abrangente, analise se ela pode ser dividida em etapas que possam ser avaliadas e identifique a menor etapa coerente a ser implementada primeiro.
Baseie a sugestão de implementação gradual nas diferenças reais, nas dependências e nos locais de chamada afetados.

## Convenções de estilo da TUI

Isso `codex-rs/tui/styles.md`.

## Convenções de codificação da TUI

- Use os auxiliares de estilo concisos da característica `Stylize` do ratatui.
  - Variações básicas: use "text".into()
  - Elementos `span` com estilo: use “text”.red(), “text”.green(), “text”.magenta(), “text”.dim(), etc.
  - É preferível usar essas formas em vez de construir estilos diretamente com `Span::styled` e `Style`.
  - Exemplo: linhas do arquivo de resumo do patch
    - Desejado: vec!["  └ ".into(), "M".red(), " ".dim(), "tui/src/app.rs".dim()]

### TUI Styling (ratatui)

- Dê preferência aos auxiliares do Stylize: use “text”.dim(), .bold(), .cyan(), .italic(), .underlined() em vez de definir estilos manualmente, sempre que possível.
- Prefira conversões simples: use “text”.into() para spans e vec![…].into() para linhas; quando a inferência for ambígua (por exemplo, Paragraph::new/Cell::from), use Line::from(spans) ou Span::from(text).
- Estilos calculados: se o estilo for calculado em tempo de execução, é válido usar `Span::styled` (`Span::from(text).set_style(style)` também é aceitável).
- Evite definir o branco diretamente no código: não use `.white()`; prefira a cor de primeiro plano padrão (sem cor).
- Encadeamento: combine métodos auxiliares por meio do encadeamento para facilitar a leitura (por exemplo, url.cyan().underlined()).
- Itens individuais: dê preferência a “text”.into(); use Line::from(text) ou Span::from(text) apenas quando o tipo de destino não for óbvio a partir do contexto ou quando o uso de .into() exigir anotações de tipo adicionais.
- Linhas de construção: use vec![…].into() para construir uma Line quando o tipo de destino for óbvio e não forem necessárias anotações de tipo adicionais; caso contrário, use Line::from(vec![…]).
- Evite mudanças desnecessárias: não refatore entre formas equivalentes (Span::styled ↔ set_style, Line::from ↔ .into()) sem um ganho claro em termos de legibilidade ou funcionalidade; siga as convenções locais do arquivo e não introduza anotações de tipo apenas para atender ao .into().
- Compacidade: dê preferência à forma que permanecer em uma única linha após a aplicação do rustfmt; se apenas uma das opções Line::from(vec![…]) ou vec![…].into() evitar o quebra de linha, escolha essa. Se ambas quebrarem a linha, escolha aquela com menos linhas quebradas.

### Quebra automática de linha

- Sempre use textwrap::wrap para quebrar o texto em strings simples.
- Se você tiver uma linha ratatui e quiser que ela seja quebrada, use os auxiliares em tui/src/wrapping.rs, por exemplo, word_wrap_lines / word_wrap_line.
- Se você precisar recuar as linhas que quebraram de linha, use as opções initial_indent / subsequent_indent do RtOptions, se possível, em vez de escrever uma lógica personalizada.
- Se você tiver uma lista de linhas e precisar adicionar um prefixo a todas elas (que pode ser diferente na primeira linha em relação às seguintes), use o auxiliar `prefix_lines` do pacote line_utils.

## Testes

### Organização do módulo de teste

- Ao adicionar um novo módulo de teste, defina seu conteúdo em um arquivo separado, no mesmo nível, em vez de incluí-lo diretamente no arquivo de implementação.
- Use um atributo `#[path = "..._tests.rs"]` explícito para que o nome do arquivo de teste seja descritivo e fácil de localizar:

  ```tranquilidade```
  #[cfg(test)]
  #[path = "parser_tests.rs"]
  contra testes;
  ```

- Isso se aplica apenas ao introduzir um novo módulo de teste. Não mova nem reescreva módulos inline `#[cfg(test)] mod tests { ... }` existentes apenas para seguir essa convenção.

### Testes de instantâneo

Este repositório utiliza testes de snapshot (por meio de `insta`), especialmente em `codex-rs/tui`, para validar a saída renderizada.

**Requisito:** qualquer alteração que afete a interface do usuário visível (incluindo a adição de novos elementos da interface) deve incluir
cobertura do snapshot correspondente `insta` (adicione um novo teste de snapshot caso ainda não exista um, ou
atualizar o snapshot existente). Analisar e aceitar as atualizações do snapshot como parte do PR para avaliar o impacto na interface do usuário
é fácil de revisar e as diferenças futuras permanecem visíveis.

Quando a interface do usuário ou a saída de texto forem alteradas intencionalmente, atualize os instantâneos da seguinte forma:

- Execute os testes para gerar eventuais instantâneos atualizados:
  - `just test -p codex-tui`
- Verifique o que está pendente:
  - `cargo insta pending-snapshots -p codex-tui`
- Analise as alterações lendo os arquivos `*.snap.new` gerados diretamente no repositório ou visualize um arquivo específico:
  - `cargo insta show -p codex-tui path/to/file.snap.new`
- Somente se você pretender aceitar todos os novos snapshots desta crate, execute:
  - `cargo insta accept -p codex-tui`

Se você não tiver a ferramenta:

- `cargo install --locked cargo-insta`

### Testes de desempenho

Os benchmarks do cargo podem ser executados com `just bench`; use a caixa divan para criar novos benchmarks.

Use `just bench-smoke` para executar o teste de desempenho em modo de simulação por uma única iteração, a fim de garantir que ele funcione.

### Asserções de teste

- Os testes devem usar `pretty_assertions::assert_eq` para gerar comparações mais claras. Importe essa biblioteca no início do módulo de teste, caso ainda não esteja lá.
- Sempre que possível, dê preferência a comparações com o operador “equals”. Aplique o operador `assert_eq!()` a objetos inteiros, em vez de campos individuais.
- Evite alterar o ambiente do processo nos testes; prefira passar sinalizadores ou dependências derivadas do ambiente a partir de camadas superiores.

### Geração de binários do espaço de trabalho em testes (Cargo x Bazel)

- Prefira `codex_utils_cargo_bin::cargo_bin("...")` em vez de `assert_cmd::Command::cargo_bin(...)` ou `escargot` quando os testes precisarem gerar binários próprios.
  - No Bazel, os binários e os recursos podem estar localizados nos arquivos de execução; use `codex_utils_cargo_bin::cargo_bin` para resolver caminhos absolutos que permanecem estáveis após `chdir`.
- Ao localizar arquivos de fixture ou recursos de teste no Bazel, evite usar `env!("CARGO_MANIFEST_DIR")`. Dê preferência a `codex_utils_cargo_bin::find_resource!` para que os caminhos sejam resolvidos corretamente tanto nos arquivos de execução do Cargo quanto do Bazel.

### Testes de integração

#### testes de integração do codex_core

- Prefira usar os utilitários em `core_test_support::responses` ao escrever testes de ponta a ponta do Codex.
- Use `TestCodexBuilder::build_with_auto_env()` como padrão para garantir que os novos testes funcionem com
  sistemas operacionais de aplicativos/executáveis externos. Consulte $remote-tests para obter mais detalhes.
- Todos os auxiliares `mount_sse*` retornam um `ResponseMock`; guarde-o para que você possa verificar os corpos das solicitações POST de saída `/responses`.
- Use `ResponseMock::single_request()` quando um teste deve emitir apenas um POST, ou `ResponseMock::requests()` para inspecionar cada `ResponsesRequest` capturado.
- `ResponsesRequest` disponibiliza auxiliares (`body_json`, `input`, `function_call_output`, `custom_tool_call_output`, `call_output`, `header`, `path`, `query_param`) para que as asserções possam ter como alvo cargas úteis estruturadas, em vez de uma análise manual do JSON.
- Crie cargas úteis SSE usando os construtores `ev_*` fornecidos e o `sse(...)`.
- Prefira `wait_for_event` a `wait_for_event_with_timeout`.
- Prefira `mount_sse_once` em vez de `mount_sse_once_match` ou `mount_sse_sequence`

- Padrão típico:

  ```tranquilidade```
  let mock = responses::mount_sse_once(&server, responses::sse(vec![
      responses::ev_response_created("resp-1"),
      responses::ev_function_call(call_id, "shell", &serde_json::to_string(&args)?),
      responses::ev_completed("resp-1"),
  ])).await;

  codex.submit(Op::UserTurn { ... }).await?;

  // Verifique o corpo da solicitação, se necessário.
  let request = mock.single_request();
  // Verifique usando request.function_call_output(call_id), request.json_body() ou outros auxiliares.
  ```

#### testes de integração do servidor de aplicativos

- Os testes devem testar a API JSON-RPC pública do servidor de aplicativos.
- Utilize simulações de servidor semelhantes às dos testes de integração principais.
- Use `TestAppServer::builder().build()` e `TestAppServer::send_thread_start_request_with_auto_env()`
  por padrão, para garantir que os novos testes funcionem com sistemas operacionais de aplicativos/execução externos. Consulte `$remote-tests` para
  detalhes.

## Melhores práticas para o desenvolvimento de APIs de servidores de aplicativos

Estas diretrizes se aplicam ao trabalho com protocolos de servidor de aplicativos no `codex-rs`, especialmente:

- `app-server-protocol/src/protocol/common.rs`
- `app-server-protocol/src/protocol/v2.rs`
- `app-server/README.md`

### Regras Básicas

- Todo o desenvolvimento ativo de APIs deve ocorrer no servidor de aplicativos v2. Não adicione novas interfaces de API à v1.
- Siga uma nomenclatura consistente para as cargas úteis:
  `*Params` para cargas úteis de solicitações, `*Response` para respostas e `*Notification` para notificações.
- Exponha os métodos RPC como `<resource>/<method>` e mantenha `<resource>` singular (por exemplo, `thread/read`, `app/list`).
- Sempre exponha os campos como camelCase na transmissão com `#[serde(rename_all = "camelCase")]`, a menos que uma união marcada ou um requisito explícito de compatibilidade exija uma renomeação específica.
- Sempre exponha os valores de enumeração de string como camelCase na transmissão de dados, com anotações correspondentes do serde e do TS `rename_all = "camelCase"`, a menos que um requisito explícito de compatibilidade exija renomeações específicas.
- Exceção: espera-se que as cargas de dados RPC de configuração utilizem snake_case para corresponder às chaves do arquivo config.toml (consulte as APIs de leitura, gravação e listagem de configuração em `app-server-protocol/src/protocol/v2.rs`).
- Sempre defina `#[ts(export_to = "v2/")]` nos tipos de solicitação/resposta/notificação v2 para que o TypeScript gerado seja colocado no namespace correto.
- Nunca utilize `#[serde(skip_serializing_if = "Option::is_none")]` nos campos de carga útil da API v2.
  Exceção: as solicitações cliente->servidor que, intencionalmente, não possuem parâmetros podem usar:
  `params: #[ts(type = "undefined")] #[serde(skip_serializing_if = "Option::is_none")] Option<()>`.
- Mantenha a renomeação de variáveis entre Rust e TS alinhada. Se um campo ou variante usar `#[serde(rename = "...")]`, adicione o correspondente `#[ts(rename = "...")]`.
- Para uniões discriminadas, utilize marcação explícita em ambos os serializadores:
  `#[serde(tag = "type", ...)]` e `#[ts(tag = "type", ...)]`.
- Prefira IDs simples `String` no limite da API (faça a análise/conversão de UUIDs internamente, se necessário).
- Os carimbos de data e hora devem ser segundos Unix inteiros (`i64`) e denominados `*_at` (por exemplo, `created_at`, `updated_at`, `resets_at`).
- Para a área de superfície experimental da API:
  use `#[experimental("method/or/field")]`, derive `ExperimentalApi` quando for necessário o controle de acesso por campo e use `inspect_params: true` em `common.rs` quando apenas alguns campos de um método forem experimentais.

### Cargas úteis de solicitações cliente->servidor (`*Params`)

- Todos os campos opcionais devem ser marcados com `#[ts(optional = nullable)]`. Não utilize `#[ts(optional = nullable)]` fora das cargas de solicitação cliente->servidor (`*Params`).
- Os campos opcionais de coleção (por exemplo, `Vec`, `HashMap`) devem usar `Option<...>` + `#[ts(optional = nullable)]`. Não utilize `#[serde(default)]` para modelar coleções opcionais e não utilize `skip_serializing_if` nos campos de carga útil da v2.
- Quando você quiser que a omissão signifique `false` para campos booleanos, use `#[serde(default, skip_serializing_if = "std::ops::Not::not")] pub field: bool` em vez de `Option<bool>`.
- Para novos métodos de lista, implemente a paginação por cursor por padrão:
  campos de solicitação `pub cursor: Option<String>` e `pub limit: Option<u32>`,
  campos de resposta `pub data: Vec<...>` e `pub next_cursor: Option<String>`.

### Fluxo de trabalho de desenvolvimento

- Atualizar a documentação e os exemplos do servidor de aplicativos quando houver alterações no comportamento da API (no mínimo `app-server/README.md`).
- Regenerar os fixtures do esquema quando houver alterações na estrutura da API:
  `just write-app-server-schema`
  (e `just write-app-server-schema --experimental` quando os fixtures da API experimental forem afetados).
- Valide com `just test -p codex-app-server-protocol`.
- Evite testes padronizados que apenas verifiquem marcadores de campo experimentais para cada
  campos de solicitação em `common.rs`; em vez disso, baseie-se na geração de esquemas/testes e na cobertura comportamental.

## Melhores práticas de desenvolvimento em Python

### Ignorar a compatibilidade com o Python 2

Este projeto utiliza Python 3+. Você não deve usar o módulo `__future__`.

Se você precisar verificar a compatibilidade de recursos entre diferentes versões pontuais da série 3.xx, consulte o
Campo `requires-python` mais próximo de `pyproject.toml` para verificar qual é a versão mínima do runtime compatível.

## Suporte a plataformas

Os testes e os recursos devem ser compatíveis com Linux, macOS e Windows, a menos que o recurso seja explicitamente específico de um sistema operacional.

O Codex permite a execução do servidor de aplicativos conectado e do servidor de execução em sistemas operacionais diferentes. Consulte o
`$remote-tests` para obter detalhes sobre os testes de integração dessas configurações.
