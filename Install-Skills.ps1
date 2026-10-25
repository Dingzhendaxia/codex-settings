param([string]$TargetRoot)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $TargetRoot) { $TargetRoot = Join-Path $HOME '.agents\skills' }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
New-Item -ItemType Directory -Path $TargetRoot -Force | Out-Null

foreach ($name in @('archify', 'tomd')) {
    $source = Join-Path $repo "skills\$name"
    if (-not (Test-Path -LiteralPath (Join-Path $source 'SKILL.md'))) {
        throw "仓库中缺少技能：$name"
    }
    $target = Join-Path $TargetRoot $name
    $existing = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    if ($existing) {
        if ($existing.LinkType -in @('Junction', 'SymbolicLink') -and
            @($existing.Target)[0] -eq $source) {
            Write-Host "$name 已连接。"
            continue
        }
        if ($existing.LinkType -notin @('Junction', 'SymbolicLink')) {
            $sourceFiles = @(Get-ChildItem -LiteralPath $source -Recurse -File)
            $targetFiles = @(Get-ChildItem -LiteralPath $target -Recurse -File)
            if ($sourceFiles.Count -eq $targetFiles.Count) {
                $different = $false
                foreach ($file in $sourceFiles) {
                    $relative = [System.IO.Path]::GetRelativePath($source, $file.FullName)
                    $other = Join-Path $target $relative
                    if (-not (Test-Path -LiteralPath $other) -or
                        (Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $other).Hash) {
                        $different = $true
                        break
                    }
                }
                if (-not $different) {
                    Write-Host "$name 已是最新。"
                    continue
                }
            }
        }
        $backup = "$target.backup-$stamp"
        Move-Item -LiteralPath $target -Destination $backup
        Write-Host "已备份旧版 $name：$backup"
    }
    try {
        New-Item -ItemType Junction -Path $target -Target $source -ErrorAction Stop | Out-Null
        Write-Host "已连接 $name。"
    } catch {
        Copy-Item -LiteralPath $source -Destination $target -Recurse
        Write-Host "已复制 $name。"
    }
}
