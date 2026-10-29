#Requires -Version 7.0
param([Parameter(Mandatory)][string]$TestRoot)
$ErrorActionPreference='Stop'
$sync=Join-Path (Split-Path $PSScriptRoot -Parent) 'Sync-Archify.ps1'
if (!(Test-Path -LiteralPath $sync)) { throw 'Sync-Archify.ps1 is missing' }
if (Test-Path -LiteralPath $TestRoot) { throw 'Use a new test directory' }
[IO.Directory]::CreateDirectory($TestRoot)|Out-Null
function G([string]$Dir,[string[]]$Arguments) {
    $out=& git -C $Dir @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($out -join "`n") }
    return ($out -join "`n").Trim()
}
function Check([bool]$Value,[string]$Message) { if (!$Value) { throw $Message } }
function Write-Text([string]$Path,[string]$Text) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))|Out-Null
    [IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))
}
function Init([string]$Dir) {
    [IO.Directory]::CreateDirectory($Dir)|Out-Null
    G $Dir @('init','-b','main')|Out-Null
    G $Dir @('config','user.name','Sync Test')|Out-Null
    G $Dir @('config','user.email','sync-test@example.invalid')|Out-Null
}
$up=Join-Path $TestRoot 'upstream';Init $up
Write-Text (Join-Path $up 'archify/SKILL.md') "---`nname: archify`ndescription: Fixture`n---`n"
Write-Text (Join-Path $up 'archify/package.json') '{"name":"archify","version":"1.0.0"}'
Write-Text (Join-Path $up 'archify/bin/archify.mjs') "console.log('fixture doctor passed');"
Write-Text (Join-Path $up 'archify/LICENSE') 'Fixture license'
Write-Text (Join-Path $up 'archify/THIRD_PARTY_NOTICES.md') 'Fixture notices'
Write-Text (Join-Path $up 'archify/data.txt') 'version one'
G $up @('add','.')|Out-Null;G $up @('commit','-m','upstream one')|Out-Null
$remote=Join-Path $TestRoot 'remote.git'
& git init --bare --initial-branch=main $remote|Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Bare repository initialization failed' }
$work=Join-Path $TestRoot 'work';Init $work
Write-Text (Join-Path $work 'README.md') 'user repository'
Write-Text (Join-Path $work 'skills/archify/obsolete.txt') 'must disappear'
G $work @('add','.')|Out-Null;G $work @('commit','-m','base')|Out-Null
G $work @('remote','add','origin',$remote)|Out-Null;G $work @('push','-u','origin','main')|Out-Null
Write-Text (Join-Path $work '.git/info/exclude') 'skills/archify/local.hidden'
Write-Text (Join-Path $work 'skills/archify/local.hidden') 'hidden local content'
(Get-Item -LiteralPath (Join-Path $work 'skills/archify/local.hidden')).Attributes = [IO.FileAttributes]::Hidden
$installed=Join-Path $TestRoot 'installed'
Write-Text (Join-Path $installed 'other/SKILL.md') 'keep other skill'

$firstOutput=@(& $sync -RepositoryRoot $work -UpstreamRepository $up -SkillsRoot $installed 6>&1)
$firstResult=(($firstOutput|Where-Object { $_ -is [string] }) -join "`n")|ConvertFrom-Json
Check ($firstResult.Updated -eq $true) 'Updated result not reported'
Check (($firstOutput|Out-String) -match '已更新') 'Chinese update result missing'
Check ([IO.File]::ReadAllText((Join-Path $firstResult.Backup 'previous-package/local.hidden')) -eq 'hidden local content') 'Hidden backup content lost'
Check ([IO.File]::ReadAllText((Join-Path $work 'skills/archify/data.txt')) -eq 'version one') 'Package not synchronized'
Check (!(Test-Path -LiteralPath (Join-Path $work 'skills/archify/obsolete.txt'))) 'Obsolete package file remains'
Check ([IO.File]::ReadAllText((Join-Path $installed 'archify/data.txt')) -eq 'version one') 'Local skill not refreshed'
Check ((G $work @('rev-parse','HEAD')) -eq (G $remote @('rev-parse','main'))) 'Commit not pushed'
$lock=Get-Content -LiteralPath (Join-Path $work 'skills/archify.upstream.json') -Raw|ConvertFrom-Json
Check ($lock.commit -eq (G $up @('rev-parse','HEAD'))) 'Upstream revision not recorded'
$first=G $work @('rev-parse','HEAD')
$repeatOutput=@(& $sync -RepositoryRoot $work -UpstreamRepository $up -SkillsRoot $installed 6>&1)
$repeatResult=(($repeatOutput|Where-Object { $_ -is [string] }) -join "`n")|ConvertFrom-Json
Check ($repeatResult.Updated -eq $false) 'No-op incorrectly reported an update'
Check (($repeatOutput|Out-String) -match '已是最新') 'Chinese no-op result missing'
Check ((G $work @('rev-parse','HEAD')) -eq $first) 'No-op sync created a commit'

Write-Text (Join-Path $up 'archify/data.txt') 'version two'
G $up @('add','.')|Out-Null;G $up @('commit','-m','upstream two')|Out-Null
& $sync -RepositoryRoot $work -UpstreamRepository $up -SkillsRoot $installed
Check ([IO.File]::ReadAllText((Join-Path $installed 'archify/data.txt')) -eq 'version two') 'Second version not installed'
Check ([IO.File]::ReadAllText((Join-Path $installed 'other/SKILL.md')) -eq 'keep other skill') 'Unrelated skill changed'
Check ([IO.File]::ReadAllText((Join-Path $work 'README.md')) -eq 'user repository') 'Unrelated repository file changed'

$last=G $remote @('rev-parse','main')
$bad=Join-Path $TestRoot 'invalid-upstream';Init $bad
Write-Text (Join-Path $bad 'README.md') 'No installable package'
G $bad @('add','.')|Out-Null;G $bad @('commit','-m','invalid package')|Out-Null
$beforeHash=(Get-FileHash -LiteralPath (Join-Path $work 'skills/archify/data.txt')).Hash
$rejected=$false
try { & $sync -RepositoryRoot $work -UpstreamRepository $bad -SkillsRoot $installed } catch { $rejected=$true }
Check $rejected 'Invalid upstream package was not rejected'
Check ((Get-FileHash -LiteralPath (Join-Path $work 'skills/archify/data.txt')).Hash -eq $beforeHash) 'Invalid upstream changed installed package'
Check ((G $remote @('rev-parse','main')) -eq $last) 'Invalid package was published'

$removeControl=@{FailOnce=$true}
function Remove-Item {
    [CmdletBinding()]
    param([string]$LiteralPath,[switch]$Recurse,[switch]$Force)
    if ($LiteralPath -eq [IO.Path]::GetFullPath((Join-Path $work 'skills/archify')) -and $removeControl.FailOnce) {
        $removeControl.FailOnce=$false
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath (Join-Path $LiteralPath 'data.txt') -Force
        throw 'Simulated partial deletion failure'
    }
    Microsoft.PowerShell.Management\Remove-Item @PSBoundParameters
}
$rejected=$false
Write-Text (Join-Path $up 'archify/data.txt') 'deletion failure version'
G $up @('add','.')|Out-Null;G $up @('commit','-m','delete transaction test')|Out-Null
try { & $sync -RepositoryRoot $work -UpstreamRepository $up -SkillsRoot $installed } catch { $rejected=$true }
finally { Microsoft.PowerShell.Management\Remove-Item -LiteralPath 'Function:\Remove-Item' }
Check $rejected 'Partial deletion failure was not reported'
Check ([IO.File]::ReadAllText((Join-Path $work 'skills/archify/data.txt')) -eq 'version two') 'Original not restored after partial deletion'
Check (!(G $work @('status','--porcelain'))) 'Partial deletion rollback left dirty files'

Write-Text (Join-Path $up 'archify/data.txt') 'version three'
G $up @('add','.')|Out-Null;G $up @('commit','-m','upstream three')|Out-Null
function Copy-Item {
    [CmdletBinding()]
    param([string]$LiteralPath,[string]$Destination,[switch]$Recurse,[switch]$Force)
    if ([IO.Path]::GetFileName($LiteralPath) -eq 'package' -and $Destination -eq (Join-Path $work 'skills/archify')) {
        Write-Text (Join-Path $Destination 'partial.txt') 'incomplete copy'
        throw 'Simulated partial copy failure'
    }
    Microsoft.PowerShell.Management\Copy-Item @PSBoundParameters
}
$rejected=$false
try { & $sync -RepositoryRoot $work -UpstreamRepository $up -SkillsRoot $installed } catch { $rejected=$true }
finally { Remove-Item -LiteralPath 'Function:\Copy-Item' }
Check $rejected 'Partial copy failure was not detected'
Check ([IO.File]::ReadAllText((Join-Path $work 'skills/archify/data.txt')) -eq 'version two') 'Original not restored after copy failure'
Check (!(Test-Path -LiteralPath (Join-Path $work 'skills/archify/partial.txt'))) 'Partial file remains after rollback'
Check (!(G $work @('status','--porcelain'))) 'Rollback left tracked changes'
& $sync -RepositoryRoot $work -UpstreamRepository $up -SkillsRoot $installed
Check ([IO.File]::ReadAllText((Join-Path $installed 'archify/data.txt')) -eq 'version three') 'Retry after copy failure did not succeed'
$last=G $remote @('rev-parse','main')

$mergeWork=Join-Path $TestRoot 'merge-work'
& git clone $remote $mergeWork 2>&1|Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Merge fixture clone failed' }
G $mergeWork @('config','user.name','Sync Test')|Out-Null
G $mergeWork @('config','user.email','sync-test@example.invalid')|Out-Null
G $mergeWork @('checkout','-b','feature')|Out-Null
Write-Text (Join-Path $mergeWork 'skills/archify/feature.txt') 'allowed feature'
G $mergeWork @('add','.')|Out-Null;G $mergeWork @('commit','-m','feature')|Out-Null
G $mergeWork @('checkout','main')|Out-Null
Write-Text (Join-Path $mergeWork 'skills/archify/main.txt') 'allowed main'
G $mergeWork @('add','.')|Out-Null;G $mergeWork @('commit','-m','main')|Out-Null
G $mergeWork @('merge','--no-commit','--no-ff','feature')|Out-Null
Write-Text (Join-Path $mergeWork 'README.md') 'unrelated merge-only change'
G $mergeWork @('add','README.md')|Out-Null;G $mergeWork @('commit','-m','merge-only unrelated work')|Out-Null
$rejected=$false
try { & $sync -RepositoryRoot $mergeWork -UpstreamRepository $up -SkillsRoot $installed } catch { $rejected=$true }
Check $rejected 'Merge-only unrelated change was not rejected'
Check ((G $remote @('rev-parse','main')) -eq $last) 'Unrelated merge change was published'

$junctionWork=Join-Path $TestRoot 'junction-work';Init $junctionWork
Write-Text (Join-Path $junctionWork 'README.md') 'junction test'
G $junctionWork @('add','.')|Out-Null;G $junctionWork @('commit','-m','junction base')|Out-Null
G $junctionWork @('remote','add','origin',$remote)|Out-Null
$outside=Join-Path $TestRoot 'outside-skills'
Write-Text (Join-Path $outside 'archify/sentinel.txt') 'keep external content'
New-Item -ItemType Junction -Path (Join-Path $junctionWork 'skills') -Target $outside|Out-Null
$rejected=$false
try { & $sync -RepositoryRoot $junctionWork -UpstreamRepository $up -SkillsRoot $installed } catch { $rejected=$_.Exception.Message -like '*skills directory must not be a junction*' }
Check $rejected 'Junction parent not rejected'
Check ([IO.File]::ReadAllText((Join-Path $outside 'archify/sentinel.txt')) -eq 'keep external content') 'External content changed'
Write-Text (Join-Path $work 'README.md') 'uncommitted work'
$rejected=$false
try { & $sync -RepositoryRoot $work -UpstreamRepository $up -SkillsRoot $installed } catch { $rejected=$true }
Check $rejected 'Dirty working tree was not rejected'
Check ((G $remote @('rev-parse','main')) -eq $last) 'Dirty work was published'
Write-Text (Join-Path $work 'README.md') 'unpublished user commit'
G $work @('add','README.md')|Out-Null;G $work @('commit','-m','private local work')|Out-Null
$rejected=$false
try { & $sync -RepositoryRoot $work -UpstreamRepository $up -SkillsRoot $installed } catch { $rejected=$true }
Check $rejected 'Unrelated ahead commit was not rejected'
Check ((G $remote @('rev-parse','main')) -eq $last) 'Unrelated commit was published'
[pscustomobject]@{ Passed=14; Checks=@('sync and push','Chinese update/no-op results preserve JSON pipeline','obsolete file removed','revision recorded','idempotent no-op','version updates and local install','unrelated files preserved','invalid upstream rejected','hidden files backed up','partial deletion restored','partial copy restored and retry succeeds','merge-only unrelated work rejected','junction parent specifically rejected','dirty/ahead work rejected'); Artifacts=$TestRoot }|ConvertTo-Json -Depth 3
