#Requires -Version 7.4
# Authors the recipe-reproducible media fixtures under D-047, ratified 2026-08-21.
#
# This is an authoring tool, not a gate and not a product path. It runs only when a
# maintainer runs it, it writes only into the directory it is given, and it never
# touches evidence. The tool it drives is pinned by SHA-256 and refused if the hash
# does not match, the same discipline the comparison recorder applies before it
# executes the inspection authority.
#
# Reproducibility is the point. Under bit-exact flags this build writes no segment
# identifier, no writing-application version, and no wall-clock date, so two runs
# produce byte-identical files; the proof is to run this script twice into different
# directories and compare hashes. The four original fixtures predate this recipe and
# were not authored bit-exactly, so their bytes are not reproducible and the manifest
# says so plainly.
#
# The chapter titles are deliberate. One carries a colon, because a chapter label is
# author-controlled free text and the CLI JSON value grammar is ambiguous between a
# bare label and a language-prefixed label; the fixture carries the hazard so the
# normalizer's refusal to split on it is provable.
[CmdletBinding()]
param(
    [string]$FfmpegPath = 'C:\StaxRip\Apps\FrameServer\AviSynth\ffmpeg.exe',
    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$engRoot = Split-Path -Parent $PSCommandPath
$crossPlatformRoot = Split-Path -Parent $engRoot
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $crossPlatformRoot 'eng\fixtures\media-inspection\media'
}

$expectedToolSha256 = '890af5f546b8b8560d873e12dec223b84caa495c829291a120d0c2a990ff8e23'

if (-not (Test-Path -LiteralPath $FfmpegPath -PathType Leaf)) {
    throw "Fixture-authoring tool not found at $FfmpegPath. D-047 names this build; a different one needs a decision."
}
$actualToolSha256 = (Get-FileHash -LiteralPath $FfmpegPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualToolSha256 -cne $expectedToolSha256) {
    throw "Fixture-authoring tool hash mismatch. Expected $expectedToolSha256, found $actualToolSha256. Refusing to author fixtures with an unpinned tool."
}
Write-Output "tool_sha256=$actualToolSha256"
Write-Output "tool_version=$((& $FfmpegPath -version 2>&1 | Select-Object -First 1))"

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("staxrip-fixture-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $work | Out-Null

try {
    # Inputs are written here rather than committed: they are derivable, and a committed
    # input that no test reads is a file nobody maintains.
    $chapters = @(
        ';FFMETADATA1'
        '[CHAPTER]'
        'TIMEBASE=1/1000'
        'START=0'
        'END=1000'
        'title=Cold Open'
        '[CHAPTER]'
        'TIMEBASE=1/1000'
        'START=1000'
        'END=2000'
        'title=Act One: The Setup'
    ) -join "`n"
    $chapterPath = Join-Path $work 'chapters.ffmeta'
    [System.IO.File]::WriteAllText($chapterPath, $chapters + "`n", [System.Text.UTF8Encoding]::new($false))

    # Subtitle payload byte counts are load bearing: the goldens record StreamSize, and
    # the tests assert those exact values, so changing this text changes the fixture.
    $sdh = @(
        '1'
        '00:00:00,000 --> 00:00:01,000'
        '[door creaks]'
        ''
        '2'
        '00:00:01,000 --> 00:00:02,000'
        '[footsteps approaching]'
        ''
    ) -join "`n"
    $sdhPath = Join-Path $work 'subs-sdh.srt'
    [System.IO.File]::WriteAllText($sdhPath, $sdh, [System.Text.UTF8Encoding]::new($false))

    $commentary = @(
        '1'
        '00:00:00,000 --> 00:00:01,000'
        'We shot this in one take.'
        ''
        '2'
        '00:00:01,000 --> 00:00:02,000'
        'The lighting was tricky.'
        ''
    ) -join "`n"
    $commentaryPath = Join-Path $work 'subs-commentary.srt'
    [System.IO.File]::WriteAllText($commentaryPath, $commentary, [System.Text.UTF8Encoding]::new($false))

    $bitexact = @('-fflags', '+bitexact', '-flags:v', '+bitexact', '-flags:a', '+bitexact')

    # Fixture one: MP4 with chapters and one subtitle track. This container reports
    # subtitle stream size from its own sample tables and emits two Menu tracks for a
    # single chapter list, which is why the payload carries a menu index rather than
    # assuming one menu.
    $mp4 = Join-Path $OutputDirectory 'cfr-h264-aac-chapters.mp4'
    $mp4Args = @(
        '-y', '-nostdin', '-hide_banner', '-loglevel', 'error',
        '-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=24:duration=2',
        '-f', 'lavfi', '-i', 'sine=frequency=440:duration=2',
        '-i', $sdhPath,
        '-i', $chapterPath,
        '-map', '0:v', '-map', '1:a', '-map', '2:s', '-map_metadata', '3',
        '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '40', '-pix_fmt', 'yuv420p',
        '-c:a', 'aac', '-b:a', '32k', '-c:s', 'mov_text',
        '-metadata:s:s:0', 'language=eng', '-metadata:s:s:0', 'title=English SDH'
    ) + $bitexact + @($mp4)
    & $FfmpegPath @mp4Args
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed authoring $mp4" }

    # Fixture two: Matroska with chapters and two subtitle tracks carrying dispositions.
    # The dispositions are authored deliberately even though the facts they carry are
    # not exposed in version 1: the range floor does not report them (unknown P-012),
    # and the fixture is the committed evidence of that gap.
    $mkv = Join-Path $OutputDirectory 'cfr-h264-aac-subtitles.mkv'
    $mkvArgs = @(
        '-y', '-nostdin', '-hide_banner', '-loglevel', 'error',
        '-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=24:duration=2',
        '-f', 'lavfi', '-i', 'sine=frequency=440:duration=2',
        '-i', $sdhPath,
        '-i', $commentaryPath,
        '-i', $chapterPath,
        '-map', '0:v', '-map', '1:a', '-map', '2:s', '-map', '3:s', '-map_metadata', '4',
        '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '40', '-pix_fmt', 'yuv420p',
        '-c:a', 'aac', '-b:a', '32k', '-c:s', 'srt',
        '-metadata:s:s:0', 'language=eng', '-metadata:s:s:0', 'title=English SDH',
        '-disposition:s:0', 'hearing_impaired+default',
        '-metadata:s:s:1', 'language=eng', '-metadata:s:s:1', 'title=Director Commentary',
        '-disposition:s:1', 'comment'
    ) + $bitexact + @($mkv)
    & $FfmpegPath @mkvArgs
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed authoring $mkv" }

    foreach ($authored in @($mp4, $mkv)) {
        $item = Get-Item -LiteralPath $authored
        Write-Output ("authored {0} bytes={1} sha256={2}" -f `
            $item.Name, $item.Length, (Get-FileHash -LiteralPath $authored -Algorithm SHA256).Hash.ToLowerInvariant())
    }
}
finally {
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
}
