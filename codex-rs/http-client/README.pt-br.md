# codex-http-client

`codex-http-client` é o transporte HTTP de baixo nível compartilhado pelas crates do Codex. É o previsto
proprietário da integração direta `reqwest` do espaço de trabalho; os crates do produto devem utilizar os tipos contidos neste
criar em vez de construir os próprios valores `reqwest::Client`.

A centralização da construção de clientes mantém as solicitações de saída sujeitas às mesmas políticas e evita a criação de
clientes de curta duração que fragmentam o pool de conexões do reqwest. Em particular, este crate possui:

- os tipos de solicitação, resposta, streaming e transporte utilizados nas chamadas HTTP de saída;
- gestão personalizada de CA por meio de `CODEX_CA_CERTIFICATE` e `SSL_CERT_FILE`;
- política explícita de proxy de saída, incluindo o sistema, PAC/WPAD, ambiente e rotas diretas;
- agrupamento de clientes com reconhecimento de rota e gerenciamento de redirecionamentos;
- injeção de cabeçalho de rastreamento e diagnósticos opcionais da solicitação; e
- o armazenamento de cookies do ChatGPT Cloudflare (com consentimento prévio).

Outra motivação importante é o suporte consistente ao recurso `respect_system_proxy`. Isso
Esse recurso exige mais do que apenas ativar o comportamento padrão do proxy do reqwest: o Codex precisa resolver a plataforma
configurações do sistema e PAC/WPAD para cada destino, agrupar conexões sem misturar rotas e
determinar os destinos dos redirecionamentos de forma independente.

A política de telemetria de novas tentativas de nível superior, SSE e tentativas de solicitação permanece em `codex-client`.

## Política de proxy de saída

Construa um `HttpClientFactory` a partir da configuração efetiva do aplicativo e passe-o para o
componentes que fazem solicitações. Os locais de chamada não devem verificar de forma independente o sinalizador de recurso ou
escolha `OutboundProxyPolicy::ReqwestDefault`.

A política da fábrica possui dois modos:

- `RespectSystemProxy` determina a rota para a URL completa da solicitação. Configurações do sistema da plataforma
  e o PAC/WPAD são considerados em primeiro lugar, seguidos pelas variáveis de ambiente de proxy explícitas e, em seguida, um
  conexão direta.
- `ReqwestDefault` mantém o comportamento de proxy tradicional do transporte. Ele existe para configurações
  nos casos em que o suporte ao proxy do sistema estiver desativado, e não como um padrão conveniente para novos locais de chamada.

Esses dois modos existem porque `respect_system_proxy` é, atualmente, configurável. Se ele passar para
comportamento integrado não configurável, a determinação de recursos no nível do aplicativo, a seleção de políticas,
e a maior parte da lógica condicional `ReqwestDefault` pode ser eliminada. A implementação sensível à rota faria
ainda pode ser necessário: as decisões do sistema e do PAC podem variar de acordo com a URL completa; os redirecionamentos podem selecionar um
As rotas alternativas e os requisitos excepcionais de roteamento direto devem permanecer explícitos e passíveis de auditoria.

Para um cliente que se comunica com um destino conhecido, crie-o uma vez e mantenha-o:

```rust
use codex_http_client::ClientRouteClass;

let client = http_client_factory.build_client(api_url, ClientRouteClass::Api)?;
let response = client.get(api_url).send().await?;
```

Use `HttpClientBuilder` quando o cliente precisar de uma configuração compartilhada adicional:

```rust
use codex_http_client::ClientRouteClass;
use codex_http_client::HttpClientBuilder;

let client = HttpClientBuilder::new()
    .default_headers(default_headers)
    .build_respecting_outbound_proxy_policy(
        &http_client_factory,
        api_url,
        ClientRouteClass::Api,
    )?;
```

O método do terminal é intencionalmente explícito. O tráfego de produtos deve, normalmente, utilizar
`build_respecting_outbound_proxy_policy`. `build_direct` destina-se exclusivamente a usos excepcionais e deve ser
reservado para uma necessidade documentada, como um dispositivo de teste local hermético, um callback localhost,
ou tráfego da sandbox cujo roteamento de saída é tratado separadamente. O transport-default e o
Os métodos de terminal “custom-CA-fallback” são caminhos de compatibilidade com versões antigas, considerados obsoletos, e não devem ser utilizados
para o tráfego relacionado a novos produtos.

## Agrupamento com consideração da rota

Use um `RouteAwareClientPool` de longa duração quando um componente puder enviar solicitações para mais de uma URL ou
seguir redirecionamentos:

```rust
use codex_http_client::ClientRouteClass;
use codex_http_client::RouteAwareClientPool;

let client_pool =
    RouteAwareClientPool::new(http_client_factory.clone(), ClientRouteClass::Api);
let response = client_pool.get(request_url).send().await?;
```

Com `RespectSystemProxy`, a seleção do proxy pode depender da URL completa, e não apenas de sua origem.
Portanto, o pool resolve todas as URLs de solicitação e armazena em cache até 16 clientes de transporte por resolução
rota. Isso permite reutilizar a conexão sem enviar acidentalmente uma URL por meio de um cliente vinculado a
o caminho errado.

Os redirecionamentos precisam do mesmo tratamento. O Reqwest normalmente os acompanha durante uma única execução do cliente, o que
ignoraria a seleção de rota do Codex para o destino do redirecionamento. No modo `RespectSystemProxy`, o pool
O "follows" redireciona-se automaticamente, resolve cada salto e remove cabeçalhos confidenciais quando a origem é alterada.

Não crie um novo `HttpClient`, `HttpClientFactory` ou `RouteAwareClientPool` para cada solicitação.
Armazene o cliente ou o pool no componente responsável pelo tráfego, para que suas conexões possam ser reutilizadas.

## Dados confidenciais da solicitação

Clientes normais emitem informações de diagnóstico de depuração que contêm a URL da solicitação e os cabeçalhos da resposta. Para
endpoints nos quais esses valores possam conter credenciais, use
`HttpClientFactory::build_client_without_request_logging` ou
`RouteAwareClientPool::new_without_request_logging`. O conjunto de cookies correspondente do ChatGPT
O construtor é `with_chatgpt_cloudflare_cookies_without_request_logging`.

As implementações `Debug` do wrapper ocultam as URLs das solicitações e as configurações de proxy resolvidas, mas os chamadores
Ainda assim, deve-se evitar, sempre que possível, incluir informações confidenciais nas URLs.

## Adaptação a clientes de nível superior

O código que utiliza a abstração de transporte deve converter um wrapper configurado, em vez de criá-lo
um cliente de solicitação “raw”:

```rust
use codex_http_client::ClientRouteClass;
use codex_http_client::ReqwestTransport;

let client = http_client_factory.build_client(api_url, ClientRouteClass::Api)?;
let transport = ReqwestTransport::from_http_client(client);
```

Se a superfície do invólucro existente não for compatível com um caso de uso, amplie `codex-http-client` em vez de
adicionar uma dependência direta `reqwest` a outro crate do próprio autor.
