# Comandos Slash

Para uma visão geral dos comandos slash do Codex CLI, consulte a [documentação oficial](https://developers.openai.com/codex/cli/slash-commands).

## Comandos Principais do Codex CLI

| Comando | Descrição |
|---|---|
| `/init` | Inicializa as configurações da sessão e cria o arquivo `AGENTS.md` |
| `/status` | Exibe o status da sessão atual, modelo ativo e limites |
| `/model` | Seleciona o modelo de linguagem e o nível de esforço de raciocínio |
| `/permissions` | Gerencia e exibe as permissões ativas da ferramenta |
| `/review` | Revisa alterações de código feitas na sessão |

## Comandos Personalizados e Skills

| Comando | Descrição |
|---|---|
| `/doc-translator-deeplx` | Executa o pipeline de tradução automática de documentação (`.md`, `.txt`, `.yaml`) para PT-BR utilizando o container DeepLX (`dlx-translator`) com preservação de estrutura, rate limit adaptativo e resiliência por container recycling |

## Histórico de Execuções Recentes

1. **Instalação e Validação do Ambiente Bazel/Buildifier**:
   - Instalado **Buildifier v8.5.1** em `C:\Users\fjuni\go\bin\buildifier.exe`.
   - Instalado **Bazel v9.0.0 / Bazelisk** em `C:\Users\fjuni\go\bin\bazel.exe`.
   - Validação executada com sucesso (`bazel query //...`).

2. **Mapeamento de Documentação (`.md`)**:
   - Levantamento efetuado: **173 arquivos `.md`** localizados no repositório `c:\Users\fjuni\codex`.
   - Na pasta `Downloads`: **11 arquivos** na raiz e **1.579** considerando subdiretórios.

3. **Execução de Tradução Automática (DeepLX)**:
   - Container Docker `dlx-translator` ativo na porta `1188`.
   - Escaneamento concluído via `translate_docs.py scan`.
   - Batch de tradução iniciado em background (`task-36`) para os **173 arquivos `.md`** com as flags `--skip-existing`, `--resume` e `--recycle-container`.
