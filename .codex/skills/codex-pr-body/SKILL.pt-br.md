---
name: codex-pr-body
description: Update the title and body of one or more pull requests.
---

## Determinação do(s) PR(s)

Quando essa habilidade é invocada, o(s) PR(s) a ser(em) atualizado(s) pode(m) ser especificado(s) explicitamente, mas, no caso mais comum, o(s) PR(s) a ser(em) atualizado(s) será(ão) inferido(s) a partir do branch/commit no qual o usuário está trabalhando no momento. Para o uso comum do Git (ou seja, não o Sapling, conforme discutido abaixo), talvez seja necessário usar uma combinação de `git branch` e `gh pr view <branch> --repo openai/codex --json number --jq '.number'` para determinar o PR associado ao branch/commit atual.

## Conteúdo do comunicado de imprensa

Ao ser chamado, use `gh` para editar o corpo e o título da solicitação de pull, de modo a refletir o conteúdo da solicitação especificada. Certifique-se de verificar o corpo da solicitação de pull existente para ver se há informações importantes que devam ser preservadas. Por exemplo, NUNCA remova uma imagem do corpo da solicitação de pull existente, pois o autor pode não ter como recuperá-la caso você a remova.

É extremamente importante explicar _por que_ a alteração está sendo feita. Se a conversa atual em que essa funcionalidade é mencionada já tiver abordado a motivação, certifique-se de incluir essa informação no corpo da solicitação de pull.

O corpo do texto também deve explicar _o que_ mudou, mas isso deve vir depois do _porquê_.

Limite a discussão à _mudança líquida_ do commit. Em geral, não é bem visto discutir mudanças que foram tentadas, mas posteriormente revertidas ao longo do desenvolvimento da solicitação de pull. Ao reescrever o corpo da solicitação de pull, talvez seja necessário eliminar detalhes como esses quando eles não forem mais apropriados ou de interesse para futuros leitores.

Evite referências a caminhos absolutos no meu disco local. Ao se referir a um caminho que esteja dentro do repositório, basta usar o caminho relativo ao repositório.

Evite referências a informações confidenciais, incluindo, entre outras, nomes de código ou URLs internos da OpenAI.

Geralmente, é útil discutir como a alteração foi verificada. Dito isso, não é necessário mencionar itens que a CI verifica automaticamente; por exemplo, não inclua “executou `just fmt`” como parte do plano de teste. No entanto, muitas vezes é apropriado identificar os novos testes que foram introduzidos propositalmente para verificar o novo comportamento trazido pela solicitação de pull.

Utilize o Markdown para formatar a solicitação de pull de maneira profissional. Certifique-se de que os “trechos de código” apareçam entre crases simples quando referenciados no corpo do texto. Blocos de código entre colchetes são úteis ao referenciar código ou exibir um histórico de comando. Além disso, utilize os links permanentes do GitHub ao citar trechos de código existentes que sejam relevantes para a alteração.

Certifique-se de fazer referência a quaisquer pull requests ou issues relevantes; no entanto, não deve ser necessário mencionar o pull request no próprio corpo do PR.

Caso haja documentação que deva ser atualizada no https://developers.openai.com/codex em decorrência dessa alteração, por favor, indique isso em uma seção separada, próxima ao final da solicitação de pull. Omita essa seção se não houver documentação que precise ser atualizada.

## Trabalhando com pilhas

Às vezes, uma solicitação de pull é composta por uma série de commits que se complementam. Nesses casos, o corpo da solicitação de pull deve refletir a mudança _líquida_ introduzida pela série como um todo, em vez dos commits individuais que a compõem.

Da mesma forma, às vezes um usuário pode estar utilizando uma ferramenta como o Sapling para aproveitar _pull requests empilhados_; nesse caso, o `base` do PR pode ser um branch que corresponde ao `head` de outro PR na pilha, em vez de `main`. Nesse caso, certifique-se de discutir apenas a alteração líquida entre o `base` e o `head` do PR que está sendo aberto com base nessa pilha, em vez das alterações relativas ao `main`.

## Mudinha

Se `.git/sl/store` estiver presente, então este repositório Git é gerenciado pelo Sapling SCM (https://sapling-scm.com).

No Sapling, execute o seguinte comando para verificar se há uma solicitação de pull no GitHub associada à revisão atual:

```shell
sl log --template '{github_pull_request_url}' -r .
```

Como alternativa, você pode executar `sl sl` para ver o branch de desenvolvimento atual e se há uma solicitação de pull no GitHub associada ao commit atual. Por exemplo, se a saída fosse:

```
  @  cb032b31cf  72 minutes ago  mbolin  #11412
╭─╯  tui: show non-file layer content in /debug-config
│
o  fdd0cd1de9  Today at 20:09  origin/main
│
~
```

- `@` indica que o commit atual é `cb032b31cf`
- trata-se de um ramo de desenvolvimento que contém um único commit, derivado do `origin/main`
- está associado à solicitação de pull do GitHub nº 11412
