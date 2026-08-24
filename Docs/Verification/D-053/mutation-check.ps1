<#
D-053 mutation check: proves clone-differential.ps1 is a guard rather than decoration.

A differential that reports zero differences proves nothing until it has been seen to report
something. clone-differential.ps1 falsifies its own comparator internally, but that only shows
the comparator works, not that it is actually watching the shipping copier. This script goes
the rest of the way: it breaks Source\General\DeepCopy.vb three ways, rebuilds each time, and
requires the differential to fail on each. Then it restores the file and requires a pass.

Each mutation removes exactly one of the behaviors D-053 names, so a mutation the harness does
not catch is a hole in the harness.

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File Docs\Verification\D-053\mutation-check.ps1

DeepCopy.vb is edited in place and restored in a finally block. Do not run it on a tree with
uncommitted changes to that file. Expect roughly ten minutes: every mutation is a full rebuild.
#>
[CmdletBinding()]
param(
    [string] $MSBuild = 'C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe',
    [int] $TimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$source = Join-Path $root 'Source\General\DeepCopy.vb'
$project = Join-Path $root 'Source\StaxRip.vbproj'
$differential = Join-Path $PSScriptRoot 'clone-differential.ps1'

foreach ($required in $source, $project, $differential, $MSBuild) {
    if (-not (Test-Path $required)) { Write-Host "FAIL: not found: $required" -ForegroundColor Red; exit 2 }
}

$original = [IO.File]::ReadAllText($source)
$newline = if ($original.Contains("`r`n")) { "`r`n" } else { "`n" }

# Each mutation deletes one behavior. <NL> stands for whatever line ending the file actually
# uses, so the anchors do not quietly stop matching if the file is renormalised. Every anchor
# must match exactly once: a refactor that moves the code makes this script fail loudly rather
# than silently testing nothing.
$mutations = @(
    @{
        Name    = 'NonSerialized fields are copied instead of skipped'
        Find    = '                If Not field.IsNotSerialized Then fields.Add(field)'
        Replace = '                fields.Add(field)'
    },
    @{
        Name    = 'serialization callbacks are never invoked'
        Find    = '        If methods.Length = 0 Then Exit Sub'
        Replace = '        Exit Sub<NL>        If methods.Length = 0 Then Exit Sub'
    },
    @{
        Name    = 'structures are filled in through a boxed reference'
        Find    = '        copy = FormatterServices.PopulateObjectMembers(copy, DirectCast(fields, MemberInfo()), values)'
        Replace = '        For writeIndex = 0 To fields.Length - 1<NL>            fields(writeIndex).SetValue(copy, values(writeIndex))<NL>        Next'
    }
)

function Build {
    $output = & $MSBuild $project /p:Configuration=Debug /p:Platform=x64 /v:minimal /nologo 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host '    build FAILED:' -ForegroundColor Red
        $output | Select-Object -Last 8 | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
        return $false
    }
    return $true
}

function Invoke-Differential {
    $exe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $outFile = [IO.Path]::GetTempFileName()
    $errFile = [IO.Path]::GetTempFileName()

    $proc = Start-Process -FilePath $exe -PassThru -WindowStyle Hidden `
        -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$differential`"" `
        -RedirectStandardOutput $outFile -RedirectStandardError $errFile

    # Touching Handle caches it, which is what keeps ExitCode readable after the process ends.
    # Without this the property comes back empty and every run looks like a failure.
    $null = $proc.Handle

    # A copier broken badly enough leaves a cloned Dictionary whose bucket chain loops back on
    # itself, and the first lookup never returns. Hanging the harness is a detection, but only
    # if the run is bounded; otherwise this script waits forever on its own success.
    $timedOut = -not $proc.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        try { $proc.Kill() } catch { }
        $null = $proc.WaitForExit(15000)
    }

    $text = @()
    foreach ($file in $outFile, $errFile) {
        if (Test-Path $file) { $text += @(Get-Content $file -ErrorAction SilentlyContinue) }
    }
    Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue

    $reported = @($text | Where-Object { $_ -match '^\s+FAIL\s' } |
        ForEach-Object { ($_ -replace '^\s+FAIL\s+', '').Trim() })
    if ($reported.Count -eq 0 -and -not $timedOut) {
        $reported = @($text | Where-Object { $_ -match 'Exception|SerializationException' } | Select-Object -First 1)
    }

    return [pscustomobject]@{
        Code     = if ($timedOut) { 'timeout' } else { $proc.ExitCode }
        TimedOut = $timedOut
        Caught   = $reported
    }
}

$failures = New-Object 'System.Collections.Generic.List[string]'

try {
    Write-Host ''
    Write-Host '=== baseline: unmutated tree must pass ==='
    if (-not (Build)) {
        $failures.Add('baseline build')
    } else {
        $baseline = Invoke-Differential
        if (-not $baseline.TimedOut -and $baseline.Code -eq 0) {
            Write-Host '  PASS  differential is green before any mutation'
        } else {
            Write-Host "  FAIL  differential is already failing (exit $($baseline.Code)); fix that before mutating" -ForegroundColor Red
            $baseline.Caught | ForEach-Object { Write-Host "          $_" -ForegroundColor Red }
            $failures.Add('baseline differential')
        }
    }

    if ($failures.Count -eq 0) {
        foreach ($mutation in $mutations) {
            Write-Host ''
            Write-Host "=== mutation: $($mutation.Name) ==="

            $occurrences = ([regex]::Matches($original, [regex]::Escape($mutation.Find))).Count
            if ($occurrences -ne 1) {
                Write-Host "  FAIL  anchor matched $occurrences times, expected exactly 1 -- this mutation tested nothing" -ForegroundColor Red
                $failures.Add("$($mutation.Name) [anchor]")
                continue
            }

            $replacement = $mutation.Replace.Replace('<NL>', $newline)
            [IO.File]::WriteAllText($source, $original.Replace($mutation.Find, $replacement))

            if (-not (Build)) {
                Write-Host '  FAIL  mutated tree did not build, so the mutation proved nothing' -ForegroundColor Red
                $failures.Add("$($mutation.Name) [build]")
                continue
            }

            $result = Invoke-Differential
            if ($result.TimedOut) {
                Write-Host "  PASS  differential caught it (wedged, killed after ${TimeoutSeconds}s -- the broken copy hangs on first use)"
            } elseif ($result.Code -ne 0) {
                Write-Host "  PASS  differential caught it (exit $($result.Code), $($result.Caught.Count) check(s) failed)"
                $result.Caught | Select-Object -First 5 | ForEach-Object { Write-Host "          caught: $_" }
            } else {
                Write-Host '  FAIL  differential stayed green with the behavior removed -- the guard has a hole' -ForegroundColor Red
                $failures.Add($mutation.Name)
            }
        }
    }
} finally {
    [IO.File]::WriteAllText($source, $original)
    Write-Host ''
    Write-Host '=== restored: rebuilding the unmutated tree ==='
    if (Build) {
        $restored = Invoke-Differential
        if (-not $restored.TimedOut -and $restored.Code -eq 0) {
            Write-Host '  PASS  differential is green again'
        } else {
            Write-Host "  FAIL  differential still failing after restore (exit $($restored.Code))" -ForegroundColor Red
            $failures.Add('restore')
        }
    } else {
        Write-Host '  FAIL  restored tree did not build' -ForegroundColor Red
        $failures.Add('restore build')
    }
}

Write-Host ''
if ($failures.Count -eq 0) {
    Write-Host 'RESULT: PASS -- every mutation was caught, and the tree is back as it was.' -ForegroundColor Green
    exit 0
} else {
    Write-Host ("RESULT: FAIL -- {0} problem(s):" -f $failures.Count) -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
