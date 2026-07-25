$OllamaDir = "C:\Users\fjuni\AppData\Local\Programs\Ollama"
$UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')

if ($UserPath -notlike "*$OllamaDir*") {
    $NewPath = $OllamaDir + ";" + $UserPath
    [Environment]::SetEnvironmentVariable('Path', $NewPath, 'User')
    Write-Host "Ollama adicionado ao PATH permanente do Usuário."
} else {
    Write-Host "Ollama já se encontra no PATH do Usuário."
}

$env:Path = $OllamaDir + ";" + $env:Path

$CodexDir = Join-Path $env:USERPROFILE ".codex"
$ConfigToml = Join-Path $CodexDir "config.toml"

if (Test-Path $ConfigToml) {
    $Content = Get-Content -Path $ConfigToml -Raw
    $Updated = $Content -replace 'model_reasoning_effort\s*=\s*"(xhigh|max)"', 'model_reasoning_effort = "high"'
    Set-Content -Path $ConfigToml -Value $Updated -Encoding utf8
    Write-Host "config.toml atualizado com sucesso."
}

& "$OllamaDir\ollama.exe" --version
