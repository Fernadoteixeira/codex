# Cliente de teste do servidor de aplicativos
Guia rápido para executar e pressionar `codex app-server`.

## Guia rápido

Inicie a partir de `<reporoot>/codex-rs`.

```bash
# 1) Build debug codex binary
cargo build -p codex-cli --bin codex

# 2) Start websocket app-server in background
cargo run -p codex-app-server-test-client -- \
  --codex-bin ./target/debug/codex \
  serve --listen ws://127.0.0.1:4222 --kill

# 3) Call app-server (defaults to ws://127.0.0.1:4222)
cargo run -p codex-app-server-test-client -- model-list
```

`send-message` e `send-message-v2` processam as solicitações do servidor `request_user_input` de forma interativa.
Quando o Codex fizer uma pergunta, escolha uma opção numerada (ou `o` para uma resposta livre, quando essa opção estiver disponível)
e o cliente enviará a resposta e continuará a transmissão no mesmo turno.

## Testando o login no Amazon Bedrock gerenciado pelo Codex

`test-login --amazon-bedrock` inicializa a API experimental do servidor de aplicativos e envia um
`account/login/start` solicitação com uma chave da API do Amazon Bedrock e aguarda a
Notificações `account/login/completed` e `account/updated`. O login substitui o principal atual
credencial e define `model_provider = "amazon-bedrock"`; portanto, use um `CODEX_HOME` isolado quando
teste.

```bash
export CODEX_HOME="$(mktemp -d)"
printf 'cli_auth_credentials_store = "file"\n' > "$CODEX_HOME/config.toml"

cargo build -p codex-cli --bin codex
cargo run -p codex-app-server-test-client -- \
  --codex-bin ./target/debug/codex \
  test-login \
  --amazon-bedrock \
  --api-key "<BEDROCK_API_KEY>" \
  --region us-west-2
```

O cliente de teste suprime `apiKey` do seu registro de solicitações enviadas. Após o login, inicie um novo Codex
execute o processo com o mesmo `CODEX_HOME` para verificar se ele utiliza a credencial gerenciada armazenada.

## Teste de logout

`test-logout` inicializa o servidor de aplicativos, envia uma solicitação `account/logout` e aguarda a
notificação resultante `account/updated`. Ela utiliza o `CODEX_HOME` ativo; portanto, direcione-a para um
diretório isolado ao testar a limpeza de credenciais.

```bash
cargo run -p codex-app-server-test-client -- \
  --codex-bin ./target/debug/codex \
  test-logout
```

## Análise do plugin de testes

O comando `plugin-analytics-smoke` executa o plugin `plugin/installed`
ativar/desativar gravações de configuração e uma referência estruturada ao plug-in por meio de um
conexão com o servidor de aplicativos. As métricas são registradas em um arquivo JSONL local e são
não são enviadas ao backend de análise. O modelo, por sua vez, utiliza respostas de loopback
Servidor de API.

O plug-in selecionado já deve estar instalado e ativado remotamente, e o
O perfil ativo do Codex deve ser autenticado. Em um cache local vazio, o comando
repete as tentativas de conexão temporárias enquanto o pacote remoto instalado conclui a sincronização.

```bash
# Build a debug Codex binary; analytics capture is unavailable in release builds.
cargo build -p codex-cli --bin codex

cargo run -p codex-app-server-test-client -- \
  --codex-bin ./target/debug/codex \
  plugin-analytics-smoke \
  --plugin-id linear@openai-curated-remote
```

Use `--capture-file /tmp/plugin-analytics.jsonl` para selecionar o caminho de saída.
O comando valida os valores `codex_plugin_disabled`, `codex_plugin_enabled` e
`codex_plugin_used` evento com as identidades esperadas dos plug-ins locais e remotos
e metadados de capacidade. Cada evento inclui o ID local em `plugin_id` e o
ID do backend em `remote_plugin_id`. Os eventos de ativação e desativação provêm de
gravações bem-sucedidas na configuração temporária; o comando não altera o
estado com acesso remoto ativado. Ele exibe os eventos e mantém o arquivo JSONL no local
para inspeção. Ele não instala nem desinstala plug-ins e não modifica
a configuração persistente do perfil.

### Testando análises de instalação e desinstalação remotas

`plugin-analytics-mutation-smoke` é um teste de fumaça ao vivo executado manualmente. Ele
entra em contato com a API do plug-in remoto configurada e altera temporariamente o ativo
estado dos plug-ins instalados na conta. Não é executado por `cargo test`, `just test`,
ou CI.

Escolha um plug-in remoto que esteja disponível para a conta ativa e que não seja
instalado no momento. O comando não é executado quando o plug-in já está
instala, instala o programa, valida `codex_plugin_installed`, desinstala e
valida `codex_plugin_uninstalled` e verifica se o original
O estado de desinstalação foi restaurado.

Os eventos de mutação incluem o ID local do Codex em `plugin_id` e o ID do backend
e `remote_plugin_id`.

`--remote-plugin-id` utiliza o ID do backend, como `plugins~Plugin_...`, e não o
ID local 00.

```bash
cargo run -p codex-app-server-test-client -- \
  --codex-bin ./target/debug/codex \
  plugin-analytics-mutation-smoke \
  --remote-plugin-id <REMOTE_PLUGIN_ID> \
  --confirm-account-mutation \
  --capture-file /tmp/plugin-mutation-analytics.jsonl
```

A análise utiliza a fila normal, a redução, o processamento em lote e o caminho de serialização,
mas o destino da captura de depuração suprime a entrega à rede de análise. O
O comando exibe um destes estados finais:

- `PASS`: os eventos de instalação e desinstalação foram validados e o plug-in foi desinstalado.
- `FAIL-CLEAN`: falha na validação, mas o estado original de desinstalação era
  restaurado.
- `FAIL-LOCAL-CACHE`: o backend foi desinstalado, mas foi relatada uma limpeza local
  um erro.
- `FAIL-DIRTY`: a limpeza falhou e o plug-in ainda aparece como instalado.
- `FAIL-UNKNOWN`: o comando não conseguiu verificar o estado final da instalação.

Se o resultado estiver incorreto ou duvidoso, tente novamente a limpeza com:

```bash
cargo run -p codex-app-server-test-client -- \
  --codex-bin ./target/debug/codex \
  plugin-remote-uninstall \
  --remote-plugin-id <REMOTE_PLUGIN_ID> \
  --confirm-account-mutation
```

A limpeza não requer a captura de dados analíticos nem um binário do Codex de depuração. Quando o
O smoke utiliza substituições globais `--config`; seu comando de recuperação exibido preserva
para que a limpeza tenha como alvo o mesmo backend e a mesma conta.

## Monitorando o tráfego de entrada bruto

Inicialize uma conexão e, em seguida, exiba todas as mensagens JSON-RPC recebidas até interromper o processo com
`Ctrl+C`:

```bash
cargo run -p codex-app-server-test-client -- watch
```

## Testando o comportamento de reintegração de threads

Compile e inicie um servidor de aplicativos usando os comandos acima. O log do servidor de aplicativos é gravado em `/tmp/codex-app-server-test-client/app-server.log`

### 1) Obter o ID do tópico

Crie pelo menos um tópico e, em seguida, liste os tópicos:

```bash
cargo run -p codex-app-server-test-client -- send-message-v2 "seed thread for rejoin test"
cargo run -p codex-app-server-test-client -- thread-list --limit 5
```

Copie o ID do tópico da saída `thread-list`.

### 2) Retornar à partida enquanto um turno está em andamento (dois terminais)

Terminal A:

```bash
cargo run --bin codex-app-server-test-client -- \
  resume-message-v2 <THREAD_ID> "respond with thorough docs on the rust core"
```

Terminal B (enquanto o Terminal A ainda está transmitindo):

```bash
cargo run --bin codex-app-server-test-client -- thread-resume <THREAD_ID>
```
