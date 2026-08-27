#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$Encoder,
    [switch]$Json,
    [switch]$AdvanceRatchet,
    [switch]$SelfTest,
    [string]$CompareFacts,
    [string]$Dump
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'OptionHelp.psm1') -Force

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
}

if ($Dump) {
    $file = Read-OptionHelpFile -Path $Dump
    [Console]::Out.Write((ConvertTo-OptionHelpDump -File $file))
    exit 0
}

if ($SelfTest) {
    exit (Invoke-OptionHelpSelfTest -FixturesRoot (Join-Path $PSScriptRoot 'fixtures'))
}

if ($CompareFacts) {
    $diff = @(Compare-OptionHelpFacts -RepoRoot $RepoRoot -FactsPath $CompareFacts)
    foreach ($d in $diff) { [Console]::Error.WriteLine($d) }
    if ($diff.Count -gt 0) { exit 1 }
    [Console]::Error.WriteLine('facts: no differences')
    exit 0
}

$report = Test-OptionHelpRepository -RepoRoot $RepoRoot -Encoder $Encoder
if ($Json) {
    [Console]::Out.Write(($report | ConvertTo-Json -Depth 6))
}
else {
    [Console]::Out.Write((Format-OptionHelpReport -Report $report))
}
if ($AdvanceRatchet) {
    if (-not $report.Pass) { [Console]::Error.WriteLine('Ratchet not advanced: validation failed'); exit 1 }
    Update-OptionHelpRatchet -RepoRoot $RepoRoot -Report $report
    [Console]::Error.WriteLine('Ratchet advanced')
}
if ($report.Pass) { exit 0 }
exit 1
