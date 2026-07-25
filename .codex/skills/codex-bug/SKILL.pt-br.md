---
name: codex-bug
description: Diagnose GitHub bug reports in openai/codex. Use when given a GitHub issue URL from openai/codex and asked to decide next steps such as verifying against the repo, requesting more info, or explaining why it is not a bug; follow any additional user-provided instructions.
---

# Erro no Codex

## Visão geral

Analise um relatório de bug do Codex no GitHub e decida qual será a próxima ação: verificar com base nos códigos-fonte, solicitar mais informações ou explicar por que não se trata de um bug.

## Fluxo de trabalho

1. Confirme a entrada

- É necessário um URL de issue do GitHub que aponte para `github.com/openai/codex/issues/…`.
- Se a URL estiver faltando ou não estiver no repositório correto, peça ao usuário o link correto.

2. Acesso à rede

- Sempre acesse o problema pela rede imediatamente, mesmo que você ache que o acesso esteja bloqueado ou indisponível.
- Prefira a API do GitHub em vez das páginas HTML, pois o HTML contém muitos elementos desnecessários:
  - Edição: `https://api.github.com/repos/openai/codex/issues/<number>`
  - Comentários: `https://api.github.com/repos/openai/codex/issues/<number>/comments`
- Se o ambiente exigir aprovação explícita, solicite-a quando necessário por meio da ferramenta e continue sem que seja necessário solicitar confirmação adicional ao usuário.
- Somente se a tentativa de conexão com a rede falhar após a solicitação de aprovação, explique o que você pode fazer offline (por exemplo, elaborar um modelo de resposta) e pergunte como proceder.

3. Leia a edição

- Use as respostas da API do GitHub (issues + comentários) como fonte confiável, em vez de extrair o conteúdo da página HTML do issue.
- Extrato: título, corpo do texto, etapas de reprodução, resultados esperados versus resultados reais, ambiente, registros e quaisquer anexos.
- Verifique se o relatório já inclui registros ou detalhes da sessão.
- Se o relatório incluir um ID de tópico, mencione-o no resumo e use-o para consultar os registros e os detalhes da sessão, caso tenha acesso a eles.

4. Resuma o bug antes de investigá-lo

- Antes de analisar o código, a documentação ou os registros de forma detalhada, escreva um breve resumo do relatório com suas próprias palavras.
- Inclua o comportamento relatado, o comportamento esperado, as etapas para reproduzir o problema, o ambiente e quais evidências já estão anexadas ou faltam.

5. Decida o que fazer

- **Verifique com as fontes** quando o relato for específico e provavelmente reproduzível. Analise os arquivos relevantes do Codex (ou indique quais arquivos devem ser analisados caso o acesso não esteja disponível).
- **Solicite mais informações** quando o relatório for vago, não incluir etapas para reproduzir o problema ou não conter logs/detalhes do ambiente.
- **Explique que não se trata de um bug** quando o relato contradizer o comportamento atual ou as restrições documentadas (cite as evidências do ticket e quaisquer fontes locais que você tenha verificado).

6. Responder

- Apresente um relatório conciso com suas conclusões e os próximos passos.
