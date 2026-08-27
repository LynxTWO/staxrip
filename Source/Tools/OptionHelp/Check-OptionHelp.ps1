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

# Tasks 3 and 4 add the repository check, ratchet, JSON, and facts comparison here.
[Console]::Error.WriteLine('Repository check is not implemented yet.')
exit 1
