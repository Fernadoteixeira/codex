---
name: path-types
description: Choose Rust types for operating system paths across the Codex repository. Use when defining new path-bearing types or explicitly migrating existing ones.
---

# Tipos de caminho

Aplique estas orientações ao definir novos tipos. Altere o código existente somente quando for explicitamente solicitado,
e mantenha as edições mínimas e proporcionais. Considere essas regras como o objetivo a ser alcançado em um processo contínuo
migração; caso haja dificuldade em cumprir as normas, pergunte ao usuário como proceder.

- Nos tipos de protocolo do servidor de aplicativos, use `LegacyAppPathString` para garantir a compatibilidade com versões anteriores durante a URI
  migração. No limite do protocolo, converta-o para `PathUri` e use `PathUri` internamente. Para
  A lógica local do host, como alguns valores de configuração, deve usar `AbsolutePathBuf` ou `PathBuf` em vez disso.
- Nos tipos de protocolo do servidor executivo, use `PathUri`. Internamente, use `PathUri` ou `AbsolutePathBuf` como
  adequado.
- Nas dependências compartilhadas por ambos os servidores, use `PathUri` ou APIs distintas que desacoplem seu uso
  casos.
- Os argumentos de chamada da ferramenta que o modelo deve gerar devem ser desserializados como
  `String`s com código de tratamento de caminho específico para cada recurso.

## Requisitos de migração

Tenha esses requisitos em mente ao migrar o código para que ele esteja em conformidade com as diretrizes acima:

* Os clientes existentes do servidor de aplicativos continuam enviando e recebendo strings de caminho nativo legadas
* O servidor de aplicativos pode armazenar e manipular URIs de caminho de plataformas externas
* As APIs do exec-server utilizam URIs do tipo file://
* uma operação exclusivamente local não deve alterar o texto visível no modelo
* Os argumentos da ferramenta “model” podem conter caminhos relativos ou absolutos sem formatação para qualquer sistema operacional
* o raciocínio de caminho deve funcionar antes que o ambiente relacionado esteja em funcionamento
* Os URIs não podem codificar explicitamente a convenção de caminho do executor nem o sistema operacional
* os usuários não devem configurar explicitamente o sistema operacional ou as convenções de caminho do ambiente
* Os URIs ainda não devem ser armazenados em rollouts, bancos de dados ou outros meios de armazenamento persistente
* erros de conversão de caminhos: “fail-closed” para caminhos relevantes para a segurança; “fail-open” para interface do usuário/diagnósticos
* prefiro métodos pequenos e específicos em `PathUri` ou `LegacyAppPathString` em vez de auxiliares locais
* representar valores `PathUri` como URIs em diagnósticos

Não há problema se a conversão entre caminhos e URIs apresentar alguma perda, desde que o resultado seja o correto
algo para usuários reais.

A migração para URIs não deve introduzir novos modos de falha significativos. Precisaremos exibir os erros em
alguns pontos que antes eram infalíveis, mas isso deve ser reduzido ao mínimo.
