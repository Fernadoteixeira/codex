# Memórias

Este diretório contém os crates de memória reutilizáveis e a documentação do pipeline de memória.

A orquestração em tempo de execução para a Fase 1 e a Fase 2 ainda está localizada em `codex-core`, em
`codex-rs/core/src/memories/`.

## Caixas

- `codex-rs/memories/read` (`codex-memories-read`) é o proprietário do caminho de leitura:
  injeção de instruções de desenvolvimento de memória, análise de citações de memória e
  classificação de telemetria de leitura e uso.
- `codex-rs/memories/write` (`codex-memories-write`) é o proprietário do caminho de gravação:
  Renderização imediata das Fases 1 e 2, auxiliares de artefatos do sistema de arquivos,
  auxiliares de comparação de espaços de trabalho e otimização de recursos de extensões.

## Modelos de prompts

Os modelos de prompt de memória ficam na crate que os utiliza:

- Os arquivos-modelo sem data são as versões mais recentes canônicas utilizadas no momento da execução:
  - `read/templates/memories/read_path.md`
  - `write/templates/memories/stage_one_system.md`
  - `write/templates/memories/stage_one_input.md`
  - `write/templates/memories/consolidation.md`
- Em `codex`, edite esses arquivos de modelo sem data diretamente no local.
- O fluxo de trabalho desatualizado de cópias instantâneas é usado no repositório separado `openai/project/agent_memory/write` do harness, e não aqui.

## Quando estiver em execução

O pipeline é acionado quando uma sessão root é iniciada, e somente se:

- a sessão não é efêmera
- o recurso de memória está ativado
- a sessão não é uma sessão de subagente
- O banco de dados estadual está disponível

Ele é executado de forma assíncrona em segundo plano e executa duas fases na seguinte ordem: Fase 1 e, em seguida, Fase 2.

## Fase 1: Extração de rollout (por thread)

A Fase 1 identifica implementações recentes que atendem aos critérios e extrai uma memória estruturada de cada uma delas.

As implementações elegíveis são selecionadas do banco de dados estadual por meio das regras iniciais de reivindicação. Na prática, isso significa que
O pipeline leva em consideração apenas as implementações que:

- de fontes de sessão interativa permitidas
- dentro do intervalo de idade configurado
- permanecer inativo por tempo suficiente (para evitar resumir lançamentos ainda ativos ou recentes)
- que ainda não seja de propriedade de outro trabalhador da fase 1 em atividade
- dentro dos limites de varredura/reivindicação na inicialização (trabalho limitado por inicialização)

O que ele faz:

- recupera um conjunto limitado de tarefas de implementação do banco de dados de estado (recuperação de inicialização)
- os filtros restringem o conteúdo aos itens de resposta relevantes para a memória
- envia cada lançamento para um modelo (em paralelo, com um limite de concorrência)
- espera uma saída estruturada contendo:
  - um detalhado `raw_memory`
  - um compacto `rollout_summary`
  - opcional `rollout_slug`
- oculta informações confidenciais dos campos de memória gerados
- armazena os resultados bem-sucedidos de volta no banco de dados de estado como resultados da etapa 1

Concorrência / coordenação:

- A Fase 1 executa vários trabalhos de extração em paralelo (com um limite fixo de simultaneidade), de modo que a geração de memória inicial possa processar várias implementações ao mesmo tempo.
- Cada tarefa é alocada/reservada no banco de dados estadual antes do processamento, o que evita a duplicação de trabalho entre trabalhadores/inicializações simultâneas.
- As tarefas com falha são marcadas com um intervalo de repetição, de modo que são repetidas posteriormente, em vez de entrarem em um ciclo contínuo.

Resultados profissionais:

- `succeeded` (memória produzida)
- `succeeded_no_output` (execução válida, mas nada útil foi gerado)
- `failed` (com retardo de repetição de tentativas e gerenciamento de validade no banco de dados)

A Fase 1 é a etapa que transforma lançamentos individuais em registros de memória respaldados pelo banco de dados.

## Fase 2: Consolidação global

A Fase 2 consolida os resultados mais recentes da Fase 1 nos artefatos de memória do sistema de arquivos e, em seguida, executa um agente de consolidação dedicado.

O que ele faz:

- requer um único bloqueio global de fase 2 antes de acessar a raiz das memórias (portanto, apenas uma consolidação
  (inspeciona ou altera o espaço de trabalho de cada vez)
- carrega um conjunto limitado de saídas da fase 1 do banco de dados de estados utilizando a fase 2
  regras de seleção:
  - ignora as memórias cujo `last_usage` fica fora do intervalo configurado
    Janela `max_unused_days`
  - para memórias sem `last_usage`, recorre a `generated_at`, tão recente
    as memórias nunca utilizadas ainda podem ser selecionadas
  - classifica as memórias elegíveis primeiro por `usage_count` e, em seguida, pelas mais recentes
    `last_usage` / `generated_at`
- calcula uma marca d'água de conclusão a partir da marca d'água reivindicada + os carimbos de data e hora de entrada mais recentes
- sincroniza os artefatos da memória local na raiz “memories”:
  - `raw_memories.md` (memórias brutas mescladas, ordem ascendente estável dos IDs dos tópicos)
  - `rollout_summaries/` (um arquivo de resumo por implementação selecionada)
- mantém as memórias como um diretório de linha de base do Git, inicializado em
  `~/.codex/memories/.git` por `codex-git-utils`
- elimina resumos de implementação obsoletos que não estão mais selecionados
- elimina os arquivos de recursos de extensão de memória mais antigos do que o período de retenção da extensão
  janela, para que a limpeza apareça no diff da área de trabalho
- grava `phase2_workspace_diff.md` na raiz do diretório “memories” com o diff no estilo git
  da linha de base bem-sucedida da Fase 2 anterior para a árvore de trabalho atual
- se o espaço de trabalho de memória não apresentar alterações após a sincronização/limpeza de artefatos, marca o
  A tarefa foi concluída com sucesso e o programa é encerrado

Se houver alterações no espaço de trabalho da memória, então:

- gera um subagente de consolidação interno
- gera o prompt da Fase 2 com o caminho para o arquivo de comparação do espaço de trabalho gerado
- define o agente em `phase2_workspace_diff.md` para o contexto detalhado da comparação
- o executa sem autorizações, sem rede e apenas com acesso de gravação local
- desativa a colaboração para esse agente (para evitar a delegação recursiva)
- monitora o status do agente e verifica a atividade do contrato global da tarefa enquanto ela está em execução
- redefine a linha de base do Git na memória após o agente concluir a operação com sucesso; o
  O arquivo de diferenças gerado é removido antes dessa redefinição, de modo que o conteúdo excluído não é
  armazenados no artefato do prompt ou em objetos Git inacessíveis
- registra o sucesso ou o fracasso da tarefa da fase 2 no banco de dados estadual quando o agente conclui a tarefa

Comportamento da seleção e da comparação de áreas de trabalho:

- As execuções bem-sucedidas da Fase 2 correspondem exatamente aos instantâneos da Fase 1 que foram utilizados
  `selected_for_phase2 = 1` e persistir a correspondência
  `selected_for_phase2_source_updated_at`
- As atualizações da Fase 1 preservam a linha de base anterior `selected_for_phase2` até que
  a próxima execução bem-sucedida da Fase 2 a reescreve
- A Fase 2 carrega apenas as N entradas selecionadas da Fase 1 que estão no topo da lista no momento e sincroniza
  `rollout_summaries/` diretamente para essa seleção, resulta em `raw_memories.md`
  em ordem crescente e estável de IDs de tópicos, para evitar oscilações na classificação de uso, e então permite que o
  Comparação de alterações no espaço de trabalho no estilo Git, mostrando adições, modificações e exclusões
  em comparação com a linha de base de memória anterior, que apresentou bons resultados
- quando o conjunto de entradas selecionado estiver vazio, os arquivos obsoletos `rollout_summaries/` são
  é removido e `raw_memories.md` é reescrito no espaço reservado para entrada vazia;
  resultados consolidados, como `MEMORY.md`, `memory_summary.md` e `skills/`
  ficam a cargo do agente para atualização

Comportamento da marca d’água:

- O bloqueio global de fase 2 não utiliza watermarks do banco de dados como verificação de alterações; git
  O nível de sujeira do espaço de trabalho determina se um agente precisa ser executado.
- A disputa global sobre a fase 2 do projeto ainda utiliza um valor de referência de entrada como registro contábil
  para o carimbo de data e hora mais recente da entrada no banco de dados conhecido no momento em que a tarefa foi reivindicada.
- A Fase 2 recalcula um `new_watermark` utilizando o valor máximo entre:
  - a marca d’água alegada
  - o carimbo de data/hora mais recente `source_updated_at` nas entradas da etapa 1 que foram efetivamente carregadas
- Se for bem-sucedida, a Fase 2 armazena esse marcador de conclusão no banco de dados.
- Isso evita que a marca d’água de conclusão registrada seja deslocada para trás, mas não
  decidir se há trabalho na Fase 2.

Na prática, essa fase é responsável por atualizar o espaço de trabalho da memória no disco e por gerar/atualizar os resultados consolidados de memória de nível superior.

## Por que é dividido em duas fases

- A Fase 1 abrange várias implementações e gera registros de memória normalizados por implementação.
- A Fase 2 serializa a consolidação global para que os artefatos da memória compartilhada sejam atualizados de forma segura e consistente.
