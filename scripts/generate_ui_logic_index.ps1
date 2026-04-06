[CmdletBinding()]
param(
    [string]$ProjectRoot = '',
    [string]$UiLogicRelative = 'assets\ui_logic',
    [string]$OutputFile = 'ui_logic_index.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent $scriptRoot
}
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$uiRoot = Join-Path $ProjectRoot $UiLogicRelative
$outPath = Join-Path $uiRoot $OutputFile

if (-not (Test-Path $uiRoot)) {
    throw "UI logic folder not found: $uiRoot"
}

$files = @(
    Get-ChildItem -Path $uiRoot -Recurse -File -Include *.xml,*.txt -ErrorAction SilentlyContinue |
        Sort-Object FullName
)

$keywordPattern = '(?i)login|signin|sign in|password|email|passport|wheel|spinner|logo|button|edit|textbox|window|frame|background|account|credential|auth'
$tokenPattern = '(?i)id\s*=\s*"([^"]+)"|name\s*=\s*"([^"]+)"|resource\s*=\s*"([^"]+)"|cmdid\s*=\s*"([^"]+)"|layout\w*\s*=\s*"([^"]+)"'

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# UI Logic Companion Index')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine('')
[void]$sb.AppendLine("Total files indexed: $($files.Count)")
[void]$sb.AppendLine('')

foreach ($file in $files) {
    $relative = [System.Uri]::UnescapeDataString((New-Object System.Uri(($ProjectRoot.TrimEnd('\\') + '\\'))).MakeRelativeUri((New-Object System.Uri($file.FullName))).ToString()) -replace '/', '\\'
    $text = ''
    try {
        $text = [System.IO.File]::ReadAllText($file.FullName)
    }
    catch {
        $text = ''
    }

    $matches = @([regex]::Matches($text, $keywordPattern))
    $keywordHits = @($matches | ForEach-Object { $_.Value.ToLowerInvariant() } | Sort-Object -Unique)

    $tokenMatches = @([regex]::Matches($text, $tokenPattern))
    $tokens = New-Object System.Collections.Generic.List[string]
    foreach ($m in $tokenMatches) {
        for ($i = 1; $i -le 5; $i++) {
            $v = $m.Groups[$i].Value
            if (-not [string]::IsNullOrWhiteSpace($v) -and -not $tokens.Contains($v)) {
                $tokens.Add($v)
            }
        }
    }

    [void]$sb.AppendLine("## $relative")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("- Size bytes: $($file.Length)")
    [void]$sb.AppendLine("- Login keyword hits: $($keywordHits.Count)")
    if ($keywordHits.Count -gt 0) {
        [void]$sb.AppendLine("- Keywords: $([string]::Join(', ', $keywordHits))")
    }
    [void]$sb.AppendLine("- Candidate IDs/tokens: $($tokens.Count)")
    if ($tokens.Count -gt 0) {
        $sample = @($tokens | Select-Object -First 40)
        [void]$sb.AppendLine("- Token sample: $([string]::Join(', ', $sample))")
    }
    [void]$sb.AppendLine('')
}

[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::UTF8)
Write-Output "UI logic index generated: $outPath"
