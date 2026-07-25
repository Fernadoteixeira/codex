# AGENTS.md

Para obter informações sobre o AGENTS.md, consulte [esta documentação](https://developers.openai.com/codex/guides/agents-md).

# Instruções personalizadas com o AGENTS.md

O Codex lê os arquivos `AGENTS.md` antes de realizar qualquer trabalho. Combinando orientações globais com sobreposições específicas de projetos, você pode iniciar cada tarefa com expectativas consistentes, independentemente do repositório aberto.

## Como o Codex descobre as orientações

O Codex constrói uma cadeia de instruções quando é iniciado (uma vez por execução; na TUI isso geralmente significa uma vez por sessão lançada). A descoberta segue esta ordem de precedência:

1. **Escopo global:** No seu diretório inicial do Codex (o padrão é `~/.codex`, a menos que você defina `CODEX_HOME`), o Codex lê o `AGENTS.override.md`, se existir. Caso contrário, lê o `AGENTS.md`. O Codex utiliza apenas o primeiro arquivo não vazio neste nível.
2. **Escopo do projeto:** Começando na raiz do projeto (geralmente a raiz do Git), o Codex navega até o seu diretório de trabalho atual. Se o Codex não encontrar uma raiz de projeto, ele verifica apenas o diretório atual. Em cada diretório ao longo do caminho, ele verifica a presença de `AGENTS.override.md`, depois `AGENTS.md` e, em seguida, quaisquer nomes de substituição em `project_doc_fallback_filenames`. O Codex inclui no máximo um arquivo por diretório.
3. **Ordem de mesclagem:** O Codex concatena os arquivos desde a raiz até o diretório atual, unindo-os com linhas em branco. Arquivos mais próximos do seu diretório atual sobrepõem orientações anteriores porque aparecem mais abaixo no prompt combinado.

O Codex ignora arquivos vazios e para de adicionar arquivos assim que o tamanho combinado atinge o limite definido por `project_doc_max_bytes` (32 KiB por padrão). Para obter detalhes sobre essas configurações, consulte [Descoberta de instruções de projeto](https://learn.chatgpt.com/docs/config-file/config-advanced#project-instructions-discovery). Aumente o limite ou divida as instruções em diretórios aninhados quando atingir o teto.

## Criar orientações globais

Crie padrões persistentes no seu diretório inicial do Codex para que todos os repositórios herdem seus acordos de trabalho.

1. Certifique-se de que o diretório existe:

   ```bash
   mkdir -p ~/.codex
   ```

2. Crie o `~/.codex/AGENTS.md` com preferências reutilizáveis:

   ```md
   # ~/.codex/AGENTS.md

   ## Acordos de trabalho

   - Sempre execute `npm test` após modificar arquivos JavaScript.
   - Dê preferência ao `pnpm` ao instalar dependências.
   - Peça confirmação antes de adicionar novas dependências de produção.
   ```

3. Execute o Codex em qualquer lugar para confirmar que ele carrega o arquivo:

   ```bash
   codex --ask-for-approval never "Resuma as instruções atuais."
   ```

   Esperado: O Codex cita os itens do `~/.codex/AGENTS.md` antes de propor qualquer trabalho.

Use `~/.codex/AGENTS.override.md` quando precisar de uma sobreposição global temporária sem excluir o arquivo base. Remova a sobreposição para restaurar a orientação compartilhada.

## Sobrepor instruções por projeto

Arquivos no nível do repositório mantêm o Codex ciente das normas do projeto, enquanto continuam herdando seus padrões globais.

1. Na raiz do seu repositório, adicione um `AGENTS.md` que cubra a configuração básica:

   ```md
   # AGENTS.md

   ## Expectativas do repositório

   - Execute `npm run lint` antes de abrir um pull request.
   - Documente utilitários públicos em `docs/` quando alterar comportamentos.
   ```

2. Adicione sobreposições em diretórios aninhados quando equipes específicas precisarem de regras diferentes. Por exemplo, dentro de `services/payments/`, crie `AGENTS.override.md`:

   ```md
   # services/payments/AGENTS.override.md

   ## Regras do serviço de pagamentos

   - Use `make test-payments` em vez de `npm test`.
   - Nunca rotacione chaves de API sem notificar o canal de segurança.
   ```

3. Inicie o Codex a partir do diretório de pagamentos:

   ```bash
   codex --cd services/payments --ask-for-approval never "Liste as fontes de instrução carregadas."
   ```

   Esperado: O Codex relata o arquivo global primeiro, o `AGENTS.md` da raiz do repositório em segundo lugar, e a sobreposição de pagamentos por último.

O Codex para a busca assim que chega ao seu diretório atual, portanto, posicione as sobreposições o mais próximo possível do trabalho especializado.

Aqui está um exemplo de repositório após adicionar um arquivo global e uma sobreposição específica de pagamentos:

<FileTree
class="mt-4"
tree={[
{
name: "AGENTS.md",
comment: "Expectativas do repositório",
highlight: true,
},
{
name: "services/",
open: true,
children: [
{
name: "payments/",
open: true,
children: [
{
name: "AGENTS.md",
comment: "Ignorado porque existe uma sobreposição",
},
{
name: "AGENTS.override.md",
comment: "Regras do serviço de pagamentos",
highlight: true,
},
{ name: "README.md" },
],
},
{
name: "search/",
children: [{ name: "AGENTS.md" }, { name: "…", placeholder: true }],
},
],
},
]}
/>

## Adicionar regras de revisão de código

Para a [Revisão de código do Codex no GitHub](https://learn.chatgpt.com/docs/third-party/github#customize-what-codex-reviews), adicione uma seção `## Code Review Rules` (Regras de Revisão de Código) no `AGENTS.md` mais próximo do código que as regras governam. Coloque verificações para todo o repositório na raiz e verificações específicas de serviços em um arquivo aninhado.

```md
## Code Review Rules

### Cohortes de experimentos

- Não filtre comparações de tratamento no comportamento pós-exposição, incluindo conversão ou retenção.
  Caminho seguro: construa cohortes a partir da atribuição ou exposição; relate a conversão como um resultado.
```

Mantenha as regras concisas, explique o comportamento a ser sinalizado e qualquer caminho seguro ou exceção, e reserve verificações de formatação e lint para a CI. Consulte [Personalizar o que o Codex revisa](https://learn.chatgpt.com/docs/third-party/github#customize-what-codex-reviews) para orientações de configuração e escrita de regras.

## Personalizar nomes de arquivos de fallback

Se o seu repositório já usa um nome de arquivo diferente (por exemplo, `TEAM_GUIDE.md`), adicione-o à lista de substituição para que o Codex o trate como um arquivo de instruções.

1. Edite sua configuração do Codex:

   ```toml
   # ~/.codex/config.toml
   project_doc_fallback_filenames = ["TEAM_GUIDE.md", ".agents.md"]
   project_doc_max_bytes = 65536
   ```

2. Reinicie o Codex ou execute um novo comando para que a configuração atualizada seja carregada.

Agora o Codex verifica cada diretório nesta ordem: `AGENTS.override.md`, `AGENTS.md`, `TEAM_GUIDE.md`, `.agents.md`. Nomes de arquivos fora desta lista são ignorados para a descoberta de instruções. O limite de bytes maior permite mais orientações combinadas antes do truncamento.

Com a lista de fallback configurada, o Codex trata os arquivos alternativos como instruções:

<FileTree
class="mt-4"
tree={[
{
name: "TEAM_GUIDE.md",
comment: "Detectado via lista de fallback",
highlight: true,
},
{
name: ".agents.md",
comment: "Arquivo de fallback na raiz",
},
{
name: "support/",
open: true,
children: [
{
name: "AGENTS.override.md",
comment: "Sobrepõe a orientação de fallback",
highlight: true,
},
{
name: "playbooks/",
children: [{ name: "…", placeholder: true }],
},
],
},
]}
/>

Defina a variável de ambiente `CODEX_HOME` quando quiser um perfil diferente, como um usuário de automação específico do projeto:

```bash
CODEX_HOME=$(pwd)/.codex codex exec "Listar fontes de instrução ativas"
```

Esperado: A saída lista os arquivos relativos ao diretório `.codex` personalizado.

## Verificar sua configuração

- Execute `codex --ask-for-approval never "Resuma as instruções atuais."` a partir da raiz do repositório. O Codex deve refletir as orientações dos arquivos globais e do projeto na ordem de precedência.
- Use `codex --cd subdir --ask-for-approval never "Mostre quais arquivos de instrução estão ativos."` para confirmar que sobreposições aninhadas substituem regras mais amplas.
- Para auditar quais arquivos de instrução o Codex carregou, ative um log de TUI em texto simples com `codex -c log_dir=./.codex-log` e verifique `./.codex-log/codex-tui.log`, ou inspecione o arquivo `session-*.jsonl` mais recente se tiver ativado o log de sessão.
- Se as instruções parecerem desatualizadas, reinicie o Codex no diretório de destino. O Codex reconstrói a cadeia de instruções em cada execução (e no início de cada sessão de TUI), portanto não há cache para limpar manualmente.

## Solucionar problemas de descoberta

- **Nada é carregado:** Verifique se você está no repositório pretendido e se `codex status` relata a raiz de workspace esperada. Certifique-se de que os arquivos de instrução possuem conteúdo; o Codex ignora arquivos vazios.
- **Orientação errada aparece:** Procure por um `AGENTS.override.md` mais acima na árvore de diretórios ou no diretório inicial do Codex. Renomeie ou remova a sobreposição para retornar ao arquivo regular.
- **O Codex ignora nomes de fallback:** Confirme se você listou os nomes em `project_doc_fallback_filenames` sem erros de digitação e reinicie o Codex para que a configuração atualizada surta efeito.
- **Instruções truncadas:** Aumente `project_doc_max_bytes` ou divida arquivos grandes em diretórios aninhados para manter as orientações críticas intactas.
- **Confusão de perfil:** Execute `echo $CODEX_HOME` antes de iniciar o Codex. Um valor diferente do padrão aponta o Codex para um diretório inicial diferente daquele que você editou.

## Próximos passos

- Visite o site oficial do [AGENTS.md](https://agents.md) para obter mais informações.
- Revise [Prompts no Codex](https://learn.chatgpt.com/docs/prompting) para padrões de conversa que se combinam bem com orientações persistentes.
