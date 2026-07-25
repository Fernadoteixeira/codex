# Autenticação

Para obter informações sobre a autenticação da Codex CLI, consulte [esta documentação](https://developers.openai.com/codex/auth).

# Autenticação

## Autenticação OpenAI

<a id="sign-in-with-chatgpt"></a>

O Codex suporta duas formas de autenticação ao utilizar modelos da OpenAI:

- Entrar com o ChatGPT para acesso baseado em assinatura
- Entrar com uma chave de API para acesso baseado no consumo

O aplicativo de desktop do ChatGPT, a Codex CLI e a extensão de IDE suportam ambos os métodos de login para trabalho local. A nuvem do Codex exige o login com o ChatGPT.

O seu método de login também determina quais controles administrativos e políticas de tratamento de dados se aplicam:

- Quando você entra com o ChatGPT, o uso do Codex segue as permissões do seu workspace do ChatGPT, controle de acesso baseado em função (RBAC) e as configurações de retenção e residência do ChatGPT Enterprise.
- Com uma chave de API, o uso segue as configurações de retenção e compartilhamento de dados da sua organização na plataforma API.

Para workspaces gerenciados, a autenticação é apenas uma camada de acesso. A associação e o provisionamento do workspace determinam quem pode entrar, enquanto os assentos (seats) e as funções no workspace determinam quais superfícies e recursos de produtos podem ser utilizados. Para trabalho local no aplicativo ChatGPT desktop, Codex CLI ou extensão IDE, os perfis de permissão restringem o que o agente pode fazer no dispositivo. Consulte [Grupos e provisionamento](https://learn.chatgpt.com/docs/enterprise/groups-and-provisioning) e [Funções e permissões de workspace](https://learn.chatgpt.com/docs/enterprise/roles-and-workspace-permissions) para planejar esses controles.

### Entrar com o ChatGPT

Quando você entra com o ChatGPT a partir do aplicativo ChatGPT desktop, da Codex CLI ou da extensão IDE, o fluxo de login abre uma janela do navegador. Após você autenticar, o navegador retorna suas credenciais para o Codex.

#### Codex CLI

Execute `codex login` e conclua o fluxo no navegador. Este é o caminho de autenticação padrão quando nenhuma sessão válida estiver disponível.

<a id="sign-in-with-an-api-key"></a>

### Entrar com uma chave de API

Você também pode se autenticar no aplicativo ChatGPT desktop, Codex CLI ou extensão IDE usando uma chave de API. Obtenha sua chave de API no [painel da OpenAI](https://platform.openai.com/api-keys).

#### Codex CLI

Passe a chave para o `codex login` através do stdin:

```shell
printenv OPENAI_API_KEY | codex login --with-api-key
```

A OpenAI cobra o uso da chave de API através da sua conta na Plataforma OpenAI de acordo com as taxas padrão da API. Consulte a [página de preços da API](https://openai.com/api/pricing/).

A autenticação por chave de API suporta fluxos de trabalho locais do Codex, mas alguns recursos que dependem do acesso ao workspace do ChatGPT ou de serviços em nuvem podem estar limitados ou indisponíveis. Compare o suporte por plano em [Disponibilidade de recursos](https://learn.chatgpt.com/docs/pricing#feature-availability).

Na Codex CLI e no Codex dentro do aplicativo desktop do ChatGPT, a autenticação por chave de API inclui acesso a plugins curados pela OpenAI suportados. Alguns plugins não estão disponíveis porque seus fluxos de conexão exigem recursos OAuth não suportados. Consulte [Usar plugins](https://learn.chatgpt.com/docs/plugins#api-key-availability).

Ao entrar com uma chave de API, o Codex usa o preço padrão de API em vez dos créditos incluídos do plano do ChatGPT.

Use a autenticação por chave de API para fluxos de trabalho programáticos da Codex CLI, como jobs de CI/CD. Não exponha a execução do Codex em ambientes não confiáveis ou públicos.

### Verificar autenticação ou sair

Execute `codex login status` para ver o método de autenticação ativo. Execute `codex logout` para limpar as credenciais atuais.

### Usar tokens de acesso do Codex para automação empresarial

Em workspaces do ChatGPT Enterprise, os administradores podem conceder permissão de token de acesso para que membros autorizados criem tokens de acesso do Codex para fluxos de trabalho locais confiáveis e não interativos. Use um token de acesso quando a automação precisar de acesso ao workspace do ChatGPT, direitos do Codex gerenciados pelo ChatGPT ou controles de workspace empresarial sem login via navegador.

Os tokens de acesso são destinados a scripts confiáveis, agendadores e runners privados de CI. Para chamadas de API gerais da OpenAI, continue usando as chaves de API da Plataforma.

Para etapas de configuração, permissões, rotação e revogação, consulte [Tokens de acesso](https://learn.chatgpt.com/docs/enterprise/access-tokens).

Se o seu ambiente já fornece um token de acesso do Codex, passe-o para a CLI:

```shell
printenv CODEX_ACCESS_TOKEN | codex login --with-access-token
```

## Proteger sua conta na nuvem do Codex

A nuvem do Codex interage diretamente com sua base de código, por isso precisa de uma segurança mais forte do que muitos outros recursos do ChatGPT. Ative a autenticação de dois fatores (MFA).

Se você usa um provedor de login social (Google, Microsoft, Apple), não é obrigado a ativar o MFA na sua conta do ChatGPT, mas pode configurá-lo no seu provedor de login social.

Para instruções de configuração, consulte:

- [Google](https://support.google.com/accounts/answer/185839)
- [Microsoft](https://support.microsoft.com/en-us/topic/what-is-multifactor-authentication-e5e39437-121c-be60-d123-eda06bddf661)
- [Apple](https://support.apple.com/en-us/102660)

Se você acessa o ChatGPT via Single Sign-On (SSO), o administrador de SSO da sua organização deve impor o MFA para todos os usuários.

Se você faz login com e-mail e senha, deve configurar o MFA em sua conta antes de acessar a nuvem do Codex.

<a id="login-caching"></a>

## Cache de login

Quando você faz login no aplicativo desktop do ChatGPT, na Codex CLI ou na extensão IDE usando o ChatGPT ou uma chave de API, seus detalhes de login são armazenados em cache e reutilizados. A CLI e a extensão compartilham os mesmos detalhes de login em cache. Se você fizer logout de um deles, precisará se autenticar novamente na próxima vez que iniciar a CLI ou extensão.

O Codex armazena em cache os detalhes de login localmente em um arquivo de texto simples em `~/.codex/auth.json` ou no cofre de credenciais específico do seu sistema operacional.

Para sessões de login com o ChatGPT, o Codex atualiza os tokens automaticamente durante o uso antes que expirem, portanto, sessões ativas geralmente continuam sem exigir outro login no navegador.

<a id="credential-storage"></a>

## Armazenamento de credenciais

Use `cli_auth_credentials_store` para controlar onde a Codex CLI armazena credenciais em cache:

```toml
# file | keyring | auto
cli_auth_credentials_store = "keyring"
```

- `file` armazena credenciais em `auth.json` sob `CODEX_HOME` (padrão em `~/.codex`).
- `keyring` armazena credenciais no cofre de credenciais do seu sistema operacional.
- `auto` usa o cofre de credenciais do SO quando disponível; caso contrário, recorre ao `auth.json`.

Consulte a [referência de configuração](https://learn.chatgpt.com/docs/config-file/config-reference) para o esquema completo do `config.toml`.

Se você usa armazenamento baseado em arquivo, trate o `~/.codex/auth.json` como uma senha: ele contém tokens de acesso. Não o envie para repositórios, não o cole em tickets nem o compartilhe em chats.

## Impor um método de login ou workspace

Em ambientes gerenciados, os administradores podem restringir a forma como os usuários se autenticam:

```toml
# Permitir apenas login pelo ChatGPT ou apenas chave de API.
forced_login_method = "chatgpt" # ou "api"

# Ao usar o login pelo ChatGPT, restrinja os usuários a um workspace específico.
forced_chatgpt_workspace_id = "00000000-0000-0000-0000-000000000000"
```

Se as credenciais ativas não corresponderem às restrições configuradas, o Codex encerra a sessão do usuário e sai.

Essas configurações são comumente aplicadas via configuração gerenciada em vez de configuração por usuário. Consulte [Configuração gerenciada](https://learn.chatgpt.com/docs/enterprise/managed-configuration).

## Diagnósticos de login

Execuções diretas de `codex login` gravam um arquivo dedicado `codex-login.log` no diretório de logs configurado. Use-o para depurar falhas de login no navegador ou código de dispositivo, ou quando o suporte solicitar logs específicos de login.

## Pacotes de CA personalizados

Se a sua rede usa um proxy TLS corporativo ou uma CA raiz privada, defina `CODEX_CA_CERTIFICATE` para um pacote PEM antes de fazer login. Quando `CODEX_CA_CERTIFICATE` não estiver definido, o Codex recorre ao `SSL_CERT_FILE`. As mesmas configurações de CA personalizadas se aplicam ao login, requisições HTTPS normais e conexões WebSocket seguras.

```shell
export CODEX_CA_CERTIFICATE=/path/to/corporate-root-ca.pem
codex login
```

## Login em dispositivos headless (sem interface gráfica)

Se você estiver fazendo login no ChatGPT com a Codex CLI, existem situações em que a interface de login baseada em navegador pode não funcionar:

- Você está executando a CLI em um ambiente remoto ou sem interface gráfica (headless).
- Sua configuração de rede local bloqueia o callback em localhost que o Codex usa para retornar o token OAuth para a CLI após o login.

Nessas situações, dê preferência à autenticação por código de dispositivo (beta). Na interface interativa de login, escolha **Sign in with Device Code** ou execute `codex login --device-auth` diretamente.

### Preferencial: Autenticação por código de dispositivo (beta)

1. Ative o login por código de dispositivo nas configurações de segurança do ChatGPT (conta pessoal) ou nas permissões do workspace (administrador do workspace).
2. No terminal onde está executando o Codex:
   - Na interface interativa, selecione **Sign in with Device Code**.
   - Ou execute `codex login --device-auth`.
3. Abra o link no seu navegador, faça login e insira o código de uso único.

### Alternativa: Autenticar localmente e copiar seu cache de autenticação

Se você pode concluir o fluxo de login em uma máquina com navegador, pode copiar suas credenciais em cache para a máquina sem interface gráfica.

1. Em uma máquina com navegador, execute `codex login`.
2. Confirme se o cache existe em `~/.codex/auth.json`.
3. Copie o `~/.codex/auth.json` para o `~/.codex/auth.json` na máquina remota/headless.

Copiar para uma máquina remota via SSH:

```shell
ssh user@remote 'mkdir -p ~/.codex'
scp ~/.codex/auth.json user@remote:~/.codex/auth.json
```

Ou usando um comando direto:

```shell
ssh user@remote 'mkdir -p ~/.codex && cat > ~/.codex/auth.json' < ~/.codex/auth.json
```

Copiar para um container Docker:

```shell
CONTAINER_HOME=$(docker exec MY_CONTAINER printenv HOME)
docker exec MY_CONTAINER mkdir -p "$CONTAINER_HOME/.codex"
docker cp ~/.codex/auth.json MY_CONTAINER:"$CONTAINER_HOME/.codex/auth.json"
```

### Alternativa: Redirecionar o callback de localhost via SSH

Se você pode redirecionar portas entre a máquina local e o host remoto:

1. Na sua máquina local, inicie o redirecionamento de porta:

```shell
ssh -L 1455:localhost:1455 user@remote
```

2. Nessa sessão SSH, execute `codex login` e siga o endereço impresso na sua máquina local.

## Provedores de modelos alternativos

Ao definir um [provedor de modelo personalizado](https://learn.chatgpt.com/docs/config-file/config-advanced#custom-model-providers) no seu arquivo de configuração, você pode escolher um destes métodos de autenticação:

- **Autenticação OpenAI**: Defina `requires_openai_auth = true` para usar a autenticação da OpenAI. Você pode então entrar com o ChatGPT ou uma chave de API. Útil quando você acessa modelos da OpenAI através de um servidor proxy LLM. Quando `requires_openai_auth = true`, o Codex ignora `env_key`.
- **Autenticação por variável de ambiente**: Defina `env_key = "<NOME_DA_VARIAVEL>"` para usar uma chave de API específica do provedor a partir de uma variável de ambiente local.
- **Sem autenticação**: Se você não definir `requires_openai_auth` (ou definir como `false`) e não definir `env_key`, o Codex assume que o provedor não exige autenticação. Útil para modelos locais.
