# codex-cliente

Política de solicitações de nível superior implementada sobre o `codex-http-client` sem qualquer reconhecimento das APIs do Codex/OpenAI.

- Fornece utilitários de repetição de tentativa (`RetryPolicy`, `RetryOn`, `run_with_retry`, `backoff`) que os chamadores podem utilizar para chamadas unárias e de streaming.
- Fornece o auxiliar `sse_stream` para converter fluxos de bytes em quadros SSE `data:` brutos, com tempos limite de inatividade e erros de fluxo identificados.
- Define o callback de telemetria da solicitação utilizado por clientes de nível superior.
- Reexporta temporariamente os tipos HTTP de baixo nível para que os usuários possam migrar para `codex-http-client` de forma incremental.
