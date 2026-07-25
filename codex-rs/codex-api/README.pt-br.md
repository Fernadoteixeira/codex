# código de conduta

Clientes tipados para as APIs do Codex/OpenAI, desenvolvidos com base no transporte genérico do `codex-client`.

- Hospeda os modelos de solicitação/resposta e os geradores de solicitação para as APIs Responses e Compact.
- Controla a configuração do provedor (URLs base, cabeçalhos, parâmetros de consulta), a inserção de cabeçalhos de autenticação, o ajuste de tentativas de repetição e as configurações de inatividade do fluxo.
- Analisa fluxos SSE em `ResponseEvent`/`ResponseStream`, incluindo instantâneos de limite de taxa e mapeamento de erros específico da API.
- Funciona como a camada de nível de comunicação consumida pelo `codex-core`; as camadas superiores lidam com a atualização da autenticação e a lógica de negócios.

## Interface principal

A interface pública deste crate é intencionalmente pequena e uniforme:

- **Endpoint de respostas**
  - Entrada:
    - `ResponsesApiRequest` para o corpo da solicitação (`model`, `instructions`, `input`, `tools`, `parallel_tool_calls`, controles de justificativa/texto).
    - `ResponsesOptions` para questões relacionadas ao transporte/cabeçalho (`conversation_id`, `session_source`, `extra_headers`, `compression`, `turn_state`).
  - Saída: um `ResponseStream` de `ResponseEvent` (ambos reexportados de `common`).

- **Ponto final da compactação**
  - Entrada: `CompactionInput<'a>` (reexportado como `codex_api::CompactionInput`):
    - `model: &str`.
    - `input: &[ResponseItem]` – histórico a ser compactado.
    - `instructions: &str` – instruções de compactação totalmente definidas.
  - Resultado: `Vec<ResponseItem>`.
  - `CompactClient::compact_input(&CompactionInput, extra_headers)` engloba a codificação JSON e a integração de tentativas de repetição e telemetria.

- **Ponto final de resumo da memória**
  - Entrada: `MemorySummarizeInput` (reexportado como `codex_api::MemorySummarizeInput`):
    - `model: String`.
    - `raw_memories: Vec<RawMemory>` (serializado como `traces` para compatibilidade com a transmissão por fio).
      - `RawMemory` inclui `id`, `metadata.source_path` e `items` normalizado.
    - `reasoning: Option<Reasoning>`.
  - Resultado: `Vec<MemorySummarizeOutput>`.
  - `MemoriesClient::summarize_input(&MemorySummarizeInput, extra_headers)` engloba a codificação JSON e a integração de tentativas de repetição e telemetria.

Todos os detalhes HTTP (URLs, cabeçalhos, políticas de repetição/recuo, estruturação SSE) são encapsulados em `codex-api` e `codex-client`. Os chamadores constroem prompts/entradas usando tipos de protocolo e trabalham com fluxos tipados de valores `ResponseEvent` ou compactados `ResponseItem`.
