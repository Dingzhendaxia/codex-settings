#Requires -Version 7.0
param([string]$TargetRoot)

$ErrorActionPreference = 'Stop'
$skillsRoot = $PSScriptRoot
if (-not $TargetRoot) { $TargetRoot = Join-Path $HOME '.agents\skills' }
$TargetRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TargetRoot)
$skillNames = @('archify', 'tomd', 'litreview')
# Check the complete package before changing an existing installation.
foreach ($name in $skillNames) {
    if (-not (Test-Path -LiteralPath (Join-Path $skillsRoot "$name\SKILL.md") -PathType Leaf)) {
        throw "仓库中缺少技能：$name"
    }
}
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
New-Item -ItemType Directory -Path $TargetRoot -Force | Out-Null

foreach ($name in $skillNames) {
    $source = Join-Path $skillsRoot $name
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
        $backup = "$target.backup-$stamp-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        # Both move endpoints must remain direct children of the requested root.
        foreach ($candidate in @($target, $backup)) {
            if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($candidate)) -ne $TargetRoot.TrimEnd('\', '/')) {
                throw "备份路径超出目标技能目录：$candidate"
            }
        }
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
