# codex-app-server-client

Cliente compartilhado do servidor de aplicativos em execução, utilizado pelas interfaces de linha de comando (CLI) conversacionais:

- `codex-exec`
- `codex-tui`

## Objetivo

Este crate centraliza o gerenciamento da inicialização e do ciclo de vida de um processo em andamento
`codex-app-server` tempo de execução, de modo que os clientes da CLI não precisam duplicar:

- Inicialização do servidor de aplicativos e troca de informações de inicialização
- conexão de transporte de solicitações/eventos na memória
- orquestração do ciclo de vida com base na identidade de inicialização fornecida pelo chamador
- comportamento adequado ao desligamento

## Identidade da startup

Os chamadores passam tanto o servidor do aplicativo `SessionSource` quanto a função de inicialização
`client_info.name` explicitamente ao iniciar a fachada.

Isso mantém os metadados do tópico (por exemplo, em `thread/list` e `thread/read`)
alinhado com o ambiente de execução de origem, sem incorporar políticas específicas do TUI/exec
para a camada de cliente compartilhada.

## Modelo de transporte

O caminho de processamento utiliza canais tipados:

- cliente -> servidor: `ClientRequest` / `ClientNotification`
- servidor -> cliente: `InProcessServerEvent`
  - `ServerRequest`
  - `ServerNotification`
  - `LegacyNotification`

A serialização JSON ainda é utilizada nos limites de transporte externos
(stdio/websocket), mas o caminho de acesso rápido dentro do processo é tipado.

As solicitações tipadas ainda recebem respostas do servidor de aplicativos por meio do JSON-RPC
envelope de resultado internamente. Isso é intencional: o caminho durante o processamento é
tem como objetivo preservar a semântica do servidor de aplicativos ao remover o processo
limite, para não introduzir um segundo contrato de resposta.

## Comportamento do Bootstrap

A fachada do cliente inicia um ambiente de execução já inicializado no processo, mas
O bootstrap da thread ainda segue o fluxo normal do servidor de aplicativos:

- o chamador envia `thread/start` ou `thread/resume`
- O app-server retorna a resposta tipada imediatamente
- metadados mais detalhados da sessão podem ser disponibilizados posteriormente como um `SessionConfigured`
  evento tradicional

Superfícies como TUI e exec podem, portanto, precisar de um breve processo de inicialização
fase em que eles comparam os dados de resposta na inicialização com eventos posteriores.

## Contrapressão e desligamento

- As filas são limitadas e utilizam `DEFAULT_IN_PROCESS_CHANNEL_CAPACITY` por padrão.
- As filas cheias retornam o comportamento de sobrecarga explícita, em vez de um crescimento ilimitado.
- `shutdown()` realiza um desligamento controlado e, em seguida, interrompe a operação se ocorrer um tempo limite
  é excedido.

Se o cliente ficar atrasado no consumo de eventos, o worker emite
`InProcessServerEvent::Lagged` e pode rejeitar solicitações pendentes do servidor, de modo que
os fluxos de aprovação não ficam parados indefinidamente atrás de uma fila saturada.
