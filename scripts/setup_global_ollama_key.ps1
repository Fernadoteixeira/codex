# Export Ollama API Key globally and register Ollama + Codex binaries to PATH

$OllamaKey = "3d859c811a424c77818b13275d7f0c6e.g8-Pbhq4GuQ7CONW_ykE5dDA"

# 1. Set environment variables globally (User level)
[Environment]::SetEnvironmentVariable("OLLAMA_API_KEY", $OllamaKey, "User")
[Environment]::SetEnvironmentVariable("OLLAMA_KEY", $OllamaKey, "User")

Write-Host "✅ OLLAMA_API_KEY exportada permanentemente no perfil do Usuário."

# 2. Add Ollama & Codex directories to User PATH
$OllamaDir = "C:\Users\fjuni\AppData\Local\Programs\Ollama"
$CodexDir = "C:\Users\fjuni\AppData\Local\OpenAI\Codex\bin\69066b736e1e17a4"
$GoDir = "C:\Users\fjuni\go\bin"

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$PathsToAdd = @($OllamaDir, $CodexDir, $GoDir)

foreach ($dir in $PathsToAdd) {
    if (Test-Path $dir) {
        if ($UserPath -notlike "*$dir*") {
            $UserPath = "$dir;$UserPath"
            Write-Host "✅ Adicionado ao PATH do Usuário: $dir"
        } else {
            Write-Host "ℹ️ Já está no PATH: $dir"
        }
    }
}

[Environment]::SetEnvironmentVariable("Path", $UserPath, "User")

# 3. Update current process environment
$env:OLLAMA_API_KEY = $OllamaKey
$env:OLLAMA_KEY = $OllamaKey
$env:Path = "$OllamaDir;$CodexDir;$GoDir;$env:Path"

Write-Host "`nTestando executáveis na sessão atual:"
& "$OllamaDir\ollama.exe" --version
& "$CodexDir\codex.exe" --version
