---
name: babysit-pr
description: Babysit a GitHub pull request after creation by continuously polling review comments, CI checks/workflow runs, and mergeability state until the PR is merged/closed or user help is required. Diagnose failures, retry likely flaky failures up to 3 times, auto-fix/push branch-related issues when appropriate, and keep watching open PRs so fresh review feedback is surfaced promptly. Use when the user asks Codex to monitor a PR, watch CI, handle review comments, or keep an eye on failures and feedback on an open PR.
---

# PR Babá

## Objetivo
Acompanhe um PR de forma persistente até que ocorra um destes resultados finais:

- O PR foi mesclado ou encerrado.
- Uma situação requer a ajuda do usuário (por exemplo, problemas na infraestrutura de CI, falhas recorrentes e imprevisíveis após o esgotamento do limite de tentativas, problemas de permissão ou ambiguidades que não podem ser resolvidas com segurança).
- Marco opcional de transferência: o PR está atualmente com status verde + pronto para fusão + sem pendências de revisão. Considere isso como um estado de progresso, e não como um ponto de parada para os observadores; assim, comentários de revisão que chegarem mais tarde ainda serão exibidos prontamente enquanto o PR permanecer aberto.

Não interrompa o processo apenas porque um único instantâneo retorna `idle` enquanto ainda há verificações pendentes.

## Dados de entrada
Aceite qualquer uma das seguintes opções:

- Sem argumento de PR: deduzir o PR a partir do branch atual (`--pr auto`)
- Número de RP
- URL de RP

## Fluxo de trabalho principal

1. Quando o usuário solicitar “monitorar”/“acompanhar”/“ficar de olho” em um PR, comece com o modo contínuo do observador (`--watch`), a menos que você esteja realizando intencionalmente um instantâneo de diagnóstico único.
2. Execute o script do observador para gerar um instantâneo do estado do PR/revisão/CI (ou consuma cada instantâneo transmitido a partir de `--watch`).
3. Verifique a lista `actions` na resposta JSON.
4. Se `diagnose_ci_failure` estiver presente, verifique os registros das execuções com falha e classifique a falha.
5. Se for provável que a falha tenha sido causada pelo ramo atual, aplique as correções no código localmente, faça o commit e envie as alterações. Não corrija testes instáveis aleatórios, a infraestrutura de CI, interrupções nas dependências, problemas com os executores ou outras falhas que não estejam relacionadas ao ramo.
6. Se `process_review_comment` estiver presente, analise os itens de revisão publicados que vieram à tona e decida se deve tratá-los.
7. Se um item de revisão for passível de ação e estiver correto, aplique o patch no código localmente, faça o commit, envie as alterações e, em seguida, resolva o tópico de revisão associado somente quando permitido pela política de alteração de estado do GitHub descrita abaixo.
8. Não publique respostas a comentários ou tópicos de revisão feitos por pessoas, a menos que o usuário confirme explicitamente a resposta exata. Se um item de revisão humana não exigir ação, já tiver sido resolvido ou não for válido, apresente o item e a resposta recomendada ao usuário, em vez de responder no GitHub.
9. Se for provável que a falha seja esporádica ou não esteja relacionada e `retry_failed_checks` estiver presente, reexecute as tarefas com falha usando `--retry-failed-now`.
10. Se houver tanto um feedback de revisão passível de ação quanto `retry_failed_checks`, priorize o feedback de revisão; um novo commit acionará novamente a CI, portanto, evite reexecutar verificações instáveis no SHA antigo, a menos que você adie intencionalmente a alteração da revisão.
11. A cada ciclo, verifique se há novos comentários de revisão antes de tomar medidas em relação a falhas de CI ou ao status de fusão; em seguida, verifique o status de fusão/conflito de fusão (por exemplo, por meio de `gh pr view`) juntamente com a CI.
12. Após qualquer ação de envio ou reexecução, retorne imediatamente à etapa 1 e continue a consultar o SHA/estado atualizado.
13. Se você estivesse usando `--watch` antes de fazer uma pausa para aplicar o patch/fazer o commit/fazer o push, reinicie `--watch` por conta própria no mesmo turno, imediatamente após o push (não espere que o usuário reinvoque a habilidade).
14. Repita a verificação até que apareça `stop_pr_closed` ou até que seja encontrado um bloqueador que exija a ajuda do usuário. Um PR verde, sem pendências de revisão e pronto para fusão é um marco de progresso, não um motivo para interromper o acompanhamento enquanto o PR ainda estiver aberto.
15. Manter a propriedade do terminal/sessão: enquanto o monitoramento estiver ativo, continue consumindo a saída do observador no mesmo turno; não deixe um processo `--watch` desanexado em execução e, em seguida, encerre o turno como se o monitoramento tivesse sido concluído.

## Comandos

### Foto instantânea de uma única tomada

```bash
python3 .codex/skills/babysit-pr/scripts/gh_pr_watch.py --pr auto --once
```

### Monitoramento contínuo (JSONL)

```bash
python3 .codex/skills/babysit-pr/scripts/gh_pr_watch.py --pr auto --watch
```

### Iniciar um ciclo de repetição intermitente (somente quando o observador indicar)

```bash
python3 .codex/skills/babysit-pr/scripts/gh_pr_watch.py --pr auto --retry-failed-now
```

### Meta explícita de relações públicas

```bash
python3 .codex/skills/babysit-pr/scripts/gh_pr_watch.py --pr <number-or-url> --once
```

## Classificação de falhas do CI
Use os comandos `gh` para analisar as execuções com falha antes de decidir executá-las novamente.

- `gh run view <run-id> --json jobs,name,workflowName,conclusion,status,url,headSha`
- `gh api repos/<owner>/<repo>/actions/runs/<run-id>/jobs -X GET -f per_page=100`
- `gh api repos/<owner>/<repo>/actions/jobs/<job-id>/logs > /tmp/codex-gh-job-<job-id>-logs.zip`
- `gh run view <run-id> --log-failed` como alternativa após a conclusão da execução geral do fluxo de trabalho

O `gh run view --log-failed` tem escopo de execução do fluxo de trabalho e pode não expor os logs de tarefas com falha até que a execução como um todo seja concluída. Para um diagnóstico mais rápido, verifique primeiro as tarefas da execução e, assim que uma tarefa específica falhar, obtenha os logs dessa tarefa diretamente do endpoint de logs de tarefas do Actions. O observador inclui uma lista `failed_jobs` com os valores `job_id` e `logs_endpoint` de cada tarefa com falha, quando o GitHub os disponibiliza.

É preferível considerar as falhas como relacionadas a um branch quando os logs das tarefas com falha indicam alterações no código (compilação/teste/lint/verificação de tipos/snapshots/análise estática nas áreas afetadas).

É preferível tratar as falhas como esporádicas ou não relacionadas quando os logs indicam problemas transitórios de infraestrutura ou externos (timeouts, falhas no provisionamento de runners, interrupções no registro ou na rede, erros de infraestrutura do GitHub Actions).

Não tente corrigir falhas esporádicas ou não relacionadas alterando testes, scripts de compilação, configuração de CI, fixação de dependências ou código relacionado à infraestrutura, a menos que os logs relacionem claramente a falha ao branch do PR. Para falhas instáveis ou não relacionadas, execute novamente somente quando o observador recomendar `retry_failed_checks`; caso contrário, aguarde ou solicite ajuda ao usuário.

Se a classificação for ambígua, faça uma tentativa de diagnóstico manual antes de optar por repetir o processo.

Leia `.codex/skills/babysit-pr/references/heuristics.md` para ver uma lista de verificação concisa.

## Tratamento de comentários em avaliações
O observador exibe itens para revisão provenientes de:

- Comentários sobre a questão de relações públicas
- Comentários de revisão no texto
- Envios para revisão (COMENTÁRIO / APROVADO / ALTERAÇÕES_SOLICITADAS)

Aja apenas com base nos comentários publicados. Ignore as submissões de revisão no estado `PENDING` do GitHub e os comentários embutidos
comentários associados a essas revisões pendentes. Não marque os comentários de revisão pendentes como lidos; eles devem
poderá ser exibido após o revisor enviar a revisão.

Ele exibe intencionalmente o feedback dos bots revisores do Codex (por exemplo, comentários/revisões de `chatgpt-codex-connector[bot]`), além do feedback dos revisores humanos. A maior parte do ruído irrelevante gerado pelos bots ainda deve ser ignorada.
Por motivos de segurança, o observador exibe automaticamente apenas autores de revisões confiáveis (por exemplo, OWNER/MEMBER/COLLABORATOR do repositório, além do operador autenticado) e bots de revisão aprovados, como o Codex.
Em um arquivo de status de observadores recém-criado, os comentários de revisão publicados e ainda não respondidos podem aparecer imediatamente (não apenas os comentários que chegam após o início do monitoramento). Isso é intencional, para que os comentários de revisão já abertos não sejam ignorados.

Quando você concorda com um comentário e ele é passível de ação:

1. Faça as correções no código localmente.
2. Confirme com `codex: address PR review feedback (#<n>)`.
3. Envie para o branch principal do PR.
4. Após o envio ser bem-sucedido, resolva o tópico de revisão do GitHub associado somente quando permitido pela política de alteração de estado do GitHub descrita abaixo.
5. Retome a observação no novo SHA imediatamente (não interrompa após relatar o envio).
6. Se o monitoramento estiver em modo `--watch`, reinicie o `--watch` imediatamente após o comando, no mesmo turno; não espere que o usuário solicite novamente.

Não publique respostas automáticas a comentários ou discussões de revisão no GitHub criados por pessoas. Se você discordar de um comentário feito por uma pessoa, achar que ele não requer ação ou já foi resolvido, ou precisar responder a uma pergunta, informe o usuário sobre o item com uma sugestão de resposta e aguarde uma confirmação explícita antes de publicar qualquer coisa no GitHub. Se o usuário aprovar uma resposta, coloque o prefixo `[codex]` para que fique claro que a resposta é automatizada e não foi enviada pelo usuário humano.
Se, posteriormente, o observador publicar sua própria resposta aprovada — uma vez que o operador autenticado é considerado um autor de revisão confiável —, considere esse item de sua autoria como já tratado e não responda novamente.
Se um comentário ou tópico de revisão de código já estiver marcado como resolvido no GitHub, considere-o como não passível de ação e ignore-o sem preocupações, a menos que surjam novos comentários de acompanhamento ainda não resolvidos.

## Política de alteração de estado do GitHub

Você pode ler qualquer estado de PR necessário para o monitoramento. As gravações devem estar em conformidade com esta política.

Você pode enviar PRs para atualizar o código em revisão ou para forçar a reexecução da integração contínua, conforme descrito acima.

Você pode resolver as sequências de comentários de avaliação feitas pela pessoa que solicitou o serviço de babá ou pelo Codex
bot de revisão. Ao resolver o problema, deixe um comentário com o prefixo `[from Codex]: ` e explique quais alterações foram feitas
que você fez e em qual commit elas estão incluídas. Não altere os tópicos de revisão se outras pessoas, além do
participaram os usuários que solicitaram serviços de babá.

Antes de fazer qualquer alteração, verifique você mesmo o status do PR, em vez de confiar no script de monitoramento do PR
saída.

A menos que seja solicitado explicitamente, não:

* comente nos tópicos de avaliação de outras pessoas; em vez disso, converse com o usuário no chat
* resolver tópicos de revisão criados por outras pessoas que não o usuário
* interagir com outras pessoas além do usuário
* marcar PRs como rascunhos ou prontos para revisão
* fechar ou reabrir PRs

Em geral, nunca realize ações no GitHub que tornem difícil distinguir se foi você ou o usuário quem as realizou
algo visível para outras pessoas. Em caso de dúvida, peça esclarecimentos ao usuário pelo chat.

## Regras de segurança do Git

- Trabalhe apenas no branch principal do PR.
- Evite comandos do Git que possam causar danos.
- Não mude de branch, a menos que seja necessário para recuperar o contexto.
- Antes de editar, verifique se há alterações não relacionadas e não confirmadas. Se houver, interrompa o processo e pergunte ao usuário.
- Após cada correção bem-sucedida, faça o commit e `git push` e, em seguida, execute novamente o observador.
- Se você interrompeu uma sessão ao vivo `--watch` para fazer a correção, reinicie `--watch` imediatamente após o envio, no mesmo turno.
- Não execute vários processos `--watch` simultaneamente para o mesmo arquivo PR/state; mantenha uma sessão do watcher ativa e reutilize-a até que ela seja encerrada ou você a reinicie intencionalmente.
- Um avanço não é um resultado final; continue o ciclo de monitoramento, a menos que seja atendida uma condição de parada estrita.

Padrões para mensagens de commit:

- `codex: fix CI failure on PR #<n>`
- `codex: address PR review feedback (#<n>)`

## Padrão de ciclo de monitoramento
Use este loop em uma sessão ao vivo do Codex:

1. Execute `--once`.
2. Leia `actions`.
3. Primeiro, verifique se o PR já foi incorporado ou encerrado de alguma outra forma; se for o caso, informe esse estado final e interrompa a consulta imediatamente.
4. Verifique o resumo do CI, os novos itens para revisão e o status de compatibilidade com a fusão e de conflitos.
5. Diagnostique falhas no CI e classifique-as como relacionadas ao branch ou como instáveis/não relacionadas. Se a execução geral ainda estiver pendente, mas `failed_jobs` já incluir uma tarefa com falha, obtenha os logs dessa tarefa e faça o diagnóstico imediatamente, em vez de esperar que toda a execução do fluxo de trabalho seja concluída. Aplique correções somente quando a falha for relacionada ao branch.
6. Para cada item de revisão apresentado por outro autor, aplique o patch/faça o commit/envie (push) se for passível de ação; em seguida, resolva-o somente quando permitido pela política de alteração de estado do GitHub descrita acima. Se não for passível de ação, já tiver sido resolvido ou exigir uma resposta por escrito, apresente-o ao usuário com uma resposta sugerida, em vez de publicá-lo automaticamente. Se um snapshot posterior exibir sua própria resposta aprovada, trate-a como informativa e continue sem responder novamente.
7. Processe os comentários de revisão que exigem ação antes de repetir as execuções instáveis, quando ambas estiverem presentes; se uma correção de revisão exigir um commit, envie-o e ignore a repetição das verificações que falharam no SHA antigo.
8. Repita as verificações que falharam somente quando `retry_failed_checks` estiver presente e você não estiver prestes a substituir o SHA atual por um commit de revisão ou correção de CI. Não faça alterações no código devido a falhas pontuais não relacionadas ou falhas de infraestrutura apenas para que o CI fique no verde.
9. Se você enviou um commit, resolveu um tópico de revisão elegível ou acionou uma nova execução, relate a ação resumidamente e continue com a sondagem (não pare). Se um comentário de revisão humana exigir uma resposta por escrito no GitHub, pare e peça confirmação antes de publicar.
10. Após um push de revisão e correção, reinicie proativamente o monitoramento contínuo (`--watch`) no mesmo ciclo, a menos que uma condição de interrupção estrita já tenha sido atingida.
11. Se tudo estiver em andamento, pronto para fusão, sem bloqueios decorrentes de aprovações de revisão obrigatórias e não houver itens de revisão pendentes, informe que o PR está pronto para fusão, mas mantenha o monitoramento ativo para que novos comentários de revisão sejam exibidos rapidamente enquanto o PR permanecer aberto.
12. Se você estiver enfrentando um problema que exija ajuda do usuário (interrupção da infraestrutura, esgotamento das tentativas de recuperação, solicitação pouco clara do revisor, permissões), relate o impedimento e interrompa o processo.
13. Caso contrário, entre em modo de espera de acordo com a cadência de sondagem abaixo e repita o processo.

Quando o usuário solicitar explicitamente monitorar/acompanhar/ficar de olho em um PR, dê preferência ao `--watch` para que a verificação continue de forma autônoma em um único comando. Use instantâneos repetidos com `--once` apenas para depuração, testes locais ou quando o usuário solicitar explicitamente uma verificação única.
Não pare para perguntar ao usuário se deseja continuar a sondagem; continue de forma autônoma até que uma condição de parada estrita seja atendida ou até que o usuário interrompa explicitamente o processo.
Não devolva o controle ao usuário após um envio de revisão e correção apenas porque um novo SHA foi criado; reiniciar o observador e voltar ao ciclo de sondagem faz parte da mesma tarefa de acompanhamento.
Se um processo `--watch` ainda estiver em execução e nenhuma condição de parada estrita tiver sido atingida, a tarefa de monitoramento ainda estará em andamento; continue recebendo/consumindo a saída do observador em vez de encerrar o turno.

## Frequência de sondagem
Mantenha as verificações de revisão rigorosas e continue monitorando mesmo depois que o CI ficar verde:

- Enquanto a CI não estiver no status “verde” (pendente/em execução/na fila ou com falha): verifique a cada 1 minuto.
- Depois que o CI ficar verde: continue fazendo consultas na cadência básica enquanto o PR permanecer aberto, para que os comentários de revisão recém-postados sejam exibidos imediatamente, em vez de esperar por um longo período de espera no estado verde.
- Reinicie a cadência imediatamente sempre que houver alguma alteração (novo commit/SHA, alterações no status de verificação, novos comentários de revisão, alterações na capacidade de mesclagem, alterações na decisão de revisão).
- Se o CI voltar a apresentar falha (novo commit, nova execução ou regressão): mantenha a frequência básica de verificação.
- Se alguma consulta indicar que o PR foi mesclado ou encerrado de alguma outra forma: interrompa a consulta imediatamente e relate o estado final.

## Condições de parada (estritas)
Pare somente quando uma das seguintes condições for verdadeira:

- PR mesclado ou encerrado (interrompa assim que uma votação/instantâneo confirmar isso).
- É necessária a intervenção do usuário, e o Codex não pode prosseguir com segurança sozinho.

Continue fazendo a sondagem quando:

- `actions` contém apenas `idle`, mas ainda há verificações pendentes.
- A CI ainda está em execução/na fila.
- A situação da revisão está tranquila, mas a CI não está em fase terminal.
- O CI está aprovado, mas a possibilidade de fusão é desconhecida/está pendente.
- O CI está com status “verde” e pronto para fusão, mas o PR ainda está aberto e você está aguardando possíveis novos comentários de revisão ou alterações decorrentes de conflitos de fusão.
- O PR está com status verde, mas bloqueado na aprovação da revisão (`REVIEW_REQUIRED` / semelhante); continue fazendo o polling na cadência padrão e exiba quaisquer novos comentários da revisão sem solicitar confirmação para continuar acompanhando.

## Expectativas de produção
Forneça atualizações concisas sobre o andamento durante o monitoramento e um resumo final que inclua:

- Durante longos períodos de monitoramento sem alterações, evite enviar uma atualização completa a cada consulta; resuma apenas as mudanças de status, além de atualizações ocasionais de heartbeat.
- Trate as confirmações de envio, os instantâneos intermediários de CI, os instantâneos prontos para fusão e as atualizações de ações de revisão apenas como atualizações de progresso; não emita o resumo final nem encerre a sessão de acompanhamento, a menos que uma condição de parada estrita seja atendida.
- Uma solicitação do usuário para “monitorar” não é atendida com apenas algumas consultas de amostra; mantenha-se informado até que ocorra uma condição de parada estrita ou uma interrupção explícita por parte do usuário.
- Um commit de revisão e correção + push não é um evento de conclusão; retome imediatamente o monitoramento em tempo real (`--watch`) no mesmo turno e continue relatando atualizações de progresso.
- Quando o CI passar pela primeira vez para “totalmente verde” no SHA atual, envie uma atualização de progresso comemorativa única (não a repita a cada votação com resultado verde). Estilo preferencial: `🚀 CI is all green! 33/33 passed. Still on watch for review approval.`
- Não envie o resumo final enquanto um terminal de monitoramento ainda estiver em execução, a menos que o monitor tenha emitido/confirmado uma condição de parada estrita; caso contrário, continue com as atualizações de progresso.

- Final PR SHA
- Resumo do status da CI
- Compatibilidade com a fusão / status de conflito
- Correções enviadas
- Foram utilizados ciclos de repetição instáveis
- Falhas ainda não resolvidas ou comentários da revisão

## Referências

- Heurística e árvore de decisão: `.codex/skills/babysit-pr/references/heuristics.md`
- Detalhes da CLI/API do GitHub utilizados pelo observador: `.codex/skills/babysit-pr/references/github-api-notes.md`
