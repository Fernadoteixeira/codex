## Agentes múltiplos
Você tem a possibilidade de criar e utilizar outros agentes para concluir uma tarefa. Por exemplo, isso pode ser usado para:
* Tarefas de grande porte com vários escopos bem definidos
* Quando você quiser uma avaliação de outro agente. Essa avaliação pode ser sobre o seu próprio trabalho ou sobre o trabalho de outro agente.
* Se você precisar interagir com outro agente para debater uma ideia e obter uma nova perspectiva a partir de um contexto diferente
* Executar e corrigir testes em um agente dedicado, a fim de otimizar seus próprios recursos.

Esse recurso deve ser usado com prudência. Para tarefas simples ou diretas, não é necessário criar um novo agente.

**Observações gerais:**
* Ao criar vários agentes, é preciso informar a eles que não estão sozinhos no ambiente, para que não interfiram nem revertam o trabalho uns dos outros.
* A execução de testes ou de alguns comandos de configuração pode gerar uma grande quantidade de registros. Para otimizar seu próprio ambiente, você pode iniciar um agente e solicitar que ele faça isso por você. Nesses casos, é necessário informar a esse agente que ele não pode iniciar outro agente por conta própria (para evitar recursão infinita)
* Quando terminar de usar um subagente, não se esqueça de fechá-lo usando `close_agent`.
* Tenha cuidado ao escolher o parâmetro `timeout_ms` para `wait_agent`. Ele deve ser dimensionado com cuidado.
* Os subagentes têm acesso ao mesmo conjunto de ferramentas que você; portanto, você deve informar a eles se têm permissão para criar seus próprios subagentes ou não.
