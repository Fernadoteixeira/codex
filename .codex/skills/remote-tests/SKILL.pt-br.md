---
name: remote-tests
description: Testing against remote executors in integration tests.
---

Os testes de executor remoto verificam a separação entre o servidor de aplicativos e o servidor de execução para garantir que os recursos do agente funcionem
tanto em ambientes de execução locais quanto remotos.

Atualmente, os testes do executor remoto exigem uma máquina host Linux x86_64. Existem duas variantes:

1. Docker (servidor exec do Linux)
2. Wine (servidor executável do Windows)

## Dispositivos de teste

Cada caso de teste deve ser explicitamente configurado para ser executado em um executor remoto.

### Código principal

Use `TestCodexBuilder::build_with_auto_env()` para habilitar a execução remota na integração principal
testes, a menos que o teste exija um controle mais preciso sobre quem o executa.

### servidor de aplicativos

Inicie o servidor com `TestAppServer::new_with_auto_env()`, a menos que o teste defina seu próprio
`$CODEX_HOME/environments.toml` ou definirá ambientes personalizados em tempo de execução.

Comece os tópicos com `TestAppServer::send_thread_start_request_with_auto_env()` se você tiver criado o
servidor com a abordagem `auto_env`. Omita `ThreadStartParams.environments` (deixe como `None`) quando
fazendo isso.

## Navio de teste

Se um teste não for aprovado em uma determinada configuração de executor remoto, você pode ignorá-lo apenas nessa configuração
configuração. Inclua uma justificativa em forma de string para futuros leitores, caso a macro de ignoração selecionada suporte
um.

Escolha a macro de ignoração com base no motivo pelo qual o teste falha:

- `skip_if_target_windows!`: Comportamento do destino no Windows.
- `skip_if_wine_exec!`: Restrições do executável do Wine.
- `skip_if_host_windows!`: Restrições do host do Windows.
- `skip_if_remote!`: Comportamento de teste apenas local.
- `skip_if_no_remote_env!`: Comportamento do teste exclusivamente remoto.

É preferível definir testes que sejam executados em todas as configurações de host/destino por padrão. Consulte o `$path-types`
conhecimento das alterações mais comuns necessárias para tornar os testes compatíveis.

## Docker

O contêiner do Docker é criado e inicializado por meio do arquivo ./scripts/test-remote-env.sh. Ao executar esse script
No Bash, também há a função `codex_remote_env_cleanup`, que pode ser usada após o teste.

Para executar testes de integração essenciais em um executor remoto do Docker:

```bash
bash -c '
  set -euo pipefail
  unset CODEX_TEST_REMOTE_EXEC_SERVER_URL
  source scripts/test-remote-env.sh
  trap codex_remote_env_cleanup EXIT

  cd codex-rs
  just test -p codex-core --test all
'
```

Para executar testes de integração do servidor de aplicativos em um executor remoto do Docker:

```bash
bash -c '
  set -euo pipefail
  unset CODEX_TEST_REMOTE_EXEC_SERVER_URL
  source scripts/test-remote-env.sh
  trap codex_remote_env_cleanup EXIT

  cd codex-rs
  just test -p codex-app-server --test all
'
```

## Vinho

Esses testes criam um servidor de execução para Windows e o executam no Wine, enquanto o servidor de aplicativos permanece em
o host Linux. A dependência de compilação multiplataforma significa que elas só rodam no Bazel.

Para os testes de integração principais:

```sh
bazel test //codex-rs/core:core-all-wine-exec-test
```

Para testes de integração do servidor de aplicativos:

```sh
bazel test //codex-rs/app-server:app-server-all-wine-exec-test
```

## Devboxes

Você pode usar um devbox para executar esses testes se estiver trabalhando em um computador com macOS.

Você pode listar as devboxes usando o comando `applied_devbox ls` e escolher aquela que tiver `codex` no nome.
Conecte-se ao devbox pelo `ssh <devbox_name>`.
Reutilize o mesmo checkout do Codex em `~/code/codex`. Reinicie os arquivos, se necessário. Vários checkouts demoram mais para serem compilados e ocupam mais espaço.
Verifique se o SHA e os arquivos modificados estão sincronizados entre o servidor remoto e o local.
