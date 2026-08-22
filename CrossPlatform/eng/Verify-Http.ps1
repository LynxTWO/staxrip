[CmdletBinding()]
param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",

    [string]$ServerPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$gateId = "port-http-windows"
$startedAt = [System.Diagnostics.Stopwatch]::StartNew()
$script:CheckCount = 0
$script:CurrentCheck = "preflight"
$script:ProducerExit = $null
$script:Clients = [System.Collections.Generic.List[object]]::new()
$script:Servers = [System.Collections.Generic.List[object]]::new()
$script:OuterCleanupCheck = $null
$script:OuterCleanupException = $null
$script:EvidenceLeaseOwned = $false
$script:EvidenceLeaseNonce = $null
$script:EvidenceLeaseBytes = $null
$script:EvidenceLeaseStream = $null
$script:EvidenceAuditInvalidated = $false
$script:OwnedTaskCreated = $false
$script:TaskCleanupResult = "not-created"
$maximumResponseBytes = 307200
$maximumConsoleCharacters = 8192

if ($null -eq ("StaxRip.Verification.BoundedTextCollector" -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Threading.Tasks;

namespace StaxRip.Verification
{
    public sealed class BoundedTextCollector
    {
        private readonly int maximumCharacters;
        private readonly StringBuilder captured;
        private readonly StringBuilder firstLineBuffer;
        private readonly TaskCompletionSource<string> firstLine;

        public BoundedTextCollector(TextReader reader, int maximumCharacters)
        {
            if (reader == null) throw new ArgumentNullException(nameof(reader));
            if (maximumCharacters < 1) throw new ArgumentOutOfRangeException(nameof(maximumCharacters));

            this.maximumCharacters = maximumCharacters;
            captured = new StringBuilder(Math.Min(maximumCharacters, 1024));
            firstLineBuffer = new StringBuilder(Math.Min(maximumCharacters, 256));
            firstLine = new TaskCompletionSource<string>(TaskCreationOptions.RunContinuationsAsynchronously);
            Completion = DrainAsync(reader);
        }

        public Task<string> FirstLine { get { return firstLine.Task; } }
        public Task Completion { get; private set; }
        public long TotalCharacters { get; private set; }
        public bool Overflowed { get; private set; }
        public string CapturedText { get { return captured.ToString(); } }

        public void ClearCapturedText()
        {
            captured.Clear();
            firstLineBuffer.Clear();
        }

        private async Task DrainAsync(TextReader reader)
        {
            var buffer = new char[1024];
            var firstLineComplete = false;
            try
            {
                while (true)
                {
                    var count = await reader.ReadAsync(buffer, 0, buffer.Length).ConfigureAwait(false);
                    if (count == 0) break;

                    TotalCharacters += count;
                    var available = maximumCharacters - captured.Length;
                    if (available > 0)
                    {
                        captured.Append(buffer, 0, Math.Min(available, count));
                    }
                    if (count > available) Overflowed = true;

                    if (!firstLineComplete)
                    {
                        for (var index = 0; index < count; index++)
                        {
                            var value = buffer[index];
                            if (value == '\n')
                            {
                                if (firstLineBuffer.Length > 0 &&
                                    firstLineBuffer[firstLineBuffer.Length - 1] == '\r')
                                {
                                    firstLineBuffer.Length--;
                                }
                                firstLineComplete = true;
                                firstLine.TrySetResult(firstLineBuffer.ToString());
                                break;
                            }
                            if (firstLineBuffer.Length < maximumCharacters)
                            {
                                firstLineBuffer.Append(value);
                            }
                            else
                            {
                                Overflowed = true;
                            }
                        }
                    }
                }

                if (!firstLineComplete)
                {
                    firstLine.TrySetResult(firstLineBuffer.Length == 0 ? null : firstLineBuffer.ToString());
                }
            }
            catch (Exception exception)
            {
                firstLine.TrySetException(exception);
                throw;
            }
        }
    }
}
'@ -Language CSharp
}

function Confirm-Check {
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,

        [Parameter(Mandatory)]
        [ValidatePattern("^[a-z0-9][a-z0-9-]{1,79}$")]
        [string]$Id
    )

    $script:CurrentCheck = $Id
    if (-not $Condition) {
        throw [System.InvalidOperationException]::new("CHECK:$Id")
    }

    $script:CheckCount++
}

function Get-FullPath {
    param([Parameter(Mandatory)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Confirm-DescendantPath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Id
    )

    $fullPath = Get-FullPath $Path
    $fullRoot = (Get-FullPath $Root).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar)
    $prefix = $fullRoot + [System.IO.Path]::DirectorySeparatorChar
    Confirm-Check ($fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) $Id
    return $fullPath
}

function Confirm-NoReparseComponents {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Id
    )

    $fullPath = Get-FullPath $Path
    $fullRoot = Get-FullPath $Root
    Confirm-Check ($fullPath -eq $fullRoot -or $fullPath.StartsWith(
            $fullRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar,
            [System.StringComparison]::OrdinalIgnoreCase)) $Id
    $current = $fullRoot
    if ([System.IO.Directory]::Exists($current)) {
        Confirm-Check ((((Get-Item -LiteralPath $current -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0)) $Id
    }
    $relative = [System.IO.Path]::GetRelativePath($fullRoot, $fullPath)
    foreach ($component in $relative.Split(
            [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar),
            [System.StringSplitOptions]::RemoveEmptyEntries)) {
        $current = Join-Path $current $component
        if (-not (Test-Path -LiteralPath $current)) { break }
        Confirm-Check ((((Get-Item -LiteralPath $current -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0)) $Id
    }
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
        for ($index = 0; $index -lt $components.Count; $index++) {
            $component = $components[$index]
            if ($component -in @('.', '..')) {
                return $false
            }
            $matches = @(Get-ChildItem -LiteralPath $current -Force | Where-Object {
                    [string]::Equals($_.Name, $component, [System.StringComparison]::Ordinal)
                })
            if ($matches.Count -ne 1) {
                return $false
            }
            $item = $matches[0]
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                return $false
            }
            if ($index -lt ($components.Count - 1) -and -not $item.PSIsContainer) {
                return $false
            }
            $current = $item.FullName
        }
        $leaf = $matches[0]
        $linkTypeProperty = $leaf.PSObject.Properties['LinkType']
        return -not $leaf.PSIsContainer -and
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

function Write-AtomicUtf8Artifact {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $fullPath = Get-FullPath $Path
    if (-not (Test-SafeWritableArtifactLeaf -Path $fullPath)) {
        throw [System.InvalidOperationException]::new("CHECK:fixed-output-leaf")
    }
    $parent = Split-Path -Parent $fullPath
    $temporaryPath = Join-Path $parent (
        '.' + [System.IO.Path]::GetFileName($fullPath) + '.' +
        [System.Guid]::NewGuid().ToString('N') + '.tmp')
    if (-not (Test-SafeWritableArtifactLeaf -Path $temporaryPath)) {
        throw [System.InvalidOperationException]::new("CHECK:fixed-output-temp")
    }
    $normalizedContent = $Content.Replace("`r`n", "`n")
    if ($normalizedContent.Contains("`r", [System.StringComparison]::Ordinal)) {
        throw [System.IO.InvalidDataException]::new("CHECK:fixed-output-bare-cr")
    }
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
        if (-not (Test-SafeExistingLeaf -Path $temporaryPath -AllowedRoot $crossPlatformRoot) -or
            -not (Test-SafeWritableArtifactLeaf -Path $fullPath)) {
            throw [System.InvalidOperationException]::new("CHECK:fixed-output-revalidate")
        }
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

function Enter-EvidenceWriterLease {
    if ($script:EvidenceLeaseOwned -or $null -ne $script:EvidenceLeaseStream) {
        Assert-EvidencePublicationReady
        return
    }

    Confirm-NoReparseComponents $evidenceRoot $crossPlatformRoot "evidence-lease-root-precreate"
    [void][System.IO.Directory]::CreateDirectory($evidenceRoot)
    Confirm-NoReparseComponents $evidenceRoot $crossPlatformRoot "evidence-lease-root-created"
    Confirm-NoReparseComponents $evidenceLeasePath $crossPlatformRoot "evidence-lease-path-safe"

    $nonce = [System.Guid]::NewGuid().ToString("N")
    if ($nonce -cnotmatch "^[0-9a-f]{32}$") {
        throw (New-CheckException "evidence-lease-receipt-shape")
    }
    $receiptBytes = [System.Text.UTF8Encoding]::new($false).GetBytes($nonce + "`n")
    if ($receiptBytes.Length -ne 33) {
        throw (New-CheckException "evidence-lease-receipt-length")
    }

    $stream = $null
    try {
        $stream = [System.IO.File]::Open(
            $evidenceLeasePath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None)
        $stream.Write($receiptBytes, 0, $receiptBytes.Length)
        $stream.Flush($true)
        if (-not (Test-ExactBytes -Stream $stream -Expected $receiptBytes)) {
            throw (New-CheckException "evidence-lease-receipt-write")
        }

        $script:EvidenceLeaseNonce = $nonce
        $script:EvidenceLeaseBytes = $receiptBytes
        $script:EvidenceLeaseStream = $stream
        $script:EvidenceLeaseOwned = $true
        $script:EvidenceAuditInvalidated = $false
        $stream = $null
        $script:CheckCount++
    }
    catch {
        $acquisitionException = $_.Exception
        $exactPartialReceipt = $false
        if ($null -ne $stream) {
            try {
                $exactPartialReceipt = Test-ExactBytes -Stream $stream -Expected $receiptBytes
                $stream.Dispose()
                $stream = $null
            }
            catch {
                throw (New-CheckException "evidence-lease-create-dispose" (
                    [System.AggregateException]::new(
                        "Evidence lease creation and stream disposal both failed.",
                        [System.Exception[]]@($acquisitionException, $_.Exception))))
            }
        }
        if ($exactPartialReceipt) {
            $verificationStream = $null
            try {
                if (-not (Test-SafeExistingLeaf -Path $evidenceLeasePath -AllowedRoot $evidenceRoot)) {
                    throw (New-CheckException "evidence-lease-create-cleanup-safe")
                }
                $verificationStream = [System.IO.File]::Open(
                    $evidenceLeasePath,
                    [System.IO.FileMode]::Open,
                    [System.IO.FileAccess]::Read,
                    [System.IO.FileShare]::None)
                if (-not (Test-ExactBytes -Stream $verificationStream -Expected $receiptBytes)) {
                    throw (New-CheckException "evidence-lease-create-cleanup-receipt")
                }
                $verificationStream.Dispose()
                $verificationStream = $null
                [System.IO.File]::Delete($evidenceLeasePath)
                if (Test-Path -LiteralPath $evidenceLeasePath) {
                    throw (New-CheckException "evidence-lease-create-cleanup-delete")
                }
            }
            catch {
                throw (New-CheckException "evidence-lease-create-cleanup" (
                    [System.AggregateException]::new(
                        "Evidence lease creation and exact partial-receipt cleanup both failed.",
                        [System.Exception[]]@($acquisitionException, $_.Exception))))
            }
            finally {
                if ($null -ne $verificationStream) {
                    try { $verificationStream.Dispose() } catch { }
                }
            }
        }
        if ($acquisitionException.Message -cmatch '^CHECK:') { throw $acquisitionException }
        throw (New-CheckException "evidence-lease-create-new" $acquisitionException)
    }
}

function Assert-EvidenceWriterLease {
    if (-not $script:EvidenceLeaseOwned -or
        $null -eq $script:EvidenceLeaseStream -or
        $null -eq $script:EvidenceLeaseBytes -or
        $script:EvidenceLeaseNonce -cnotmatch "^[0-9a-f]{32}$" -or
        $script:EvidenceLeaseBytes.Length -ne 33 -or
        -not (Test-SafeExistingLeaf -Path $evidenceLeasePath -AllowedRoot $evidenceRoot) -or
        -not (Test-ExactBytes -Stream $script:EvidenceLeaseStream -Expected $script:EvidenceLeaseBytes)) {
        throw (New-CheckException "evidence-lease-ownership")
    }
    $script:CheckCount++
}

function Invalidate-EvidenceAudit {
    Assert-EvidenceWriterLease
    foreach ($path in @($auditSidecarPath, $auditPath)) {
        if (Test-Path -LiteralPath $path) {
            if (-not (Test-SafeExistingLeaf -Path $path -AllowedRoot $evidenceRoot)) {
                throw (New-CheckException "evidence-audit-invalidation-safe")
            }
            [System.IO.File]::Delete($path)
            if (Test-Path -LiteralPath $path) {
                throw (New-CheckException "evidence-audit-invalidation-delete")
            }
            $script:CheckCount++
        }
    }
    Assert-EvidenceWriterLease
    if ((Test-Path -LiteralPath $auditSidecarPath) -or (Test-Path -LiteralPath $auditPath)) {
        throw (New-CheckException "evidence-audit-invalidation-postcondition")
    }
    $script:EvidenceAuditInvalidated = $true
}

function Assert-EvidencePublicationReady {
    Assert-EvidenceWriterLease
    if (-not $script:EvidenceAuditInvalidated -or
        (Test-Path -LiteralPath $auditSidecarPath) -or
        (Test-Path -LiteralPath $auditPath)) {
        throw (New-CheckException "evidence-publication-audit-invalidated")
    }
    $script:CheckCount++
}

function Exit-EvidenceWriterLease {
    if (-not $script:EvidenceLeaseOwned) { return }

    Assert-EvidenceWriterLease
    $stream = $script:EvidenceLeaseStream
    $script:EvidenceLeaseStream = $null
    try {
        $stream.Dispose()
    }
    catch {
        throw (New-CheckException "evidence-lease-stream-dispose" $_.Exception)
    }

    if (-not (Test-SafeExistingLeaf -Path $evidenceLeasePath -AllowedRoot $evidenceRoot)) {
        throw (New-CheckException "evidence-lease-release-safe")
    }
    $verificationStream = $null
    try {
        $verificationStream = [System.IO.File]::Open(
            $evidenceLeasePath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::None)
        if (-not (Test-ExactBytes -Stream $verificationStream -Expected $script:EvidenceLeaseBytes)) {
            throw (New-CheckException "evidence-lease-release-receipt")
        }
    }
    finally {
        if ($null -ne $verificationStream) {
            $verificationStream.Dispose()
        }
    }

    if (-not (Test-SafeExistingLeaf -Path $evidenceLeasePath -AllowedRoot $evidenceRoot)) {
        throw (New-CheckException "evidence-lease-release-revalidate")
    }
    [System.IO.File]::Delete($evidenceLeasePath)
    if (Test-Path -LiteralPath $evidenceLeasePath) {
        throw (New-CheckException "evidence-lease-release-delete")
    }

    $script:EvidenceLeaseOwned = $false
    $script:EvidenceLeaseNonce = $null
    $script:EvidenceLeaseBytes = $null
    $script:EvidenceAuditInvalidated = $false
    $script:CheckCount++
}

function ConvertTo-CanonicalJson {
    param(
        [Parameter(Mandatory)]$InputObject,
        [Parameter(Mandatory)][ValidateRange(2, 64)][int]$Depth
    )

    $json = ConvertTo-Json -InputObject $InputObject -Depth $Depth -WarningAction Stop
    $json = $json.Replace("`r`n", "`n")
    if ($json.Contains("`r", [System.StringComparison]::Ordinal)) {
        throw [System.IO.InvalidDataException]::new("CHECK:json-bare-cr")
    }
    return $json.TrimEnd([char]10) + "`n"
}

function Remove-ValidatedTaskDirectory {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$TaskRoot
    )

    if (-not [System.IO.Directory]::Exists($Path)) {
        return
    }

    $fullPath = Get-FullPath $Path
    $fullRoot = Get-FullPath $TaskRoot
    $parent = [System.IO.Directory]::GetParent($fullPath)
    $leaf = [System.IO.Path]::GetFileName($fullPath)

    if ($null -eq $parent -or
        -not [string]::Equals($parent.FullName, $fullRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        $leaf -notmatch "^run-[0-9a-f]{32}$") {
        throw [System.InvalidOperationException]::new("CHECK:cleanup-target")
    }

    Confirm-NoReparseComponents $fullRoot $crossPlatformRoot "cleanup-root-no-reparse"
    Confirm-NoReparseComponents $fullPath $crossPlatformRoot "cleanup-target-no-reparse"
    foreach ($item in @(Get-ChildItem -LiteralPath $fullPath -Recurse -Force)) {
        Confirm-Check ((($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0)) "cleanup-tree-no-reparse"
    }

    [System.IO.Directory]::Delete($fullPath, $true)
}

function Get-SourceRecordSha256 {
    param([Parameter(Mandatory)][string]$EvidenceRoot)

    $sourceRecordLeaf = "static-gate.json"
    $sourceRecordMatches = @(Get-ChildItem -LiteralPath $EvidenceRoot -Force | Where-Object {
            [string]::Equals($_.Name, $sourceRecordLeaf, [System.StringComparison]::Ordinal)
        })
    Confirm-Check ($sourceRecordMatches.Count -eq 1) "http-source-record-unique"

    $sourceRecordItem = $sourceRecordMatches[0]
    $expectedSourceRecordPath = Get-FullPath (Join-Path $EvidenceRoot $sourceRecordLeaf)
    Confirm-Check (
        [string]::Equals(
            (Get-FullPath $sourceRecordItem.FullName),
            $expectedSourceRecordPath,
            [System.StringComparison]::OrdinalIgnoreCase)) "http-source-record-path"
    Confirm-Check (-not $sourceRecordItem.PSIsContainer) "http-source-record-not-directory"
    Confirm-Check (
        (($sourceRecordItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0)) `
        "http-source-record-no-reparse"
    Confirm-Check `
        (Test-SafeExistingLeaf -Path $sourceRecordItem.FullName -AllowedRoot $EvidenceRoot) `
        "http-source-record-safe"

    $sourceRecordSha256 = (Get-FileHash -LiteralPath $sourceRecordItem.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    Confirm-Check ($sourceRecordSha256 -match "^[0-9a-f]{64}$") "http-source-record-hash"
    Confirm-Check `
        (Test-SafeExistingLeaf -Path $sourceRecordItem.FullName -AllowedRoot $EvidenceRoot) `
        "http-source-record-still-safe"
    return $sourceRecordSha256
}

# Composite identity of the managed set the apphost loads. SHA-256 over the
# newline-joined lowercase per-file hashes of the six runtime-relevant files, in this
# exact order, with a trailing newline. The same function exists verbatim in
# Verify-Browser.ps1 and Verify-Evidence.ps1; drift between copies is self-revealing
# because the audit compares producer values against its own recomputation.
function Get-ManagedSetSha256 {
    param([Parameter(Mandatory)][string]$ServerDirectory)

    $managedSetLeaves = @(
        'StaxRip.Contracts.dll',
        'StaxRip.Core.dll',
        'StaxRip.Platform.dll',
        'StaxRip.Server.deps.json',
        'StaxRip.Server.dll',
        'StaxRip.Server.runtimeconfig.json'
    )
    $rows = foreach ($leaf in $managedSetLeaves) {
        (Get-FileHash -LiteralPath (Join-Path $ServerDirectory $leaf) -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes(($rows -join "`n") + "`n")
    return [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Write-SuccessRecord {
    param(
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [Parameter(Mandatory)][string]$VerifiedServerPath
    )

    Assert-EvidencePublicationReady
    Confirm-NoReparseComponents $EvidenceRoot $crossPlatformRoot "http-evidence-root-no-reparse"
    [void][System.IO.Directory]::CreateDirectory($EvidenceRoot)
    Confirm-NoReparseComponents $EvidenceRoot $crossPlatformRoot "http-evidence-root-created"
    $sourceRecordSha256 = Get-SourceRecordSha256 $EvidenceRoot
    $recordPath = Join-Path $EvidenceRoot "http-windows.json"
    Confirm-NoReparseComponents $recordPath $crossPlatformRoot "http-evidence-leaf-no-reparse"
    # Named before record construction so a failure while hashing (missing or locked
    # file) is attributed to this step instead of the previous check id.
    $script:CurrentCheck = "http-evidence-write"
    $record = [ordered]@{
        schema = "staxrip-http-windows-v1"
        gate = $gateId
        result = "pass"
        configuration = $Configuration
        sourceRecordSha256 = $sourceRecordSha256
        host = [ordered]@{
            platformId = "windows"
            architectureId = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString().ToLowerInvariant()
            runtimeVersion = [Environment]::Version.ToString()
        }
        serverSha256 = (Get-FileHash -LiteralPath $VerifiedServerPath -Algorithm SHA256).Hash.ToLowerInvariant()
        # The apphost is a configuration-invariant launcher stub, byte-identical between
        # Debug and Release, so serverSha256 alone cannot falsify the declared
        # configuration. What differs is the managed set the apphost loads from its own
        # directory. A composite over the full set is required: binding Server.dll alone
        # would let a Debug Core/Contracts/Platform assembly or a tampered runtime
        # configuration sit beside a genuine Release Server.dll undetected. The composite
        # is the SHA-256 of the newline-joined per-file hashes in this fixed order.
        # Tracked in Docs/Review/SLICE-002-Remediation-Backlog.md as R-S2-042.
        managedSetSha256 = (Get-ManagedSetSha256 -ServerDirectory (Split-Path -Parent $VerifiedServerPath))
        checks = $script:CheckCount
        lifecycle = "gate-initiated-kill"
        secretsPersisted = $false
    }
    Write-AtomicUtf8Artifact `
        -Path $recordPath `
        -Content (ConvertTo-CanonicalJson -InputObject $record -Depth 8)
}

function Get-TreeSnapshot {
    param([Parameter(Mandatory)][string]$Root)

    $rootPath = Get-FullPath $Root
    $rows = [System.Collections.Generic.List[string]]::new()

    foreach ($entry in Get-ChildItem -LiteralPath $rootPath -Force -Recurse | Sort-Object FullName) {
        $relative = [System.IO.Path]::GetRelativePath($rootPath, $entry.FullName).Replace('\', '/')
        $isReparse = ($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
        Confirm-Check (-not $isReparse) "snapshot-no-reparse"

        if ($entry.PSIsContainer) {
            $rows.Add("d|$relative")
        }
        else {
            $hash = (Get-FileHash -LiteralPath $entry.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            $rows.Add("f|$relative|$($entry.Length)|$hash")
        }
    }

    return ,$rows.ToArray()
}

function Compare-Snapshot {
    param(
        [Parameter(Mandatory)][string[]]$Before,
        [Parameter(Mandatory)][string[]]$After,
        [Parameter(Mandatory)][string]$Id
    )

    Confirm-Check ($Before.Count -eq $After.Count) "$Id-count"
    for ($index = 0; $index -lt $Before.Count; $index++) {
        Confirm-Check ([string]::Equals($Before[$index], $After[$index], [System.StringComparison]::Ordinal)) "$Id-row"
    }
}

function Test-HexText {
    param(
        [Parameter(Mandatory)][string]$Value,
        [Parameter(Mandatory)][int]$Length
    )

    if ($Value.Length -ne $Length) {
        return $false
    }

    foreach ($character in $Value.ToCharArray()) {
        if (-not (($character -ge '0' -and $character -le '9') -or
            ($character -ge 'a' -and $character -le 'f') -or
            ($character -ge 'A' -and $character -le 'F'))) {
            return $false
        }
    }

    return $true
}

function Test-SetCookieStructure {
    param([Parameter(Mandatory)][string[]]$Values)

    Confirm-Check ($Values.Count -eq 1) "cookie-single-header"
    $headerValue = $Values[0]
    $segments = $headerValue.Split(';', [System.StringSplitOptions]::None)
    Confirm-Check ($segments.Count -eq 4) "cookie-segment-count"

    $pair = $segments[0].Trim()
    $separator = $pair.IndexOf('=')
    Confirm-Check ($separator -gt 0) "cookie-pair-shape"
    $cookieName = $pair.Substring(0, $separator)
    $cookieValue = $pair.Substring($separator + 1)
    Confirm-Check ($cookieName.StartsWith("staxrip_session_", [System.StringComparison]::Ordinal)) "cookie-name-prefix"
    Confirm-Check (Test-HexText $cookieName.Substring("staxrip_session_".Length) 24) "cookie-name-random-shape"
    Confirm-Check (Test-HexText $cookieValue 64) "cookie-token-shape"

    $attributes = @($segments[1..($segments.Count - 1)] | ForEach-Object { $_.Trim().ToLowerInvariant() } | Sort-Object)
    $expected = @("httponly", "path=/api/v1", "samesite=strict") | Sort-Object
    Confirm-Check (($attributes -join "|") -ceq ($expected -join "|")) "cookie-attribute-set"

    $cookieValue = $null
    $pair = $null
    $headerValue = $null
    return $cookieName
}

function New-ClientBundle {
    $container = [System.Net.CookieContainer]::new()
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::None
    $handler.CookieContainer = $container
    $handler.UseCookies = $true
    $handler.UseProxy = $false
    $client = [System.Net.Http.HttpClient]::new($handler, $true)
    $client.Timeout = [System.TimeSpan]::FromSeconds(10)
    $bundle = [pscustomobject]@{
        Client = $client
        Container = $container
    }
    $script:Clients.Add($bundle)
    return $bundle
}

function Read-BoundedResponseBody {
    param([Parameter(Mandatory)][System.Net.Http.HttpResponseMessage]$Response)

    if ($Response.Content.Headers.ContentLength -gt $maximumResponseBytes) {
        throw [System.InvalidOperationException]::new("CHECK:response-content-length")
    }

    $stream = $Response.Content.ReadAsStream()
    try {
        $buffer = [byte[]]::new(8192)
        $memory = [System.IO.MemoryStream]::new()
        try {
            while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                if (($memory.Length + $read) -gt $maximumResponseBytes) {
                    throw [System.InvalidOperationException]::new("CHECK:response-body-bound")
                }
                $memory.Write($buffer, 0, $read)
            }
            return [System.Text.Encoding]::UTF8.GetString($memory.ToArray())
        }
        finally {
            $memory.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Get-ResponseHeaders {
    param([Parameter(Mandatory)][System.Net.Http.HttpResponseMessage]$Response)

    $headers = [System.Collections.Generic.Dictionary[string, string[]]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($header in $Response.Headers) {
        if (-not [string]::Equals($header.Key, "Set-Cookie", [System.StringComparison]::OrdinalIgnoreCase)) {
            $headers[$header.Key] = @($header.Value)
        }
    }
    foreach ($header in $Response.Content.Headers) {
        $headers[$header.Key] = @($header.Value)
    }
    return $headers
}

function Confirm-NoCorsPermission {
    param([Parameter(Mandatory)]$Headers)
    foreach ($name in $Headers.Keys) {
        Confirm-Check (-not $name.StartsWith("Access-Control-Allow-", [System.StringComparison]::OrdinalIgnoreCase)) "cors-no-permission"
    }
}

function Confirm-SecurityHeaders {
    param([Parameter(Mandatory)]$Headers)

    $expected = [ordered]@{
        "Cache-Control" = "no-store"
        "Content-Security-Policy" = "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self'; font-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'; worker-src 'none'; manifest-src 'none'"
        "X-Content-Type-Options" = "nosniff"
        "X-Frame-Options" = "DENY"
        "Referrer-Policy" = "no-referrer"
        "Cross-Origin-Opener-Policy" = "same-origin"
        "Cross-Origin-Resource-Policy" = "same-origin"
        "Permissions-Policy" = "accelerometer=(), autoplay=(), camera=(), display-capture=(), encrypted-media=(), fullscreen=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), midi=(), payment=(), picture-in-picture=(), publickey-credentials-get=(), screen-wake-lock=(), serial=(), usb=(), web-share=(), xr-spatial-tracking=()"
    }

    foreach ($item in $expected.GetEnumerator()) {
        Confirm-Check ($Headers.ContainsKey($item.Key)) "security-header-present"
        Confirm-Check (($Headers[$item.Key] -join ", ") -ceq $item.Value) "security-header-value"
    }

    Confirm-Check (-not $Headers.ContainsKey("Server")) "security-no-server-header"
}

function Test-SensitiveConsoleText {
    param([AllowEmptyString()][string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return $false }
    $options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    # R-S2-045. This detector was the one redactor left behind when the credential rules
    # were widened across the other gates, and it was recorded as covering more than it
    # did. Three classes were missing outright and are added below. The header rule also
    # accepted only ":" as a separator, so "Authorization=..." forms escaped it; both
    # separators are now accepted with an optional surrounding quote, which is the same
    # shape R-S2-036 settled on for the browser gate.
    if ([System.Text.RegularExpressions.Regex]::IsMatch(
            $Text,
            '^[^\r\n]*?["'']?\b(?:Authorization|Proxy-Authorization|Cookie|Set-Cookie)\b["'']?\s*[:=][^\r\n]*(?=\r?$)',
            $options)) {
        return $true
    }
    # Credential schemes anywhere in the text. Present in the static, wrapper and manifest
    # scripts; absent here until now, so a bare "Bearer <token>" was invisible.
    if ([System.Text.RegularExpressions.Regex]::IsMatch(
            $Text,
            '(?i)\b(?:Bearer|Basic|Digest|Negotiate|NTLM)\s+[A-Za-z0-9._~+/=-]{8,}',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)) {
        return $true
    }
    # URI user information. The browser gate carries this rule; this gate did not, so a
    # credential embedded in a URL was invisible.
    if ([System.Text.RegularExpressions.Regex]::IsMatch(
            $Text,
            '(?i)\b[a-z][a-z0-9+.-]*://[^/\s@]+:[^/\s@]+@',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)) {
        return $true
    }
    # Token fields with either separator and an optional surrounding quote, so quoted JSON
    # members such as {"token":"..."} are detected. This is the R-S2-036 gap in this file.
    return [System.Text.RegularExpressions.Regex]::IsMatch(
        $Text,
        '(?i)(?:["'']?\bstaxrip_session_[0-9a-f]{24}\b["'']?|["'']?\b(?:access[_-]?token|refresh[_-]?token|id[_-]?token|api[_-]?key|client[_-]?secret|password|passwd|token|secret)\b["'']?)[ \t]*[:=]',
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
}

function ConvertTo-RedactedConsoleText {
    param([AllowEmptyString()][string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    $lineOptions = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    $redacted = [System.Text.RegularExpressions.Regex]::Replace(
        $Text,
        '^[^\r\n]*?["''](?:Authorization|Proxy-Authorization|Cookie|Set-Cookie)["'']\s*:[^\r\n]*(?=\r?$)',
        '<redacted-sensitive-header-line>',
        $lineOptions)
    $authorizationEvaluator = [System.Text.RegularExpressions.MatchEvaluator]{
        param([System.Text.RegularExpressions.Match]$Match)
        $prefix = $Match.Groups['prefix'].Value
        $value = $Match.Groups['value'].Value.Trim()
        $scheme = [System.Text.RegularExpressions.Regex]::Match(
            $value,
            '^(?<scheme>[A-Za-z][A-Za-z0-9+._-]*)(?:[ \t]+.*)?$',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
        if ($scheme.Success) {
            return $prefix + $scheme.Groups['scheme'].Value + ' <redacted>'
        }
        return $prefix + '<redacted>'
    }
    $redacted = [System.Text.RegularExpressions.Regex]::Replace(
        $redacted,
        '^(?<prefix>[^\r\n]*?\b(?:Authorization|Proxy-Authorization)[ \t]*:[ \t]*)(?<value>[^\r\n]*)(?=\r?$)',
        $authorizationEvaluator,
        $lineOptions)
    $redacted = [System.Text.RegularExpressions.Regex]::Replace(
        $redacted,
        '^(?<prefix>[^\r\n]*?\b(?:Cookie|Set-Cookie)[ \t]*:)[^\r\n]*(?=\r?$)',
        '${prefix} <redacted>',
        $lineOptions)
    $redacted = [System.Text.RegularExpressions.Regex]::Replace(
        $redacted,
        '(?i)(?<prefix>\bstaxrip_session_[0-9a-f]{24}[ \t]*=[ \t]*)[0-9a-f]{64}',
        '${prefix}<redacted>',
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
    $redacted = [System.Text.RegularExpressions.Regex]::Replace(
        $redacted,
        '(?i)(?<prefix>\b(?:access[_-]?token|refresh[_-]?token|id[_-]?token|api[_-]?key|client[_-]?secret|password|passwd|token|secret)\b[ \t]*=[ \t]*)(?:"[^"\r\n]*"|''[^''\r\n]*''|[^\s;&,\r\n]+)',
        '${prefix}<redacted>',
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
    return $redacted
}

function Confirm-PrivacyText {
    param(
        [AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][string[]]$Sentinels,
        [Parameter(Mandatory)][string]$Id
    )

    foreach ($sentinel in $Sentinels) {
        Confirm-Check (-not $Text.Contains($sentinel, [System.StringComparison]::OrdinalIgnoreCase)) "$Id-sentinel"
    }
    Confirm-Check (-not [System.Text.RegularExpressions.Regex]::IsMatch(
        $Text,
        "staxrip_session_[0-9a-f]{24}=[0-9a-f]{64}",
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) "$Id-token"
}

function Invoke-HttpCase {
    param(
        [Parameter(Mandatory)]$Bundle,
        [Parameter(Mandatory)][uri]$BaseUri,
        [Parameter(Mandatory)][string]$Route,
        [string]$Method = "GET",
        [string]$HostHeader,
        [string[]]$OriginValues,
        [string[]]$ClientHeaderValues,
        [hashtable]$AdditionalHeaders,
        [string]$BodyText,
        [string]$ContentTypeText = "text/plain",
        [switch]$Chunked,
        [ValidateSet("none", "one", "ignore")][string]$CookieExpectation = "none",
        [Parameter(Mandatory)][string[]]$PrivacySentinels
    )

    $script:CurrentCheck = "http-uri-create"
    $requestUri = [uri]::new($BaseUri, $Route)
    $script:CurrentCheck = "http-request-create"
    $request = [System.Net.Http.HttpRequestMessage]::new(
        [System.Net.Http.HttpMethod]::new($Method),
        $requestUri)
    try {
        $script:CurrentCheck = "http-request-headers"
        if ([string]::IsNullOrEmpty($HostHeader)) {
            $request.Headers.Host = $BaseUri.Authority
        }
        else {
            $request.Headers.Host = $HostHeader
        }

        if ($null -ne $OriginValues) {
            foreach ($origin in $OriginValues) {
                [void]$request.Headers.TryAddWithoutValidation("Origin", $origin)
            }
        }
        if ($null -ne $ClientHeaderValues) {
            foreach ($clientHeader in $ClientHeaderValues) {
                [void]$request.Headers.TryAddWithoutValidation("X-StaxRip-Client", $clientHeader)
            }
        }
        if ($null -ne $AdditionalHeaders) {
            foreach ($header in $AdditionalHeaders.GetEnumerator()) {
                [void]$request.Headers.TryAddWithoutValidation([string]$header.Key, [string]$header.Value)
            }
        }

        if ($PSBoundParameters.ContainsKey("BodyText")) {
            $request.Content = [System.Net.Http.ByteArrayContent]::new(
                [System.Text.Encoding]::UTF8.GetBytes($BodyText))
            $request.Content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($ContentTypeText)
        }
        if ($Chunked) {
            if ($null -eq $request.Content) {
                $request.Content = [System.Net.Http.ByteArrayContent]::new([byte[]]::new(0))
            }
            $request.Headers.TransferEncodingChunked = $true
        }

        $script:CurrentCheck = "http-send"
        $response = $Bundle.Client.SendAsync(
            $request,
            [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        try {
            $script:CurrentCheck = "http-response-body"
            $body = Read-BoundedResponseBody $response
            $script:CurrentCheck = "http-response-headers"
            $headers = Get-ResponseHeaders $response
            $setCookieValues = $null
            if ($response.Headers.TryGetValues("Set-Cookie", [ref]$setCookieValues)) {
                $setCookieValues = @($setCookieValues)
            }
            else {
                $setCookieValues = @()
            }

            $cookieName = $null
            if ($CookieExpectation -eq "one") {
                $cookieName = Test-SetCookieStructure $setCookieValues
            }
            elseif ($CookieExpectation -eq "none") {
                Confirm-Check ($setCookieValues.Count -eq 0) "cookie-root-only"
            }

            $script:CurrentCheck = "http-response-policy"
            Confirm-NoCorsPermission $headers
            Confirm-SecurityHeaders $headers
            $script:CurrentCheck = "http-response-privacy"
            Confirm-PrivacyText $body $PrivacySentinels "response-privacy"
            $setCookieValues = $null

            return [pscustomobject]@{
                Status = [int]$response.StatusCode
                Body = $body
                Headers = $headers
                CookieName = $cookieName
            }
        }
        finally {
            $response.Dispose()
        }
    }
    finally {
        $request.Dispose()
    }
}

function Confirm-JsonKeys {
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string[]]$Expected,
        [Parameter(Mandatory)][string]$Id
    )

    $actual = @($Object.PSObject.Properties.Name | Sort-Object)
    $wanted = @($Expected | Sort-Object)
    Confirm-Check (($actual -join "|") -ceq ($wanted -join "|")) $Id
}

function Confirm-ErrorResponse {
    param(
        [Parameter(Mandatory)]$Result,
        [Parameter(Mandatory)][int]$Status,
        [Parameter(Mandatory)][string]$Code,
        [Parameter(Mandatory)][string]$Message,
        [switch]$AllowEmptyBody
    )

    Confirm-Check ($Result.Status -eq $Status) "error-status-$Status"
    if ($AllowEmptyBody -and $Status -eq 405 -and $Result.Body.Length -eq 0) {
        return
    }
    Confirm-Check ($Result.Body.Length -gt 0) "error-body-present"
    $payload = $Result.Body | ConvertFrom-Json
    Confirm-JsonKeys $payload @("schemaVersion", "apiVersion", "error") "error-root-keys"
    Confirm-JsonKeys $payload.error @("code", "message") "error-detail-keys"
    Confirm-Check ($payload.schemaVersion -ceq "1") "error-schema"
    Confirm-Check ($payload.apiVersion -ceq "v1") "error-api"
    Confirm-Check ($payload.error.code -ceq $Code) "error-code-$Code"
    Confirm-Check ($payload.error.message -ceq $Message) "error-message"
}

function Confirm-HealthResponse {
    param([Parameter(Mandatory)]$Result)
    Confirm-Check ($Result.Status -eq 200) "health-status"
    $payload = $Result.Body | ConvertFrom-Json
    Confirm-JsonKeys $payload @("schemaVersion", "apiVersion", "engineVersion", "status") "health-keys"
    Confirm-Check ($payload.schemaVersion -ceq "1") "health-schema"
    Confirm-Check ($payload.apiVersion -ceq "v1") "health-api"
    Confirm-Check ($payload.engineVersion -ceq "0.1.0-bootstrap") "health-engine"
    Confirm-Check ($payload.status -ceq "ready") "health-ready"
}

function Confirm-CapabilityResponse {
    param([Parameter(Mandatory)]$Result)
    Confirm-Check ($Result.Status -eq 200) "capability-status"
    $payload = $Result.Body | ConvertFrom-Json
    Confirm-JsonKeys $payload @("schemaVersion", "apiVersion", "engineVersion", "host", "features", "tools") "capability-root-keys"
    Confirm-JsonKeys $payload.host @("platformId", "architectureId", "runtimeVersion", "logicalProcessorCount") "capability-host-keys"
    Confirm-Check ($payload.features.Count -eq 8) "capability-feature-count"
    Confirm-Check ($payload.tools.Count -eq 6) "capability-tool-count"

    $unavailable = @("media-inspection", "encoding", "persistence", "remote-access", "plugins", "project-import")
    foreach ($id in $unavailable) {
        $row = @($payload.features | Where-Object { $_.id -ceq $id })
        Confirm-Check ($row.Count -eq 1) "capability-unavailable-id"
        Confirm-Check ($row[0].availability -ceq "unavailable") "capability-unavailable-state"
    }
    foreach ($tool in $payload.tools) {
        Confirm-Check ($tool.compatibility -ceq "unverified") "capability-tool-unverified"
    }
}

function Convert-RawResponse {
    param([Parameter(Mandatory)][byte[]]$Bytes)

    $text = [System.Text.Encoding]::UTF8.GetString($Bytes)
    $separator = $text.IndexOf("`r`n`r`n", [System.StringComparison]::Ordinal)
    Confirm-Check ($separator -gt 0) "raw-header-boundary"
    $head = $text.Substring(0, $separator)
    $body = $text.Substring($separator + 4)
    $lines = $head.Split("`r`n", [System.StringSplitOptions]::None)
    Confirm-Check ($lines[0] -match "^HTTP/1\.[01] ([0-9]{3})(?: |$)") "raw-status-line"
    $status = [int]$Matches[1]
    $headers = [System.Collections.Generic.Dictionary[string, string[]]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($line in $lines[1..($lines.Count - 1)]) {
        $colon = $line.IndexOf(':')
        if ($colon -le 0) { continue }
        $name = $line.Substring(0, $colon).Trim()
        $value = $line.Substring($colon + 1).Trim()
        if ($headers.ContainsKey($name)) {
            $headers[$name] = @($headers[$name]) + @($value)
        }
        else {
            $headers[$name] = @($value)
        }
    }
    return [pscustomobject]@{ Status = $status; Headers = $headers; Body = $body }
}

function Invoke-RawCase {
    param(
        [Parameter(Mandatory)][int]$Port,
        [Parameter(Mandatory)][string]$RequestText,
        [Parameter(Mandatory)][string[]]$PrivacySentinels
    )

    $client = [System.Net.Sockets.TcpClient]::new([System.Net.Sockets.AddressFamily]::InterNetwork)
    try {
        $connect = $client.ConnectAsync([System.Net.IPAddress]::Loopback, $Port)
        Confirm-Check ($connect.Wait([System.TimeSpan]::FromSeconds(5))) "raw-connect-timeout"
        $stream = $client.GetStream()
        try {
            $stream.ReadTimeout = 5000
            $stream.WriteTimeout = 5000
            $requestBytes = [System.Text.Encoding]::ASCII.GetBytes($RequestText)
            $stream.Write($requestBytes, 0, $requestBytes.Length)
            $stream.Flush()
            $memory = [System.IO.MemoryStream]::new()
            try {
                $buffer = [byte[]]::new(4096)
                while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    if (($memory.Length + $read) -gt $maximumResponseBytes) {
                        throw [System.InvalidOperationException]::new("CHECK:raw-response-bound")
                    }
                    $memory.Write($buffer, 0, $read)
                }
                $result = Convert-RawResponse $memory.ToArray()
            }
            finally {
                $memory.Dispose()
            }
        }
        finally {
            $stream.Dispose()
        }
    }
    finally {
        $client.Dispose()
    }

    Confirm-NoCorsPermission $result.Headers
    Confirm-PrivacyText $result.Body $PrivacySentinels "raw-privacy"
    return $result
}

function New-HostileWorkingDirectory {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Sentinel
    )

    [void][System.IO.Directory]::CreateDirectory($Path)
    foreach ($name in @("home", "tmp", "xdg-config", "xdg-cache", "xdg-data", "wwwroot")) {
        [void][System.IO.Directory]::CreateDirectory((Join-Path $Path $name))
    }
    [System.IO.File]::WriteAllText(
        (Join-Path $Path "appsettings.json"),
        "{`"Urls`":`"http://0.0.0.0:61231`",`"Sentinel`":`"$Sentinel`"}",
        [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText(
        (Join-Path $Path "wwwroot\index.html"),
        "<!doctype html><title>$Sentinel</title>",
        [System.Text.UTF8Encoding]::new($false))
}

function New-CheckException {
    param(
        [Parameter(Mandatory)][ValidatePattern("^[a-z0-9][a-z0-9-]{1,79}$")][string]$Id,
        [System.Exception]$Cause
    )

    if ($null -eq $Cause) {
        return [System.InvalidOperationException]::new("CHECK:$Id")
    }
    return [System.InvalidOperationException]::new("CHECK:$Id", $Cause)
}

function Set-ServerCleanupFailure {
    param(
        [Parameter(Mandatory)]$Server,
        [Parameter(Mandatory)][ValidatePattern("^[a-z0-9][a-z0-9-]{1,79}$")][string]$Id,
        [System.Exception]$Cause
    )

    if ($null -eq $Server.CleanupException) {
        $Server.CleanupCheck = $Id
        $Server.CleanupException = New-CheckException $Id $Cause
    }
}

function Set-OuterCleanupFailure {
    param(
        [Parameter(Mandatory)][ValidatePattern("^[a-z0-9][a-z0-9-]{1,79}$")][string]$Id,
        [System.Exception]$Cause
    )

    if ($null -eq $script:OuterCleanupException) {
        $script:OuterCleanupCheck = $Id
        $script:OuterCleanupException = New-CheckException $Id $Cause
    }
}

function Set-ServerConsoleFailure {
    param(
        [Parameter(Mandatory)]$Server,
        [Parameter(Mandatory)][System.Exception]$Exception
    )

    if ($null -eq $Server.ConsoleException) {
        $check = "server-console-policy"
        $cause = $Exception
        for ($depth = 0; $depth -lt 8; $depth++) {
            if ($cause.Message -cmatch '^CHECK:([a-z0-9][a-z0-9-]{1,79})$') {
                $check = $Matches[1]
            }
            if ($null -eq $cause.InnerException) { break }
            $cause = $cause.InnerException
        }
        $Server.ConsoleCheck = $check
        $Server.ConsoleException = $Exception
    }
}

function Complete-ServerCollector {
    param(
        [Parameter(Mandatory)]$Server,
        [Parameter(Mandatory)][ValidateSet("stdout", "stderr")][string]$StreamName
    )

    $collectorProperty = if ($StreamName -ceq "stdout") { "StdoutCollector" } else { "StderrCollector" }
    $reader = if ($StreamName -ceq "stdout") { $Server.Process.StandardOutput } else { $Server.Process.StandardError }
    $collector = $Server.$collectorProperty
    if ($null -eq $collector) {
        Set-ServerCleanupFailure $Server "server-$StreamName-collector-missing"
        return
    }

    $completed = $false
    try {
        $completed = $collector.Completion.Wait([System.TimeSpan]::FromSeconds(5))
    }
    catch {
        Set-ServerCleanupFailure $Server "server-$StreamName-read" $_.Exception
        $completed = $collector.Completion.IsCompleted
    }
    if (-not $completed) {
        Set-ServerCleanupFailure $Server "server-$StreamName-drain-timeout"
        try {
            $reader.Dispose()
        }
        catch {
            Set-ServerCleanupFailure $Server "server-$StreamName-reader-dispose" $_.Exception
        }
        try {
            [void]$collector.Completion.Wait([System.TimeSpan]::FromSeconds(1))
        }
        catch {
            if ($null -eq $Server.CleanupException) {
                Set-ServerCleanupFailure $Server "server-$StreamName-read" $_.Exception
            }
        }
    }

    if ($collector.Completion.IsCompletedSuccessfully) {
        try {
            [void]$collector.Completion.GetAwaiter().GetResult()
            if ($StreamName -ceq "stdout") {
                $Server.StdoutDrained = $true
                $Server.StdoutCharacters = $collector.TotalCharacters
                $Server.StdoutOverflowed = $collector.Overflowed
            }
            else {
                $Server.StderrDrained = $true
                $Server.StderrCharacters = $collector.TotalCharacters
                $Server.StderrOverflowed = $collector.Overflowed
            }
            $script:CheckCount++
        }
        catch {
            Set-ServerCleanupFailure $Server "server-$StreamName-read" $_.Exception
        }
    }
    elseif ($collector.Completion.IsFaulted) {
        try {
            [void]$collector.Completion.GetAwaiter().GetResult()
        }
        catch {
            Set-ServerCleanupFailure $Server "server-$StreamName-read" $_.Exception
        }
    }
}

function Invoke-ServerCleanup {
    param([Parameter(Mandatory)]$Server)

    if ($Server.ProcessDisposed) {
        return
    }

    $Server.CleanupAttempted = $true
    $process = $Server.Process
    if (-not $Server.Started) {
        try {
            $process.Dispose()
            $Server.ProcessDisposed = $true
            $Server.PortRelease = "not-applicable-process-not-started"
            $Server.Stopped = $true
            $Server.CleanupComplete = $true
            $script:CheckCount++
        }
        catch {
            Set-ServerCleanupFailure $Server "server-unstarted-process-dispose" $_.Exception
        }
        return
    }

    $hasExited = $false
    try {
        $hasExited = $process.HasExited
    }
    catch {
        Set-ServerCleanupFailure $Server "server-process-state-read" $_.Exception
    }

    if (-not $hasExited) {
        try {
            $actualPath = Get-FullPath $process.MainModule.FileName
            $actualStartTimeUtc = $process.StartTime.ToUniversalTime()
            if (-not $Server.IdentityCaptured -or
                $process.Id -ne $Server.ProcessId -or
                $actualStartTimeUtc.Ticks -ne $Server.ProcessStartTimeUtc.Ticks -or
                -not [string]::Equals(
                    $actualPath,
                    $Server.ExecutablePath,
                    [System.StringComparison]::OrdinalIgnoreCase)) {
                Set-ServerCleanupFailure $Server "server-process-identity"
            }
            else {
                $Server.IdentityRevalidated = $true
                $script:CheckCount++
            }
        }
        catch {
            Set-ServerCleanupFailure $Server "server-process-identity" $_.Exception
        }

        # Windows exposes no non-HTTP graceful signal for this hidden child. The gate
        # owns the exact Process handle and terminates its complete descendant tree.
        $Server.KillAttempted = $true
        try {
            $process.Kill($true)
            $Server.KillSucceeded = $true
            $script:CheckCount++
        }
        catch {
            Set-ServerCleanupFailure $Server "server-kill-tree" $_.Exception
        }
    }

    try {
        if ($process.WaitForExit(10000)) {
            $Server.Reaped = $true
            $Server.ExitCode = $process.ExitCode
            $script:CheckCount++
        }
        else {
            Set-ServerCleanupFailure $Server "server-exit-timeout"
        }
    }
    catch {
        Set-ServerCleanupFailure $Server "server-exit-wait" $_.Exception
    }

    Complete-ServerCollector $Server "stdout"
    Complete-ServerCollector $Server "stderr"

    $observedPort = if ($Server.Port -is [int]) { $Server.Port } else { $Server.CandidatePort }
    if ($Server.Reaped -and $observedPort -is [int]) {
        $probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $observedPort)
        $probe.Server.ExclusiveAddressUse = $true
        try {
            $probe.Start()
            $Server.PortRelease = "passed"
            $script:CheckCount++
        }
        catch {
            $Server.PortRelease = "failed"
            Set-ServerCleanupFailure $Server "server-port-released" $_.Exception
        }
        finally {
            try { $probe.Stop() }
            catch { Set-ServerCleanupFailure $Server "server-port-probe-dispose" $_.Exception }
        }
    }
    elseif ($Server.Reaped) {
        $Server.PortRelease = "not-observed-before-reap"
    }
    else {
        $Server.PortRelease = "blocked-process-not-reaped"
    }

    if ($Server.Reaped) {
        try {
            $process.Dispose()
            $Server.ProcessDisposed = $true
            $script:CheckCount++
        }
        catch {
            Set-ServerCleanupFailure $Server "server-process-dispose" $_.Exception
        }
    }

    $Server.Stopped = $Server.Reaped
    $Server.CleanupComplete =
        $Server.Reaped -and
        $Server.StdoutDrained -and
        $Server.StderrDrained -and
        $Server.PortRelease -cin @("passed", "not-observed-before-reap") -and
        $Server.ProcessDisposed -and
        $null -eq $Server.CleanupException
}

function Confirm-ServerConsole {
    param([Parameter(Mandatory)]$Server)

    Confirm-Check $Server.StdoutDrained "server-stdout-drained"
    Confirm-Check $Server.StderrDrained "server-stderr-drained"
    Confirm-Check (-not $Server.StdoutOverflowed) "server-stdout-bound"
    Confirm-Check (-not $Server.StderrOverflowed) "server-stderr-bound"
    Confirm-Check ($Server.StdoutCharacters -le $maximumConsoleCharacters) "server-stdout-count-bound"
    Confirm-Check ($Server.StderrCharacters -le $maximumConsoleCharacters) "server-stderr-count-bound"

    $stdout = $Server.StdoutCollector.CapturedText
    $stderr = $Server.StderrCollector.CapturedText
    Confirm-Check ($stdout.Length -le $maximumConsoleCharacters) "server-stdout-capture-bound"
    Confirm-Check ($stderr.Length -le $maximumConsoleCharacters) "server-stderr-capture-bound"
    Confirm-Check ($stdout.StartsWith($Server.ReadyLine, [System.StringComparison]::Ordinal)) "server-ready-captured"
    $remainder = $stdout.Substring($Server.ReadyLine.Length)
    Confirm-Check ([string]::IsNullOrWhiteSpace($remainder)) "server-no-extra-stdout"
    Confirm-Check ([string]::IsNullOrWhiteSpace($stderr)) "server-no-stderr"
    Confirm-PrivacyText ($stdout + $stderr) $Server.PrivacySentinels "server-console-privacy"
    Confirm-Check (-not (Test-SensitiveConsoleText ($stdout + $stderr))) "server-console-sensitive-text"
    $Server.ConsoleValidated = $true
}

function Protect-ServerConsoleCapture {
    param([Parameter(Mandatory)]$Server)

    if ($Server.CaptureSanitized) { return }
    if (($null -ne $Server.StdoutCollector -and -not $Server.StdoutCollector.Completion.IsCompleted) -or
        ($null -ne $Server.StderrCollector -and -not $Server.StderrCollector.Completion.IsCompleted)) {
        return
    }
    $stdout = if ($null -ne $Server.StdoutCollector) { $Server.StdoutCollector.CapturedText } else { "" }
    $stderr = if ($null -ne $Server.StderrCollector) { $Server.StderrCollector.CapturedText } else { "" }
    $Server.ConsoleSensitiveDetected = Test-SensitiveConsoleText ($stdout + $stderr)
    [void](ConvertTo-RedactedConsoleText $stdout)
    [void](ConvertTo-RedactedConsoleText $stderr)
    if ($null -ne $Server.ReadyLine) {
        $Server.ReadyLine = ConvertTo-RedactedConsoleText $Server.ReadyLine
    }
    if ($null -ne $Server.StdoutCollector -and $Server.StdoutCollector.Completion.IsCompleted) {
        $Server.StdoutCollector.ClearCapturedText()
    }
    if ($null -ne $Server.StderrCollector -and $Server.StderrCollector.Completion.IsCompleted) {
        $Server.StderrCollector.ClearCapturedText()
    }
    $Server.CaptureSanitized = $true
}

function Test-BoundedConsoleCollector {
    $line = "READY http://127.0.0.1:49152/"
    $overflowText = $line + "`r`n" + ("x" * 96)
    $reader = [System.IO.StringReader]::new($overflowText)
    try {
        $collector = [StaxRip.Verification.BoundedTextCollector]::new($reader, 64)
        Confirm-Check ($collector.FirstLine.Wait([System.TimeSpan]::FromSeconds(1))) "collector-selftest-ready"
        Confirm-Check ($collector.FirstLine.GetAwaiter().GetResult() -ceq $line) "collector-selftest-first-line"
        Confirm-Check ($collector.Completion.Wait([System.TimeSpan]::FromSeconds(1))) "collector-selftest-complete"
        [void]$collector.Completion.GetAwaiter().GetResult()
        Confirm-Check $collector.Overflowed "collector-selftest-overflow"
        Confirm-Check ($collector.TotalCharacters -eq $overflowText.Length) "collector-selftest-total"
        Confirm-Check ($collector.CapturedText.Length -eq 64) "collector-selftest-cap"
    }
    finally {
        $reader.Dispose()
    }

    $boundedText = "alpha`nbeta"
    $boundedReader = [System.IO.StringReader]::new($boundedText)
    try {
        $boundedCollector = [StaxRip.Verification.BoundedTextCollector]::new($boundedReader, 64)
        Confirm-Check ($boundedCollector.Completion.Wait([System.TimeSpan]::FromSeconds(1))) "collector-selftest-bounded-complete"
        [void]$boundedCollector.Completion.GetAwaiter().GetResult()
        Confirm-Check (-not $boundedCollector.Overflowed) "collector-selftest-bounded-no-overflow"
        Confirm-Check ($boundedCollector.CapturedText -ceq $boundedText) "collector-selftest-bounded-text"
    }
    finally {
        $boundedReader.Dispose()
    }

    $sensitiveText = @(
        "Authorization: Bearer synthetic-auth-value",
        "Proxy-Authorization: Basic synthetic-proxy-value",
        "Cookie: session=synthetic-cookie-value",
        "Set-Cookie: session=synthetic-set-cookie-value; HttpOnly",
        (('x' * 40) + " Authorization: Bearer synthetic-long-prefix-value"),
        '{"Authorization":"Bearer synthetic-json-value"}',
        "access_token=synthetic-access-value secret='synthetic-secret-value'"
    ) -join "`r`n"
    Confirm-Check (Test-SensitiveConsoleText $sensitiveText) "redaction-selftest-sensitive-detected"
    # R-S2-045 guard. The combined check above passes if ANY single rule fires, so it
    # cannot notice a deleted rule. Each form below targets a specific rule, and mutation
    # confirmed that removing either newly added rule turns this red. R-S2-036 established
    # why this matters: a widening applied without a per-form guard could be reverted with
    # every check still green.
    #
    # Note that some forms are matched by more than one rule; an earlier version of this
    # comment claimed each was detectable by exactly one, which is not true. A bare scheme
    # on a header line, for example, satisfies both the header rule and the scheme rule.
    # The guard therefore proves the two new rules are load-bearing for the forms only they
    # match, and does not prove one-to-one coverage for every case.
    foreach ($case in @(
            @{ Id = 'header-colon'; Text = 'Authorization: Bearer synthetic-value-aaaaaaaa' },
            @{ Id = 'header-equals'; Text = 'Authorization=synthetic-value-aaaaaaaa' },
            @{ Id = 'cookie-equals'; Text = 'Cookie=session=synthetic-cookie-value' },
            @{ Id = 'scheme-bearer'; Text = 'value printed as Bearer synthetic-token-aaaaaaaa' },
            @{ Id = 'scheme-basic'; Text = 'proxy line Basic c3ludGhldGljOnNlY3JldA==' },
            @{ Id = 'uri-userinfo'; Text = 'endpoint=https://synthetic-user:synthetic-pw@example.invalid/path' },
            @{ Id = 'json-token'; Text = '{"token":"synthetic-json-token"}' },
            @{ Id = 'json-password'; Text = '{"password":"synthetic-json-password"}' },
            @{ Id = 'json-session-cookie'; Text = ('{"staxrip_session_' + ('a' * 24) + '":"synthetic"}') },
            @{ Id = 'assignment-token'; Text = 'access_token=synthetic-assignment' })) {
        Confirm-Check (Test-SensitiveConsoleText $case.Text) ('redaction-selftest-form-' + $case.Id)
    }
    # Widening must not be bought with false positives. Each of these is benign and must
    # stay undetected, including the readiness line the gate itself prints.
    foreach ($safeText in @(
            'READY http://127.0.0.1:49152/',
            'tokenizer=enabled',
            'CookieJar synthetic',
            'https://example.invalid/path')) {
        Confirm-Check (-not (Test-SensitiveConsoleText $safeText)) 'redaction-selftest-near-miss'
    }
    $redactedText = ConvertTo-RedactedConsoleText $sensitiveText
    foreach ($secret in @(
        "synthetic-auth-value",
        "synthetic-proxy-value",
        "synthetic-cookie-value",
        "synthetic-set-cookie-value",
        "synthetic-long-prefix-value",
        "synthetic-json-value",
        "synthetic-access-value",
        "synthetic-secret-value")) {
        Confirm-Check (-not $redactedText.Contains($secret, [System.StringComparison]::Ordinal)) "redaction-selftest-secret-removed"
    }
    Confirm-Check ($redactedText.Contains("Authorization: Bearer <redacted>", [System.StringComparison]::Ordinal)) "redaction-selftest-auth-scheme"
    Confirm-Check ($redactedText.Contains("Proxy-Authorization: Basic <redacted>", [System.StringComparison]::Ordinal)) "redaction-selftest-proxy-scheme"
    Confirm-Check ($redactedText.Contains("Cookie: <redacted>", [System.StringComparison]::Ordinal)) "redaction-selftest-cookie-line"
    Confirm-Check ($redactedText.Contains("Set-Cookie: <redacted>", [System.StringComparison]::Ordinal)) "redaction-selftest-set-cookie-line"
    Confirm-Check ($redactedText.Contains((('x' * 40) + " Authorization: Bearer <redacted>"), [System.StringComparison]::Ordinal)) "redaction-selftest-long-prefix"
    Confirm-Check ($redactedText.Contains("<redacted-sensitive-header-line>", [System.StringComparison]::Ordinal)) "redaction-selftest-json-header"
    Confirm-Check ($redactedText.Contains("access_token=<redacted>", [System.StringComparison]::Ordinal)) "redaction-selftest-token-assignment"
    Confirm-Check ($redactedText.Contains("secret=<redacted>", [System.StringComparison]::Ordinal)) "redaction-selftest-quoted-assignment"
    Confirm-Check (-not (Test-SensitiveConsoleText "READY http://127.0.0.1:49152/")) "redaction-selftest-ready-safe"
}

function Start-TestServer {
    param(
        [Parameter(Mandatory)][string]$Executable,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$Sentinel,
        [switch]$ForceReadyShapeFailure
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Executable
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.ArgumentList.Add("--urls")
    $startInfo.ArgumentList.Add("http://0.0.0.0:61232")
    $startInfo.ArgumentList.Add("--contentRoot")
    $startInfo.ArgumentList.Add($WorkingDirectory)

    $hostileEnvironment = [ordered]@{
        "ASPNETCORE_URLS" = "http://0.0.0.0:61233"
        "ASPNETCORE_HTTP_PORTS" = "61234"
        "ASPNETCORE_HTTPS_PORTS" = "61235"
        "DOTNET_HTTP_PORTS" = "61236"
        "DOTNET_HTTPS_PORTS" = "61237"
        "Kestrel__Endpoints__Hostile__Url" = "http://0.0.0.0:61238"
        "ASPNETCORE_HOSTINGSTARTUPASSEMBLIES" = "Hostile.Startup.Assembly"
        "DOTNET_HOSTINGSTARTUPASSEMBLIES" = "Hostile.Startup.Assembly"
        "ASPNETCORE_PREVENTHOSTINGSTARTUP" = "false"
        "ASPNETCORE_ENVIRONMENT" = "Development"
        "DOTNET_ENVIRONMENT" = "Development"
        "STAXRIP_PRIVACY_SENTINEL" = $Sentinel
        "HOME" = (Join-Path $WorkingDirectory "home")
        "TMP" = (Join-Path $WorkingDirectory "tmp")
        "TEMP" = (Join-Path $WorkingDirectory "tmp")
        "XDG_CONFIG_HOME" = (Join-Path $WorkingDirectory "xdg-config")
        "XDG_CACHE_HOME" = (Join-Path $WorkingDirectory "xdg-cache")
        "XDG_DATA_HOME" = (Join-Path $WorkingDirectory "xdg-data")
    }
    foreach ($item in $hostileEnvironment.GetEnumerator()) {
        $startInfo.Environment[$item.Key] = $item.Value
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo

    # Register the exact Process handle before Start, then mark it started before any
    # readiness, path, identity, or receipt work can fail.
    $server = [pscustomobject]@{
        Process = $process
        Started = $false
        ProcessId = $null
        ProcessStartTimeUtc = $null
        ExecutablePath = $null
        ExpectedExecutablePath = $Executable
        IdentityCaptured = $false
        IdentityRevalidated = $false
        StdoutCollector = $null
        StderrCollector = $null
        StdoutDrained = $false
        StderrDrained = $false
        StdoutCharacters = [long]0
        StderrCharacters = [long]0
        StdoutOverflowed = $false
        StderrOverflowed = $false
        BaseUri = $null
        Port = $null
        CandidatePort = $null
        ReadyLine = $null
        PrivacySentinels = @($Sentinel, $WorkingDirectory)
        ExitCode = $null
        KillAttempted = $false
        KillSucceeded = $false
        Reaped = $false
        PortRelease = "pending"
        ProcessDisposed = $false
        ConsoleValidated = $false
        ConsoleCheck = $null
        ConsoleException = $null
        ConsoleSensitiveDetected = $false
        CaptureSanitized = $false
        CleanupAttempted = $false
        CleanupComplete = $false
        CleanupCheck = $null
        CleanupException = $null
        Stopped = $false
        ExpectedStartupFailure = $ForceReadyShapeFailure.IsPresent
    }
    $script:Servers.Add($server)

    try {
        $started = $process.Start()
        $server.Started = $started
        Confirm-Check $started "server-process-start"

        # Both collectors start before readiness waits so neither redirected pipe can
        # block the producer. They retain at most the configured character cap.
        $server.StdoutCollector = [StaxRip.Verification.BoundedTextCollector]::new(
            $process.StandardOutput,
            $maximumConsoleCharacters)
        $server.StderrCollector = [StaxRip.Verification.BoundedTextCollector]::new(
            $process.StandardError,
            $maximumConsoleCharacters)

        $server.ProcessId = $process.Id
        $server.ProcessStartTimeUtc = $process.StartTime.ToUniversalTime()
        # Read the image the OS actually loaded, not the path we asked it to load. The
        # identity check below previously read StartInfo.FileName, which is the same
        # string as ExpectedExecutablePath, so that one comparison could not fail. (The
        # cleanup path already observed MainModule safely after shutdown; the vacuous
        # comparison was only here.) Tracked as R-S2-024.
        #
        # MainModule is not readable immediately after Start: Windows leaves the module
        # list empty until the target's loader has populated it, .NET then returns null
        # rather than throwing, and strict mode turns the null dereference into a caught
        # exception. Measured on this harness's own launch shape, the list becomes
        # readable roughly ten to sixty milliseconds after start, so a single immediate
        # read fails on almost every run and would kill the gate under an id that claims
        # a different binary was loaded. Poll against a bounded deadline instead; the
        # deadline is generous because exhausting it fails the gate. Ownership must still
        # be captured before readiness, so the poll sits here rather than after the
        # readiness wait.
        $observedImagePath = $null
        $identityDeadline = [System.Diagnostics.Stopwatch]::StartNew()
        while ($identityDeadline.ElapsedMilliseconds -lt 5000) {
            try {
                $mainModule = $process.MainModule
                if ($null -ne $mainModule -and -not [string]::IsNullOrWhiteSpace($mainModule.FileName)) {
                    $observedImagePath = $mainModule.FileName
                    break
                }
            }
            catch { }
            if ($process.HasExited) { break }
            Start-Sleep -Milliseconds 20
        }
        $server.ExecutablePath = if ([string]::IsNullOrWhiteSpace($observedImagePath)) {
            $null
        }
        else {
            Get-FullPath $observedImagePath
        }
        Confirm-Check ($server.ProcessId -gt 0) "server-process-id-captured"
        Confirm-Check ($server.ProcessStartTimeUtc -is [datetime]) "server-process-start-captured"
        Confirm-Check ([string]::Equals(
                $server.ExecutablePath,
                $server.ExpectedExecutablePath,
                [System.StringComparison]::OrdinalIgnoreCase)) "server-process-executable-captured"
        $server.IdentityCaptured = $true

        $readyCompleted = $false
        try {
            $readyCompleted = $server.StdoutCollector.FirstLine.Wait([System.TimeSpan]::FromSeconds(20))
        }
        catch {
            throw (New-CheckException "server-ready-read" $_.Exception)
        }
        if (-not $readyCompleted) {
            throw [System.TimeoutException]::new("CHECK:server-ready-timeout")
        }
        try {
            $readyLine = $server.StdoutCollector.FirstLine.GetAwaiter().GetResult()
        }
        catch {
            throw (New-CheckException "server-ready-read" $_.Exception)
        }
        $server.ReadyLine = $readyLine

        if ($null -ne $readyLine) {
            $candidateMatch = [System.Text.RegularExpressions.Regex]::Match(
                $readyLine,
                "^READY http://127\.0\.0\.1:([1-9][0-9]{0,4})(?:/)?$",
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
            if ($candidateMatch.Success) {
                $candidatePort = [int]$candidateMatch.Groups[1].Value
                if ($candidatePort -le 65535) {
                    $server.CandidatePort = $candidatePort
                }
            }
        }

        $readyMatch = if ($null -eq $readyLine) {
            $null
        }
        else {
            [System.Text.RegularExpressions.Regex]::Match(
                $readyLine,
                "^READY http://127\.0\.0\.1:([1-9][0-9]{0,4})/$",
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
        }
        if ($null -eq $readyMatch -or -not $readyMatch.Success) {
            try {
                if ($process.HasExited) { $script:ProducerExit = $process.ExitCode }
            }
            catch { }
            throw [System.InvalidOperationException]::new("CHECK:server-ready-shape")
        }
        if ($ForceReadyShapeFailure) {
            throw [System.InvalidOperationException]::new("CHECK:server-ready-shape")
        }

        $port = [int]$readyMatch.Groups[1].Value
        Confirm-Check ($port -le 65535) "server-ready-port-range"
        Confirm-Check (-not $process.HasExited) "server-alive-after-ready"
        $server.BaseUri = [uri]$readyLine.Substring("READY ".Length)
        $server.Port = $port
        return $server
    }
    catch {
        $primaryException = $_.Exception
        [void](Invoke-ServerCleanup $server)
        throw $primaryException
    }
}

function Stop-TestServer {
    param([Parameter(Mandatory)]$Server)

    if ($Server.ConsoleValidated) { return }
    $unexpectedExit = $false
    $stateException = $null
    try {
        $unexpectedExit = $Server.Process.HasExited
        if ($unexpectedExit) {
            $script:ProducerExit = $Server.Process.ExitCode
        }
    }
    catch {
        $stateException = New-CheckException "server-process-state-read" $_.Exception
    }

    [void](Invoke-ServerCleanup $Server)
    if ($null -ne $stateException) {
        throw $stateException
    }
    if ($unexpectedExit) {
        throw [System.InvalidOperationException]::new("CHECK:server-unexpected-exit")
    }
    if ($null -ne $Server.CleanupException) {
        throw $Server.CleanupException
    }
    try {
        Confirm-ServerConsole $Server
        Protect-ServerConsoleCapture $Server
    }
    catch {
        Set-ServerConsoleFailure $Server $_.Exception
        throw
    }
}

function Test-StartupFailureCleanup {
    param(
        [Parameter(Mandatory)][string]$Executable,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$Sentinel
    )

    $serverCountBefore = $script:Servers.Count
    $caughtCheck = $null
    try {
        [void](Start-TestServer $Executable $WorkingDirectory $Sentinel -ForceReadyShapeFailure)
        throw (New-CheckException "startup-selftest-fault-not-activated")
    }
    catch {
        $cause = $_.Exception
        for ($depth = 0; $depth -lt 8; $depth++) {
            if ($cause.Message -cmatch '^CHECK:([a-z0-9][a-z0-9-]{1,79})$') {
                $caughtCheck = $Matches[1]
            }
            if ($null -eq $cause.InnerException) { break }
            $cause = $cause.InnerException
        }
    }
    Confirm-Check ($caughtCheck -ceq "server-ready-shape") "startup-selftest-primary-preserved"
    Confirm-Check ($script:Servers.Count -eq ($serverCountBefore + 1)) "startup-selftest-owned-record"
    $server = $script:Servers[$script:Servers.Count - 1]
    Confirm-Check $server.Started "startup-selftest-started"
    Confirm-Check $server.IdentityCaptured "startup-selftest-identity"
    Confirm-Check $server.CleanupAttempted "startup-selftest-cleanup-attempted"
    Confirm-Check $server.KillAttempted "startup-selftest-kill-attempted"
    Confirm-Check $server.KillSucceeded "startup-selftest-kill-succeeded"
    Confirm-Check $server.Reaped "startup-selftest-reaped"
    Confirm-Check $server.StdoutDrained "startup-selftest-stdout-drained"
    Confirm-Check $server.StderrDrained "startup-selftest-stderr-drained"
    Confirm-Check ($server.PortRelease -ceq "passed") "startup-selftest-port-released"
    Confirm-Check $server.ProcessDisposed "startup-selftest-process-disposed"
    Confirm-Check $server.CleanupComplete "startup-selftest-cleanup-complete"
    Protect-ServerConsoleCapture $server
    Confirm-Check $server.CaptureSanitized "startup-selftest-console-sanitized"
}

function Write-FailurePacket {
    param(
        [Parameter(Mandatory)][string]$FailureRoot,
        [Parameter(Mandatory)][System.Exception]$Exception
    )

    $primaryCheck = $script:CurrentCheck
    Assert-EvidencePublicationReady
    $outerType = $Exception.GetType().Name
    $cause = $Exception
    for ($depth = 0; $depth -lt 8 -and $null -ne $cause.InnerException; $depth++) {
        $cause = $cause.InnerException
    }
    $causeType = $cause.GetType().Name
    $causeCode = if ($cause -is [System.Net.Sockets.SocketException]) {
        [string]$cause.SocketErrorCode
    }
    elseif ($cause -is [System.Net.Http.HttpRequestException]) {
        [string]$cause.HttpRequestError
    }
    else {
        'none'
    }
    $ownedServers = @($script:Servers)
    $consolePolicyServers = @($ownedServers | Where-Object { -not $_.ExpectedStartupFailure })
    $cleanupFailures = @($ownedServers | Where-Object { $null -ne $_.CleanupException })
    $consoleFailures = @($consolePolicyServers | Where-Object { $null -ne $_.ConsoleException })
    $cleanupCheck = if ($cleanupFailures.Count -gt 0) {
        [string]$cleanupFailures[0].CleanupCheck
    }
    elseif ($null -ne $script:OuterCleanupException) {
        [string]$script:OuterCleanupCheck
    }
    else {
        'none'
    }
    $cleanupExceptionType = if ($cleanupFailures.Count -gt 0) {
        $cleanupFailures[0].CleanupException.GetType().Name
    }
    elseif ($null -ne $script:OuterCleanupException) {
        $script:OuterCleanupException.GetType().Name
    }
    else {
        'none'
    }
    $taskCleanupComplete =
        -not $script:OwnedTaskCreated -or
        $script:TaskCleanupResult -ceq "passed"
    $cleanupPassed =
        $cleanupFailures.Count -eq 0 -and
        $null -eq $script:OuterCleanupException -and
        @($ownedServers | Where-Object { -not $_.CleanupComplete }).Count -eq 0 -and
        $taskCleanupComplete
    try {
        Confirm-NoReparseComponents $FailureRoot $crossPlatformRoot "failure-root-precreate-no-reparse"
        [void][System.IO.Directory]::CreateDirectory($FailureRoot)
        Confirm-NoReparseComponents $FailureRoot $crossPlatformRoot "failure-root-created-no-reparse"
        $safeConfiguration = $Configuration.ToLowerInvariant()
        $packetPath = Join-Path $FailureRoot "port-http-windows-$safeConfiguration.json"
        Confirm-NoReparseComponents $packetPath $crossPlatformRoot "failure-leaf-no-reparse"
        $packet = [ordered]@{
            gate = $gateId
            check = $primaryCheck
            exceptionType = $outerType
            causeType = $causeType
            causeCode = $causeCode
            producerExit = $script:ProducerExit
            configuration = $Configuration
            elapsedMs = $startedAt.ElapsedMilliseconds
            replay = "pwsh -NoProfile -NonInteractive -File CrossPlatform/eng/Verify-Http.ps1 -Configuration $Configuration"
            cleanupResult = if ($cleanupPassed) { "passed" } else { "failed" }
            cleanupComplete = $cleanupPassed
            cleanupCheck = $cleanupCheck
            cleanupExceptionType = $cleanupExceptionType
            taskCleanupResult = $script:TaskCleanupResult
            registeredProcessCount = $ownedServers.Count
            ownedProcessCount = @($ownedServers | Where-Object { $_.Started }).Count
            reapedProcessCount = @($ownedServers | Where-Object { $_.Reaped }).Count
            disposedProcessCount = @($ownedServers | Where-Object { $_.ProcessDisposed }).Count
            stdoutDrainedProcessCount = @($ownedServers | Where-Object { $_.StdoutDrained }).Count
            stderrDrainedProcessCount = @($ownedServers | Where-Object { $_.StderrDrained }).Count
            stdoutOverflowProcessCount = @($ownedServers | Where-Object { $_.StdoutOverflowed }).Count
            stderrOverflowProcessCount = @($ownedServers | Where-Object { $_.StderrOverflowed }).Count
            consolePolicyResult = if ($consoleFailures.Count -gt 0) { "failed" } elseif ($consolePolicyServers.Count -eq 0) { "not-applicable-no-runtime-server" } elseif (@($consolePolicyServers | Where-Object { $_.ConsoleValidated }).Count -eq $consolePolicyServers.Count) { "passed" } else { "not-exercised-for-unready-process" }
            consolePolicyCheck = if ($consoleFailures.Count -gt 0) { [string]$consoleFailures[0].ConsoleCheck } else { "none" }
            sensitiveConsoleProcessCount = @($ownedServers | Where-Object { $_.ConsoleSensitiveDetected }).Count
            sanitizedConsoleProcessCount = @($ownedServers | Where-Object { $_.CaptureSanitized }).Count
            observedPortCount = @($ownedServers | Where-Object { $_.Port -is [int] -or $_.CandidatePort -is [int] }).Count
            releasedPortCount = @($ownedServers | Where-Object { $_.PortRelease -ceq "passed" }).Count
            unobservedPortCount = @($ownedServers | Where-Object { $_.PortRelease -ceq "not-observed-before-reap" }).Count
            stdoutRetained = $false
            stderrRetained = $false
            cookieRetained = $false
        } | ConvertTo-Json -Compress
        Write-AtomicUtf8Artifact -Path $packetPath -Content $packet
    }
    finally {
        $script:CurrentCheck = $primaryCheck
    }
}

function Assert-FailureCleanupState {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][ValidatePattern("^[a-z0-9][a-z0-9-]{1,79}$")][string]$Id
    )

    $script:CurrentCheck = $Id
    if (-not $Condition) {
        throw [System.InvalidOperationException]::new("CHECK:$Id")
    }
}

function Remove-OwnFailurePacket {
    param(
        [Parameter(Mandatory)][string]$ArtifactsRoot,
        [Parameter(Mandatory)][string]$FailureRoot
    )

    Assert-EvidencePublicationReady
    $failureDirectoryName = [System.IO.Path]::GetFileName($FailureRoot)
    Assert-FailureCleanupState `
        ([string]::Equals($failureDirectoryName, "failures", [System.StringComparison]::Ordinal)) `
        "http-failure-cleanup-root-name"
    Assert-FailureCleanupState `
        (Test-SafeArtifactDirectory -Path $ArtifactsRoot) `
        "http-failure-cleanup-artifacts-root-safe"

    $failureRootMatches = @(Get-ChildItem -LiteralPath $ArtifactsRoot -Force | Where-Object {
            [string]::Equals($_.Name, $failureDirectoryName, [System.StringComparison]::Ordinal)
        })
    Assert-FailureCleanupState `
        ($failureRootMatches.Count -le 1) `
        "http-failure-cleanup-root-unique"
    if ($failureRootMatches.Count -eq 0) {
        return
    }

    $failureRootItem = $failureRootMatches[0]
    Assert-FailureCleanupState `
        $failureRootItem.PSIsContainer `
        "http-failure-cleanup-root-directory"
    Assert-FailureCleanupState `
        (($failureRootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) `
        "http-failure-cleanup-root-no-reparse"
    Assert-FailureCleanupState `
        ([string]::Equals(
            (Get-FullPath $failureRootItem.FullName),
            (Get-FullPath $FailureRoot),
            [System.StringComparison]::OrdinalIgnoreCase)) `
        "http-failure-cleanup-root-path"
    Assert-FailureCleanupState `
        (Test-SafeArtifactDirectory -Path $FailureRoot) `
        "http-failure-cleanup-root-safe"

    $failureLeaf = "port-http-windows-$($Configuration.ToLowerInvariant()).json"
    $failureMatches = @(Get-ChildItem -LiteralPath $FailureRoot -Force | Where-Object {
            [string]::Equals($_.Name, $failureLeaf, [System.StringComparison]::Ordinal)
        })
    Assert-FailureCleanupState `
        ($failureMatches.Count -le 1) `
        "http-failure-cleanup-leaf-unique"
    if ($failureMatches.Count -eq 0) {
        return
    }

    $failureItem = $failureMatches[0]
    $expectedFailurePath = Get-FullPath (Join-Path $FailureRoot $failureLeaf)
    Assert-FailureCleanupState `
        ([string]::Equals(
            (Get-FullPath $failureItem.FullName),
            $expectedFailurePath,
            [System.StringComparison]::OrdinalIgnoreCase)) `
        "http-failure-cleanup-leaf-path"
    Assert-FailureCleanupState `
        (-not $failureItem.PSIsContainer) `
        "http-failure-cleanup-leaf-not-directory"
    Assert-FailureCleanupState `
        (($failureItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) `
        "http-failure-cleanup-leaf-no-reparse"
    Assert-FailureCleanupState `
        (Test-SafeExistingLeaf -Path $failureItem.FullName -AllowedRoot $FailureRoot) `
        "http-failure-cleanup-leaf-safe"

    $script:CurrentCheck = "http-failure-cleanup-leaf-delete"
    [System.IO.File]::Delete($failureItem.FullName)

    $remainingMatches = @(Get-ChildItem -LiteralPath $FailureRoot -Force | Where-Object {
            [string]::Equals($_.Name, $failureLeaf, [System.StringComparison]::Ordinal)
        })
    Assert-FailureCleanupState `
        ($remainingMatches.Count -eq 0) `
        "http-failure-cleanup-leaf-removed"
}

$crossPlatformRoot = Get-FullPath (Join-Path $PSScriptRoot "..")
$artifactsRoot = Get-FullPath (Join-Path $crossPlatformRoot "artifacts")
$taskRoot = Get-FullPath (Join-Path $artifactsRoot "tmp\port-http")
$failureRoot = Get-FullPath (Join-Path $artifactsRoot "failures")
$evidenceRoot = Get-FullPath (Join-Path $artifactsRoot "evidence")
$auditPath = Get-FullPath (Join-Path $evidenceRoot "evidence-audit.json")
$auditSidecarPath = Get-FullPath (Join-Path $evidenceRoot "evidence-audit.json.sha256")
$evidenceLeasePath = Get-FullPath (Join-Path $evidenceRoot ".evidence-writer.lock")
$runLeaf = "run-" + [System.Guid]::NewGuid().ToString("N")
$runDirectory = Join-Path $taskRoot $runLeaf
$cleanupAllowed = $false
$bodyCompleted = $false
$primaryException = $null
$primaryCheck = $null
$evidenceLeaseStartupReady = $false

try {
    Enter-EvidenceWriterLease
    Invalidate-EvidenceAudit
    Assert-EvidencePublicationReady
    $evidenceLeaseStartupReady = $true

    if ([string]::IsNullOrWhiteSpace($ServerPath)) {
        $pivot = $Configuration.ToLowerInvariant()
        $ServerPath = Join-Path $artifactsRoot "bin\StaxRip.Server\$pivot\StaxRip.Server.exe"
    }
    $ServerPath = Get-FullPath $ServerPath
    Confirm-Check ([System.IO.File]::Exists($ServerPath)) "server-apphost-exists"
    Confirm-Check ([System.IO.Path]::GetFileName($ServerPath) -ceq "StaxRip.Server.exe") "server-apphost-name"
    Test-BoundedConsoleCollector

    Confirm-NoReparseComponents $taskRoot $crossPlatformRoot "task-root-precreate-no-reparse"
    [void][System.IO.Directory]::CreateDirectory($taskRoot)
    Confirm-NoReparseComponents $taskRoot $crossPlatformRoot "task-root-created-no-reparse"
    Confirm-Check (@(Get-ChildItem -LiteralPath $taskRoot -Force).Count -eq 0) "task-root-empty"
    $runDirectory = Confirm-DescendantPath $runDirectory $taskRoot "run-directory-scope"
    [void][System.IO.Directory]::CreateDirectory($runDirectory)
    $cleanupAllowed = $true
    $script:OwnedTaskCreated = $true
    $script:TaskCleanupResult = "pending"
    Confirm-NoReparseComponents $runDirectory $crossPlatformRoot "run-directory-created-no-reparse"

    $sentinel = "SR_PRIVACY_" + [System.Guid]::NewGuid().ToString("N")
    $workDirectories = @(
        (Join-Path $runDirectory "instance-one"),
        (Join-Path $runDirectory "instance-two"),
        (Join-Path $runDirectory "instance-three")
    )
    foreach ($workDirectory in $workDirectories) {
        New-HostileWorkingDirectory $workDirectory $sentinel
    }
    $privacySentinels = @($sentinel, $runDirectory, $workDirectories)
    $binaryDirectory = Split-Path -Parent $ServerPath
    $binaryBefore = Get-TreeSnapshot $binaryDirectory
    $startupWorkBefore = Get-TreeSnapshot $runDirectory
    Test-StartupFailureCleanup $ServerPath $workDirectories[0] $sentinel
    $startupWorkAfter = Get-TreeSnapshot $runDirectory
    Compare-Snapshot $startupWorkBefore $startupWorkAfter "startup-selftest-working-tree"
    $binaryAfterStartupSelfTest = Get-TreeSnapshot $binaryDirectory
    Compare-Snapshot $binaryBefore $binaryAfterStartupSelfTest "startup-selftest-binary-tree"
    $workBefore = Get-TreeSnapshot $runDirectory

    $serverOne = Start-TestServer $ServerPath $workDirectories[0] $sentinel
    $authority = $serverOne.BaseUri.GetLeftPart([System.UriPartial]::Authority)
    Confirm-Check ($serverOne.BaseUri.Scheme -ceq "http") "authority-http"
    Confirm-Check ($serverOne.BaseUri.Host -ceq "127.0.0.1") "authority-ipv4-loopback"
    Confirm-Check ($serverOne.BaseUri.AbsolutePath -ceq "/") "authority-root-path"
    Confirm-Check (@(61231, 61232, 61233, 61234, 61235, 61236, 61237, 61238) -notcontains $serverOne.Port) "authority-hostile-config-ignored"

    $script:CurrentCheck = "client-create-anonymous"
    $anonymous = New-ClientBundle
    $script:CurrentCheck = "client-create-session"
    $sessionOne = New-ClientBundle

    $script:CurrentCheck = "health-request"
    $health = Invoke-HttpCase $anonymous $serverOne.BaseUri "/healthz" -PrivacySentinels $privacySentinels
    Confirm-HealthResponse $health
    $css = Invoke-HttpCase $anonymous $serverOne.BaseUri "/app.css" -PrivacySentinels $privacySentinels
    Confirm-Check ($css.Status -eq 200) "route-css-status"
    Confirm-Check ($css.Body.Contains(".shell", [System.StringComparison]::Ordinal)) "route-css-marker"
    $javascript = Invoke-HttpCase $anonymous $serverOne.BaseUri "/app.js" -PrivacySentinels $privacySentinels
    Confirm-Check ($javascript.Status -eq 200) "route-js-status"
    Confirm-Check ($javascript.Body.Contains("X-StaxRip-Client", [System.StringComparison]::Ordinal)) "route-js-marker"
    $unauthorized = Invoke-HttpCase $anonymous $serverOne.BaseUri "/api/v1/capabilities" -ClientHeaderValues @("web") -PrivacySentinels $privacySentinels
    Confirm-ErrorResponse $unauthorized 401 "unauthorized" "Authorization is required."
    $root = Invoke-HttpCase $sessionOne $serverOne.BaseUri "/" -CookieExpectation one -PrivacySentinels $privacySentinels
    Confirm-Check ($root.Status -eq 200) "route-root-status"
    Confirm-Check ($root.Body.Contains('data-app-marker="staxrip-local-engine-shell"', [System.StringComparison]::Ordinal)) "route-root-marker"
    $cookieNameOne = $root.CookieName
    $capabilities = Invoke-HttpCase $sessionOne $serverOne.BaseUri "/api/v1/capabilities" -ClientHeaderValues @("web") -PrivacySentinels $privacySentinels
    Confirm-CapabilityResponse $capabilities

    $wrongSession = New-ClientBundle
    $wrongSession.Container.Add($serverOne.BaseUri, [System.Net.Cookie]::new($cookieNameOne, ("0" * 64), "/api/v1"))
    $wrong = Invoke-HttpCase $wrongSession $serverOne.BaseUri "/api/v1/capabilities" -ClientHeaderValues @("web") -PrivacySentinels $privacySentinels
    Confirm-ErrorResponse $wrong 401 "unauthorized" "Authorization is required."

    $wrongNameSession = New-ClientBundle
    $wrongNameSession.Container.Add($serverOne.BaseUri, [System.Net.Cookie]::new("staxrip_session_000000000000000000000000", ("0" * 64), "/api/v1"))
    $wrongName = Invoke-HttpCase $wrongNameSession $serverOne.BaseUri "/api/v1/capabilities" -ClientHeaderValues @("web") -PrivacySentinels $privacySentinels
    Confirm-ErrorResponse $wrongName 401 "unauthorized" "Authorization is required."

    $duplicateSession = New-ClientBundle
    $duplicateRoot = Invoke-HttpCase $duplicateSession $serverOne.BaseUri "/" -CookieExpectation one -PrivacySentinels $privacySentinels
    Confirm-Check ($duplicateRoot.CookieName -ceq $cookieNameOne) "cookie-name-stable-instance"
    $duplicateSession.Container.Add($serverOne.BaseUri, [System.Net.Cookie]::new($cookieNameOne, ("0" * 64), "/"))
    $duplicate = Invoke-HttpCase $duplicateSession $serverOne.BaseUri "/api/v1/capabilities" -ClientHeaderValues @("web") -PrivacySentinels $privacySentinels
    Confirm-ErrorResponse $duplicate 401 "unauthorized" "Authorization is required."

    $clientHeaderCases = [object[]]::new(3)
    $clientHeaderCases[0] = [string[]]@()
    $clientHeaderCases[1] = [string[]]@("wrong")
    $clientHeaderCases[2] = [string[]]@("web", "web")
    foreach ($clientHeaders in $clientHeaderCases) {
        $result = Invoke-HttpCase $sessionOne $serverOne.BaseUri "/api/v1/capabilities" -ClientHeaderValues $clientHeaders -PrivacySentinels $privacySentinels
        Confirm-ErrorResponse $result 401 "unauthorized" "Authorization is required."
    }

    $wrongPort = if ($serverOne.Port -lt 65535) { $serverOne.Port + 1 } else { $serverOne.Port - 1 }
    foreach ($invalidHost in @(
        "127.0.0.1",
        "127.0.0.1:$wrongPort",
        "localhost:$($serverOne.Port)",
        "[::1]:$($serverOne.Port)",
        "127.000.000.001:$($serverOne.Port)",
        "127.0.0.1.evil.invalid:$($serverOne.Port)")) {
        $result = Invoke-HttpCase $anonymous $serverOne.BaseUri "/healthz" -HostHeader $invalidHost -PrivacySentinels $privacySentinels
        Confirm-ErrorResponse $result 400 "invalidRequest" "The request was rejected."
    }

    $exactOrigin = Invoke-HttpCase $anonymous $serverOne.BaseUri "/healthz" -OriginValues @($authority) -PrivacySentinels $privacySentinels
    Confirm-HealthResponse $exactOrigin
    foreach ($invalidOrigin in @(
        "null",
        "not-an-origin",
        "https://127.0.0.1:$($serverOne.Port)",
        "http://localhost:$($serverOne.Port)",
        "http://127.0.0.1:$wrongPort",
        "$authority/",
        $authority.ToUpperInvariant())) {
        $result = Invoke-HttpCase $anonymous $serverOne.BaseUri "/healthz" -OriginValues @($invalidOrigin) -PrivacySentinels $privacySentinels
        Confirm-ErrorResponse $result 403 "forbidden" "The request was rejected."
    }

    # The request law after the D-046 amendment: five GET routes keep the bodyless,
    # queryless law; the one POST route accepts exactly one bounded JSON body shape.
    # The Allow header on a 405 names the path's own method, so it is asserted per
    # route rather than as a constant.
    $mediaFactsRoute = "/api/v1/media-facts"
    $mediaFactsContentType = "application/json; charset=utf-8"
    $mediaFactsBody = '{"path":"placeholder"}'
    $routes = @("/", "/app.css", "/app.js", "/healthz", "/api/v1/capabilities", $mediaFactsRoute)
    $allMethods = @("HEAD", "GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "TRACE")
    foreach ($route in $routes) {
        $allowedMethod = if ($route -ceq $mediaFactsRoute) { "POST" } else { "GET" }
        foreach ($method in @($allMethods | Where-Object { $_ -cne $allowedMethod })) {
            $result = Invoke-HttpCase $anonymous $serverOne.BaseUri $route -Method $method -PrivacySentinels $privacySentinels
            Confirm-ErrorResponse $result 405 "methodNotAllowed" "The request was rejected." -AllowEmptyBody:($method -ceq "HEAD")
            Confirm-Check ($result.Headers.ContainsKey("Allow")) "method-allow-present"
            Confirm-Check (($result.Headers["Allow"] -join ", ") -ceq $allowedMethod) "method-allow-exact"
        }

        if ($route -ceq $mediaFactsRoute) {
            $query = Invoke-HttpCase $anonymous $serverOne.BaseUri ($route + "?probe=$sentinel") -Method "POST" -BodyText $mediaFactsBody -ContentTypeText $mediaFactsContentType -PrivacySentinels $privacySentinels
            Confirm-ErrorResponse $query 400 "invalidRequest" "The request was rejected."
            $bodyless = Invoke-HttpCase $anonymous $serverOne.BaseUri $route -Method "POST" -PrivacySentinels $privacySentinels
            Confirm-ErrorResponse $bodyless 400 "invalidRequest" "The request was rejected."
            $wrongType = Invoke-HttpCase $anonymous $serverOne.BaseUri $route -Method "POST" -BodyText $mediaFactsBody -PrivacySentinels $privacySentinels
            Confirm-ErrorResponse $wrongType 400 "invalidRequest" "The request was rejected."
            $oversized = Invoke-HttpCase $anonymous $serverOne.BaseUri $route -Method "POST" -BodyText ('{"path":"' + ("a" * 1100) + '"}') -ContentTypeText $mediaFactsContentType -PrivacySentinels $privacySentinels
            Confirm-ErrorResponse $oversized 400 "invalidRequest" "The request was rejected."
            $chunked = Invoke-HttpCase $anonymous $serverOne.BaseUri $route -Method "POST" -BodyText $mediaFactsBody -ContentTypeText $mediaFactsContentType -Chunked -PrivacySentinels $privacySentinels
            Confirm-ErrorResponse $chunked 400 "invalidRequest" "The request was rejected."

            # D-052. A rejection that answers without reading a declared body leaves the
            # connection unusable, because the unread bytes would be read as the next
            # request. The server closes it; these assert that it says so, which is what
            # lets a client retire the connection instead of pooling it and racing the
            # close. Both directions are asserted deliberately: setting the header
            # unconditionally would satisfy the positive cases and fail the bodyless one,
            # so neither omitting it nor always sending it can pass.
            Confirm-Check ((($query.Headers["Connection"]) -join ",") -ceq "close") "media-facts-query-close-announced"
            Confirm-Check ((($wrongType.Headers["Connection"]) -join ",") -ceq "close") "media-facts-wrong-type-close-announced"
            Confirm-Check ((($oversized.Headers["Connection"]) -join ",") -ceq "close") "media-facts-oversized-close-announced"
            Confirm-Check ((($chunked.Headers["Connection"]) -join ",") -ceq "close") "media-facts-chunked-close-announced"
            Confirm-Check (-not $bodyless.Headers.ContainsKey("Connection")) "media-facts-bodyless-keeps-connection"
        }
        else {
            $query = Invoke-HttpCase $anonymous $serverOne.BaseUri ($route + "?probe=$sentinel") -PrivacySentinels $privacySentinels
            Confirm-ErrorResponse $query 400 "invalidRequest" "The request was rejected."
            $body = Invoke-HttpCase $anonymous $serverOne.BaseUri $route -BodyText $sentinel -PrivacySentinels $privacySentinels
            Confirm-ErrorResponse $body 400 "invalidRequest" "The request was rejected."
            $chunked = Invoke-HttpCase $anonymous $serverOne.BaseUri $route -Chunked -PrivacySentinels $privacySentinels
            Confirm-ErrorResponse $chunked 400 "invalidRequest" "The request was rejected."

            # D-052 on the bodyless routes: same rule, and the query case is the negative
            # here because it carries no body and must keep its connection.
            Confirm-Check ((($body.Headers["Connection"]) -join ",") -ceq "close") "route-body-close-announced"
            Confirm-Check ((($chunked.Headers["Connection"]) -join ",") -ceq "close") "route-chunked-close-announced"
            Confirm-Check (-not $query.Headers.ContainsKey("Connection")) "route-query-keeps-connection"
        }
    }

    foreach ($route in @("/index.html", "/app.css/", "/app.js/", "/healthz/", "/api/v1/capabilities/", "/api/v1/media-facts/", "/unknown", "/app.js%2f..%2fhealthz")) {
        $result = Invoke-HttpCase $anonymous $serverOne.BaseUri $route -PrivacySentinels $privacySentinels
        Confirm-ErrorResponse $result 404 "notFound" "The request was rejected."
    }

    # The endpoint's own contract while no inspection configuration exists: the
    # session gate answers first, and an authorized caller learns exactly that the
    # capability is unavailable, with the body never read.
    $mediaAnonymous = Invoke-HttpCase $anonymous $serverOne.BaseUri $mediaFactsRoute -Method "POST" -BodyText $mediaFactsBody -ContentTypeText $mediaFactsContentType -PrivacySentinels $privacySentinels
    Confirm-ErrorResponse $mediaAnonymous 401 "unauthorized" "Authorization is required."
    $mediaUnconfigured = Invoke-HttpCase $sessionOne $serverOne.BaseUri $mediaFactsRoute -Method "POST" -BodyText $mediaFactsBody -ContentTypeText $mediaFactsContentType -ClientHeaderValues @("web") -PrivacySentinels $privacySentinels
    Confirm-ErrorResponse $mediaUnconfigured 503 "capabilityUnavailable" "The capability is unavailable."

    $preflightHeaders = @{
        "Access-Control-Request-Method" = "GET"
        "Access-Control-Request-Headers" = "X-StaxRip-Client"
    }
    $preflight = Invoke-HttpCase $anonymous $serverOne.BaseUri "/api/v1/capabilities" -Method "OPTIONS" -OriginValues @("http://127.0.0.1:61239") -AdditionalHeaders $preflightHeaders -PrivacySentinels $privacySentinels
    Confirm-ErrorResponse $preflight 403 "forbidden" "The request was rejected."
    $privateNetworkHeaders = @{
        "Access-Control-Request-Method" = "GET"
        "Access-Control-Request-Headers" = "X-StaxRip-Client"
        "Access-Control-Request-Private-Network" = "true"
    }
    $privateNetworkPreflight = Invoke-HttpCase $anonymous $serverOne.BaseUri "/api/v1/capabilities" -Method "OPTIONS" -OriginValues @($authority) -AdditionalHeaders $privateNetworkHeaders -PrivacySentinels $privacySentinels
    Confirm-ErrorResponse $privateNetworkPreflight 405 "methodNotAllowed" "The request was rejected."

    $rawPrefix = "GET /healthz HTTP/1.1`r`n"
    foreach ($rawRequest in @(
        ($rawPrefix + "Connection: close`r`n`r`n"),
        ($rawPrefix + "Host: 127.0.0.1:$($serverOne.Port)`r`nHost: 127.0.0.1:$($serverOne.Port)`r`nConnection: close`r`n`r`n"),
        ($rawPrefix + "Host: [::1`r`nConnection: close`r`n`r`n"))) {
        $rawResult = Invoke-RawCase $serverOne.Port $rawRequest $privacySentinels
        Confirm-Check ($rawResult.Status -eq 400) "raw-host-rejected"
    }

    $duplicateOriginRequest = $rawPrefix +
        "Host: $($serverOne.BaseUri.Authority)`r`n" +
        "Origin: $authority`r`n" +
        "Origin: $authority`r`n" +
        "Connection: close`r`n`r`n"
    $duplicateOrigin = Invoke-RawCase $serverOne.Port $duplicateOriginRequest $privacySentinels
    Confirm-Check ($duplicateOrigin.Status -eq 403) "raw-duplicate-origin-rejected"
    Confirm-SecurityHeaders $duplicateOrigin.Headers

    $connectRequest = "CONNECT $($serverOne.BaseUri.Authority) HTTP/1.1`r`nHost: $($serverOne.BaseUri.Authority)`r`nConnection: close`r`n`r`n"
    $connect = Invoke-RawCase $serverOne.Port $connectRequest $privacySentinels
    Confirm-Check ($connect.Status -eq 405) "connect-rejected"
    Confirm-SecurityHeaders $connect.Headers

    $doubleSlashRequest = "GET // HTTP/1.1`r`nHost: $($serverOne.BaseUri.Authority)`r`nConnection: close`r`n`r`n"
    $doubleSlash = Invoke-RawCase $serverOne.Port $doubleSlashRequest $privacySentinels
    Confirm-Check ($doubleSlash.Status -eq 404) "double-slash-rejected"
    Confirm-SecurityHeaders $doubleSlash.Headers

    Stop-TestServer $serverOne

    $serverTwo = Start-TestServer $ServerPath $workDirectories[1] $sentinel
    $serverThree = Start-TestServer $ServerPath $workDirectories[2] $sentinel
    Confirm-Check ($serverTwo.Port -ne $serverThree.Port) "concurrent-port-separation"

    $restartOld = Invoke-HttpCase $sessionOne $serverTwo.BaseUri "/api/v1/capabilities" -ClientHeaderValues @("web") -PrivacySentinels $privacySentinels
    Confirm-ErrorResponse $restartOld 401 "unauthorized" "Authorization is required."

    $sessionTwo = New-ClientBundle
    $sessionThree = New-ClientBundle
    $rootTwo = Invoke-HttpCase $sessionTwo $serverTwo.BaseUri "/" -CookieExpectation one -PrivacySentinels $privacySentinels
    $rootThree = Invoke-HttpCase $sessionThree $serverThree.BaseUri "/" -CookieExpectation one -PrivacySentinels $privacySentinels
    Confirm-Check ($rootTwo.CookieName -cne $cookieNameOne) "restart-cookie-name-change"
    Confirm-Check ($rootTwo.CookieName -cne $rootThree.CookieName) "concurrent-cookie-name-change"
    Confirm-CapabilityResponse (Invoke-HttpCase $sessionTwo $serverTwo.BaseUri "/api/v1/capabilities" -ClientHeaderValues @("web") -PrivacySentinels $privacySentinels)
    Confirm-CapabilityResponse (Invoke-HttpCase $sessionThree $serverThree.BaseUri "/api/v1/capabilities" -ClientHeaderValues @("web") -PrivacySentinels $privacySentinels)
    Confirm-ErrorResponse (Invoke-HttpCase $sessionTwo $serverThree.BaseUri "/api/v1/capabilities" -ClientHeaderValues @("web") -PrivacySentinels $privacySentinels) 401 "unauthorized" "Authorization is required."
    Confirm-ErrorResponse (Invoke-HttpCase $sessionThree $serverTwo.BaseUri "/api/v1/capabilities" -ClientHeaderValues @("web") -PrivacySentinels $privacySentinels) 401 "unauthorized" "Authorization is required."

    Stop-TestServer $serverTwo
    Stop-TestServer $serverThree

    foreach ($clientBundle in $script:Clients) {
        $clientBundle.Client.Dispose()
    }
    $script:Clients.Clear()

    $workAfter = Get-TreeSnapshot $runDirectory
    $binaryAfter = Get-TreeSnapshot $binaryDirectory
    Compare-Snapshot $workBefore $workAfter "runtime-working-tree"
    Compare-Snapshot $binaryBefore $binaryAfter "runtime-binary-tree"

    Remove-ValidatedTaskDirectory $runDirectory $taskRoot
    $cleanupAllowed = $false
    $script:TaskCleanupResult = "passed"
    $bodyCompleted = $true
}
catch {
    $primaryException = $_.Exception
    $primaryCheck = $script:CurrentCheck
    $cause = $primaryException
    for ($depth = 0; $depth -lt 8; $depth++) {
        if ($cause.Message -cmatch '^CHECK:([a-z0-9][a-z0-9-]{1,79})$') {
            $primaryCheck = $Matches[1]
        }
        if ($null -eq $cause.InnerException) {
            break
        }
        $cause = $cause.InnerException
    }
}
finally {
    $savedCheck = if ($null -ne $primaryCheck) { $primaryCheck } else { $script:CurrentCheck }
    foreach ($server in $script:Servers) {
        if (-not $server.CleanupComplete -and -not $server.ProcessDisposed) {
            try { [void](Invoke-ServerCleanup $server) }
            catch { Set-ServerCleanupFailure $server "server-cleanup-authority" $_.Exception }
        }
        if (-not $server.CleanupComplete -and $null -eq $server.CleanupException) {
            Set-ServerCleanupFailure $server "server-cleanup-incomplete"
        }
        if ($server.CleanupComplete -and
            $server.BaseUri -is [uri] -and
            -not $server.ConsoleValidated -and
            $null -eq $server.ConsoleException) {
            try { Confirm-ServerConsole $server }
            catch { Set-ServerConsoleFailure $server $_.Exception }
        }
        if (-not $server.CaptureSanitized) {
            try { Protect-ServerConsoleCapture $server }
            catch {
                Set-ServerConsoleFailure $server (New-CheckException "server-console-redaction" $_.Exception)
            }
        }
    }
    foreach ($clientBundle in $script:Clients) {
        try { $clientBundle.Client.Dispose() }
        catch { Set-OuterCleanupFailure "http-client-dispose" $_.Exception }
    }
    if ($cleanupAllowed) {
        try {
            Remove-ValidatedTaskDirectory $runDirectory $taskRoot
            $cleanupAllowed = $false
            $script:TaskCleanupResult = "passed"
        }
        catch {
            $script:TaskCleanupResult = "failed"
            Set-OuterCleanupFailure "http-task-directory-cleanup" $_.Exception
        }
    }
    $script:CurrentCheck = $savedCheck
}

$serverCleanupFailures = @($script:Servers | Where-Object { $null -ne $_.CleanupException })
$serverConsoleFailures = @($script:Servers | Where-Object { $null -ne $_.ConsoleException })
if ($null -eq $primaryException -and $serverCleanupFailures.Count -gt 0) {
    $primaryException = $serverCleanupFailures[0].CleanupException
    $primaryCheck = $serverCleanupFailures[0].CleanupCheck
}
if ($null -eq $primaryException -and $serverConsoleFailures.Count -gt 0) {
    $primaryException = $serverConsoleFailures[0].ConsoleException
    $primaryCheck = $serverConsoleFailures[0].ConsoleCheck
}
if ($null -eq $primaryException -and $null -ne $script:OuterCleanupException) {
    $primaryException = $script:OuterCleanupException
    $primaryCheck = $script:OuterCleanupCheck
}
if ($null -eq $primaryException -and -not $bodyCompleted) {
    $primaryCheck = "http-body-incomplete"
    $primaryException = New-CheckException $primaryCheck
}

if ($null -eq $primaryException) {
    $publicationException = $null
    $publicationCheck = $script:CurrentCheck
    try {
        Assert-EvidencePublicationReady
        Write-SuccessRecord $evidenceRoot $ServerPath
        Remove-OwnFailurePacket -ArtifactsRoot $artifactsRoot -FailureRoot $failureRoot
    }
    catch {
        $publicationException = $_.Exception
        $publicationCheck = $script:CurrentCheck
        $cause = $publicationException
        for ($depth = 0; $depth -lt 8; $depth++) {
            if ($cause.Message -cmatch '^CHECK:([a-z0-9][a-z0-9-]{1,79})$') {
                $publicationCheck = $Matches[1]
            }
            if ($null -eq $cause.InnerException) { break }
            $cause = $cause.InnerException
        }
    }
    if ($null -ne $publicationException) {
        $primaryException = $publicationException
        $primaryCheck = $publicationCheck
    }
}

$packetResult = "not-applicable"
$leaseReleaseResult = if ($script:EvidenceLeaseOwned) { "pending" } else { "not-acquired" }
$leaseReleaseException = $null
if ($null -ne $primaryException) {
    $startedAt.Stop()
    $script:CurrentCheck = $primaryCheck
    $packetResult = "none"
    if ($evidenceLeaseStartupReady) {
        try {
            Assert-EvidencePublicationReady
            $script:CurrentCheck = $primaryCheck
            Write-FailurePacket $failureRoot $primaryException
            $packetResult = "written"
        }
        catch {
            $packetResult = "failed"
        }
    }
}

if ($script:EvidenceLeaseOwned) {
    try {
        Exit-EvidenceWriterLease
        $leaseReleaseResult = "passed"
    }
    catch {
        $leaseReleaseResult = "failed"
        $leaseReleaseException = $_.Exception
    }
}
elseif ($null -ne $script:EvidenceLeaseStream) {
    $leaseReleaseResult = "failed"
    $leaseReleaseException = New-CheckException "evidence-lease-release-state"
}

if ($null -eq $primaryException -and $null -ne $leaseReleaseException) {
    if ($startedAt.IsRunning) { $startedAt.Stop() }
    $primaryException = $leaseReleaseException
    $primaryCheck = "evidence-lease-release"
    $packetResult = "none"
}

if ($null -ne $primaryException) {
    if ($startedAt.IsRunning) { $startedAt.Stop() }
    $script:CurrentCheck = $primaryCheck
    $exceptionType = $primaryException.GetType().Name
    $cause = $primaryException
    for ($depth = 0; $depth -lt 8 -and $null -ne $cause.InnerException; $depth++) {
        $cause = $cause.InnerException
    }
    $causeType = $cause.GetType().Name
    $causeCode = if ($cause -is [System.Net.Sockets.SocketException]) {
        [string]$cause.SocketErrorCode
    }
    elseif ($cause -is [System.Net.Http.HttpRequestException]) {
        [string]$cause.HttpRequestError
    }
    else {
        'none'
    }
    $failureEvidence = if ($packetResult -ceq "written") {
        "CrossPlatform/artifacts/failures/port-http-windows-$($Configuration.ToLowerInvariant()).json"
    }
    else {
        "none"
    }
    try {
        [Console]::Error.WriteLine(
            "FAIL $gateId check=$primaryCheck type=$exceptionType cause=$causeType code=$causeCode cleanup=$($serverCleanupFailures.Count) evidence=$failureEvidence packet=$packetResult lease_release=$leaseReleaseResult")
    }
    catch { }
    if ($script:ProducerExit -is [int] -and $script:ProducerExit -ne 0) {
        exit $script:ProducerExit
    }
    exit 1
}

$startedAt.Stop()
Write-Output "PASS $gateId checks=$script:CheckCount elapsed_ms=$($startedAt.ElapsedMilliseconds) evidence=CrossPlatform/artifacts/evidence/http-windows.json"
exit 0
