# codex-core

Este crate implementa a lógica de negócios do Codex. Ele foi projetado para ser utilizado pelas diversas interfaces de usuário do Codex escritas em Rust.

## Testes de integração do Wine-exec

No Linux x86-64, execute o conjunto de testes compartilhado no servidor executável do Windows com
`bazel test //codex-rs/core:core-all-wine-exec-test`.

A execução local é direcionada ao sistema operacional do host, o Docker é direcionado ao Linux e a execução via Wine é direcionada a
Windows. Escolha a macro de ignoração de acordo com o que o teste depende:

- `skip_if_target_windows!`: Comportamento do destino no Windows.
- `skip_if_host_windows!`: Restrições do host do Windows.
- `skip_if_remote!`: Comportamento de teste apenas local.
- `skip_if_no_remote_env!`: Comportamento do teste exclusivamente remoto.
- `skip_if_wine_exec!`: Dívida específica do setor vinícola.

## Dependências

Observe que o `codex-core` parte de algumas premissas quanto à disponibilidade de determinados utilitários auxiliares no ambiente. Atualmente, essa matriz de suporte é a seguinte:

### macOS

Espera que `/usr/bin/sandbox-exec` esteja presente.

Ao utilizar a política de sandbox “workspace-write”, o perfil Seatbelt permite
grava nos diretórios-raiz configurados como graváveis, mantendo `.git` (diretório ou
arquivo de ponteiro), o destino `gitdir:` resolvido e `.codex` somente leitura.

O acesso à rede e os diretórios raiz de leitura/gravação do sistema de arquivos são controlados por
`SandboxPolicy`. O Seatbelt utiliza a política definida e a aplica.

O Seatbelt também mantém o acesso de leitura às preferências padrão herdadas
(`user-preference-read`) necessário para o comportamento do macOS baseado no cfprefs.

### Linux

Espera que o binário que contém `codex-core` execute o equivalente a `codex sandbox` quando `arg0` for `codex-linux-sandbox`. Consulte o crate `codex-arg0` para obter mais detalhes.

As configurações antigas `SandboxPolicy` / `sandbox_mode` ainda são compatíveis no Linux.
Eles podem continuar usando o caminho Landlock antigo quando o sistema de arquivos estiver dividido
Essa política é equivalente, em termos de sandbox, ao modelo legado após a resolução `cwd`.
Políticas de sistema de arquivos particionado que exigem acesso direto `FileSystemSandboxPolicy`
medidas de aplicação, tais como restrições de “somente leitura” ou “negadas” no âmbito de uma permissão mais ampla de gravação
root, encaminha automaticamente pelo bubblewrap. É utilizado o caminho Landlock antigo
somente quando a política de sistema de arquivos dividido passar pelo sistema legado
`SandboxPolicy` modelo sem alterar a semântica. Isso inclui sobreposições
casos como `/repo = write`, `/repo/a = none`, `/repo/a/b = write`, em que o
Um documento filho mais específico e gravável deve ser reaberto sob um documento pai cuja solicitação foi negada.

O auxiliar de sandbox do Linux prefere o primeiro `bwrap` encontrado em `PATH` fora do
diretório de trabalho atual, sempre que estiver disponível. Se `bwrap` estiver presente, mas
por ser muito antigo para suportar `--argv0`, o auxiliar continua usando o bubblewrap do sistema e
muda para um caminho de compatibilidade sem `--argv0` para o re-exec interno. Se
Se `bwrap` estiver ausente, o sistema recorre ao `codex-resources/bwrap` incluído no pacote
O arquivo binário é fornecido com o Codex, e o Codex exibe um aviso na inicialização por meio de seu
caminho normal de notificação, em vez de imprimir diretamente a partir do auxiliar da área de teste.
O Codex também exibe um aviso na inicialização quando o bubblewrap não consegue criar um usuário
espaços de nomes. O WSL2 usa o caminho padrão do `bubblewrap` do Linux. O WSL1 não é compatível
para o sandboxing com bubblewrap, pois ele não consegue criar o usuário necessário
espaços de nomes; por isso, o Codex rejeita comandos de shell em ambiente isolado que entrariam no
trajetória do plástico-bolha antes de chamar `bwrap`.

### Windows

As configurações antigas `SandboxPolicy` / `sandbox_mode` ainda são compatíveis com
Windows. As políticas legadas `read-only` e `workspace-write` implicam total
acesso de leitura ao sistema de arquivos; as raízes exatas que podem ser lidas são representadas por “split”
em vez disso, políticas do sistema de arquivos.

A sandbox elevada do Windows também oferece suporte a:

- Comportamento dos parâmetros `ReadOnly` e `WorkspaceWrite` do sistema legado
- políticas de sistema de arquivos particionado que exigem diretórios-raiz exatos para leitura e diretórios exatos para gravação
  raízes ou seções adicionais somente leitura sob raízes graváveis
- diretórios de leitura gerenciados pelo backend necessários para a execução básica, tais como
  `C:\Windows`, `C:\Program Files`, `C:\Program Files (x86)` e
  `C:\ProgramData`, quando uma política de sistema de arquivos dividido solicita os padrões da plataforma

O backend de tokens restritos não elevado ainda oferece suporte à leitura completa legada
Modelo do Windows para o comportamento dos modelos antigos `ReadOnly` e `WorkspaceWrite`. Ele também
suporta um subconjunto restrito de sistemas de arquivos divididos: políticas de divisão com leitura total cujas
As raízes graváveis ainda correspondem ao conjunto de raízes legado `WorkspaceWrite`, mas acrescentam
subdiretórios somente leitura dentro dessas raízes graváveis.

As novas políticas de sistema de arquivos `[permissions]` / split continuam sendo compatíveis com o Windows
somente quando puderem ser aplicadas diretamente pelo backend do Windows selecionado ou
passagem pelo modelo legado `SandboxPolicy` sem alterar a semântica.
Políticas que exigissem exceções diretas, explícitas e ilegíveis (`none`) ou
Descendentes reabertos como graváveis sob exceções de somente leitura continuam apresentando falha (fechado)
em vez de adotar uma fiscalização mais fraca.

### Todas as plataformas

Espera que o binário contendo `codex-core` simule o virtual
`apply_patch` CLI quando `arg1` é `--codex-run-as-apply-patch`. Consulte o
`codex-arg0` caixa para mais detalhes.
