$ErrorActionPreference = 'Stop'

$CodexHome = Join-Path $HOME '.codex'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupRoot = Join-Path $CodexHome "backup-before-toml-fix-$Timestamp"

if (-not (Test-Path $CodexHome)) {
    throw "Diretório do Codex não encontrado: $CodexHome"
}

New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null

$Utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
$Utf8NoBom  = New-Object System.Text.UTF8Encoding($false)

$TomlFiles = Get-ChildItem -Path $CodexHome -Filter '*.toml' -File -Recurse

foreach ($File in $TomlFiles) {
    $Path = $File.FullName

    $RelativePath = $Path.Substring($CodexHome.Length).TrimStart('\')
    $BackupPath = Join-Path $BackupRoot $RelativePath
    $BackupDirectory = Split-Path $BackupPath -Parent

    New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
    Copy-Item -LiteralPath $Path -Destination $BackupPath -Force

    $Bytes = [System.IO.File]::ReadAllBytes($Path)

    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
        $Text = [System.Text.Encoding]::UTF8.GetString($Bytes, 3, $Bytes.Length - 3)
    }
    elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) {
        $Text = [System.Text.Encoding]::Unicode.GetString($Bytes, 2, $Bytes.Length - 2)
    }
    elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF) {
        $Text = [System.Text.Encoding]::BigEndianUnicode.GetString($Bytes, 2, $Bytes.Length - 2)
    }
    else {
        try {
            $Text = $Utf8Strict.GetString($Bytes)
        }
        catch {
            $Text = [System.Text.Encoding]::Default.GetString($Bytes)
        }
    }

    $Text = $Text.TrimStart([char]0xFEFF)

    if ($Text.StartsWith('ï»¿')) {
        $Text = $Text.Substring(3)
    }

    $Text = [regex]::Replace(
        $Text,
        '(?m)^(\s*model_reasoning_effort\s*=\s*)"(xhigh|max)"(\s*)$',
        '${1}"high"${3}'
    )

    [System.IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
    Write-Host "Corrigido sem BOM: $Path"
}

Write-Host "`nVerificando se algum arquivo ainda possui BOM UTF-8:"
Get-ChildItem $CodexHome -Filter '*.toml' -File -Recurse | ForEach-Object {
    $B = [System.IO.File]::ReadAllBytes($_.FullName)
    $HasBOM = ($B.Length -ge 3 -and $B[0] -eq 0xEF -and $B[1] -eq 0xBB -and $B[2] -eq 0xBF)
    Write-Host "$($_.Name) -> HasBOM: $HasBOM"
}
