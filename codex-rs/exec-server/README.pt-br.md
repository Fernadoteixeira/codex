# codex-exec-server

`codex-exec-server` é a biblioteca que sustenta `codex exec-server`, uma pequena
Servidor JSON-RPC para criar e controlar subprocessos por meio de
`codex-utils-pty`.

Estabelece o seguinte:

- um ponto de entrada da CLI: `codex exec-server`
- um cliente Rust: `ExecServerClient`
- um pequeno módulo de protocolo com tipos compartilhados de solicitação/resposta

Este crate é responsável pelos manipuladores de transporte, protocolo e sistema de arquivos/processos. O
O binário de nível superior `codex` possui um mecanismo auxiliar oculto de despacho para o ambiente isolado
operações no sistema de arquivos e `codex-linux-sandbox`.

## Transporte

O servidor envia a mensagem `codex-exec-server-protocol` específica do comando exec
envelope no fio.

O ponto de entrada da CLI oferece suporte a:

- `ws://IP:PORT` (padrão)
- `--remote URL --environment-id ID [--name NAME]`

O modo remoto registra o servidor de execução local no registro do ambiente,
em seguida, se reconecta ao WebSocket de rendezvous fornecido pelo serviço como ambiente.
A comunicação remota utiliza o contrato de retransmissão do Noise; o registro e o harness
deve apoiá-lo.
Ele utiliza o estado de login padrão do Codex ChatGPT; execute `codex login` primeiro quando
O registro remoto requer autenticação. Chamadores em contêineres que recebem um
O JWT de identidade do agente em `CODEX_ACCESS_TOKEN` pode ser incluído nesse caminho de autenticação com
`--use-agent-identity-auth`; O Codex, então, registra uma tarefa do Agente e envia o
cabeçalhos AgentAssertion derivados na solicitação de registro.

Como alternativa, os usuários da API podem usar `CODEX_API_KEY`;
O Codex o envia como um token de portador na solicitação de registro. Por exemplo:

```sh
CODEX_API_KEY="$OPENAI_API_KEY" \
codex exec-server \
  --remote ... \
  --environment-id "$ENVIRONMENT_ID"
```

Esboço em arame:

- WebSocket local: uma mensagem JSON-RPC por quadro do WebSocket
- WebSocket remoto do Noise: quadros de retransmissão protobuf binários que transportam cargas úteis criptografadas

## Formato da mensagem do relé remoto

No modo remoto, o conjunto de cabos e o ambiente se comunicam por meio de um encontro utilizando
`codex.exec_server.relay.v1.RelayMessageFrame`; o esquema registrado está em
`src/proto/codex.exec_server.relay.v1.proto`. O quadro de retransmissão transporta o fluxo
identidade e metadados de confiabilidade de propriedade do endpoint:

```text
version
stream_id
body              // handshake | data | ack_frame | resume | reset | heartbeat
ack               // highest contiguous peer segment seq received
ack_bits          // bitset for peer segment seqs after ack
seq               // data only: segment sequence number
segment_index     // data only: 0-based index within message
segment_count     // data only: number of segments in message
payload           // handshake bytes or encrypted data record
next_seq          // resume only: next sender seq
reason            // reset only: reset reason
```

`stream_id` identifica uma sessão JSON-RPC de ambiente virtual no
websocket do ambiente. O harness gera um UUIDv4 `stream_id`; o ambiente
desmultiplexa os quadros por `stream_id` e executa um `ConnectionProcessor` independente por
transmissão.

Utilize números de sequência no nível do segmento para garantir a confiabilidade:

```text
seq = 0, 1, 2, 3, ...
```

Use intervalos de sequências de segmentos contíguos para identificar e unir um segmento
mensagem do aplicativo:

```text
message_start_seq = seq - segment_index
segment_index = 0
segment_count = 1
```

`message_start_seq` é calculado pelo receptor, não é transmitido pela linha. Para
mensagens não divididas, `message_start_seq == seq`, `segment_index == 0` e
`segment_count == 1`.

Use o valor cumulativo `ack` e o valor de tamanho fixo `ack_bits` em vez de intervalos de ack variáveis:

```text
ack = highest contiguous received segment seq
bit i in ack_bits acknowledges seq = ack + 1 + i
```

Envie `ack` e `ack_bits` de forma redundante em cada quadro de saída. As confirmações de recebimento não são
eles próprios confirmam. Confirmações, novas tentativas, supressão de duplicatas, segmentação e
A remontagem é de responsabilidade dos pontos finais; as rotas de rendezvous apenas retransmitem quadros
por `stream_id`.

## Ciclo de vida

Cada conexão segue esta sequência:

1. Enviar `initialize`.
2. Aguarde a resposta `initialize`.
3. Enviar `initialized`.
4. Chamar RPCs de processo ou do sistema de arquivos.

Se o servidor receber qualquer notificação que não seja `initialized`, ele responde
ocorreu um erro ao usar o ID da solicitação `-1`.

Se a conexão WebSocket for encerrada, o servidor encerra todas as instâncias gerenciadas restantes
processos para essa conexão do cliente.

## Interface de Programação de Aplicativos

### `initialize`

Solicitação inicial de handshake.

Parâmetros da solicitação:

```json
{
  "clientName": "my-client"
}
```

Resposta:

```json
{}
```

### `initialized`

Notificação de confirmação do handshake enviada pelo cliente após um
`initialize` resposta.

Os parâmetros são ignorados no momento. O envio de qualquer outro método de notificação é tratado
como uma solicitação inválida.

### `process/start`

Inicia um novo processo gerenciado.

Parâmetros da solicitação:

```json
{
  "processId": "proc-1",
  "argv": ["bash", "-lc", "printf 'hello\\n'"],
  "cwd": "file:///absolute/working/directory",
  "env": {
    "PATH": "/usr/bin:/bin"
  },
  "tty": true,
  "pipeStdin": false,
  "arg0": null
}
```

Definições de campos:

- `processId`: identificador estável escolhido pelo chamador para este processo dentro da conexão.
- `argv`: vetor de comandos. Deve ser diferente de vazio.
- `cwd`: `file:` URI do diretório de trabalho do processo filho.
- `env`: variáveis de ambiente passadas ao processo filho.
- `tty`: quando `true`, inicia um processo interativo baseado em PTY.
- `pipeStdin`: quando `true`, mantenha o stdin não-PTY gravável por meio de `process/write`.
- `arg0`: a substituição opcional de argv0 é encaminhada para `codex-utils-pty`.

Resposta:

```json
{
  "processId": "proc-1"
}
```

Observações sobre o comportamento:

- A reutilização de um `processId` já existente é rejeitada.
- Os processos suportados pelo PTY aceitam gravações posteriores por meio de `process/write`.
- Os processos que não são PTY rejeitam gravações, a menos que `pipeStdin` seja `true`.
- A saída é transmitida de forma assíncrona por meio de `process/output`.
- A saída é notificada de forma assíncrona por meio de `process/exited`.

### `process/read`

Lê a saída armazenada em buffer e o estado do terminal de um processo gerenciado.

Parâmetros da solicitação:

```json
{
  "processId": "proc-1",
  "afterSeq": null,
  "maxBytes": 65536,
  "waitMs": 1000
}
```

Definições de campos:

- `processId`: ID do processo gerenciado retornado por `process/start`.
- `afterSeq`: cursor de número de sequência opcional; quando presente, apenas os blocos mais recentes
  são retornados.
- `maxBytes`: limite opcional de bytes da resposta.
- `waitMs`: tempo limite opcional para long-poll, em milissegundos.

Resposta:

```json
{
  "chunks": [],
  "nextSeq": 1,
  "exited": false,
  "exitCode": null,
  "closed": false,
  "failure": null
}
```

### `process/write`

Grava bytes brutos na entrada padrão (stdin) de um processo em execução.

Parâmetros da solicitação:

```json
{
  "processId": "proc-1",
  "chunk": "aGVsbG8K"
}
```

`chunk` são bytes brutos codificados em base64. No exemplo acima, é `hello\n`.

Resposta:

```json
{
  "status": "accepted"
}
```

Observações sobre o comportamento:

- As gravações em um `processId` desconhecido são rejeitadas.
- As gravações em um processo que não seja PTY são rejeitadas, a menos que tenham sido iniciadas com `pipeStdin`.

### `process/terminate`

Encerra um processo gerenciado em execução.

Parâmetros da solicitação:

```json
{
  "processId": "proc-1"
}
```

Resposta:

```json
{
  "running": true
}
```

Se o processo já for desconhecido ou já tiver sido removido, o servidor responde com:

```json
{
  "running": false
}
```

## Notificações

### `process/output`

Transmissão de um bloco de saída a partir de um processo em execução.

Para doações:

```json
{
  "processId": "proc-1",
  "seq": 1,
  "stream": "stdout",
  "chunk": "aGVsbG8K"
}
```

Campos:

- `processId`: identificador do processo
- `seq`: número de sequência de saída por processo
- `stream`: `"stdout"`, `"stderr"` ou `"pty"`
- `chunk`: bytes de saída codificados em base64

### `process/exited`

Notificação de encerramento do processo final.

Para doações:

```json
{
  "processId": "proc-1",
  "seq": 2,
  "exitCode": 0,
  "sandboxDenied": false
}
```

`sandboxDenied` permite que os clientes de streaming preservem a negação da sandbox no lado do executor
detecção sem emitir uma solicitação final `process/read`. Os clientes a recuperam
com `process/read` quando um servidor mais antigo omite o campo.

### `process/closed`

Notificação emitida após o fechamento da saída do processo e quando o identificador do processo é
removido.

Para doações:

```json
{
  "processId": "proc-1",
  "seq": 3
}
```

## RPCs do sistema de arquivos

Os métodos do sistema de arquivos exigem cadeias de caracteres URI `file:` válidas e retornam erros JSON-RPC
para caminhos inválidos ou indisponíveis. Strings de caminho absoluto nativo são rejeitadas;
os usuários devem convertê-los em URIs `file:` antes de enviar as solicitações:

- `fs/readFile`
- `fs/open`, `fs/readBlock` e `fs/close` (transporte interno para
  `ExecutorFileSystem::read_file_stream`)
- `fs/writeFile`
- `fs/createDirectory`
- `fs/getMetadata`
- `fs/canonicalize`
- `fs/readDirectory`
- `fs/remove`
- `fs/copy`

Cada solicitação do sistema de arquivos aceita um objeto `sandbox` opcional. Quando `sandbox`
contém uma política `ReadOnly` ou `WorkspaceWrite`, a operação é executada em um
processo auxiliar oculto iniciado a partir do executável de nível superior `codex` e
preparados por meio do caminho de transformação da área de teste compartilhada. Solicitações de auxílio e
As respostas são transmitidas por meio de stdin/stdout.

## Erros

O servidor retorna erros JSON-RPC com os seguintes códigos:

- `-32600`: solicitação inválida
- 0: parâmetros inválidos
- `-32603`: erro interno

Casos típicos de erro:

- método desconhecido
- parâmetros inválidos
- vazio `argv`
- duplicado `processId`
- grava em processos desconhecidos
- grava em processos que não são do PTY
- Operações no sistema de arquivos com acesso negado na sandbox

## Superfície enferrujada

A caixa exporta:

- `ExecServerClient`
- `ExecServerError`
- `ExecServerClientConnectOptions`
- `RemoteExecServerConnectArgs`
- estruturas de solicitação/resposta de protocolo para RPCs de processos e do sistema de arquivos
- `DEFAULT_LISTEN_URL` e `ExecServerListenUrlParseError`
- `ExecServerRuntimePaths`
- `run_main()` para a integração do servidor WebSocket
- `RemoteEnvironmentConfig` e `run_remote_environment()` para integração remota
  modo de registro

Os chamadores devem passar `ExecServerRuntimePaths` e um
`HttpClientFactory` a `run_main()`. O comando de nível superior `codex exec-server`
construi esses caminhos a partir do estado de despacho `codex` arg0 e resolve sua solicitação HTTP
fábrica de clientes a partir da configuração efetiva do Codex.
`RemoteEnvironmentConfig::new(...)` também utiliza o provedor de autenticação e o cliente HTTP
fábrica que o modo de registro remoto deve utilizar; a CLI cria a autenticação
provedor do estado de autenticação do Codex antes de iniciar o modo remoto.

## Exemplo de sessão

Inicializar:

```json
{"id":1,"method":"initialize","params":{"clientName":"example-client"}}
{"id":1,"result":{}}
{"method":"initialized","params":{}}
```

Iniciar um processo:

```json
{"id":2,"method":"process/start","params":{"processId":"proc-1","argv":["bash","-lc","printf 'ready\\n'; while IFS= read -r line; do printf 'echo:%s\\n' \"$line\"; done"],"cwd":"file:///tmp","env":{"PATH":"/usr/bin:/bin"},"tty":true,"pipeStdin":false,"arg0":null}}
{"id":2,"result":{"processId":"proc-1"}}
{"method":"process/output","params":{"processId":"proc-1","seq":1,"stream":"stdout","chunk":"cmVhZHkK"}}
```

Gravar no processo:

```json
{"id":3,"method":"process/write","params":{"processId":"proc-1","chunk":"aGVsbG8K"}}
{"id":3,"result":{"status":"accepted"}}
{"method":"process/output","params":{"processId":"proc-1","seq":2,"stream":"stdout","chunk":"ZWNobzpoZWxsbwo="}}
```

Encerre isso:

```json
{"id":4,"method":"process/terminate","params":{"processId":"proc-1"}}
{"id":4,"result":{"running":true}}
{"method":"process/exited","params":{"processId":"proc-1","seq":3,"exitCode":0,"sandboxDenied":false}}
{"method":"process/closed","params":{"processId":"proc-1","seq":4}}
```
