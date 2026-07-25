# codex-hotel

`codex-otel` é o crate de integração do OpenTelemetry para o Codex. Ele oferece:

- Implementação de conexões para exportadores de logs/traços/métricas (`codex_otel::OtelProvider`
  e `codex_otel::provider`).
- Emissão de evento de negócios com escopo de sessão por meio de `codex_otel::SessionTelemetry`.
- APIs de métricas de baixo nível por meio do `codex_otel::metrics`.
- Auxiliares de contexto de rastreamento por meio de `codex_otel::trace_context` e reexportações da raiz do crate.

## Rastreamento e registros

Crie um provedor OTEL a partir de `OtelSettings`. O provedor também configura
métricas (quando ativadas) e, em seguida, anexe suas camadas ao seu `tracing_subscriber`
registro:

```rust
use codex_otel::config::OtelExporter;
use codex_otel::config::OtelHttpProtocol;
use codex_otel::config::OtelSettings;
use codex_otel::OtelProvider;
use tracing_subscriber::prelude::*;

let settings = OtelSettings {
    environment: "dev".to_string(),
    service_name: "codex-cli".to_string(),
    service_version: env!("CARGO_PKG_VERSION").to_string(),
    codex_home: std::path::PathBuf::from("/tmp"),
    exporter: OtelExporter::OtlpHttp {
        endpoint: "https://otlp.example.com".to_string(),
        headers: std::collections::HashMap::new(),
        protocol: OtelHttpProtocol::Binary,
        tls: None,
    },
    trace_exporter: OtelExporter::OtlpHttp {
        endpoint: "https://otlp.example.com".to_string(),
        headers: std::collections::HashMap::new(),
        protocol: OtelHttpProtocol::Binary,
        tls: None,
    },
    metrics_exporter: OtelExporter::None,
    span_attributes: std::collections::BTreeMap::new(),
    tracestate: std::collections::BTreeMap::new(),
};

if let Some(provider) = OtelProvider::from(&settings)? {
    let registry = tracing_subscriber::registry()
        .with(provider.logger_layer())
        .with(provider.tracing_layer());
    registry.init();
}
```

Os atributos de span configurados e os campos de membros do W3C tracestate são aplicados a
intervalos de rastreamento exportados e contexto de rastreamento propagado:

```toml
[otel.span_attributes]
"example.trace_attr" = "enabled"

[otel.tracestate.example]
alpha = "one"
beta = "two"
```

Os membros do tracestate configurados e os valores codificados devem ser válidos segundo o padrão W3C para tracestate.
Cada tabela aninhada é codificada como campos `key:value` separados por ponto-e-vírgula dentro de
esse membro. Se o contexto de rastreamento propagado já contiver o membro mencionado, o Codex
realiza uma operação de upsert nos campos configurados e preserva os demais campos desse membro. Isso
A configuração “shape” não permite definir valores opacos para os membros do “tracestate”. Inválido
As entradas de metadados de rastreamento são ignoradas durante o carregamento da configuração e relatadas como parte da inicialização
avisos.

## Telemetria de sessão (eventos)

`SessionTelemetry` adiciona metadados consistentes aos eventos de rastreamento e ajuda a registrar
Eventos de sessão específicos do Codex. Eventos de sessão/negócios complexos devem passar por
`SessionTelemetry`; os eventos de auditoria pertencentes a um subsistema podem permanecer no próprio subsistema.

```rust
use codex_otel::SessionTelemetry;

let manager = SessionTelemetry::new(
    conversation_id,
    model,
    slug,
    account_id,
    account_email,
    auth_mode,
    originator,
    log_user_prompts,
    terminal_type,
    session_source,
);

manager.user_prompt(&prompt_items);
```

## Métricas (OTLP ou em memória)

Modos:

- OTLP: exporta métricas por meio do exportador OTLP do OpenTelemetry (HTTP ou gRPC).
- Na memória: grava por meio de `opentelemetry_sdk::metrics::InMemoryMetricExporter` para testes/assertões; chame `shutdown()` para esvaziar.

`codex-otel` também oferece `OtelExporter::Statsig`, uma forma abreviada de exportar métricas JSON via OTLP/HTTP
para o Statsig, utilizando os padrões internos do Codex.

Exemplo de ingestão no Statsig (OTLP/HTTP JSON):

```rust
use codex_otel::config::{OtelExporter, OtelHttpProtocol};

let metrics = MetricsClient::new(MetricsConfig::otlp(
    "dev",
    "codex-cli",
    env!("CARGO_PKG_VERSION"),
    OtelExporter::OtlpHttp {
        endpoint: "https://api.statsig.com/otlp".to_string(),
        headers: std::collections::HashMap::from([(
            "statsig-api-key".to_string(),
            std::env::var("STATSIG_SERVER_SDK_SECRET")?,
        )]),
        protocol: OtelHttpProtocol::Json,
        tls: None,
    },
))?;

metrics.counter("codex.session_started", 1, &[("source", "tui")])?;
metrics.histogram("codex.request_latency", 83, &[("route", "chat")])?;
```

Na memória (testes):

```rust
let exporter = InMemoryMetricExporter::default();
let metrics = MetricsClient::new(MetricsConfig::in_memory(
    "test",
    "codex-cli",
    env!("CARGO_PKG_VERSION"),
    exporter.clone(),
))?;
metrics.counter("codex.turns", 1, &[("model", "gpt-5.1")])?;
metrics.shutdown()?; // flushes in-memory exporter
```

## Contexto de rastreamento

Os auxiliares de propagação de rastreamento permanecem separados do emissor de eventos da sessão:

```rust
use codex_otel::current_span_w3c_trace_context;
use codex_otel::set_parent_from_w3c_trace_context;
```

## Desligamento

- `OtelProvider::shutdown()` interrompe o exportador OTEL.
- `SessionTelemetry::shutdown_metrics()` limpa e desativa o provedor de métricas.

Ambos são opcionais, pois o comando `drop` realiza um desligamento “best-effort”, mas chamá-los
garante explicitamente a liberação determinística (ou um erro de desligamento caso a liberação não ocorra)
(não concluído a tempo).
