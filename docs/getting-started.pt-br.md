# Introdução ao Codex CLI

Bem-vindo ao Codex CLI, um poderoso agente de codificação de linha de comando projetado para auxiliar em tarefas de engenharia de software diretamente no seu terminal e workspace.

## 1. Instalação Rápida

### Instalador Autônomo (Recomendado para Windows 11)

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

Inicie o Codex no seu terminal para iniciar o fluxo de autenticação:

```powershell
codex
```

1. Selecione **Sign in with ChatGPT** (ou configure uma chave de API).
2. Conclua a autorização na janela do navegador aberta.
3. Retorne ao terminal para iniciar sua sessão interativa.

## 3. Trabalhando no Workspace do seu Projeto

Navegue até a pasta do projeto alvo antes de iniciar o Codex:

```powershell
cd C:\caminho\para\seu\repositorio
codex
```

### Comandos Essenciais na Sessão

- `/init` — Cria um arquivo `AGENTS.md` com instruções e regras específicas do projeto.
- `/status` — Exibe configurações da sessão atual, seleção de modelo e limites de consumo de tokens.
- `/model` — Alterna entre modelos de IA suportados e níveis de esforço de raciocínio.
- `/permissions` — Inspeciona e gerencia permissões de execução de ferramentas.
- `/review` — Analisa alterações pendentes no Git e fornece feedback de revisão de código.

## 4. Modo Não Interativo (`codex exec`)

Execute tarefas autônomas de execução única ou scripts automatizados sem uma sessão interativa:

```powershell
codex exec "Execute os testes unitários e corrija quaisquer casos de teste com falhas"
```

## 5. Verificação e Verificações de Saúde

Confirme que os binários do Codex CLI estão definidos corretamente no seu `PATH`:

```powershell
where.exe codex
Get-Command codex -All | Select-Object CommandType, Name, Source, Version
```

Locais padrão de instalação:
- Executáveis: `%LOCALAPPDATA%\Programs\OpenAI\Codex\bin`
- Configuração global e cache: `%USERPROFILE%\.codex`
