# Notas sobre o GitHub CLI / API para `babysit-pr`

## Principais comandos utilizados

### Metadados de RP

- `gh pr view --json number,url,state,mergedAt,closedAt,headRefName,headRefOid,headRepository,headRepositoryOwner`

Utilizado para identificar o número do PR, a URL, o branch, o SHA do head e o status (fechado/mesclado).

### Resumo das verificações de relações públicas

- `gh pr checks --json name,state,bucket,link,workflow,event,startedAt,completedAt`

Utilizado para calcular as contagens de pendentes, reprovados e aprovados, bem como para determinar se a rodada atual de CI é a última.

### O fluxo de trabalho é executado para o SHA principal

- `gh api repos/{owner}/{repo}/actions/runs -X GET -f head_sha=<sha> -f per_page=100`

Utilizado para identificar execuções de fluxo de trabalho com falha e IDs de execução que podem ser repetidas.

### Falha na inspeção do registro

- `gh run view <run-id> --json jobs,name,workflowName,conclusion,status,url,headSha`
- `gh api repos/{owner}/{repo}/actions/runs/{run_id}/jobs -X GET -f per_page=100`
- `gh api repos/{owner}/{repo}/actions/jobs/{job_id}/logs > /tmp/codex-gh-job-{job_id}-logs.zip`
- `gh run view <run-id> --log-failed`

Utilizado pelo Codex para classificar falhas relacionadas ao branch e falhas esporádicas/não relacionadas. É recomendável usar o endpoint direto do log da tarefa assim que uma tarefa falhar, pois o `gh run view --log-failed` pode não gerar logs de tarefas com falha até que a execução geral do fluxo de trabalho seja concluída.

### Reexecutar apenas as tarefas com falha

- `gh run rerun <run-id> --failed`

Reexecuta apenas as tarefas (e dependências) que falharam em uma execução do fluxo de trabalho.

## Desfechos relacionados à revisão

- Envie comentários sobre o PR:
  - `gh api repos/{owner}/{repo}/issues/<pr_number>/comments?per_page=100`
- Comentários de revisão de RP no texto:
  - `gh api repos/{owner}/{repo}/pulls/<pr_number>/comments?per_page=100`
- Envio de resenhas:
  - `gh api repos/{owner}/{repo}/pulls/<pr_number>/reviews?per_page=100`

Use o `pull_request_review_id` de cada comentário embutido para localizar a avaliação à qual ele está vinculado. Ignore as avaliações principais
cujo `state` seja `PENDING`, juntamente com seus comentários embutidos, até que a revisão seja enviada.

## Campos JSON utilizados pelo observador

### `gh pr view`

- `number`
- `url`
- `state`
- `mergedAt`
- `closedAt`
- `headRefName`
- `headRefOid`

### `gh pr checks`

- `bucket` (`pass`, `fail`, `pending`, `skipping`)
- `state`
- `name`
- `workflow`
- `link`

### Ações executam a API (`workflow_runs[]`)

- `id`
- `name`
- `status`
- `conclusion`
- `html_url`
- `head_sha`

### Ações que executam a API de tarefas (`jobs[]`)

- `id`
- `name`
- `status`
- `conclusion`
- `html_url`
