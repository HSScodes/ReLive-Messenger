[CmdletBinding()]
param(
    [string]$ProjectRoot = '',
    [string]$ImagesRootRelative = 'assets\images\extracted',
    [string]$OutputFile = 'asset_gallery.html'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent $scriptRoot
}
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$imagesRoot = Join-Path $ProjectRoot $ImagesRootRelative
$outPath = Join-Path $ProjectRoot $OutputFile

if (-not (Test-Path $imagesRoot)) {
    throw "Images root not found: $imagesRoot"
}

$imageFiles = @(
    Get-ChildItem -Path $imagesRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -and (
                $_.Extension.Equals('.png', [System.StringComparison]::OrdinalIgnoreCase) -or
                $_.Extension.Equals('.bmp', [System.StringComparison]::OrdinalIgnoreCase) -or
                $_.Extension.Equals('.ico', [System.StringComparison]::OrdinalIgnoreCase) -or
                $_.Extension.Equals('.jpg', [System.StringComparison]::OrdinalIgnoreCase) -or
                $_.Extension.Equals('.jpeg', [System.StringComparison]::OrdinalIgnoreCase) -or
                $_.Extension.Equals('.webp', [System.StringComparison]::OrdinalIgnoreCase)
            )
        }
)

$imageFiles = @($imageFiles | Sort-Object FullName)

$html = New-Object System.Text.StringBuilder

[void]$html.AppendLine('<!doctype html>')
[void]$html.AppendLine('<html lang="en">')
[void]$html.AppendLine('<head>')
[void]$html.AppendLine('  <meta charset="utf-8" />')
[void]$html.AppendLine('  <meta name="viewport" content="width=device-width, initial-scale=1" />')
[void]$html.AppendLine('  <title>WLM Extracted Asset Gallery</title>')
[void]$html.AppendLine('  <style>')
[void]$html.AppendLine('    body { font-family: Segoe UI, Tahoma, Arial, sans-serif; margin: 0; background: #f2f5f8; color: #1f2937; }')
[void]$html.AppendLine('    header { position: sticky; top: 0; z-index: 10; background: #ffffff; border-bottom: 1px solid #dbe3ea; padding: 12px 16px; }')
[void]$html.AppendLine('    .meta { font-size: 13px; color: #4b5563; }')
[void]$html.AppendLine('    .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(190px, 1fr)); gap: 12px; padding: 16px; }')
[void]$html.AppendLine('    .card { background: #fff; border: 1px solid #d9e2ea; border-radius: 8px; padding: 10px; box-shadow: 0 1px 2px rgba(0,0,0,0.04); }')
[void]$html.AppendLine('    .thumb { height: 120px; display: flex; align-items: center; justify-content: center; background: linear-gradient(180deg, #f8fbff 0%, #eef4fa 100%); border: 1px solid #e6edf4; border-radius: 6px; overflow: hidden; }')
[void]$html.AppendLine('    .thumb img { max-width: 100%; max-height: 100%; object-fit: contain; image-rendering: auto; }')
[void]$html.AppendLine('    .name { margin-top: 8px; font-size: 11px; line-height: 1.35; word-break: break-all; font-family: Consolas, Menlo, monospace; }')
[void]$html.AppendLine('  </style>')
[void]$html.AppendLine('</head>')
[void]$html.AppendLine('<body>')
[void]$html.AppendLine('  <header>')
[void]$html.AppendLine('    <div><strong>WLM Extracted Asset Gallery</strong></div>')
[void]$html.AppendLine("    <div class=`"meta`">Files: $($imageFiles.Count) | Source: $ImagesRootRelative</div>")
[void]$html.AppendLine('  </header>')
[void]$html.AppendLine('  <main class="grid">')

foreach ($file in $imageFiles) {
    $projectRootWithSlash = $ProjectRoot
    if (-not $projectRootWithSlash.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $projectRootWithSlash += [System.IO.Path]::DirectorySeparatorChar
    }
    $projectUri = New-Object System.Uri($projectRootWithSlash)
    $fileUri = New-Object System.Uri($file.FullName)
    $relativePath = [System.Uri]::UnescapeDataString($projectUri.MakeRelativeUri($fileUri).ToString())
    $webPath = $relativePath -replace '\\', '/'
    $safePath = [System.Uri]::EscapeUriString($webPath)
    $safeName = [System.Net.WebUtility]::HtmlEncode($webPath)

    [void]$html.AppendLine('    <article class="card">')
    [void]$html.AppendLine('      <div class="thumb">')
    [void]$html.AppendLine("        <img src=`"$safePath`" alt=`"$safeName`" loading=`"lazy`" />")
    [void]$html.AppendLine('      </div>')
    [void]$html.AppendLine("      <div class=`"name`">$safeName</div>")
    [void]$html.AppendLine('    </article>')
}

[void]$html.AppendLine('  </main>')
[void]$html.AppendLine('</body>')
[void]$html.AppendLine('</html>')

[System.IO.File]::WriteAllText($outPath, $html.ToString(), [System.Text.Encoding]::UTF8)
Write-Output "Gallery generated: $outPath"
