#Requires -Version 7.0
<#
.SYNOPSIS
Proves that a built StaxRip.exe can load its embedded option help.

.DESCRIPTION
Check-OptionHelp.ps1 checks the sources and the project file; only this script checks the artifact.
VB names an embedded resource <RootNamespace>.<file name> and ignores the <Link> folder, so an entry
without <LogicalName>StaxRip.OptionHelp.<file></LogicalName> leaves the loader's ".OptionHelp."
marker matching nothing: the catalog returns Nothing, every help surface goes quiet, and every other
gate still passes. This script loads the executable by reflection and asserts the resources, the
chain, the resolutions, the value note and the search index are all really there.

Run it after a build; it exits 1 when any assertion fails.
#>
[CmdletBinding()]
param(
    # The executable to probe. Defaults to Source\bin\StaxRip.exe under the repository root.
    [string]$ExePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
if (-not $ExePath) { $ExePath = Join-Path $repoRoot 'Source\bin\StaxRip.exe' }
if (-not (Test-Path -LiteralPath $ExePath)) { throw "No executable at '$ExePath'; build StaxRip first." }
$ExePath = (Resolve-Path -LiteralPath $ExePath).Path
$bin = Split-Path -Parent $ExePath

$script:Failures = [System.Collections.Generic.List[string]]::new()

function Assert-Probe {
    param([Parameter(Mandatory)][AllowNull()]$Actual, [Parameter(Mandatory)][AllowNull()]$Expected, [Parameter(Mandatory)][string]$What)
    if ($Actual -ceq $Expected) { "ok   $What = $Actual" }
    else { $script:Failures.Add($What); "FAIL ${What}: expected '$Expected', got '$Actual'" }
}

# StaxRip.exe is loaded outside its own directory, so anything it drags in has to be found by hand.
$script:Resolved = [System.Collections.Generic.List[string]]::new()
[AppDomain]::CurrentDomain.add_AssemblyResolve({
        param($sender, $args)
        $simple = $args.Name.Split(',')[0]
        $path = Join-Path $bin ($simple + '.dll')
        if (Test-Path -LiteralPath $path) {
            $script:Resolved.Add("resolved-from-bin: $simple")
            return [System.Reflection.Assembly]::LoadFrom($path)
        }
        $script:Resolved.Add("unresolved: $simple")
        return $null
    })

$asm = [System.Reflection.Assembly]::LoadFrom($ExePath)
"assembly: " + $asm.GetName().Name + " " + $asm.GetName().Version
"assembly path: " + $asm.Location

$resources = @($asm.GetManifestResourceNames() | Where-Object { $_ -like '*OptionHelp*' } | Sort-Object)
foreach ($r in $resources) { "resource: $r" }
foreach ($expected in @('StaxRip.OptionHelp.concepts.md', 'StaxRip.OptionHelp.staxrip.md', 'StaxRip.OptionHelp.svt-av1.md')) {
    Assert-Probe -Actual ([bool]($resources -ccontains $expected)) -Expected $true -What "manifest holds $expected"
}

$t = $asm.GetType('StaxRip.OptionHelpCatalog', $true)

# Route the loader's diagnostics into a list: a parse error or a missing file must not pass unseen.
$script:Log = [System.Collections.Generic.List[string]]::new()
$logProp = $t.GetProperty('Log', [System.Reflection.BindingFlags]'Public, Static')
$logProp.SetValue($null, [Action[string]] { param($m) $script:Log.Add($m) })

$cat = $t.GetMethod('Get', [System.Reflection.BindingFlags]'Public, Static').Invoke($null, @('svt-av1'))
Assert-Probe -Actual ($null -ne $cat) -Expected $true -What 'Catalog.Get("svt-av1") is not null'
if ($null -eq $cat) {
    foreach ($m in $script:Log) { "LOG: $m" }
    "PROBE FAILED: $($script:Failures.Count) assertion(s)"
    exit 1
}

Assert-Probe -Actual ([string]$t.GetProperty('EncoderId').GetValue($cat)) -Expected 'svt-av1' -What 'catalog EncoderId'
$chain = $t.GetProperty('Chain').GetValue($cat)
$chainNames = ($chain | ForEach-Object { $_.GetType().GetProperty('Name').GetValue($_) }) -join ', '
Assert-Probe -Actual $chainNames -Expected 'svt-av1.md, staxrip.md' -What 'catalog Chain'

$resolve = $t.GetMethod('Resolve')

$r1 = $resolve.Invoke($cat, @('svt-av1.preset'))
$rt = $r1.GetType()
Assert-Probe -Actual ([string]$rt.GetProperty('Outcome').GetValue($r1)) -Expected 'reviewed' -What 'Resolve("svt-av1.preset") Outcome'
Assert-Probe -Actual ([string]$rt.GetProperty('FileName').GetValue($r1)) -Expected 'svt-av1.md' -What 'Resolve("svt-av1.preset") FileName'
$presetStanza = $rt.GetProperty('Stanza').GetValue($r1)
Assert-Probe -Actual ($null -ne $presetStanza) -Expected $true -What 'preset stanza is not null'
if ($null -eq $presetStanza) { "PROBE FAILED: $($script:Failures.Count) assertion(s)"; exit 1 }
$st = $presetStanza.GetType()
Assert-Probe -Actual ([string]$st.GetProperty('Id').GetValue($presetStanza)) -Expected 'svt-av1.preset' -What 'preset Stanza.Id'
Assert-Probe -Actual ([bool]$st.GetProperty('IsReviewed').GetValue($presetStanza)) -Expected $true -What 'preset Stanza.IsReviewed'
$summary = [string]$st.GetProperty('Summary').GetValue($presetStanza)
"preset Stanza.Summary: $summary"
Assert-Probe -Actual ([bool]($summary.Length -gt 0)) -Expected $true -What 'preset Stanza.Summary is not empty'

# A never-existing id must resolve to 'none' with no stanza. svt-av1.crf served here until plan 3 Task 4 wrote it.
$r2 = $resolve.Invoke($cat, @('svt-av1.no-such-option'))
Assert-Probe -Actual ([string]$rt.GetProperty('Outcome').GetValue($r2)) -Expected 'none' -What 'Resolve("svt-av1.no-such-option") Outcome'
Assert-Probe -Actual ($null -eq $rt.GetProperty('Stanza').GetValue($r2)) -Expected $true -What 'no-such-option stanza is null'

$g = $t.GetMethod('Lookup').Invoke($cat, @('concept.compression-efficiency'))
Assert-Probe -Actual ($null -ne $g) -Expected $true -What 'Lookup("concept.compression-efficiency") is not null'
if ($null -ne $g) {
    Assert-Probe -Actual ([string]$g.GetType().GetProperty('FileName').GetValue($g)) -Expected 'concepts.md' -What 'glossary Stanza.FileName'
    Assert-Probe -Actual ([bool]$g.GetType().GetProperty('IsReviewed').GetValue($g)) -Expected $true -What 'glossary Stanza.IsReviewed'
}

# The dropdown value note and the search index: the two dialog behaviours a headless probe reaches.
$note = [string]$t.GetMethod('ValueNote').Invoke($cat, @($presetStanza, '6'))
"ValueNote(preset, 6): $note"
Assert-Probe -Actual ([bool]($note.Length -gt 0)) -Expected $true -What 'ValueNote(preset, "6") is not empty'
$search = [string]$t.GetMethod('SearchText').Invoke($cat, @($presetStanza, 'svt-av1.preset'))
Assert-Probe -Actual ([bool]$search.Contains('slow')) -Expected $true -What "SearchText(preset) contains 'slow'"
Assert-Probe -Actual ([bool]$search.Contains('svt-av1')) -Expected $false -What 'SearchText(preset) does not index the namespace'

foreach ($m in $script:Log) { "LOG: $m" }
Assert-Probe -Actual $script:Log.Count -Expected 0 -What 'loader diagnostics'

if ($script:Resolved.Count -eq 0) { "dependency resolution: none needed" }
else { $script:Resolved | Sort-Object -Unique }

if ($script:Failures.Count -gt 0) {
    "PROBE FAILED: $($script:Failures.Count) assertion(s): $($script:Failures -join '; ')"
    exit 1
}
"PROBE PASSED"
exit 0
