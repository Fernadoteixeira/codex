# Interface do servidor Codex MCP [experimental]

Este documento descreve a interface experimental do servidor MCP do Codex: uma API JSON-RPC que opera sobre o protocolo de transporte Model Context Protocol (MCP) para controlar um mecanismo local do Codex.

- Status: experimental e sujeito a alterações sem aviso prévio
- Binário do servidor: `codex mcp-server` (ou `codex-mcp-server`)
- Transporte: MCP padrão via stdio (JSON-RPC 2.0, delimitado por linhas)

## Visão geral

O Codex disponibiliza métodos compatíveis com o MCP para gerenciar threads, turnos, contas, configurações e aprovações. Os tipos estão definidos em `app-server-protocol/src/protocol/{common,v1,v2}.rs` e são utilizados pela implementação do servidor de aplicativos em `app-server/`.

Em resumo:

- RPCs primários v2
  - `thread/start`, `thread/resume`, `thread/fork`, `thread/read`, `thread/list`
  - `turn/start`, `turn/steer`, `turn/interrupt`
  - `account/read`, `account/login/start`, `account/login/cancel`, `account/logout`, `account/rateLimits/read`
  - `config/read`, `config/value/write`, `config/batchWrite`
  - `model/list`, `app/list`, `collaborationMode/list`
- RPCs remanescentes compatíveis com a v1
  - `getConversationSummary`
  - `getAuthStatus`
  - `gitDiffToRemote`
  - `fuzzyFileSearch`, `fuzzyFileSearch/sessionStart`, `fuzzyFileSearch/sessionUpdate`, `fuzzyFileSearch/sessionStop`
- Notificações
  - notificações do tipo v2, como `thread/started`, `turn/completed`, `account/login/completed`
  - `codex/event/*` Notificações em tempo real sobre eventos dos agentes
  - `fuzzyFileSearch/sessionUpdated`, `fuzzyFileSearch/sessionCompleted`
- Aprovações (solicitações do servidor para o cliente)
  - `applyPatchApproval`, `execCommandApproval`

Consulte o código para obter as definições completas dos tipos e as formas exatas: `app-server-protocol/src/protocol/{common,v1,v2}.rs`.

## Iniciando o servidor

Execute o Codex como um servidor MCP e conecte um cliente MCP:

```bash
codex mcp-server | your_mcp_client
```

Para uma interface de usuário simples de inspeção, você também pode tentar:

```bash
npx @modelcontextprotocol/inspector codex mcp-server
```

Use o subcomando separado `codex mcp` para gerenciar os iniciadores de servidor MCP configurados em `config.toml`.

## Rosca e voltas

Utilize as APIs de thread e turn da v2 para todas as novas integrações. `thread/start` cria um thread, `turn/start` envia a entrada do usuário, `turn/interrupt` interrompe uma turn em andamento e `thread/list` / `thread/read` expõem o histórico persistido.

`getConversationSummary` permanece como um recurso de compatibilidade para clientes que ainda precisam de uma consulta de resumo por `conversationId` ou `rolloutPath`. As consultas por `conversationId` são preferíveis; as consultas por `rolloutPath` não funcionarão com armazenamentos de threads não locais.

Para conhecer os formatos completos das solicitações e respostas, consulte o arquivo README do servidor de aplicativos e as definições do protocolo em `app-server-protocol/src/protocol/v2.rs`.

## Modelos

Recupere o catálogo de modelos disponíveis na versão atual do Codex com `model/list`. A solicitação aceita parâmetros opcionais de paginação:

- `limit` - número de modelos a serem retornados (o valor padrão é definido pelo servidor)
- `cursor` - string opaca proveniente do `nextCursor` da resposta anterior

Cada resposta resulta em:

- `data` - lista ordenada de modelos. Um modelo inclui:
  - `id`, `model`, `displayName`, `description`
  - `supportedReasoningEfforts` - matriz de objetos com:
    - `reasoningEffort` - um valor de cadeia de caracteres fornecido pelo modelo; valores comuns são `none|minimal|low|medium|high|xhigh`
    - `description` - descrição de fácil compreensão para o esforço
  - `defaultReasoningEffort` - esforço sugerido para a interface do usuário
  - `inputModalities` - tipos de entrada aceitos pelo modelo
  - `supportsPersonality` - se o modelo suporta instruções específicas para cada personalidade
  - `isDefault` - se o modelo é recomendado para a maioria dos usuários
  - `upgrade` - ID do modelo de atualização opcional recomendado
  - `upgradeInfo` - objeto de metadados de atualização opcional com:
    - `model` - ID do modelo de atualização recomendado
    - `upgradeCopy` - texto opcional a ser exibido para a recomendação de atualização
    - `modelLink` - link opcional para a recomendação de atualização
    - `migrationMarkdown` - desconto opcional exibido ao apresentar a atualização
- `nextCursor` - passar para a próxima solicitação para continuar a paginação (opcional)

## Modos de colaboração (experimentais)

Recupere as predefinições do modo de colaboração integrado com `collaborationMode/list`. Esse endpoint não aceita paginação e retorna a lista completa em uma única resposta:

- `data` - lista ordenada de máscaras do modo de colaboração (configurações parciais a serem aplicadas sobre o modo básico)
  - Para campos de três opções, como `reasoning_effort` e `developer_instructions`, omita o campo para manter o valor atual, defina-o como `null` para zerá-lo ou defina um valor específico para atualizá-lo.
  - As predefinições integradas não definem `model`. A predefinição “Plan” define `reasoning_effort` como médio; os clientes mantêm ou substituem o modelo separadamente.

Ao enviar `turn/start` com `collaborationMode`, `settings.developer_instructions: null` significa “usar instruções integradas para o modo selecionado”.

## Fluxo de eventos

Enquanto uma conversa está em andamento, o servidor envia notificações:

- `codex/event` com a carga útil do evento Codex serializada. O formato corresponde aos tipos `Event` e `EventMsg` do `core/src/protocol.rs`. Algumas notificações incluem um `_meta.requestId` para correlacionar com a solicitação de origem.
- `fuzzyFileSearch/sessionUpdated` e `fuzzyFileSearch/sessionCompleted` para o fluxo de pesquisa difusa antigo.

Os clientes devem renderizar eventos e, quando houver, exibir solicitações de aprovação (consulte a próxima seção).

## Respostas da ferramenta

As ferramentas `codex` e `codex-reply` retornam cargas úteis padrão do MCP `CallToolResult`. Para garantir a compatibilidade com clientes MCP que preferem `structuredContent`, o Codex espelha os blocos de conteúdo dentro de `structuredContent` junto com o `threadId`.

Exemplo:

```json
{
  "content": [{ "type": "text", "text": "Hello from Codex" }],
  "structuredContent": {
    "threadId": "019bbed6-1e9e-7f31-984c-a05b65045719",
    "content": "Hello from Codex"
  }
}
```

## Aprovações (servidor → cliente)

Quando o Codex precisa de aprovação para aplicar alterações ou executar comandos, o servidor envia solicitações JSON-RPC ao cliente:

- `applyPatchApproval { conversationId, callId, fileChanges, reason?, grantRoot? }`
- `execCommandApproval { conversationId, callId, approvalId?, command, cwd, reason? }`

O cliente deve responder com `{ decision: "allow" | "deny" }` para cada solicitação.

## Funções auxiliares de autenticação

Para ver os modelos completos de solicitação/resposta e exemplos de fluxo, consulte o [Seção “Endpoints de autenticação (v2)” no README do servidor de aplicativos](../app-server/README.md#auth-endpoints-v2).

## Métodos de compatibilidade com versões anteriores

O servidor ainda aceita uma compatibilidade limitada com a versão 1 para os clientes de aplicativos existentes:

- `getConversationSummary`
- `getAuthStatus`
- `gitDiffToRemote`
- `fuzzyFileSearch`, `fuzzyFileSearch/sessionStart`, `fuzzyFileSearch/sessionUpdate`, `fuzzyFileSearch/sessionStop`

## Compatibilidade e estabilidade

Esta interface é experimental. Os nomes dos métodos, os campos e as formas dos eventos podem sofrer alterações. Para obter o esquema oficial, consulte `app-server-protocol/src/protocol/{common,v1,v2}.rs` e a configuração correspondente do servidor em `app-server/`.
