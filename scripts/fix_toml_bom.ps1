$CodexHome = Join-Path $HOME '.codex'

# Remove backup files inside .codex that might confuse the loader
Get-ChildItem -Path $CodexHome -Recurse -File | Where-Object { $_.Name -like '*.backup*' -or $_.Name -like '*backup*' } | ForEach-Object {
    Write-Host "Removendo arquivo de backup interno: $($_.FullName)"
    Remove-Item -Path $_.FullName -Force
}

# Process all .toml files strictly without BOM
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Get-ChildItem -Path $CodexHome -Recurse -File | Where-Object { $_.Extension -eq '.toml' -or $_.Name -like '*.toml*' } | ForEach-Object {
    $Path = $_.FullName
    $Bytes = [System.IO.File]::ReadAllBytes($Path)

    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
        $Text = [System.Text.Encoding]::UTF8.GetString($Bytes, 3, $Bytes.Length - 3)
    } else {
        $Text = [System.Text.Encoding]::UTF8.GetString($Bytes)
    }

    $Text = $Text.TrimStart([char]0xFEFF)

    if ($Text.StartsWith('ï»¿')) {
        $Text = $Text.Substring(3)
    }

    [System.IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
}

Write-Host "`nRelatório Final de BOM em C:\Users\fjuni\.codex:"
Get-ChildItem -Path $CodexHome -Recurse -File | Where-Object { $_.Extension -eq '.toml' } | ForEach-Object {
    $B = [System.IO.File]::ReadAllBytes($_.FullName)
    $HasBOM = ($B.Length -ge 3 -and $B[0] -eq 0xEF -and $B[1] -eq 0xBB -and $B[2] -eq 0xBF)
    Write-Host "$($_.FullName) -> HasBOM: $HasBOM"
}
