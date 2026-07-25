---
name: codex-issue-digest
description: Run a GitHub issue digest for openai/codex by feature-area labels, all areas, and configurable time windows. Use when asked to summarize recent Codex bug reports or enhancement requests, especially for owner-specific labels such as tui, exec, app, or similar areas.
---

# Resumo das edições do Codex

## Objetivo

Por padrão, gere um resumo com as manchetes em destaque e focado em insights sobre `openai/codex` assuntos relacionados às categorias solicitadas nas últimas 24 horas. Respeite um intervalo de tempo diferente quando o usuário solicitar, por exemplo, “semana passada” ou “48 horas”. Por padrão, forneça uma resposta apenas com o resumo; inclua detalhes somente quando solicitado.

Inclua apenas os issues que atualmente tenham `bug` ou `enhancement`, além de pelo menos um rótulo de responsável solicitado. Se o usuário solicitar todas as áreas ou todos os rótulos, colete os issues `bug`/`enhancement` em todos os rótulos.

## Dados de entrada

- Rótulos de áreas de recursos, por exemplo `tui exec`
- `all areas` / `all labels` para analisar todos os rótulos de características atuais
- Substituição opcional do repositório, padrão `openai/codex`
- Intervalo de tempo opcional, padrão: últimas 24 horas; exemplos: `48h`, `7d`, `1w`, `past week`

## Fluxo de trabalho

1. Execute o coletor a partir de uma cópia atual do repositório do Codex:

```bash
python3 .codex/skills/codex-issue-digest/scripts/collect_issue_digest.py --labels tui exec --window-hours 24
```

Use `--window "past week"` ou `--window-hours 168` quando o usuário solicitar uma duração diferente da padrão. Use `--all-labels` quando o usuário disser “todas as áreas” ou “todos os rótulos”.

2. Use o JSON como fonte de referência. Ele inclui novas questões, novos comentários nas questões, novas reações/votos positivos, rótulos atuais, contagens atuais de reações, `summary_inputs` (pronto para o modelo) e `digest_rows` (detalhado).
3. Escolha o modo de saída de acordo com a solicitação do usuário:
   - Modo padrão: inicie o relatório com `## Summary` e não emita `## Details`.
   - Modo de detalhes antecipados: se o usuário solicitar detalhes, uma tabela, um resumo completo, a opção “incluir detalhes” ou algo semelhante, comece com `## Summary` e, em seguida, inclua `## Details`.
   - Modo de detalhes de acompanhamento: se o usuário solicitar mais detalhes após um resumo, gere `## Details` a partir do JSON do coletor existente, desde que este ainda esteja disponível; caso contrário, execute novamente o coletor.
4. Em `## Summary`, escreva um resumo executivo começando pelo título:
   - A primeira linha não em branco abaixo de `## Summary` deve ser um título ou uma conclusão de uma única linha, e não um marcador. Ela deve ser útil mesmo que o leitor pare por ali.
   - Em dias tranquilos, escolha exatamente: `No major issues reported by users.` Use essa opção quando não houver linhas destacadas, nenhum tema repetido recentemente e nada que exija ação do responsável.
   - Quando os usuários estiverem relatando problemas significativos, faça com que o título indique o número ou o tema, por exemplo, `Two issues are being surfaced by users:`.
   - Imediatamente abaixo de um título ativo, liste apenas as questões ou temas que estão chamando atenção, ordenados por importância. Comece cada linha com o código `attention_marker` da linha, quando presente, seguido de uma descrição concisa e compreensível para o responsável, além de referências às questões inseridas no texto.
   - Considere `🔥🔥` como digno de manchete e `🔥` como destacado. Não adicione o emoji de fogo por conta própria; apenas copie o `attention_marker` da linha.
   - Limite qualquer detalhe adicional do resumo após o título a 1 a 3 linhas concisas, apenas quando ele acrescentar uma ressalva relevante para a tomada de decisão, um tema recorrente ou uma ação do responsável.
   - Não inclua contagens de rotina, estatísticas gerais ou resumos de tabelas com sinais fracos em `## Summary`, a menos que alterem o título. Coloque os metadados e as contagens opcionais em `## Details` ou no rodapé.
   - No modo padrão, encerre o relatório com uma mensagem concisa, como `Want details? I can expand this into the issue table.`. Mantenha isso separado do título do resumo para que o título permaneça claro.
   - Agrupe e nomeie os temas por conta própria a partir de `summary_inputs`; o coletor não codifica categorias de problemas de forma fixa, propositalmente.
   - Utilize um agrupamento somente quando as questões realmente compartilharem o mesmo problema do produto. Se várias questões compartilharem apenas uma plataforma ou etiqueta genérica, descreva-as individualmente.
   - Não omita um tema recorrente apenas porque suas questões específicas ficam abaixo do limite da tabela de detalhes. Vários relatos semelhantes devem ser destacados como uma preocupação recorrente dos clientes.
   - No caso de linhas com um único assunto, resuma a questão diretamente, em vez de chamá-la de “grupo”.
   - Use os links numerados embutidos de cada linha relevante, a partir de `ref_markdown`.
   - Exemplo de resumo conciso:

```markdown
## Summary
No major issues reported by users.

Source: collector v5, git `abc123def456`, window `2026-04-27T00:00:00Z` to `2026-04-28T00:00:00Z`.
Want details? I can expand this into the issue table.
```

   - Exemplo de resumo ativo:

```markdown
## Summary
Two issues are being surfaced by users:
🔥🔥 Terminal launch hangs on startup [1](https://github.com/openai/codex/issues/123)
🔥 Resume switches model providers unexpectedly [2](https://github.com/openai/codex/issues/456)

Source: collector v5, git `abc123def456`, window `2026-04-27T00:00:00Z` to `2026-04-28T00:00:00Z`.
Want details? I can expand this into the issue table.
```
5. Em `## Details`, quando forem solicitados detalhes, inclua uma tabela concisa apenas quando for útil:
   - Selecione as linhas a partir de `digest_rows`; inclua uma coluna `Refs` utilizando o valor `ref_markdown` de cada linha.
   - Mantenha a tabela concisa; omita as linhas com sinais fracos quando o resumo já as abranja.
   - Utilize colunas compactas, como marcador, área, tipo, descrição, interações e referências.
   - A célula `Description` deve conter uma frase curta e compreensível para o proprietário. Utilize a linha `description`, o título, trechos do corpo do texto e comentários recentes, mas não copie mecanicamente o título original da issue do GitHub quando ele contiver detalhes irrelevantes.
   - Uma frase clara que indica que tudo está tranquilo e não há motivo para preocupação quando não há nenhum sinal significativo.
6. Use o JSON `attention_marker` exatamente como está. Ele fica vazio para linhas normais, `🔥` para linhas destacadas e `🔥🔥` para linhas que exigem muita atenção. Os limites reais estão em `attention_thresholds`.
7. Utilize referências numeradas no texto sempre que uma linha ou um marcador indicar questões, por exemplo, `Compaction bugs [1](https://github.com/openai/codex/issues/123), [2](https://github.com/openai/codex/issues/456)`. Não inclua uma seção separada para notas de rodapé.
8. Marque `interactions` como `Interactions`; isso contabiliza usuários humanos únicos do GitHub que criaram uma nova issue, adicionaram um novo comentário ou reagiram durante o período solicitado. Várias postagens/reações do mesmo usuário na mesma issue contam apenas uma vez.
9. Mencione o coletor `script_version`, a verificação de repositório `git_head` e a janela de tempo em uma única linha de código concisa. No modo padrão, coloque isso antes do prompt de detalhes, para que a linha final ainda pergunte se o usuário deseja detalhes. No modo “detalhes antecipados”, isso pode ser colocado no rodapé.

## Tratamento de reações

O coletor utiliza os endpoints de reações do GitHub, que incluem `created_at`, para contar as reações criadas durante a janela de processamento para issues hidratados. Ele relata tanto as contagens de reações dentro da janela quanto os totais atuais de reações. Considere os totais atuais de reações como engajamento contínuo e trate `new_reactions` / `new_upvotes` como atividade dentro do intervalo.

Por padrão, o coletor busca comentários de issues com `since=<window start>` e limita o número de páginas de comentários por issue. Isso evita que discussões históricas muito longas dominem a geração do resumo e concentra o relatório nas postagens recentes. Use `--fetch-all-comments` apenas quando o histórico completo de comentários for mais importante do que o tempo de execução.

A pesquisa de issues no GitHub ainda é alimentada pelo issue `updated_at`; portanto, um issue que contenha apenas reações pode passar despercebido se as reações não aumentarem o número `updated_at`. Para abranger todos os casos de issues que contêm apenas reações, seria necessário um armazenamento de instantâneos persistentes ou uma varredura mais ampla dos issues rotulados.

## Marcadores de atenção

O coletor ajusta os indicadores de atenção de acordo com a janela de tempo solicitada. A linha de base é de 5 usuários humanos únicos para `🔥` e 10 usuários humanos únicos para `🔥🔥` ao longo de 24 horas; janelas mais longas ou mais curtas ajustam esses limites de forma linear e arredondam para cima. Por exemplo, um relatório semanal utiliza 35 e 70 interações. Usuários humanos únicos são aqueles que criaram uma nova issue, escreveram um novo comentário ou reagiram durante a janela, incluindo votos positivos. Várias ações do mesmo usuário na mesma questão contam apenas uma vez. Postagens e reações de bots são excluídas. Em texto, explique isso como alta interação do usuário, em vez de citar o emoji.

## Frescor

A automação deve ser executada a partir de um checkout do repositório que contenha essa skill. Para uso diário compartilhado, opte por um destes padrões:

- Execute a automação em um checkout que seja atualizado antes do início da automação, por exemplo, com `git pull --ff-only`.
- Se a automação não puder alterar o checkout com segurança, faça com que ela relate o valor atual `git_head` da saída do coletor, para que os leitores saibam qual versão da skill/script gerou o resumo.

## Exemplo de solicitação ao proprietário

```text
Use $codex-issue-digest to run the Codex issue digest for labels tui and exec over the previous 24 hours.
```

```text
Use $codex-issue-digest to run the Codex issue digest for all areas over the past week.
```

## Validação

Faça um teste do coletor para verificar se há problemas recentes:

```bash
python3 .codex/skills/codex-issue-digest/scripts/collect_issue_digest.py --labels tui exec --window-hours 24
```

```bash
python3 .codex/skills/codex-issue-digest/scripts/collect_issue_digest.py --all-labels --window "past week" --limit-issues 10
```

Execute os testes de script específicos:

```bash
pytest .codex/skills/codex-issue-digest/scripts/test_collect_issue_digest.py
```
