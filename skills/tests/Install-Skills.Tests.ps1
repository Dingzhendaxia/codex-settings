#Requires -Version 7.0
param(
    [string]$InstallerPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'Install-Skills.ps1'),
    [Parameter(Mandatory)][string]$TestRoot
)
$ErrorActionPreference = 'Stop'
$TestRoot = [IO.Path]::GetFullPath($TestRoot)
if (Test-Path -LiteralPath $TestRoot) { throw 'Use a new, empty test root.' }
[IO.Directory]::CreateDirectory($TestRoot) | Out-Null
$installerText = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $InstallerPath).Path)
$passed = [Collections.Generic.List[string]]::new()
function Assert-True([bool]$Value, [string]$Message) { if (-not $Value) { throw $Message } }
function New-Fixture([string]$Name, [switch]$MissingLitreview) {
    $root = Join-Path $TestRoot $Name
    [IO.Directory]::CreateDirectory($root) | Out-Null
    [IO.File]::WriteAllText((Join-Path $root 'Install-Skills.ps1'), $installerText)
    $names = if ($MissingLitreview) { @('archify','tomd') } else { @('archify','tomd','litreview') }
    foreach ($name in $names) {
        $dir = Join-Path $root $name
        [IO.Directory]::CreateDirectory((Join-Path $dir 'references')) | Out-Null
        [IO.File]::WriteAllText((Join-Path $dir 'SKILL.md'), "---`nname: $name`ndescription: Fixture`n---`n")
        [IO.File]::WriteAllText((Join-Path $dir 'references\payload.txt'), $name)
    }
    return $root
}
function Assert-Installed([string]$Root) {
    foreach ($name in @('archify','tomd','litreview')) {
        Assert-True (Test-Path -LiteralPath (Join-Path $Root "$name\SKILL.md")) "Missing installed skill: $name"
        Assert-True ([IO.File]::ReadAllText((Join-Path $Root "$name\references\payload.txt")) -eq $name) "Missing nested payload: $name"
    }
}

$fixture = New-Fixture 'fresh-source'
$target = Join-Path $TestRoot 'fresh-target'
& (Join-Path $fixture 'Install-Skills.ps1') -TargetRoot $target
Assert-Installed $target
$passed.Add('fresh installation includes all three skills and nested resources')
& (Join-Path $fixture 'Install-Skills.ps1') -TargetRoot $target
Assert-True (@(Get-ChildItem -LiteralPath $target -Filter '*.backup-*').Count -eq 0) 'Repeat install created unnecessary backups'
$passed.Add('repeat installation is idempotent')

$localTarget = Join-Path $TestRoot 'existing-target'
[IO.Directory]::CreateDirectory((Join-Path $localTarget 'litreview')) | Out-Null
[IO.File]::WriteAllText((Join-Path $localTarget 'litreview\personal.txt'), 'keep my local config')
& (Join-Path $fixture 'Install-Skills.ps1') -TargetRoot $localTarget
Assert-Installed $localTarget
$backups = @(Get-ChildItem -LiteralPath $localTarget -Filter 'litreview.backup-*' -Directory)
Assert-True ($backups.Count -eq 1) 'Existing skill backup missing'
Assert-True ([IO.File]::ReadAllText((Join-Path $backups[0].FullName 'personal.txt')) -eq 'keep my local config') 'Local data was lost'
$passed.Add('existing local skill is backed up without losing personal files')

$copyTarget = Join-Path $TestRoot 'copy-target'
function New-Item {
    [CmdletBinding()]
    param([string]$ItemType,[string]$Path,[string]$Target,[switch]$Force)
    if ($ItemType -eq 'Junction') { throw 'Simulated unavailable junction support' }
    Microsoft.PowerShell.Management\New-Item @PSBoundParameters
}
try { & (Join-Path $fixture 'Install-Skills.ps1') -TargetRoot $copyTarget }
finally { Remove-Item -LiteralPath 'Function:\New-Item' }
Assert-Installed $copyTarget
Assert-True (-not (Get-Item -LiteralPath (Join-Path $copyTarget 'litreview')).LinkType) 'Expected copied directory'
& (Join-Path $fixture 'Install-Skills.ps1') -TargetRoot $copyTarget
Assert-True (@(Get-ChildItem -LiteralPath $copyTarget -Filter '*.backup-*').Count -eq 0) 'Identical copies were unnecessarily replaced'
$passed.Add('junction failure falls back to recursive copy and remains idempotent')

$missing = New-Fixture 'missing-source' -MissingLitreview
$missingTarget = Join-Path $TestRoot 'missing-target'
$failed = $false
try { & (Join-Path $missing 'Install-Skills.ps1') -TargetRoot $missingTarget }
catch { $failed = $true }
Assert-True $failed 'Missing skill did not fail installation'
Assert-True (-not (Test-Path -LiteralPath $missingTarget)) 'Preflight failure partially modified the installation'
$passed.Add('missing source fails before any target changes')
[pscustomobject]@{ Passed=$passed.Count; Checks=$passed; Artifacts=$TestRoot } | ConvertTo-Json -Depth 4
