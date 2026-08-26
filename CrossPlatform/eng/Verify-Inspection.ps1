#Requires -Version 7.4
# Gate: port-inspection. Drives a configured media-inspection server over real HTTP
# through the contract test binary's --serve-configured host, because the shipped
# server binary deliberately has no configuration surface. Proves at the wire what
# the contract corpus proves in process: the hostile-path corpus is one uniform
# rejection, a reparse component inside a root is refused, malformed authority output
# is a typed failure, a cancelled probe leaves no child process behind, and no banned
# privacy field crosses the wire. The no-authority-call property for rejected paths
# is proven in process by CT-038, which counts probe calls against an injected
# authority; this gate relies on that proof rather than re-deriving a weaker
# process-observation version of it.
#
# Evidence-family obligations, per the verification boundary contract: every audited
# producer serializes evidence mutation through the shared writer lease, whose exact
# receipt owns removal; invalidates the audit sidecar and then its JSON before
# changing audited records; publishes atomically in canonical form; and cleans a
# receipt-named run directory under its task root with the reparse safeguards, so the
# auditor's empty-task-root law holds. Two leases fail closed. The evidence-writer
# lease covers publication only, so a concurrent holder means no evidence mutation,
# though staged task work may remain for the next run's recovery. The task-root lease
# is a share-none handle held from preflight through cleanup: a concurrent inspection
# run cannot acquire it, so it can neither delete this run's live directory nor stage
# beside it, and stale recovery only ever executes with the lease held, when every
# surviving run directory is provably from a crashed run whose handle the operating
# system has already released.
[CmdletBinding()]
param(
    [string]$Configuration = 'Debug'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$engRoot = Split-Path -Parent $PSCommandPath
$crossPlatformRoot = Split-Path -Parent $engRoot
$repositoryRoot = Split-Path -Parent $crossPlatformRoot
$artifactsRoot = [System.IO.Path]::GetFullPath((Join-Path $crossPlatformRoot 'artifacts'))
$evidenceRoot = [System.IO.Path]::GetFullPath((Join-Path $artifactsRoot 'evidence'))
$failureRoot = [System.IO.Path]::GetFullPath((Join-Path $artifactsRoot 'failures'))
$taskRoot = [System.IO.Path]::GetFullPath((Join-Path $artifactsRoot 'tmp\port-inspection'))
$taskLeaseRoot = [System.IO.Path]::GetFullPath((Join-Path $artifactsRoot 'tmp'))
$taskLeasePath = [System.IO.Path]::GetFullPath((Join-Path $artifactsRoot 'tmp\port-inspection.lock'))
$leasePath = [System.IO.Path]::GetFullPath((Join-Path $evidenceRoot '.evidence-writer.lock'))
$auditPath = [System.IO.Path]::GetFullPath((Join-Path $evidenceRoot 'evidence-audit.json'))
$auditSidecarPath = [System.IO.Path]::GetFullPath((Join-Path $evidenceRoot 'evidence-audit.json.sha256'))
$script:CheckCount = 0
$script:CurrentCheck = 'startup'
$script:LeaseOwned = $false
$script:LeaseStream = $null
$script:LeaseBytes = $null
$script:LeaseNonce = $null
$script:AuditInvalidated = $false
$script:TaskLeaseStream = $null

function Stop-Gate {
    param([Parameter(Mandatory)][string]$Message)

    # Failing closed with the lease held would wedge every later producer, so a
    # failure path releases only what it can prove it owns: the held stream must
    # still carry the exact receipt, and so must the file, or the lock is left for
    # an operator, because the exact receipt owns removal.
    if ($script:LeaseOwned -and $null -ne $script:LeaseStream) {
        try {
            if (Test-ExactBytes -Stream $script:LeaseStream -Expected $script:LeaseBytes) {
                $script:LeaseStream.Dispose()
                $script:LeaseStream = $null
                $verify = [System.IO.File]::Open($leasePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
                try {
                    if (Test-ExactBytes -Stream $verify -Expected $script:LeaseBytes) {
                        $verify.Dispose()
                        $verify = $null
                        [System.IO.File]::Delete($leasePath)
                    }
                }
                finally {
                    if ($null -ne $verify) { $verify.Dispose() }
                }
            }
        }
        catch {
            # Leave the lock in place; fail closed.
        }
    }

    # The task-root lease is owned by the held handle alone, so release is a plain
    # dispose; the lock file stays behind on purpose, because an unheld file never
    # blocks the next acquisition.
    if ($null -ne $script:TaskLeaseStream) {
        try { $script:TaskLeaseStream.Dispose() } catch { }
        $script:TaskLeaseStream = $null
    }

    New-Item -ItemType Directory -Force -Path $failureRoot | Out-Null
    $packet = @(
        'gate=port-inspection'
        'criterion=D-045,D-046'
        'exit=1'
        "check=$script:CurrentCheck"
        "message=$Message"
        "replay=pwsh -NoProfile -NonInteractive -File CrossPlatform/eng/Verify-Inspection.ps1 -Configuration $Configuration"
    ) -join "`n"
    [System.IO.File]::WriteAllText((Join-Path $failureRoot 'port-inspection.txt'), $packet + "`n")
    Write-Output "FAIL port-inspection exit=1 evidence=CrossPlatform/artifacts/failures/port-inspection.txt"
    exit 1
}

function Confirm-Check {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Name
    )

    $script:CurrentCheck = $Name
    $script:CheckCount++
    if (-not $Condition) {
        Stop-Gate -Message "Check failed: $Name"
    }
}

function Get-FullPath {
    param([Parameter(Mandatory)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Test-PathBelow {
    param(
        [Parameter(Mandatory)][string]$Candidate,
        [Parameter(Mandatory)][string]$Parent
    )

    try {
        $candidatePath = Get-FullPath $Candidate
        $parentPath = Get-FullPath $Parent
        $prefix = $parentPath.TrimEnd(
            [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)) +
            [System.IO.Path]::DirectorySeparatorChar
        return $candidatePath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
    }
    catch {
        return $false
    }
}

function Confirm-NoReparseComponents {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Id
    )

    $fullPath = Get-FullPath $Path
    $fullRoot = Get-FullPath $Root
    Confirm-Check -Condition ($fullPath -eq $fullRoot -or $fullPath.StartsWith(
            $fullRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar,
            [System.StringComparison]::OrdinalIgnoreCase)) -Name $Id
    $current = $fullRoot
    if ([System.IO.Directory]::Exists($current)) {
        Confirm-Check -Condition ((((Get-Item -LiteralPath $current -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0)) -Name $Id
    }
    $relative = [System.IO.Path]::GetRelativePath($fullRoot, $fullPath)
    foreach ($component in $relative.Split(
            [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar),
            [System.StringSplitOptions]::RemoveEmptyEntries)) {
        $current = Join-Path $current $component
        if (-not (Test-Path -LiteralPath $current)) { break }
        Confirm-Check -Condition ((((Get-Item -LiteralPath $current -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0)) -Name $Id
    }
}

function Test-SafeExistingLeaf {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$AllowedRoot
    )

    try {
        $target = Get-FullPath $Path
        $root = Get-FullPath $AllowedRoot
        if (-not (Test-PathBelow -Candidate $target -Parent $root)) {
            return $false
        }
        $rootItem = Get-Item -LiteralPath $root -Force
        if (-not $rootItem.PSIsContainer -or
            ($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            return $false
        }
        $relative = [System.IO.Path]::GetRelativePath($root, $target)
        $components = $relative.Split(
            [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar),
            [System.StringSplitOptions]::RemoveEmptyEntries)
        if ($components.Count -eq 0) {
            return $false
        }
        $current = $root
        $leafItem = $null
        for ($index = 0; $index -lt $components.Count; $index++) {
            $component = $components[$index]
            if ($component -in @('.', '..')) {
                return $false
            }
            $entries = @(Get-ChildItem -LiteralPath $current -Force | Where-Object {
                    [string]::Equals($_.Name, $component, [System.StringComparison]::Ordinal)
                })
            if ($entries.Count -ne 1) {
                return $false
            }
            $leafItem = $entries[0]
            if (($leafItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                return $false
            }
            if ($index -lt ($components.Count - 1) -and -not $leafItem.PSIsContainer) {
                return $false
            }
            $current = $leafItem.FullName
        }
        $linkTypeProperty = $leafItem.PSObject.Properties['LinkType']
        return -not $leafItem.PSIsContainer -and
            $null -ne $linkTypeProperty -and
            [string]::IsNullOrEmpty([string]$linkTypeProperty.Value)
    }
    catch {
        return $false
    }
}

function Test-SafeArtifactDirectory {
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$Create
    )

    try {
        $target = Get-FullPath $Path
        $artifactPrefix = $artifactsRoot.TrimEnd(
            [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)) +
            [System.IO.Path]::DirectorySeparatorChar
        if ($target -ne $artifactsRoot -and
            -not $target.StartsWith($artifactPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
        foreach ($pass in 1..2) {
            $current = $crossPlatformRoot
            if (((Get-Item -LiteralPath $current -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                return $false
            }
            $relative = [System.IO.Path]::GetRelativePath($crossPlatformRoot, $target)
            foreach ($component in $relative.Split(
                    [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar),
                    [System.StringSplitOptions]::RemoveEmptyEntries)) {
                $current = Join-Path $current $component
                if (-not (Test-Path -LiteralPath $current)) { break }
                if (((Get-Item -LiteralPath $current -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                    return $false
                }
            }
            if ($pass -eq 1 -and $Create) {
                [void][System.IO.Directory]::CreateDirectory($target)
            }
        }
        return Test-Path -LiteralPath $target -PathType Container
    }
    catch {
        return $false
    }
}

function Test-SafeWritableArtifactLeaf {
    param([Parameter(Mandatory)][string]$Path)

    try {
        $target = Get-FullPath $Path
        if (-not (Test-PathBelow -Candidate $target -Parent $artifactsRoot)) {
            return $false
        }
        $parent = Split-Path -Parent $target
        if (-not (Test-SafeArtifactDirectory -Path $parent -Create)) {
            return $false
        }
        if (Test-Path -LiteralPath $target) {
            return Test-SafeExistingLeaf -Path $target -AllowedRoot $crossPlatformRoot
        }
        return -not [string]::IsNullOrWhiteSpace([System.IO.Path]::GetFileName($target))
    }
    catch {
        return $false
    }
}

function Test-ExactBytes {
    param(
        [Parameter(Mandatory)][System.IO.Stream]$Stream,
        [Parameter(Mandatory)][byte[]]$Expected
    )

    try {
        $Stream.Position = 0
        $actual = [byte[]]::new($Expected.Length)
        $offset = 0
        while ($offset -lt $actual.Length) {
            $read = $Stream.Read($actual, $offset, $actual.Length - $offset)
            if ($read -eq 0) { return $false }
            $offset += $read
        }
        if ($Stream.ReadByte() -ne -1) { return $false }
        return [System.Security.Cryptography.CryptographicOperations]::FixedTimeEquals($actual, $Expected)
    }
    catch {
        return $false
    }
}

function Write-AtomicUtf8Artifact {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $fullPath = Get-FullPath $Path
    Confirm-Check -Condition (Test-SafeWritableArtifactLeaf -Path $fullPath) -Name 'evidence-output-leaf'
    $parent = Split-Path -Parent $fullPath
    $temporaryPath = Join-Path $parent (
        '.' + [System.IO.Path]::GetFileName($fullPath) + '.' +
        [System.Guid]::NewGuid().ToString('N') + '.tmp')
    Confirm-Check -Condition (Test-SafeWritableArtifactLeaf -Path $temporaryPath) -Name 'evidence-output-temp'
    $normalizedContent = $Content.Replace("`r`n", "`n")
    Confirm-Check -Condition (-not $normalizedContent.Contains("`r", [System.StringComparison]::Ordinal)) -Name 'evidence-output-bare-cr'
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($normalizedContent)
    $stream = $null
    try {
        $stream = [System.IO.File]::Open(
            $temporaryPath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
        $stream.Dispose()
        $stream = $null
        Confirm-Check -Condition (
            (Test-SafeExistingLeaf -Path $temporaryPath -AllowedRoot $crossPlatformRoot) -and
            (Test-SafeWritableArtifactLeaf -Path $fullPath)) -Name 'evidence-output-revalidate'
        [System.IO.File]::Move($temporaryPath, $fullPath, $true)
    }
    finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            if (Test-SafeExistingLeaf -Path $temporaryPath -AllowedRoot $crossPlatformRoot) {
                [System.IO.File]::Delete($temporaryPath)
            }
        }
    }
}

function Enter-EvidenceWriterLease {
    Confirm-NoReparseComponents $evidenceRoot $crossPlatformRoot 'evidence-lease-root-precreate'
    [void][System.IO.Directory]::CreateDirectory($evidenceRoot)
    Confirm-NoReparseComponents $evidenceRoot $crossPlatformRoot 'evidence-lease-root-created'
    Confirm-NoReparseComponents $leasePath $crossPlatformRoot 'evidence-lease-path-safe'

    $nonce = [System.Guid]::NewGuid().ToString('N')
    Confirm-Check -Condition ($nonce -cmatch '^[0-9a-f]{32}$') -Name 'evidence-lease-receipt-shape'
    $receiptBytes = [System.Text.UTF8Encoding]::new($false).GetBytes($nonce + "`n")
    Confirm-Check -Condition ($receiptBytes.Length -eq 33) -Name 'evidence-lease-receipt-length'

    $stream = $null
    try {
        $stream = [System.IO.File]::Open(
            $leasePath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None)
    }
    catch {
        # Contention fails closed: another producer or the auditor holds the lease,
        # and their exact receipt owns removal, so this gate reports and touches
        # nothing.
        $script:CurrentCheck = 'evidence-lease-unavailable'
        Stop-Gate -Message 'Evidence writer lease is held by another producer or the auditor; failing closed without touching evidence.'
    }

    try {
        $stream.Write($receiptBytes, 0, $receiptBytes.Length)
        $stream.Flush($true)
        if (-not (Test-ExactBytes -Stream $stream -Expected $receiptBytes)) {
            $stream.Dispose()
            Stop-Gate -Message 'Evidence lease receipt write could not be verified.'
        }
        $script:LeaseNonce = $nonce
        $script:LeaseBytes = $receiptBytes
        $script:LeaseStream = $stream
        $script:LeaseOwned = $true
        $script:AuditInvalidated = $false
        $script:CheckCount++
        $stream = $null
    }
    finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
    }
}

function Assert-EvidenceWriterLease {
    Confirm-Check -Condition (
        $script:LeaseOwned -and
        $null -ne $script:LeaseStream -and
        $null -ne $script:LeaseBytes -and
        $script:LeaseNonce -cmatch '^[0-9a-f]{32}$' -and
        $script:LeaseBytes.Length -eq 33 -and
        (Test-SafeExistingLeaf -Path $leasePath -AllowedRoot $evidenceRoot) -and
        (Test-ExactBytes -Stream $script:LeaseStream -Expected $script:LeaseBytes)) -Name 'evidence-lease-ownership'
}

function Invalidate-EvidenceAudit {
    Assert-EvidenceWriterLease
    # The per-file work enforces without counting, so the gate's check count does not
    # depend on whether a stale audit happened to exist; the surrounding asserts and
    # the postcondition carry the fixed counts.
    foreach ($stalePath in @($auditSidecarPath, $auditPath)) {
        if (Test-Path -LiteralPath $stalePath) {
            $script:CurrentCheck = 'evidence-audit-invalidation-safe'
            if (-not (Test-SafeExistingLeaf -Path $stalePath -AllowedRoot $evidenceRoot)) {
                Stop-Gate -Message 'Stale audit artifact failed the safety walk before invalidation.'
            }
            [System.IO.File]::Delete($stalePath)
            if (Test-Path -LiteralPath $stalePath) {
                $script:CurrentCheck = 'evidence-audit-invalidation-delete'
                Stop-Gate -Message 'Stale audit artifact survived invalidation.'
            }
        }
    }
    Assert-EvidenceWriterLease
    Confirm-Check -Condition (
        -not (Test-Path -LiteralPath $auditSidecarPath) -and
        -not (Test-Path -LiteralPath $auditPath)) -Name 'evidence-audit-invalidation-postcondition'
    $script:AuditInvalidated = $true
}

function Assert-EvidencePublicationReady {
    Assert-EvidenceWriterLease
    Confirm-Check -Condition (
        $script:AuditInvalidated -and
        -not (Test-Path -LiteralPath $auditSidecarPath) -and
        -not (Test-Path -LiteralPath $auditPath)) -Name 'evidence-publication-audit-invalidated'
}

function Exit-EvidenceWriterLease {
    Assert-EvidenceWriterLease
    $stream = $script:LeaseStream
    $script:LeaseStream = $null
    $stream.Dispose()

    Confirm-Check -Condition (Test-SafeExistingLeaf -Path $leasePath -AllowedRoot $evidenceRoot) -Name 'evidence-lease-release-safe'
    $verificationStream = $null
    try {
        $verificationStream = [System.IO.File]::Open(
            $leasePath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::None)
        Confirm-Check -Condition (Test-ExactBytes -Stream $verificationStream -Expected $script:LeaseBytes) -Name 'evidence-lease-release-receipt'
    }
    finally {
        if ($null -ne $verificationStream) {
            $verificationStream.Dispose()
        }
    }

    Confirm-Check -Condition (Test-SafeExistingLeaf -Path $leasePath -AllowedRoot $evidenceRoot) -Name 'evidence-lease-release-revalidate'
    [System.IO.File]::Delete($leasePath)
    Confirm-Check -Condition (-not (Test-Path -LiteralPath $leasePath)) -Name 'evidence-lease-release-delete'

    $script:LeaseOwned = $false
    $script:LeaseNonce = $null
    $script:LeaseBytes = $null
    $script:AuditInvalidated = $false
}

# The run directory is receipt-named, and its cleanup removes the one expected
# junction first, non-recursively so only the link goes, then requires the remaining
# tree to be reparse-free before the recursive delete. A junction anywhere else, or a
# foreign entry in the task root, stops the gate rather than being swept. Stale-run
# recovery at preflight enforces the same law uncounted, so the gate's check count
# and its published record do not depend on whether a prior run crashed.
function Remove-ValidatedRunDirectory {
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$Uncounted
    )

    function Confirm-Local {
        param([bool]$Condition, [string]$Name)
        if ($Uncounted) {
            $script:CurrentCheck = $Name
            if (-not $Condition) {
                Stop-Gate -Message "Check failed: $Name"
            }
        }
        else {
            Confirm-Check -Condition $Condition -Name $Name
        }
    }

    if (-not [System.IO.Directory]::Exists($Path)) {
        return
    }

    $fullPath = Get-FullPath $Path
    $parent = [System.IO.Directory]::GetParent($fullPath)
    $leaf = [System.IO.Path]::GetFileName($fullPath)
    Confirm-Local -Condition (
        $null -ne $parent -and
        [string]::Equals($parent.FullName, $taskRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        $leaf -cmatch '^run-[0-9a-f]{32}$') -Name 'cleanup-target'

    if ($Uncounted) {
        $script:CurrentCheck = 'cleanup-root-no-reparse'
        if (-not (Test-SafeArtifactDirectory -Path $taskRoot)) {
            Stop-Gate -Message 'Task root failed the safety walk before stale cleanup.'
        }
    }
    else {
        Confirm-NoReparseComponents $taskRoot $crossPlatformRoot 'cleanup-root-no-reparse'
        Confirm-NoReparseComponents $fullPath $crossPlatformRoot 'cleanup-target-no-reparse'
    }

    $expectedJunction = Join-Path (Join-Path $fullPath 'media') 'linked'
    if (Test-Path -LiteralPath $expectedJunction) {
        $junctionItem = Get-Item -LiteralPath $expectedJunction -Force
        Confirm-Local -Condition (
            $junctionItem.PSIsContainer -and
            (($junctionItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) -Name 'cleanup-junction-shape'
        [System.IO.Directory]::Delete($expectedJunction, $false)
        Confirm-Local -Condition (-not (Test-Path -LiteralPath $expectedJunction)) -Name 'cleanup-junction-removed'
    }

    foreach ($item in @(Get-ChildItem -LiteralPath $fullPath -Recurse -Force)) {
        Confirm-Local -Condition ((($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0)) -Name 'cleanup-tree-no-reparse'
    }

    [System.IO.Directory]::Delete($fullPath, $true)
    Confirm-Local -Condition (-not (Test-Path -LiteralPath $fullPath)) -Name 'cleanup-run-removed'
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Resolve the committed inputs and the built test binary.
$script:CurrentCheck = 'resolve-inputs'
$testExe = Join-Path $crossPlatformRoot "artifacts\bin\StaxRip.ContractTests\$($Configuration.ToLowerInvariant())\StaxRip.ContractTests.exe"
if (-not (Test-Path -LiteralPath $testExe -PathType Leaf)) {
    Stop-Gate -Message "Test binary not found at $testExe; build $Configuration first."
}
$testExe = (Resolve-Path -LiteralPath $testExe).Path
$fixtureRoot = (Resolve-Path -LiteralPath (Join-Path $crossPlatformRoot 'eng\fixtures\media-inspection')).Path
$baseCommit = (& git -C $repositoryRoot rev-parse 'HEAD') 2>$null
if ($LASTEXITCODE -ne 0) { Stop-Gate -Message 'Unable to resolve repository head.' }

# The task-root lease: one share-none handle owns the task root from here through
# cleanup. Acquisition proves no live inspection run exists, because every live run
# holds this handle for its whole lifetime; so everything preflight finds below is
# from a crashed run, whose handle the operating system released at process death.
# Contention means a live concurrent run, and this gate fails closed without
# touching the task root. The lock file itself persists across runs by design; the
# held handle is the ownership receipt, not the file.
$script:CurrentCheck = 'task-root-lease'
Confirm-Check -Condition (Test-SafeArtifactDirectory -Path $taskLeaseRoot -Create) -Name 'task-lease-parent-safe'
try {
    $script:TaskLeaseStream = [System.IO.File]::Open(
        $taskLeasePath,
        [System.IO.FileMode]::OpenOrCreate,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::None)
}
catch {
    Stop-Gate -Message 'Task-root lease is held; a concurrent inspection run owns the task root.'
}
Confirm-Check -Condition ($null -ne $script:TaskLeaseStream) -Name 'task-lease-acquired'

# Preflight, under the task-root lease: the task root must contain only receipt-named
# run directories from crashed prior runs, each removed through the validated path;
# anything else stops the gate.
$script:CurrentCheck = 'task-root-preflight'
Confirm-Check -Condition (Test-SafeArtifactDirectory -Path $taskRoot -Create) -Name 'task-root-safe'
foreach ($entry in @(Get-ChildItem -LiteralPath $taskRoot -Force)) {
    $script:CurrentCheck = 'task-root-foreign-entry'
    if (-not ($entry.PSIsContainer -and $entry.Name -cmatch '^run-[0-9a-f]{32}$')) {
        Stop-Gate -Message "Foreign entry in the inspection task root: $($entry.Name)"
    }
    Remove-ValidatedRunDirectory -Path $entry.FullName -Uncounted
}

# Stage the gate's media world inside a receipt-named run directory: committed media
# copies, a garbage golden for the malformed case, a sleep probe for the cancellation
# case, and a junction directory inside the root for the reparse-component case.
$script:CurrentCheck = 'stage-media-world'
$runNonce = [System.Guid]::NewGuid().ToString('N')
$runRoot = Join-Path $taskRoot ("run-" + $runNonce)
Confirm-Check -Condition (Test-SafeArtifactDirectory -Path $runRoot -Create) -Name 'run-root-safe'
$mediaDir = Join-Path $runRoot 'media'
Confirm-Check -Condition (Test-SafeArtifactDirectory -Path $mediaDir -Create) -Name 'run-media-safe'
Copy-Item -LiteralPath (Join-Path $fixtureRoot 'media\cfr-h264-aac.mp4') -Destination (Join-Path $mediaDir 'cfr-h264-aac.mp4')
Copy-Item -LiteralPath (Join-Path $fixtureRoot 'cfr-h264-aac.mp4.win-26.05.json') -Destination (Join-Path $runRoot 'cfr-h264-aac.mp4.win-26.05.json')
Copy-Item -LiteralPath (Join-Path $fixtureRoot 'media\cfr-h264-aac.mp4') -Destination (Join-Path $mediaDir 'malformed-probe.mkv')
[System.IO.File]::WriteAllText((Join-Path $runRoot 'malformed-probe.mkv.win-26.05.json'), "this is not a json document`n")
Copy-Item -LiteralPath (Join-Path $fixtureRoot 'media\cfr-h264-aac.mp4') -Destination (Join-Path $mediaDir 'sleep-probe.mkv')
$junctionDir = Join-Path $mediaDir 'linked'
& cmd /c mklink /J "$junctionDir" "$mediaDir" | Out-Null
Confirm-Check -Condition (Test-Path -LiteralPath (Join-Path $junctionDir 'cfr-h264-aac.mp4')) -Name 'junction-created'

# Start the configured host and hold its lifetime through stdin.
$script:CurrentCheck = 'start-configured-host'
$hostInfo = [System.Diagnostics.ProcessStartInfo]::new()
$hostInfo.FileName = $testExe
$hostInfo.ArgumentList.Add('--serve-configured')
$hostInfo.ArgumentList.Add($mediaDir)
$hostInfo.ArgumentList.Add($testExe)
$hostInfo.RedirectStandardInput = $true
$hostInfo.RedirectStandardOutput = $true
$hostInfo.RedirectStandardError = $true
$hostInfo.UseShellExecute = $false
$hostProcess = [System.Diagnostics.Process]::Start($hostInfo)
try {
    $readyLine = $hostProcess.StandardOutput.ReadLine()
    Confirm-Check -Condition ($null -ne $readyLine -and $readyLine.StartsWith('READY http://127.0.0.1:', [System.StringComparison]::Ordinal)) -Name 'host-ready'
    $baseUri = [uri]$readyLine.Substring(6).Trim()

    $handler = [System.Net.Http.SocketsHttpHandler]::new()
    $handler.AllowAutoRedirect = $false
    $handler.UseCookies = $false
    $handler.UseProxy = $false
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(10)

    function Invoke-GateRequest {
        param(
            [Parameter(Mandatory)][string]$Method,
            [Parameter(Mandatory)][string]$Route,
            [string]$BodyText,
            [string[]]$ExtraHeaders = @(),
            [double]$TimeoutSeconds = 10
        )

        $request = [System.Net.Http.HttpRequestMessage]::new(
            [System.Net.Http.HttpMethod]::new($Method),
            [uri]::new($baseUri, $Route))
        $request.Version = [System.Net.HttpVersion]::Version11
        $request.VersionPolicy = [System.Net.Http.HttpVersionPolicy]::RequestVersionExact
        $request.Headers.Host = $baseUri.Authority
        foreach ($header in $ExtraHeaders) {
            $parts = $header.Split(':', 2)
            [void]$request.Headers.TryAddWithoutValidation($parts[0], $parts[1])
        }
        if ($PSBoundParameters.ContainsKey('BodyText')) {
            $request.Content = [System.Net.Http.ByteArrayContent]::new([System.Text.Encoding]::UTF8.GetBytes($BodyText))
            $request.Content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/json; charset=utf-8')
        }
        $cancel = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds($TimeoutSeconds))
        try {
            $response = $client.SendAsync($request, $cancel.Token).GetAwaiter().GetResult()
            $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            return [pscustomobject]@{ Status = [int]$response.StatusCode; Body = $body; Headers = $response.Headers }
        }
        finally {
            $cancel.Dispose()
            $request.Dispose()
        }
    }

    # Session bootstrap, exactly as a shell client would.
    $rootResponse = Invoke-GateRequest -Method 'GET' -Route '/'
    Confirm-Check -Condition ($rootResponse.Status -eq 200) -Name 'session-bootstrap-status'
    $setCookie = @($rootResponse.Headers.GetValues('Set-Cookie'))
    Confirm-Check -Condition ($setCookie.Count -eq 1) -Name 'session-cookie-single'
    $cookiePair = $setCookie[0].Split(';', 2)[0]
    $sessionHeaders = @("X-StaxRip-Client:web", "Cookie:$cookiePair")

    function Invoke-MediaFacts {
        param(
            [Parameter(Mandatory)][string]$MediaPath,
            [double]$TimeoutSeconds = 10
        )

        $escaped = $MediaPath.Replace('\', '\\')
        return Invoke-GateRequest -Method 'POST' -Route '/api/v1/media-facts' -BodyText "{`"path`":`"$escaped`"}" -ExtraHeaders $sessionHeaders -TimeoutSeconds $TimeoutSeconds
    }

    # Capability agreement: the configured host publishes media inspection available.
    $capabilities = Invoke-GateRequest -Method 'GET' -Route '/api/v1/capabilities' -ExtraHeaders $sessionHeaders
    Confirm-Check -Condition ($capabilities.Status -eq 200) -Name 'capabilities-status'
    $capabilityPayload = $capabilities.Body | ConvertFrom-Json
    $inspectionRow = @($capabilityPayload.features | Where-Object { $_.id -ceq 'media-inspection' })
    Confirm-Check -Condition ($inspectionRow.Count -eq 1 -and $inspectionRow[0].availability -ceq 'available') -Name 'capability-available'

    # The happy path, and privacy through the wire: the raw golden carries banned
    # names, and none of them may appear in the response body.
    $happy = Invoke-MediaFacts -MediaPath (Join-Path $mediaDir 'cfr-h264-aac.mp4')
    Confirm-Check -Condition ($happy.Status -eq 200) -Name 'happy-status'
    $happyPayload = $happy.Body | ConvertFrom-Json
    Confirm-Check -Condition ($happyPayload.container.format -ceq 'MPEG-4') -Name 'happy-container-format'
    Confirm-Check -Condition ($happyPayload.authority.version -ceq '26.05') -Name 'happy-authority-version'
    foreach ($banned in @('UniqueID', 'Encoded_Library_Settings', 'Encoded_Application', 'File_Created_Date', 'File_Modified_Date', 'CompleteName', 'FolderName')) {
        Confirm-Check -Condition (-not $happy.Body.Contains($banned)) -Name "privacy-wire-$banned"
    }

    # The hostile corpus: every acceptance failure is the same status and the same
    # body, byte for byte, including the reparse-component path inside the root.
    $hostilePaths = @(
        (Join-Path $runRoot 'cfr-h264-aac.mp4.win-26.05.json'),
        (Join-Path $mediaDir 'absent-file-4471aa.mkv'),
        $mediaDir,
        ($mediaDir + '\..\media\cfr-h264-aac.mp4'),
        (Join-Path $junctionDir 'cfr-h264-aac.mp4'),
        'relative-name.mkv',
        '\\server\share\file.mkv'
    )
    $uniformBody = $null
    for ($index = 0; $index -lt $hostilePaths.Count; $index++) {
        $rejection = Invoke-MediaFacts -MediaPath $hostilePaths[$index]
        Confirm-Check -Condition ($rejection.Status -eq 422) -Name "hostile-status-$index"
        if ($null -eq $uniformBody) { $uniformBody = $rejection.Body }
        Confirm-Check -Condition ($rejection.Body -ceq $uniformBody) -Name "hostile-uniform-$index"
        Confirm-Check -Condition (-not $rejection.Body.Contains('\')) -Name "hostile-no-path-echo-$index"
    }

    # Malformed authority output past acceptance is a typed failure naming only the
    # reason class.
    $malformed = Invoke-MediaFacts -MediaPath (Join-Path $mediaDir 'malformed-probe.mkv')
    Confirm-Check -Condition ($malformed.Status -eq 502) -Name 'malformed-status'
    Confirm-Check -Condition ($malformed.Body.Contains('authorityFailure') -and $malformed.Body.Contains('document-not-json')) -Name 'malformed-typed'

    # Cancellation mid-probe: the client aborts a hanging probe, and afterward no
    # impersonated-tool child process may remain. The host itself is the only
    # allowed process with the test binary's image.
    $cancelObserved = $false
    try {
        Invoke-MediaFacts -MediaPath (Join-Path $mediaDir 'sleep-probe.mkv') -TimeoutSeconds 2 | Out-Null
    }
    catch {
        $cancelObserved = $true
    }
    Confirm-Check -Condition $cancelObserved -Name 'cancellation-client-aborted'
    Start-Sleep -Seconds 3
    $survivors = @(Get-Process -Name 'StaxRip.ContractTests' -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $hostProcess.Id })
    Confirm-Check -Condition ($survivors.Count -eq 0) -Name 'cancellation-no-orphans'

    # After everything, the happy path still answers: the pipeline survived the
    # corpus and the cancellation without wedging.
    $again = Invoke-MediaFacts -MediaPath (Join-Path $mediaDir 'cfr-h264-aac.mp4')
    Confirm-Check -Condition ($again.Status -eq 200) -Name 'post-corpus-happy'

    $client.Dispose()
    $handler.Dispose()
}
finally {
    if (-not $hostProcess.HasExited) {
        $hostProcess.StandardInput.Close()
        if (-not $hostProcess.WaitForExit(15000)) {
            $hostProcess.Kill($true)
            $hostProcess.WaitForExit()
        }
    }
}
Confirm-Check -Condition ($hostProcess.ExitCode -eq 0) -Name 'host-clean-shutdown'

# Publish the evidence record under the shared writer lease: acquire, invalidate the
# stale audit sidecar-then-JSON, prove publication readiness, write atomically in
# canonical form, and release with the exact receipt.
$script:CurrentCheck = 'write-evidence'
Enter-EvidenceWriterLease
Invalidate-EvidenceAudit
Assert-EvidencePublicationReady
$record = [ordered]@{
    schema = 'staxrip-inspection-v1'
    head = $baseCommit
    configuration = $Configuration
    test_binary_sha256 = (Get-FileHash -LiteralPath $testExe -Algorithm SHA256).Hash.ToLowerInvariant()
    checks = $script:CheckCount
    corpus = [ordered]@{
        hostile_paths = 7
        malformed_documents = 1
        cancellation_probes = 1
    }
    reliances = @(
        'CT-038 proves rejected paths never reach the authority, in process with an injected authority',
        'CT-020 is the load-bearing privacy proof at the guard; the wire greps here restate it, and the typed payload schema excludes banned fields structurally, shown by a strip-neutralizing mutation that CT-020 caught while the wire greps could not'
    )
}
$json = ConvertTo-Json -InputObject $record -Depth 6
Write-AtomicUtf8Artifact -Path (Join-Path $evidenceRoot 'inspection.json') -Content ($json.Replace("`r`n", "`n").TrimEnd([char]10) + "`n")
Exit-EvidenceWriterLease
if (Test-Path -LiteralPath (Join-Path $failureRoot 'port-inspection.txt')) {
    Remove-Item -LiteralPath (Join-Path $failureRoot 'port-inspection.txt') -Force
}

# Receipt-bound cleanup, then the task root must be empty for the auditor's law,
# and only then does the task-root lease release.
$script:CurrentCheck = 'cleanup'
Remove-ValidatedRunDirectory -Path $runRoot
Confirm-Check -Condition (@(Get-ChildItem -LiteralPath $taskRoot -Force).Count -eq 0) -Name 'task-root-empty-after'
$script:CurrentCheck = 'task-lease-release'
$script:TaskLeaseStream.Dispose()
$script:TaskLeaseStream = $null

$stopwatch.Stop()
Write-Output "PASS port-inspection checks=$script:CheckCount elapsed_ms=$($stopwatch.ElapsedMilliseconds) evidence=CrossPlatform/artifacts/evidence/inspection.json"
exit 0
