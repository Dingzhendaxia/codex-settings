#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$UpstreamRepository = 'https://github.com/tt-a1i/archify.git',
    [string]$UpstreamRef = 'main',
    [string]$Remote = 'origin',
    [string]$Branch = 'main',
    [string]$SkillsRoot = (Join-Path $HOME '.agents/skills')
)
$ErrorActionPreference='Stop'
function Invoke-SyncGit([string]$Directory,[string[]]$Arguments) {
    $output=& git -C $Directory @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments[0]) failed: $($output -join "`n")" }
    return ($output -join "`n").Trim()
}
function Under([string]$Path,[string]$Root) {
    $full=[IO.Path]::GetFullPath($Path)
    $prefix=[IO.Path]::GetFullPath($Root).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    if (!$full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw "Path outside expected directory: $full" }
    return $full
}
function Same-Files([string]$Left,[string]$Right) {
    if (!(Test-Path -LiteralPath $Right -PathType Container)) { return $false }
    $a=@(Get-ChildItem -LiteralPath $Left -Recurse -File -Force)
    $b=@(Get-ChildItem -LiteralPath $Right -Recurse -File -Force)
    if ($a.Count -ne $b.Count) { return $false }
    foreach ($file in $a) {
        $other=Join-Path $Right ([IO.Path]::GetRelativePath($Left,$file.FullName))
        if (!(Test-Path -LiteralPath $other -PathType Leaf) -or
            (Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $other).Hash) { return $false }
    }
    return $true
}
Get-Command git,node -ErrorAction Stop|Out-Null
$RepositoryRoot=[IO.Path]::GetFullPath((Invoke-SyncGit $RepositoryRoot @('rev-parse','--show-toplevel')))
$SkillsRoot=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SkillsRoot)
$package=Under (Join-Path $RepositoryRoot 'skills/archify') $RepositoryRoot
$lockPath=Under (Join-Path $RepositoryRoot 'skills/archify.upstream.json') $RepositoryRoot
$skillsDirectory=Get-Item -LiteralPath (Join-Path $RepositoryRoot 'skills') -Force -ErrorAction SilentlyContinue
if ($skillsDirectory -and ($skillsDirectory.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Repository skills directory must not be a junction or symlink.' }
if ((Invoke-SyncGit $RepositoryRoot @('branch','--show-current')) -ne $Branch) { throw "Switch to branch $Branch before syncing." }
if (Invoke-SyncGit $RepositoryRoot @('status','--porcelain','--untracked-files=all')) { throw 'Repository has uncommitted files; commit or stash them before syncing.' }
if ((Invoke-SyncGit $RepositoryRoot @('remote','get-url',$Remote)) -eq $UpstreamRepository) { throw 'The push remote must be your repository, not the upstream.' }
Invoke-SyncGit $RepositoryRoot @('fetch',$Remote,$Branch)|Out-Null
Invoke-SyncGit $RepositoryRoot @('merge','--ff-only',"$Remote/$Branch")|Out-Null
if (Invoke-SyncGit $RepositoryRoot @('rev-list','--min-parents=2',"$Remote/$Branch..HEAD")) { throw 'Unpublished merge commits exist; refusing to publish unrelated merge resolutions.' }
$ahead=Invoke-SyncGit $RepositoryRoot @('log',"$Remote/$Branch..HEAD",'--format=','--name-only')
foreach ($path in ($ahead -split "`n"|Where-Object { $_.Trim() })) {
    if ($path.Trim() -notmatch '^skills/archify(/|\.upstream\.json$)') { throw 'Unpublished unrelated commits exist; sync stopped without pushing them.' }
}
Invoke-SyncGit $RepositoryRoot @('push','--no-follow-tags','--dry-run',$Remote,"HEAD:refs/heads/$Branch")|Out-Null
$temp=Join-Path ([IO.Path]::GetTempPath()) ('codex-archify-sync-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temp)|Out-Null
$keepBackup=$false
try {
    $upstream=Under (Join-Path $temp 'upstream') $temp
    [IO.Directory]::CreateDirectory($upstream)|Out-Null
    Invoke-SyncGit $upstream @('init','--quiet')|Out-Null
    Invoke-SyncGit $upstream @('fetch','--depth=1',$UpstreamRepository,$UpstreamRef)|Out-Null
    $revision=Invoke-SyncGit $upstream @('rev-parse','FETCH_HEAD')
    $archive=Under (Join-Path $temp 'package.zip') $temp
    Invoke-SyncGit $upstream @('archive','--format=zip','-o',$archive,($revision+':archify'))|Out-Null
    $staged=Under (Join-Path $temp 'package') $temp
    $zip=[IO.Compression.ZipFile]::OpenRead($archive)
    try { foreach ($entry in $zip.Entries) { Under (Join-Path $staged $entry.FullName) $staged|Out-Null } }
    finally { $zip.Dispose() }
    Expand-Archive -LiteralPath $archive -DestinationPath $staged
    foreach ($required in @('SKILL.md','package.json','bin/archify.mjs','LICENSE','THIRD_PARTY_NOTICES.md')) {
        if (!(Test-Path -LiteralPath (Join-Path $staged $required) -PathType Leaf)) { throw "Incomplete upstream package: $required" }
    }
    $diagnosis=& node (Join-Path $staged 'bin/archify.mjs') doctor 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Upstream runtime check failed: $($diagnosis -join "`n")" }
    $identity=[ordered]@{ repository=$UpstreamRepository; ref=$UpstreamRef; commit=$revision; subdirectory='archify' }
    $lockText=($identity|ConvertTo-Json)+"`n"
    $old=Get-Item -LiteralPath $package -Force -ErrorAction SilentlyContinue
    if ($old -and $old.LinkType) { throw 'Repository skills/archify must be a real directory, not a link.' }
    if (!(Same-Files $staged $package)) {
        if ($old) {
            $backup=Under (Join-Path $temp 'previous-package') $temp
            Copy-Item -LiteralPath $package -Destination $backup -Recurse -Force
            $keepBackup=$true
            if (!(Same-Files $package $backup)) { throw "Backup verification failed; original package retained. Backup: $temp" }
        }
        try {
          if ($old) {
            # Resolve and check the exact recursive-delete target immediately before removal.
            $resolved=(Resolve-Path -LiteralPath $package).Path
            if ($resolved -ne $package) { throw 'Package resolution changed unexpectedly.' }
            Under $resolved (Join-Path $RepositoryRoot 'skills')|Out-Null
            Remove-Item -LiteralPath $resolved -Recurse -Force
          }
          Copy-Item -LiteralPath $staged -Destination $package -Recurse -Force
        }
        catch {
            $copyError=$_
            try {
              if (Test-Path -LiteralPath $package) {
                $partial=Get-Item -LiteralPath $package -Force
                if ($partial.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Unexpected link during rollback. Backup: $temp" }
                Under $package (Join-Path $RepositoryRoot 'skills')|Out-Null
                Remove-Item -LiteralPath $package -Recurse -Force
              }
              if ($keepBackup) { Copy-Item -LiteralPath $backup -Destination $package -Recurse -Force }
            } catch { throw "Package replacement and automatic recovery were blocked. Retained backup: $temp. $_" }
            throw "Package replacement failed and original restored where available. Backup: $temp. $copyError"
        }
    }
    [IO.File]::WriteAllText($lockPath,$lockText,[Text.UTF8Encoding]::new($false))
    Invoke-SyncGit $RepositoryRoot @('add','--','skills/archify','skills/archify.upstream.json')|Out-Null
    $changes=Invoke-SyncGit $RepositoryRoot @('diff','--cached','--name-only')
    if ($changes) {
        Invoke-SyncGit $RepositoryRoot @('commit','-m',"chore(archify): sync upstream $($revision.Substring(0,12))")|Out-Null
    }
    Invoke-SyncGit $RepositoryRoot @('push','--no-follow-tags',$Remote,"HEAD:refs/heads/$Branch")|Out-Null
    # Refresh only Archify; do not replace the user's other skills or project registries.
    [IO.Directory]::CreateDirectory($SkillsRoot)|Out-Null
    $installed=Under (Join-Path $SkillsRoot 'archify') $SkillsRoot
    $existing=Get-Item -LiteralPath $installed -Force -ErrorAction SilentlyContinue
    $linked=$existing -and $existing.LinkType -in @('Junction','SymbolicLink') -and @($existing.Target)[0] -eq $package
    $identical=$existing -and !$existing.LinkType -and (Same-Files $package $installed)
    if (!$linked -and !$identical) {
        if ($existing) {
            $installedBackup=Under (Join-Path $temp 'previous-installed-skill') $temp
            Under $installed $SkillsRoot|Out-Null
            Move-Item -LiteralPath $installed -Destination $installedBackup
            $keepBackup=$true
        }
        try { New-Item -ItemType Junction -Path $installed -Target $package -ErrorAction Stop|Out-Null }
        catch { Copy-Item -LiteralPath $package -Destination $installed -Recurse -Force }
    }
    [pscustomobject]@{ UpstreamCommit=$revision; RepositoryCommit=(Invoke-SyncGit $RepositoryRoot @('rev-parse','HEAD')); Updated=[bool]$changes; Pushed=$true; Package=$package; Skill=$installed; Backup=$(if ($keepBackup) { $temp } else { $null }) }|ConvertTo-Json
    # Keep the JSON success stream usable by scripts; human-readable text goes to the host.
    Write-Host ''
    if ($changes) { Write-Host '同步成功：Archify 已更新。' -ForegroundColor Green }
    else { Write-Host '检查完成：Archify 已是最新，本次未创建新提交。' -ForegroundColor Green }
    Write-Host "GitHub：已成功同步到 $Remote/$Branch。"
    Write-Host "上游版本：$revision"
    Write-Host "本地技能：$installed"
    if ($keepBackup) { Write-Host "备份位置：$temp" }
    else { Write-Host '备份：本次未产生备份。' }
} finally {
    if (!$keepBackup -and (Test-Path -LiteralPath $temp)) {
        $resolved=(Resolve-Path -LiteralPath $temp).Path
        if ([IO.Path]::GetFileName($resolved) -notlike 'codex-archify-sync-*') { throw 'Unexpected temporary directory' }
        Under $resolved ([IO.Path]::GetTempPath())|Out-Null
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
