---
name: pushing-ci-changes
description: Pushing GitHub Actions changes, resolving push rejection, requesting upload exceptions.
---

O repositório do Codex impede que qualquer pessoa envie alterações à sua configuração de CI, a menos que tenha
recebeu uma função temporária.

Para enviar alterações para o arquivo `.github/**/*.yml` e arquivos relacionados, você precisará que o usuário tenha permissão de leitura
Acesse go/workflow-approvals e solicite uma aprovação por meio desse fluxo. Não é possível para você
avançar solicitando você mesmo uma isenção.

Se você sabe que está prestes a enviar alterações que seriam rejeitadas devido a essas restrições, mesmo assim deve
tente enviar mesmo assim para confirmar se a conta do usuário ainda não possui a aprovação necessária.

Se você tiver uma falha no envio devido a essas restrições, compartilhe o link go/workflow-approvals com
entre em contato com o usuário e peça que ele devolva o controle a você assim que a aprovação for propagada para o GitHub.
