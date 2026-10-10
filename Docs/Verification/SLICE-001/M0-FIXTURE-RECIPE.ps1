param(
    [Parameter(Mandatory)]
    [string] $FfmpegPath,

    [Parameter(Mandatory)]
    [string] $FixtureRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# This evidence recipe is intentionally fail-closed. Inspect it before use. It
# creates only a fresh, empty Source/obj/ProjectCheckFixtures directory.
$expectedRunnerSha256 = "DB6DD81183FE57D22E03B911EC9A30A2FD7C40542E97743615355A6FB44F458F"
$expectedFfmpegSha256 = "D42F8E3B267045FE82AAD4D2617324C7E0A28E8016BF7BA3B621F5096FEF13CC"

$runnerPath = [Environment]::ProcessPath
if ([string]::IsNullOrWhiteSpace($runnerPath) -or -not [IO.File]::Exists($runnerPath)) {
    throw "The PowerShell runner executable cannot be resolved."
}

$runnerSha256 = (Get-FileHash -LiteralPath $runnerPath -Algorithm SHA256).Hash
if ($runnerSha256 -ne $expectedRunnerSha256) {
    throw "The PowerShell runner does not match the evidence manifest."
}

$ffmpegFullPath = [IO.Path]::GetFullPath($FfmpegPath)
if (-not [IO.File]::Exists($ffmpegFullPath)) {
    throw "The FFmpeg executable is unavailable."
}

$ffmpegSha256 = (Get-FileHash -LiteralPath $ffmpegFullPath -Algorithm SHA256).Hash
if ($ffmpegSha256 -ne $expectedFfmpegSha256) {
    throw "The FFmpeg executable does not match the evidence manifest."
}

$fixtureRootFullPath = [IO.Path]::GetFullPath($FixtureRoot)
$fixtureParent = [IO.Path]::GetDirectoryName($fixtureRootFullPath)
$fixtureGrandparent = [IO.Path]::GetDirectoryName($fixtureParent)
if ([IO.Path]::GetFileName($fixtureRootFullPath) -ne "ProjectCheckFixtures" -or
    [IO.Path]::GetFileName($fixtureParent) -ne "obj" -or
    [IO.Path]::GetFileName($fixtureGrandparent) -ne "Source") {
    throw "FixtureRoot must end with Source/obj/ProjectCheckFixtures."
}

if ([IO.Directory]::Exists($fixtureRootFullPath)) {
    $rootItem = Get-Item -LiteralPath $fixtureRootFullPath -Force
    if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "FixtureRoot must not be a link or reparse point."
    }

    if (@(Get-ChildItem -LiteralPath $fixtureRootFullPath -Force).Count -ne 0) {
        throw "FixtureRoot must be empty. This recipe does not overwrite files."
    }
}
else {
    [void] [IO.Directory]::CreateDirectory($fixtureRootFullPath)
}

function Write-Utf8LfFixture {
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string[]] $Lines
    )

    $content = [string]::Join("`n", $Lines) + "`n"
    [IO.File]::WriteAllBytes($Path, [Text.UTF8Encoding]::new($false).GetBytes($content))
}

Write-Utf8LfFixture -Path (Join-Path $fixtureRootFullPath "FX-AVS-01.avs") -Lines @(
    'BlankClip(width=320, height=180, length=120, fps=24000, fps_denominator=1001, pixel_type="YV12", color=$000000).KillAudio()'
)

Write-Utf8LfFixture -Path (Join-Path $fixtureRootFullPath "FX-VPY-01.vpy") -Lines @(
    'import vapoursynth as vs',
    '',
    'core = vs.core',
    'clip = core.std.BlankClip(',
    '    width=320,',
    '    height=180,',
    '    length=120,',
    '    fpsnum=24000,',
    '    fpsden=1001,',
    '    format=vs.YUV420P8,',
    '    color=[16, 128, 128],',
    ')',
    'clip.set_output()'
)

Write-Utf8LfFixture -Path (Join-Path $fixtureRootFullPath "FX-MKV-01.source.srt") -Lines @(
    '1',
    '00:00:00,250 --> 00:00:01,250',
    'Synthetic fixture subtitle one.',
    '',
    '2',
    '00:00:01,500 --> 00:00:02,750',
    'Synthetic fixture subtitle two.'
)

$mp4Args = @(
    "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
    "-f", "lavfi", "-i", "testsrc2=size=640x360:rate=30:duration=3",
    "-f", "lavfi", "-i", "sine=frequency=1000:sample_rate=48000:duration=3",
    "-map", "0:v:0", "-map", "1:a:0",
    "-map_metadata", "-1", "-map_chapters", "-1",
    "-c:v", "libx264", "-preset", "medium", "-crf", "23",
    "-pix_fmt", "yuv420p", "-r", "30", "-fps_mode", "cfr",
    "-frames:v", "90", "-g", "60", "-keyint_min", "60", "-sc_threshold", "0",
    "-x264-params", "threads=1:lookahead_threads=1:sliced_threads=0:scenecut=0:open_gop=0",
    "-c:a", "aac", "-b:a", "96k", "-ar", "48000", "-ac", "1",
    "-t", "3", "-fflags", "+bitexact", "-flags:v", "+bitexact", "-flags:a", "+bitexact",
    "-movflags", "+faststart",
    "-metadata", "title=", "-metadata", "artist=", "-metadata", "comment=",
    "FX-MP4-01.mp4"
)

$mkvArgs = @(
    "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
    "-i", "FX-MP4-01.mp4",
    "-f", "lavfi", "-i", "sine=frequency=880:sample_rate=48000:duration=3",
    "-f", "srt", "-i", "FX-MKV-01.source.srt",
    "-map", "0:v:0", "-map", "0:a:0", "-map", "1:a:0", "-map", "2:s:0",
    "-map_metadata", "-1", "-map_chapters", "-1",
    "-c:v", "copy", "-c:a:0", "copy", "-c:a:1", "aac", "-b:a:1", "96k",
    "-ar:a:1", "48000", "-ac:a:1", "1", "-c:s", "srt",
    "-t", "3", "-fflags", "+bitexact", "-flags:a:1", "+bitexact",
    "-metadata", "title=", "-metadata", "artist=", "-metadata", "comment=",
    "-metadata:s:a:0", "title=", "-metadata:s:a:1", "title=", "-metadata:s:s:0", "title=",
    "-disposition:a:0", "default", "-disposition:a:1", "0", "-disposition:s:0", "0",
    "FX-MKV-01.mkv"
)

Push-Location -LiteralPath $fixtureRootFullPath
try {
    & $ffmpegFullPath @mp4Args
    if ($LASTEXITCODE -ne 0) {
        throw "FX-MP4-01 generation failed with exit code $LASTEXITCODE."
    }

    & $ffmpegFullPath @mkvArgs
    if ($LASTEXITCODE -ne 0) {
        throw "FX-MKV-01 generation failed with exit code $LASTEXITCODE."
    }

    [byte[]] $malformedMp4 = @(
        0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70,
        0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00,
        0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32,
        0x00, 0x00, 0x00, 0x40, 0x6D, 0x64, 0x61, 0x74,
        0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x11, 0x22, 0x33
    )
    [IO.File]::WriteAllBytes((Join-Path $fixtureRootFullPath "FX-BAD-01.mp4"), $malformedMp4)
}
finally {
    Pop-Location
}

$expectedArtifacts = [ordered] @{
    "FX-AVS-01.avs" = @{ Length = 124; Sha256 = "897C467DFC7F00A1F76A01710607CEF3C7A871213560E03115B282DAB7B0AF5C" }
    "FX-VPY-01.vpy" = @{ Length = 220; Sha256 = "A7298D625B8E4697276B3CAE11FCBADE90758A8BD622FD62B3FB7B36FD8A2C23" }
    "FX-MKV-01.source.srt" = @{ Length = 129; Sha256 = "4FF6984BF57243DE4377287F140B79C53B26A90E7A7F6027DE92D416B5E393C0" }
    "FX-MP4-01.mp4" = @{ Length = 343971; Sha256 = "00790155EED0FF25C01857DFB5CDB7FD3927F5EC8D7A4E4AC88A90D562A1EDA4" }
    "FX-MKV-01.mkv" = @{ Length = 379606; Sha256 = "6261F4042942C75FCE1019AE0664AFA6E77273150AE9537321E69FDE3DC27035" }
    "FX-BAD-01.mp4" = @{ Length = 40; Sha256 = "45DA0DDE9CB0460106456A0202A30AE526982565A6E39ADD2AE740F87682DE43" }
}

$actualNames = @(Get-ChildItem -LiteralPath $fixtureRootFullPath -File | Sort-Object Name | ForEach-Object Name)
$expectedNames = @($expectedArtifacts.Keys | Sort-Object)
if ([string]::Join("`n", $actualNames) -cne [string]::Join("`n", $expectedNames)) {
    throw "The generated artifact set differs from the six-file evidence contract."
}

foreach ($entry in $expectedArtifacts.GetEnumerator()) {
    $path = Join-Path $fixtureRootFullPath $entry.Key
    $item = Get-Item -LiteralPath $path
    $sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if ($item.Length -ne $entry.Value.Length -or $sha256 -ne $entry.Value.Sha256) {
        throw "Generated bytes differ for $($entry.Key)."
    }
}

"PASS fixture-recipe artifacts=6 toolchain=pinned hashes=matched"
