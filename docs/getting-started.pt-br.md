# Introdução ao Codex CLI

Bem-vindo ao Codex CLI, um poderoso agente de programação de linha de comando projetado para auxiliar nas tarefas de engenharia de software diretamente no seu terminal e na sua área de trabalho.

## 1. Instalação rápida

### Instalador independente (recomendado para o Windows 11)

Abra o PowerShell e execute:

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
```

Verifique sua instalação:

```powershell
codex --version
```

### Alternativa via npm

Se o Node.js e o npm já estiverem configurados:

```powershell
npm install --global @openai/codex
```

## 2. Autenticação

Execute o Codex no seu terminal para iniciar o fluxo de autenticação:

```powershell
codex
```

1. Selecione **Entrar com o ChatGPT** (ou configure uma chave de API).
2. Conclua a autorização na janela do navegador aberta.
3. Volte ao terminal para iniciar sua sessão interativa.

## 3. Trabalhando na área de trabalho do seu projeto

Navegue até a pasta do projeto de destino antes de iniciar o Codex:

```powershell
cd C:\path\to\your\repository
codex
```

### Comandos essenciais durante a sessão

- `/init` — Gera um arquivo `AGENTS.md` com instruções e regras específicas do projeto.
- `/status` — Exibe as configurações da sessão atual, a seleção do modelo e os limites de uso de tokens.
- `/model` — Alterna entre os modelos de IA compatíveis e os níveis de esforço de raciocínio.
- `/permissions` — Inspeciona e gerencia as permissões de execução das ferramentas.
- `/review` — Analisa as alterações pendentes no Git e fornece comentários sobre a revisão do código.

## 4. Modo não interativo (`codex exec`)

Execute tarefas autônomas de execução única ou scripts automatizados sem uma sessão interativa:

```powershell
codex exec "Run unit tests and fix any failing test cases"
```

## 5. Verificação e análises de integridade

Verifique se os binários da CLI do Codex estão configurados corretamente no seu `PATH`:

```powershell
where.exe codex
Get-Command codex -All | Select-Object CommandType, Name, Source, Version
```

Locais padrão de instalação:
- Arquivos executáveis: `%LOCALAPPDATA%\Programs\OpenAI\Codex\bin`
- Configuração geral e cache: `%USERPROFILE%\.codex`

