# Getting Started with Codex CLI

Welcome to Codex CLI, a powerful command-line coding agent designed to assist with software engineering tasks directly in your terminal and workspace.

## 1. Quick Installation

### Standalone Installer (Recommended for Windows 11)

Open PowerShell and execute:

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
```

Verify your installation:

```powershell
codex --version
```

### Alternative via npm

If Node.js and npm are already configured:

```powershell
npm install --global @openai/codex
```

## 2. Authentication

Launch Codex in your terminal to start the authentication flow:

```powershell
codex
```

1. Select **Sign in with ChatGPT** (or configure an API key).
2. Complete authorization in the opened browser window.
3. Return to the terminal to begin your interactive session.

## 3. Working in Your Project Workspace

Navigate to your target project folder before launching Codex:

```powershell
cd C:\path\to\your\repository
codex
```

### Essential In-Session Commands

- `/init` — Scaffolds an `AGENTS.md` file with project-specific instructions and rules.
- `/status` — Displays current session configurations, model selection, and token usage limits.
- `/model` — Switches between supported AI models and reasoning effort levels.
- `/permissions` — Inspects and manages tool execution permissions.
- `/review` — Analyzes pending git changes and provides code review feedback.

## 4. Non-Interactive Mode (`codex exec`)

Run autonomous single-shot tasks or automated scripts without an interactive session:

```powershell
codex exec "Run unit tests and fix any failing test cases"
```

## 5. Verification & Health Checks

Confirm that Codex CLI binaries are correctly set in your `PATH`:

```powershell
where.exe codex
Get-Command codex -All | Select-Object CommandType, Name, Source, Version
```

Default installation locations:
- Executables: `%LOCALAPPDATA%\Programs\OpenAI\Codex\bin`
- Global config & cache: `%USERPROFILE%\.codex`

