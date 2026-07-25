## Contribuição

**Contribuições externas são apenas por convite**

No momento, a equipe do Codex não aceita contribuições de código não solicitadas.

Se você gostaria de propor um novo recurso ou uma alteração de comportamento, abra uma issue descrevendo a proposta ou vote em uma solicitação de melhoria existente. Priorizamos novos recursos com base no feedback da comunidade, alinhamento com nosso roadmap e consistência em todas as superfícies do Codex (CLI, extensões de IDE, web, etc.).

Se você encontrar um bug, abra um relatório de bug ou verifique se um relatório existente já cobre o problema. Se quiser ajudar, incentivamos você a contribuir compartilhando análises, detalhes de reprodução, hipóteses de causa raiz ou um esboço de alto nível de uma potencial correção diretamente na thread da issue.

A equipe do Codex pode convidar um contribuidor externo a enviar um pull request quando:

- o problema for bem compreendido,
- a abordagem proposta estiver alinhada com a solução pretendida pela equipe, e
- a issue for considerada de alto impacto e alta prioridade.

Pull requests que não tenham sido explicitamente convidados por um membro da equipe do Codex serão fechados sem revisão.

**Por que geralmente não aceitamos contribuições de código externas**

No passado, a equipe do Codex aceitava pull requests externos para correções de bugs. Embora tenhamos apreciado o esforço e o engajamento da comunidade, esse modelo não escalou bem.

Muitas contribuições foram feitas sem visibilidade total do contexto arquitetural, restrições no nível do sistema ou considerações de roadmap de curto prazo que guiam o desenvolvimento do Codex. Outras focavam em problemas de baixa prioridade ou que afetavam um subconjunto muito pequeno de usuários. Revisar e iterar sobre esses PRs frequentemente tomava mais tempo do que implementar a correção diretamente, além de desviar a atenção de trabalhos de maior prioridade.

As contribuições mais valiosas vieram consistentemente de membros da comunidade que demonstraram profundo entendimento do domínio do problema. Essa expertise é mais útil quando compartilhada cedo -- através de relatórios detalhados de bugs, análises e discussões de design em issues. Identificar a solução certa é normalmente a parte difícil; implementá-la é comparativamente simples com a ajuda do próprio Codex.

Por essas razões, focamos as contribuições externas em discussão, análise e feedback, e reservamos alterações de código para casos onde um convite direcionado faça sentido.

### Fluxo de trabalho de desenvolvimento

Se você for convidado por um membro da equipe do Codex a contribuir com um PR, aqui está o fluxo de trabalho recomendado:

- Crie uma _topic branch_ a partir de `main` - por exemplo: `feat/interactive-prompt`.
- Mantenha suas alterações focadas. Múltiplas correções não relacionadas devem ser abertas como PRs separados.
- Garanta que sua alteração esteja livre de avisos de linter e falhas de teste.

### Orientações para contribuições de código convidadas

1. **Comece com uma issue.** Abra uma nova ou comente em uma discussão existente para que possamos concordar com a solução antes que o código seja escrito.
2. **Adicione ou atualize testes.** Uma correção de bug deve geralmente vir com cobertura de teste que falhe antes de sua alteração e passe depois. Não é necessária 100% de cobertura, mas busque asserções significativas.
3. **Documente o comportamento.** Se sua alteração afetar o comportamento voltado ao usuário, atualize o README, a ajuda inline (`codex --help`) ou projetos de exemplo relevantes.
4. **Mantenha os commits atômicos.** Cada commit deve compilar e os testes devem passar. Isso facilita revisões e potenciais reversões (rollbacks).

### Atualizações de metadados de modelos

Quando uma alteração atualizar catálogos de modelos ou metadados de modelos (payloads de `/models`, presets ou fixtures):

- Defina `input_modalities` explicitamente para qualquer modelo que não suporte imagens.
- Tenha em mente os padrões de compatibilidade: a omissão de `input_modalities` atualmente implica suporte a texto + imagem.
- Garanta que as superfícies de cliente que aceitam imagens (por exemplo, colar/anexar na TUI) consumam o mesmo sinal de capacidade.
- Adicione/atualize testes que cubram comportamentos de imagens não suportadas e caminhos de aviso.

### Abrindo um pull request (apenas por convite)

- Preencha o template do PR (ou inclua informações semelhantes) - **O quê? Por quê? Como?**
- Inclua um link para um relatório de bug ou solicitação de melhoria no rastreador de issues.
- Execute **todas** as verificações localmente. Use os utilitários `just` na raiz para se manter consistente com o restante do workspace: `just fmt`, `just fix -p <crate>` para a crate que você modificou e os testes relevantes (por exemplo, `just test -p codex-tui` ou `just test` se precisar de uma varredura completa). Falhas de CI que poderiam ter sido capturadas localmente desaceleram o processo.
- Certifique-se de que sua branch esteja atualizada com a `main` e que você tenha resolvido conflitos de merge.
- Marque o PR como **Ready for review** apenas quando acreditar que ele está em um estado pronto para merge.

### Processo de revisão

1. Um mantenedor será atribuído como revisor principal.
2. Se o seu PR convidado introduzir escopo ou comportamento que não foi previamente discutido e aprovado, podemos fechar o PR.
3. Podemos solicitar alterações. Por favor, não leve isso para o lado pessoal. Valorizamos o trabalho, mas também valorizamos a consistência e a manutenibilidade a longo prazo.
4. Quando houver consenso de que o PR atinge o nível exigido, um mantenedor fará o squash-and-merge.

### Valores da comunidade

- **Seja gentil e inclusivo.** Trate os outros com respeito; seguimos o [Contributor Covenant](https://www.contributor-covenant.org/).
- **Presuma boa intenção.** Comunicação escrita é difícil - opte pela generosidade.
- **Ensine e aprenda.** Se notar algo confuso, abra uma issue ou discussão com sugestões ou esclarecimentos.

### Obtendo ajuda

Se você encontrar problemas ao configurar o projeto, quiser feedback sobre uma ideia ou apenas quiser dizer _olá_ - por favor, abra um tópico em Discussions ou entre na issue relevante. Estamos felizes em ajudar.

Juntos podemos fazer da Codex CLI uma ferramenta incrível. **Boas contribuições!** :rocket:

### Acordo de Licença de Contribuidor (CLA)

Todos os contribuidores **devem** aceitar o CLA. O processo é simples:

1. Abra seu pull request.
2. Cole o seguinte comentário (ou responda `recheck` se já tiver assinado antes):

   ```text
   I have read the CLA Document and I hereby sign the CLA
   ```

3. O bot CLA-Assistant registra sua assinatura no repositório e marca a verificação de status como aprovada.

Nenhum comando Git especial, anexos de e-mail ou rodapés de commit são necessários.

### Segurança e IA responsável

Descobriu uma vulnerabilidade ou tem preocupações sobre a saída do modelo? Envie um e-mail para **security@openai.com** e responderemos prontamente.
