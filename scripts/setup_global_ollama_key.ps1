$OllamaKey = '3d859c811a424c77818b13275d7f0c6e.g8-Pbhq4GuQ7CONW_ykE5dDA'

[Environment]::SetEnvironmentVariable('OLLAMA_API_KEY', $OllamaKey, 'User')
[Environment]::SetEnvironmentVariable('OLLAMA_KEY', $OllamaKey, 'User')

$OllamaDir = 'C:\Users\fjuni\AppData\Local\Programs\Ollama'
$CodexDir = 'C:\Users\fjuni\AppData\Local\OpenAI\Codex\bin\69066b736e1e17a4'
$GoDir = 'C:\Users\fjuni\go\bin'

$UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')

if ($UserPath -notlike ('*' + $OllamaDir + '*')) {
    $UserPath = $OllamaDir + ';' + $UserPath
}
if ($UserPath -notlike ('*' + $CodexDir + '*')) {
    $UserPath = $CodexDir + ';' + $UserPath
}
if ($UserPath -notlike ('*' + $GoDir + '*')) {
    $UserPath = $GoDir + ';' + $UserPath
}

[Environment]::SetEnvironmentVariable('Path', $UserPath, 'User')

$env:OLLAMA_API_KEY = $OllamaKey
$env:OLLAMA_KEY = $OllamaKey
$env:Path = $OllamaDir + ';' + $CodexDir + ';' + $GoDir + ';' + $env:Path

Write-Host 'Chave OLLAMA_API_KEY e caminhos PATH configurados com sucesso.'

& ($OllamaDir + '\ollama.exe') --version
& ($CodexDir + '\codex.exe') --version
