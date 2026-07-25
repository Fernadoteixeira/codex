# codex-linux-sandbox

Esta caixa é responsável pela produção de:

- um executável autônomo `codex-linux-sandbox` para Linux que vem junto com a versão Node.js da CLI do Codex
- uma biblioteca que expõe a lógica de negócios do executável como `run_main()`, de modo que
  - A CLI `codex-exec` pode verificar se seu argumento 0 é `codex-linux-sandbox` e, nesse caso, executar como se fosse `codex-linux-sandbox`
  - isso também deveria se aplicar à CLI da ferramenta multifuncional `codex`

No Linux, o Codex dá preferência ao primeiro `bwrap` encontrado em `PATH`
fora do diretório de trabalho atual, sempre que estiver disponível. Se `bwrap` for
está presente, mas é muito velho para dar suporte
`--argv0`, o helper continua usando o bubblewrap do sistema e muda para um
caminho de compatibilidade “no-`--argv0`” para a reexecução interna. Se `bwrap` estiver ausente,
o helper recorre ao binário `codex-resources/bwrap` incluído no pacote
com o Codex.
O Codex também exibe um aviso na inicialização quando `bwrap` está faltando, para que os usuários fiquem cientes disso
está recorrendo ao helper integrado. O Codex exibe o mesmo aviso de inicialização
caminho a ser seguido quando o bubblewrap não consegue criar espaços de nome do usuário. O WSL2 segue o procedimento normal
Caminho do bubblewrap no Linux. O WSL1 não é compatível com o sandboxing do bubblewrap porque
ele não consegue criar os espaços de nome de usuário necessários; por isso, o Codex rejeita o shell em ambiente isolado
comandos que entrariam no caminho do bubblewrap.

**Comportamento atual**
- As configurações antigas `SandboxPolicy` / `sandbox_mode` continuam sendo suportadas.
- O Bubblewrap é a sandbox padrão do sistema de arquivos.
- Se o arquivo `bwrap` estiver presente no diretório `PATH`, fora do diretório de trabalho atual, o
  o helper o utiliza.
- Se `bwrap` estiver presente, mas for muito antigo para suportar `--argv0`, o auxiliar utiliza um
  Caminho de compatibilidade no-`--argv0` para a reexecução interna.
- Se `bwrap` estiver ausente, o helper recorre ao recurso incluído no pacote
  `codex-resources/bwrap` caminho.
- Se `bwrap` estiver ausente, o Codex também exibe um aviso na inicialização, em vez de
  imprimir diretamente a partir do auxiliar da área de teste.
- Se o bubblewrap não conseguir criar espaços de nome de usuário, o Codex exibe um aviso na inicialização
  em vez de esperar por uma falha na sandbox de tempo de execução.
- O WSL2 utiliza o caminho padrão do `bubblewrap` do Linux.
- O WSL1 não é compatível com o sandboxing do bubblewrap; o Codex rejeita o sandboxing
  comandos do shell que exigiriam o caminho do bubblewrap antes de chamar o `bwrap`.
- As proteções do Landlock + de montaria do sistema antigo continuam disponíveis como um recurso explícito do sistema antigo
  caminho alternativo.
- Defina `features.use_legacy_landlock = true` (ou CLI `-c use_legacy_landlock=true`)
  para forçar o uso do mecanismo alternativo “Landlock” antigo.
- O mecanismo alternativo Landlock legado é utilizado apenas quando a política de divisão do sistema de arquivos é
  equivalente ao modelo antigo após a resolução `cwd`.
- Políticas de sistema de arquivos exclusivamente de divisão que não passam pelo sistema legado
  `SandboxPolicy` o modelo permanece no plástico-bolha, portanto, aninhado como “somente leitura” ou negado
  as exceções são mantidas.
- Quando o bubblewrap está ativo, o helper aplica `PR_SET_NO_NEW_PRIVS` e um
  Filtro de rede seccomp em execução.
- Quando o bubblewrap está ativo, o sistema de arquivos fica, por padrão, somente para leitura por meio de `--ro-bind / /`.
- Quando o bubblewrap está ativo, as raízes graváveis são sobrepostas com `--bind <root> <root>`.
- Quando o bubblewrap está ativo, os subcaminhos protegidos sob raízes graváveis (para
  exemplo `.git`,
  resolvidos `gitdir:` e `.codex`) são reaplicados como somente leitura por meio de `--ro-bind`.
- Quando o “bubblewrap” está ativo, ocorre sobreposição de políticas divididas
  as entradas são aplicadas na ordem de especificidade de caminho; portanto, os filhos graváveis com especificidade mais restrita
  pode reabrir diretórios-pai mais amplos com acesso somente leitura ou negado, enquanto subcaminhos mais restritos com acesso negado
  ainda assim vencem. Por exemplo, `/repo = write`, `/repo/a = none`, `/repo/a/b = write`
  mantém `/repo` como gravável, nega `/repo/a` e reabre `/repo/a/b` como
  novamente gravável.
- Quando o bubblewrap está ativado, as entradas glob ilegíveis são expandidas antes de
  Ao iniciar a sandbox, os arquivos correspondentes são protegidos com plástico-bolha:

  ```texto
  Preferir:   rg --files --hidden --no-ignore --glob <pattern> -- <search-root>
  Solução alternativa: rastreador interno de conjuntos globais quando o rg não estiver instalado
  Falha: qualquer outra falha no rg interrompe a construção da sandbox
  ```

  Os usuários podem definir um limite para a profundidade da verificação por perfil de permissões:

  ```toml```
  [permissions.workspace.filesystem]
  glob_scan_max_depth = 2

  [permissions.workspace.filesystem.":workspace_roots"]
  "**/*.env" = "nenhum"
  ```

- Quando o bubblewrap está ativo, links simbólicos no caminho e caminhos protegidos inexistentes dentro de
  as raízes graváveis são bloqueadas pela montagem `/dev/null` no link simbólico ou no primeiro
  componente ausente.
- Quando o bubblewrap está ativo, o helper isola explicitamente o namespace do usuário por meio de
  `--unshare-user` e o namespace PID por meio de `--unshare-pid`.
- Quando o bubblewrap está ativo e a rede está restrita sem roteamento por proxy, o helper também
  isola o namespace de rede por meio de `--unshare-net`.
- No modo de proxy gerenciado, o auxiliar utiliza `--unshare-net` mais um
  Ponte de roteamento TCP->UDS->TCP para que o tráfego da ferramenta chegue apenas ao proxy configurado
  pontos finais.
- No modo de proxy gerenciado, depois que a ponte estiver ativa, o seccomp bloqueia novos
  Criação de AF_UNIX/socketpair para o comando do usuário.
- Quando o bubblewrap está ativo, ele monta um novo `/proc` por meio de `--proc /proc` por padrão, mas
  Você pode ignorar isso em ambientes de contêiner restritivos com `--no-proc`.

**Notas**
- A superfície da CLI é `codex sandbox`; o sistema operacional do host seleciona o backend da sandbox.
