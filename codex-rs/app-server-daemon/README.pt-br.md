# codex-app-server-daemon

> `codex-app-server-daemon` é experimental e seu contrato de ciclo de vida pode
> alterar enquanto o fluxo de gerenciamento remoto ainda estiver em desenvolvimento.

`codex-app-server-daemon` serve de base para o `codex app-server` legível por máquina
comandos de ciclo de vida utilizados por clientes remotos, como os aplicativos para desktop e dispositivos móveis.
Ele se destina a instâncias do Codex iniciadas via SSH, incluindo instâncias recém-criadas para desenvolvedores
máquinas que devem disponibilizar o servidor de aplicativos com a opção `remote_control` ativada.

## Suporte a plataformas

A implementação atual do daemon é exclusiva para o Unix. Ela utiliza um sistema baseado em arquivo de PID
daemonização, além de primitivas de processos e bloqueio de arquivos do Unix, e ainda não
oferecer suporte ao gerenciamento do ciclo de vida do Windows.

## Comandos

```sh
codex app-server daemon start
codex app-server daemon restart
codex app-server daemon enable-remote-control
codex app-server daemon disable-remote-control
codex app-server daemon stop
codex app-server daemon version
codex app-server daemon bootstrap --remote-control
```

Se for bem-sucedido, cada comando grava exatamente um objeto JSON na saída padrão (stdout). Consumidores
deveria analisar esse JSON em vez de depender de texto legível por humanos. Ciclo de vida
As respostas informam o backend resolvido, o caminho do soquete, a versão local da CLI e
versão do servidor de aplicativos em execução, quando aplicável.

## Fluxo de inicialização

Para uma nova máquina remota:

```sh
curl -fsSL https://chatgpt.com/codex/install.sh | sh
$HOME/.codex/packages/standalone/current/codex app-server daemon bootstrap --remote-control
```

`bootstrap` requer a instalação autônoma gerenciada. Ele registra o daemon
configurações em `CODEX_HOME/app-server-daemon/`, inicia o servidor de aplicativos como um
processo independente baseado em um arquivo PID e inicia um ciclo de atualização independente.

## Casos de instalação e atualização

O daemon presume que o Codex está instalado por meio do `install.sh` e sempre inicia
o binário autônomo gerenciado em `CODEX_HOME`.

| Localização | O que começa | Esse daemon baixa novos binários? | Um servidor de aplicativos em execução acaba atualizando-se automaticamente para uma versão mais recente do binário? |
| --- | --- | --- | --- |
| O `install.sh` foi executado, mas apenas o `start` é utilizado | O `start` usa `CODEX_HOME/packages/standalone/current/codex` | De | Não. O caminho gerenciado é usado ao iniciar ou reiniciar, mas nenhum programa de atualização é instalado. |
| Se o `install.sh` tiver sido executado, então o `bootstrap` é utilizado | O backend do arquivo PID utiliza `CODEX_HOME/packages/standalone/current/codex` | Sim. O Bootstrap inicia um ciclo de atualização independente que executa o `install.sh` a cada hora. | Sim, enquanto esse processo de atualização estiver ativo e o servidor de aplicativos já estiver em execução. Após uma busca bem-sucedida, o atualizador reinicia o servidor de aplicativos com o binário atualizado e só então substitui a imagem do seu próprio processo. |
| Alguma outra ferramenta atualiza o caminho do binário gerenciado | Na próxima inicialização ou reinicialização, o arquivo atualizado nesse caminho será utilizado | Somente se o `bootstrap` estiver ativo, pois o atualizador ainda executa o `install.sh` em sua frequência normal. | Sem o `bootstrap`, não. Com o `bootstrap`, a próxima execução bem-sucedida do atualizador compara o conteúdo do binário gerenciado após a execução do `install.sh`; se o servidor de aplicativos estiver em execução e houver diferenças em relação à imagem atual do atualizador, ele atualiza primeiro o servidor de aplicativos e, em seguida, a si mesmo. |

### Instalações autônomas

Para instalações criadas por `install.sh`:

- Os comandos de ciclo de vida sempre utilizam o caminho do binário autônomo gerenciado
- `bootstrap` é compatível
- `bootstrap` inicia um ciclo de atualização independente, baseado em PID, que busca os dados por meio de
  `install.sh`
- Após uma atualização bem-sucedida, se o servidor de aplicativos estiver em execução e o binário gerenciado
  Se o conteúdo for alterado, o atualizador reinicia o servidor de aplicativos com esse binário primeiro e
  só então substitui sua própria imagem de processo
- O ciclo do atualizador não é persistente após a reinicialização; ele deve ser reiniciado por
  executando novamente `bootstrap` após uma reinicialização

### Atualizações fora da banda

Este daemon não monitora arquivos executáveis arbitrários para verificar se houve substituição. Se algum
outra ferramenta atualiza o caminho do binário gerenciado:

- sem `bootstrap`, um servidor de aplicativos atualmente em execução permanece na versão antiga
  imagem executável até um `restart` explícito
- com `bootstrap`, o loop de atualização independente detecta a alteração no objeto gerenciado
  binário na sua próxima passagem programada bem-sucedida após a execução de `install.sh`; se
  O app-server está em execução; ele atualiza primeiro o app-server e, em seguida, atualiza a si mesmo
  assim que essa substituição for iniciada com sucesso

## Semântica do ciclo de vida

`start` é idempotente e retorna assim que o servidor de aplicativos estiver pronto para responder normalmente
O JSON-RPC inicia o handshake no soquete de controle do Unix.

`restart` encerra qualquer daemon gerenciado e o reinicia.

`enable-remote-control` e `disable-remote-control` mantêm a configuração de inicialização
para futuras inicializações. Se um servidor de aplicativos gerenciado já estiver em execução, eles o reiniciam
Assim, a nova configuração entra em vigor imediatamente.

Os bootstraps de nível superior `codex remote-control` com `--remote-control` quando o
O loop do atualizador não está em execução. Caso contrário, ele habilita o controle remoto e inicia o
daemon normalmente.

`stop` envia primeiro uma solicitação de encerramento ordenado e, em seguida, envia uma segunda
sinal de encerramento após o período de tolerância, caso o processo ainda esteja ativo.

Todos os comandos do ciclo de vida que sofrem mutação são serializados por `CODEX_HOME`, portanto, uma operação simultânea
`start`, `restart`, `enable-remote-control`, `disable-remote-control`, `stop`,
ou `bootstrap` não entra em conflito com outra operação do ciclo de vida em andamento.

## Estado

O daemon armazena seu estado local em `CODEX_HOME/app-server-daemon/`:

- `settings.json` para configurações de inicialização salvas
- `app-server.pid` para o registro do processo do servidor de aplicativos
- `app-server-updater.pid` para o ciclo do atualizador autônomo baseado em PID
- `daemon.lock` para serialização do ciclo de vida em todo o daemon
