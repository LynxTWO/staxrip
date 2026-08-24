# Static consistency check for the Synchronize script cache.
#
# Why this exists: the runtime guard probe (chunk-sync-guard-probe.cs) cannot cover the
# cache STORE. "LastCode = <x>" sits after the frame-server round-trip, and a reflection
# probe can never complete that, so the probe always throws before reaching the assignment.
# A mutation that stores the expanded text while the guard compares the unexpanded text
# therefore survives the runtime probe, yet in production it means the cache never hits and
# the chunk-encode race returns. This check closes exactly that gap.
#
# Invariant: the identifier compared against LastCode in the guard MUST be the identifier
# assigned to LastCode in the body. If they diverge, the cache can never hit.
#
# Exit 0 = consistent. Exit 1 = inconsistent or unparseable.

[CmdletBinding()]
param(
    [string] $SourceFile = (Join-Path $PSScriptRoot '..\..\..\Source\Video\VideoScript.vb')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SourceFile)) {
    Write-Output "FAIL source file not found: $SourceFile"
    exit 1
}

$text = Get-Content -LiteralPath $SourceFile -Raw

# The guard: "If Me.Error <> "" OrElse <key> <> LastCode OrElse (comparePath ..."
$guardPattern = 'OrElse\s+([A-Za-z_][A-Za-z0-9_]*)\s+<>\s+LastCode'
$guardMatches = [regex]::Matches($text, $guardPattern)

# The store: "LastCode = <key>"
$storePattern = 'LastCode\s*=\s*([A-Za-z_][A-Za-z0-9_]*)'
$storeMatches = [regex]::Matches($text, $storePattern)

if ($guardMatches.Count -ne 1) {
    Write-Output "FAIL expected exactly 1 guard comparison against LastCode, found $($guardMatches.Count)"
    exit 1
}
if ($storeMatches.Count -ne 1) {
    Write-Output "FAIL expected exactly 1 assignment to LastCode, found $($storeMatches.Count)"
    exit 1
}

$guardKey = $guardMatches[0].Groups[1].Value
$storeKey = $storeMatches[0].Groups[1].Value

if ($guardKey -ne $storeKey) {
    Write-Output "FAIL cache key mismatch: guard compares '$guardKey' but the body stores '$storeKey'."
    Write-Output "     The cache can never hit, so Synchronize rewrites on every call and"
    Write-Output "     concurrent chunk-encode workers re-enter the guarded body."
    exit 1
}

# The key must not be the macro-expanded variable. 'code' is reassigned by Macro.Expand
# immediately before the guard, so using it as the key is the original defect.
if ($guardKey -eq 'code') {
    Write-Output "FAIL the cache key is 'code', which Macro.Expand reassigns just above the guard."
    Write-Output "     Volatile macros (%current_time%, %current_time24%, %random%) make that"
    Write-Output "     value differ on every call, so the guard can never short-circuit."
    exit 1
}

Write-Output "PASS cache key '$guardKey' is used consistently by the guard and the store."
exit 0
