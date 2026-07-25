# Guia de Início Rápido do Codex CLI

Bem-vindo ao Codex CLI, um agente de codificação via linha de comando projetado para auxiliar em tarefas de engenharia de software diretamente no seu terminal e ambiente de trabalho.

## 1. Instalação Rápida

### Instalador Standalone (Recomendado para Windows 11)

Abra o PowerShell e execute:

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
```

Verifique a instalação:

```powershell
codex --version
```

### Alternativa via npm

Caso Node.js e npm já estejam configurados:

```powershell
npm install --global @openai/codex
```

## 2. Autenticação

Inicie o Codex no terminal para iniciar o fluxo de autenticação:

```powershell
codex
```

1. Selecione **Sign in with ChatGPT** (ou configure uma chave de API).
2. Conclua a autorização na janela do navegador que se abrirá.
3. Retorne ao terminal para iniciar a sessão interativa.

## 3. Trabalhando no seu Repositório

Navegue até a pasta do seu projeto antes de iniciar o Codex:

```powershell
cd C:\caminho\para\seu\repositorio
codex
```

### Comandos Principais da Sessão

- `/init` — Cria o arquivo `AGENTS.md` com instruções e regras específicas do projeto.
- `/status` — Exibe as configurações da sessão atual, modelo selecionado e limites de uso.
- `/model` — Altera entre os modelos suportados e níveis de esforço de raciocínio.
- `/permissions` — Inspeciona e gerencia as permissões de execução de ferramentas.
- `/review` — Analisa alterações pendentes no Git e fornece feedback de code review.

## 4. Modo Não Interativo (`codex exec`)

Execute tarefas autônomas de execução única ou scripts automatizados sem abrir a sessão interativa:

```powershell
codex exec "Executar testes unitários e corrigir falhas encontradas"
```

## 5. Verificação do Ambiente

Confirme se os binários do Codex CLI estão configurados corretamente no seu `PATH`:

```powershell
where.exe codex
Get-Command codex -All | Select-Object CommandType, Name, Source, Version
```

Locais padrão de instalação:

- Executáveis: `%LOCALAPPDATA%\Programs\OpenAI\Codex\bin`
- Configurações globais e cache: `%USERPROFILE%\.codex`
