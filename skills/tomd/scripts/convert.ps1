[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Source,
    [string]$OutputDirectory = (Join-Path (Get-Location) 'outputs/markitdown'),
    [switch]$AllowNetwork
)

$ErrorActionPreference = 'Stop'
function Report([hashtable]$Result, [int]$Code) {
    $Result | ConvertTo-Json -Depth 4 -Compress
    exit $Code
}

try {
    $remote = $Source -match '^https?://'
    if ($remote) {
        $uri = [uri]$Source
        if (-not $uri.IsAbsoluteUri -or -not $uri.Host) { throw 'Invalid HTTP(S) URL.' }
        $inputSource = $uri.AbsoluteUri
        $label = 'web-document'
        $extension = [IO.Path]::GetExtension($uri.AbsolutePath).ToLowerInvariant()
    } else {
        $item = Get-Item -LiteralPath $Source
        if ($item.PSIsContainer) { throw 'Source must be a file, not a directory.' }
        $inputSource = $item.FullName
        $label = $item.Name
        $extension = $item.Extension.ToLowerInvariant()
        if ($extension -in @('.md', '.markdown')) {
            Report @{ status = 'already_markdown'; markdown = $inputSource } 0
        }
    }
    if (($remote -or $extension -in @('.wav', '.mp3', '.m4a', '.ogg', '.flac', '.mp4', '.webm')) -and -not $AllowNetwork) {
        Report @{ status = 'needs_network'; message = 'Confirm the required external processing, then pass -AllowNetwork.' } 3
    }

    $converter = Get-Command markitdown -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $converter) {
        $fallback = Join-Path $env:USERPROFILE '.local/bin/markitdown.exe'
        if (Test-Path -LiteralPath $fallback -PathType Leaf) {
            $converterPath = $fallback
        } else { throw 'MarkItDown is not installed or its executable cannot be found.' }
    } else { $converterPath = $converter.Source }

    $outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
    [IO.Directory]::CreateDirectory($outputRoot) | Out-Null
    $label = [regex]::Replace($label, '[<>:"/\\|?*\x00-\x1f]', '_')
    if ($label.Length -gt 70) { $label = $label.Substring(0, 70) }
    $prefix = Join-Path $outputRoot ($label + '-' + [guid]::NewGuid().ToString('N').Substring(0, 12))
    $markdown = $prefix + '.md'
    $pending = $prefix + '.partial.md'
    $log = $prefix + '.log'
    $nativeArgs = @($inputSource, '-o', $pending)
    $ErrorActionPreference = 'Continue'
    & $converterPath @nativeArgs *> $log
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($code -ne 0 -or -not (Test-Path -LiteralPath $pending -PathType Leaf)) {
        Report @{ status = 'failed'; exit_code = $code; log = $log; partial = $pending } 1
    }
    $text = [IO.File]::ReadAllText($pending, [Text.Encoding]::UTF8)
    if ([string]::IsNullOrWhiteSpace($text)) {
        Report @{ status = 'empty'; characters = 0; log = $log; partial = $pending } 2
    }
    Move-Item -LiteralPath $pending -Destination $markdown
    Report @{ status = 'converted'; markdown = $markdown; characters = $text.Length; log = $log; quality = 'not_reviewed' } 0
} catch {
    Report @{ status = 'failed'; message = $_.Exception.Message } 1
}
