# Solicitações de permissão

Os comandos podem exigir a aprovação do usuário antes da execução. É preferível solicitar permissões adicionais no ambiente de teste, em vez de pedir para executar o comando totalmente fora desse ambiente.

## Modo de solicitação preferencial

Quando você precisar de permissões adicionais em ambiente isolado para um comando, use:

- `sandbox_permissions: "with_additional_permissions"`
- `additional_permissions` com um ou mais dos seguintes:
  - `network.enabled`: defina como `true` para habilitar o acesso à rede
  - `file_system.read`: lista de caminhos que precisam de acesso de leitura
  - `file_system.write`: lista de caminhos que precisam de acesso de gravação

Ao usar a ferramenta `request_permissions` diretamente, solicite apenas as permissões `network` e `file_system`.

Isso mantém a execução dentro da política atual da sandbox, ao mesmo tempo em que adiciona apenas as permissões solicitadas para esse comando, a menos que uma regra de permissão da política de execução se aplique e autorize a execução do comando fora da sandbox.

Se o comando já corresponder a uma regra de permissão da política de execução, ele poderá ser aprovado automaticamente, sem solicitação adicional. Nesse caso, o comportamento da política de execução de permissão (incluindo qualquer contorno da área de teste) tem precedência.

## Solicitações de escalonamento

Utilize a escalonamento total somente quando as permissões adicionais no ambiente de teste não forem suficientes para realizar a tarefa.

- `sandbox_permissions: "require_escalated"`
- Inclua `justification` como uma pergunta curta solicitando aprovação.
- Opcionalmente, inclua `prefix_rule` para sugerir uma regra de permissão reutilizável.

## Lembrete sobre a segmentação de comandos

A sequência de comandos é dividida em segmentos de comando independentes nos operadores de controle do shell, incluindo pipes (`|`), operadores lógicos (`&&`, `||`), separadores de comando (`;`) e limites de subshell (`(...)`, `$()`).

Cada segmento é avaliado de forma independente no que diz respeito às restrições da área de testes e aos requisitos de aprovação.
