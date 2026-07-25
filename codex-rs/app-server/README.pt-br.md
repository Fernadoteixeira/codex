# codex-app-server

`codex app-server` é a interface que o Codex utiliza para criar interfaces ricas, como a [Extensão Codex para o VS Code](https://marketplace.visualstudio.com/items?itemName=openai.chatgpt).

## Índice

- [Protocol](#protocol)
- [Message Schema](#message-schema)
- [Core Primitives](#core-primitives)
- [Lifecycle Overview](#lifecycle-overview)
- [Initialization](#initialization)
- [API Overview](#api-overview)
- [Events](#events)
- [Approvals](#approvals)
- [Skills](#skills)
- [Apps](#apps)
- [Auth endpoints](#auth-endpoints)
- [Experimental API Opt-in](#experimental-api-opt-in)

## Protocolo

Assim como o [My Chemical Romance](https://modelcontextprotocol.io/), o `codex app-server` suporta comunicação bidirecional por meio de mensagens JSON-RPC 2.0 (com o cabeçalho `"jsonrpc":"2.0"` omitido na transmissão).

Meios de transporte compatíveis:

- stdio (`--stdio` ou `--listen stdio://`, padrão): JSON delimitado por quebra de linha (JSONL)
- websocket (`--listen ws://IP:PORT`): uma mensagem JSON-RPC por quadro de texto do websocket (**experimental / sem suporte**)
- soquete Unix (`--listen unix://` ou `--listen unix://PATH`): conexões WebSocket pelo `$CODEX_HOME/app-server-control/app-server-control.sock` ou por um caminho de soquete personalizado, utilizando o handshake padrão HTTP Upgrade
- desativado (`--listen off`): não expor um transporte local

Ao ser executado com `--listen ws://IP:PORT`, o mesmo listener também fornece testes básicos de integridade HTTP:

- `GET /readyz` retorna `200 OK` assim que o ouvinte estiver aceitando novas conexões.
- `GET /healthz` retorna `200 OK` quando não há nenhum cabeçalho `Origin`.
- Qualquer solicitação que contenha um cabeçalho `Origin` é rejeitada com `403 Forbidden`.

O transporte WebSocket é, no momento, experimental e não é suportado. Não o utilize para cargas de trabalho em produção.

Passe `--code-mode-host wss://HOST/PATH` para conectar este processo do servidor de aplicativos a um host remoto no modo de código, em vez de iniciar um host local. Essa conexão de saída é independente de `--listen` e é compartilhada pelas threads do processo. Use `ws://` para um host local no modo de código.

O transporte por soquete Unix destina-se a clientes do plano de controle do servidor de aplicativos local. `codex app-server proxy`
abre exatamente uma conexão de fluxo bruto com `$CODEX_HOME/app-server-control/app-server-control.sock`
por padrão, ou para `--sock PATH` quando especificado, e atua como proxy para os bytes entre esse soquete e o stdin/stdout.
O fluxo redirecionado transporta o handshake HTTP Upgrade do WebSocket, seguido pelos quadros do WebSocket.

Saída de rastreamento/log:

- `RUST_LOG` controla a filtragem e o nível de detalhamento dos registros.
- Defina `LOG_FORMAT=json` para enviar os logs de rastreamento do servidor de aplicativos para `stderr` no formato JSON (um evento por linha).

Comportamento da contrapressão:

- O servidor utiliza filas com limite entre a entrada de dados de transporte, o processamento de solicitações e as gravações de saída.
- Quando a entrada de solicitações está saturada, novas solicitações são rejeitadas com um código de erro JSON-RPC `-32001` e a mensagem `"Server overloaded; retry later."`.
- Os clientes devem considerar que essa operação pode ser repetida e utilizar o backoff exponencial com jitter.

## Esquema da mensagem

Atualmente, é possível gerar uma versão do esquema em TypeScript usando `codex app-server generate-ts` ou um pacote de JSON Schema por meio de `codex app-server generate-json-schema`. Cada saída é específica para a versão do Codex usada para executar o comando; portanto, garante-se que os artefatos gerados sejam compatíveis com essa versão.

```
codex app-server generate-ts --out DIR
codex app-server generate-json-schema --out DIR
```

## Primitivas de núcleo

A API disponibiliza três primitivas de nível superior que representam uma interação entre um usuário e o Codex:

- **Tópico**: Uma conversa entre um usuário e o agente do Codex. Cada tópico contém várias trocas de mensagens.
- **Turno**: Uma sequência da conversa, que geralmente começa com uma mensagem do usuário e termina com uma mensagem do agente. Cada turno contém vários itens.
- **Item**: Representa as entradas do usuário e as respostas do agente como parte do turno, sendo armazenadas e utilizadas como contexto para conversas futuras. Exemplos de itens incluem mensagens do usuário, raciocínio do agente, mensagens do agente, comandos de shell, edição de arquivos, etc.

Use as APIs do Thread para criar, listar ou arquivar conversas. Conduza uma conversa com as APIs de turno e acompanhe o andamento por meio de notificações de turno.

## Visão geral do ciclo de vida

- Inicializar uma vez por conexão: Imediatamente após abrir uma conexão de transporte, envie uma solicitação `initialize` com os metadados do seu cliente e, em seguida, emita uma notificação `initialized`. Qualquer outra solicitação nessa conexão antes desse handshake será rejeitada.
- Iniciar (ou retomar) um tópico: chame `thread/start` para abrir uma nova conversa. A resposta retorna o objeto do tópico e você também receberá uma notificação `thread/started`. Se estiver dando continuidade a uma conversa existente, chame `thread/resume` com o ID dela. Se quiser criar um ramo a partir de uma conversa existente, chame `thread/fork` para criar um novo ID de thread com o histórico copiado. Assim como `thread/start`, `thread/fork` também aceita `ephemeral: true` para um thread temporário na memória.
  O sinalizador `thread.ephemeral` retornado indica se a sessão está intencionalmente apenas na memória; quando ele é `true`, `thread.path` é `null`.
- Iniciar um turno: Para enviar a entrada do usuário, chame `turn/start` com o destino `threadId` e a entrada do usuário. Campos opcionais permitem substituir a seleção do modelo, do diretório de trabalho (cwd), da política de sandbox ou do perfil experimental `permissions`, da política de aprovação, do revisor de aprovações etc. Isso retorna imediatamente o novo objeto de turno. O servidor de aplicativos emite `turn/started` quando esse turno realmente começa a ser executado.
- Eventos de streaming: Após `turn/start`, continue lendo as notificações JSON-RPC na saída padrão (stdout). Você verá `item/started`, `item/completed`, deltas como `item/agentMessage/delta`, o andamento da ferramenta etc. Esses elementos representam a saída do modelo em streaming, além de quaisquer efeitos colaterais (comandos, chamadas de ferramentas, notas de raciocínio).
- Concluir o turno: Quando o modelo estiver concluído (ou o turno for interrompido por meio da chamada `turn/interrupt`), o servidor envia `turn/completed` com o estado final do turno e o uso dos tokens.

## Inicialização

Os clientes devem enviar uma única solicitação `initialize` por conexão de transporte antes de invocar qualquer outro método nessa conexão e, em seguida, confirmar com uma notificação `initialized`. O servidor retorna a string do agente do usuário que apresentará aos serviços upstream, `codexHome` para o diretório raiz do Codex do servidor e as strings `platformFamily` e `platformOs` que descrevem o destino de tempo de execução do servidor de aplicativos; solicitações subsequentes emitidas antes da inicialização recebem um erro `"Not initialized"`, e chamadas repetidas `initialize` na mesma conexão recebem um erro `"Already initialized"`.

O `initialize.params.capabilities` também oferece suporte à exclusão de notificações por conexão por meio do `optOutNotificationMethods`, que é uma lista dos nomes exatos dos métodos a serem suprimidos para essa conexão. A correspondência é exata (sem curingas/prefixos). Nomes de métodos desconhecidos são aceitos e ignorados.

Clientes que processam formulários MCP estendidos da OpenAI, incluindo uma opção alternativa para
tipos de campo não suportados, definir
`initialize.params.capabilities.mcpServerOpenaiFormElicitation` a `true`.
O servidor de aplicativos, então, anuncia a extensão MCP `openai/form` de downstream para
threads iniciados, retomados ou criados por essa conexão. Clientes que não conseguem
Ao processar o envelope da solicitação, omita o campo ou defina-o como `false`.

Os aplicativos desenvolvidos com base no `codex app-server` devem se identificar por meio do parâmetro `clientInfo`.

**Importante**: `clientInfo.name` é usado para identificar o cliente na Plataforma de Registros de Conformidade da OpenAI. Se
Se você estiver desenvolvendo uma nova integração com o Codex destinada ao uso corporativo, entre em contato conosco para obtê-la
adicionado à lista de clientes conhecidos. Para mais contexto: https://chatgpt.com/admin/api-reference#tag/Logs:-Codex

Exemplo (da extensão oficial do VSCode da OpenAI):

```json
{
  "method": "initialize",
  "id": 0,
  "params": {
    "clientInfo": {
      "name": "codex_vscode",
      "title": "Codex VS Code Extension",
      "version": "0.1.0"
    }
  }
}
```

Exemplo com opção de cancelamento de notificações:

```json
{
  "method": "initialize",
  "id": 1,
  "params": {
    "clientInfo": {
      "name": "my_client",
      "title": "My Client",
      "version": "0.1.0"
    },
    "capabilities": {
      "experimentalApi": true,
      "optOutNotificationMethods": ["thread/started", "item/agentMessage/delta"]
    }
  }
}
```

## Visão geral da API

- `thread/start` — cria uma nova thread; emite `thread/started` (incluindo o `thread.status` atual) e inscreve você automaticamente para receber eventos de turn/item dessa thread. O `historyMode: "paginated"` experimental seleciona um histórico durável baseado em projeção. Quando a solicitação inclui um `cwd` e a sandbox resolvida é `workspace-write` ou acesso total, o servidor de aplicativos também marca esse projeto como confiável no `config.toml` do usuário. Passe `sessionStartSource: "clear"` ao iniciar uma thread de substituição após limpar a sessão atual, para que os ganchos `SessionStart` recebam `source: "clear"` em vez do padrão `"startup"`. O recurso experimental `allowProviderModelFallback` permite que provedores apoiados por um catálogo de modelos estático e autoritário substituam um `model` solicitado indisponível pelo padrão do catálogo; catálogos dinâmicos ou em cache preservam o modelo solicitado. O recurso experimental `runtimeWorkspaceRoots` fornece as raízes do espaço de trabalho de tempo de execução usadas quando o servidor de aplicativos cria seleções de ambiente padrão; os caminhos devem ser absolutos. Para permissões, prefira a seleção experimental `permissions` de perfil por ID; a sintaxe abreviada legada `sandbox` ainda é aceita, mas não pode ser combinada com `permissions`. O experimental `multiAgentMode`, obsoleto, é ignorado; use o esforço de raciocínio do Ultra para um comportamento proativo de múltiplos agentes. O experimental `environments` seleciona os ambientes de execução fixos para os turnos na thread; omita-o para usar o padrão do servidor, passe `[]` para desativar ambientes ou passe IDs de ambiente explícitos com `cwd` por ambiente e `runtimeWorkspaceRoots` nativo do ambiente (opcional). Ambientes explícitos ignoram as raízes de nível superior; raízes por ambiente omitidas assumem por padrão o valor `cwd` desse ambiente, enquanto uma lista vazia seleciona explicitamente nenhuma raiz. O parâmetro experimental `selectedCapabilityRoots` seleciona raízes de plug-ins pertencentes ao ambiente ou de habilidades autônomas usando caminhos absolutos nativos do ambiente. As habilidades encontradas abaixo dessas raízes são listadas e lidas por meio do ambiente proprietário. Os servidores Stdio MCP declarados pelos plug-ins selecionados são iniciados nesse ambiente, e as conexões HTTP MCP utilizam o cliente HTTP desse ambiente.
- `thread/resume` — reabre um tópico existente pelo ID, de modo que as chamadas subsequentes de `turn/start` sejam anexadas a ele. Aceita as mesmas regras de substituição de permissão que `thread/start`.
- `thread/fork` — cria uma ramificação de um tópico existente em um novo ID de tópico, copiando o histórico armazenado; passe um `lastTurnId` opcional para copiar apenas o histórico até aquele turno, inclusive, e descartar os turnos posteriores da ramificação. Um limite `lastTurnId` em andamento é rejeitado. A opção experimental `beforeTurnId`, por sua vez, copia o histórico estritamente antes da rodada referenciada, inclusive quando essa rodada está em andamento, e não pode ser combinada com `lastTurnId`. Se ambos os limites forem nulos enquanto a thread de origem estiver no meio de uma volta, a bifurcação registra o mesmo marcador de interrupção que `turn/interrupt`, em vez de herdar um sufixo de volta parcial não marcado. O `thread.forkedFromId` retornado aponta para a thread de origem, quando conhecida. Aceita `ephemeral: true` para uma bifurcação temporária na memória, emite `thread/started` (incluindo o `thread.status` atual) e inscreve você automaticamente nos eventos de turno/item da nova thread. Clientes experimentais podem passar `excludeTurns: true` quando planejam paginar o histórico de bifurcações via `thread/turns/list`, em vez de receber a matriz completa de turnos imediatamente, ou `deferGoalContinuation: true` para transportar a meta atual da thread de origem para a bifurcação e executar um turno explícito antes que a continuação automática seja retomada. A continuação de meta diferida é mantida até que essa rodada comece e não pode ser combinada com `ephemeral: true`. Aceita as mesmas regras de substituição de permissão que `thread/start`.
- As respostas `thread/start`, `thread/resume` e `thread/fork` incluem a projeção de compatibilidade legada `sandbox`. `instructionSources` lista os arquivos de instruções carregados usando a sintaxe de caminho absoluto nativa de cada ambiente de origem, incluindo arquivos carregados de ambientes remotos. Clientes experimentais podem ler `runtimeWorkspaceRoots` para as raízes de tempo de execução no escopo da thread e `activePermissionProfile` para a identidade/proveniência do perfil embutido, nomeado ou implícito, quando conhecida. Seu campo experimental obsoleto `multiAgentMode` e a configuração de thread correspondente sempre relatam `explicitRequestOnly`; o esforço de raciocínio do Ultra é a fonte do comportamento proativo de múltiplos agentes.
- `thread/list` — percorre as threads armazenadas; suporta paginação baseada no cursor e os filtros opcionais `modelProviders`, `sourceKinds`, `archived`, `isPinned`, `cwd` e `searchTerm`. Clientes experimentais podem usar `parentThreadId` para filhos gerados diretamente ou `ancestorThreadId` para descendentes gerados em qualquer profundidade; os dois filtros são mutuamente exclusivos. Os threads de revisão e de guarda não estão incluídos, pois não participam desse ciclo de vida de geração. Cada `thread` retornado inclui `status` (`ThreadStatus`), cujo valor padrão é `notLoaded` quando a thread não está carregada no momento. As threads de subagentes também incluem `parentThreadId` quando o pai imediato é conhecido.
- `thread/loaded/list` — lista os IDs das threads atualmente carregadas na memória.
- `thread/read` — lê um thread armazenado pelo ID sem retomá-lo; opcionalmente, inclui turnos por meio de `includeTurns`. O valor `thread` retornado inclui `status` (`ThreadStatus`), assumindo o valor padrão `notLoaded` quando a thread não estiver carregada no momento. Para threads carregadas, clientes experimentais podem usar `canAcceptDirectInput` para determinar se `turn/start` e `turn/steer` são aceitos; threads armazenadas não carregadas informam `null` quando esse recurso não estiver disponível.
- `thread/turns/list` — experimental; permite percorrer o histórico de turnos de um thread armazenado sem retomá-lo; oferece suporte à paginação baseada no cursor com `sortDirection`, `itemsView`, `nextCursor` e `backwardsCursor`.
- `thread/items/list` — experimental; percorre os itens do thread persistido sem retomar o thread. Passe `turnId` para restringir os resultados a uma rodada, ou omita-o para percorrer os itens em todo o thread. O armazenamento do thread ativo deve oferecer suporte à paginação de itens.
- `thread/searchOccurrences` — experimental; localiza correspondências literais, sem distinção entre maiúsculas e minúsculas, nas mensagens visíveis do usuário e nas mensagens finais do assistente selecionadas no resumo, dentro de um tópico paginado.
- `thread/metadata/update` — atualiza os metadados da thread armazenados no SQLite; suporta a atualização dos campos `gitInfo` e `isPinned` persistidos e retorna o `thread` atualizado.
- `thread/settings/update` — experimental; coloca em fila uma atualização parcial das configurações do próximo turno de um thread carregado, sem iniciar um turno nem adicionar itens de transcrição. Campos omitidos mantêm as configurações inalteradas; `serviceTier: null` limpa o nível; o `multiAgentMode`, obsoleto, é ignorado, enquanto o esforço de raciocínio Ultra permite um comportamento proativo entre múltiplos agentes; `sandboxPolicy` e `permissions` não podem ser combinados. Retorna `{}` quando a atualização é aceita e emite `thread/settings/updated` com as configurações efetivas completas somente se elas realmente forem alteradas. As substituições de configurações `turn/start` emitem a mesma notificação quando alteram as configurações armazenadas.
- `thread/memoryMode/set` — experimental; define a elegibilidade de uma thread para a memória persistente como `"enabled"` ou `"disabled"`, seja para uma thread carregada ou para um rollout armazenado; retorna `{}` em caso de sucesso.
- `memory/reset` — experimental; limpa o diretório atual `CODEX_HOME/memories` e reinicializa os dados do estágio de memória persistente no SQLite, preservando os modos de memória das threads existentes; retorna `{}` em caso de sucesso.
- `thread/goal/set` — cria ou atualiza a única meta persistida para uma thread materializada; retorna a meta atual e emite `thread/goal/updated`.
- `thread/goal/get` — recupera a meta atual persistida para uma thread materializada; retorna `goal: null` quando não há nenhuma meta.
- `thread/goal/clear` — limpa a meta atual persistida para uma thread materializada; retorna se uma meta foi removida e emite `thread/goal/cleared` quando o estado muda.
- `thread/goal/updated` — notificação emitida sempre que a meta de um thread é alterada; inclui a meta atual completa.
- `thread/goal/cleared` — notificação emitida sempre que uma meta de thread é removida.
- `thread/settings/updated` — notificação experimental enviada aos clientes inscritos quando as configurações efetivas da próxima vez de execução de um thread carregado são alteradas; inclui `threadId` e o `threadSettings` completo.
- `thread/status/changed` — notificação emitida quando o status de um thread carregado muda (`threadId` + novo `status`).
- `thread/archive` — move o arquivo de rollout de uma thread para o diretório de arquivamento e tenta mover os arquivos de rollout de quaisquer threads descendentes geradas; retorna `{}` em caso de sucesso e emite `thread/archived` para cada thread arquivada.
- `thread/delete` — exclui definitivamente um tópico ativo ou arquivado e quaisquer tópicos descendentes gerados; retorna `{}` em caso de sucesso e emite `thread/deleted` para cada tópico excluído.
- `thread/unsubscribe` — cancelar a inscrição desta conexão nos eventos de turn/item do thread. Se este fosse o último assinante, o servidor mantém a thread carregada e só a descarrega após 30 minutos sem assinantes e sem atividade na thread, executa os ganchos `SessionEnd` e, em seguida, emite `thread/closed`.
- `thread/name/set` — define ou atualiza o nome de um thread exibido ao usuário, seja para um thread carregado ou para um rollout persistido; retorna `{}` em caso de sucesso e emite `thread/name/updated` para clientes inicializados e que tenham optado por participar. Não é necessário que os nomes dos threads sejam únicos; as consultas de nome remetem ao thread atualizado mais recentemente.
- `thread/unarchive` — move um arquivo de rollout arquivado de volta para o diretório de sessões; retorna o `thread` restaurado em caso de sucesso e emite `thread/unarchived`.
- `thread/compact/start` — aciona a compactação do histórico de conversas de um tópico; retorna `{}` imediatamente, enquanto o progresso é exibido por meio das notificações padrão de turno/item.
- `thread/shellCommand` — executa um comando de shell `!` iniciado pelo usuário em uma thread; isso é executado fora da sandbox, com acesso total, em vez de herdar a política de sandbox da thread. Retorna `{}` imediatamente, enquanto o progresso é transmitido por meio de notificações padrão de turno/item, e qualquer turno ativo recebe a saída formatada em seu fluxo de mensagens.
- `thread/backgroundTerminals/clean` — encerra todos os terminais em segundo plano em execução de uma thread (experimental; requer `capabilities.experimentalApi`); retorna `{}` quando a solicitação de limpeza é aceita.
- `thread/backgroundTerminals/list` — lista os terminais em execução em segundo plano para uma thread carregada (experimental; requer `capabilities.experimentalApi`); retorna `data` com os IDs dos terminais em execução.
- `thread/backgroundTerminals/terminate` — encerra um terminal em segundo plano em execução pelo app-server `processId` (experimental; requer `capabilities.experimentalApi`); retorna se um processo foi encerrado.
- `thread/rollback` — obsoleto e será removido em breve. Remove as últimas N iterações do contexto em memória do agente e armazena um marcador de reversão no rollout para que futuras retomadas vejam o histórico podado; retorna o `thread` atualizado (com `turns` preenchido) em caso de sucesso. Threads paginadas não suportam reversão.
- `turn/start` — adiciona a entrada do usuário a um thread e inicia a geração do Codex; responde com o objeto inicial `turn` e transmite as notificações `turn/started`, `item/*` e `turn/completed`. `clientUserMessageId` é opcional; quando fornecido, o item `userMessage` correspondente o repete como `clientId`. O recurso experimental `runtimeWorkspaceRoots` fornece as raízes padrão para seleções de ambiente recém-resolvidas. A substituição explícita `environments[].runtimeWorkspaceRoots` substitui esse padrão por caminhos absolutos nativos do ambiente. Dê preferência à seleção experimental de perfil `permissions` por ID para substituições de permissão; o campo legado `sandboxPolicy` ainda é aceito, mas não pode ser combinado com `permissions`. Para `collaborationMode`, `settings.developer_instructions: null` significa “usar instruções integradas para o modo selecionado”. O `multiAgentMode` experimental, obsoleto, é ignorado; o raciocínio do Ultra seleciona um comportamento proativo.
- `thread/inject_items` — acrescenta itens brutos da API de respostas ao histórico visível pelo modelo de um tópico carregado, sem iniciar uma rodada do usuário; retorna `{}` em caso de sucesso.
- `turn/steer` — adiciona uma entrada do usuário a uma volta regular já em andamento, sem iniciar uma nova volta; retorna o `turnId` ativo que aceitou a entrada. `clientUserMessageId` é opcional; quando fornecido, o item `userMessage` correspondente o exibe como `clientId`. As etapas de revisão e compactação manual rejeitam `turn/steer`.
- `turn/interrupt` — solicita o cancelamento de uma manobra em voo por `(thread_id, turn_id)`; o sucesso é indicado por uma resposta vazia de `{}`, e a manobra é concluída com `status: "interrupted"`.
- `thread/realtime/start` — inicia uma sessão em tempo real com escopo de thread (experimental); passe `outputModality: "text"` ou `outputModality: "audio"` para escolher a saída do modelo; opcionalmente, passe `model` e `version` para substituir a seleção em tempo real configurada apenas para esta sessão; passe `includeStartupContext: false` para omitir o contexto de inicialização gerado pelo Codex, e, opcionalmente, passe `initialItems` para inicializar o V3 com mensagens de texto completas contendo funções na criação da sessão. A versão `"v1"` usa o Bidi legado `conversation.handoff.*`, a `"v2"` usa a API de Voz em Tempo Real e a `"v3"` preserva o comportamento do Codex Voice V1 ao usar o Frameless Bidi `delegation.*`. Para o texto automático do Codex da V3, `codexResponseHandoffMode` aceita `"thinking"` (o padrão; toda a saída usa acréscimos sem canal), `"commentary"` (toda a saída usa o canal de comentários) ou `"bemTags"` (o envelope BEM bruto seleciona o canal da API: BEM `analysis` e `commentary` usam `commentary`, enquanto BEM `final` e saídas não analisáveis usam `speakable`). O envelope BEM permanece no texto anexado para que o modelo front-end o interprete. As versões V1 e V2 ignoram essa configuração. As transferências da versão V3 não antepõem o rótulo legado `"Agent Final Message"`. Passe `clientManagedHandoffs: true` para desativar o envio automático de respostas do Codex, de modo que apenas as chamadas explícitas de acréscimo do cliente produzam transferências. Passe `codexResponsesAsItems: true` para enviar respostas automáticas do Codex como itens de conversa em tempo real e, opcionalmente, passe `codexResponseItemPrefix` para antepor instruções do experimento a esses itens. Retorna `{}` e transmite notificações `thread/realtime/*`. Omita `transport` para o transporte via WebSocket ou passe `{ "type": "webrtc", "sdp": "..." }` para criar uma sessão Bidi WebRTC a partir de uma oferta SDP gerada pelo navegador; a resposta SDP remota é emitida como `thread/realtime/sdp`. As solicitações de conversação `version: "v2"` continuam sem suporte para WebRTC.
- `thread/realtime/appendAudio` — acrescenta um trecho de áudio de entrada à sessão em tempo real ativa (experimental); retorna `{}`.
- `thread/realtime/appendText` — acrescenta a entrada de texto à sessão ativa em tempo real com um `role` obrigatório de `user`, `developer` ou `assistant` (experimental); retorna `{}`. Clientes mais antigos que omitem `role` usam `user` como padrão.
- `thread/realtime/appendSpeech` — acrescenta o texto que o modelo em tempo real deve dizer ao usuário (experimental); retorna `{}`.
- `thread/realtime/stop` — interrompe a sessão ativa em tempo real da thread (experimental); retorna `{}`.
- `review/start` — aciona o revisor automatizado do Codex para um tópico; responde como `turn/start`. Revisões embutidas geram notificações `item/started`/`item/completed` com itens `enteredReviewMode` e `exitedReviewMode`, além de um assistente final `agentMessage` contendo a revisão. Revisões separadas transmitem itens de turno comuns no novo tópico de revisão.
- `command/exec` — executa um único comando na área restrita do servidor sem iniciar uma thread/turno (útil para utilitários e validação).
- `command/exec/write` — grava os bytes da entrada padrão (stdin) decodificados em base64 em uma sessão `command/exec` em execução ou fecha a entrada padrão (stdin); retorna `{}`.
- `command/exec/resize` — redimensiona uma sessão `command/exec` em execução, baseada em PTY, em `processId`; retorna `{}`.
- `command/exec/terminate` — encerra uma sessão `command/exec` em execução por meio de `processId`; retorna `{}`.
- `command/exec/outputDelta` — notificação emitida para blocos de stdout/stderr codificados em base64 provenientes de uma sessão de streaming `command/exec`.
- `process/spawn` — experimental; inicia um processo independente sem a sandbox do Codex no host onde o servidor de aplicativos está em execução; retorna após o início do processo e emite as notificações `process/outputDelta` e `process/exited`.
- `process/writeStdin` — experimental; grava os bytes da entrada padrão (stdin) decodificados em base64 em uma sessão `process/spawn` em execução ou fecha a entrada padrão (stdin); retorna `{}`.
- `process/resizePty` — experimental; redimensiona uma sessão `process/spawn` em execução, baseada em PTY, em `processHandle`; retorna `{}`.
- `process/kill` — experimental; encerra uma sessão `process/spawn` em execução por meio de `processHandle`; retorna `{}`.
- `process/outputDelta` — experimental; notificação emitida para blocos de stdout/stderr codificados em base64 provenientes de uma sessão de streaming `process/spawn`.
- `process/exited` — experimental; notificação emitida quando uma sessão `process/spawn` é encerrada.
- `fs/readFile` — lê um caminho absoluto de arquivo e retorna `{ dataBase64 }`.
- `fs/writeFile` — gera um caminho absoluto de arquivo a partir do valor `{ dataBase64 }` codificado em base64; retorna `{}`.
- `fs/createDirectory` — cria um caminho absoluto de diretório; `recursive` é o padrão para `true`.
- `fs/getMetadata` — retorna metadados para um caminho absoluto: `isDirectory`, `isFile`, `isSymlink`, `createdAtMs` e `modifiedAtMs`.
- `fs/readDirectory` — lista as entradas filhas diretas de um caminho absoluto de diretório; cada entrada contém `fileName`, `isDirectory` e `isFile`, e `fileName` é apenas o nome do filho, não um caminho.
- `fs/remove` — remove um arquivo ou uma árvore de diretórios absoluta; `recursive` e `force` assumem o valor padrão `true`.
- `fs/copy` — copiar entre caminhos absolutos; cópias de diretórios exigem `recursive: true`.
- `fs/watch` — inscreve esta conexão para receber notificações de alterações no sistema de arquivos para um caminho absoluto de arquivo ou diretório e o valor `watchId` fornecido pelo chamador; retorna o valor canonizado `path`.
- `fs/unwatch` — interrompe o envio de notificações para um `fs/watch` anterior; retorna `{}`.
- `fs/changed` — notificação emitida quando os caminhos monitorados sofrem alterações, incluindo o `watchId` e o `changedPaths`.
- `model/list` — lista os modelos disponíveis (defina `includeHidden: true` para incluir entradas com `hidden: true`), com as opções de esforço de raciocínio por string anunciadas pelo modelo na ordem de progressão pretendida do catálogo, `additionalSpeedTiers`, `serviceTiers`, opcional `defaultServiceTier`, IDs de modelos legados opcionais `upgrade`, metadados opcionais `upgradeInfo` (`model`, `upgradeCopy`, `modelLink`, `migrationMarkdown`) e metadados opcionais `availabilityNux`. Os clientes devem preservar a ordem da matriz `supportedReasoningEfforts`, em vez de derivar a ordem a partir dos nomes dos esforços.
- `modelProvider/capabilities/read` — ler os recursos no nível do provedor para o provedor de modelo atualmente configurado.
- `experimentalFeature/list` — lista os sinalizadores de recurso com metadados de estágio (`beta`, `underDevelopment`, `stable`, etc.), estado ativado/ativado por padrão e paginação por cursor. Passe `threadId` ao exibir o estado de um recurso para um thread carregado existente, de modo que `enabled` seja calculado a partir da configuração atualizada desse thread, incluindo a configuração local do projeto para o diretório de trabalho atual do thread; se omitido, o servidor usa seu contexto padrão de resolução de configuração. Para sinalizadores que não sejam beta, `displayName`/`description`/`announcement` são `null`.
- `permissionProfile/list` — beta; lista os IDs dos perfis de permissão disponíveis com texto de exibição opcional `description` e um indicador `allowed` que reflete os requisitos efetivos, utilizando paginação por cursor. Passe `cwd` quando o chamador precisar que entradas `[permissions.<id>]` locais do projeto sejam incluídas na visualização atual do catálogo.
- `experimentalFeature/enablement/set` — aplica a ativação do recurso de tempo de execução em memória para todo o processo, para as chaves de recurso atualmente suportadas. Para cada recurso, a ordem de prioridade é: requisitos da nuvem > --enable <feature_name> > config.toml > experimentalFeature/enablement/set (novo) > padrão do código. Chaves inválidas serão ignoradas.
- `environment/add` — experimental; adiciona ou substitui um ambiente remoto nomeado por `environmentId` e `execServerUrl` para seleção posterior por `thread/start` ou `turn/start`; o opcional `connectTimeoutMs` substitui o tempo limite da conexão WebSocket; retorna `{}` e não altera o ambiente padrão.
- `environment/info` — experimental; conecta-se a um ambiente configurado por `environmentId` e retorna o `shell` detectado, somado ao `cwd` padrão, como um URI `file:` canônico nativo do ambiente. Falhas na conexão são retornadas como erros de solicitação.
- `environment/status` — experimental; lê o status atual de um `environmentId` configurado. Ambientes remotos prontos são verificados por meio de sua conexão existente com o servidor de execução, sem iniciar ou reconectar os ambientes; a resposta indica `ready`, `pending`, `disconnected` ou `unknown`.
- `thread/environment/connected` e `thread/environment/disconnected` — experimental; relatam as transições de conexão com o servidor executivo observadas após a inicialização da thread em ambientes selecionados. O estado atual da conexão não é reproduzido.
- `collaborationMode/list` — lista as predefinições disponíveis para o modo de colaboração (experimental, sem paginação). As predefinições integradas não selecionam um modelo; a predefinição “Plan” seleciona um esforço de raciocínio médio. Esta resposta omite as instruções integradas para desenvolvedores; os clientes devem passar `settings.developer_instructions: null` ao definir um modo para usar as instruções integradas do Codex ou fornecer suas próprias instruções explicitamente.
- `skills/list` — listar habilidades para um ou mais valores `cwd` (opcional `forceReload`).
- `skills/extraRoots/set` — substitua as raízes das habilidades autônomas adicionais em tempo de execução do processo do servidor de aplicativos. As raízes não são persistidas; diretórios ausentes são aceitos e simplesmente não carregam nenhuma habilidade.
- `hooks/list` — lista os hooks encontrados para um ou mais valores `cwd`.
- `marketplace/add` — adiciona uma loja de plug-ins remota a partir de uma URL Git HTTP(S), uma URL Git SSH ou uma abreviação do GitHub `owner/repo` e, em seguida, armazena essa configuração na configuração da loja do usuário. Retorna o caminho raiz da instalação e indica se a loja já estava presente.
- `marketplace/remove` — remove um marketplace configurado pelo nome da configuração de marketplaces do usuário e exclui a raiz do marketplace instalado, caso exista.
- `marketplace/upgrade` — atualiza todos os marketplaces de plug-ins do Git configurados ou um marketplace específico, caso `marketplaceName` seja fornecido. Retorna os nomes dos marketplaces selecionados, as raízes atualizadas e os erros por marketplace.
- `plugin/list` — lista os mercados de plug-ins detectados e o status dos plug-ins, incluindo metadados da política de instalação/autenticação efetiva do mercado, proveniência da política de instalação remota (que pode ser nula) em `installPolicySource` (`WORKSPACE_SETTING` ou `IMPLICIT_CANONICAL_APP`), o mercado remoto `version` e o materializado localmente `localVersion`, quando disponível, o plug-in `availability` (`AVAILABLE` por padrão ou `DISABLED_BY_ADMIN` para plug-ins remotos bloqueados no upstream), entradas `marketplaceLoadErrors` do tipo “fail-open” para arquivos do mercado que não puderam ser analisados ou carregados, e `featuredPluginIds` do tipo “best-effort” para o mercado oficial com curadoria. Cada `PluginSummary` retornado pelos métodos plugin list, installed, read e share-list inclui `mustShowInstallationInterstitial`: os valores de serviços remotos preservam `true` ou `false`, enquanto plug-ins locais e respostas remotas que omitem a política retornam `null`. Os clientes devem adotar a política “fail-closed” quando o valor for `null`. Os clientes podem solicitar explicitamente os tipos de marketplace remotos `workspace-directory`, `shared-with-me` ou `created-by-me-remote`. Defina `forceRefetch: true` para ignorar os caches de catálogo remotos baseados em TTL para os marketplaces solicitados e aguardar dados atualizados; as entradas do cache são substituídas somente após uma busca bem-sucedida. Quando marketplaces locais estão incluídos, a solicitação também aguarda a reconciliação dos caches de plug-ins configurados antes que os resumos dos marketplaces sejam retornados. Na inicialização do servidor de aplicativos, os catálogos em cache existentes permanecem disponíveis para `plugin/list` enquanto são atualizados em segundo plano. `interface.category` usa a categoria do marketplace quando presente; caso contrário, recorre à categoria do manifesto do plug-in (**em desenvolvimento; não chame ainda a partir de clientes de produção**).
- `plugin/installed` — lista as linhas de plug-ins instalados, além de quaisquer nomes de plug-ins de sugestão de instalação local explicitamente solicitados, sem consultar o catálogo remoto mais abrangente. As linhas remotas incluem o valor nulo `installPolicySource`; as linhas locais retornam `null`. As superfícies de menção podem usar essa visão mais restrita quando precisarem de cargas úteis de menção a plug-ins, em vez de dados de descoberta de páginas de plug-ins (**em desenvolvimento; não chame ainda a partir de clientes de produção**).
- `plugin/read` — lê um plug-in por `marketplacePath` mais `pluginName`, retornando informações do marketplace, um `summary` no formato de lista, descrições do manifesto/metadados da interface e nomes de habilidades/hooks/aplicativos/servidores MCP incluídos no pacote. Os detalhes do plug-in remoto podem incluir resumos de tarefas agendadas do catálogo; `scheduledTasks: null` significa que os metadados não estão disponíveis, enquanto um array vazio indica que o catálogo não encontrou tarefas agendadas. Os detalhes do plug-in remoto expõem o `shareUrl` canônico fornecido pelo catálogo remoto quando disponível; ele é `null` para plug-ins locais ou quando o catálogo o omite. Esse campo é separado de `summary.shareContext`, que continua a descrever o estado de compartilhamento do usuário e do espaço de trabalho. Para plug-ins de espaço de trabalho de propriedade do usuário, `summary.shareContext.canPublishToWorkspace` informa se o usuário atual pode adicionar o plug-in ao diretório do espaço de trabalho; `plugin/share/save` retorna a mesma capacidade após a criação ou atualização de um compartilhamento, e os clientes devem encerrar a operação com falha quando qualquer um dos valores for `null`. Interfaces de habilidades remotas expõem `iconSmallUrl` e `iconLargeUrl` quando o catálogo fornece URLs de ícones. As habilidades de plug-ins retornadas incluem seu estado atual `enabled` após a filtragem da configuração local; os ganchos agrupados são retornados como resumos de declaração leves, indexados para correlação com `hooks/list`. Use o `appsNeedingAuth` de `plugin/install` para conduzir a autenticação pós-instalação e o `isAccessible` de `app/list` para determinar a acessibilidade atual do conector (**em desenvolvimento; não chame ainda a partir de clientes de produção**).
- `plugin/skill/read` — ler o Markdown das habilidades de plug-ins remotos sob demanda por meio de `remoteMarketplaceName`, `remotePluginId` e `skillName`. Isso permite que os clientes visualizem as habilidades de plug-ins remotos não instalados sem precisar baixar o pacote do plug-in.
- `skills/changed` — notificação emitida quando os arquivos de habilidades locais monitorados são alterados.
- `app/installed` — lê o estado de execução do conector instalado a partir do último snapshot confirmado, atualizando-o opcionalmente antes.
- `app/list` — listar os aplicativos disponíveis.
- `remoteControl/enable` — experimental; habilita o controle remoto para o processo atual do servidor de aplicativos e retorna um instantâneo do status atual do controle remoto. Por padrão, qualquer registro ausente é concluído antes da resposta, e a preferência é persistida para o escopo atual do cliente do servidor de aplicativos. Passe `ephemeral: true` para habilitar o controle remoto apenas para o processo atual, sem alterar a preferência persistida.
- `remoteControl/disable` — experimental; desativa o controle remoto para o processo atual do servidor de aplicativos e retorna o instantâneo do status atual do controle remoto. Por padrão, a preferência de desativação é mantida para o escopo atual do cliente do servidor de aplicativos. Passe `ephemeral: true` para desativar apenas para o processo atual, sem alterar a preferência armazenada. Isso não revoga os dispositivos controladores já cadastrados.
- `remoteControl/status/read` — experimental; lê o instantâneo do status atual do controle remoto. `status` é um dos valores `disabled`, `connecting`, `connected` ou `errored`; `serverName` é o nome da máquina local usado por este processo do servidor de aplicativos; `environmentId` é uma sequência de caracteres quando o servidor de aplicativos possui um registro atual e `null` quando esse registro é apagado, invalidado ou o controle remoto está desativado.
- `remoteControl/pairing/start` — experimental; inicia um objeto de emparelhamento de controle remoto de curta duração para o processo atual do servidor de aplicativos. Passe `manualCode: true` para solicitar também um código de emparelhamento manual. Retorna `pairingCode`, `manualPairingCode`, `environmentId` e segundos Unix `expiresAt`; o app-server não expõe intencionalmente o backend `serverId`.
- `remoteControl/pairing/status` — experimental; verifica se um controle remoto `pairingCode` ou `manualPairingCode` foi reivindicado. Passa exatamente um dos dois campos. Retorna `claimed`.
- `remoteControl/client/list` — experimental; lista os dispositivos controladores com acesso concedido a um ambiente. Passe `environmentId` e os parâmetros opcionais `cursor`, `limit` e `order`; retorna metadados do cliente orientados ao seletor, além de `nextCursor`. Essa operação de gerenciamento de contas conectadas funciona enquanto o relé local estiver desativado ou não estiver registrado.
- `remoteControl/client/revoke` — experimental; revoga a autorização de um dispositivo controlador para um ambiente. Aceita `environmentId` e `clientId`; retorna um objeto vazio. Essa operação de gerenciamento de contas conectadas funciona enquanto o relé local estiver desativado ou não estiver registrado.
- `remoteControl/status/changed` — notificação emitida quando o status do controle remoto ou o ID do ambiente visível ao cliente é alterado. `status` é um dos valores `disabled`, `connecting`, `connected` ou `errored`; `serverName` é o nome da máquina local usado por este processo do servidor de aplicativos; `environmentId` é uma sequência de caracteres quando o servidor de aplicativos possui um cadastro atual e `null` quando esse cadastro é apagado, invalidado ou o controle remoto é desativado. Clientes do servidor de aplicativos recém-inicializados sempre recebem o instantâneo do status atual.
- `skills/config/write` — gravar a configuração de habilidades no nível do usuário por nome ou caminho absoluto.
- `plugin/install` — instalar um plug-in a partir de uma entrada identificada no marketplace, rejeitando as entradas marcadas como indisponíveis para instalação, instalar MCPs, se houver, e retornar a política de autenticação efetiva do plug-in, além de quaisquer aplicativos que ainda precisem de autenticação (**em desenvolvimento; não chamar a partir de clientes de produção ainda**).
- `plugin/uninstall` — desinstalar um plug-in local por meio de `pluginId` no formulário `<plugin>@<marketplace>`, removendo seus arquivos em cache e limpando sua, ou desinstalar um plug-in remoto do ChatGPT pelo backend `pluginId`, encaminhando a desinstalação para o backend do plug-in do ChatGPT e removendo qualquer cache de plug-ins remotos baixados (**em desenvolvimento; não chame ainda a partir de clientes de produção**).
- `mcpServer/oauth/login` — inicia um login via OAuth para um servidor MCP configurado; passa `threadId` para resolver os servidores a partir dos plug-ins e do executor selecionados por essa thread e recebe um `authorization_url` seguido de `mcpServer/oauthLogin/completed` assim que o fluxo do navegador for concluído.
- `tool/requestUserInput` — apresentar ao usuário de 1 a 3 perguntas curtas por meio de uma chamada de ferramenta e retornar suas respostas (experimental).
- `config/mcpServer/reload` — recarrega a configuração do servidor MCP a partir do disco e agendou uma atualização para os threads carregados (aplicada na próxima vez que cada thread estiver ativo); retorna `{}`. Use isso após editar `config.toml` sem reiniciar o servidor.
- `mcpServerStatus/list` — lista os servidores MCP configurados com suas ferramentas, status de autenticação, informações do servidor, além de recursos/modelos de recursos para detalhes em `full`; suporta o parâmetro opcional `threadId` e paginação com cursor e limite. Se `threadId` for omitido, o servidor lê diretamente da configuração global mais recente. Se `detail` for omitido, o servidor usa `full` como padrão.
- `mcpServer/resource/read` — lê um recurso de um servidor MCP configurado por meio dos parâmetros opcionais `threadId`, `server` e `uri`, retornando o recurso text/blob `contents`. Se `threadId` for omitido, o servidor lê diretamente da configuração mais recente do MCP.
- `mcpServer/tool/call` — chamar uma ferramenta no servidor MCP configurado de uma thread por meio de `threadId`, `server`, `tool`, o opcional `arguments` e o opcional `_meta`, retornando o resultado da ferramenta MCP.
- `windowsSandbox/setupStart` — inicia a configuração da sandbox do Windows para o modo selecionado (`elevated` ou `unelevated`); aceita um parâmetro absoluto opcional `cwd` para direcionar a configuração a um espaço de trabalho específico, retorna `{ started: true }` imediatamente e, posteriormente, emite `windowsSandbox/setupCompleted`.
- `feedback/upload` — envia um relatório de feedback (classificação + motivo/registros opcionais, conversation_id e matriz de anexos opcionais `extraLogFiles`); retorna o ID do tópico de rastreamento.
- `config/read` — obter a configuração válida em tempo de execução após resolver a hierarquia de configurações e os requisitos gerenciados, incluindo valores opacos `desktop` armazenados em `config.toml`.
- `externalAgentConfig/detect` — detecta artefatos de agente externo passíveis de migração com `includeHome`, `cwds` opcional e um seletor `migrationSource` opcional. Valores omitidos, `null` ou não reconhecidos como fonte de migração mantêm o comportamento padrão. O campo opcional `source`, considerado obsoleto, continua sendo aceito por motivos de compatibilidade, mas não seleciona a fonte de migração. Cada item detectado inclui `cwd` (`null` para a página inicial), e migrações com vários itens podem incluir adicionalmente `details` estruturado com IDs de plug-ins, nomes de habilidades, memória, metadados de sessão ou nomes de outros artefatos.
- `externalAgentConfig/import` — aplica os itens de migração de agente externo selecionados, passando explicitamente `migrationItems` com `cwd` (`null` para a página inicial) e qualquer `details` retornado pela função detect. Passe o mesmo `migrationSource` opcional usado para detecção, para que o servidor leia da fonte correspondente; se omitido, `null` ou valores não reconhecidos mantêm o comportamento padrão. O `source` opcional identifica o produto que iniciou a importação, enquanto o `providerId` opcional e opaco atribui análises ao provedor selecionado por esse produto sem afetar a seleção da fonte de migração. A resposta confirma a fase de importação síncrona com um `importId`. Falhas de migração esperadas são relatadas como falhas por item, em vez de erros JSON-RPC; assim, o servidor ainda retorna esse `importId` e emite `externalAgentConfig/import/completed` com o mesmo ID assim que todo o trabalho síncrono e em segundo plano for concluído. A notificação de conclusão contém `itemTypeResults` no nível do tipo, com sucessos e falhas, incluindo mensagens brutas de falha para que o cliente as relate separadamente.
- `externalAgentConfig/import/readHistories` — ler os históricos de importação concluídos e os conectores candidatos detectados a partir dos históricos de sessões importados com sucesso. Os conectores candidatos incluem uma exibição normalizada `name`, o número de sessões importadas que utilizaram o conector e o campo de metadados de origem utilizado para a detecção.
- `config/value/write` — grava uma única chave/valor de configuração no arquivo config.toml do usuário no disco; caminhos pontilhados, como `desktop.someKey`, utilizam a mesma área de gravação genérica. Gravações que se sobrepõem a um requisito gerenciado são rejeitadas com `configRequirementReadonly`.
- `config/batchWrite` — aplica várias alterações de configuração de forma atômica ao arquivo config.toml do usuário no disco, com a opção `reloadUserConfig: true` para recarregar em tempo real os threads carregados, incluindo várias alterações `desktop.*`. Os padrões de modelo estático de sessão, esforço de raciocínio, esforço de raciocínio no modo de plano, camada de serviço e personalidade não recarregam threads existentes.
- `configRequirements/read` — obter as restrições de requisitos carregadas de `requirements.toml` e/ou do MDM (ou de `null`, caso nenhuma esteja configurada), incluindo valores gerenciados exatos (`sqliteHome`, `logDir`, `modelCatalogJson`, `checkForUpdateOnStartup`, `allowLoginShell`, `feedback.enabled` e `windowsSandboxPrivateDesktop`), listas de permissão (`allowedApprovalPolicies`, `allowedSandboxModes`, `allowedWebSearchModes`), o mapa de permissão do perfil de permissão em camadas (`allowedPermissionProfiles`), o padrão do perfil de permissão gerenciado (`defaultPermissions`), o bloqueio de gancho de ciclo de vida (`allowManagedHooksOnly`), a política de controle remoto (`allowRemoteControl`; `false` desativa forçadamente o controle remoto, enquanto `true` ou `null` preservam o comportamento existente), política de uso do computador (`computerUse`), política de uso do navegador (`browserUse.disableAutoReview`), valores de recursos fixados (`featureRequirements`), ganchos de ciclo de vida gerenciados (`hooks`, incluindo o `additionalContextLimit` opcional de cada manipulador de comando), `enforceResidency`, padrões gerenciados para novas threads (`models.newThread.model`, `models.newThread.modelReasoningEffort` e `models.newThread.serviceTier`) e restrições `network`, como permissões canônicas de domínio/soquete, além de `managedAllowedDomainsOnly` e `dangerFullAccessDenylistOnly`.

### Exemplo: Iniciar ou retomar um tópico

Crie um novo tópico quando precisar iniciar uma nova discussão sobre o Codex.

```json
{ "method": "thread/start", "id": 10, "params": {
    // Optionally set config settings. If not specified, will use the user's
    // current config settings.
    "model": "gpt-5.1-codex",
    "cwd": "/Users/me/project",
    "approvalPolicy": "never",
    "sandbox": "workspaceWrite",
    // Prefer experimental profile selection:
    // "permissions": ":workspace"
    // Experimental runtime roots for :workspace_roots materialization:
    // "runtimeWorkspaceRoots": ["/Users/me/project", "/Users/me/openai"],
    // Experimental capability roots selected by the hosting platform:
    "selectedCapabilityRoots": [
        {
            "id": "github@openai",
            "location": {
                "type": "environment",
                "environmentId": "workspace",
                "path": "/opt/cca/plugins/github"
            }
        }
    ],
    // Do not send both "sandbox" and "permissions".
    "personality": "friendly",
    "serviceName": "my_app_server_client", // optional metrics tag (`service_name`)
    "sessionStartSource": "startup", // optional: "startup" (default) or "clear"
    // Experimental: requires opt-in
    "dynamicTools": [
        {
            "type": "namespace",
            "name": "tickets",
            "description": "Ticket management tools",
            "tools": [
                {
                    "type": "function",
                    "name": "lookup_ticket",
                    "description": "Fetch a ticket by id",
                    "deferLoading": true,
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "id": { "type": "string" }
                        },
                        "required": ["id"]
                    }
                }
            ]
        }
    ],
} }
{ "id": 10, "result": {
    "thread": {
        "id": "thr_123",
        "preview": "",
        "modelProvider": "openai",
        "createdAt": 1730910000
    }
} }
{ "method": "thread/started", "params": { "thread": { … } } }
```

Os valores válidos para `personality` são `"friendly"`, `"pragmatic"` e `"none"`. Quando `"none"` é selecionado, o espaço reservado para a personalidade é substituído por uma string vazia.

Para continuar uma sessão armazenada, chame `thread/resume` com o `thread.id` que você registrou anteriormente. O formato da resposta corresponde a `thread/start`. Quando a sessão armazenada inclui o uso de tokens persistentes, o servidor emite `thread/tokenUsage/updated` imediatamente após a resposta, para que os clientes possam renderizar o uso restaurado antes do início da próxima rodada. Você também pode passar as mesmas substituições de configuração suportadas por `thread/start`, incluindo `approvalsReviewer`.

Por padrão, `thread/resume` inclui o histórico de turnos reconstruído em `thread.turns`. Clientes experimentais podem passar `excludeTurns: true` para retornar apenas os metadados da thread e o estado de retomada em tempo real; em seguida, devem chamar `thread/turns/list` separadamente caso queiram enviar o histórico de turnos em páginas pela rede. Nesse modo, o servidor também ignora a reprodução do `thread/tokenUsage/updated` restaurado, o que evita a reconstrução de turnos apenas para atribuir o uso histórico.

Os threads paginados mantêm o mesmo contrato de retomada que os threads legados. Uma retomada padrão materializa todo o histórico projetado em `thread.turns`; `excludeTurns: true` mantém essa matriz vazia e inclui `turnsBackwardsCursor` e `itemsBackwardsCursor` para o histórico durável visível no limite da retomada. Passe cada cursor diretamente para a API de lista correspondente com `sortDirection: "desc"`; a primeira página inclui a linha inicial do cursor, enquanto registros mais recentes chegam por meio de notificações em tempo real. Qualquer um dos cursores é `null` quando ainda não há nenhuma linha durável.

Apenas um processo do servidor de aplicativos pode manter uma thread paginada aberta para gravação por vez. Se outro processo já estiver controlando a thread, `thread/resume`, `thread/archive` e `thread/delete` falharão com o erro JSON-RPC `-32600`. O arquivamento e a exclusão também falham se outro processo estiver controlando qualquer thread descendente gerada. As solicitações somente de leitura permanecem disponíveis sem a retomada da thread.

Clientes experimentais que desejam a assinatura de atualização em tempo real, além de uma mudança de página em uma única viagem de ida e volta, podem passar `initialTurnsPage`. Ele aceita os mesmos controles `limit`, `sortDirection` e `itemsView` que `thread/turns/list`; controles omitidos utilizam seus valores padrão. A resposta inclui `initialTurnsPage` com `nextCursor` e `backwardsCursor` para paginação subsequente.

Por padrão, o `resume` utiliza os valores mais recentes de `model` e `reasoningEffort` persistidos associados à thread. Ao fornecer qualquer um dos valores `model`, `modelProvider`, `config.model` ou `config.model_reasoning_effort`, esse fallback persistido é desativado e, em vez disso, são utilizadas as substituições explícitas, juntamente com a resolução normal da configuração.

Exemplo:

```json
{ "method": "thread/resume", "id": 11, "params": {
    "threadId": "thr_123",
    "personality": "friendly"
} }
{ "id": 11, "result": { "thread": { "id": "thr_123", … } } }

{ "method": "thread/resume", "id": 12, "params": {
    "threadId": "thr_123",
    "excludeTurns": true
} }
{ "id": 12, "result": {
    "thread": { "id": "thr_123", "turns": [], … },
    "turnsBackwardsCursor": "turn-head-cursor-or-null",
    "itemsBackwardsCursor": "item-head-cursor-or-null"
} }

{ "method": "thread/resume", "id": 13, "params": {
    "threadId": "thr_123",
    "excludeTurns": true,
    "initialTurnsPage": {
        "limit": 20,
        "sortDirection": "desc",
        "itemsView": "summary"
    }
} }
{ "id": 13, "result": {
    "thread": { "id": "thr_123", "turns": [], … },
    "initialTurnsPage": {
        "data": [ ... ],
        "nextCursor": "older-turns-cursor-or-null",
        "backwardsCursor": "newer-turns-cursor-or-null"
    }
} }
```

Para criar uma ramificação a partir de uma sessão armazenada, chame `thread/fork` com o `thread.id`. Isso cria um novo ID de thread e emite uma notificação `thread/started` para ele. O `thread.sessionId` retornado identifica a raiz da árvore da sessão ativa atual. As threads raiz usam seu próprio `thread.id` como `thread.sessionId`; as threads armazenadas que não estão carregadas também informam seu próprio `thread.id`, pois retomar uma delas a torna a raiz de uma nova árvore de sessão ativa. Quando o histórico de origem inclui o uso de tokens persistentes, o servidor também emite `thread/tokenUsage/updated` para a nova thread imediatamente após a resposta. Se a thread de origem estiver em execução ativa, a bifurcação cria um instantâneo dela como se a vez atual tivesse sido interrompida primeiro. Passe `ephemeral: true` quando a bifurcação dever permanecer apenas na memória:

```json
{ "method": "thread/fork", "id": 12, "params": { "threadId": "thr_123", "ephemeral": true } }
{ "id": 12, "result": { "thread": { "id": "thr_456", "sessionId": "thr_456", … } } }
{ "method": "thread/started", "params": { "thread": { … } } }
```

Assim como `thread/resume`, os clientes experimentais podem passar `excludeTurns: true` para `thread/fork` a fim de retornar apenas os metadados da thread em `thread.turns` e o histórico da página com `thread/turns/list`. Nesse modo, o servidor ignora a reprodução do `thread/tokenUsage/updated` restaurado, o que evita que o caminho da bifurcação seja reconstruído apenas para atribuir o uso histórico. Bifurcações efêmeras de threads paginadas exigem `excludeTurns: true`.

### Exemplo: Listar tópicos (com paginação e filtros)

`thread/list` permite renderizar uma interface de usuário de histórico. Por padrão, os resultados são exibidos em ordem decrescente com `createdAt` (os mais recentes primeiro). Passe qualquer combinação de:

- `cursor` — sequência opaca de uma resposta anterior; omitir na primeira página.
- `limit` — se não for definido, o servidor usa um tamanho de página razoável por padrão.
- `sortKey` — `created_at` (padrão), `updated_at` ou `recency_at`.
- `recencyAt` é inicializado quando a thread é criada e avança quando uma rodada começa. Ao contrário de `updatedAt`, a saída em segundo plano e outras alterações persistentes não fazem com que ele avance.
- `sortDirection` — `desc` (padrão) ou `asc`.
- `modelProviders` — restringe os resultados a provedores específicos; se não for definido, for nulo ou for um array vazio, serão incluídos todos os provedores.
- `sourceKinds` — restringe os resultados a fontes específicas; omita ou utilize `[]` apenas para sessões interativas (`cli`, `vscode`).
- `archived` — quando `true`, listar apenas tópicos arquivados. Quando `false` ou `null`, listar tópicos não arquivados (padrão).
- `isPinned` — quando especificado, retorna apenas as threads cujo estado de fixação persistido corresponda ao valor solicitado; omita-o para incluir tanto as threads fixadas quanto as não fixadas.
- `cwd` — restringe os resultados aos threads cujo diretório de trabalho atual (cwd) da sessão corresponda exatamente a este caminho ou a um desses caminhos, quando for fornecida uma matriz. Os caminhos relativos são resolvidos em relação ao diretório de trabalho atual do processo do servidor de aplicativos antes da comparação.
- `useStateDbOnly` — quando `true`, retorne do banco de dados de estado sem analisar os rollouts JSONL para reparar os metadados. Omita ou passe `false` para preservar o comportamento padrão de análise e reparo.
- `searchTerm` — restringe os resultados aos tópicos cujo título extraído contenha essa subcadeia (diferencia maiúsculas de minúsculas).
- As respostas incluem `nextCursor` para continuar na mesma direção e `backwardsCursor` para ultrapassar como `cursor` ao dar ré `sortDirection`.
- As respostas incluem `agentNickname` e `agentRole` para os subagentes de threads gerados pelo AgentControl, quando disponíveis.

Exemplo:

```json
{ "method": "thread/list", "id": 20, "params": {
    "cursor": null,
    "limit": 25,
    "cwd": ["/Users/me/project", "/Users/me/project-worktree"],
    "sortKey": "created_at"
} }
{ "id": 20, "result": {
    "data": [
        { "id": "thr_a", "preview": "Create a TUI", "modelProvider": "openai", "createdAt": 1730831111, "updatedAt": 1730831111, "recencyAt": 1730831111, "status": { "type": "notLoaded" }, "agentNickname": "Atlas", "agentRole": "explorer" },
        { "id": "thr_b", "preview": "Fix tests", "modelProvider": "openai", "createdAt": 1730750000, "updatedAt": 1730750000, "recencyAt": 1730750000, "status": { "type": "notLoaded" } }
    ],
    "nextCursor": "opaque-token-or-null",
    "backwardsCursor": "opaque-token-or-null"
} }
```

Quando `nextCursor` for igual a `null`, você terá chegado à última página.

### Exemplo: Listar threads descendentes

Ative `capabilities.experimentalApi` durante a inicialização e, em seguida, use `thread/list` com `ancestorThreadId` para percorrer todos os descendentes gerados de uma thread a partir do estado persistido da aresta de geração. O próprio ancestral é excluído, e o `parentThreadId` de cada resultado permanece como seu pai imediato. Use `parentThreadId` em vez disso quando apenas filhos diretos forem desejados; enviar ambos os filtros é inválido. As threads de revisão e de guarda não são incluídas porque não participam do ciclo de vida da borda de geração. Quando `modelProviders` ou `sourceKinds` é omitido, as solicitações filtradas por relação incluem todos os tipos de provedores ou fontes, respectivamente. Filtros explícitos mantêm o comportamento normal de `thread/list`, incluindo o padrão “somente interativo” para uma lista `sourceKinds` vazia.

```json
{ "method": "thread/list", "id": 21, "params": {
    "ancestorThreadId": "00000000-0000-0000-0000-000000000100",
    "limit": 25
} }
{ "id": 21, "result": {
    "data": [
        { "id": "00000000-0000-0000-0000-000000000101", "parentThreadId": "00000000-0000-0000-0000-000000000100", "status": { "type": "notLoaded" } },
        { "id": "00000000-0000-0000-0000-000000000102", "parentThreadId": "00000000-0000-0000-0000-000000000101", "status": { "type": "notLoaded" } }
    ],
    "nextCursor": null,
    "backwardsCursor": null
} }
```

### Exemplo: Lista de threads carregados

`thread/loaded/list` retorna os IDs dos threads atualmente carregados na memória. Isso é útil quando você deseja verificar quais sessões estão ativas sem precisar examinar as versões em disco.

```json
{ "method": "thread/loaded/list", "id": 21 }
{ "id": 21, "result": {
    "data": ["thr_123", "thr_456"]
} }
```

### Exemplo: Acompanhar as alterações no status do tópico

`thread/status/changed` é emitido sempre que o status de um thread carregado muda depois de já ter sido apresentado ao cliente:

- Inclui o `threadId` e o novo `status`.
- O status pode ser `notLoaded`, `idle`, `systemError` ou `active` (sendo que `activeFlags` e `active` indicam que o sistema está em execução).
- `thread/start`, `thread/fork` e os tópicos de revisão independentes não emitem um `thread/status/changed` inicial separado; sua notificação `thread/started` já contém o `thread.status` atual.

```json
{
  "method": "thread/status/changed",
  "params": {
    "threadId": "thr_123",
    "status": { "type": "active", "activeFlags": [] }
  }
}
```

### Exemplo: Cancelar a inscrição em um tópico carregado

`thread/unsubscribe` remove a assinatura da conexão atual em um thread. O status da resposta pode ser um dos seguintes:

- `unsubscribed` quando a conexão foi ativada e agora foi removida.
- `notSubscribed` quando a conexão não estava associada àquela thread.
- `notLoaded` quando o thread não está carregado.

Se este fosse o último assinante, o servidor não liberaria a thread imediatamente. Ele libera a thread após ela ficar sem assinantes e sem atividade por 30 minutos, executa os ganchos `SessionEnd`, em seguida emite `thread/closed` e uma transição `thread/status/changed` para `notLoaded`.

O `SessionEnd` também é executado antes do arquivamento, da exclusão e do desligamento ordenado do servidor de aplicativos. Ele é executado apenas para threads raiz, não para `ThreadSpawn` filhas ou subagentes internos. Os ganchos têm caráter consultivo: sua saída não pode bloquear o desligamento. O tempo limite padrão é de um segundo; os tempos limite configurados têm limite máximo de três segundos; o `async: true` é executado de forma síncrona com um aviso de configuração; e a entrada do gancho sempre reporta `reason: "other"`. Os comparadores `SessionEnd` são avaliados com base nesse motivo.

```json
{ "method": "thread/unsubscribe", "id": 22, "params": { "threadId": "thr_123" } }
{ "id": 22, "result": { "status": "unsubscribed" } }
```

Posteriormente, após o tempo limite de descarga por inatividade:

```json
{ "method": "thread/status/changed", "params": {
    "threadId": "thr_123",
    "status": { "type": "notLoaded" }
} }
{ "method": "thread/closed", "params": { "threadId": "thr_123" } }
```

### Exemplo: Ler um tópico

Use `thread/read` para recuperar um thread armazenado pelo ID sem retomá-lo. Passe `includeTurns` quando quiser que o histórico da thread seja carregado em `thread.turns`. A thread retornada inclui `parentThreadId`, `agentNickname` e `agentRole` para threads de subagentes, quando disponíveis.

Os threads paginados suportam apenas leituras de metadados; `includeTurns: true` não é compatível com eles.

```json
{ "method": "thread/read", "id": 22, "params": { "threadId": "thr_123" } }
{ "id": 22, "result": {
    "thread": { "id": "thr_123", "status": { "type": "notLoaded" }, "turns": [] }
} }
```

```json
{ "method": "thread/read", "id": 23, "params": { "threadId": "thr_123", "includeTurns": true } }
{ "id": 23, "result": {
    "thread": { "id": "thr_123", "status": { "type": "notLoaded" }, "turns": [ ... ] }
} }
```

### Exemplo: Listar voltas do fio (experimental)

Use `thread/turns/list` com `capabilities.experimentalApi = true` para percorrer o histórico de turnos de um thread armazenado sem retomá-lo. Por padrão, os resultados são classificados em ordem decrescente, de modo que os clientes possam começar pelo presente e buscar turnos mais antigos com `nextCursor`. A resposta também inclui `backwardsCursor`; passe-o como `cursor` em uma solicitação posterior com `sortDirection: "asc"` para buscar turnos mais recentes do que o primeiro item da página anterior.

Cada valor `Turn` retornado inclui `itemsView`, que informa aos clientes se a matriz `items` foi omitida intencionalmente (`notLoaded`), contém apenas itens de resumo (`summary`), ou contém todos os itens disponíveis no histórico persistido do servidor de aplicativos (`full`). Passe `itemsView` para escolher o nível de detalhe retornado; se `itemsView` for omitido, o padrão será `"summary"`.

Os threads paginados suportam as mesmas visualizações. A visualização `full` deles é materializada a partir da projeção do item paginado antes que o servidor de aplicativos retorne a página seguinte.

```json
{ "method": "thread/turns/list", "id": 24, "params": {
    "threadId": "thr_123",
    "limit": 50,
    "sortDirection": "desc",
    "itemsView": "summary"
} }
{ "id": 24, "result": {
    "data": [ ... ],
    "nextCursor": "older-turns-cursor-or-null",
    "backwardsCursor": "newer-turns-cursor-or-null"
} }
```

`thread/items/list` páginas com itens salvos em um tópico, opcionalmente filtrados para uma rodada:

```json
{ "method": "thread/items/list", "id": 25, "params": {
    "threadId": "thr_123",
    "turnId": "turn_456",
    "limit": 100,
    "sortDirection": "asc"
} }
```

Cada entrada retornada inclui o `turnId` que a contém e seu `item` completo, para que os clientes possam agrupar
divide as páginas não filtradas em turnos. Omita `turnId` ou passe `null` para os itens da página em toda a thread. Item
Os cursores podem ser reutilizados com ou sem `turnId`; o filtro não altera o escopo do cursor.
Os armazenamentos de threads que não implementam a paginação de itens retornam JSON-RPC `-32601` com a mensagem
`thread/items/list is not supported yet`.

`thread/searchOccurrences` pesquisa um tópico paginado sem reproduzir sua sequência de eventos. Ele retorna
ocorrências na ordem cronológica das mensagens de todos os usuários visíveis, incluindo as de orientação
mensagens e mensagens finais do assistente. `snippetMatchRange` utiliza
Os deslocamentos UTF-16 dentro de `snippet` e `turnCursor` podem ser passados diretamente para `thread/turns/list`
para carregar a curva correspondente.

```json
{ "method": "thread/searchOccurrences", "id": 26, "params": {
    "threadId": "thr_123",
    "searchTerm": "needle",
    "limit": 50
} }
{ "id": 26, "result": {
    "data": [{
        "turnId": "turn_456",
        "itemId": "item_789",
        "snippet": "The needle is here.",
        "snippetMatchRange": { "start": 4, "end": 10 },
        "turnCursor": "opaque-inclusive-turn-cursor"
    }],
    "nextCursor": null
} }
```

### Exemplo: Atualizar metadados de threads armazenados

Use `thread/metadata/update` para corrigir metadados armazenados no SQLite de uma thread sem retomá-la. Atualmente, isso oferece suporte a `gitInfo` persistido; os campos omitidos permanecem inalterados, enquanto `null` explícito limpa um valor armazenado.

```json
{ "method": "thread/metadata/update", "id": 24, "params": {
    "threadId": "thr_123",
    "gitInfo": { "branch": "feature/sidebar-pr" }
} }
{ "id": 24, "result": {
    "thread": {
        "id": "thr_123",
        "gitInfo": { "sha": null, "branch": "feature/sidebar-pr", "originUrl": null }
    }
} }

{ "method": "thread/metadata/update", "id": 25, "params": {
    "threadId": "thr_123",
    "gitInfo": { "branch": null }
} }
{ "id": 25, "result": {
    "thread": {
        "id": "thr_123",
        "gitInfo": null
    }
} }
```

Experimental: use `thread/memoryMode/set` para definir se uma thread continua elegível para a geração futura de memória.

```json
{ "method": "thread/memoryMode/set", "id": 26, "params": {
    "threadId": "thr_123",
    "mode": "disabled"
} }
{ "id": 26, "result": {} }
```

Experimental: use `memory/reset` para limpar artefatos da memória local e os dados da fase de memória baseada em SQLite para a página inicial atual do Codex. Isso preserva os modos de memória existentes das threads; use `thread/memoryMode/set` separadamente quando a elegibilidade futura de memória de uma thread precisar ser alterada.

```json
{ "method": "memory/reset", "id": 27 }
{ "id": 27, "result": {} }
```

### Exemplo: Definir e atualizar uma meta de discussão

Use `thread/goal/set` para criar ou atualizar a meta atual de uma thread materializada. Os clientes podem definir `budgetLimited` quando param porque o orçamento de tokens se esgotou ou está quase esgotado, `blocked` quando o progresso está aguardando intervenção externa e `usageLimited` quando a disponibilidade de uso impede a continuação do trabalho. O sistema também define `budgetLimited` quando a contabilidade ultrapassa um orçamento de tokens configurado e `usageLimited` quando um turno termina devido a um erro de limite rígido de uso.

```json
{ "method": "thread/goal/set", "id": 27, "params": {
    "threadId": "thr_123",
    "objective": "Keep improving the benchmark until p95 latency is under 120ms",
    "tokenBudget": 200000
} }
{ "id": 27, "result": { "goal": {
    "threadId": "thr_123",
    "objective": "Keep improving the benchmark until p95 latency is under 120ms",
    "status": "active",
    "tokenBudget": 200000,
    "tokensUsed": 0,
    "timeUsedSeconds": 0,
    "createdAt": 1776272400,
    "updatedAt": 1776272400
} } }
{ "method": "thread/goal/updated", "params": { "threadId": "thr_123", "goal": {
    "threadId": "thr_123",
    "objective": "Keep improving the benchmark until p95 latency is under 120ms",
    "status": "active",
    "tokenBudget": 200000,
    "tokensUsed": 0,
    "timeUsedSeconds": 0,
    "createdAt": 1776272400,
    "updatedAt": 1776272400
} } }
```

```json
{ "method": "thread/goal/set", "id": 28, "params": {
    "threadId": "thr_123",
    "status": "blocked"
} }
{ "id": 28, "result": { "goal": {
    "threadId": "thr_123",
    "objective": "Keep improving the benchmark until p95 latency is under 120ms",
    "status": "blocked",
    "tokenBudget": 200000,
    "tokensUsed": 10000,
    "timeUsedSeconds": 60,
    "createdAt": 1776272400,
    "updatedAt": 1776272460
} } }
```

Use `thread/goal/get` para ler a meta atual sem alterá-la.

```json
{ "method": "thread/goal/get", "id": 29, "params": { "threadId": "thr_123" } }
{ "id": 29, "result": { "goal": null } }
```

Use `thread/goal/clear` para remover a meta atual.

```json
{ "method": "thread/goal/clear", "id": 30, "params": { "threadId": "thr_123" } }
{ "id": 30, "result": { "cleared": true } }
{ "method": "thread/goal/cleared", "params": { "threadId": "thr_123" } }
```

### Exemplo: Arquivar um tópico

Use `thread/archive` para mover o rollout persistido (armazenado como um arquivo JSONL no disco) para o diretório de sessões arquivadas e tentar mover quaisquer rollouts de threads descendentes criadas.

```json
{ "method": "thread/archive", "id": 21, "params": { "threadId": "thr_b" } }
{ "id": 21, "result": {} }
{ "method": "thread/archived", "params": { "threadId": "thr_b" } }
```

Um tópico arquivado não aparecerá em `thread/list`, a menos que `archived` esteja definido como `true`.

### Exemplo: Excluir um tópico

Use `thread/delete` para excluir definitivamente um tópico e os tópicos descendentes gerados a partir dele. Os arquivos de rollout existentes e os metadados associados devem ser removidos para que a solicitação seja bem-sucedida; arquivos de rollout ausentes são tratados como se já tivessem sido excluídos.

```json
{ "method": "thread/delete", "id": 23, "params": { "threadId": "thr_b" } }
{ "id": 23, "result": {} }
{ "method": "thread/deleted", "params": { "threadId": "thr_b" } }
```

### Exemplo: Desarquivar um tópico

Use `thread/unarchive` para mover um rollout arquivado de volta para o diretório de sessões.

```json
{ "method": "thread/unarchive", "id": 24, "params": { "threadId": "thr_b" } }
{ "id": 24, "result": { "thread": { "id": "thr_b" } } }
{ "method": "thread/unarchived", "params": { "threadId": "thr_b" } }
```

### Exemplo: Acionar a compactação de threads

Use `thread/compact/start` para acionar a compactação manual do histórico de um thread. A solicitação retorna imediatamente com `{}`.

O progresso é transmitido como notificações padrão `turn/*` e `item/*` no mesmo `threadId`. Os clientes devem esperar um único item de compactação:

- `item/started` com `item: { "type": "contextCompaction", ... }`
- `item/completed` com o mesmo ID de item `contextCompaction`

Enquanto a compactação estiver em andamento, o thread está, na prática, em uma espera; portanto, os clientes devem exibir o progresso na interface do usuário com base nas notificações.

```json
{ "method": "thread/compact/start", "id": 25, "params": { "threadId": "thr_b" } }
{ "id": 25, "result": {} }
```

### Exemplo: Executar um comando do shell em uma thread

Use `thread/shellCommand` para o fluxo de trabalho TUI `!`. A solicitação retorna imediatamente com `{}`.
Essa API é executada fora do ambiente de sandbox, com acesso total; ela não herda a thread
política de sandbox.

Se o thread já tiver um turno ativo, o comando é executado como uma ação auxiliar nesse turno. Nesse caso, o progresso é transmitido por meio de notificações padrão `item/*` no turno existente, e a saída formatada é inserida no fluxo de mensagens do turno:

- `item/started` com `item: { "type": "commandExecution", "source": "userShell", ... }`
- zero ou mais `item/commandExecution/outputDelta`
- `item/completed` com o mesmo ID de item `commandExecution`

Se o thread ainda não tiver uma rodada ativa, o servidor inicia uma rodada independente para o comando do shell. Nesse caso, os clientes devem esperar:

- `turn/started`
- `item/started` com `item: { "type": "commandExecution", "source": "userShell", ... }`
- zero ou mais `item/commandExecution/outputDelta`
- `item/completed` com o mesmo ID de item `commandExecution`
- `turn/completed`

```json
{ "method": "thread/shellCommand", "id": 26, "params": { "threadId": "thr_b", "command": "git status --short" } }
{ "id": 26, "result": {} }
```

### Exemplo: Iniciar um turno (enviar entrada do usuário)

As rodadas anexam a entrada do usuário (texto, imagens ou áudio) a um tópico e acionam a geração do Codex. O campo `input` é uma lista de uniões discriminadas:

- `{"type":"text","text":"Explain this diff"}`
- `{"type":"image","url":"data:image/png;base64,…"}`
- `{"type":"localImage","path":"/tmp/screenshot.png"}`
- `{"type":"audio","url":"data:audio/wav;base64,…"}`
- `{"type":"localAudio","path":"/tmp/recording.mp3"}`

A variante `image` aceita URLs de dados embutidos. URLs de imagens remotas via HTTP(S) são rejeitadas; use um URL de dados ou `localImage` em vez disso.
A variante `audio` aceita URLs de dados. Outros esquemas de URL são rejeitados. A variante `localAudio` lê arquivos locais nos formatos wav, mp3, m4a, webm e ogg e os converte em URLs de dados antes da solicitação à API de Respostas.

Opcionalmente, você pode especificar substituições de configuração na nova rodada. Se especificadas, essas configurações se tornam o padrão para as rodadas subsequentes na mesma thread. `outputSchema` se aplica apenas à rodada atual. O parâmetro experimental `environments` tem escopo de turno: omita-o para herdar os ambientes fixos da thread, passe `[]` para executar o turno sem ambientes ou passe IDs de ambiente explícitos para substituir a seleção fixa apenas para este turno.

`approvalsReviewer` aceita:

- `"user"` — padrão. Analise os pedidos de aprovação diretamente no cliente.
- `"auto_review"` — encaminha as solicitações de aprovação de rota a um subagente cuidadosamente configurado, que reúne o contexto relevante e aplica uma estrutura de decisão baseada em risco antes de aprovar ou negar a solicitação. O valor legado `"guardian_subagent"` ainda é aceito por motivos de compatibilidade.

```json
{ "method": "turn/start", "id": 30, "params": {
    "threadId": "thr_123",
    "clientUserMessageId": "client_msg_123",
    "input": [ { "type": "text", "text": "Run tests" } ],
    // Below are optional config overrides
    "cwd": "/Users/me/project",
    // Experimental: turn-scoped environment selection.
    "environments": [
        { "environmentId": "local", "cwd": "/Users/me/project" }
    ],
    "approvalPolicy": "unlessTrusted",
    "sandboxPolicy": {
        "type": "workspaceWrite",
        "writableRoots": ["/Users/me/project"],
        "networkAccess": true
    },
    // Prefer experimental profile selection:
    // "permissions": ":workspace"
    // Experimental runtime roots for :workspace_roots materialization:
    // "runtimeWorkspaceRoots": ["/Users/me/project", "/Users/me/openai"],
    // Do not send both "sandboxPolicy" and "permissions".
    "model": "gpt-5.1-codex",
    "effort": "medium",
    "summary": "concise",
    "personality": "friendly",
    // Optional JSON Schema to constrain the final assistant message for this turn.
    "outputSchema": {
        "type": "object",
        "properties": { "answer": { "type": "string" } },
        "required": ["answer"],
        "additionalProperties": false
    }
} }
{ "id": 30, "result": { "turn": {
    "id": "turn_456",
    "status": "inProgress",
    "items": [],
    "error": null
} } }
```

### Exemplo: Iniciar um turno (ativar uma habilidade)

Chame uma habilidade explicitamente incluindo `$<skill-name>` na entrada de texto e adicionando um item de entrada `skill` ao lado dela.

```json
{ "method": "turn/start", "id": 33, "params": {
    "threadId": "thr_123",
    "input": [
        { "type": "text", "text": "$skill-creator Add a new skill for triaging flaky CI and include step-by-step usage." },
        { "type": "skill", "name": "skill-creator", "path": "/Users/me/.codex/skills/skill-creator/SKILL.md" }
    ]
} }
{ "id": 33, "result": { "turn": {
    "id": "turn_457",
    "status": "inProgress",
    "items": [],
    "error": null
} } }
```

### Exemplo: Iniciar um turno (abrir um aplicativo)

Para chamar um aplicativo, inclua `$<app-slug>` no campo de entrada de texto e adicione um item de entrada `mention` com o ID do aplicativo no formulário `app://<connector-id>`.

```json
{ "method": "turn/start", "id": 34, "params": {
    "threadId": "thr_123",
    "input": [
        { "type": "text", "text": "$demo-app Summarize the latest updates." },
        { "type": "mention", "name": "Demo App", "path": "app://demo-app" }
    ]
} }
{ "id": 34, "result": { "turn": {
    "id": "turn_458",
    "status": "inProgress",
    "items": [],
    "error": null
} } }
```

### Exemplo: Iniciar um turno (chamar um plug-in)

Para chamar um plug-in, inclua um token de referência da interface do usuário, como `@sample`, no campo de texto e adicione um item de entrada `mention` com o caminho exato `plugin://<plugin-name>@<marketplace-name>` retornado por `plugin/installed` ou `plugin/list`.

```json
{ "method": "turn/start", "id": 35, "params": {
    "threadId": "thr_123",
    "input": [
        { "type": "text", "text": "@sample Summarize the latest updates." },
        { "type": "mention", "name": "Sample Plugin", "path": "plugin://sample@test" }
    ]
} }
{ "id": 35, "result": { "turn": {
    "id": "turn_459",
    "status": "inProgress",
    "items": [],
    "error": null
} } }
```

### Exemplo: Inserir itens de histórico não processados

Use `thread/inject_items` para anexar itens pré-criados da API de Respostas ao histórico de prompts de um thread carregado, sem iniciar uma rodada do usuário. Esses itens são armazenados no rollout e incluídos nas solicitações subsequentes ao modelo. Quaisquer itens `input_image` devem usar URLs de dados embutidos; URLs remotas de imagens HTTP(S) são rejeitadas.

```json
{ "method": "thread/inject_items", "id": 36, "params": {
    "threadId": "thr_123",
    "items": [
        {
            "type": "message",
            "role": "assistant",
            "content": [{ "type": "output_text", "text": "Previously computed context." }]
        }
    ]
} }
{ "id": 36, "result": {} }
```

### Exemplo: Iniciar o RealTime com WebRTC

Use `thread/realtime/start` com `transport.type: "webrtc"` quando um navegador ou webview for o proprietário do `RTCPeerConnection` e o servidor do aplicativo deva criar a sessão em tempo real no lado do servidor. O transporte `sdp` deve ser o SDP de oferta gerado por `RTCPeerConnection.createOffer()`, e não uma string SDP escrita manualmente ou minimalista.

A oferta deve incluir as seções de mídia que o cliente deseja negociar. Para o fluxo padrão da interface do usuário em tempo real, crie a trilha de áudio/transceptor e o canal de dados `oai-events` antes de chamar `createOffer()`:

```javascript
const pc = new RTCPeerConnection();

audioElement.autoplay = true;
pc.ontrack = (event) => {
  audioElement.srcObject = event.streams[0];
};

const mediaStream = await navigator.mediaDevices.getUserMedia({ audio: true });
pc.addTrack(mediaStream.getAudioTracks()[0], mediaStream);
pc.createDataChannel("oai-events");

const offer = await pc.createOffer();
await pc.setLocalDescription(offer);
```

Em seguida, envie `offer.sdp` para o servidor de aplicativos. O Core utiliza `experimental_realtime_ws_backend_prompt` para as instruções do backend e o ID da conversa da thread como identificador padrão da sessão da API em tempo real. Esse valor `realtimeSessionId` refere-se à sessão da API em tempo real upstream, e não a um ID de sessão/grupo de threads do Codex. A resposta inicial é `{}`; o SDP da resposta remota chega posteriormente como `thread/realtime/sdp` e deve ser passado para `setRemoteDescription()`:

```json
{ "method": "thread/realtime/start", "id": 40, "params": {
    "threadId": "thr_123",
    "outputModality": "audio",
    "prompt": "You are on a call.",
    "realtimeSessionId": null,
    "transport": { "type": "webrtc", "sdp": "v=0\r\no=..." }
} }
{ "id": 40, "result": {} }
{ "method": "thread/realtime/sdp", "params": {
    "threadId": "thr_123",
    "sdp": "v=0\r\no=..."
} }
```

Omita `prompt` para usar o prompt padrão do backend em tempo real do Codex. Envie `prompt: null` ou
`prompt: ""` quando a sessão deve iniciar sem aquele prompt padrão do backend.
Os clientes também podem passar `model` em `thread/realtime/start` para selecionar um
configuração diferente da sessão em tempo real sem alterar a configuração da thread ou do usuário.
Os clientes podem passar `version` para selecionar o protocolo em tempo real para esta sessão
apenas. O WebRTC utiliza AVAS e é compatível com o Bidi `"v1"` tradicional ou com o Bidi sem moldura
`"v3"`; O Realtime Voice `"v2"` é rejeitado pelo WebRTC.
Passe `includeStartupContext: false` para ignorar o contexto de inicialização do Codex para isso
sessão, mantendo o prompt do backend selecionado.
Na versão V3, os clientes podem passar `initialItems` para inicializar a sessão com o texto completo
mensagens antes do início da entrada ao vivo:

```json
{
  "initialItems": [
    {
      "role": "developer",
      "text": "Relevant user memory: prefers concise technical answers."
    },
    {
      "role": "user",
      "text": "Continue from the prior discussion."
    }
  ]
}
```

Cada item requer um `role` de `"user"`, `"developer"` ou `"assistant"` e um
`text` string. O Core serializa esses valores como Frameless Bidi `session.initial_items`
durante a inicialização da sessão inicial (incluindo a criação da chamada WebRTC).
As solicitações estão limitadas a 128 itens, com uma estimativa de 8.192 tokens de texto por item, e
8.192 tokens de texto estimados em todos os itens.
A omissão de `initialItems`, ou a passagem de uma lista vazia, preserva o valor anterior
carga útil da sessão e comportamento de inicialização. As versões V1 e V2 rejeitam valores não vazios
`initialItems`.
Passe `clientManagedHandoffs: true` para suprimir as transferências automáticas de resposta do Codex
e itens. O cliente pode então escolher quais atualizações serão entregues com
`thread/realtime/appendText` ou `thread/realtime/appendSpeech`.
Passe `codexResponsesAsItems: true` para inserir respostas automáticas do Codex com
`conversation.item.create` em vez da saída falada padrão do protocolo
caminho. Ao usar esse modo, `codexResponseItemPrefix` pode anteceder um curto
instruções do experimento para cada item de resposta automática do Codex. Omitir
`codexResponsesAsItems`, ou passe `false`, para manter a opção de leitura em voz alta padrão
comportamento. No V3, as transferências automáticas são definidas por padrão como
`codexResponseHandoffMode: "thinking"`, que omite o acréscimo de contexto `channel`
para cada resposta automática. Passe `"commentary"` para direcionar todas as respostas para
comentário, ou `"bemTags"` para redirecionar as tags de comentário BEM para `commentary`, final
tags para `speakable` e tags de análise para `commentary`. Saída BEM não analisável
volta a `speakable`. O roteamento BEM lê o envelope bruto e o preserva
no texto anexo para o modelo front-end. Com `"bemTags"`, os clientes podem passar
`codexResponseHandoffChannelPrefixes` para substituir os prefixos aceitos para
canais individuais, por exemplo
`{"analysis":["[THINKING]"],"commentary":["[PROGRESS]","[UPDATE]"],"final":["[DONE]"]}`.
Os canais omitidos mantêm os códigos fixos `[ANALYSIS]`, `[COMMENTARY]` e `[FINAL]`
valores padrão. Isso
Essa configuração não tem efeito sobre V1 ou V2. As transferências de V3 nunca antepõem o rótulo legado `"Agent Final Message"`. Versões mais antigas
os clientes podem continuar a enviar o campo `codexResponseHandoffPrefix` removido; o
O servidor ignora campos de solicitação desconhecidos.
Ligar
`thread/realtime/appendText` para acrescentar itens de texto em tempo real fornecidos pelo aplicativo, ou
`thread/realtime/appendSpeech` quando o aplicativo determina que deve haver uma atualização em tempo real
dito.

```javascript
await pc.setRemoteDescription({
  type: "answer",
  sdp: notification.params.sdp,
});
```

### Exemplo: Interromper um turno ativo

Você pode cancelar um Turno em andamento com `turn/interrupt`.

```json
{ "method": "turn/interrupt", "id": 31, "params": {
    "threadId": "thr_123",
    "turnId": "turn_456"
} }
{ "id": 31, "result": {} }
```

O servidor solicita o cancelamento do turno ativo e, em seguida, emite um evento `turn/completed` com `status: "interrupted"`. Isso não encerra os terminais em segundo plano; use `thread/backgroundTerminals/clean` quando quiser interromper explicitamente esses shells. Utilize o evento `turn/completed` para saber quando a interrupção do turno foi concluída.

### Exemplo: Limpar os terminais de fundo

Use `thread/backgroundTerminals/clean` para encerrar todos os terminais em segundo plano em execução associados a uma thread. Esse método é experimental e requer `capabilities.experimentalApi = true`.

```json
{ "method": "thread/backgroundTerminals/clean", "id": 35, "params": {
    "threadId": "thr_123"
} }
{ "id": 35, "result": {} }
```

### Exemplo: Listar e encerrar terminais em segundo plano

Use `thread/backgroundTerminals/list` para inspecionar terminais em segundo plano em execução associados a um thread carregado. O segmento `backgroundTerminals` segue intencionalmente o método `thread/backgroundTerminals/clean` existente. O valor `processId` retornado é o ID do processo do servidor de aplicativos; os metadados do sistema operacional do host podem ser nulos. A solicitação aceita os campos padrão de paginação `cursor` e `limit`. Quando `nextCursor` for diferente de nulo, passe-o como `cursor` para buscar a próxima página.

```json
{ "method": "thread/backgroundTerminals/list", "id": 36, "params": { "threadId": "thr_123" } }
{ "id": 36, "result": { "data": [
    {
        "itemId": "item_456",
        "processId": "42",
        "command": "python3 -m http.server",
        "cwd": "/workspace",
        "osPid": null,
        "cpuPercent": null,
        "rssKb": null
    }
], "nextCursor": null } }
```

Use `thread/backgroundTerminals/terminate` para encerrar um terminal em segundo plano que esteja em execução com o comando `processId`.

```json
{ "method": "thread/backgroundTerminals/terminate", "id": 37, "params": { "threadId": "thr_123", "processId": "42" } }
{ "id": 37, "result": { "terminated": true } }
```

### Exemplo: Fazer uma curva ativa

Use `turn/steer` para acrescentar uma entrada adicional do usuário ao turno regular atualmente ativo. Isso faz
não emite `turn/started` e não aceita substituições nas configurações de thread.

```json
{ "method": "turn/steer", "id": 32, "params": {
    "threadId": "thr_123",
    "clientUserMessageId": "client_msg_124",
    "input": [ { "type": "text", "text": "Actually focus on failing tests first." } ],
    "expectedTurnId": "turn_456"
} }
{ "id": 32, "result": { "turnId": "turn_456" } }
```

É necessário `expectedTurnId`. Se não houver um turno ativo, `expectedTurnId` não corresponde ao
curva ativa, ou o tipo de curva ativa não permite a mudança de direção na mesma curva (por exemplo, consulte ou
compactação manual), a solicitação falha com um erro `invalid request`.

### Exemplo: Solicitar uma revisão de código

Use `review/start` para executar o revisor do Codex no projeto atualmente baixado. A solicitação recebe o ID da thread, além de um `target` que descreve o que deve ser revisado:

- `{"type":"uncommittedChanges"}` — arquivos marcados, não marcados e não rastreados.
- `{"type":"baseBranch","branch":"main"}` — comparação com o upstream do branch fornecido (consulte o prompt para obter as instruções exatas `git merge-base`/`git diff` que o Codex executará).
- `{"type":"commit","sha":"abc1234","title":"Optional subject"}` — revisar um commit específico.
- `{"type":"custom","instructions":"Free-form reviewer instructions"}` — mensagem de fallback equivalente à solicitação de revisão manual tradicional.
- `delivery` (`"inline"` ou `"detached"`, padrão `"inline"`) — onde a revisão é executada:
  - `"inline"`: executa a revisão como um novo turno no tópico existente. O valor `reviewThreadId` da resposta é igual ao `threadId` original, e nenhuma nova notificação `thread/started` é emitida.
  - `"detached"`: cria um novo tópico de revisão a partir da conversa principal e executa a revisão nesse tópico. O valor `reviewThreadId` da resposta é o ID desse novo tópico de revisão, e o servidor emite uma notificação `thread/started` para ele antes de transmitir os itens de revisão.

Exemplo de solicitação/resposta:

```json
{ "method": "review/start", "id": 40, "params": {
    "threadId": "thr_123",
    "delivery": "inline",
    "target": { "type": "commit", "sha": "1234567deadbeef", "title": "Polish tui colors" }
} }
{ "id": 40, "result": {
    "turn": {
        "id": "turn_900",
        "status": "inProgress",
        "items": [
            { "type": "userMessage", "id": "turn_900", "content": [ { "type": "text", "text": "Review commit 1234567: Polish tui colors" } ] }
        ],
        "error": null
    },
    "reviewThreadId": "thr_123"
} }
```

Para uma revisão independente, use `"delivery": "detached"`. A resposta tem o mesmo formato, mas `reviewThreadId` será o ID do novo tópico de revisão (diferente do `threadId` original). O servidor também emite uma notificação `thread/started` para esse novo tópico antes de transmitir o turno de revisão. Internamente, trata-se de um tópico e turno bifurcados normais, cujo prompt menciona a habilidade `$review-agent` incluída; portanto, aplicam-se os comportamentos normais de direção de turno, ferramentas, permissões e transmissão de itens.

A análise independente não é suportada quando a thread pai é paginada.

Para uma revisão em linha, o Codex exibe a notificação habitual `turn/started`, seguida por um `item/started`
com um item `enteredReviewMode` para que os clientes possam acompanhar o progresso:

```json
{
  "method": "item/started",
  "params": {
    "item": {
      "type": "enteredReviewMode",
      "id": "turn_900",
      "review": "current changes"
    }
  }
}
```

Quando o revisor terminar, o servidor emite `item/started` e `item/completed`
que contenha um item `exitedReviewMode` com o texto da revisão final:

```json
{
  "method": "item/completed",
  "params": {
    "item": {
      "type": "exitedReviewMode",
      "id": "turn_900",
      "review": "Looks solid overall...\n\n- Prefer Stylize helpers — app.rs:10-20\n  ..."
    }
  }
}
```

A string `review` é um texto simples que já inclui a explicação geral, além de uma lista com marcadores para cada resultado estruturado (correspondente a `ThreadItem::ExitedReviewMode` no esquema gerado). Use essa notificação para exibir a saída do revisor no seu cliente.

### Exemplo: Execução única de um comando

Execute um comando independente (vetor argv) na área isolada do servidor sem criar uma thread ou um turn:

```json
{ "method": "command/exec", "id": 32, "params": {
    "command": ["ls", "-la"],
    "processId": "ls-1",                           // optional string; required for streaming and ability to terminate the process
    "cwd": "/Users/me/project",                    // optional; defaults to server cwd
    "env": { "FOO": "override" },                  // optional; merges into the server env and overrides matching names
    "size": { "rows": 40, "cols": 120 },           // optional; PTY size in character cells, only valid with tty=true
    "permissionProfile": ":workspace",             // optional profile id; defaults to user config
    "outputBytesCap": 1048576,                     // optional; per-stream capture cap
    "disableOutputCap": false,                     // optional; cannot be combined with outputBytesCap
    "timeoutMs": 10000,                            // optional; ms timeout; defaults to server timeout
    "disableTimeout": false                        // optional; cannot be combined with timeoutMs
} }
{ "id": 32, "result": {
    "exitCode": 0,
    "stdout": "...",
    "stderr": ""
} }
```

- Prefira usar `process/spawn` quando desejar uma API de execução de processos explicitamente fora do sandbox, com confirmação imediata da criação do processo, controle baseado em identificadores, notificações de saída e uma notificação de encerramento.
- Para clientes que já estejam em ambiente de sandbox externo, defina o parâmetro legado `sandboxPolicy` como `{"type":"externalSandbox","networkAccess":"enabled"}` (ou omita `networkAccess` para mantê-lo restrito). O Codex não aplicará seu próprio ambiente de sandbox neste modo; ele informa ao modelo que possui acesso total ao sistema de arquivos e transmite o estado `networkAccess` por meio de `environment_context`.

Notas:

- Matrizes vazias `command` são rejeitadas.
- Prefira `permissionProfile` para substituições de permissão de comando. Ele seleciona um perfil ativo pelo ID (por exemplo, `:read-only`, `:workspace` ou um perfil `[permissions.<id>]` definido pelo usuário), em vez de aceitar permissões de baixo nível do sistema de arquivos ou da rede. O campo legado `sandboxPolicy` aceita o mesmo formato usado por `turn/start` (por exemplo, `dangerFullAccess`, `readOnly`, `workspaceWrite` com sinalizadores, `externalSandbox` com `networkAccess` `restricted|enabled`), mas não pode ser combinado com `permissionProfile`.
- `env` é incorporado ao ambiente definido pela política de ambiente do shell do servidor. Os nomes correspondentes são substituídos; as variáveis não especificadas permanecem inalteradas.
- Quando omitido, `timeoutMs` assume o valor padrão do servidor.
- Quando omitido, `outputBytesCap` adota o valor padrão do servidor, que é de 1 MiB por fluxo.
- `disableOutputCap: true` desativa o truncamento da captura de stdout/stderr para essa solicitação `command/exec`. Não pode ser combinado com `outputBytesCap`.
- `disableTimeout: true` desativa totalmente o tempo limite para essa solicitação `command/exec`. Não pode ser combinado com `timeoutMs`.
- `processId` é opcional para a execução em buffer. Quando omitido, o Codex gera um ID interno para rastreamento do ciclo de vida, mas `tty`, `streamStdin` e `streamStdoutStderr` devem permanecer desativados, e as chamadas subsequentes `command/exec/write` / `command/exec/terminate` não estão disponíveis para esse comando.
- `size` só é válido quando `tty: true`. Define o tamanho inicial do PTY em células de caracteres.
- A execução em sandbox do Windows com buffer aceita `processId` para correlação, mas `command/exec/write` e `command/exec/terminate` ainda não são suportados para essas solicitações.
- A execução em sandbox do Windows com buffer também exige o limite de saída padrão; os valores personalizados `outputBytesCap` e `disableOutputCap` não são suportados nesse ambiente.
- `tty`, `streamStdin` e `streamStdoutStderr` são valores booleanos opcionais. As solicitações legadas que os omitirem continuam a utilizar a execução em buffer.
- `tty: true` significa o modo PTY, além de `streamStdin: true` e `streamStdoutStderr: true`.
- `tty` e `streamStdin` não desativam o tempo limite por si só; omita `timeoutMs` para usar o tempo limite padrão do servidor ou defina `disableTimeout: true` para manter o processo ativo até que seja encerrado ou terminado explicitamente.
- `outputBytesCap` se aplica independentemente a `stdout` e `stderr`, e os bytes transmitidos não são duplicados na resposta final.
- A resposta `command/exec` é adiada até que o processo seja encerrado e só é enviada depois que todas as notificações `command/exec/outputDelta` para essa conexão tiverem sido emitidas.
- `command/exec/outputDelta` As notificações têm escopo de conexão. Se a conexão de origem for encerrada, o servidor encerra o processo.

O streaming de stdin/stdout utiliza base64 para que as sessões PTY possam transportar bytes arbitrários:

```json
{ "method": "command/exec", "id": 33, "params": {
    "command": ["bash", "-i"],
    "processId": "bash-1",
    "tty": true,
    "outputBytesCap": 32768
} }
{ "method": "command/exec/outputDelta", "params": {
    "processId": "bash-1",
    "stream": "stdout",
    "deltaBase64": "YmFzaC00LjQkIA==",
    "capReached": false
} }
{ "method": "command/exec/write", "id": 34, "params": {
    "processId": "bash-1",
    "deltaBase64": "cHdkCg=="
} }
{ "id": 34, "result": {} }
{ "method": "command/exec/write", "id": 35, "params": {
    "processId": "bash-1",
    "closeStdin": true
} }
{ "id": 35, "result": {} }
{ "method": "command/exec/resize", "id": 36, "params": {
    "processId": "bash-1",
    "size": { "rows": 48, "cols": 160 }
} }
{ "id": 36, "result": {} }
{ "method": "command/exec/terminate", "id": 37, "params": {
    "processId": "bash-1"
} }
{ "id": 37, "result": {} }
{ "id": 33, "result": {
    "exitCode": 137,
    "stdout": "",
    "stderr": ""
} }
```

- `command/exec/write` aceita `deltaBase64`, `closeStdin` ou ambos.
- Os clientes podem fornecer uma string com escopo de conexão `processId` em `command/exec`; `command/exec/write`, `command/exec/resize` e `command/exec/terminate` aceitam apenas os identificadores de string fornecidos pelos clientes.
- `command/exec/outputDelta.processId` é sempre o identificador de string fornecido pelo cliente na solicitação `command/exec` original.
- `command/exec/outputDelta.stream` é `stdout` ou `stderr`. O modo PTY multiplexa a saída do terminal por meio de `stdout`.
- `command/exec/outputDelta.capReached` é igual a `true` no último bloco transmitido de um fluxo quando `outputBytesCap` trunca esse fluxo; as saídas posteriores nesse fluxo são descartadas.
- `command/exec.params.env` substitui o ambiente calculado pelo servidor para cada chave; defina uma chave como `null` para desativar uma variável herdada.
- `command/exec/resize` é compatível apenas com sessões `command/exec` baseadas em PTY.

### Exemplo: Execução do ciclo de vida do processo

Use `process/spawn` para iniciar um processo autônomo baseado em argv sem a sandbox do Codex no host onde o servidor de aplicativos está em execução. A API `process/*` é experimental e requer `initialize.params.capabilities.experimentalApi: true`. A resposta “spawn” indica que o processo foi iniciado e que o `processHandle` foi registrado; a conclusão é informada posteriormente por meio de `process/exited`.

```json
{ "method": "process/spawn", "id": 40, "params": {
    "command": ["cargo", "check"],
    "processHandle": "cargo-check-1",
    "cwd": "/Users/me/project",                    // required absolute path
    "env": { "RUST_LOG": null },                    // optional; override or unset app-server env vars
    "outputBytesCap": 1048576,                     // optional; omit for default, null disables
    "timeoutMs": 10000                             // optional; omit for default, null disables
} }
{ "id": 40, "result": {} }
{ "method": "process/exited", "params": {
    "processHandle": "cargo-check-1",
    "exitCode": 0,
    "stdout": "...",
    "stdoutCapReached": false,
    "stderr": "",
    "stderrCapReached": false
} }
```

Para processos interativos ou de streaming, defina `tty: true` ou `streamStdoutStderr: true` e encaminhe as notificações de saída por meio de `processHandle`:

```json
{ "method": "process/spawn", "id": 41, "params": {
    "command": ["bash", "-i"],
    "processHandle": "bash-1",
    "cwd": "/Users/me/project",
    "tty": true,
    "size": { "rows": 40, "cols": 120 },
    "outputBytesCap": null,
    "timeoutMs": null
} }
{ "id": 41, "result": {} }
{ "method": "process/outputDelta", "params": {
    "processHandle": "bash-1",
    "stream": "stdout",
    "deltaBase64": "YmFzaC00LjQkIA==",
    "capReached": false
} }
{ "method": "process/writeStdin", "id": 42, "params": {
    "processHandle": "bash-1",
    "deltaBase64": "cHdkCg=="
} }
{ "id": 42, "result": {} }
{ "method": "process/resizePty", "id": 43, "params": {
    "processHandle": "bash-1",
    "size": { "rows": 48, "cols": 160 }
} }
{ "id": 43, "result": {} }
{ "method": "process/kill", "id": 44, "params": {
    "processHandle": "bash-1"
} }
{ "id": 44, "result": {} }
{ "method": "process/exited", "params": {
    "processHandle": "bash-1",
    "exitCode": 137,
    "stdout": "",
    "stdoutCapReached": false,
    "stderr": "",
    "stderrCapReached": false
} }
```

- Matrizes vazias `command` e cadeias de caracteres vazias `processHandle` são rejeitadas.
- `cwd` é obrigatório e deve ser absoluto.
- `process/spawn` não está, intencionalmente, em sandbox e não define campos de seleção de sandbox, como `sandboxPolicy` ou `permissionProfile`.
- Valores `processHandle` ativos duplicados são rejeitados na mesma conexão; o mesmo identificador pode ser reutilizado após o encerramento do processo anterior.
- `tty: true` significa o modo PTY, além de `streamStdin: true` e `streamStdoutStderr: true`.
- `process/writeStdin` aceita `deltaBase64`, `closeStdin` ou ambos.
- Quando omitidos, `timeoutMs` e `outputBytesCap` assumem os valores padrão do servidor. Defina qualquer um dos campos como `null` para desativar esse limite em sessões do tipo terminal.
- `outputBytesCap` se aplica independentemente a `stdout` e `stderr`; `process/exited.stdoutCapReached` e `stderrCapReached` indicam se cada fluxo atingiu o limite. Os bytes transmitidos não são duplicados em `process/exited`.
- As notificações `process/outputDelta` e `process/exited` têm escopo de conexão. Se a conexão de origem for encerrada, o servidor encerra o processo.

### Exemplo: Utilitários do sistema de arquivos

Esses métodos operam com caminhos absolutos no sistema de arquivos do host e abrangem leitura, gravação, percurso de diretórios, cópia, exclusão e notificações de alteração.

Todos os caminhos do sistema de arquivos nesta seção devem ser absolutos.

```json
{ "method": "fs/createDirectory", "id": 40, "params": {
    "path": "/tmp/example/nested",
    "recursive": true
} }
{ "id": 40, "result": {} }
{ "method": "fs/writeFile", "id": 41, "params": {
    "path": "/tmp/example/nested/note.txt",
    "dataBase64": "aGVsbG8="
} }
{ "id": 41, "result": {} }
{ "method": "fs/getMetadata", "id": 42, "params": {
    "path": "/tmp/example/nested/note.txt"
} }
{ "id": 42, "result": {
    "isDirectory": false,
    "isFile": true,
    "isSymlink": false,
    "createdAtMs": 1730910000000,
    "modifiedAtMs": 1730910000000
} }
{ "method": "fs/readFile", "id": 43, "params": {
    "path": "/tmp/example/nested/note.txt"
} }
{ "id": 43, "result": {
    "dataBase64": "aGVsbG8="
} }
```

- `fs/getMetadata` indica se o caminho remete a um diretório ou a um arquivo comum, se o próprio caminho é um link simbólico, além de `createdAtMs` e `modifiedAtMs` em milissegundos do Unix. Se um carimbo de data/hora não estiver disponível na plataforma atual, esse campo será `0`.
- `fs/createDirectory` assume o valor padrão de `recursive` a `true` quando omitido.
- `fs/remove` define tanto `recursive` quanto `force` como `true` quando omitido.
- `fs/readFile` sempre retorna bytes em base64 por meio de `dataBase64`, e `fs/writeFile` sempre espera bytes em base64 em `dataBase64`.
- `fs/copy` lida tanto com cópias de arquivos quanto com cópias de árvores de diretórios; requer `recursive: true` quando `sourcePath` é um diretório. As cópias recursivas percorrem arquivos regulares, diretórios e links simbólicos; outros tipos de entradas são ignorados.

### Exemplo: Monitoramento do sistema de arquivos

`fs/watch` aceita caminhos absolutos de arquivos ou diretórios. O monitoramento de um arquivo emite `fs/changed` para esse caminho de arquivo, incluindo atualizações entregues por meio de operações de substituição ou renomeação.

```json
{ "method": "fs/watch", "id": 44, "params": {
    "watchId": "0195ec6b-1d6f-7c2e-8c7a-56f2c4a8b9d1",
    "path": "/Users/me/project/.git/HEAD"
} }
{ "id": 44, "result": {
    "path": "/Users/me/project/.git/HEAD"
} }
{ "method": "fs/changed", "params": {
    "watchId": "0195ec6b-1d6f-7c2e-8c7a-56f2c4a8b9d1",
    "changedPaths": ["/Users/me/project/.git/HEAD"]
} }
{ "method": "fs/unwatch", "id": 45, "params": {
    "watchId": "0195ec6b-1d6f-7c2e-8c7a-56f2c4a8b9d1"
} }
{ "id": 45, "result": {} }
```

## Eventos

As notificações de eventos constituem o fluxo de eventos iniciado pelo servidor para os ciclos de vida das threads, os ciclos de vida das rodadas e os itens contidos neles. Depois de iniciar ou retomar uma thread, continue lendo a saída padrão (stdout) em busca das notificações `thread/started`, `thread/archived`, `thread/unarchived`, `thread/closed`, `turn/*` e `item/*`.

O Thread realtime utiliza uma superfície de notificação separada, restrita ao escopo da thread. As notificações `thread/realtime/*` são eventos de transporte efêmeros, não são `ThreadItem`s, e não são retornadas por `thread/read`, `thread/resume` ou `thread/fork`.

Os avisos de configuração e inicialização recuperáveis utilizam a notificação existente `configWarning`: `{ summary, details?, path?, range? }`. O servidor de aplicativos pode emiti-la durante a inicialização para análise da configuração e diagnósticos de configuração relacionados, ou para a conexão solicitante durante `thread/start`, quando as regras da política de execução daquela thread não conseguem ser analisadas.

Os avisos genéricos de tempo de execução utilizam a notificação `warning`: `{ threadId?, message }`. O servidor de aplicativos emite essa notificação para avisos não fatais provenientes do fluxo de eventos do núcleo, incluindo casos em que nem todas as habilidades ativadas estão incluídas na lista de habilidades visíveis ao modelo para uma sessão.

### Cancelamento do recebimento de notificações

Os clientes podem suprimir notificações específicas por conexão enviando os nomes exatos dos métodos em `initialize.params.capabilities.optOutNotificationMethods`.

- Apenas correspondência exata: `item/agentMessage/delta` suprime apenas esse método.
- Nomes de métodos desconhecidos são ignorados.
- Aplica-se a notificações do tipo servidor de aplicativos, como `thread/*`, `turn/*`, `item/*` e `rawResponseItem/*`.
- Não se aplica a solicitações/respostas/erros.

Exemplos:

- Cancelar o recebimento de notificações sobre o ciclo de vida dos tópicos: `thread/started`
- Desativar a transmissão de alterações de texto do agente: `item/agentMessage/delta`

### Eventos de pesquisa difusa de arquivos (experimental)

A API de sessão de pesquisa difusa de arquivos emite notificações para cada consulta:

- `fuzzyFileSearch/sessionUpdated` — `{ sessionId, query, files }` com os arquivos correspondentes à consulta ativa.
- `fuzzyFileSearch/sessionCompleted` — `{ sessionId, query }` assim que a indexação/correspondência para essa consulta for concluída.

### Eventos em tempo real por thread (experimental)

A API em tempo real do thread emite notificações no âmbito do thread relacionadas ao ciclo de vida da sessão e à transmissão de mídia:

- `thread/realtime/started` — `{ threadId, realtimeSessionId }` assim que o modo em tempo real for iniciado para o thread (experimental). `realtimeSessionId` é o identificador da sessão da API Realtime do upstream, e não um ID de sessão ou de grupo de threads do Codex.
- `thread/realtime/itemAdded` — `{ threadId, item }` para itens em tempo real não relacionados a áudio que não possuem uma notificação de servidor de aplicativo com tipo específico, incluindo `handoff_request` (experimental). `item` é encaminhado como JSON bruto enquanto o esquema do item do WebSocket de origem permanecer instável.
- `thread/realtime/transcript/delta` — `{ threadId, role, delta }` para diferenças na transcrição em tempo real (experimental).
- `thread/realtime/transcript/done` — `{ threadId, role, text }` quando o Realtime emite o texto completo final de uma parte da transcrição (experimental).
- `thread/realtime/outputAudio/delta` — `{ threadId, audio }` para blocos de áudio de saída transmitidos (experimental). `audio` utiliza campos em camelCase (`data`, `sampleRate`, `numChannels`, `samplesPerChannel`).
- `thread/realtime/error` — `{ threadId, message }` quando o realtime detecta um erro de transporte ou de backend (experimental).
- `thread/realtime/closed` — `{ threadId, reason }` quando o transporte em tempo real é encerrado (experimental).

Como o áudio está intencionalmente separado de `ThreadItem`, os clientes podem desativar `thread/realtime/outputAudio/delta` de forma independente por meio de `optOutNotificationMethods`.

### Eventos de configuração da área restrita do Windows

- `windowsSandbox/setupCompleted` — `{ mode, success, error }` após a conclusão de uma solicitação `windowsSandbox/setupStart`.

### Eventos de inicialização do servidor MCP

- `mcpServer/startupStatus/updated` — `{ threadId, name, status, error, failureReason }` quando o servidor de aplicativos observa uma transição de inicialização do servidor MCP. `threadId` identifica a thread proprietária quando a inicialização está no escopo da thread e é `null` quando a inicialização está no escopo do aplicativo. `status` é um dos seguintes: `starting`, `ready`, `failed` ou `cancelled`. `error` e `failureReason` são `null`, exceto por `failed`; `failureReason` é `reauthenticationRequired` quando as credenciais OAuth armazenadas expiraram e não podem ser atualizadas, de modo que os clientes possam solicitar ao usuário que se reconecte ao servidor especificado.

### Eventos decisivos

O servidor do aplicativo transmite notificações JSON-RPC enquanto um turno está em execução. Cada turno emite `turn/started` quando começa a ser executado e termina com `turn/completed` (status final `turn`). Os eventos de uso de tokens são transmitidos separadamente por meio de `thread/tokenUsage/updated`. Os clientes assinam os eventos de seu interesse, renderizando cada item de forma incremental à medida que as atualizações chegam. O ciclo de vida por item é sempre: `item/started` → zero ou mais deltas específicas do item → `item/completed`.

- `turn/started` — `{ turn }` com o ID da rodada, `items` vazio e `status: "inProgress"`.
- `turn/completed` — `{ turn }`, em que `turn.status` é `completed`, `interrupted` ou `failed`; as rodadas bem-sucedidas incluem a mensagem final do agente, quando disponível, e as falhas apresentam `{ error: { message, codexErrorInfo?, additionalDetails? } }`.
- `turn/diff/updated` — `{ threadId, turnId, diff }` representa o instantâneo atualizado do diff unificado no nível da rodada, gerado após cada item FileChange. `diff` é o diff unificado agregado mais recente, abrangendo todas as alterações de arquivo na rodada. As interfaces de usuário podem renderizar isso para mostrar a visualização completa do “o que mudou” sem precisar juntar itens `fileChange` individuais.
- `turn/plan/updated` — `{ turnId, explanation?, plan }` sempre que o agente compartilha ou altera seu plano; cada entrada `plan` é `{ step, status }` com `status` em `pending`, `inProgress` ou `completed`.
- `rawResponse/completed` — apenas para uso interno; quando `thread/start.experimentalRawEvents` está habilitado, emite `{ threadId, turnId, responseId, usage }` uma vez para cada conclusão da API de respostas do upstream. `usage` é a carga útil exata de uso do upstream mapeada para o formato de detalhamento do token do servidor de aplicativos e é `null` quando a conclusão do upstream omitiu o uso. Ao contrário de `thread/tokenUsage/updated`, essa notificação não é acumulada, estimada, armazenada nem reproduzida.
- `model/safetyBuffering/updated` — `{ threadId, turnId, model, useCases, reasons, showBufferingUi, fasterModel }` quando uma resposta entra no buffer de segurança. `fasterModel` pode ser nulo. Essa notificação é transitória e não é registrada no histórico de implementação.
- `model/rerouted` — `{ threadId, turnId, fromModel, toModel, reason }` quando o backend redireciona uma solicitação para um modelo diferente (por exemplo, devido a verificações de segurança cibernética de alto risco).
- `model/verification` — `{ threadId, turnId, verifications }` quando o backend sinaliza uma verificação adicional da conta, como `trustedAccessForCyber`.
- `turn/moderationMetadata` — experimental; `{ threadId, turnId, metadata }` quando um backend próprio fornece metadados de moderação no escopo do turn para apresentação no lado do cliente.

`turn/started` não contém itens. `turn/completed` contém apenas a mensagem final do agente como um recurso alternativo resumido; continue consumindo as notificações `item/*` para obter a lista canônica completa de itens.

#### Itens

`ThreadItem` é a união de tags incluída nas respostas de turno e `item/*` nas notificações. Atualmente, oferecemos suporte a eventos para os seguintes itens:

- `userMessage` — `{id, clientId, content}`, em que `clientId` é o `clientUserMessageId` opcional fornecido a `turn/start` ou `turn/steer`, e `content` é uma lista de entradas do usuário (`text`, `image`, `localImage`, `audio` ou `localAudio`).
- `agentMessage` — `{id, text}` contendo a resposta acumulada do agente.
- `plan` — `{id, text}` emitido para curvas no modo de plano; o texto do plano pode ser transmitido via `item/plan/delta` (experimental).
- `reasoning` — `{id, summary, content}`, em que `summary` contém resumos de raciocínio transmitidos em tempo real (aplicável à maioria dos modelos da OpenAI) e `content` contém blocos de raciocínio brutos (aplicável, por exemplo, a modelos de código aberto).
- `commandExecution` — `{id, pluginId?, scriptPath?, command, cwd, status, commandActions, aggregatedOutput?, exitCode?, durationMs?}` para comandos em ambiente isolado; `pluginId` está presente apenas para comandos atribuídos a um plug-in de primeira parte confiável; itens recém-atribuídos também incluem `scriptPath` como um caminho seguro `/`separado por - em relação à raiz do plug-in confiável; o histórico mais antigo pode omitir `scriptPath`, e `status` é `inProgress`, `completed`, `failed` ou `declined`.
- `fileChange` — `{id, changes, status}` descrevendo as edições propostas; `changes` a lista `{path, kind, diff}` e `status` é `inProgress`, `completed`, `failed` ou `declined`.
- `mcpToolCall` — `{id, server, tool, status, arguments, appContext, mcpAppResourceUri?, pluginId, result?, error?}` descrevendo chamadas MCP; `appContext` é `{connectorId, linkId, resourceUri, appName, actionName}` para chamadas por meio de um aplicativo MCP confiável, em que `connectorId` identifica o conector proprietário da ferramenta, `linkId` identifica o link do aplicativo, `resourceUri` aponta para o modelo do widget, `appName` é o nome de exibição do conector e `actionName` é o conector estável `Action.name`. `appName` e `actionName` podem ser nulos para entradas de implementação mais antigas. O `mcpAppResourceUri` de nível superior está obsoleto e foi temporariamente duplicado para a migração do cliente. `tool` identifica a ferramenta MCP bruta. `status` é `inProgress`, `completed` ou `failed`.
- `collabToolCall` — `{id, tool, status, senderThreadId, receiverThreadId?, newThreadId?, prompt?, agentStatus?}` descrevendo chamadas de ferramentas de colaboração (`spawn_agent`, `send_input`, `resume_agent`, `wait`, `close_agent`); `status` é `inProgress`, `completed` ou `failed`.
- `webSearch` — `{id, query, action?, results?}` para uma solicitação de pesquisa na web emitida pelo agente; `action` reflete a carga útil da ação web_search da API de respostas (`search`, `open_page`, `find_in_page`) e pode ser omitida até a conclusão. Para pesquisa na web autônoma, `results` contém os DTOs de resultados estruturados fora de banda retornados por `/v1/alpha/search`; os clientes devem ignorar os tipos de resultados e campos que não compreenderem.
- `imageView` — `{id, path}` emitido quando o agente aciona a ferramenta de visualização de imagens.
- `sleep` — `{id, durationMs}` emitido enquanto o agente aguarda o término de um intervalo ou uma nova entrada.
- `enteredReviewMode` — `{id, review}` é enviado quando o revisor inicia o processo; `review` é um rótulo curto voltado para o usuário, como `"current changes"` ou a descrição do destino solicitado.
- `exitedReviewMode` — `{id, review}` é emitido quando o revisor conclui o trabalho; `review` é a revisão completa em texto simples (geralmente, notas gerais e conclusões em forma de lista com marcadores).
- `contextCompaction` — `{id}` emitido quando o Codex compacta o histórico de conversas. Isso pode ocorrer automaticamente.
- `compacted` - `{threadId, turnId}` quando o Codex compacta o histórico de conversas. Isso pode ocorrer automaticamente. **Obsoleto:** Use `contextCompaction` em vez disso.

Todos os itens emitem eventos de ciclo de vida em comum:

- `item/started` — emite o `item` completo quando uma nova unidade de trabalho é iniciada, para que a interface do usuário possa exibi-lo imediatamente; o `item.id` nesta carga corresponde ao `itemId` usado pelos deltas.
- `item/completed` — envia o `item` final assim que a própria operação for concluída (por exemplo, após a conclusão de uma chamada de ferramenta ou de uma mensagem); considere esse valor como o estado definitivo de execução/resultado.
- `item/autoApprovalReview/started` — [INSTÁVEL] notificação temporária de revisão automática que exibe `{threadId, turnId, targetItemId, review, action}` quando a revisão automática para aprovação é iniciada. Espera-se que essa forma mude em breve.
- `item/autoApprovalReview/completed` — [INSTÁVEL] notificação temporária de revisão automática com o código `{threadId, turnId, targetItemId, review, action}` quando a revisão automática de aprovação for concluída. Espera-se que esse formato mude em breve.

`review` está em [INSTÁVEL] e atualmente possui `{status, riskLevel?, userAuthorization?, rationale?}`, sendo que `status` é um entre `inProgress`, `approved`, `denied` ou `aborted`. `riskLevel` é um dos seguintes: `"low"`, `"medium"`, `"high"` ou `"critical"`, quando presente. `userAuthorization` é um dos seguintes: `"unknown"`, `"low"`, `"medium"` ou `"high"`, quando presente. `action` é uma união marcada com `type: "command" | "execve" | "applyPatch" | "networkAccess" | "mcpToolCall"`. Ações do tipo comando incluem um discriminador `source` (`"shell"` ou `"unifiedExec"`). Essas notificações são independentes do próprio ciclo de vida `item/completed` do item de destino e são intencionalmente temporárias enquanto o protocolo do aplicativo de revisão automática ainda está sendo projetado.

Existem eventos adicionais específicos para cada item:

#### agentMessage

- `item/agentMessage/delta` — acrescenta o texto transmitido para a mensagem do agente; concatene os valores de `delta` correspondentes ao mesmo `itemId` para reconstruir a resposta completa.

#### plano

- `item/plan/delta` — transmite o conteúdo proposto do plano para os itens do plano (experimental); concatena os valores `delta` para o mesmo plano `itemId`. Essas diferenças correspondem ao bloco `<proposed_plan>`.

#### raciocínio

- `item/reasoning/summaryTextDelta` — exibe resumos de raciocínio legíveis; `summaryIndex` aumenta quando uma nova seção de resumo é aberta.
- `item/reasoning/summaryPartAdded` — marca o limite entre as seções de resumo do raciocínio para um `itemId`; as entradas `summaryTextDelta` subsequentes compartilham o mesmo `summaryIndex`.
- `item/reasoning/textDelta` — exibe o texto bruto do raciocínio (aplicável apenas, por exemplo, a modelos de código aberto); use `contentIndex` para agrupar os deltas que pertencem ao mesmo conjunto antes de exibi-los na interface do usuário.

#### execução de comando

- `item/commandExecution/outputDelta` — transmite a saída padrão (stdout) e a saída de erro (stderr) do comando; acrescenta os deltas para exibir a saída em tempo real junto com `aggregatedOutput` no item final.
  Os `commandExecution` itens finais incluem os itens analisados `commandActions`, `status`, `exitCode` e `durationMs`, para que a interface do usuário possa resumir o que foi executado e se houve sucesso.

#### alteração no arquivo

- `item/fileChange/patchUpdated` - quando `features.apply_patch_streaming_events` está ativado, transmite instantâneos estruturados das alterações nos arquivos, analisados a partir do patch gerado pelo modelo antes de sua execução.
- `item/fileChange/outputDelta` - entrada de protocolo obsoleta para saída de texto `apply_patch`; mantida por motivos de compatibilidade, mas não é mais emitida pelo servidor.

### Erros

O evento `error` é emitido sempre que o servidor encontra um erro no meio de um turno (por exemplo, erros no modelo upstream ou limites de cota). Ele contém a mesma carga útil `{ error: { message, codexErrorInfo?, additionalDetails? } }` que o `turn.status: "failed"` e pode preceder essa notificação final.

`codexErrorInfo` corresponde à enumeração `CodexErrorInfo`. Valores comuns:

- `ContextWindowExceeded`
- `SessionBudgetExceeded`
- `UsageLimitExceeded`
- `HttpConnectionFailed { httpStatusCode? }`: falhas HTTP a montante, incluindo códigos 4xx/5xx
- `ResponseStreamConnectionFailed { httpStatusCode? }`: falha ao conectar-se ao fluxo SSE de resposta
- `ResponseStreamDisconnected { httpStatusCode? }`: desconexão do fluxo SSE de resposta no meio de um turno, antes de sua conclusão
- `ResponseTooManyFailedAttempts { httpStatusCode? }`
- `ActiveTurnNotSteerable { turnKind }`: `turn/start` ou `turn/steer` foi enviado enquanto o
  a curva ativa atual não era direcionável, por exemplo, `/review` ou manual `/compact`
- `BadRequest`
- `Unauthorized`
- `SandboxError`
- `InternalServerError`
- `Other`: todos os erros não classificados

Quando um status HTTP de origem está disponível (por exemplo, da API de Respostas ou de um provedor), ele é encaminhado em `httpStatusCode` na variante `codexErrorInfo` correspondente.

## Aprovações

Certas ações (comandos do shell ou modificação de arquivos) podem exigir aprovação explícita do usuário, dependendo da configuração do usuário. Quando `turn/start` é usado, o servidor de aplicativos inicia um fluxo de aprovação enviando uma solicitação JSON-RPC iniciada pelo servidor ao cliente. O cliente deve responder para informar ao Codex se deve prosseguir. As interfaces de usuário devem apresentar essas solicitações em linha com a etapa ativa, para que os usuários possam revisar o comando proposto ou a comparação antes de escolher.

- As solicitações incluem `threadId` e `turnId` — use-as para restringir o estado da interface do usuário à conversa ativa.
- Responda com uma única carga útil `{ "decision": ... }`. As aprovações de comando aceitam `accept`, `acceptForSession`, `acceptWithExecpolicyAmendment`, `applyNetworkPolicyAmendment`, `decline` ou `cancel`. O servidor retoma ou recusa o trabalho e encerra o item com `item/completed`.

### Aprovações para execução de comandos

Ordem das mensagens:

1. `item/started` — exibe o item `commandExecution` pendente com os campos `command`, `cwd` e outros, para que você possa executar a ação proposta.
2. `item/commandExecution/requestApproval` (solicitação) — contém os mesmos `itemId`, `threadId`, `turnId`, o parâmetro nulo `environmentId` onde o comando será executado, opcionalmente `approvalId` (para callbacks de subcomandos) e `reason`. Novas aprovações de shell e de execução unificada definem `environmentId`; eventos mais antigos que não fornecem um são expostos como `null`. Para aprovações de comando normais, a solicitação também inclui `command`, `cwd` e `commandActions` para exibição amigável. Quando `initialize.params.capabilities.experimentalApi = true`, também pode incluir o campo experimental `additionalPermissions`, que descreve o acesso solicitado à sandbox por comando; quaisquer caminhos do sistema de arquivos nessa carga são absolutos na transmissão, e o acesso à rede é representado como `additionalPermissions.network.enabled`. Para aprovações exclusivamente de rede, esses campos de comando podem ser omitidos e `networkApprovalContext` é fornecido em seu lugar. Dicas opcionais de persistência também podem ser incluídas por meio de `proposedExecpolicyAmendment` e `proposedNetworkPolicyAmendments`. Os clientes podem dar preferência a `availableDecisions`, quando presente, para apresentar o conjunto exato de opções que o servidor deseja expor, mantendo o recurso de recuo para as heurísticas mais antigas caso seja omitido.
3. Resposta do cliente — por exemplo, `{ "decision": "accept" }`, `{ "decision": "acceptForSession" }`, `{ "decision": { "acceptWithExecpolicyAmendment": { "execpolicy_amendment": [...] } } }`, `{ "decision": { "applyNetworkPolicyAmendment": { "network_policy_amendment": { "host": "example.com", "action": "allow" } } } }`, `{ "decision": "decline" }` ou `{ "decision": "cancel" }`.
4. `serverRequest/resolved` — `{ threadId, requestId }` confirma que a solicitação pendente foi resolvida ou encerrada, incluindo a limpeza do ciclo de vida no início, na conclusão ou na interrupção do turno.
5. `item/completed` — último item `commandExecution` com `status: "completed" | "failed" | "declined"` e saída da execução. Apresente isso como o resultado oficial.

### Aprovações de alterações em arquivos

Ordem das mensagens:

1. `item/started` — gera um item `fileChange` com `changes` (resumos dos trechos com diferenças) e `status: "inProgress"`. Mostra ao usuário as edições propostas e os caminhos.
2. `item/fileChange/requestApproval` (solicitação) — inclui `itemId`, `threadId`, `turnId`, um `reason` opcional e pode incluir um `grantRoot` instável quando o agente estiver solicitando acesso de gravação no escopo da sessão sob uma raiz específica.
3. Resposta do cliente — `{ "decision": "accept" }`, `{ "decision": "acceptForSession" }`, `{ "decision": "decline" }` ou `{ "decision": "cancel" }`.
4. `serverRequest/resolved` — `{ threadId, requestId }` confirma que a solicitação pendente foi resolvida ou encerrada, incluindo a limpeza do ciclo de vida no início, na conclusão ou na interrupção do turno.
5. `item/completed` — retorna o mesmo item `fileChange` com `status` atualizado para `completed`, `failed` ou `declined` após a tentativa de patch. Utilize isso para indicar sucesso/falha e finalizar o estado da comparação (diff) em sua interface de usuário.

Orientação de interface do usuário para IDEs: exiba uma caixa de diálogo de aprovação assim que a solicitação for recebida. A operação seguirá adiante após o servidor receber uma resposta à solicitação de aprovação. A notificação `item/completed` do terminal será enviada com o status apropriado.

### solicitar_entrada_do_usuário

Quando o cliente responde com `item/tool/requestUserInput`, o servidor emite `serverRequest/resolved` com `{ threadId, requestId }`. Se a solicitação pendente for cancelada pelo início, conclusão ou interrupção do turno antes que o cliente responda, o servidor emite a mesma notificação para esse cancelamento.

### Geração de atestados

Os hosts de desktop que fornecem atestado de upstream devem definir `capabilities.requestAttestation` durante `initialize` e processar a solicitação `attestation/generate` iniciada pelo servidor. O servidor de aplicativos o emite bem a tempo, antes que o ChatGPT Codex solicite o encaminhamento de `x-oai-attestation`; o cliente responde com `{ "token": "v1.<opaque>" }`, em que `token` é um valor opaco de propriedade do cliente. Quando o servidor de aplicativos recebe uma resposta do cliente, ele encaminha um envelope externo consistente, como `{ "v": 1, "s": 0, "t": "v1.<opaque>" }`, em que `t` contém o token do cliente inalterado. Se o servidor de aplicativos tentar a atestação, mas falhar dentro de seus próprios limites, ele envia o mesmo formato de envelope com um código de status do servidor de aplicativos e sem `t` (`1 = timeout`, `2 = request failed`, `3 = request canceled`, `4 = malformed response`). Se nenhum cliente inicializado tiver optado pela atestação, o servidor de aplicativos omite `x-oai-attestation` para essa solicitação upstream.

### Hora atual

Quando `[features.current_time_reminder]` está habilitado com `clock_source = "external"`, o servidor de aplicativos envia ao cliente inscrito na thread uma solicitação experimental `currentTime/read` com `{ "threadId": "thr_123" }` quando chega a hora de um lembrete. O cliente responde com `{ "currentTimeAt": 1781717655 }`, em que `currentTimeAt` é um timestamp Unix inteiro em segundos. Uma resposta com falha, cancelada, com tempo de espera esgotado ou malformada interrompe a sequência antes que a solicitação do modelo seja enviada.

### Solicitações do servidor MCP

Os servidores MCP podem interromper um turno e solicitar ao cliente uma entrada estruturada por meio de `mcpServer/elicitation/request`.

Ordem das mensagens:

1. `mcpServer/elicitation/request` (solicitação) — inclui `threadId`, `turnId` (pode ser nulo), `serverName` e uma das seguintes opções:
   - um pedido de formulário: `{ "mode": "form", "message": "...", "requestedSchema": { ... } }`
   - uma solicitação no formato estendido da OpenAI: `{ "mode": "openai/form", "message": "...", "requestedSchema": { ... } }`
   - uma solicitação de URL: `{ "mode": "url", "message": "...", "url": "...", "elicitationId": "..." }`
2. Resposta do cliente — `{ "action": "accept", "content": ... }`, `{ "action": "decline", "content": null }` ou `{ "action": "cancel", "content": null }`.
3. `serverRequest/resolved` — `{ threadId, requestId }` confirma que a solicitação pendente foi resolvida ou encerrada, incluindo a limpeza do ciclo de vida no início, na conclusão ou na interrupção do turno.

`turnId` é do tipo “melhor esforço”. Quando a solicitação está correlacionada a um turno ativo, a solicitação inclui o identificador desse turno; caso contrário, é `null`.

Para `openai/form`, o servidor de aplicativos encaminha `requestedSchema` como JSON opaco. O
O cliente é responsável pela validação e renderização dos tipos de campo suportados e deve retornar um
resposta válida `decline` ou `cancel` quando não consegue exibir um formulário.

Para solicitações de aprovação de ferramentas do MCP, o formulário de solicitação `meta` inclui
`codex_approval_kind: "mcp_tool_call"` e pode incluir `persist: "session"`,
`persist: "always"` ou `persist: ["session", "always"]` para indicar se
O cliente pode oferecer opções de aprovação válidas apenas para a sessão e/ou persistentes.

### Solicitações de permissão

A ferramenta integrada `request_permissions` envia uma solicitação JSON-RPC `item/permissions/requestApproval` ao cliente com o perfil de permissão solicitado. Essa carga útil da v2 reflete o formato `additionalPermissions` de execução de comando: ela pode solicitar acesso à rede e acesso adicional ao sistema de arquivos. Os campos `environmentId` e `cwd` identificam o ambiente e o diretório usados para resolver as permissões da raiz do projeto e os globs de negação relativos.

```json
{
  "method": "item/permissions/requestApproval",
  "id": 61,
  "params": {
    "threadId": "thr_123",
    "turnId": "turn_123",
    "itemId": "call_123",
    "environmentId": "local",
    "cwd": "/Users/me/project",
    "reason": "Select a workspace root",
    "permissions": {
      "fileSystem": {
        "write": ["/Users/me/project", "/Users/me/shared"]
      }
    }
  }
}
```

O cliente responde com `result.permissions`, que deve ser o subconjunto concedido do perfil de permissão solicitado. Também é possível definir `result.scope` como `"session"` para que a concessão persista em turnos posteriores na mesma sessão; a omissão ou o valor `"turn"` mantêm o comportamento existente, restrito ao turno:

```json
{
  "id": 61,
  "result": {
    "scope": "session",
    "permissions": {
      "fileSystem": {
        "write": ["/Users/me/project"]
      }
    }
  }
}
```

Apenas o subconjunto concedido é relevante na transmissão. Quaisquer permissões omitidas de `result.permissions` são consideradas negadas. Quaisquer permissões que não estejam presentes na solicitação original são ignoradas pelo servidor.

No mesmo ciclo de execução, as permissões concedidas são persistentes: chamadas posteriores de ferramentas do tipo shell podem reutilizar automaticamente o subconjunto concedido sem precisar reenviar uma solicitação de permissão separada.

Se a política de aprovação de sessão utilizar `Granular` com `request_permissions: false`, as chamadas à ferramenta autônoma `request_permissions` são automaticamente negadas e nenhum prompt `item/permissions/requestApproval` é enviado. As solicitações de comando `with_additional_permissions` embutidas continuam sendo controladas por `sandbox_approval`, e quaisquer permissões concedidas anteriormente permanecem válidas para chamadas posteriores do tipo shell no mesmo turno.

### Chamadas dinâmicas de ferramentas (experimental)

`dynamicTools` em `thread/start` e o fluxo de solicitação/resposta correspondente `item/tool/call` são APIs experimentais. Para ativá-las, defina `initialize.params.capabilities.experimentalApi = true`.

Cada entrada em `dynamicTools` é uma função de nível superior ou um namespace que contém ferramentas de função. Os identificadores de ferramentas dinâmicas seguem as mesmas restrições que as ferramentas de respostas:

- `name` deve corresponder a `^[a-zA-Z0-9_-]+$` e ter entre 1 e 128 caracteres.
- Os nomes dos namespaces devem corresponder a `^[a-zA-Z0-9_-]+$` e ter entre 1 e 64 caracteres.
- As descrições dos namespaces devem ter, no máximo, 1.024 caracteres.
- Os nomes dos namespaces não devem entrar em conflito com os namespaces reservados do tempo de execução do Responses, tais como `functions`, `multi_tool_use`, `file_search`, `web`, `browser`, `image_gen`, `computer`, `container`, `terminal`, `python`, `python_user_visible`, `api_tool`, `tool_search` ou `submodel_delegator`.

Cada função pode definir `deferLoading`. Quando omitido, o valor padrão é `false`. Funções diferidas devem pertencer a um namespace. Defina-o como `true` para manter a função registrada e chamável por recursos de tempo de execução, como `code_mode`, ao mesmo tempo em que a exclui da lista de ferramentas voltadas para o modelo enviada em turnos comuns. Quando `tool_search` estiver disponível, as ferramentas dinâmicas diferidas poderão ser pesquisadas e expostas por meio de um resultado de pesquisa correspondente.

Quando uma ferramenta dinâmica é invocada durante um turno, o servidor envia uma solicitação JSON-RPC `item/tool/call` ao cliente:

```json
{
  "method": "item/tool/call",
  "id": 60,
  "params": {
    "threadId": "thr_123",
    "turnId": "turn_123",
    "callId": "call_123",
    "namespace": "tickets",
    "tool": "lookup_ticket",
    "arguments": { "id": "ABC-123" }
  }
}
```

O servidor também emite notificações sobre o ciclo de vida dos itens relacionadas à solicitação:

1. `item/started` com `item.type = "dynamicToolCall"`, `status = "inProgress"`, além de `tool` e `arguments`.
2. `item/tool/call` solicitação.
3. Resposta do cliente.
4. `item/completed` com `item.type = "dynamicToolCall"`, `status` final e `contentItems`/`success` devolvidos.

O cliente deve responder com itens de conteúdo. Use `inputText` para texto, `inputImage` para URLs de dados de imagem embutidos e `inputAudio` para URLs de dados de áudio embutidos. URLs de dados de áudio aceitam os tipos de mídia wav, mp3, m4a, webm e ogg. URLs remotas de imagens via HTTP(S) e URLs de áudio que não sejam de dados invalidam a resposta da ferramenta dinâmica.

```json
{
  "id": 60,
  "result": {
    "contentItems": [
      { "type": "inputText", "text": "Ticket ABC-123 is open." },
      { "type": "inputImage", "imageUrl": "data:image/png;base64,AAA" },
      { "type": "inputAudio", "audioUrl": "data:audio/wav;base64,AAA" }
    ],
    "success": true
  }
}
```

## Habilidades

Para acionar uma habilidade, inclua `$<skill-name>` no texto inserido. Adicione um item de entrada `skill` (recomendado) para que o backend insira as instruções completas da habilidade, em vez de depender do modelo para resolver o nome.

```json
{
  "method": "turn/start",
  "id": 101,
  "params": {
    "threadId": "thread-1",
    "input": [
      {
        "type": "text",
        "text": "$skill-creator Add a new skill for triaging flaky CI."
      },
      {
        "type": "skill",
        "name": "skill-creator",
        "path": "/Users/me/.codex/skills/skill-creator/SKILL.md"
      }
    ]
  }
}
```

Se você omitir o item `skill`, o modelo ainda analisará o marcador `$<skill-name>` e tentará localizar a habilidade, o que pode aumentar a latência.

Exemplo:

```
$skill-creator Add a new skill for triaging flaky CI and include step-by-step usage.
```

Use `skills/list` para obter as habilidades disponíveis (opcionalmente filtradas por `cwds`, com `forceReload`).
`skills/list` pode reutilizar um resultado de habilidades armazenado em cache por `cwd`; definir `forceReload` como `true` atualiza o resultado a partir do disco.
O servidor também emite `skills/changed` notificações quando os arquivos de habilidades locais monitorados são alterados. Considere isso como um sinal de invalidação e execute novamente `skills/list` com seus parâmetros atuais quando necessário.
Use `skills/extraRoots/set` para substituir raízes de habilidades autônomas adicionais para o processo atual do servidor de aplicativos. Essas raízes utilizam o mesmo layout que outras raízes de habilidades autônomas: cada raiz contém diretórios de habilidades, e cada diretório de habilidades contém `SKILL.md`. Raízes ausentes são aceitas e não carregam nenhuma habilidade até que elas existam. Essa configuração é perdida quando o servidor de aplicativos é encerrado.

```json
{ "method": "skills/list", "id": 25, "params": {
    "cwds": ["/Users/me/project", "/Users/me/other-project"],
    "forceReload": true
} }
{ "id": 25, "result": {
    "data": [{
        "cwd": "/Users/me/project",
        "skills": [
            {
              "name": "skill-creator",
              "description": "Create or update a Codex skill",
              "enabled": true,
              "interface": {
                "displayName": "Skill Creator",
                "shortDescription": "Create or update a Codex skill",
                "iconSmall": "icon.svg",
                "iconLarge": "icon-large.svg",
                "brandColor": "#111111",
                "defaultPrompt": "Add a new skill for triaging flaky CI."
              }
            }
        ],
        "errors": []
    }]
} }
```

```json
{
  "method": "skills/changed",
  "params": {}
}
```

```json
{
  "method": "skills/extraRoots/set",
  "id": 26,
  "params": {
    "extraRoots": ["/Users/me/generated-skills"]
  }
}
{ "id": 26, "result": {} }
```

Para ativar ou desativar uma habilidade por caminho absoluto:

```json
{
  "method": "skills/config/write",
  "id": 27,
  "params": {
    "path": "/Users/alice/.codex/skills/skill-creator/SKILL.md",
    "name": null,
    "enabled": false
  }
}
```

Para ativar ou desativar uma habilidade pelo nome:

```json
{
  "method": "skills/config/write",
  "id": 28,
  "params": {
    "path": null,
    "name": "github:yeet",
    "enabled": false
  }
}
```

Use `hooks/list` para obter os hooks detectados para um ou mais `cwds`. Cada resultado é avaliado com a configuração efetiva desse `cwd`; portanto, os gatilhos de recursos e as camadas de configuração detectadas podem variar dentro de uma única resposta.

Para árvores de trabalho do Git vinculadas, as declarações de hooks do projeto provêm das pastas `.codex/` correspondentes na raiz do checkout, em vez de provirem de declarações de hooks divergentes armazenadas apenas na árvore de trabalho vinculada. Isso garante que cada repositório mantenha uma única definição autoritativa de hooks do projeto e um único estado de confiança.

Os hooks são retornados mesmo quando desativados, para que os clientes possam renderizá-los e reativá-los. O estado controlado pelo usuário é armazenado em `hooks.state`. Os hooks gerenciados não são configuráveis, e as entradas do usuário para chaves de hooks gerenciados são ignoradas durante o carregamento.

Para hooks não gerenciados, `currentHash` e `trustStatus` indicam se a definição atual é a primeira vez que aparece, se foi aprovada ou se sofreu alterações desde a aprovação. Somente hooks não gerenciados confiáveis tornam-se executáveis. As chaves de hook combinam a identidade de origem com um seletor de evento/grupo/manipulador no final, que atualmente é posicional.

```json
{
  "method": "hooks/list",
  "id": 28,
  "params": {
    "cwds": ["/Users/me/project"]
  }
}
```

```json
{
  "id": 28,
  "result": {
    "data": [{
      "cwd": "/Users/me/project",
      "hooks": [{
        "key": "/Users/me/.codex/config.toml:pre_tool_use:0:0",
        "eventName": "pre_tool_use",
        "handlerType": "command",
        "isManaged": false,
        "matcher": "Bash",
        "command": "python3 /Users/me/hook.py",
        "timeoutSec": 5,
        "statusMessage": "running hook",
        "additionalContextLimit": null,
        "sourcePath": "/Users/me/.codex/config.toml",
        "source": "user",
        "pluginId": null,
        "displayOrder": 0,
        "enabled": true,
        "currentHash": "sha256:...",
        "trustStatus": "untrusted"
      }],
      "warnings": [],
      "errors": []
    }]
  }
}
```

Para desativar um gancho não gerenciado, insira ou atualize uma entrada de estado em `hooks.state` com o valor `config/batchWrite`:

```json
{
  "method": "config/batchWrite",
  "id": 29,
  "params": {
    "edits": [{
      "keyPath": "hooks.state",
      "value": {
        "/Users/me/.codex/config.toml:pre_tool_use:0:0": {
          "enabled": false
        }
      },
      "mergeStrategy": "upsert"
    }],
    "reloadUserConfig": true
  }
}
```

Para reativá-lo, faça um upsert da mesma chave de hook com `"enabled": true`.
## Aplicativos

Use `app/installed` para verificar os aplicativos instalados e se cada um deles está ativado e disponível no momento.

```json
{ "method": "app/installed", "id": 49, "params": {
    "threadId": "thr_123",
    "forceRefresh": false
} }
{ "id": 49, "result": {
    "apps": [
        {
            "id": "demo-app",
            "runtimeName": "Demo App",
            "enabled": true,
            "callable": true
        }
    ]
} }
```

`id` é o ID do conector do aplicativo, e `runtimeName` é o nome nulo relatado pelo ambiente de execução. `enabled` reflete a configuração efetiva do aplicativo e a política do espaço de trabalho. `callable` é verdadeiro quando o aplicativo está habilitado e possui pelo menos uma ferramenta visível ao modelo permitida pela política do aplicativo e da ferramenta.

Quando `threadId` é fornecido, a resposta utiliza a configuração efetiva daquela thread; caso contrário, utiliza a configuração global atual. O valor padrão de `forceRefresh` é `false`. Defina-o como `true` para atualizar o instantâneo da ferramenta de tempo de execução do conector hospedado antes de ler a resposta. Quando os aplicativos são desativados por uma política global ou do espaço de trabalho, os aplicativos observados anteriormente ainda podem ser retornados com `enabled` e `callable` definidos como `false`.

Use `app/list` para buscar os aplicativos disponíveis (conectores). Cada entrada inclui metadados como o aplicativo `id`, exibição `name`, `installUrl`, URLs de logotipos antigos, recursos de ícones estruturados nos temas claro e escuro, `branding`, `appMetadata`, `labels`, se está acessível no momento e se está habilitado na configuração.

```json
{ "method": "app/list", "id": 50, "params": {
    "cursor": null,
    "limit": 50,
    "threadId": "thr_123",
    "forceRefetch": false
} }
{ "id": 50, "result": {
    "data": [
        {
            "id": "demo-app",
            "name": "Demo App",
            "description": "Example connector for documentation.",
            "logoUrl": "https://example.com/demo-app.png",
            "logoUrlDark": null,
            "iconAssets": {
                "256_square": "https://example.com/demo-app-square.png"
            },
            "iconDarkAssets": null,
            "distributionChannel": null,
            "branding": null,
            "appMetadata": null,
            "labels": null,
            "installUrl": "https://chatgpt.com/apps/demo-app/demo-app",
            "isAccessible": true,
            "isEnabled": true
        }
    ],
    "nextCursor": null
} }
```

Quando `threadId` é fornecido, o controle de acesso aos recursos do aplicativo (`Feature::Apps`) é avaliado com base no instantâneo de configuração daquela thread. Quando omitido, é utilizada a configuração global mais recente.

`app/list` é retornado após o carregamento tanto dos aplicativos acessíveis quanto dos aplicativos de diretório. Defina `forceRefetch: true` para ignorar os caches dos aplicativos e buscar dados atualizados das fontes. As entradas do cache só são substituídas quando essas novas buscas forem bem-sucedidas.

O servidor também emite `app/list/updated` notificações quando aplicativos acessíveis ou de diretório recém-carregados alteram a lista de aplicativos mesclada. Cada notificação inclui a lista de aplicativos mesclada mais recente. Um `app/list` inicial armazenado em cache ainda emite uma notificação final para que outros clientes inicializados possam atualizar sua lista de aplicativos, enquanto a leitura de uma página de continuação em cache inalterada não emite uma notificação duplicada; o `forceRefetch: true` preserva as notificações progressivas existentes enquanto novos dados são carregados.

```json
{
  "method": "app/list/updated",
  "params": {
    "data": [
      {
        "id": "demo-app",
        "name": "Demo App",
        "description": "Example connector for documentation.",
        "logoUrl": "https://example.com/demo-app.png",
        "logoUrlDark": null,
        "iconAssets": {
          "256_square": "https://example.com/demo-app-square.png"
        },
        "iconDarkAssets": null,
        "distributionChannel": null,
        "branding": null,
        "appMetadata": null,
        "labels": null,
        "installUrl": "https://chatgpt.com/apps/demo-app/demo-app",
        "isAccessible": true,
        "isEnabled": true
      }
    ]
  }
}
```

Use `app/read` quando um cliente já tiver IDs de aplicativos e precisar apenas de metadados. A solicitação aceita
máximo de 100 `appIds`; os IDs repetidos são deduplicados, preservando a ordem da primeira solicitação. Ambos `apps`
e `missingAppIds` seguem essa ordem. IDs desconhecidos ou não autorizados são retornados como correspondências parciais
em vez de rejeitar toda a solicitação.

```json
{ "method": "app/read", "id": 51, "params": {
    "appIds": ["demo-app", "missing-app"],
    "includeTools": true
} }
{ "id": 51, "result": {
    "apps": [
        {
            "id": "demo-app",
            "name": "Demo App",
            "description": "Example app for documentation.",
            "iconUrl": "https://files.openai.com/content?id=demo-app",
            "toolSummaries": [
                {
                    "name": "search",
                    "title": "Search",
                    "description": "Search the app.",
                    "isEnabled": true,
                    "disabledReason": null,
                    "isReadOnly": true
                }
            ]
        }
    ],
    "missingAppIds": ["missing-app"]
} }
```

`app/read` lê novos registros de metadados de um cache particionado por URL do backend e ChatGPT
identidade da conta/área de trabalho e, em seguida, gera no máximo um `POST /ps/apps/batch` para dados ausentes ou
IDs expirados. `includeTools` assume o valor padrão “false” e é encaminhado como `include_tools`; um novo
A entrada do cache que contém apenas metadados é recarregada quando são solicitados resumos de ferramentas. Back-end ou transporte
As falhas retornam um erro de RPC sem substituir os registros existentes no cache. A estrutura de seus metadados pode
inclui resumos de ferramentas públicas apenas para exibição, com o status “ativado” ou “somente leitura”, e exclui intencionalmente
estado de execução, estado da ferramenta MCP, ações completas e descrições de modelos.

Os aplicativos conectados podem substituir o revisor de aprovação do tópico em `config.toml`.
Use `apps._default.approvals_reviewer` para definir o revisor para todos os aplicativos, e um
valor por aplicativo para substituir esse padrão. Quando ambos forem omitidos, o aplicativo herda
o valor de nível superior `approvals_reviewer`:

```toml
approvals_reviewer = "auto_review"

[apps._default]
approvals_reviewer = "user"
default_tools_approval_mode = "prompt"

[apps.demo-app]
approvals_reviewer = "auto_review"
default_tools_approval_mode = "approve"
```

Ao definir o valor do aplicativo como `"user"`, as solicitações de aprovação são encaminhadas ao usuário
em vez do Guardian; definir o valor como `"auto_review"` ativa o Guardian nesse aplicativo
revisar quando permitido pelos requisitos de configuração.

Use `apps._default.default_tools_approval_mode` para definir o modo de aprovação para
ferramentas sem uma substituição específica por aplicativo ou por ferramenta. Os valores permitidos são `"auto"`,
`"prompt"`, `"writes"` e `"approve"`. O modo `"writes"` solicita a seleção de ferramentas
que não anunciam `readOnlyHint = true` e ignora as ferramentas declaradas como somente leitura.
O nível de ferramenta `approval_mode` tem precedência sobre
o valor `default_tools_approval_mode` por aplicativo, que tem precedência sobre o
Valor `apps._default`. Os requisitos das ferramentas gerenciadas têm precedência sobre todos os
essas configurações. Quando nenhuma delas estiver definida, o modo assume o valor padrão `"auto"`.

Chame um aplicativo inserindo `$<app-slug>` no campo de entrada de texto. O slug é derivado do nome do aplicativo e convertido para letras minúsculas, com os caracteres não alfanuméricos substituídos por `-` (por exemplo, “Demo App” passa a ser `$demo-app`). Adicione um item de entrada `mention` (recomendado) para que o servidor utilize o caminho exato `app://<connector-id>`, em vez de adivinhar com base no nome. Os plug-ins usam o mesmo formato de item `mention`, mas com caminhos `plugin://<plugin-name>@<marketplace-name>` a partir de `plugin/installed` ou `plugin/list`.

Exemplo:

```
$demo-app Pull the latest updates from the team.
```

```json
{
  "method": "turn/start",
  "id": 51,
  "params": {
    "threadId": "thread-1",
    "input": [
      {
        "type": "text",
        "text": "$demo-app Pull the latest updates from the team."
      },
      { "type": "mention", "name": "Demo App", "path": "app://demo-app" }
    ]
  }
}
```

## Endpoints de autenticação

A interface de autenticação/conta do JSON-RPC disponibiliza métodos de solicitação/resposta, além de notificações iniciadas pelo servidor (sem `id`). Use-os para determinar o estado de autenticação, iniciar ou cancelar logins, fazer logout e verificar os limites de taxa do ChatGPT.

### Modos de autenticação

O Codex oferece suporte a esses modos de autenticação. O modo atual é exibido em `account/updated` (`authMode`), que também inclui o ChatGPT atual `planType` quando disponível, e pode ser inferido a partir de `account/read`.

- **Chave da API (`apiKey`)**: O solicitante fornece uma chave da API da OpenAI por meio de `account/login/start` com `type: "apiKey"`. A chave da API é salva e utilizada para solicitações à API.
- **Gerenciado pelo ChatGPT (`chatgpt`)** (recomendado): O Codex é responsável pelo fluxo OAuth do ChatGPT e pelos tokens de atualização. Comece pelo `account/login/start` com o `type: "chatgpt"` para o fluxo do navegador ou o `type: "chatgptDeviceCode"` para o código do dispositivo; o Codex armazena os tokens no disco e os atualiza automaticamente.
- **Autenticação do Amazon Bedrock gerenciada pelo Codex (`amazonBedrock`, experimental)**: O chamador fornece uma chave de API do Amazon Bedrock e a região por meio de `account/login/start` com `type: "amazonBedrock"`. O cliente deve habilitar o recurso de inicialização `experimentalApi` para o login no Amazon Bedrock gerenciado pelo Codex. O Codex substitui a autenticação primária atual pelas credenciais do Bedrock e grava `model_provider = "amazon-bedrock"` na configuração do usuário.
- **Token de acesso pessoal (`personalAccessToken`)**: O Codex utiliza um token de acesso pessoal baseado no ChatGPT, carregado fora dos RPCs de login do servidor do aplicativo, como no caso de `codex login --with-access-token` ou `CODEX_ACCESS_TOKEN`.

### Visão geral da API

- `account/read` — obter informações da conta corrente; opcionalmente, atualizar os tokens.
- `account/login/start` — início do login (`apiKey`, `chatgpt`, `chatgptDeviceCode`, `amazonBedrock`).
- `account/login/completed` (notificar) — emitido quando uma tentativa de login é concluída (seja com sucesso ou com erro).
- `account/login/cancel` — cancela um login gerenciado do ChatGPT pendente com o comando `loginId`.
- `account/logout` — encerrar sessão; aciona `account/updated` em caso de sucesso.
- `account/updated` (notificar) — emitido sempre que o modo de autenticação for alterado (`authMode`: `apikey`, `bedrockApiKey`, `chatgpt`, `personalAccessToken` ou `null`) e inclui o `planType` atual do ChatGPT, quando disponível.
- `account/rateLimits/read` — obtém os limites de taxa do ChatGPT, um limite de crédito mensal efetivo opcional, se o controle de gastos foi atingido e as reinicializações de limite de taxa ganhas atualmente disponíveis, incluindo detalhes de validade, quando fornecidos pelo backend. As atualizações dos limites de taxa chegam por meio de `account/rateLimits/updated` (notify); os dados de redefinição de crédito são apenas instantâneos.
- `account/rateLimitResetCredit/consume` — consumir uma reinicialização adquirida usando uma chave de idempotência fornecida pelo chamador, selecionando, opcionalmente, um ID de crédito de reinicialização retornado por `account/rateLimits/read`.
- `account/usage/read` — recuperar o resumo de atividades do token da conta do ChatGPT e os intervalos diários.
- `account/workspaceMessages/read` — busca as mensagens do espaço de trabalho ativo, incluindo os títulos das notificações do espaço de trabalho, quando disponíveis.
- `account/rateLimits/updated` (notificar) — emitido sempre que os limites de taxa do ChatGPT de um usuário forem alterados. Trata-se de uma atualização contínua e esparsa; incorpore os valores disponíveis à resposta `account/rateLimits/read` mais recente ou recupere esse instantâneo.
  `spendControlReached` é igual a `true` ou `false` quando o backend informa o estado do controle de gastos; `null` significa “indisponível” e não deve apagar um valor observado anteriormente em uma atualização esparsa.
- `account/sendAddCreditsNudgeEmail` — peça ao ChatGPT para enviar um e-mail ao proprietário do espaço de trabalho informando que os créditos se esgotaram ou que o limite de uso foi atingido.
- `mcpServer/oauthLogin/completed` (notificar) — emitido após a conclusão de um fluxo `mcpServer/oauth/login` para um servidor; a carga útil inclui `{ name, threadId, success, error? }`.
- `mcpServer/startupStatus/updated` (notificar) — emitido quando o status de inicialização de um servidor MCP configurado é alterado; a carga útil inclui `{ threadId, name, status, error, failureReason }`, em que `threadId` é a thread proprietária quando a inicialização está no escopo da thread e `null` quando está no escopo do aplicativo, e `status` é `starting`, `ready`, `failed` ou `cancelled`. `failureReason` é igual a `reauthenticationRequired` quando as credenciais OAuth armazenadas expiraram e não podem ser atualizadas, de modo que os clientes possam solicitar ao usuário que se reconecte ao servidor indicado.

### 1) Verificar o status da autenticação

Solicitação:

```json
{ "method": "account/read", "id": 1, "params": { "refreshToken": false } }
```

Exemplos de respostas:

```json
{ "id": 1, "result": { "account": { "type": "chatgpt", "email": "user@example.com", "planType": "pro" }, "requiresOpenaiAuth": true } }
{ "id": 1, "result": { "account": { "type": "amazonBedrock", "usesCodexManagedCredentials": false }, "requiresOpenaiAuth": false } }
```

Notas de campo:

- `refreshToken` (bool): defina como `true` para forçar a atualização do token.
- `email` é igual a `null` quando a conta do ChatGPT não possui um endereço de e-mail.
- `requiresOpenaiAuth` indica o provedor ativo; quando é `false`, o Codex pode ser executado sem credenciais da OpenAI.
- O Amazon Bedrock retorna `usesCodexManagedCredentials: true` quando utiliza uma chave de API do Bedrock gerenciada pelo Codex. Ele retorna `false` para caminhos de credenciais externas, incluindo a cadeia de credenciais da AWS e a autenticação por comando configurada. Isso identifica se as credenciais gerenciadas pelo Codex estão selecionadas; não valida se a fonte de credenciais é capaz de resolver as credenciais.

### 2) Faça login com uma chave de API

1. Enviar:
   ```json```
   {
     "método": "account/login/start",
     identificador: 2,
     params: { type: 'apiKey', apiKey: 'sk-…' }
   }
   ```
2. O que esperar:
   ```json```
   { "id": 2, "result": { "type": "apiKey" } }
   ```
3. Notificações:
   ```json```
   { "method": "account/login/completed", "params": { "loginId": null, "success": true, "error": null } }
   { "method": "account/updated", "params": { "authMode": "apikey", "planType": null } }
   ```

### 3) Faça login com o ChatGPT (processo no navegador)

1. Início:
   ```json```
   { "method": "account/login/start", "id": 3, "params": { "type": "chatgpt" } }
   { "id": 3, "result": { "type": "chatgpt", "loginId": "<uuid>", "authUrl": "https://chatgpt.com/…&redirect_uri=http%3A%2F%2Flocalhost%3A1%2Fauth%2Fcallback" } }
   ```
2. Abra `authUrl` em um navegador; o servidor de aplicativos hospeda o callback local.
   Por padrão, uma chamada de retorno bem-sucedida redireciona para a página de sucesso local. Os clientes podem definir
   `useHostedLoginSuccessPage: true` para redirecionar callbacks bem-sucedidos que não exigem
   configuração da organização para a página de sucesso do Codex hospedado. Quando o login hospedado é bem-sucedido,
   Quando ativado, os clientes podem definir `appBrand` como `"codex"` ou `"chatgpt"` para selecionar o serviço hospedado correspondente
   arte da página; valores omitidos ou `null` assumem o valor padrão `"codex"`.
3. Aguarde as notificações:
   ```json```
   { "method": "account/login/completed", "params": { "loginId": "<uuid>", "success": true, "error": null } }
   { "method": "account/updated", "params": { "authMode": "chatgpt", "planType": "plus" } }
   ```

### 3) Faça login com uma chave da API do Amazon Bedrock

Esse fluxo experimental exige que o cliente seja inicializado com `experimentalApi: true`.

1. Enviar:
   ```json```
   {
     "método": "account/login/start",
     identificador: 3,
     "params": { "type": "amazonBedrock", "apiKey": "…", "region": "us-west-2" }
   }
   ```
2. O que esperar:
   ```json```
   { "id": 3, "result": { "type": "amazonBedrock" } }
   ```
3. Notificações:
   ```json```
   { "method": "account/login/completed", "params": { "loginId": null, "success": true, "error": null } }
   { "method": "account/updated", "params": { "authMode": "bedrockApiKey", "planType": null } }
   ```

O Codex armazena a chave e a região como a autenticação primária do Codex, substituindo qualquer login armazenado anteriormente, e grava `model_provider = "amazon-bedrock"` na configuração do usuário ativo. As sessões carregadas existentes mantêm sua seleção atual de provedor; portanto, os clientes devem reiniciar o servidor de aplicativos antes de enviar mais solicitações de modelo. Essa limitação será resolvida em uma atualização futura.

### 4) Faça login com o ChatGPT (fluxo de código do dispositivo)

1. Início:
   ```json```
   { "method": "account/login/start", "id": 4, "params": { "type": "chatgptDeviceCode" } }
   { "id": 4, "result": { "type": "chatgptDeviceCode", "loginId": "<uuid>", "verificationUrl": "https://auth.openai.com/codex/device", "userCode": "ABCD-1234" } }
   ```
2. Mostre `verificationUrl` e `userCode` ao usuário; a interface do usuário é de responsabilidade do front-end.
3. Aguarde as notificações:
   ```json```
   { "method": "account/login/completed", "params": { "loginId": "<uuid>", "success": true, "error": null } }
   { "method": "account/updated", "params": { "authMode": "chatgpt", "planType": "plus" } }
   ```

### 5) Cancelar um login no ChatGPT

```json
{ "method": "account/login/cancel", "id": 5, "params": { "loginId": "<uuid>" } }
{ "method": "account/login/completed", "params": { "loginId": "<uuid>", "success": false, "error": "…" } }
```

### 6) Sair

```json
{ "method": "account/logout", "id": 6 }
{ "id": 6, "result": {} }
{ "method": "account/updated", "params": { "authMode": null, "planType": null } }
```

Ao usar uma chave do Bedrock gerenciada pelo Codex, o logout remove a chave e zera `model_provider` caso ainda esteja definido como `"amazon-bedrock"`. Ao usar credenciais gerenciadas pela AWS, gerencie-as pela AWS ou troque de provedor antes de fazer o logout.

### 7) Limites de taxa (ChatGPT)

```json
{ "method": "account/rateLimits/read", "id": 7 }
{
  "id": 7,
  "result": {
    "rateLimits": {
      "primary": { "usedPercent": 25, "windowDurationMins": 15, "resetsAt": 1730947200 },
      "secondary": null,
      "rateLimitReachedType": null
    },
    "rateLimitResetCredits": {
      "availableCount": 2,
      "credits": [
        {
          "id": "RateLimitResetCredit_1",
          "resetType": "codexRateLimits",
          "status": "available",
          "grantedAt": 1781654400,
          "expiresAt": 1784246400,
          "title": "Full reset (Weekly + 5 hr)",
          "description": "Ready to redeem"
        }
      ]
    }
  }
}
{ "method": "account/rateLimits/updated", "params": { "rateLimits": { … } } }
```

Notas de campo:

- `usedPercent` é o consumo atual dentro do período de cota da OpenAI.
- `windowDurationMins` é o comprimento da janela de cota.
- `resetsAt` é um timestamp do Unix (em segundos) para a próxima reinicialização.
- `rateLimitReachedType` identifica o estado-limite classificado pelo backend quando um deles for atingido.
- `individualLimit` descreve o limite de crédito mensal efetivo, quando disponível. Em uma resposta `account/rateLimits/read`, `null` significa que não há limite mensal disponível. Em uma notificação `account/rateLimits/updated` incompleta, os metadados da conta que podem ser nulos podem não estar disponíveis e não apagam um valor observado anteriormente.
- `rateLimitResetCredits` contém a contagem disponível de reinicializações de pontos ganhos, quando o backend a fornece; caso contrário, é `null`.
- `rateLimitResetCredits.credits` é igual a `null` quando apenas a contagem está disponível. Um array vazio significa que os detalhes foram buscados, mas nenhum crédito disponível foi retornado.
- O backend pode limitar o valor a `rateLimitResetCredits.credits`; portanto, `availableCount` é o total oficial e pode ser maior do que o número de linhas de detalhes.
- Recuperar `account/rateLimits/read` após a aplicação de uma reinicialização.

### 8) Reinicialização do limite de taxas adquiridas (ChatGPT)

```json
{ "method": "account/rateLimitResetCredit/consume", "id": 8, "params": { "idempotencyKey": "8ae96ff3-3425-4f4c-8772-b6fd61502868", "creditId": "RateLimitResetCredit_1" } }
{ "id": 8, "result": { "outcome": "reset" } }
```

Notas de campo:

- `idempotencyKey` deve ser um valor não vazio. Recomenda-se utilizar um UUID para cada tentativa lógica de resgate; reutilize o mesmo valor ao tentar novamente essa tentativa.
- `creditId` é opcional. Quando fornecido, deve ser um ID opaco não vazio retornado por `account/rateLimits/read`; quando omitido, o backend seleciona o próximo crédito disponível.
- `reset` significa que um crédito foi consumido.
- `alreadyRedeemed` significa que o resgate já foi concluído anteriormente. Trate isso como um sucesso idempotente e atualize os limites da conta.
- `nothingToReset` significa que não há janela de limite de taxa elegível para ser reiniciada.
- `noCredit` significa que a conta não possui créditos de reinicialização acumulados disponíveis.
- Recuperar novamente `account/rateLimits/read` após aplicar uma reinicialização, em vez de inferir o estado atualizado a partir dessa resposta.

### 9) Mensagens do Workspace (ChatGPT)

```json
{ "method": "account/workspaceMessages/read", "id": 9 }
{ "id": 9, "result": { "featureEnabled": true, "messages": [
    { "messageId": "msg_123", "messageType": "headline", "messageBody": "Workspace maintenance starts at 5pm.", "createdAt": 1781395200, "archivedAt": null }
] } }
```

Quando o recurso de mensagem do espaço de trabalho upstream está desativado, `featureEnabled` é `false` e `messages` está vazio.

### 10) Notificar o proprietário de um espaço de trabalho sobre um limite

```json
{ "method": "account/sendAddCreditsNudgeEmail", "id": 9, "params": { "creditType": "credits" } }
{ "id": 9, "result": { "status": "sent" } }
```

Use `creditType: "credits"` quando os créditos do espaço de trabalho estiverem esgotados ou `creditType: "usage_limit"` quando o limite de uso do espaço de trabalho tiver sido atingido. Se o proprietário já tiver sido notificado recentemente, o status da resposta é `cooldown_active`.

## Ativação da API experimental

Alguns métodos e campos do servidor de aplicativos estão intencionalmente restritos a um recurso experimental, sem garantias de compatibilidade com versões anteriores. Isso permite que os clientes escolham entre:

- Apenas superfície estável (padrão): sem opção de adesão, sem exposição a métodos/campos experimentais.
- Superfície experimental: inscreva-se durante o período `initialize`.

### Geração de esquemas de cliente estáveis versus experimentais

`codex app-server` A geração de esquemas usa por padrão a interface da API estável (campos e métodos experimentais são filtrados). Passe `--experimental` para incluir métodos/campos experimentais no esquema TypeScript ou JSON gerado:

```bash
# Stable-only output (default)
codex app-server generate-ts --out DIR
codex app-server generate-json-schema --out DIR

# Include experimental API surface
codex app-server generate-ts --out DIR --experimental
codex app-server generate-json-schema --out DIR --experimental
```

### Como os clientes ativam a participação em tempo de execução

Defina `capabilities.experimentalApi` como `true` em sua única solicitação `initialize`:

```json
{
  "method": "initialize",
  "id": 1,
  "params": {
    "clientInfo": {
      "name": "my_client",
      "title": "My Client",
      "version": "0.1.0"
    },
    "capabilities": {
      "experimentalApi": true
    }
  }
}
```

Em seguida, envie a notificação padrão `initialized` e prossiga normalmente.

Notas:

- Se `capabilities` for omitido, `experimentalApi` será tratado como `false`.
- Essa configuração é definida uma única vez no momento da inicialização e permanece válida durante toda a duração do processo (a reinicialização é rejeitada com `"Already initialized"`).

### O que acontece se não houver consentimento expresso

Se uma solicitação utilizar um método experimental ou definir um campo experimental sem ter sido habilitada, o servidor do aplicativo a rejeita com um erro JSON-RPC. A mensagem é:

`<descriptor> requires experimentalApi capability`

Exemplos de sequências de descritores:

- `mock/experimentalMethod` (porta no nível do método)
- `thread/start.mockExperimentalField` (porta de nível de campo)
- `askForApproval.granular` (variante de enumeração gate, para `approvalPolicy: { "granular": ... }`)

### Para os mantenedores: Adição de campos e métodos experimentais

Utilize esta lista de verificação ao introduzir um campo/método que só deve estar disponível quando o cliente optar por utilizar APIs experimentais.

Durante a execução, os clientes devem enviar `initialize` com `capabilities.experimentalApi = true` para utilizar métodos ou campos experimentais.

1. Anote o campo no tipo de protocolo (geralmente `app-server-protocol/src/protocol/v2.rs`) com:
   ```tranquilidade```
   #[experimental("thread/start.myField")]
   pub my_field: Opção<String>,
   ```
2. Certifique-se de que o tipo dos parâmetros derive de `ExperimentalApi` para que o gating no nível do campo possa ser detectado em tempo de execução.

3. Em `app-server-protocol/src/protocol/common.rs`, mantenha o método estável e use `inspect_params: true` quando apenas alguns campos forem experimentais (como `thread/start`). Se todo o método for experimental, anote a variante do método com `#[experimental("method/name")]`.

As variantes de enumeração também podem ser condicionadas:

```rust
#[derive(ExperimentalApi)]
enum AskForApproval {
    #[experimental("askForApproval.granular")]
    Granular { /* ... */ },
}
```

Se um campo estável contiver um tipo aninhado que, por sua vez, possa ser experimental, marque
o campo com `#[experimental(nested)]`, de modo que `ExperimentalApi` forma bolhas no aninhado
razão até o tipo contido:

```rust
#[derive(ExperimentalApi)]
struct Config {
    #[experimental(nested)]
    approval_policy: Option<AskForApproval>,
}
```

Para cargas de solicitação iniciadas pelo servidor, anote o campo da mesma forma para que a geração do esquema o trate como experimental e certifique-se de que o servidor de aplicativos omita esse campo quando o cliente não tiver optado por `experimentalApi`.

4. Regenerar os fixtures do protocolo:

   bash
   basta escrever o esquema do servidor de aplicativos
   # Incluir campos/métodos experimentais da API nos fixtures.
   basta digitar `write-app-server-schema --experimental`
   ```

5. Verifique o crate do protocolo:

   bash
   basta digitar `test -p codex-app-server-protocol`
   ```
