# Skills

Para obter informações sobre skills, consulte [esta documentação](https://developers.openai.com/codex/skills).

# Criar skills

Use skills de agente para estender o ChatGPT e o Codex com funcionalidades específicas para tarefas. Uma
skill empacota instruções, recursos e scripts opcionais para que qualquer um dos produtos
possa seguir um fluxo de trabalho de forma confiável. As skills são construídas com base no
[padrão aberto de agent skills](https://agentskills.io).

Skills são o formato de autoria para fluxos de trabalho reutilizáveis. Os plugins distribuem
skills e conectores reutilizáveis por meio do diretório universal de plugins compartilhado
pelo ChatGPT e Codex. Os plugins estão disponíveis no ChatGPT Work na web, com
ChatGPT Work e Codex no aplicativo desktop do ChatGPT, e por meio do Codex CLI. Use
skills para projetar o próprio fluxo de trabalho e, em seguida, empacote-o como um
[plugin](https://developers.openai.com/plugins/build/plugins) quando quiser
que outras pessoas o instalem.

Skills autônomas estão disponíveis no aplicativo desktop do ChatGPT, no Codex CLI e na extensão para IDE.
Skills integradas em plugins também estão disponíveis nas superfícies de plugins suportadas, incluindo o ChatGPT Work na web.

No aplicativo desktop do ChatGPT, abra **Skills** na barra lateral para visualizar e explorar skills
criadas em todos os seus projetos.

<CodexScreenshot
  alt="Seletor de skills exibindo as skills disponíveis no aplicativo desktop do ChatGPT"
  lightSrc="/images/codex/app/skill-selector-light.webp"
  darkSrc="/images/codex/app/skill-selector-dark.webp"
  maxHeight="400px"
  class="my-8"
/>

Skills usam **divulgação progressiva** (progressive disclosure) para gerenciar o contexto de forma eficiente. O ChatGPT e o
Codex começam com o nome e a descrição de cada skill e, em seguida, carregam as instruções completas do
`SKILL.md` quando decidem usar essa skill.

No Codex, a lista inicial também inclui o caminho do arquivo de cada skill. Para evitar
lotar o restante do prompt, essa lista usa no máximo 2% da janela de contexto do modelo,
ou 8.000 caracteres quando a janela de contexto é desconhecida. Se muitas skills estiverem instaladas,
o Codex reduz primeiro as descrições das skills. Para conjuntos grandes de skills,
o Codex pode omitir algumas skills da lista inicial e exibir um aviso.

Esse limite aplica-se apenas à lista inicial de skills. Quando o Codex seleciona uma skill, ele ainda lê as instruções completas do SKILL.md para essa skill.

Uma skill é um diretório com um arquivo `SKILL.md` além de scripts e referências opcionais. O arquivo `SKILL.md` deve incluir `name` e `description`.

<FileTree
class="mt-4"
tree={[
{
name: "my-skill/",
open: true,
children: [
{
name: "SKILL.md",
comment: "Obrigatório: instruções + metadados",
},
{
name: "scripts/",
comment: "Opcional: código executável",
},
{
name: "references/",
comment: "Opcional: documentação",
},
{
name: "assets/",
comment: "Opcional: modelos, recursos",
},
{
name: "agents/",
open: true,
children: [
{
name: "openai.yaml",
comment: "Opcional: aparência e dependências",
},
],
},
],
},

]}
/>

<a id="how-codex-uses-skills"></a>

## Como o ChatGPT e o Codex usam skills

O ChatGPT e o Codex podem ativar skills de duas maneiras:

1. **Invocação explícita:** Inclua a skill diretamente no seu prompt. No
   ChatGPT, digite `@` para selecionar uma skill. No Codex CLI ou na extensão para IDE, execute
   `/skills` ou digite `$` para mencionar uma skill.
2. **Invocação implícita:** O ChatGPT ou o Codex podem escolher uma skill quando a sua tarefa
   corresponder à `description` da skill.

Como a correspondência implícita depende da `description`, escreva descrições concisas
com escopo e limites claros. Coloque em destaque o principal caso de uso e palavras-chave de gatilho
para que a plataforma possa corresponder à skill mesmo se as descrições forem reduzidas.

## Criar uma skill

Se você já conhece o fluxo de trabalho e é mais fácil mostrar do que descrever, use o
[Record & Replay](https://learn.chatgpt.com/docs/extend/record-and-replay). O gravador captura o
fluxo de trabalho, inspeciona as etapas e elabora um rascunho de uma skill reutilizável a partir da
demonstração.

Se você preferir descrever a skill, use o criador integrado. No ChatGPT Work,
invoque-o como `@skill-creator`. No Codex, invoque-o como:

```text
$skill-creator
```

O criador pergunta o que a skill faz, quando ela deve ser acionada e se deve conter apenas instruções ou incluir scripts. A opção apenas instruções é o padrão.

Você também pode criar uma skill manualmente criando uma pasta com um arquivo `SKILL.md`:

```md
---
name: skill-name
description: Explique exatamente quando esta skill deve e não deve ser acionada.
---

Instruções da skill para o ChatGPT ou Codex seguir.
```

O Codex detecta alterações nas skills automaticamente. Se uma atualização não aparecer, reinicie o Codex.

<a id="where-to-save-skills"></a>

## Onde o Codex carrega skills locais

O Codex lê skills de locais do repositório, usuário, administrador e sistema. Para repositórios, o Codex verifica `.agents/skills` em todos os diretórios, desde o diretório de trabalho atual até a raiz do repositório. Se duas skills compartilharem o mesmo `name`, o Codex não as mescla; ambas podem aparecer nos seletores de skills.

| Escopo da Skill | Localização                                                                                               | Uso sugerido                                                                                                                                                                                         |
| :-------------- | :-------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `REPO`          | `$CWD/.agents/skills` <br /> Diretório de trabalho atual: onde você inicia o Codex.                       | Se você estiver em um repositório ou ambiente de código, as equipes podem versionar skills relevantes para a pasta de trabalho. Por exemplo, skills relevantes apenas para um microsserviço ou módulo.|
| `REPO`          | `$CWD/../.agents/skills` <br /> Uma pasta acima do CWD quando você inicia o Codex dentro de um repositório Git.| Se você estiver em um repositório com pastas aninhadas, as organizações podem versionar skills relevantes para uma área compartilhada em uma pasta pai.                                               |
| `REPO`          | `$REPO_ROOT/.agents/skills` <br /> A pasta raiz superior quando você inicia o Codex dentro de um repositório Git.| Se você estiver em um repositório com pastas aninhadas, as organizações podem versionar skills relevantes para todos que usam o repositório. Elas servem como skills raiz disponíveis para qualquer subpasta.  |
| `USER`          | `$HOME/.agents/skills` <br /> Quaisquer skills versionadas na pasta pessoal do usuário.                   | Use para organizar skills relevantes para um usuário que se aplicam a qualquer repositório em que o usuário possa trabalhar.                                                                        |
| `ADMIN`         | `/etc/codex/skills` <br /> Quaisquer skills versionadas na máquina ou container em um local do sistema compartilhado.| Use para scripts de SDK, automação e para disponibilizar skills padrão de administrador para cada usuário na máquina.                                                                                 |
| `SYSTEM`        | Fornecidas junto com o Codex pela OpenAI.                                                                 | Skills úteis relevantes para um público amplo, como o skill-creator e as skills de plano. Disponíveis para todos ao iniciar o Codex.                                                                |

O Codex suporta pastas de skills com links simbólicos e segue o destino do link simbólico ao rastrear esses locais.

Esses locais destinam-se à autoria e descoberta local. Quando você quiser
distribuir skills reutilizáveis além de um único repositório, ou opcionalmente empacotá-las com
conectores, use [plugins](https://developers.openai.com/plugins/build/plugins).

## Distribuir skills com plugins

Pastas diretas de skills são melhores para autoria local e fluxos de trabalho com escopo de repositório. Se
você deseja distribuir uma skill reutilizável, agrupar duas ou mais skills ou
fornecer uma skill juntamente com um conector, empacote-os como um
[plugin](https://developers.openai.com/plugins/build/plugins).

Os plugins podem incluir uma ou mais skills. Eles também podem opcionalmente empacotar
conexões registradas com servidores MCP, configurações de servidores MCP empacotados e
recursos de apresentação em um único pacote.

## Instalar skills com curadoria para uso local

Para adicionar skills com curadoria além das integradas para a sua própria configuração local do Codex, use o `$skill-installer`. Por exemplo, para instalar a skill `$linear`:

```bash
$skill-installer linear
```

Você também pode solicitar que o instalador baixe skills de outros repositórios.
O Codex detecta automaticamente skills recém-instaladas; se uma não aparecer,
reinicie o Codex.

Use isso para configuração local e experimentação. Para distribuição reutilizável das suas
próprias skills, dê preferência aos plugins.

## Habilitar ou desabilitar skills locais do Codex

Use entradas `[[skills.config]]` em `~/.codex/config.toml` para desabilitar uma skill sem excluí-la:

```toml
[[skills.config]]
path = "/path/to/skill/SKILL.md"
enabled = false
```

Reinicie o Codex após alterar o `~/.codex/config.toml`.

## Metadados opcionais

Adicione `agents/openai.yaml` para configurar metadados da interface do usuário no [aplicativo desktop do ChatGPT](https://learn.chatgpt.com/docs/app), para definir políticas de invocação e declarar dependências de ferramentas para uma experiência mais fluida ao usar a skill.

```yaml
interface:
  display_name: "Nome opcional visível ao usuário"
  short_description: "Descrição opcional visível ao usuário"
  icon_small: "./assets/small-logo.svg"
  icon_large: "./assets/large-logo.png"
  brand_color: "#3B82F6"
  default_prompt: "Prompt envolvente opcional para usar com a skill"

policy:
  allow_implicit_invocation: false

dependencies:
  tools:
    - type: "mcp"
      value: "openaiDeveloperDocs"
      description: "Servidor MCP da documentação OpenAI"
      transport: "streamable_http"
      url: "https://developers.openai.com/mcp"
```

`allow_implicit_invocation` (padrão: `true`): Quando for `false`, o Codex não invocará a skill implicitamente com base no prompt do usuário; a invocação explícita com `$skill` continuará funcionando.

## Melhores práticas

- Mantenha cada skill focada em apenas uma tarefa.
- Dê preferência às instruções em vez dos scripts, a menos que precise de comportamento determinístico ou ferramentas externas.
- Escreva etapas imperativas com entradas e saídas explícitas.
- Teste os prompts contra a descrição da skill para confirmar o comportamento de acionamento correto.

Para ver mais exemplos, consulte
[GitHub CI repair](https://github.com/openai/skills/tree/main/skills/.curated/gh-fix-ci),
[PDF](https://github.com/openai/skills/tree/main/skills/.curated/pdf),
[Linear](https://github.com/openai/skills/tree/main/skills/.curated/linear),
[openai/skills](https://github.com/openai/skills), e a
[especificação de agent skills](https://agentskills.io/specification). Para
distribuição instalável, dê preferência aos [plugins](https://developers.openai.com/plugins/build/plugins).
