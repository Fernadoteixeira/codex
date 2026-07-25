# CI / Heurísticas de revisão

## Lista de verificação para classificação de CI

Tratar como **relacionado ao branch** quando os logs indicarem claramente uma regressão causada pelo branch do PR:

- Falhas de compilação, verificação de tipos ou lint em arquivos ou módulos afetados pelo branch
- Falhas determinísticas em testes unitários/de integração em áreas alteradas
- Alterações na saída do Snapshot causadas por mudanças na interface do usuário e no texto no ramo
- Violações de análise estática introduzidas pela última atualização
- Alterações no script de compilação/configuração no PR que causam uma falha determinística

Considere como **provavelmente instável ou sem relação** quando as evidências apontarem para problemas transitórios ou externos:

- Erros de tempo limite de DNS/rede/registro durante a obtenção de dependências
- Falhas no provisionamento ou na inicialização do Runner
- Interrupções na infraestrutura/nos serviços do GitHub Actions
- Limites de taxa de uso da nuvem/serviços ou interrupções temporárias da API
- Falhas não determinísticas em testes de integração não relacionados, com padrões de instabilidade conhecidos

Não corrija falhas que possam ser esporádicas ou não relacionadas. Use o limite de tentativas para falhas que possam ser repetidas, aguarde os trabalhos pendentes ou interrompa e relate o bloqueio quando a falha for persistente ou estiver relacionada à infraestrutura.

Em caso de dúvida, verifique os logs com falha antes de optar por executar novamente.

## Árvore de decisão (corrigir x repetir x interromper)

1. Se o PR for mesclado/encerrado: pare.
2. Se houver verificações com falha:
   - Primeiro, faça o diagnóstico.
   - Se ainda houver verificações pendentes, mas uma tarefa específica já tiver falhado: obtenha os registros dessa tarefa e faça o diagnóstico agora.
   - Se estiver relacionado a um branch: corrija localmente, faça o commit e envie as alterações.
   - Se houver indícios de instabilidade ou falta de relação e todas as verificações do SHA atual forem finais: reexecute os trabalhos com falha.
   - Se parecer instável/não relacionado e não for possível reexecutá-lo com segurança: interrompa o processo e relate o bloqueador; não edite testes não relacionados, scripts de compilação, configuração de CI, fixações de dependências ou código de infraestrutura.
   - Se ainda houver verificações pendentes e ainda não houver nenhuma tarefa com falha disponível: aguarde.
3. Se as repetições intermitentes para o mesmo SHA atingirem o limite configurado (padrão: 3): interrompa e relate uma falha persistente.
4. De forma independente, processe quaisquer novos comentários da revisão manual.

## Critérios para aprovação de comentários em avaliações

Responda ao comentário quando:

- O comentário está tecnicamente correto.
- A alteração está pronta para ser implementada no branch atual.
- A alteração solicitada não entra em conflito com a intenção do usuário nem com as orientações recentes.
- A alteração pode ser feita com segurança, sem refatorações não relacionadas.

Corrija no código os comentários válidos de revisão humana sempre que possível, mas não publique uma resposta no GitHub a um comentário ou tópico escrito por uma pessoa, a menos que o usuário confirme explicitamente a resposta exata.

Não aplique a correção automática quando:

- O comentário é ambíguo e precisa de esclarecimentos.
- A solicitação entra em conflito com as instruções explícitas do usuário.
- A alteração proposta exige decisões relacionadas ao produto ou ao design que o usuário ainda não tomou.
- O código-fonte está em um estado desorganizado e sem coerência, o que torna incerta a possibilidade de uma edição segura.
- O comentário precisa apenas de uma resposta por escrito ou de uma manifestação de discordância; sugira a resposta ao usuário em vez de publicá-la automaticamente.

## Condições de “pare e pergunte”

Pare e pergunte ao usuário, em vez de continuar automaticamente, quando:

- A árvore de trabalho local contém alterações não relacionadas e não confirmadas.
- `gh` Falha na autenticação/permissões.
- O branch PR não pode ser enviado.
- As falhas de CI persistem após o limite de tentativas instável.
- O feedback do revisor exige uma decisão sobre o produto ou coordenação entre equipes.
- Um comentário de revisão humana exige uma resposta por escrito no GitHub, em vez de uma alteração no código.
