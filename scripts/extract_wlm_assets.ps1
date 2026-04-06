[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$MessengerRoot = 'C:\Program Files (x86)\Windows Live\Messenger',
    [string]$ProjectRoot = '',
    [switch]$OnlyMsgres,
    [switch]$SkipImages,
    [switch]$SkipAudio,
    [switch]$SkipFonts,
    [switch]$SkipUiLogic
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent $scriptRoot
}
$ProjectRoot = (Resolve-Path $ProjectRoot).Path

$imagesOut = Join-Path $ProjectRoot 'assets\images\extracted'
$soundsOut = Join-Path $ProjectRoot 'assets\sounds'
$fontsOut = Join-Path $ProjectRoot 'assets\fonts'
$uiLogicOut = Join-Path $ProjectRoot 'assets\ui_logic'

if (-not (Test-Path $MessengerRoot)) {
    throw "Messenger path not found: $MessengerRoot"
}

Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class NativeResources
{
    private const uint LOAD_LIBRARY_AS_DATAFILE = 0x00000002;

    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    private static extern IntPtr LoadLibraryEx(string lpFileName, IntPtr hFile, uint dwFlags);

    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern bool FreeLibrary(IntPtr hModule);

    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern IntPtr FindResourceEx(IntPtr hModule, IntPtr lpType, IntPtr lpName, ushort wLanguage);

    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern uint SizeofResource(IntPtr hModule, IntPtr hResInfo);

    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern IntPtr LoadResource(IntPtr hModule, IntPtr hResInfo);

    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern IntPtr LockResource(IntPtr hResData);

    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern bool EnumResourceTypes(IntPtr hModule, EnumResTypeProc lpEnumFunc, IntPtr lParam);

    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern bool EnumResourceNames(IntPtr hModule, IntPtr lpszType, EnumResNameProc lpEnumFunc, IntPtr lParam);

    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern bool EnumResourceLanguages(IntPtr hModule, IntPtr lpszType, IntPtr lpszName, EnumResLangProc lpEnumFunc, IntPtr lParam);

    public delegate bool EnumResTypeProc(IntPtr hModule, IntPtr lpszType, IntPtr lParam);
    public delegate bool EnumResNameProc(IntPtr hModule, IntPtr lpszType, IntPtr lpszName, IntPtr lParam);
    public delegate bool EnumResLangProc(IntPtr hModule, IntPtr lpszType, IntPtr lpszName, ushort wIDLanguage, IntPtr lParam);

    public static bool IsIntResource(IntPtr ptr)
    {
        long value = ptr.ToInt64();
        return (value >> 16) == 0;
    }

    public static ushort IdFromPtr(IntPtr ptr)
    {
        return (ushort)(ptr.ToInt64() & 0xFFFF);
    }

    public static IntPtr PtrFromId(int id)
    {
        return new IntPtr(id);
    }

    public static IntPtr LoadModule(string path)
    {
        return LoadLibraryEx(path, IntPtr.Zero, LOAD_LIBRARY_AS_DATAFILE);
    }

    public static bool UnloadModule(IntPtr hModule)
    {
        if (hModule == IntPtr.Zero) return false;
        return FreeLibrary(hModule);
    }

    public static List<ushort> EnumTypeIds(IntPtr hModule)
    {
        var ids = new List<ushort>();
        EnumResourceTypes(hModule, (mod, type, param) => {
            if (IsIntResource(type))
            {
                ids.Add(IdFromPtr(type));
            }
            return true;
        }, IntPtr.Zero);
        return ids;
    }

    public static List<ushort> EnumNameIds(IntPtr hModule, int typeId)
    {
        var ids = new List<ushort>();
        IntPtr typePtr = PtrFromId(typeId);
        EnumResourceNames(hModule, typePtr, (mod, type, name, param) => {
            if (IsIntResource(name))
            {
                ids.Add(IdFromPtr(name));
            }
            return true;
        }, IntPtr.Zero);
        return ids;
    }

    public static List<ushort> EnumLangIds(IntPtr hModule, int typeId, int nameId)
    {
        var ids = new List<ushort>();
        IntPtr typePtr = PtrFromId(typeId);
        IntPtr namePtr = PtrFromId(nameId);
        EnumResourceLanguages(hModule, typePtr, namePtr, (mod, type, name, lang, param) => {
            ids.Add(lang);
            return true;
        }, IntPtr.Zero);
        return ids;
    }

    public static byte[] ReadResource(IntPtr hModule, int typeId, int nameId, ushort langId)
    {
        IntPtr typePtr = PtrFromId(typeId);
        IntPtr namePtr = PtrFromId(nameId);

        IntPtr hResInfo = FindResourceEx(hModule, typePtr, namePtr, langId);
        if (hResInfo == IntPtr.Zero) return null;

        uint size = SizeofResource(hModule, hResInfo);
        if (size == 0) return null;

        IntPtr hResData = LoadResource(hModule, hResInfo);
        if (hResData == IntPtr.Zero) return null;

        IntPtr pRes = LockResource(hResData);
        if (pRes == IntPtr.Zero) return null;

        byte[] data = new byte[size];
        Marshal.Copy(pRes, data, 0, (int)size);
        return data;
    }
}
"@

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-Hash {
    param([byte[]]$Bytes)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash($Bytes)
        return ([System.BitConverter]::ToString($hashBytes)).Replace('-', '')
    }
    finally {
        $sha.Dispose()
    }
}

$global:SeenHashes = @{}

function Save-UniqueBytes {
    param(
        [byte[]]$Bytes,
        [string]$BasePathNoExt,
        [string]$Extension
    )

    if ($null -eq $Bytes -or $Bytes.Length -eq 0) {
        return $null
    }

    $hash = Get-Hash -Bytes $Bytes
    if ($global:SeenHashes.ContainsKey($hash)) {
        return $null
    }
    $global:SeenHashes[$hash] = $true

    $candidate = "$BasePathNoExt.$Extension"
    $index = 1
    while (Test-Path $candidate) {
        $candidate = "$BasePathNoExt`_$index.$Extension"
        $index++
    }

    [System.IO.File]::WriteAllBytes($candidate, $Bytes)
    return $candidate
}

function Save-UniqueText {
    param(
        [string]$Text,
        [string]$BasePathNoExt,
        [string]$Extension
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hash = Get-Hash -Bytes $bytes
    if ($global:SeenHashes.ContainsKey($hash)) {
        return $null
    }
    $global:SeenHashes[$hash] = $true

    $candidate = "$BasePathNoExt.$Extension"
    $index = 1
    while (Test-Path $candidate) {
        $candidate = "$BasePathNoExt`_$index.$Extension"
        $index++
    }

    [System.IO.File]::WriteAllText($candidate, $Text, [System.Text.Encoding]::UTF8)
    return $candidate
}

function Try-DecodeTextFromBytes {
    param([byte[]]$Bytes)

    if ($null -eq $Bytes -or $Bytes.Length -lt 4) {
        return $null
    }

    $encodings = @(
        [System.Text.Encoding]::Unicode,
        [System.Text.Encoding]::BigEndianUnicode,
        [System.Text.Encoding]::UTF8,
        [System.Text.Encoding]::ASCII,
        [System.Text.Encoding]::GetEncoding(1252)
    )

    foreach ($encoding in $encodings) {
        try {
            $decoded = $encoding.GetString($Bytes)
            if ([string]::IsNullOrWhiteSpace($decoded)) {
                continue
            }

            # Keep only text that likely contains UI markup/resource mapping.
            if ($decoded -match '(?is)<\?xml|<ui|uifile|<layout|<element|<control|resource\s*=|id\s*=') {
                return $decoded
            }
        }
        catch {
            continue
        }
    }

    return $null
}

function Extract-UiLogicFromDll {
    param(
        [string]$DllPath,
        [string]$DestinationRoot
    )

    $dllName = [System.IO.Path]::GetFileNameWithoutExtension($DllPath)
    $dllOut = Join-Path $DestinationRoot $dllName
    Ensure-Directory -Path $dllOut

    $module = [NativeResources]::LoadModule($DllPath)
    if ($module -eq [IntPtr]::Zero) {
        return [PSCustomObject]@{
            Dll = $DllPath
            Extracted = 0
            Errors = 1
        }
    }

    $extracted = 0
    $errors = 0

    try {
        $typeIds = [NativeResources]::EnumTypeIds($module)
        foreach ($typeId in $typeIds) {
            $nameIds = [NativeResources]::EnumNameIds($module, [int]$typeId)
            foreach ($nameId in $nameIds) {
                $langIds = [NativeResources]::EnumLangIds($module, [int]$typeId, [int]$nameId)
                foreach ($langId in $langIds) {
                    try {
                        $bytes = [NativeResources]::ReadResource($module, [int]$typeId, [int]$nameId, [ushort]$langId)
                        if ($null -eq $bytes -or $bytes.Length -lt 4) {
                            continue
                        }

                        $decoded = Try-DecodeTextFromBytes -Bytes $bytes
                        if ([string]::IsNullOrWhiteSpace($decoded)) {
                            continue
                        }

                        $isUiType = ($typeId -eq 2110)
                        $isXmlLike = ($decoded -match '(?is)<\?xml|<ui|uifile|<layout|<element|<control')
                        if (-not ($isUiType -or $isXmlLike)) {
                            continue
                        }

                        $ext = if ($decoded -match '(?is)<\?xml|<ui|uifile|<layout|<element|<control') { 'xml' } else { 'txt' }
                        $base = Join-Path $dllOut ("t{0}_n{1}_l{2}" -f $typeId, $nameId, $langId)
                        $saved = Save-UniqueText -Text $decoded -BasePathNoExt $base -Extension $ext
                        if ($null -ne $saved) {
                            $extracted++
                        }
                    }
                    catch {
                        $errors++
                    }
                }
            }
        }
    }
    finally {
        [NativeResources]::UnloadModule($module) | Out-Null
    }

    return [PSCustomObject]@{
        Dll = $DllPath
        Extracted = $extracted
        Errors = $errors
    }
}

function Get-Utf16LePatternBytes {
    param([string]$Text)

    $chars = $Text.ToCharArray()
    $list = New-Object System.Collections.Generic.List[byte]
    foreach ($c in $chars) {
        $code = [int][char]$c
        $list.Add([byte]($code -band 0xFF))
        $list.Add([byte](($code -shr 8) -band 0xFF))
    }
    return $list.ToArray()
}

function Find-BytePatternPositions {
    param(
        [byte[]]$Data,
        [byte[]]$Pattern
    )

    $positions = New-Object System.Collections.Generic.List[int]
    if ($null -eq $Data -or $null -eq $Pattern -or $Pattern.Length -eq 0 -or $Data.Length -lt $Pattern.Length) {
        return $positions
    }

    for ($i = 0; $i -le ($Data.Length - $Pattern.Length); $i++) {
        $matched = $true
        for ($j = 0; $j -lt $Pattern.Length; $j++) {
            if ($Data[$i + $j] -ne $Pattern[$j]) {
                $matched = $false
                break
            }
        }
        if ($matched) {
            $positions.Add($i)
        }
    }

    return $positions
}

function Extract-UiLogicByCarvingFromDll {
    param(
        [string]$DllPath,
        [string]$DestinationRoot
    )

    $dllName = [System.IO.Path]::GetFileNameWithoutExtension($DllPath)
    $dllOut = Join-Path $DestinationRoot $dllName
    Ensure-Directory -Path $dllOut

    $bytes = [System.IO.File]::ReadAllBytes($DllPath)
    $length = $bytes.Length
    $maxSlice = 262144

    $asciiMarkers = @('<?xml', '<UIFILE', '<uifile', '<Layout', '<Page', '<Element', '<Control')
    $positions = New-Object System.Collections.Generic.List[object]

    foreach ($marker in $asciiMarkers) {
        $asciiPattern = [System.Text.Encoding]::ASCII.GetBytes($marker)
        foreach ($pos in (Find-BytePatternPositions -Data $bytes -Pattern $asciiPattern)) {
            $positions.Add([PSCustomObject]@{ Pos = $pos; Encoding = 'ASCII' })
        }

        $utf16Pattern = Get-Utf16LePatternBytes -Text $marker
        foreach ($pos in (Find-BytePatternPositions -Data $bytes -Pattern $utf16Pattern)) {
            $positions.Add([PSCustomObject]@{ Pos = $pos; Encoding = 'Unicode' })
        }
    }

    $positions = @($positions | Sort-Object Pos -Unique)
    $extracted = 0

    foreach ($p in $positions) {
        $start = [int]$p.Pos
        if ($start -lt 0 -or $start -ge $length) {
            continue
        }

        $remaining = $length - $start
        $sliceLength = [Math]::Min($maxSlice, $remaining)
        if ($sliceLength -lt 32) {
            continue
        }

        $slice = New-Object byte[] $sliceLength
        [Array]::Copy($bytes, $start, $slice, 0, $sliceLength)

        $decoded = $null
        if ($p.Encoding -eq 'Unicode') {
            $decoded = [System.Text.Encoding]::Unicode.GetString($slice)
        }
        else {
            $decoded = [System.Text.Encoding]::UTF8.GetString($slice)
        }

        if ([string]::IsNullOrWhiteSpace($decoded)) {
            continue
        }

        $decoded = $decoded -replace "`0", ''
        $endIndex = $decoded.IndexOf('>')
        if ($endIndex -lt 0) {
            continue
        }

        if ($decoded -notmatch '(?is)<\?xml|<ui|uifile|<layout|<page|<element|<control') {
            continue
        }

        # Trim very long noisy tails using closing tags when available.
        $cut = $decoded.Length
        foreach ($endTag in @('</UIFILE>', '</uifile>', '</Layout>', '</Page>', '</Element>', '</Control>')) {
            $idx = $decoded.IndexOf($endTag, [System.StringComparison]::OrdinalIgnoreCase)
            if ($idx -ge 0) {
                $candidate = $idx + $endTag.Length
                if ($candidate -lt $cut) {
                    $cut = $candidate
                }
            }
        }
        if ($cut -lt $decoded.Length) {
            $decoded = $decoded.Substring(0, $cut)
        }

        if ($decoded.Length -lt 20) {
            continue
        }

        $base = Join-Path $dllOut ("carved_ui_{0}" -f $start)
        $saved = Save-UniqueText -Text $decoded -BasePathNoExt $base -Extension 'xml'
        if ($null -ne $saved) {
            $extracted++
        }
    }

    return [PSCustomObject]@{
        Dll = $DllPath
        Extracted = $extracted
        Errors = 0
    }
}

function Convert-DibToBmp {
    param([byte[]]$Dib)

    if ($null -eq $Dib -or $Dib.Length -lt 40) {
        return $null
    }

    $biSize = [BitConverter]::ToInt32($Dib, 0)
    if ($biSize -lt 40) {
        return $null
    }

    $bitCount = [BitConverter]::ToInt16($Dib, 14)
    $compression = [BitConverter]::ToInt32($Dib, 16)
    $clrUsed = [BitConverter]::ToInt32($Dib, 32)

    $paletteEntries = 0
    if ($clrUsed -gt 0) {
        $paletteEntries = $clrUsed
    }
    elseif ($bitCount -le 8 -and $bitCount -gt 0) {
        $paletteEntries = [Math]::Pow(2, $bitCount)
    }

    $maskBytes = 0
    if (($compression -eq 3 -or $compression -eq 6) -and $biSize -eq 40) {
        $maskBytes = 12
    }

    $offBits = 14 + $biSize + ([int]$paletteEntries * 4) + $maskBytes
    $minOffBits = 14 + $biSize
    if ($offBits -lt $minOffBits -or $offBits -gt (14 + $Dib.Length)) {
        $offBits = $minOffBits
    }

    $totalSize = 14 + $Dib.Length
    $bmp = New-Object byte[] $totalSize

    $bmp[0] = 0x42
    $bmp[1] = 0x4D

    [BitConverter]::GetBytes([int]$totalSize).CopyTo($bmp, 2)
    [BitConverter]::GetBytes([int]0).CopyTo($bmp, 6)
    [BitConverter]::GetBytes([int]$offBits).CopyTo($bmp, 10)

    [Array]::Copy($Dib, 0, $bmp, 14, $Dib.Length)
    return $bmp
}

function Test-PngSignature {
    param([byte[]]$Bytes)

    if ($null -eq $Bytes -or $Bytes.Length -lt 8) {
        return $false
    }

    $sig = @(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
    for ($i = 0; $i -lt 8; $i++) {
        if ($Bytes[$i] -ne $sig[$i]) {
            return $false
        }
    }
    return $true
}

function Test-WavSignature {
    param([byte[]]$Bytes)

    if ($null -eq $Bytes -or $Bytes.Length -lt 12) {
        return $false
    }

    return (
        $Bytes[0] -eq 0x52 -and # R
        $Bytes[1] -eq 0x49 -and # I
        $Bytes[2] -eq 0x46 -and # F
        $Bytes[3] -eq 0x46 -and # F
        $Bytes[8] -eq 0x57 -and # W
        $Bytes[9] -eq 0x41 -and # A
        $Bytes[10] -eq 0x56 -and # V
        $Bytes[11] -eq 0x45    # E
    )
}

function Extract-WavResourcesFromDll {
    param(
        [string]$DllPath,
        [string]$DestinationRoot
    )

    $dllName = [System.IO.Path]::GetFileNameWithoutExtension($DllPath)
    $module = [NativeResources]::LoadModule($DllPath)
    if ($module -eq [IntPtr]::Zero) {
        return [PSCustomObject]@{
            Dll = $DllPath
            Extracted = 0
            Errors = 1
        }
    }

    $extracted = 0
    $errors = 0

    try {
        $typeIds = [NativeResources]::EnumTypeIds($module)
        foreach ($typeId in $typeIds) {
            $nameIds = [NativeResources]::EnumNameIds($module, [int]$typeId)
            foreach ($nameId in $nameIds) {
                $langIds = [NativeResources]::EnumLangIds($module, [int]$typeId, [int]$nameId)
                foreach ($langId in $langIds) {
                    try {
                        $bytes = [NativeResources]::ReadResource($module, [int]$typeId, [int]$nameId, [ushort]$langId)
                        if ($null -eq $bytes -or $bytes.Length -lt 12) {
                            continue
                        }

                        if (-not (Test-WavSignature -Bytes $bytes)) {
                            continue
                        }

                        $base = Join-Path $DestinationRoot ("{0}_t{1}_n{2}_l{3}" -f $dllName, $typeId, $nameId, $langId)
                        $saved = Save-UniqueBytes -Bytes $bytes -BasePathNoExt $base -Extension 'wav'
                        if ($null -ne $saved) {
                            $extracted++
                        }
                    }
                    catch {
                        $errors++
                    }
                }
            }
        }
    }
    finally {
        [NativeResources]::UnloadModule($module) | Out-Null
    }

    return [PSCustomObject]@{
        Dll = $DllPath
        Extracted = $extracted
        Errors = $errors
    }
}

function Build-IcoFromGroup {
    param(
        [IntPtr]$Module,
        [byte[]]$GroupData,
        [ushort]$LangId
    )

    if ($null -eq $GroupData -or $GroupData.Length -lt 6) {
        return $null
    }

    $count = [BitConverter]::ToUInt16($GroupData, 4)
    if ($count -le 0) {
        return $null
    }

    $entries = @()
    $cursor = 6
    for ($i = 0; $i -lt $count; $i++) {
        if ($cursor + 14 -gt $GroupData.Length) {
            break
        }

        $width = $GroupData[$cursor]
        $height = $GroupData[$cursor + 1]
        $colorCount = $GroupData[$cursor + 2]
        $reserved = $GroupData[$cursor + 3]
        $planes = [BitConverter]::ToUInt16($GroupData, $cursor + 4)
        $bitCount = [BitConverter]::ToUInt16($GroupData, $cursor + 6)
        $bytesInRes = [BitConverter]::ToUInt32($GroupData, $cursor + 8)
        $iconId = [BitConverter]::ToUInt16($GroupData, $cursor + 12)

        $iconBytes = [NativeResources]::ReadResource($Module, 3, [int]$iconId, $LangId)
        if ($null -eq $iconBytes) {
            $langs = [NativeResources]::EnumLangIds($Module, 3, [int]$iconId)
            foreach ($fallbackLang in $langs) {
                $iconBytes = [NativeResources]::ReadResource($Module, 3, [int]$iconId, [ushort]$fallbackLang)
                if ($null -ne $iconBytes) {
                    break
                }
            }
        }

        if ($null -ne $iconBytes -and $iconBytes.Length -gt 0) {
            $entries += [PSCustomObject]@{
                Width = $width
                Height = $height
                ColorCount = $colorCount
                Reserved = $reserved
                Planes = $planes
                BitCount = $bitCount
                Bytes = $iconBytes
                BytesInRes = [uint32]$iconBytes.Length
            }
        }

        $cursor += 14
    }

    if ($entries.Count -eq 0) {
        return $null
    }

    $stream = New-Object System.IO.MemoryStream
    $writer = New-Object System.IO.BinaryWriter($stream)
    try {
        $writer.Write([UInt16]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]$entries.Count)

        $offset = 6 + (16 * $entries.Count)
        foreach ($entry in $entries) {
            $writer.Write([byte]$entry.Width)
            $writer.Write([byte]$entry.Height)
            $writer.Write([byte]$entry.ColorCount)
            $writer.Write([byte]$entry.Reserved)
            $writer.Write([UInt16]$entry.Planes)
            $writer.Write([UInt16]$entry.BitCount)
            $writer.Write([UInt32]$entry.BytesInRes)
            $writer.Write([UInt32]$offset)
            $offset += $entry.Bytes.Length
        }

        foreach ($entry in $entries) {
            $writer.Write($entry.Bytes)
        }

        $writer.Flush()
        return $stream.ToArray()
    }
    finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

function Extract-ImageResourcesFromDll {
    param(
        [string]$DllPath,
        [string]$DestinationRoot
    )

    $dllName = [System.IO.Path]::GetFileNameWithoutExtension($DllPath)
    $dllOut = Join-Path $DestinationRoot $dllName
    Ensure-Directory -Path $dllOut

    $counts = [ordered]@{
        Png = 0
        Bmp = 0
        Ico = 0
        RawImage = 0
        Errors = 0
    }

    $module = [NativeResources]::LoadModule($DllPath)
    if ($module -eq [IntPtr]::Zero) {
        throw "LoadLibraryEx failed: $DllPath"
    }

    try {
        $typeIds = [NativeResources]::EnumTypeIds($module)

        foreach ($typeId in $typeIds) {
            $nameIds = [NativeResources]::EnumNameIds($module, [int]$typeId)
            foreach ($nameId in $nameIds) {
                $langIds = [NativeResources]::EnumLangIds($module, [int]$typeId, [int]$nameId)
                if ($langIds.Count -eq 0) {
                    continue
                }

                foreach ($langId in $langIds) {
                    try {
                        $bytes = [NativeResources]::ReadResource($module, [int]$typeId, [int]$nameId, [ushort]$langId)
                        if ($null -eq $bytes -or $bytes.Length -eq 0) {
                            continue
                        }

                        $base = Join-Path $dllOut ("t{0}_n{1}_l{2}" -f $typeId, $nameId, $langId)

                        if ($typeId -eq 14) {
                            $icoBytes = Build-IcoFromGroup -Module $module -GroupData $bytes -LangId ([ushort]$langId)
                            if ($null -ne $icoBytes) {
                                $saved = Save-UniqueBytes -Bytes $icoBytes -BasePathNoExt $base -Extension 'ico'
                                if ($null -ne $saved) {
                                    $counts.Ico++
                                }
                            }
                            continue
                        }

                        if ($typeId -eq 2) {
                            $bmpBytes = Convert-DibToBmp -Dib $bytes
                            if ($null -ne $bmpBytes) {
                                $saved = Save-UniqueBytes -Bytes $bmpBytes -BasePathNoExt $base -Extension 'bmp'
                                if ($null -ne $saved) {
                                    $counts.Bmp++
                                }
                            }
                            continue
                        }

                        if (Test-PngSignature -Bytes $bytes) {
                            $saved = Save-UniqueBytes -Bytes $bytes -BasePathNoExt $base -Extension 'png'
                            if ($null -ne $saved) {
                                $counts.Png++
                            }
                            continue
                        }

                        if ($bytes.Length -ge 2 -and $bytes[0] -eq 0x42 -and $bytes[1] -eq 0x4D) {
                            $saved = Save-UniqueBytes -Bytes $bytes -BasePathNoExt $base -Extension 'bmp'
                            if ($null -ne $saved) {
                                $counts.Bmp++
                            }
                            continue
                        }

                        if ($bytes.Length -ge 4 -and $bytes[0] -eq 0x00 -and $bytes[1] -eq 0x00 -and $bytes[2] -eq 0x01 -and $bytes[3] -eq 0x00) {
                            $saved = Save-UniqueBytes -Bytes $bytes -BasePathNoExt $base -Extension 'ico'
                            if ($null -ne $saved) {
                                $counts.Ico++
                            }
                            continue
                        }

                        if ($typeId -eq 10) {
                            $saved = Save-UniqueBytes -Bytes $bytes -BasePathNoExt $base -Extension 'bin'
                            if ($null -ne $saved) {
                                $counts.RawImage++
                            }
                        }
                    }
                    catch {
                        $counts.Errors++
                    }
                }
            }
        }
    }
    finally {
        [NativeResources]::UnloadModule($module) | Out-Null
    }

    return [PSCustomObject]@{
        Dll = $DllPath
        Output = $dllOut
        Png = $counts.Png
        Bmp = $counts.Bmp
        Ico = $counts.Ico
        Raw = $counts.RawImage
        Errors = $counts.Errors
    }
}

function Extract-ImagesBySignatureFromDll {
    param(
        [string]$DllPath,
        [string]$DestinationRoot
    )

    $dllName = [System.IO.Path]::GetFileNameWithoutExtension($DllPath)
    $dllOut = Join-Path $DestinationRoot $dllName
    Ensure-Directory -Path $dllOut

    $bytes = [System.IO.File]::ReadAllBytes($DllPath)
    $length = $bytes.Length

    $pngCount = 0
    $bmpCount = 0
    $icoCount = 0

    # Carve PNG streams by locating signature and matching IEND chunk.
    $pngSig = @(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
    $iend = @(0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82)
    for ($i = 0; $i -le ($length - 8); $i++) {
        $isPng = $true
        for ($j = 0; $j -lt 8; $j++) {
            if ($bytes[$i + $j] -ne $pngSig[$j]) {
                $isPng = $false
                break
            }
        }
        if (-not $isPng) {
            continue
        }

        for ($k = $i + 8; $k -le ($length - 8); $k++) {
            if (
                $bytes[$k] -eq $iend[0] -and
                $bytes[$k + 1] -eq $iend[1] -and
                $bytes[$k + 2] -eq $iend[2] -and
                $bytes[$k + 3] -eq $iend[3] -and
                $bytes[$k + 4] -eq $iend[4] -and
                $bytes[$k + 5] -eq $iend[5] -and
                $bytes[$k + 6] -eq $iend[6] -and
                $bytes[$k + 7] -eq $iend[7]
            ) {
                if ($k -ge 8) {
                    $start = $i
                    $end = $k + 8
                    $size = $end - $start
                    if ($size -gt 64 -and $end -le $length) {
                        $slice = New-Object byte[] $size
                        [Array]::Copy($bytes, $start, $slice, 0, $size)
                        $saved = Save-UniqueBytes -Bytes $slice -BasePathNoExt (Join-Path $dllOut ("carved_png_{0}" -f $start)) -Extension 'png'
                        if ($null -ne $saved) {
                            $pngCount++
                        }
                        $i = $end - 1
                    }
                }
                break
            }
        }
    }

    # Carve BMP by BM header and declared file size.
    for ($i = 0; $i -le ($length - 14); $i++) {
        if ($bytes[$i] -eq 0x42 -and $bytes[$i + 1] -eq 0x4D) {
            $size = [BitConverter]::ToInt32($bytes, $i + 2)
            if ($size -gt 54 -and ($i + $size) -le $length) {
                $slice = New-Object byte[] $size
                [Array]::Copy($bytes, $i, $slice, 0, $size)
                $saved = Save-UniqueBytes -Bytes $slice -BasePathNoExt (Join-Path $dllOut ("carved_bmp_{0}" -f $i)) -Extension 'bmp'
                if ($null -ne $saved) {
                    $bmpCount++
                }
                $i = $i + $size - 1
            }
        }
    }

    # Carve ICO by header and directory entries.
    for ($i = 0; $i -le ($length - 6); $i++) {
        if ($bytes[$i] -eq 0x00 -and $bytes[$i + 1] -eq 0x00 -and $bytes[$i + 2] -eq 0x01 -and $bytes[$i + 3] -eq 0x00) {
            $count = [BitConverter]::ToUInt16($bytes, $i + 4)
            if ($count -lt 1 -or $count -gt 128) {
                continue
            }

            $dirStart = $i + 6
            $dirSize = $count * 16
            if (($dirStart + $dirSize) -gt $length) {
                continue
            }

            $maxEnd = 0
            $valid = $true
            for ($e = 0; $e -lt $count; $e++) {
                $entry = $dirStart + ($e * 16)
                $bytesInRes = [BitConverter]::ToUInt32($bytes, $entry + 8)
                $offset = [BitConverter]::ToUInt32($bytes, $entry + 12)
                if ($bytesInRes -le 0 -or $offset -lt (6 + $dirSize)) {
                    $valid = $false
                    break
                }
                $end = $offset + $bytesInRes
                if ($end -gt $maxEnd) {
                    $maxEnd = $end
                }
            }

            if ($valid -and $maxEnd -gt (6 + $dirSize) -and ($i + $maxEnd) -le $length) {
                $size = [int]$maxEnd
                $slice = New-Object byte[] $size
                [Array]::Copy($bytes, $i, $slice, 0, $size)
                $saved = Save-UniqueBytes -Bytes $slice -BasePathNoExt (Join-Path $dllOut ("carved_ico_{0}" -f $i)) -Extension 'ico'
                if ($null -ne $saved) {
                    $icoCount++
                }
                $i = $i + $size - 1
            }
        }
    }

    return [PSCustomObject]@{
        Dll = $DllPath
        Output = $dllOut
        Png = $pngCount
        Bmp = $bmpCount
        Ico = $icoCount
        Raw = 0
        Errors = 0
    }
}

function Copy-WlmSounds {
    param(
        [string]$SourceRoot,
        [string]$DestinationRoot
    )

    Ensure-Directory -Path $DestinationRoot

    $allFiles = @(
        Get-ChildItem -Path $SourceRoot -Recurse -File -Force -ErrorAction SilentlyContinue
    )
    $allAudioFiles = @(
        $allFiles | Where-Object {
            $_.Extension -and (
                $_.Extension.Equals('.wav', [System.StringComparison]::OrdinalIgnoreCase) -or
                $_.Extension.Equals('.wave', [System.StringComparison]::OrdinalIgnoreCase) -or
                $_.Extension.Equals('.wma', [System.StringComparison]::OrdinalIgnoreCase)
            )
        }
    )
    $copied = 0

    foreach ($audioFile in $allAudioFiles) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($audioFile.Name)
        $ext = $audioFile.Extension
        $dest = Join-Path $DestinationRoot $audioFile.Name
        $index = 1
        while (Test-Path $dest) {
            $dest = Join-Path $DestinationRoot ("{0}_{1}{2}" -f $baseName, $index, $ext)
            $index++
        }

        if ($PSCmdlet.ShouldProcess($dest, "Copy $($audioFile.FullName)")) {
            Copy-Item -Path $audioFile.FullName -Destination $dest -Force
            $copied++
        }
    }

    return [PSCustomObject]@{
        Found = $allAudioFiles.Count
        Copied = $copied
        Destination = $DestinationRoot
    }
}

function Copy-SegoeFonts {
    param(
        [string]$DestinationRoot,
        [string]$FontRoot = 'C:\Windows\Fonts'
    )

    Ensure-Directory -Path $DestinationRoot

    $patterns = @('segoe*.ttf', 'segoe*.ttc', 'segui*.ttf', 'segui*.ttc')
    $fontFiles = @(
        foreach ($pattern in $patterns) {
            Get-ChildItem -Path $FontRoot -File -Filter $pattern -ErrorAction SilentlyContinue
        }
    )

    $fontFiles = @($fontFiles | Sort-Object FullName -Unique)
    $copied = 0

    foreach ($font in $fontFiles) {
        $dest = Join-Path $DestinationRoot $font.Name
        if ($PSCmdlet.ShouldProcess($dest, "Copy $($font.FullName)")) {
            Copy-Item -Path $font.FullName -Destination $dest -Force
            $copied++
        }
    }

    return [PSCustomObject]@{
        Found = $fontFiles.Count
        Copied = $copied
        Destination = $DestinationRoot
    }
}

if (-not $SkipImages) {
    Ensure-Directory -Path $imagesOut
}
if (-not $SkipAudio) {
    Ensure-Directory -Path $soundsOut
}
if (-not $SkipFonts) {
    Ensure-Directory -Path $fontsOut
}
if (-not $SkipUiLogic) {
    Ensure-Directory -Path $uiLogicOut
}

$dlls = @()
if (-not $SkipImages) {
    if ($OnlyMsgres) {
        $msgres = Join-Path $MessengerRoot 'msgres.dll'
        if (-not (Test-Path $msgres)) {
            $fallback = Get-ChildItem -Path $MessengerRoot -Recurse -File -Filter 'msgres.dll' -ErrorAction SilentlyContinue |
                Select-Object -First 1 -ExpandProperty FullName
            if ([string]::IsNullOrWhiteSpace($fallback)) {
                throw "msgres.dll not found under: $MessengerRoot"
            }
            $msgres = $fallback
        }
        $dlls = @($msgres)
    }
    else {
        $dlls = @(
            Get-ChildItem -Path $MessengerRoot -File -Filter '*.dll' | Select-Object -ExpandProperty FullName
        )
        if ($dlls.Count -eq 0) {
            throw "No DLL files found under $MessengerRoot"
        }
    }
}

$results = @()
if (-not $SkipImages) {
    foreach ($dll in $dlls) {
        Write-Host "Extracting image resources from $dll ..."
        $resourceResult = Extract-ImageResourcesFromDll -DllPath $dll -DestinationRoot $imagesOut
        $carveResult = Extract-ImagesBySignatureFromDll -DllPath $dll -DestinationRoot $imagesOut

        $results += [PSCustomObject]@{
            Dll = $dll
            Output = $resourceResult.Output
            Png = ($resourceResult.Png + $carveResult.Png)
            Bmp = ($resourceResult.Bmp + $carveResult.Bmp)
            Ico = ($resourceResult.Ico + $carveResult.Ico)
            Raw = $resourceResult.Raw
            Errors = ($resourceResult.Errors + $carveResult.Errors)
        }
    }
}

$soundResult = $null
$dllWavResults = @()
if (-not $SkipAudio) {
    Write-Host 'Copying original audio files (.wav/.wave/.wma) ...'
    $soundResult = Copy-WlmSounds -SourceRoot $MessengerRoot -DestinationRoot $soundsOut

    if ($soundResult.Found -eq 0) {
        Write-Host 'No loose WAV files found. Trying embedded WAV resource extraction from DLLs ...'
        $audioDlls = @(
            Get-ChildItem -Path $MessengerRoot -File -Filter '*.dll' -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty FullName
        )

        foreach ($dll in $audioDlls) {
            $dllWavResults += Extract-WavResourcesFromDll -DllPath $dll -DestinationRoot $soundsOut
        }
    }
}

$fontResult = $null
if (-not $SkipFonts) {
    Write-Host 'Copying Segoe font files ...'
    $fontResult = Copy-SegoeFonts -DestinationRoot $fontsOut
}

$uiLogicResults = @()
if (-not $SkipUiLogic) {
    $uiDllNames = @('msgsres.dll', 'uxcore.dll')
    $uiDlls = @()
    foreach ($uiDllName in $uiDllNames) {
        $matches = @(
            Get-ChildItem -Path $MessengerRoot -Recurse -File -Filter $uiDllName -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty FullName
        )
        if ($matches.Count -gt 0) {
            $uiDlls += $matches
        }
    }
    $uiDlls = @($uiDlls | Sort-Object -Unique)

    if ($uiDlls.Count -eq 0) {
        Write-Host 'UI logic extraction skipped: msgsres.dll and uxcore.dll were not found.'
    }
    else {
        foreach ($uiDll in $uiDlls) {
            Write-Host "Extracting UI logic resources from $uiDll ..."
            $resourceUi = Extract-UiLogicFromDll -DllPath $uiDll -DestinationRoot $uiLogicOut
            $carvedUi = Extract-UiLogicByCarvingFromDll -DllPath $uiDll -DestinationRoot $uiLogicOut

            $uiLogicResults += [PSCustomObject]@{
                Dll = $uiDll
                Extracted = ($resourceUi.Extracted + $carvedUi.Extracted)
                Errors = ($resourceUi.Errors + $carvedUi.Errors)
            }
        }
    }
}

Write-Host ''
Write-Host 'Extraction summary:'
if ($results.Count -gt 0) {
    $results | Format-Table Dll, Png, Bmp, Ico, Raw, Errors -AutoSize
}
if ($null -ne $soundResult) {
    Write-Host ("Audio files found: {0}, copied: {1}, destination: {2}" -f $soundResult.Found, $soundResult.Copied, $soundResult.Destination)
}
if ($dllWavResults.Count -gt 0) {
    $totalEmbedded = ($dllWavResults | Measure-Object -Property Extracted -Sum).Sum
    Write-Host ("Embedded WAV resources extracted from DLLs: {0}" -f $totalEmbedded)
}
if ($null -ne $fontResult) {
    Write-Host ("Segoe fonts found: {0}, copied: {1}, destination: {2}" -f $fontResult.Found, $fontResult.Copied, $fontResult.Destination)
}
if ($uiLogicResults.Count -gt 0) {
    $uiTotal = ($uiLogicResults | Measure-Object -Property Extracted -Sum).Sum
    $uiErrors = ($uiLogicResults | Measure-Object -Property Errors -Sum).Sum
    Write-Host ("UI logic resources extracted: {0}, errors: {1}, destination: {2}" -f $uiTotal, $uiErrors, $uiLogicOut)
}
