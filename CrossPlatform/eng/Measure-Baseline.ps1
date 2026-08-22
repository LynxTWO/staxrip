#Requires -Version 7.4
<#
Measurement harness, first baseline. Owner: P-014.

WHAT THIS MEASURES, AND WHAT IT DOES NOT

This measures the per-invocation cost of the one external-tool boundary the portable
side actually has today: a MediaInfo CLI probe of a committed fixture. It reports the
process-start floor separately from the parse cost, because on inputs this size the
floor dominates and reporting one number would hide that.

It does NOT measure encoding throughput. The portable side has no encoding pipeline, so
there is nothing to measure, and a harness that implied otherwise would be worse than no
harness. When encoding arrives, this file is the pattern to extend, not the number to
compare against.

It is not a gate. Nothing here passes or fails. Timings on a shared desktop are not
reproducible the way a hash is, which is exactly why it reports a spread rather than a
single figure, and why a result with a wide spread should be re-run rather than quoted.

RECORDING RULES

Docs/Planning/ENGINEERING.md permits aggregate durations, counts, stable fixture ids,
process handles, exit status, and the tested commit in benchmark output, and excludes
paths, media names, titles, scripts, commands, and external output. The emitted record
carries fixture base names and byte sizes, which are committed repository facts, and no
absolute path from this machine.

USAGE

  pwsh -File CrossPlatform/eng/Measure-Baseline.ps1 [-Repetitions 20] [-Quiet]

Exit codes: 0 on a completed run, 1 on a setup failure such as a tool hash mismatch.
#>

[CmdletBinding()]
param(
    [ValidateRange(3, 500)]
    [int] $Repetitions = 20,

    [switch] $Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$crossPlatform = Join-Path $repoRoot 'CrossPlatform'
$fixtureDir = Join-Path $crossPlatform 'eng/fixtures/media-inspection/media'
# Deliberately NOT artifacts/evidence. That directory is published under the shared
# evidence-writer lease and audited by port-evidence, and this harness holds no lease and
# is not a gate. Writing a measurement there would put an unaudited file inside an audited
# tree, which is the defect the lease discipline exists to prevent.
$measurementDir = Join-Path $crossPlatform 'artifacts/measurements'

# The pinned Windows authority from the tool matrix. The hash is verified before the
# binary is executed, the same discipline the gates apply, because a measurement taken
# with an unknown binary measures nothing.
$toolPath = Join-Path $crossPlatform 'artifacts/tools/win-mediainfo-26.05/MediaInfo.exe'
$toolSha256 = '30f2828a45a1895b033c3cd7784581033327e7b393033c55f4a03bb15cab0d89'

function Fail([string] $message) {
    Write-Host "FAIL measure-baseline $message"
    exit 1
}

if (-not (Test-Path -LiteralPath $toolPath -PathType Leaf)) {
    Fail 'reason=tool-missing'
}

$actualSha = (Get-FileHash -LiteralPath $toolPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualSha -ne $toolSha256) {
    Fail "reason=tool-hash-mismatch expected=$toolSha256 actual=$actualSha"
}

if (-not (Test-Path -LiteralPath $fixtureDir -PathType Container)) {
    Fail "reason=fixture-directory-missing"
}

# The array subexpression is load-bearing under StrictMode: an empty or single-item
# Get-ChildItem result otherwise has no usable Count, and the check below would throw
# instead of reporting the real problem.
$fixtures = @(Get-ChildItem -LiteralPath $fixtureDir -File |
    Where-Object { $_.Extension -in @('.mp4', '.mkv', '.webm') } |
    Sort-Object Name)

if ($fixtures.Count -eq 0) {
    Fail 'reason=no-fixtures'
}

# One invocation. Returns wall time as the caller sees it and the process's own
# lifetime. The gap between them is this harness's overhead, and reporting both keeps
# that overhead visible instead of silently folded into the tool's number.
function Invoke-Probe {
    param(
        [string[]] $Arguments
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $toolPath
    foreach ($argument in $Arguments) { $startInfo.ArgumentList.Add($argument) }
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $process = [System.Diagnostics.Process]::Start($startInfo)

    # Read before waiting. A full pipe buffer with a waiting parent is a deadlock, and
    # a measurement harness that can hang is not one that can be left running.
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stopwatch.Stop()

    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $null = $stderrTask.GetAwaiter().GetResult()

    $processMs = ($process.ExitTime - $process.StartTime).TotalMilliseconds
    $exitCode = $process.ExitCode
    $process.Dispose()

    [pscustomobject]@{
        WallMs     = $stopwatch.Elapsed.TotalMilliseconds
        ProcessMs  = $processMs
        ExitCode   = $exitCode
        OutputSize = $stdout.Length
    }
}

function Get-Percentile {
    param(
        [double[]] $Values,
        [double] $Percentile
    )

    $sorted = $Values | Sort-Object
    if ($sorted.Count -eq 1) { return [double]$sorted[0] }
    $rank = ($sorted.Count - 1) * $Percentile
    $lower = [Math]::Floor($rank)
    $upper = [Math]::Ceiling($rank)
    if ($lower -eq $upper) { return [double]$sorted[[int]$rank] }
    return [double]$sorted[[int]$lower] + (($rank - $lower) * ([double]$sorted[[int]$upper] - [double]$sorted[[int]$lower]))
}

function Measure-Series {
    param(
        [string] $Label,
        [string[]] $Arguments,
        [int] $Count
    )

    # The first invocation is discarded from the series and reported on its own. Cold
    # start is a real cost the orchestrator pays once, and averaging it into the warm
    # runs would misstate both.
    $cold = Invoke-Probe -Arguments $Arguments
    if ($cold.ExitCode -ne 0) {
        Fail "reason=probe-failed label=$Label exit=$($cold.ExitCode)"
    }

    $wall = [System.Collections.Generic.List[double]]::new()
    $proc = [System.Collections.Generic.List[double]]::new()
    $outputSize = $cold.OutputSize

    for ($i = 0; $i -lt $Count; $i++) {
        $run = Invoke-Probe -Arguments $Arguments
        if ($run.ExitCode -ne 0) {
            Fail "reason=probe-failed label=$Label exit=$($run.ExitCode) iteration=$i"
        }
        if ($run.OutputSize -ne $outputSize) {
            Fail "reason=nondeterministic-output label=$Label first=$outputSize now=$($run.OutputSize)"
        }
        $wall.Add($run.WallMs)
        $proc.Add($run.ProcessMs)
    }

    $wallArray = $wall.ToArray()
    $median = Get-Percentile -Values $wallArray -Percentile 0.5
    $p90 = Get-Percentile -Values $wallArray -Percentile 0.9
    $min = ($wallArray | Measure-Object -Minimum).Minimum
    $max = ($wallArray | Measure-Object -Maximum).Maximum

    [pscustomobject]@{
        label          = $Label
        samples        = $Count
        coldWallMs     = [Math]::Round($cold.WallMs, 2)
        minWallMs      = [Math]::Round($min, 2)
        medianWallMs   = [Math]::Round($median, 2)
        p90WallMs      = [Math]::Round($p90, 2)
        maxWallMs      = [Math]::Round($max, 2)
        medianProcessMs = [Math]::Round((Get-Percentile -Values $proc.ToArray() -Percentile 0.5), 2)
        spreadRatio    = if ($min -gt 0) { [Math]::Round($max / $min, 2) } else { 0 }
        outputBytes    = $outputSize
    }
}

if (-not $Quiet) {
    Write-Host "measure-baseline tool=MediaInfo-26.05 repetitions=$Repetitions fixtures=$($fixtures.Count)"
}

$series = [System.Collections.Generic.List[object]]::new()

# The floor. --Version opens no media file, so this is process creation plus tool
# initialization and nothing else. Every media number below includes this cost, and the
# difference between them is the only part that is actually parsing.
$series.Add((Measure-Series -Label 'version-probe' -Arguments @('--Version') -Count $Repetitions))

foreach ($fixture in $fixtures) {
    $result = Measure-Series -Label $fixture.Name -Arguments @('--Output=JSON', $fixture.FullName) -Count $Repetitions
    $result | Add-Member -NotePropertyName 'fixtureBytes' -NotePropertyValue $fixture.Length
    $series.Add($result)
}

$floor = ($series | Where-Object { $_.label -eq 'version-probe' }).medianWallMs
foreach ($entry in $series) {
    if ($entry.label -eq 'version-probe') { continue }
    $entry | Add-Member -NotePropertyName 'parseMsAboveFloor' -NotePropertyValue ([Math]::Round($entry.medianWallMs - $floor, 2))
}

$commit = (git -C $repoRoot rev-parse HEAD).Trim()

$record = [ordered]@{
    harness          = 'measure-baseline'
    version          = 1
    commit           = $commit
    utc              = [DateTime]::UtcNow.ToString('o')
    os               = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    processArch      = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
    logicalProcessors = [Environment]::ProcessorCount
    tool             = 'MediaInfo CLI 26.05'
    toolSha256       = $toolSha256
    repetitions      = $Repetitions
    processFloorMs   = $floor
    series           = $series
    caveats          = @(
        'Wall times on a shared desktop are not reproducible; treat spreadRatio above 2 as noise-dominated.',
        'This measures probe cost only. The portable side has no encoding pipeline, so no throughput number exists.',
        'parseMsAboveFloor subtracts the median version-probe cost and can be near zero on small fixtures.'
    )
}

if (-not (Test-Path -LiteralPath $measurementDir)) {
    $null = New-Item -ItemType Directory -Path $measurementDir -Force
}

$recordPath = Join-Path $measurementDir 'baseline-measurement.json'
$json = ($record | ConvertTo-Json -Depth 6) -replace "`r`n", "`n"
[System.IO.File]::WriteAllText($recordPath, $json + "`n", [System.Text.UTF8Encoding]::new($false))

if (-not $Quiet) {
    foreach ($entry in $series) {
        $above = if ($entry.PSObject.Properties.Name -contains 'parseMsAboveFloor') { $entry.parseMsAboveFloor } else { 0 }
        '{0,-32} median={1,8:N2}ms p90={2,8:N2}ms spread={3,5:N2}x above_floor={4,7:N2}ms' -f `
            $entry.label, $entry.medianWallMs, $entry.p90WallMs, $entry.spreadRatio, $above
    }
}

$worstSpread = ($series | Measure-Object -Property spreadRatio -Maximum).Maximum
Write-Host ("DONE measure-baseline floor_ms={0:N2} series={1} worst_spread={2:N2}x record=CrossPlatform/artifacts/measurements/baseline-measurement.json" -f $floor, $series.Count, $worstSpread)
exit 0
