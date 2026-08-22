#Requires -Version 7.4
# Recorder: the Windows comparison the S-PORT-02 exit criteria require. Runs both
# authorities over the committed fixture corpus and records per-fact agreement: the
# installed product's MediaInfo.dll, read with exactly the parameter names the product
# reads, against the pinned MediaInfo CLI in JSON mode, the ratified portable primary.
# This is a recorder, not a gate: it produces committed data with provenance, and
# divergences are findings to record, never failures to hide. The CLI is hash-verified
# against the fixture manifest before it executes; the installed dll is outside the
# repository's control, so its identity is recorded rather than pinned.
[CmdletBinding()]
param(
    [string]$DllPath = 'C:\StaxRip\Apps\Support\MediaInfo.NET\MediaInfo.dll',
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$engRoot = Split-Path -Parent $PSCommandPath
$crossPlatformRoot = Split-Path -Parent $engRoot
$repositoryRoot = Split-Path -Parent $crossPlatformRoot
$fixtureRoot = Join-Path $crossPlatformRoot 'eng\fixtures\media-inspection'
$mediaRoot = Join-Path $fixtureRoot 'media'
if (-not $OutputPath) {
    $OutputPath = Join-Path (Split-Path -Parent $repositoryRoot) 'Docs\Verification\S-PORT-02\comparison-record.md'
}
$OutputPath = Join-Path $repositoryRoot 'Docs\Verification\S-PORT-02\comparison-record.md'

# Resolve and hash-verify the pinned CLI against the committed manifest.
$cliCandidates = @(Get-ChildItem (Join-Path $crossPlatformRoot 'artifacts\tools') -Recurse -Filter 'MediaInfo.exe' -ErrorAction SilentlyContinue)
if ($cliCandidates.Count -lt 1) { throw 'Pinned MediaInfo CLI not found under artifacts/tools.' }
$cliPath = $cliCandidates[0].FullName
$cliHash = (Get-FileHash -LiteralPath $cliPath -Algorithm SHA256).Hash.ToLowerInvariant()
$manifestText = Get-Content -Raw (Join-Path $fixtureRoot 'MANIFEST.md')
if (-not $manifestText.ToLowerInvariant().Contains($cliHash)) {
    throw "CLI hash $cliHash is not recorded in the fixture manifest; refusing to execute an unverified tool."
}

if (-not (Test-Path -LiteralPath $DllPath -PathType Leaf)) {
    throw "Installed MediaInfo.dll not found at $DllPath."
}
$dllHash = (Get-FileHash -LiteralPath $DllPath -Algorithm SHA256).Hash.ToLowerInvariant()

# The product's exact native surface, replicated: explicit load of the exact dll,
# then the same wide-character Get calls with the same parameter names.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class MediaInfoNative
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern IntPtr LoadLibraryW(string path);

    [DllImport("MediaInfo.dll")]
    public static extern IntPtr MediaInfo_New();

    [DllImport("MediaInfo.dll", CharSet = CharSet.Unicode)]
    public static extern int MediaInfo_Open(IntPtr handle, string fileName);

    [DllImport("MediaInfo.dll")]
    public static extern int MediaInfo_Close(IntPtr handle);

    [DllImport("MediaInfo.dll")]
    public static extern void MediaInfo_Delete(IntPtr handle);

    [DllImport("MediaInfo.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr MediaInfo_Get(IntPtr handle, int streamKind, int streamNumber, string parameter, int infoKind, int searchKind);

    [DllImport("MediaInfo.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr MediaInfo_Option(IntPtr handle, string option, string value);

    [DllImport("MediaInfo.dll")]
    public static extern int MediaInfo_Count_Get(IntPtr handle, int streamKind, int streamNumber);
}
'@

if ([MediaInfoNative]::LoadLibraryW($DllPath) -eq [IntPtr]::Zero) {
    throw "LoadLibraryW failed for $DllPath."
}

function Get-DllValue {
    param([IntPtr]$Handle, [int]$Kind, [int]$Stream, [string]$Parameter)
    return [System.Runtime.InteropServices.Marshal]::PtrToStringUni(
        [MediaInfoNative]::MediaInfo_Get($Handle, $Kind, $Stream, $Parameter, 1, 0))
}

$dllVersion = [System.Runtime.InteropServices.Marshal]::PtrToStringUni(
    [MediaInfoNative]::MediaInfo_Option([IntPtr]::Zero, 'Info_Version', ''))

# The agreed-facts parameter inventory, per section, in the product's spellings. The
# JSON field name differs where the CLI serializer rewrites characters.
$factSections = @(
    @{ Kind = 0; KindName = 'General'; JsonType = 'General'; Parameters = @(
        @{ Dll = 'Format' }, @{ Dll = 'Duration' }, @{ Dll = 'FileSize' }, @{ Dll = 'Title' }) },
    @{ Kind = 1; KindName = 'Video'; JsonType = 'Video'; Parameters = @(
        @{ Dll = 'Format' }, @{ Dll = 'Format_Profile' }, @{ Dll = 'Width' }, @{ Dll = 'Height' },
        @{ Dll = 'PixelAspectRatio' }, @{ Dll = 'DisplayAspectRatio' }, @{ Dll = 'FrameRate' },
        @{ Dll = 'FrameRate_Mode' }, @{ Dll = 'FrameCount' }, @{ Dll = 'BitDepth' },
        @{ Dll = 'ChromaSubsampling' }, @{ Dll = 'ChromaSubsampling_Position' },
        @{ Dll = 'ColorSpace' }, @{ Dll = 'ScanType' }, @{ Dll = 'ScanOrder' },
        @{ Dll = 'Rotation' }, @{ Dll = 'StreamSize' }, @{ Dll = 'BitRate' }, @{ Dll = 'Language' },
        @{ Dll = 'transfer_characteristics' }, @{ Dll = 'colour_primaries' },
        @{ Dll = 'matrix_coefficients' }, @{ Dll = 'colour_range' },
        @{ Dll = 'MasteringDisplay_ColorPrimaries' }, @{ Dll = 'MasteringDisplay_Luminance' },
        @{ Dll = 'MaxCLL' }, @{ Dll = 'MaxFALL' },
        @{ Dll = 'HDR_Format_Commercial' }, @{ Dll = 'HDR_Format/String'; Json = 'HDR_Format_String' }) },
    @{ Kind = 2; KindName = 'Audio'; JsonType = 'Audio'; Parameters = @(
        @{ Dll = 'Format' }, @{ Dll = 'Format_Profile' },
        @{ Dll = 'Channel(s)'; Json = 'Channels' }, @{ Dll = 'ChannelLayout' },
        @{ Dll = 'SamplingRate' }, @{ Dll = 'BitDepth' }, @{ Dll = 'BitRate' },
        @{ Dll = 'Language' }, @{ Dll = 'Title' }, @{ Dll = 'Default' }, @{ Dll = 'Forced' },
        @{ Dll = 'Video_Delay' }, @{ Dll = 'Compression_Mode' }) },
    # Subtitle and menu sections joined the recorder on 2026-08-22, when the corpus
    # first carried tracks of either kind. Comparing zero facts over a section the
    # payload exposes would have been a silent coverage hole in this record.
    @{ Kind = 3; KindName = 'Text'; JsonType = 'Text'; Parameters = @(
        @{ Dll = 'Format' }, @{ Dll = 'Codec/String'; Json = 'Codec_String' },
        @{ Dll = 'Language' }, @{ Dll = 'Title' }, @{ Dll = 'Default' }, @{ Dll = 'Forced' },
        @{ Dll = 'StreamSize' }, @{ Dll = 'ServiceKind' },
        @{ Dll = 'Commentary' }, @{ Dll = 'HearingImpaired' }) },
    @{ Kind = 4; KindName = 'Menu'; JsonType = 'Menu'; Parameters = @(
        @{ Dll = 'Chapters_Pos_Begin' }, @{ Dll = 'Chapters_Pos_End' }) }
)

$mediaFiles = @('cfr-h264-aac.mp4', 'cfr-ffv1-10bit-pcm.mkv', 'cfr-vp9-opus.webm', 'vfr-ffv1.mkv', 'cfr-h264-aac-chapters.mp4', 'cfr-h264-aac-subtitles.mkv')
$rows = [System.Collections.Generic.List[object]]::new()
$counts = [ordered]@{ equal = 0; 'absent-both' = 0; 'absent-cli' = 0; 'absent-dll' = 0; divergent = 0 }

foreach ($mediaName in $mediaFiles) {
    $mediaPath = Join-Path $mediaRoot $mediaName

    # CLI side: the recorded invocation, run from the media directory with the
    # relative name, exactly as the goldens were captured.
    Push-Location $mediaRoot
    try {
        $cliJsonText = & $cliPath --Output=JSON $mediaName
    }
    finally {
        Pop-Location
    }
    $cliJson = ($cliJsonText -join "`n") | ConvertFrom-Json
    $cliTracks = @($cliJson.media.track)

    # Dll side: open once per file.
    $handle = [MediaInfoNative]::MediaInfo_New()
    try {
        if ([MediaInfoNative]::MediaInfo_Open($handle, $mediaPath) -ne 1) {
            throw "MediaInfo_Open failed for $mediaName."
        }

        foreach ($section in $factSections) {
            $streamCount = [MediaInfoNative]::MediaInfo_Count_Get($handle, $section.Kind, -1)
            if ($section.Kind -eq 0) { $streamCount = 1 }
            $jsonStreams = @($cliTracks | Where-Object { $_.'@type' -ceq $section.JsonType })

            for ($stream = 0; $stream -lt $streamCount; $stream++) {
                $jsonStream = if ($stream -lt $jsonStreams.Count) { $jsonStreams[$stream] } else { $null }

                foreach ($parameter in $section.Parameters) {
                    $dllValue = Get-DllValue -Handle $handle -Kind $section.Kind -Stream $stream -Parameter $parameter.Dll
                    $jsonName = if ($parameter.ContainsKey('Json')) { $parameter.Json } else { $parameter.Dll }
                    $cliValue = $null
                    if ($null -ne $jsonStream -and $null -ne ($jsonStream.PSObject.Properties[$jsonName])) {
                        $cliValue = [string]$jsonStream.$jsonName
                    }

                    $dllAbsent = [string]::IsNullOrEmpty($dllValue)
                    $cliAbsent = [string]::IsNullOrEmpty($cliValue)
                    $verdict =
                        if ($dllAbsent -and $cliAbsent) { 'absent-both' }
                        elseif ($cliAbsent) { 'absent-cli' }
                        elseif ($dllAbsent) { 'absent-dll' }
                        elseif ($dllValue -ceq $cliValue) { 'equal' }
                        else { 'divergent' }
                    $counts[$verdict] = $counts[$verdict] + 1

                    if ($verdict -ne 'absent-both') {
                        $rows.Add([pscustomobject]@{
                            File = $mediaName
                            Section = $section.KindName
                            Stream = $stream
                            Parameter = $parameter.Dll
                            Verdict = $verdict
                            Dll = if ($dllAbsent) { '' } else { $dllValue }
                            Cli = if ($cliAbsent) { '' } else { $cliValue }
                        })
                    }
                }
            }
        }
    }
    finally {
        [void][MediaInfoNative]::MediaInfo_Close($handle)
        [MediaInfoNative]::MediaInfo_Delete($handle)
    }
}

# Compose the committed record.
$lines = [System.Collections.Generic.List[string]]::new()
[void]$lines.Add('# S-PORT-02 Windows Comparison Record')
[void]$lines.Add('')
[void]$lines.Add("Date: $([DateTime]::UtcNow.ToString('yyyy-MM-dd')). Recorded by Record-MediaComparison.ps1 over the four")
[void]$lines.Add('committed media fixtures, per the comparison protocol in the agreed-facts list.')
[void]$lines.Add('')
[void]$lines.Add('## Provenance')
[void]$lines.Add('')
[void]$lines.Add("- Portable primary: pinned MediaInfo CLI, sha256 ``$cliHash``, verified against the")
[void]$lines.Add('  fixture manifest before execution, invoked exactly as the goldens were captured.')
[void]$lines.Add("- Windows authority: the installed product''s library, ``$dllVersion``,")
[void]$lines.Add("  sha256 ``$dllHash``, read through the same native calls and parameter names the")
[void]$lines.Add('  product source reads. The installed library is outside repository control; its')
[void]$lines.Add('  identity is recorded here, not pinned.')
[void]$lines.Add('')
[void]$lines.Add('## Summary')
[void]$lines.Add('')
[void]$lines.Add('| Verdict | Count |')
[void]$lines.Add('|---|---|')
foreach ($key in $counts.Keys) {
    [void]$lines.Add("| $key | $($counts[$key]) |")
}
[void]$lines.Add('')
[void]$lines.Add('`absent-both` pairs are counted but not listed: a fact absent from both')
[void]$lines.Add('authorities on a fixture agrees by absence. `absent-cli`, `absent-dll`, and')
[void]$lines.Add('`divergent` rows are the findings this record exists to carry.')
[void]$lines.Add('')
[void]$lines.Add('## Non-equal rows')
[void]$lines.Add('')
[void]$lines.Add('| File | Section | Stream | Parameter | Verdict | Product library | Pinned CLI |')
[void]$lines.Add('|---|---|---|---|---|---|---|')
foreach ($row in $rows | Where-Object { $_.Verdict -ne 'equal' }) {
    [void]$lines.Add("| $($row.File) | $($row.Section) | $($row.Stream) | $($row.Parameter) | $($row.Verdict) | $($row.Dll) | $($row.Cli) |")
}
[void]$lines.Add('')
[void]$lines.Add('## Equal rows, count per file')
[void]$lines.Add('')
[void]$lines.Add('| File | Equal facts |')
[void]$lines.Add('|---|---|')
foreach ($group in ($rows | Where-Object { $_.Verdict -eq 'equal' } | Group-Object File)) {
    [void]$lines.Add("| $($group.Name) | $($group.Count) |")
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
[System.IO.File]::WriteAllText($OutputPath, (($lines -join "`n") + "`n"))
Write-Output "RECORDED $OutputPath"
Write-Output ("counts: " + (($counts.Keys | ForEach-Object { "$_=$($counts[$_])" }) -join ' '))
