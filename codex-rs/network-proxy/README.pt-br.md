# codex-network-proxy

`codex-network-proxy` é o proxy de aplicação de políticas de rede local do Codex. Ele executa:

- um proxy HTTP (padrão `127.0.0.1:3128`)
- um proxy SOCKS5 (padrão `127.0.0.1:8081`, ativado por padrão)

Ele aplica uma política de permissão/restrição e um modo “limitado” destinado ao acesso à rede somente para leitura.

## Guia de Início Rápido

### 1) Configurar

`codex-network-proxy` é lido a partir do `config.toml` mesclado do Codex (por meio do carregamento da configuração `codex-core`).

As configurações de rede estão associadas ao perfil de permissões selecionado. Exemplo de configuração:

```toml
default_permissions = "workspace"

[permissions.workspace.network]
enabled = true
proxy_url = "http://127.0.0.1:3128"
# SOCKS5 listener (enabled by default).
enable_socks5 = true
socks_url = "http://127.0.0.1:8081"
enable_socks5_udp = true
# When `enabled` is false, the proxy no-ops and does not bind listeners.
# When true, respect HTTP(S)_PROXY/ALL_PROXY for upstream requests (HTTP(S) proxies only),
# including CONNECT tunnels in full mode.
allow_upstream_proxy = true
# By default, non-loopback binds are clamped to loopback for safety.
# If you want to expose these listeners beyond localhost, you must opt in explicitly.
dangerously_allow_non_loopback_proxy = false
mode = "full" # default when unset; use "limited" for read-only mode
# HTTPS MITM is enabled automatically when `mode = "limited"` or when MITM hooks are configured.
# The CA private key remains in proxy memory. When MITM is active, spawned commands receive CA
# bundle env vars pointing at immutable public files under $CODEX_HOME/proxy/ so common HTTPS
# clients trust the managed CA.

# If false, local/private networking is rejected. Explicit allowlisting of local IP literals
# (or `localhost`) is required to permit them.
# Hostnames that resolve to local/private IPs are still blocked even if allowlisted.
# Clients that always bypass proxies for loopback, such as Go's `net/http`, remain blocked by
# the operating-system sandbox when local binding is disabled.
allow_local_binding = false

# DANGEROUS (macOS-only): bypasses unix socket allowlisting and permits any
# absolute socket path from `x-unix-socket`.
dangerously_allow_all_unix_sockets = false

# Hosts must match the allowlist (unless denied).
# Use exact hosts or scoped wildcards like `*.openai.com` or `**.openai.com`.
# The global `*` wildcard is rejected.
# If no domain entries are marked `allow`, the proxy blocks requests until an allowlist is configured.
[permissions.workspace.network.domains]
"*.openai.com" = "allow"
"localhost" = "allow"
"127.0.0.1" = "allow"
"::1" = "allow"
"evil.example" = "deny"

# MITM hooks match HTTPS requests after CONNECT is terminated.
[permissions.workspace.network.mitm.hooks.github_write]
host = "api.github.com"
methods = ["POST", "PUT"]
path_prefixes = ["/repos/openai/"]
action = ["strip_auth"]

# Named actions can be shared across hooks and overridden by higher-precedence config layers.
[permissions.workspace.network.mitm.actions.strip_auth]
strip_request_headers = ["authorization"]

# macOS-only: allows proxying to a unix socket when request includes `x-unix-socket: /path`.
[permissions.workspace.network.unix_sockets]
"/tmp/example.sock" = "allow"
```

### 2) Execute o proxy

```bash
cargo run -p codex-network-proxy --
```

### 3) Direcionar um cliente para ele

Para o tráfego HTTP(S):

```bash
export HTTP_PROXY="http://127.0.0.1:3128"
export HTTPS_PROXY="http://127.0.0.1:3128"
export WS_PROXY="http://127.0.0.1:3128"
export WSS_PROXY="http://127.0.0.1:3128"
```

Para o tráfego SOCKS5 (quando `enable_socks5 = true`):

```bash
export ALL_PROXY="socks5h://127.0.0.1:8081"
```

### 4) Compreender blocos / depuração

Quando uma solicitação é bloqueada, o proxy responde com `403` e inclui:

- `x-proxy-error`: um dos seguintes:
  - `blocked-by-allowlist`
  - `blocked-by-denylist`
  - `blocked-by-method-policy`
  - `blocked-by-policy`

No modo “limitado”, apenas `GET`, `HEAD` e `OPTIONS` são permitidos. Solicitações HTTPS `CONNECT` e
Os destinos HTTPS SOCKS5 TCP em `:443` exigem MITM para aplicar a política de método em modo limitado; caso contrário,
eles estão bloqueados. O SOCKS5 UDP e o SOCKS5 TCP não HTTPS continuam bloqueados no modo limitado.

Os clientes WebSocket normalmente estabelecem um túnel `wss://` por meio de HTTPS `CONNECT`; esses destinos CONNECT continuam indo
por meio das mesmas verificações da lista de permissão/bloqueio do host.

## API da biblioteca

O `codex-network-proxy` pode ser incorporado como uma biblioteca com uma API enxuta:

```rust
use codex_network_proxy::{NetworkProxy, NetworkDecision, NetworkPolicyRequest};

let proxy = NetworkProxy::builder()
    .http_addr("127.0.0.1:8080".parse()?)
    .policy_decider(|request: NetworkPolicyRequest| async move {
        // Example: auto-allow when exec policy already approved a command prefix.
        if let Some(command) = request.command.as_deref() {
            if command.starts_with("curl ") {
                return NetworkDecision::Allow;
            }
        }
        NetworkDecision::Deny {
            reason: "policy_denied".to_string(),
        }
    })
    .build()
    .await?;

let handle = proxy.run().await?;
handle.shutdown().await?;
```

Quando o proxy de soquetes Unix está habilitado (`unix_sockets` ou
`dangerously_allow_all_unix_sockets`), as substituições de ligação por proxy continuam restritas ao loopback para
evitar transformar o proxy em uma ponte remota para os daemons locais.

### Ganchos de política (mapeamento de execução de políticas)

O proxy disponibiliza um gancho de política (`NetworkPolicyDecider`) que pode substituir bloqueios baseados exclusivamente na lista de permissões.
Ele recebe os campos `command` e `exec_policy_hint` quando fornecidos pelo aplicativo de integração. Isso permite que
limitar as aprovações do mapa principal ao acesso à rede; por exemplo, se um usuário já tiver aprovado `curl *` para uma sessão,
O Decider pode permitir automaticamente as solicitações de rede originadas desse comando.

**Importante:** As regras de negação explícita continuam prevalecendo. O mecanismo de decisão só tem a chance de substituir
`not_allowed` (falhas na lista de permissões), e não `denied` ou `not_allowed_local`.

## Eventos de auditoria do OTEL (integrados/gerenciados)

Quando o `codex-network-proxy` está incorporado no ambiente de execução gerenciado do Codex, as decisões de política geram
Eventos compatíveis com OTEL com `target=codex_otel.network_proxy`.

Nome do evento:

- `codex.network_proxy.policy_decision`
  - emitidas para cada decisão de política (`domain` e `non_domain`).
  - `network.policy.scope = "domain"` para avaliações de políticas do host (`evaluate_host_policy`).
  - `network.policy.scope = "non_domain"` para verificações de modo-guard/proxy-state (incluindo caminhos de proteção de unix-socket e decisões de permissão de unix-socket).

Campos comuns:

- `event.name`
- `event.timestamp` (RFC 3339 UTC, precisão em milissegundos)
- metadados opcionais:
  - `conversation.id`
  - `app.version`
  - `user.account_id`
- política/rede:
  - `network.policy.scope` (`domain` ou `non_domain`)
  - `network.policy.decision` (`allow`, `deny` ou `ask`)
  - `network.policy.source` (`baseline_policy`, `mode_guard`, `proxy_state`, `decider`)
  - `network.policy.reason`
  - `network.transport.protocol`
  - `server.address`
  - `server.port`
  - `http.request.method` (o valor padrão é `"none"` quando não for especificado)
  - `client.address` (o valor padrão é `"unknown"` quando não for especificado)
  - `network.policy.override` (`true` somente quando a permissão do decisor se sobrepõe à linha de base `not_allowed`)

As auditorias de caminho de bloco de soquetes Unix utilizam valores de ponto final sentinela:

- `server.address = "unix-socket"`
- `server.port = 0`

Os eventos de auditoria evitam intencionalmente registrar dados completos de URL, caminho e consulta.

## Notas sobre a plataforma

- O proxy de soquetes Unix por meio do cabeçalho `x-unix-socket` é **exclusivo do macOS**; em outras plataformas,
  rejeitar solicitações de soquete Unix.
- O tunelamento HTTPS utiliza o rustls por meio do `rama-tls-rustls` do Rama; isso evita o símbolo do BoringSSL/OpenSSL
  colisões em grafos de dependências TLS mistos.

## Observações de segurança (importante)

Esta seção documenta as proteções implementadas pelo `codex-network-proxy` e os limites de
o que pode razoavelmente garantir.

- Política de “lista de permissões em primeiro lugar”: se `domains` não tiver entradas `allow`, as solicitações serão bloqueadas até que uma lista de permissões seja configurada.
- Padrões de domínio: hosts exatos são suportados; `*.example.com` corresponde apenas a subdomínios, e `**.example.com` corresponde ao domínio raiz mais os subdomínios; o curinga global `*` só é aceito quando explicitamente habilitado para a compilação da lista de permissões e, caso contrário, é rejeitado.
- Rejeitar: `domains` entradas marcadas com `deny` sempre se sobrepõem à lista de permissões.
- Proteção da rede local/privada: quando `allow_local_binding = false`, o proxy bloqueia o loopback
  e intervalos comuns privados/locais de enlace. Inclusão explícita na lista de permissões de endereços IP locais literais (ou `localhost`)
  é necessário permitir isso; nomes de host que apontam para endereços IP locais/privados continuam bloqueados, mesmo que
  na lista de permissões (pesquisa de DNS com o melhor esforço possível).
- Aplicação restrita do modo:
  - só são permitidos `GET`, `HEAD` e `OPTIONS`
  - As solicitações HTTPS `CONNECT` e os destinos HTTPS SOCKS5 TCP em `:443` exigem MITM para que o proxy possa
    aplicar a política de modo restrito; SOCKS5 UDP e SOCKS5 TCP não HTTPS continuam bloqueados
- Configurações padrão de segurança do ouvinte:
  - O ouvinte do proxy HTTP bloqueia ligações que não sejam de loopback, a menos que isso seja explicitamente habilitado por meio de
    `dangerously_allow_non_loopback_proxy`
- Quando o proxy de soquetes Unix está habilitado, todos os ouvintes do proxy são forçados a fazer loopback para evitar que o
    proxy em uma ponte remota para daemons locais.
- `dangerously_allow_all_unix_sockets = true` ignora completamente a lista de permissões do soquete Unix (ainda
  (exclusivamente para macOS e apenas com caminhos absolutos). Utilize apenas em ambientes rigidamente controlados.
- `enabled` é aplicado em tempo de execução; quando falso, o proxy não executa nenhuma operação e não vincula ouvintes.
Limitações:

- É difícil impedir totalmente o rebinding de DNS sem fixar o(s) endereço(s) IP resolvido(s) até o nível do
  camada de transporte. Se o seu modelo de ameaças incluir DNS hostil, aplique o controle de saída de rede em um nível inferior
  também em outras camadas (por exemplo, firewall / VPC / políticas de proxy corporativas).
