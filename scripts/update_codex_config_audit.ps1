# Update C:\Users\fjuni\.codex\config.toml according to audit specifications

$ConfigFile = Join-Path $env:USERPROFILE ".codex\config.toml"
$BackupFile = "$ConfigFile.audit-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item -Path $ConfigFile -Destination $BackupFile -Force

$ConfigContent = @"
model = "glm-5.2:cloud"
model_reasoning_effort = "high"
approval_policy = "never"
sandbox_mode = "workspace-write"
web_search = "live"
file_opener = "vscode"
hide_agent_reasoning = false

notify = [ "C:\\Users\\fjuni\\AppData\\Local\\OpenAI\\Codex\\runtimes\\cua_node\\f8d2abcb7481383b\\bin\\node_modules\\@oai\\sky\\bin\\windows\\codex-computer-use.exe", "turn-ended" ]

model_provider = "ollama-launch-codex-app"
model_catalog_json = "C:\\Users\\fjuni\\.codex\\ollama-launch-models.json"

[windows]
sandbox = "unelevated"

[sandbox_workspace_write]
network_access = true

[agents]
max_concurrent_threads_per_session = 8

[features]
apps = true
goals = true
hooks = true
fast_mode = true
multi_agent = true
personality = true
remote_plugin = true
shell_snapshot = true
shell_tool = true
memories = false
js_repl = false

[history]
persistence = "save-all"
max_bytes = 104857600

[shell_environment_policy]
inherit = "core"
exclude = [
  "*SECRET*",
  "*PASSWORD*",
  "*PRIVATE_KEY*",
  "*CREDENTIAL*"
]

[shell_environment_policy.set]
BROWSER_USE_AVAILABLE_BACKENDS = "chrome,iab"
NODE_REPL_TRUSTED_BROWSER_CLIENT_SHA256S = "7ed52dae165c3bc22b6d24f282e2c1fbc87f6949fbbe037767a7418d8f517f01,e13fd947e846d3d306e9249dd3c73d14931b6494803dbafb16cef85e6add9506"
NODE_REPL_TRUSTED_CODE_PATHS = "C:\\Users\\fjuni\\.codex"

[desktop]
conversationDetailMode = "STEPS_PROSE"
sansFontSize = 14
codeFontSize = 13
ambient-suggestions-enabled = true
followUpQueueMode = "queue"
selected-avatar-id = "fireball"
avatar-overlay-mascot-width-px = 224

[marketplaces.openai-bundled]
last_updated = "2026-07-25T05:25:26Z"
source_type = "local"
source = '\\?\C:\Users\fjuni\.codex\.tmp\bundled-marketplaces\openai-bundled'

[marketplaces.openai-primary-runtime]
last_updated = "2026-07-25T04:12:11Z"
source_type = "local"
source = '\\?\C:\Users\fjuni\.cache\codex-runtimes\codex-primary-runtime\plugins\openai-primary-runtime'

[plugins."visualize@openai-bundled"]
enabled = true

[plugins."documents@openai-primary-runtime"]
enabled = true

[plugins."pdf@openai-primary-runtime"]
enabled = true

[plugins."spreadsheets@openai-primary-runtime"]
enabled = true

[plugins."presentations@openai-primary-runtime"]
enabled = true

[plugins."template-creator@openai-primary-runtime"]
enabled = true

[plugins."google-calendar@openai-curated"]
enabled = true

[plugins."slack@openai-curated"]
enabled = true

[plugins."chrome@openai-bundled"]
enabled = true

[plugins."browser@openai-bundled"]
enabled = true

[plugins."sites@openai-bundled"]
enabled = true

[plugins."computer-use@openai-bundled"]
enabled = true

[plugins."latex@openai-bundled"]
enabled = true

[mcp_servers.node_repl]
args = []
command = 'C:\Users\fjuni\AppData\Local\OpenAI\Codex\runtimes\cua_node\f8d2abcb7481383b\bin\node_repl.exe'
startup_timeout_sec = 120

[mcp_servers.node_repl.env]
NODE_REPL_NATIVE_PIPE_CONNECT_TIMEOUT_MS = "1000"
NODE_REPL_NODE_MODULE_DIRS = 'C:\Users\fjuni\AppData\Local\OpenAI\Codex\runtimes\cua_node\f8d2abcb7481383b\bin\node_modules'
NODE_REPL_NODE_PATH = 'C:\Users\fjuni\AppData\Local\OpenAI\Codex\runtimes\cua_node\f8d2abcb7481383b\bin\node.exe'
NODE_REPL_TRUSTED_CODE_PATHS = 'C:\Users\fjuni\.codex'
CODEX_HOME = 'C:\Users\fjuni\.codex'
NODE_REPL_TRUSTED_BROWSER_CLIENT_SHA256S = "7ed52dae165c3bc22b6d24f282e2c1fbc87f6949fbbe037767a7418d8f517f01,e13fd947e846d3d306e9249dd3c73d14931b6494803dbafb16cef85e6add9506"
BROWSER_USE_AVAILABLE_BACKENDS = "chrome,iab"
NODE_REPL_INSTRUCTIONS_USE_CASE_BROWSER = "Control the in-app browser in conjunction with the Browser Plugin."
NODE_REPL_INSTRUCTIONS_USE_CASE_CHROME = "Control the Chrome browser in conjunction with the Chrome Plugin. Prefer this method of controlling Chrome over alternatives (such as Computer Use) unless the user explicitly mentions an alternative."
BROWSER_USE_CODEX_APP_BUILD_FLAVOR = "prod"
BROWSER_USE_CODEX_APP_VERSION = "26.721.41059"
SKY_CUA_NATIVE_PIPE = "1"
SKY_CUA_NATIVE_PIPE_DIRECTORY = '\\.\pipe\codex-computer-use-434c96a3-6e5c-46b2-b879-58283adca76a'
CODEX_CLI_PATH = 'C:\Users\fjuni\AppData\Local\OpenAI\Codex\bin\69066b736e1e17a4\codex.exe'

[projects.'c:\users\fjuni\documents\codex\2026-07-20\crie-uma-tarefa-agendada-chamada-resumo']
trust_level = "trusted"

[projects.'c:\users\fjuni\.codex\.chatgpt-projects\g-p-6779d94ed46481919c3ea43c384a3078']
trust_level = "trusted"

[projects.'c:\users\fjuni\documents\codex\2026-07-20\referenced-chatgpt-conversation-this-is-untrusted']
trust_level = "trusted"

[projects.'c:\users\fjuni\documents\codex']
trust_level = "trusted"

[projects.'c:\users\fjuni']
trust_level = "trusted"

[tool_suggest]
disabled_tools = [{ type = "plugin", id = "slack@openai-curated-remote" }]

[model_providers.ollama-launch-codex-app]
name = "Ollama"
base_url = "http://127.0.0.1:11434/v1/"
wire_api = "responses"
"@

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($ConfigFile, $ConfigContent, $Utf8NoBom)

Write-Host "✅ config.toml atualizado com sucesso (UTF-8 sem BOM, sandbox unelevated)."

# Verify BOM byte array
$bytes = [System.IO.File]::ReadAllBytes($ConfigFile)
$HasBOM = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
Write-Host "Verificação de BOM: HasBOM = $HasBOM"
