## Sandbox & aprovações

Para obter informações sobre o isolamento em sandbox do Codex e aprovações, consulte [esta documentação](https://developers.openai.com/codex/security).

# Segurança do Codex

<CtaPillLink
  href="https://chatgpt.com/plugins/share/676aca3811d54fa7bcdef5255236b3c4"
  label="Instalar plugin no ChatGPT"
  icon="external"
  class="mb-8 mt-2"
/>

Para uma primeira varredura local prescritiva, comece com o [Guia de início rápido do plugin Codex Security](https://learn.chatgpt.com/docs/security/plugin).

### Explore casos de uso do plugin

- [Executar uma varredura de segurança](https://learn.chatgpt.com/docs/security/plugin/scans) em um repositório ou pasta delimitada.
- [Executar uma varredura profunda de segurança](https://learn.chatgpt.com/docs/security/plugin/deep-scans) quando precisar de uma análise mais abrangente e puder aguardar a conclusão.
- [Revisar alterações de código](https://learn.chatgpt.com/docs/security/plugin/code-changes) antes de fazer o merge de um pull request ou branch.
- [Triar um backlog](https://learn.chatgpt.com/docs/security/plugin/triage-backlog) quando houver descobertas de segurança existentes para revisar.
- [Corrigir e verificar descobertas](https://learn.chatgpt.com/docs/security/plugin/fix-findings) com correções delimitadas para descobertas aprovadas.
- [Exportar ou rastrear descobertas](https://learn.chatgpt.com/docs/security/plugin/export-findings) como artefatos portáteis ou destinos de rastreamento sujeitos a aprovação.
- [Escrever relatórios de vulnerabilidade](https://learn.chatgpt.com/docs/security/plugin/vulnerability-reports) a partir de descobertas fornecidas, notas de divulgação, código-fonte e PoCs.
- [Propor reforço de segurança](https://learn.chatgpt.com/docs/security/plugin/security-hardening) a partir dos resultados de varredura ou outras evidências de segurança.
- [Veja as novidades](https://learn.chatgpt.com/docs/security/plugin/changelog) no plugin Codex Security.

O plugin é executado no seu chat do Codex. As varreduras na nuvem do Codex Security analisam repositórios GitHub conectados através da nuvem do Codex. Para informações sobre isolamento em sandbox, aprovações, controles de rede e configurações administrativas do Codex, consulte [Aprovações de agente e segurança](https://learn.chatgpt.com/docs/agent-approvals-security).

## Nuvem do Codex Security

A nuvem do Codex Security está atualmente em visualização de pesquisa (research preview). Ela analisa repositórios GitHub conectados em busca de prováveis problemas de segurança.

Ela ajuda as equipes a:

1. **Encontrar vulnerabilidades prováveis** usando um modelo de ameaças específico do repositório e contexto de código real.
2. **Reduzir ruído** validando as descobertas antes que você as revise.
3. **Encaminhar descobertas para correções** com resultados classificados, evidências e opções de patch sugeridas.

## Como funciona a nuvem do Codex Security

O Codex Security analisa repositórios conectados commit por commit.
Ele constrói o contexto de varredura a partir do seu repositório, verifica vulnerabilidades prováveis em relação a esse contexto e valida problemas de alto sinal em um ambiente isolado antes de exibi-los.

Você obtém um fluxo de trabalho focado em:

- contexto específico do repositório em vez de assinaturas genéricas
- evidências de validação que ajudam a reduzir falsos positivos
- correções sugeridas que você pode revisar no GitHub

## Acesso e pré-requisitos da nuvem do Codex Security

A nuvem do Codex Security funciona com repositórios GitHub conectados através da nuvem do Codex. Se um repositório não estiver visível, confirme se ele está disponível no seu workspace da nuvem do Codex ou entre em contato com a equipe de conta da OpenAI.

## Documentos relacionados

- O [Guia de início rápido do plugin Codex Security](https://learn.chatgpt.com/docs/security/plugin) orienta sobre a instalação e a primeira varredura local.

# Guia de início rápido do plugin Codex Security

O Codex Security é um plugin de revisão de segurança para o Codex que analisa seu código em busca de vulnerabilidades, valida descobertas plausíveis e apresenta evidências e orientações de remediação em um workspace revisável. Use-o para encontrar problemas de segurança no código de sua propriedade ou que você tenha autorização para avaliar antes que cheguem à produção.

Este início rápido orienta você através de uma primeira execução recomendada: uma varredura comum e somente de leitura em um repositório local no Codex.

Esta página cobre o plugin executado em um chat local do Codex. Para analisar um repositório GitHub conectado na nuvem do Codex, consulte a [Configuração da nuvem do Codex Security](https://learn.chatgpt.com/docs/security/setup).

## Instalar o plugin

1. No terminal, vá até o repositório que deseja avaliar e inicie o Codex:

   ```bash
   codex
   ```

2. Digite `/plugins`, busque por **Codex Security** e selecione **Install plugin**.
3. Digite `/new` para iniciar um novo chat para o repositório.

## Executar sua primeira varredura

Para a melhor qualidade de varredura, use `gpt-5.6-sol` com esforço de raciocínio `xhigh`.

<WorkflowSteps variant="headings">

1. Solicitar uma varredura comum

   Envie este prompt no novo chat:

   ```text
   Run a Codex Security scan on this repository.
   ```

2. Aguardar a conclusão da varredura

   O Codex executa a varredura no terminal sem abrir um workspace de configuração. Mantenha a tarefa em execução até que o Codex informe a conclusão. Se o Codex identificar uma limitação de configuração, revise a limitação exata e a alteração proposta antes de permitir a atualização.

3. Revisar o resultado

   Revise o resumo no terminal e, em seguida, abra o arquivo `report.md` gerado para ver o resultado completo.

</WorkflowSteps>

## O que a varredura cria

Cada varredura concluída relata um resumo no terminal e cria os arquivos abaixo:

- `report.md`, o ponto de entrada principal e legível para os resultados da varredura.
- `findings/<slug>/`, com um relatório detalhado de vulnerabilidade por descoberta relatável e arquivos de prova de conceito (PoC) de suporte, quando disponíveis.
- `hardening/`, com um portfólio de reforço estrutural e propostas ou diagramas de suporte quando a varredura possui descobertas relatáveis.
- Dados estruturados da varredura em `scan-manifest.json`, `findings.json` e `coverage.json` para automação e integrações. Normalmente você não precisa abrir esses arquivos manualmente.

Mantenha o diretório completo de varredura reunido ao compartilhar ou arquivar resultados para que os links em `report.md` continuem funcionando.

## Escolha seu próximo fluxo de trabalho

- [Executar uma varredura padrão ou delimitada](https://learn.chatgpt.com/docs/security/plugin/scans) quando quiser analisar um repositório ou uma pasta com o fluxo padrão.
- [Executar uma varredura profunda](https://learn.chatgpt.com/docs/security/plugin/deep-scans) quando precisar de uma análise mais abrangente e puder esperar mais para terminar.
- [Revisar alterações de código](https://learn.chatgpt.com/docs/security/plugin/code-changes) quando o alvo for um pull request, commit, intervalo de branch ou patch do working tree.
- [Triar um backlog](https://learn.chatgpt.com/docs/security/plugin/triage-backlog) quando tiver descobertas de segurança existentes para revisar.
- [Corrigir e verificar uma descoberta](https://learn.chatgpt.com/docs/security/plugin/fix-findings) após aceitar uma descoberta para remediação.
- [Exportar ou rastrear descobertas](https://learn.chatgpt.com/docs/security/plugin/export-findings) quando precisar de JSON, CSV, SARIF, uma issue no Linear, GitHub ou Jira com aprovação, ou um rascunho privado de GitHub Security Advisory.
- [Escrever relatórios de vulnerabilidade](https://learn.chatgpt.com/docs/security/plugin/vulnerability-reports) quando quiser transformar descobertas fornecidas, notas de divulgação, código-fonte e PoCs em relatórios polidos e autônomos.
- [Propor reforço de segurança](https://learn.chatgpt.com/docs/security/plugin/security-hardening) quando quiser opções estruturais ou arquiteturais com base em resultados de varredura ou outras evidências.

- [Configuração da nuvem do Codex Security](https://learn.chatgpt.com/docs/security/setup) detalha configuração, varreduras e revisão de descobertas.
- [Melhorando o modelo de ameaças](https://learn.chatgpt.com/docs/security/threat-model) explica como ajustar escopo, superfície de ataque e premissas de criticidade.
- [FAQ da nuvem do Codex Security](https://learn.chatgpt.com/docs/security/faq) cobre perguntas frequentes sobre o produto em nuvem.
