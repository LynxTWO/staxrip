[CmdletBinding()]
param(
    [string]$BaseCommit = '940eaba1134e52260a74cb452a86e3e243ed76c9'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gateId = 'port-evidence'
$defaultBaseCommit = '940eaba1134e52260a74cb452a86e3e243ed76c9'
$timer = [System.Diagnostics.Stopwatch]::StartNew()
$crossPlatformRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $crossPlatformRoot '..'))
$artifactsRoot = [System.IO.Path]::GetFullPath((Join-Path $crossPlatformRoot 'artifacts'))
$evidenceRoot = [System.IO.Path]::GetFullPath((Join-Path $artifactsRoot 'evidence'))
$failureRoot = [System.IO.Path]::GetFullPath((Join-Path $artifactsRoot 'failures'))
$browserTaskRoot = [System.IO.Path]::GetFullPath((Join-Path $artifactsRoot 'tmp\port-browser'))
$httpTaskRoot = [System.IO.Path]::GetFullPath((Join-Path $artifactsRoot 'tmp\port-http'))
$verifyWorkflowMarkerPath = [System.IO.Path]::GetFullPath((Join-Path $artifactsRoot 'tmp\.port-verify-running'))
$publishRoot = [System.IO.Path]::GetFullPath((Join-Path $artifactsRoot 'publish'))
$packagesRoot = [System.IO.Path]::GetFullPath((Join-Path $artifactsRoot 'nuget'))
$auditPath = [System.IO.Path]::GetFullPath((Join-Path $evidenceRoot 'evidence-audit.json'))
$auditSidecarPath = [System.IO.Path]::GetFullPath((Join-Path $evidenceRoot 'evidence-audit.json.sha256'))
$leasePath = [System.IO.Path]::GetFullPath((Join-Path $evidenceRoot '.evidence-writer.lock'))
$failurePacketPath = [System.IO.Path]::GetFullPath((Join-Path $failureRoot 'port-evidence.txt'))
$emptySha256 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
$script:Checks = 0
$script:CloseoutChecks = 0
$script:CurrentCheck = 'preflight'
$script:Stopping = $false
$script:EvidenceLeaseAcquired = $false
$script:EvidenceLeaseReceiptValidated = $false
$script:EvidencePassPairInvalidated = $false
$script:EvidenceLeaseNonce = $null
$script:EvidenceLeaseStream = $null
$script:ArchiveAssertionMode = $null
$script:SidecarStagePath = $null
$script:JsonDocuments = [System.Collections.Generic.List[System.Text.Json.JsonDocument]]::new()

function Test-ContainedPath {
    param(
        [Parameter(Mandatory)] [string]$Candidate,
        [Parameter(Mandatory)] [string]$Root,
        [switch]$AllowEqual
    )

    try {
        $target = [System.IO.Path]::GetFullPath($Candidate)
        $parent = [System.IO.Path]::GetFullPath($Root).TrimEnd(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar)
        $comparison = if ($IsWindows) {
            [System.StringComparison]::OrdinalIgnoreCase
        }
        else {
            [System.StringComparison]::Ordinal
        }
        if ($AllowEqual -and $target.Equals($parent, $comparison)) {
            return $true
        }
        $prefix = $parent + [System.IO.Path]::DirectorySeparatorChar
        return $target.StartsWith($prefix, $comparison)
    }
    catch {
        return $false
    }
}

function Test-SafeComponent {
    param([Parameter(Mandatory)] [string]$Name)

    if ($Name.Length -eq 0 -or $Name.Length -gt 255 -or $Name -in @('.', '..')) {
        return $false
    }
    if ($Name -notmatch '^[\x20-\x7e]+$' -or
        $Name -match '[<>:"/\\|?*]' -or
        $Name.EndsWith(' ', [System.StringComparison]::Ordinal) -or
        $Name.EndsWith('.', [System.StringComparison]::Ordinal)) {
        return $false
    }
    return $true
}

function Test-ExistingPathChain {
    param([Parameter(Mandatory)] [string]$Path)

    try {
        $target = [System.IO.Path]::GetFullPath($Path)
        $volume = [System.IO.Path]::GetPathRoot($target)
        if ([string]::IsNullOrWhiteSpace($volume) -or -not [System.IO.Directory]::Exists($volume)) {
            return $false
        }
        $volumeItem = Get-Item -LiteralPath $volume -Force
        if (($volumeItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            return $false
        }

        $current = $volume
        $relative = $target.Substring($volume.Length)
        $components = $relative.Split(
            [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar),
            [System.StringSplitOptions]::RemoveEmptyEntries)
        foreach ($component in $components) {
            $exact = @([System.IO.Directory]::EnumerateFileSystemEntries($current) |
                    Where-Object {
                        [System.IO.Path]::GetFileName($_).Equals(
                            $component,
                            [System.StringComparison]::Ordinal)
                    })
            if ($exact.Count -ne 1) {
                return $false
            }
            $current = $exact[0]
            $item = Get-Item -LiteralPath $current -Force
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                return $false
            }
        }
        return $true
    }
    catch {
        return $false
    }
}

function Test-SafeDirectory {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$AllowedRoot
    )

    try {
        $target = [System.IO.Path]::GetFullPath($Path)
        $root = [System.IO.Path]::GetFullPath($AllowedRoot)
        if (-not (Test-ContainedPath -Candidate $target -Root $root -AllowEqual)) {
            return $false
        }
        if (-not [System.IO.Directory]::Exists($root) -or
            -not (Test-ExistingPathChain -Path $root)) {
            return $false
        }
        $relative = [System.IO.Path]::GetRelativePath($root, $target).Replace('\', '/')
        if ($relative -ne '.') {
            foreach ($component in $relative.Split('/')) {
                if (-not (Test-SafeComponent $component)) {
                    return $false
                }
            }
        }
        if (-not [System.IO.Directory]::Exists($target) -or
            -not (Test-ExistingPathChain -Path $target)) {
            return $false
        }
        $item = Get-Item -LiteralPath $target -Force
        return $item.PSIsContainer -and
            (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0)
    }
    catch {
        return $false
    }
}

function Ensure-SafeDirectory {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$AllowedRoot
    )

    try {
        $target = [System.IO.Path]::GetFullPath($Path)
        $root = [System.IO.Path]::GetFullPath($AllowedRoot)
        if (-not (Test-SafeDirectory -Path $root -AllowedRoot $root) -or
            -not (Test-ContainedPath -Candidate $target -Root $root -AllowEqual)) {
            return $false
        }
        if (Test-SafeDirectory -Path $target -AllowedRoot $root) {
            return $true
        }
        if ([System.IO.File]::Exists($target) -or [System.IO.Directory]::Exists($target)) {
            return $false
        }
        $relative = [System.IO.Path]::GetRelativePath($root, $target).Replace('\', '/')
        if ($relative -eq '.' -or [string]::IsNullOrWhiteSpace($relative)) {
            return $false
        }
        foreach ($component in $relative.Split('/')) {
            if (-not (Test-SafeComponent $component)) {
                return $false
            }
        }
        $parent = [System.IO.Directory]::GetParent($target)
        if ($null -eq $parent -or
            -not (Test-SafeDirectory -Path $parent.FullName -AllowedRoot $root)) {
            return $false
        }
        [System.IO.Directory]::CreateDirectory($target) | Out-Null
        return Test-SafeDirectory -Path $target -AllowedRoot $root
    }
    catch {
        return $false
    }
}

function Test-SafeLeaf {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$AllowedRoot,
        [switch]$AllowMissing
    )

    try {
        $target = [System.IO.Path]::GetFullPath($Path)
        $root = [System.IO.Path]::GetFullPath($AllowedRoot)
        if (-not (Test-SafeDirectory -Path $root -AllowedRoot $root) -or
            -not (Test-ContainedPath -Candidate $target -Root $root)) {
            return $false
        }
        $relative = [System.IO.Path]::GetRelativePath($root, $target).Replace('\', '/')
        foreach ($component in $relative.Split('/')) {
            if (-not (Test-SafeComponent $component)) {
                return $false
            }
        }
        $parent = [System.IO.Directory]::GetParent($target)
        if ($null -eq $parent -or
            -not (Test-SafeDirectory -Path $parent.FullName -AllowedRoot $root)) {
            return $false
        }
        if (-not [System.IO.File]::Exists($target)) {
            return $AllowMissing -and -not [System.IO.Directory]::Exists($target)
        }
        if (-not (Test-ExistingPathChain -Path $target)) {
            return $false
        }
        $item = Get-Item -LiteralPath $target -Force
        $linkTypeProperty = $item.PSObject.Properties['LinkType']
        return -not $item.PSIsContainer -and
            (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) -and
            $null -ne $linkTypeProperty -and
            [string]::IsNullOrEmpty([string]$linkTypeProperty.Value)
    }
    catch {
        return $false
    }
}

function Remove-SafeFixedLeaf {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$AllowedRoot
    )

    try {
        $target = [System.IO.Path]::GetFullPath($Path)
        if (-not (Test-SafeLeaf -Path $target -AllowedRoot $AllowedRoot -AllowMissing)) {
            return $false
        }
        if (-not [System.IO.File]::Exists($target)) {
            return -not [System.IO.Directory]::Exists($target)
        }
        if (-not (Test-SafeLeaf -Path $target -AllowedRoot $AllowedRoot)) {
            return $false
        }
        [System.IO.File]::Delete($target)
        return -not [System.IO.File]::Exists($target) -and
            -not [System.IO.Directory]::Exists($target)
    }
    catch {
        return $false
    }
}

function Test-ExactEvidenceLeaseBytes {
    param(
        [Parameter(Mandatory)] [System.IO.Stream]$Stream,
        [Parameter(Mandatory)] [byte[]]$Expected
    )

    try {
        if (-not $Stream.CanRead -or $Expected.Length -ne 33) {
            return $false
        }
        $Stream.Position = 0
        if ($Stream.Length -ne 33) {
            return $false
        }
        $actual = [byte[]]::new(33)
        $offset = 0
        while ($offset -lt $actual.Length) {
            $count = $Stream.Read($actual, $offset, $actual.Length - $offset)
            if ($count -eq 0) {
                return $false
            }
            $offset += $count
        }
        if ($Stream.ReadByte() -ne -1 -or $Stream.Length -ne 33) {
            return $false
        }
        for ($index = 0; $index -lt $Expected.Length; $index++) {
            if ($actual[$index] -ne $Expected[$index]) {
                return $false
            }
        }
        return $true
    }
    catch {
        return $false
    }
}

function Test-EvidenceLeasePathReceipt {
    if (-not $script:EvidenceLeaseAcquired -or
        [string]::IsNullOrEmpty($script:EvidenceLeaseNonce) -or
        $script:EvidenceLeaseNonce -cnotmatch '^[0-9a-f]{32}$' -or
        -not (Test-SafeLeaf -Path $leasePath -AllowedRoot $evidenceRoot)) {
        return $false
    }

    $stream = $null
    $receiptMatches = $false
    try {
        $expected = [System.Text.Encoding]::ASCII.GetBytes("$($script:EvidenceLeaseNonce)`n")
        $stream = [System.IO.File]::Open(
            $leasePath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::Read)
        $receiptMatches = Test-ExactEvidenceLeaseBytes -Stream $stream -Expected $expected
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $stream) {
            try { $stream.Dispose() } catch { }
        }
    }
    return $receiptMatches -and
        (Test-SafeLeaf -Path $leasePath -AllowedRoot $evidenceRoot)
}

function Test-EvidenceLeaseReceipt {
    if (-not $script:EvidenceLeaseAcquired -or
        [string]::IsNullOrEmpty($script:EvidenceLeaseNonce) -or
        $script:EvidenceLeaseNonce -cnotmatch '^[0-9a-f]{32}$') {
        return $false
    }
    if ($null -eq $script:EvidenceLeaseStream) {
        return Test-EvidenceLeasePathReceipt
    }
    try {
        if (-not (Test-SafeLeaf -Path $leasePath -AllowedRoot $evidenceRoot) -or
            -not $script:EvidenceLeaseStream.CanRead -or
            -not $script:EvidenceLeaseStream.CanWrite -or
            [System.IO.Path]::GetFullPath($script:EvidenceLeaseStream.Name) -cne
                [System.IO.Path]::GetFullPath($leasePath)) {
            return $false
        }
        $expected = [System.Text.Encoding]::ASCII.GetBytes("$($script:EvidenceLeaseNonce)`n")
        return Test-ExactEvidenceLeaseBytes `
            -Stream $script:EvidenceLeaseStream `
            -Expected $expected
    }
    catch {
        return $false
    }
}

function Test-EvidenceLeaseAuthority {
    return $script:EvidenceLeaseAcquired -and
        $script:EvidenceLeaseReceiptValidated -and
        $null -ne $script:EvidenceLeaseStream -and
        (Test-EvidenceLeaseReceipt)
}

function Test-EvidencePassPairAbsent {
    return (Test-SafeLeaf -Path $auditSidecarPath -AllowedRoot $evidenceRoot -AllowMissing) -and
        -not [System.IO.File]::Exists($auditSidecarPath) -and
        -not [System.IO.Directory]::Exists($auditSidecarPath) -and
        (Test-SafeLeaf -Path $auditPath -AllowedRoot $evidenceRoot -AllowMissing) -and
        -not [System.IO.File]::Exists($auditPath) -and
        -not [System.IO.Directory]::Exists($auditPath)
}

function Test-EvidencePassPairInvalidated {
    # This records the initial invalidation. The evidence gate intentionally
    # creates the audit pair later while the same lease remains current.
    return $script:EvidencePassPairInvalidated
}

function Test-EvidencePublicationAuthority {
    return (Test-EvidenceLeaseAuthority) -and
        (Test-EvidencePassPairInvalidated)
}

function Remove-ExactEvidenceWriterLease {
    if (-not $script:EvidenceLeaseAcquired) {
        return -not $script:EvidenceLeaseReceiptValidated -and
            -not $script:EvidencePassPairInvalidated -and
            $null -eq $script:EvidenceLeaseNonce -and
            $null -eq $script:EvidenceLeaseStream
    }
    $receiptCurrent = Test-EvidenceLeaseReceipt
    if ($null -ne $script:EvidenceLeaseStream) {
        try {
            $script:EvidenceLeaseStream.Dispose()
            $script:EvidenceLeaseStream = $null
        }
        catch {
            return $false
        }
    }
    if (-not $receiptCurrent) {
        return $false
    }
    try {
        if (-not (Test-EvidenceLeasePathReceipt) -or
            -not (Test-EvidenceLeasePathReceipt)) {
            return $false
        }
        [System.IO.File]::Delete($leasePath)
        if ([System.IO.File]::Exists($leasePath) -or
            [System.IO.Directory]::Exists($leasePath)) {
            return $false
        }
        $script:EvidenceLeaseAcquired = $false
        $script:EvidenceLeaseReceiptValidated = $false
        $script:EvidencePassPairInvalidated = $false
        $script:EvidenceLeaseNonce = $null
        $script:EvidenceLeaseStream = $null
        return $true
    }
    catch {
        return $false
    }
}

function Remove-PassPairLeaf {
    param([Parameter(Mandatory)] [string]$Path)

    try {
        if (-not (Test-EvidenceLeaseAuthority) -or
            -not (Test-SafeLeaf -Path $Path -AllowedRoot $evidenceRoot -AllowMissing)) {
            return $false
        }
        if (-not [System.IO.File]::Exists($Path)) {
            return -not [System.IO.Directory]::Exists($Path) -and
                (Test-EvidenceLeaseAuthority)
        }
        if (-not (Test-SafeLeaf -Path $Path -AllowedRoot $evidenceRoot) -or
            -not (Test-EvidenceLeaseAuthority)) {
            return $false
        }
        [System.IO.File]::Delete($Path)
        return (Test-EvidenceLeaseAuthority) -and
            -not [System.IO.File]::Exists($Path) -and
            -not [System.IO.Directory]::Exists($Path)
    }
    catch {
        return $false
    }
}

function Invalidate-PassPair {
    if (-not (Test-EvidenceLeaseAuthority)) {
        return $false
    }
    $script:EvidencePassPairInvalidated = $false
    if (-not (Remove-PassPairLeaf -Path $auditSidecarPath) -or
        -not (Test-EvidenceLeaseAuthority) -or
        -not (Remove-PassPairLeaf -Path $auditPath) -or
        -not (Test-EvidenceLeaseAuthority) -or
        -not (Test-EvidencePassPairAbsent)) {
        return $false
    }
    $script:EvidencePassPairInvalidated = $true
    return Test-EvidencePublicationAuthority
}

function Enter-EvidenceLease {
    if ($script:EvidenceLeaseAcquired) {
        return (Test-EvidencePublicationAuthority)
    }
    if ($script:EvidenceLeaseReceiptValidated -or
        $script:EvidencePassPairInvalidated -or
        $null -ne $script:EvidenceLeaseNonce -or
        $null -ne $script:EvidenceLeaseStream -or
        -not (Test-SafeDirectory -Path $evidenceRoot -AllowedRoot $artifactsRoot) -or
        [System.IO.Directory]::Exists($leasePath) -or
        [System.IO.File]::Exists($leasePath) -or
        -not (Test-SafeLeaf -Path $leasePath -AllowedRoot $evidenceRoot -AllowMissing)) {
        return $false
    }

    $nonce = [System.Guid]::NewGuid().ToString('N')
    $bytes = [System.Text.Encoding]::ASCII.GetBytes("$nonce`n")
    if ($nonce -cnotmatch '^[0-9a-f]{32}$' -or $bytes.Length -ne 33) {
        return $false
    }
    $stream = $null
    $entered = $false
    try {
        $stream = [System.IO.File]::Open(
            $leasePath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None)
        $script:EvidenceLeaseAcquired = $true
        $script:EvidenceLeaseNonce = $nonce
        $script:EvidenceLeaseStream = $stream
        $stream = $null
        $script:EvidenceLeaseStream.Position = 0
        $script:EvidenceLeaseStream.Write($bytes, 0, $bytes.Length)
        $script:EvidenceLeaseStream.Flush($true)
        if (-not (Test-EvidenceLeaseReceipt)) {
            return $false
        }
        $script:EvidenceLeaseReceiptValidated = $true
        if (-not (Invalidate-PassPair) -or
            -not (Test-EvidencePublicationAuthority)) {
            return $false
        }
        $entered = $true
        return $true
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $stream) {
            try { $stream.Dispose() } catch { }
        }
        if (-not $entered -and $script:EvidenceLeaseAcquired) {
            [void](Remove-ExactEvidenceWriterLease)
        }
    }
}

function Exit-EvidenceLease {
    return Remove-ExactEvidenceWriterLease
}

function Test-FailureDirectoryEmpty {
    try {
        if (-not (Test-SafeDirectory -Path $failureRoot -AllowedRoot $artifactsRoot)) {
            return $false
        }
        return @(Get-ChildItem -LiteralPath $failureRoot -Force).Count -eq 0
    }
    catch {
        return $false
    }
}

function Test-TaskRootEmpty {
    param([Parameter(Mandatory)] [string]$Path)

    try {
        $target = [System.IO.Path]::GetFullPath($Path)
        if (-not (Test-ContainedPath -Candidate $target -Root $artifactsRoot)) {
            return $false
        }
        $parent = [System.IO.Path]::GetDirectoryName($target)
        if ([string]::IsNullOrWhiteSpace($parent) -or
            -not (Test-SafeDirectory -Path $parent -AllowedRoot $artifactsRoot)) {
            return $false
        }
        $leafName = [System.IO.Path]::GetFileName($target)
        $matches = @([System.IO.Directory]::EnumerateFileSystemEntries($parent) |
                Where-Object {
                    [System.IO.Path]::GetFileName($_).Equals(
                        $leafName,
                        [System.StringComparison]::OrdinalIgnoreCase)
                })
        if ($matches.Count -eq 0) {
            return $true
        }
        if ($matches.Count -ne 1) {
            return $false
        }
        if (-not [System.IO.Path]::GetFileName($matches[0]).Equals(
                $leafName,
                [System.StringComparison]::Ordinal) -or
            -not [System.IO.Path]::GetFullPath($matches[0]).Equals(
                $target,
                [System.StringComparison]::Ordinal)) {
            return $false
        }
        $item = Get-Item -LiteralPath $matches[0] -Force
        return $item.PSIsContainer -and
            (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) -and
            (Test-SafeDirectory -Path $target -AllowedRoot $artifactsRoot) -and
            @(Get-ChildItem -LiteralPath $target -Force).Count -eq 0
    }
    catch {
        return $false
    }
}

function Test-TaskMarkerAbsent {
    param([Parameter(Mandatory)] [string]$Path)

    try {
        $target = [System.IO.Path]::GetFullPath($Path)
        if (-not (Test-ContainedPath -Candidate $target -Root $artifactsRoot)) {
            return $false
        }
        $parent = [System.IO.Path]::GetDirectoryName($target)
        if ([string]::IsNullOrWhiteSpace($parent) -or
            -not (Test-SafeDirectory -Path $parent -AllowedRoot $artifactsRoot)) {
            return $false
        }
        $leafName = [System.IO.Path]::GetFileName($target)
        $matches = @([System.IO.Directory]::EnumerateFileSystemEntries($parent) |
                Where-Object {
                    [System.IO.Path]::GetFileName($_).Equals(
                        $leafName,
                        [System.StringComparison]::OrdinalIgnoreCase)
                })
        return $matches.Count -eq 0 -and
            (Test-SafeLeaf -Path $target -AllowedRoot $artifactsRoot -AllowMissing)
    }
    catch {
        return $false
    }
}

function Get-BytesSha256 {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [byte[]]$Bytes)

    return [System.Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
}

function Try-WriteAtomicUtf8File {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$AllowedRoot,
        [Parameter(Mandatory)] [string]$Content,
        [ValidateRange(1, 1048576)] [int]$MaximumBytes = 1048576,
        [switch]$ReplaceExisting
    )

    $stream = $null
    $temporaryPath = $null
    try {
        if (-not (Test-EvidencePublicationAuthority)) {
            return $false
        }
        $target = [System.IO.Path]::GetFullPath($Path)
        $root = [System.IO.Path]::GetFullPath($AllowedRoot)
        if (-not (Test-SafeLeaf -Path $target -AllowedRoot $root -AllowMissing)) {
            return $false
        }
        $parent = [System.IO.Path]::GetDirectoryName($target)
        if ([string]::IsNullOrWhiteSpace($parent) -or
            -not (Test-SafeDirectory -Path $parent -AllowedRoot $root)) {
            return $false
        }

        $normalizedContent = $Content.Replace("`r`n", "`n")
        if ($normalizedContent.Contains("`r", [System.StringComparison]::Ordinal)) {
            return $false
        }
        $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($normalizedContent)
        if ($bytes.Length -gt $MaximumBytes) {
            return $false
        }
        $temporaryPath = [System.IO.Path]::GetFullPath((Join-Path $parent ('.tmp-' + [System.Guid]::NewGuid().ToString('N'))))
        if (-not (Test-SafeLeaf -Path $temporaryPath -AllowedRoot $root -AllowMissing)) {
            return $false
        }

        if (-not (Test-EvidencePublicationAuthority)) {
            return $false
        }
        $stream = [System.IO.File]::Open(
            $temporaryPath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None)
        if (-not (Test-EvidencePublicationAuthority)) {
            return $false
        }
        $stream.Write($bytes, 0, $bytes.Length)
        if (-not (Test-EvidencePublicationAuthority)) {
            return $false
        }
        $stream.Flush($true)
        $stream.Dispose()
        $stream = $null
        if (-not (Test-EvidencePublicationAuthority)) {
            return $false
        }

        if (-not (Test-SafeLeaf -Path $temporaryPath -AllowedRoot $root) -or
            -not (Test-SafeDirectory -Path $parent -AllowedRoot $root) -or
            -not (Test-SafeLeaf -Path $target -AllowedRoot $root -AllowMissing)) {
            return $false
        }
        if (-not (Test-EvidencePublicationAuthority)) {
            return $false
        }
        [System.IO.File]::Move($temporaryPath, $target, [bool]$ReplaceExisting)
        if (-not (Test-EvidencePublicationAuthority)) {
            return $false
        }
        $temporaryPath = $null
        if (-not (Test-SafeLeaf -Path $target -AllowedRoot $root)) {
            return $false
        }
        return ((Get-SafeSha256 -Path $target -AllowedRoot $root) -ceq (Get-BytesSha256 $bytes)) -and
            (Test-EvidencePublicationAuthority)
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
        if ($null -ne $temporaryPath -and
            (Test-EvidencePublicationAuthority) -and
            (Test-SafeLeaf -Path $temporaryPath -AllowedRoot $AllowedRoot)) {
            try {
                if (Test-EvidencePublicationAuthority) {
                    [System.IO.File]::Delete($temporaryPath)
                    [void](Test-EvidencePublicationAuthority)
                }
            }
            catch {
            }
        }
    }
}

function ConvertTo-CanonicalJson {
    param(
        [Parameter(Mandatory)]$InputObject,
        [Parameter(Mandatory)] [ValidateRange(2, 64)] [int]$Depth
    )

    $json = ConvertTo-Json -InputObject $InputObject -Depth $Depth -WarningAction Stop
    $json = $json.Replace("`r`n", "`n")
    if ($json.Contains("`r", [System.StringComparison]::Ordinal)) {
        throw [System.IO.InvalidDataException]::new('JSON serialization emitted a bare carriage return.')
    }
    return $json.TrimEnd([char]10) + "`n"
}

function Protect-Text {
    param([AllowEmptyString()] [string]$Text)

    $safe = ([string]$Text).Replace("`r`n", "`n").Replace("`r", "`n")
    $privatePaths = @(
        $repositoryRoot,
        [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile),
        [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData),
        [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique |
        Sort-Object -Property @{ Expression = { $_.Length }; Descending = $true }
    foreach ($privatePath in $privatePaths) {
        foreach ($form in @($privatePath, $privatePath.Replace('\', '/')) | Select-Object -Unique) {
            $safe = [regex]::Replace(
                $safe,
                [regex]::Escape($form),
                '<redacted-path>',
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        }
    }
    $safe = [regex]::Replace(
        $safe,
        '(?im)((?<![A-Za-z0-9_-])["'']?(?:authorization|proxy-authorization|cookie|set-cookie)["'']?\s*[:=]\s*)(?:"(?:\\.|[^"\r\n])*"|''(?:\\.|[^''\r\n])*''|[^\r\n}]*)',
        '$1<redacted>')
    $safe = [regex]::Replace(
        $safe,
        '(?i)\b(?:bearer|basic|digest|negotiate|ntlm)\s+[^\s,;}\]]+',
        '<redacted-credential>')
    $safe = [regex]::Replace(
        $safe,
        '(?i)\b(https?|wss?)://[^/\s:@]+:[^@\s/]+@',
        '$1://<redacted>@')
    $safe = [regex]::Replace(
        $safe,
        '(?im)(["'']?(?:access_token|refresh_token|id_token|api_key|client_secret|token|secret)["'']?\s*[:=]\s*)(?:"(?:\\.|[^"\r\n])*"|''[^''\r\n]*''|[^\s,;&}\r\n]+)',
        '$1<redacted>')
    $safe = [regex]::Replace($safe, '[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]', '?')
    if ($safe.Length -gt 8192) {
        $safe = $safe.Substring(0, 8192)
    }
    return $safe
}

function Stop-Gate {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [AllowEmptyString()] [string]$Output = ''
    )

    if ($script:Stopping) {
        if ($script:EvidenceLeaseAcquired) {
            try { [void](Exit-EvidenceLease) } catch { }
        }
        [Console]::Error.WriteLine('FAIL port-evidence exit=1 evidence=none stale_pass=unknown')
        exit 1
    }
    $script:Stopping = $true

    if (-not (Test-EvidencePublicationAuthority)) {
        if ($script:EvidenceLeaseAcquired) {
            try { [void](Exit-EvidenceLease) } catch { }
        }
        [Console]::Error.WriteLine('FAIL port-evidence exit=1 evidence=none lease=not-authorized')
        exit 1
    }

    $wrotePacket = $false
    $passPairInvalidated = $false
    try {
        if (-not (Test-EvidencePublicationAuthority)) {
            throw [System.IO.IOException]::new('Publication authority changed before pass invalidation.')
        }
        $passPairInvalidated = Invalidate-PassPair
        if (-not $passPairInvalidated -or
            -not (Test-EvidencePublicationAuthority)) {
            throw [System.IO.IOException]::new('The stale pass pair could not be invalidated.')
        }

        if ($null -ne $script:SidecarStagePath) {
            $stagePath = $script:SidecarStagePath
            if (-not (Test-EvidencePublicationAuthority)) {
                throw [System.IO.IOException]::new('Publication authority changed before stage cleanup.')
            }
            if (Test-SafeLeaf -Path $stagePath -AllowedRoot $evidenceRoot) {
                if (-not (Test-EvidencePublicationAuthority)) {
                    throw [System.IO.IOException]::new('Publication authority changed before stage deletion.')
                }
                [System.IO.File]::Delete($stagePath)
                if (-not (Test-EvidencePublicationAuthority) -or
                    [System.IO.File]::Exists($stagePath) -or
                    [System.IO.Directory]::Exists($stagePath)) {
                    throw [System.IO.IOException]::new('The owned sidecar stage could not be removed safely.')
                }
            }
            elseif (-not (Test-SafeLeaf -Path $stagePath -AllowedRoot $evidenceRoot -AllowMissing)) {
                throw [System.IO.IOException]::new('The owned sidecar stage path is no longer safe.')
            }
            $script:SidecarStagePath = $null
        }

        if (-not (Test-EvidencePublicationAuthority)) {
            throw [System.IO.IOException]::new('Publication authority changed before failure-root validation.')
        }
        $failureRootReady = Ensure-SafeDirectory -Path $failureRoot -AllowedRoot $artifactsRoot
        if (-not (Test-EvidencePublicationAuthority)) {
            throw [System.IO.IOException]::new('Publication authority changed during failure-root validation.')
        }
        if ($failureRootReady) {
            if (Test-SafeLeaf -Path $failurePacketPath -AllowedRoot $failureRoot -AllowMissing) {
                $safeMessage = (Protect-Text $Message) -replace '[\r\n]+', ' '
                if ($safeMessage.Length -gt 512) {
                    $safeMessage = $safeMessage.Substring(0, 512)
                }
                $boundedLines = [System.Collections.Generic.List[string]]::new()
                foreach ($line in @((Protect-Text $Output) -split "`r?`n" |
                            Where-Object { $_ -ne '' } |
                            Select-Object -First 40)) {
                    $boundedLines.Add($(if ($line.Length -gt 300) { $line.Substring(0, 300) } else { $line }))
                }
                $safeBase = (Protect-Text $BaseCommit) -replace '[\r\n]+', ' '
                if ($safeBase.Length -gt 64) {
                    $safeBase = $safeBase.Substring(0, 64)
                }
                $replayBase = if ($BaseCommit -cmatch '^[0-9a-f]{40}$') {
                    $BaseCommit
                }
                else {
                    $defaultBaseCommit
                }
                $packet = @(
                    "gate=$gateId"
                    "check=$script:CurrentCheck"
                    'criterion=LNX-001..LNX-022'
                    'exit=1'
                    "base=$safeBase"
                    "message=$safeMessage"
                    "replay=pwsh -NoProfile -NonInteractive -File CrossPlatform/eng/Verify-Evidence.ps1 -BaseCommit '$replayBase'"
                    'output_begin'
                    ($boundedLines -join "`n")
                    'output_end'
                ) -join "`n"
                if (-not (Test-EvidencePublicationAuthority)) {
                    throw [System.IO.IOException]::new('Publication authority changed before failure publication.')
                }
                $wrotePacket = Try-WriteAtomicUtf8File `
                    -Path $failurePacketPath `
                    -AllowedRoot $failureRoot `
                    -Content ($packet + "`n") `
                    -MaximumBytes 65536 `
                    -ReplaceExisting
                if ($wrotePacket -and -not (Test-EvidencePublicationAuthority)) {
                    $wrotePacket = $false
                }
            }
        }
    }
    catch {
        $wrotePacket = $false
    }

    $publicationAuthorityRetained = $passPairInvalidated -and
        (Test-EvidencePublicationAuthority) -and
        (Test-EvidencePassPairAbsent)
    $leaseReleased = $true
    if ($script:EvidenceLeaseAcquired) {
        try {
            $leaseReleased = Exit-EvidenceLease
        }
        catch {
            $leaseReleased = $false
        }
    }
    if (-not $publicationAuthorityRetained -or -not $leaseReleased) {
        $wrotePacket = $false
    }
    if ($wrotePacket) {
        [Console]::Error.WriteLine('FAIL port-evidence exit=1 evidence=CrossPlatform/artifacts/failures/port-evidence.txt')
    }
    else {
        [Console]::Error.WriteLine('FAIL port-evidence exit=1 evidence=none')
    }
    exit 1
}

function Confirm-Check {
    param(
        [Parameter(Mandatory)] [bool]$Condition,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$')]
        [string]$Id,
        [AllowEmptyString()] [string]$Detail = ''
    )

    $script:CurrentCheck = $Id
    if (-not $Condition) {
        Stop-Gate -Message "Evidence assertion failed: $Id" -Output $Detail
    }
    $script:Checks++
}

function Confirm-RedactionContract {
    $quotedSecret = 'QUOTED_AUTHORIZATION_VALUE_8f1d14b7'
    $quotedProbe = '{"Authorization":"Bearer ' + $quotedSecret + '","safe":true}'
    $quotedResult = Protect-Text $quotedProbe
    Confirm-Check (
        -not $quotedResult.Contains($quotedSecret, [System.StringComparison]::Ordinal) -and
        $quotedResult.Contains('<redacted>', [System.StringComparison]::Ordinal)) `
        'redaction-quoted-json'

    $prefixedSecret = 'COOKIE_VALUE_93a57ebcd58c'
    $fortyCharacterPrefix = '0123456789012345678901234567890123456789'
    $prefixedResult = Protect-Text (
        "$fortyCharacterPrefix Cookie: session=$prefixedSecret; second=also-sensitive")
    Confirm-Check (
        -not $prefixedResult.Contains($prefixedSecret, [System.StringComparison]::Ordinal) -and
        -not $prefixedResult.Contains('also-sensitive', [System.StringComparison]::Ordinal) -and
        $prefixedResult.Contains('<redacted>', [System.StringComparison]::Ordinal)) `
        'redaction-forty-character-prefix'

    $headerSecret = 'PROXY_AND_COOKIE_VALUE_b16249dd'
    $headerProbe = @(
        "prefix Proxy-Authorization=Basic $headerSecret",
        "prefix Set-Cookie: staxrip_session=$headerSecret",
        "prefix Authorization: Negotiate $headerSecret"
    ) -join "`r`n"
    $headerResult = Protect-Text $headerProbe
    Confirm-Check (
        -not $headerResult.Contains($headerSecret, [System.StringComparison]::Ordinal) -and
        -not $headerResult.Contains("`r", [System.StringComparison]::Ordinal) -and
        @($headerResult -split "`n" | Where-Object {
                $_.Contains('<redacted>', [System.StringComparison]::Ordinal)
            }).Count -eq 3) `
        'redaction-all-sensitive-headers'

    $bareCrSecret = 'BARE_CR_VALUE_e0ceba72'
    $bareCrResult = Protect-Text (
        "Authorization: Bearer $bareCrSecret`rCookie: session=$bareCrSecret")
    Confirm-Check (
        -not $bareCrResult.Contains($bareCrSecret, [System.StringComparison]::Ordinal) -and
        -not $bareCrResult.Contains("`r", [System.StringComparison]::Ordinal) -and
        @($bareCrResult -split "`n").Count -eq 2) `
        'redaction-bare-cr-normalized'

    $tokenSecret = 'TOKEN_ASSIGNMENT_VALUE_37a3dc66'
    $userinfoSecret = 'URI_USERINFO_VALUE_ea9bb1d2'
    $credentialSecret = 'SCHEME_VALUE_798ea149'
    $genericResult = Protect-Text (
        "token='$tokenSecret' url=https://synthetic:$userinfoSecret@example.invalid/ " +
        "value=Bearer $credentialSecret path=$repositoryRoot")
    Confirm-Check (
        -not $genericResult.Contains($tokenSecret, [System.StringComparison]::Ordinal) -and
        -not $genericResult.Contains($userinfoSecret, [System.StringComparison]::Ordinal) -and
        -not $genericResult.Contains($credentialSecret, [System.StringComparison]::Ordinal) -and
        -not $genericResult.Contains($repositoryRoot, [System.StringComparison]::OrdinalIgnoreCase)) `
        'redaction-token-userinfo-scheme'
}

function Resolve-SafeRelativePath {
    param(
        [Parameter(Mandatory)] [string]$RelativePath,
        [Parameter(Mandatory)] [string]$Root,
        [ValidateSet('Leaf', 'Directory')] [string]$Kind,
        [Parameter(Mandatory)] [string]$Id
    )

    Confirm-Check (
        $RelativePath.Length -gt 0 -and
        $RelativePath.Length -le 2048 -and
        $RelativePath -match '^[\x20-\x7e]+$' -and
        -not $RelativePath.Contains('\') -and
        -not $RelativePath.StartsWith('/', [System.StringComparison]::Ordinal) -and
        -not $RelativePath.EndsWith('/', [System.StringComparison]::Ordinal)) "$Id-grammar"
    foreach ($component in $RelativePath.Split('/')) {
        Confirm-Check (Test-SafeComponent $component) "$Id-component"
    }
    $native = $RelativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $Root $native))
    if ($Kind -eq 'Leaf') {
        Confirm-Check (Test-SafeLeaf -Path $candidate -AllowedRoot $Root) "$Id-safe"
    }
    else {
        Confirm-Check (Test-SafeDirectory -Path $candidate -AllowedRoot $Root) "$Id-safe"
    }
    return $candidate
}

function Read-SafeBytes {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$AllowedRoot,
        [ValidateRange(1, 268435456)] [int]$MaximumBytes = 1048576
    )

    if (-not (Test-SafeLeaf -Path $Path -AllowedRoot $AllowedRoot)) {
        throw [System.IO.IOException]::new('Input is not a safe regular leaf.')
    }
    $stream = [System.IO.File]::Open(
        $Path,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::Read)
    try {
        if ($stream.Length -lt 0 -or $stream.Length -gt $MaximumBytes) {
            throw [System.IO.InvalidDataException]::new('Input exceeds its bounded size.')
        }
        $bytes = [byte[]]::new([int]$stream.Length)
        $offset = 0
        while ($offset -lt $bytes.Length) {
            $read = $stream.Read($bytes, $offset, $bytes.Length - $offset)
            if ($read -le 0) {
                throw [System.IO.EndOfStreamException]::new('Input ended before its declared length.')
            }
            $offset += $read
        }
        if ($stream.ReadByte() -ne -1) {
            throw [System.IO.InvalidDataException]::new('Input grew beyond its bounded length while being read.')
        }
    }
    finally {
        $stream.Dispose()
    }
    if (-not (Test-SafeLeaf -Path $Path -AllowedRoot $AllowedRoot)) {
        throw [System.IO.IOException]::new('Input did not remain a safe regular leaf.')
    }
    return ,$bytes
}

function Read-SafeTextRecord {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$AllowedRoot,
        [ValidateRange(1, 268435456)] [int]$MaximumBytes = 1048576,
        [switch]$Ascii,
        [switch]$CanonicalLines
    )

    $bytes = Read-SafeBytes -Path $Path -AllowedRoot $AllowedRoot -MaximumBytes $MaximumBytes
    if ($CanonicalLines) {
        if ($bytes.Length -eq 0 -or $bytes[$bytes.Length - 1] -ne 10 -or $bytes -contains 13) {
            throw [System.IO.InvalidDataException]::new('Text does not use canonical LF-terminated lines.')
        }
    }
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xef -and $bytes[1] -eq 0xbb -and $bytes[2] -eq 0xbf) {
        throw [System.IO.InvalidDataException]::new('UTF-8 BOM is not accepted.')
    }
    if ([System.Array]::IndexOf[byte]($bytes, [byte]0) -ge 0) {
        throw [System.IO.InvalidDataException]::new('NUL is not accepted in text evidence.')
    }
    if ($Ascii) {
        $strictAscii = [System.Text.Encoding]::GetEncoding(
            'us-ascii',
            [System.Text.EncoderFallback]::ExceptionFallback,
            [System.Text.DecoderFallback]::ExceptionFallback)
        $text = $strictAscii.GetString($bytes)
    }
    else {
        $text = [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes)
    }
    return [pscustomobject]@{
        Bytes = $bytes
        Text = $text
        Sha256 = Get-BytesSha256 $bytes
    }
}

function Read-SafeText {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$AllowedRoot,
        [ValidateRange(1, 268435456)] [int]$MaximumBytes = 1048576,
        [switch]$Ascii,
        [switch]$CanonicalLines
    )

    return (Read-SafeTextRecord `
            -Path $Path `
            -AllowedRoot $AllowedRoot `
            -MaximumBytes $MaximumBytes `
            -Ascii:$Ascii `
            -CanonicalLines:$CanonicalLines).Text
}

function Read-CanonicalLines {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$AllowedRoot,
        [ValidateRange(1, 268435456)] [int]$MaximumBytes = 10485760
    )

    $record = Read-SafeTextRecord `
        -Path $Path `
        -AllowedRoot $AllowedRoot `
        -MaximumBytes $MaximumBytes `
        -Ascii `
        -CanonicalLines
    $bytes = $record.Bytes
    $text = $record.Text
    $body = $text.Substring(0, $text.Length - 1)
    $lines = $body.Split("`n", [System.StringSplitOptions]::None)
    if ($lines.Count -eq 0 -or $lines[$lines.Count - 1] -eq '') {
        throw [System.IO.InvalidDataException]::new('Evidence contains an empty trailing row.')
    }
    return [pscustomobject]@{
        Bytes = $bytes
        Text = $text
        Lines = $lines
        Sha256 = $record.Sha256
    }
}

function Get-SafeSha256 {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$AllowedRoot
    )

    if (-not (Test-SafeLeaf -Path $Path -AllowedRoot $AllowedRoot)) {
        throw [System.IO.IOException]::new('Hash input is not a safe regular leaf.')
    }
    $stream = [System.IO.File]::Open(
        $Path,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::Read)
    try {
        $hash = [System.Security.Cryptography.SHA256]::HashData($stream)
    }
    finally {
        $stream.Dispose()
    }
    if (-not (Test-SafeLeaf -Path $Path -AllowedRoot $AllowedRoot)) {
        throw [System.IO.IOException]::new('Hash input did not remain a safe regular leaf.')
    }
    return [System.Convert]::ToHexString($hash).ToLowerInvariant()
}

function Write-SafeUtf8File {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$AllowedRoot,
        [Parameter(Mandatory)] [string]$Content
    )

    $target = [System.IO.Path]::GetFullPath($Path)
    if ($target -ceq [System.IO.Path]::GetFullPath($auditPath) -and
        -not (Test-EvidencePassPairAbsent)) {
        throw [System.IO.IOException]::new('The audit target is not absent at publication.')
    }
    if (-not (Test-EvidencePublicationAuthority) -or
        -not (Try-WriteAtomicUtf8File `
                -Path $target `
                -AllowedRoot $AllowedRoot `
                -Content $Content `
                -MaximumBytes 1048576) -or
        -not (Test-EvidencePublicationAuthority)) {
        throw [System.IO.IOException]::new('Output could not be published as a safe atomic leaf.')
    }
}

function New-AuditSidecarStage {
    param([Parameter(Mandatory)] [string]$AuditHash)

    if (-not (Test-EvidencePublicationAuthority) -or
        -not (Test-Sha256Text $AuditHash) -or
        -not (Test-SafeDirectory -Path $evidenceRoot -AllowedRoot $artifactsRoot) -or
        -not (Test-SafeLeaf -Path $auditSidecarPath -AllowedRoot $evidenceRoot -AllowMissing) -or
        [System.IO.File]::Exists($auditSidecarPath) -or
        [System.IO.Directory]::Exists($auditSidecarPath)) {
        throw [System.IO.IOException]::new('The audit sidecar cannot be staged safely.')
    }

    $content = "$AuditHash  evidence-audit.json`n"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($content)
    $stagePath = [System.IO.Path]::GetFullPath((Join-Path $evidenceRoot ('.stage-port-evidence-' + [System.Guid]::NewGuid().ToString('N'))))
    $stream = $null
    try {
        if (-not (Test-SafeLeaf -Path $stagePath -AllowedRoot $evidenceRoot -AllowMissing)) {
            throw [System.IO.IOException]::new('The audit sidecar stage path is unsafe.')
        }
        if (-not (Test-EvidencePublicationAuthority)) {
            throw [System.IO.IOException]::new('Publication authority changed before sidecar staging.')
        }
        $stream = [System.IO.File]::Open(
            $stagePath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None)
        if (-not (Test-EvidencePublicationAuthority)) {
            throw [System.IO.IOException]::new('Publication authority changed after sidecar stage creation.')
        }
        $stream.Write($bytes, 0, $bytes.Length)
        if (-not (Test-EvidencePublicationAuthority)) {
            throw [System.IO.IOException]::new('Publication authority changed during sidecar staging.')
        }
        $stream.Flush($true)
        $stream.Dispose()
        $stream = $null
        if (-not (Test-EvidencePublicationAuthority) -or
            -not (Test-SafeLeaf -Path $stagePath -AllowedRoot $evidenceRoot) -or
            (Get-SafeSha256 -Path $stagePath -AllowedRoot $evidenceRoot) -cne (Get-BytesSha256 $bytes)) {
            throw [System.IO.IOException]::new('The staged audit sidecar bytes are not current.')
        }
        if (-not (Test-EvidencePublicationAuthority)) {
            throw [System.IO.IOException]::new('Publication authority changed after sidecar staging.')
        }
        $script:SidecarStagePath = $stagePath
        return $stagePath
    }
    catch {
        if ($null -ne $stream) {
            try { $stream.Dispose() } catch { }
        }
        if ((Test-EvidencePublicationAuthority) -and
            (Test-SafeLeaf -Path $stagePath -AllowedRoot $evidenceRoot)) {
            try {
                if (Test-EvidencePublicationAuthority) {
                    [System.IO.File]::Delete($stagePath)
                    [void](Test-EvidencePublicationAuthority)
                }
            }
            catch { }
        }
        throw
    }
}

function Commit-AuditSidecarStage {
    param([Parameter(Mandatory)] [string]$StagePath)

    $fullStagePath = [System.IO.Path]::GetFullPath($StagePath)
    if (-not (Test-EvidencePublicationAuthority) -or
        $null -eq $script:SidecarStagePath -or
        $fullStagePath -cne [System.IO.Path]::GetFullPath($script:SidecarStagePath) -or
        -not (Test-SafeLeaf -Path $fullStagePath -AllowedRoot $evidenceRoot) -or
        -not (Test-SafeLeaf -Path $auditSidecarPath -AllowedRoot $evidenceRoot -AllowMissing) -or
        [System.IO.File]::Exists($auditSidecarPath) -or
        [System.IO.Directory]::Exists($auditSidecarPath)) {
        throw [System.IO.IOException]::new('The audit sidecar commit boundary is not current.')
    }
    if (-not (Test-EvidencePublicationAuthority)) {
        throw [System.IO.IOException]::new('Publication authority changed before the sidecar commit.')
    }
    [System.IO.File]::Move($fullStagePath, $auditSidecarPath, $false)
    if (-not (Test-EvidencePublicationAuthority)) {
        throw [System.IO.IOException]::new('Publication authority changed after the sidecar commit.')
    }
    $script:SidecarStagePath = $null
}

function Get-RepositoryRelativePath {
    param([Parameter(Mandatory)] [string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-ContainedPath -Candidate $fullPath -Root $repositoryRoot)) {
        throw [System.IO.InvalidDataException]::new('Audit path is not repository-relative.')
    }
    $relative = [System.IO.Path]::GetRelativePath($repositoryRoot, $fullPath).Replace('\', '/')
    foreach ($component in $relative.Split('/')) {
        if (-not (Test-SafeComponent $component)) {
            throw [System.IO.InvalidDataException]::new('Audit path has an unsafe component.')
        }
    }
    return $relative
}

function Invoke-BoundedProcess {
    param(
        [Parameter(Mandatory)] [string]$FileName,
        [Parameter(Mandatory)] [string[]]$Arguments,
        [Parameter(Mandatory)] [string]$WorkingDirectory,
        [ValidateRange(1, 30)] [int]$TimeoutSeconds = 10,
        [ValidateRange(1024, 8388608)] [int]$MaximumStdOutBytes = 4194304,
        [ValidateRange(1024, 1048576)] [int]$MaximumStdErrBytes = 262144,
        [ValidateRange(2048, 9437184)] [int]$MaximumCombinedBytes = 4456448
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FileName
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.Environment.Clear()
    if ($IsWindows) {
        $systemDirectory = [Environment]::SystemDirectory
        $windowsDirectory = [System.IO.Directory]::GetParent($systemDirectory).FullName
        $startInfo.Environment['SystemRoot'] = $windowsDirectory
        $startInfo.Environment['WINDIR'] = $windowsDirectory
        $startInfo.Environment['ComSpec'] = Join-Path $systemDirectory 'cmd.exe'
        $startInfo.Environment['PATH'] = $systemDirectory
        $startInfo.Environment['PATHEXT'] = '.COM;.EXE;.BAT;.CMD'
    }
    else {
        $startInfo.Environment['PATH'] = '/usr/bin:/bin'
    }
    foreach ($argument in $Arguments) {
        $startInfo.ArgumentList.Add($argument)
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $stdoutMemory = [System.IO.MemoryStream]::new()
    $stderrMemory = [System.IO.MemoryStream]::new()
    $started = $false
    $reaped = $false
    try {
        if (-not $process.Start()) {
            throw [System.InvalidOperationException]::new('Required process did not start.')
        }
        $started = $true
        $stdoutStream = $process.StandardOutput.BaseStream
        $stderrStream = $process.StandardError.BaseStream
        $stdoutBuffer = [byte[]]::new(4096)
        $stderrBuffer = [byte[]]::new(4096)
        $stdoutTask = $null
        $stderrTask = $null
        $stdoutEnded = $false
        $stderrEnded = $false
        $timedOut = $false
        $outputOverflow = $false
        $terminationRequested = $false
        $deadline = [System.DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
        $terminationDeadline = [System.DateTime]::MaxValue
        while (-not ($stdoutEnded -and $stderrEnded -and $process.HasExited)) {
            if (-not $stdoutEnded -and $null -eq $stdoutTask) {
                $stdoutTask = $stdoutStream.ReadAsync($stdoutBuffer, 0, $stdoutBuffer.Length)
            }
            if (-not $stderrEnded -and $null -eq $stderrTask) {
                $stderrTask = $stderrStream.ReadAsync($stderrBuffer, 0, $stderrBuffer.Length)
            }

            $now = [System.DateTime]::UtcNow
            if (-not $terminationRequested -and $now -ge $deadline) {
                $timedOut = $true
                $terminationRequested = $true
                $terminationDeadline = $now.AddSeconds(10)
                if (-not $process.HasExited) {
                    try { $process.Kill($true) } catch { }
                }
            }

            $pendingTasks = [System.Collections.Generic.List[System.Threading.Tasks.Task]]::new()
            if ($null -ne $stdoutTask) { $pendingTasks.Add($stdoutTask) }
            if ($null -ne $stderrTask) { $pendingTasks.Add($stderrTask) }
            if ($pendingTasks.Count -gt 0) {
                [void][System.Threading.Tasks.Task]::WaitAny($pendingTasks.ToArray(), 50)
            }
            else {
                Start-Sleep -Milliseconds 10
            }

            if ($null -ne $stdoutTask -and $stdoutTask.IsCompleted) {
                $count = $stdoutTask.GetAwaiter().GetResult()
                $stdoutTask = $null
                if ($count -eq 0) {
                    $stdoutEnded = $true
                }
                elseif (-not $outputOverflow -and
                    ($stdoutMemory.Length + $count -gt $MaximumStdOutBytes -or
                        $stdoutMemory.Length + $stderrMemory.Length + $count -gt $MaximumCombinedBytes)) {
                    $outputOverflow = $true
                }
                elseif (-not $outputOverflow) {
                    $stdoutMemory.Write($stdoutBuffer, 0, $count)
                }
            }
            if ($null -ne $stderrTask -and $stderrTask.IsCompleted) {
                $count = $stderrTask.GetAwaiter().GetResult()
                $stderrTask = $null
                if ($count -eq 0) {
                    $stderrEnded = $true
                }
                elseif (-not $outputOverflow -and
                    ($stderrMemory.Length + $count -gt $MaximumStdErrBytes -or
                        $stdoutMemory.Length + $stderrMemory.Length + $count -gt $MaximumCombinedBytes)) {
                    $outputOverflow = $true
                }
                elseif (-not $outputOverflow) {
                    $stderrMemory.Write($stderrBuffer, 0, $count)
                }
            }
            if ($outputOverflow -and -not $terminationRequested -and -not $process.HasExited) {
                $terminationRequested = $true
                $terminationDeadline = [System.DateTime]::UtcNow.AddSeconds(10)
                try { $process.Kill($true) } catch { }
            }
            if ($terminationRequested -and [System.DateTime]::UtcNow -ge $terminationDeadline) {
                break
            }
        }

        if (-not $process.HasExited) {
            try { $process.Kill($true) } catch { }
        }
        $reaped = $process.WaitForExit(10000)
        $encoding = [System.Text.UTF8Encoding]::new($false, $false)
        return [pscustomobject]@{
            ExitCode = if (-not $reaped) { 126 } elseif ($timedOut) { 124 } elseif ($outputOverflow) { 125 } else { $process.ExitCode }
            TimedOut = $timedOut
            OutputOverflow = $outputOverflow
            ProcessReaped = $reaped
            StdOut = $encoding.GetString($stdoutMemory.ToArray())
            StdErr = $encoding.GetString($stderrMemory.ToArray())
        }
    }
    finally {
        if ($started -and -not $reaped) {
            try {
                if (-not $process.HasExited) { $process.Kill($true) }
                $reaped = $process.WaitForExit(10000)
            }
            catch { }
        }
        $stdoutMemory.Dispose()
        $stderrMemory.Dispose()
        $process.Dispose()
    }
}

function Invoke-Git {
    param([Parameter(Mandatory)] [string[]]$Arguments)

    $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $git) {
        throw [System.IO.FileNotFoundException]::new('git is unavailable.')
    }
    $result = Invoke-BoundedProcess -FileName $git.Source -Arguments (@('-C', $repositoryRoot) + $Arguments) -WorkingDirectory $repositoryRoot
    if ($result.ExitCode -ne 0) {
        throw [System.InvalidOperationException]::new('A bounded git query failed.')
    }
    return $result.StdOut
}

function Split-NullText {
    param([AllowEmptyString()] [string]$Text)

    if ([string]::IsNullOrEmpty($Text)) {
        return @()
    }
    return @($Text.Split([char]0, [System.StringSplitOptions]::RemoveEmptyEntries))
}

function Assert-ScopeCheck {
    param(
        [Parameter(Mandatory)] [bool]$Condition,
        [Parameter(Mandatory)] [string]$Id,
        [switch]$Uncounted
    )

    if ($Uncounted) {
        if (-not $Condition) {
            throw [System.IO.InvalidDataException]::new("Scope assertion failed: $Id")
        }
        return
    }
    Confirm-Check $Condition $Id
}

function Test-OrdinalStringSetEqual {
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.HashSet[string]]$Left,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.HashSet[string]]$Right
    )

    if ($Left.Count -ne $Right.Count) {
        return $false
    }
    foreach ($value in $Left) {
        if (-not $Right.Contains($value)) {
            return $false
        }
    }
    return $true
}

function Get-GitScopeSnapshot {
    param([switch]$Uncounted)

    $indexRows = @(Split-NullText (Invoke-Git @('ls-files', '--stage', '-z', '--')))
    Assert-ScopeCheck ($indexRows.Count -gt 0) 'scope-index-not-empty' -Uncounted:$Uncounted
    $indexByPath = [System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::Ordinal)
    $objectIdLength = 0
    foreach ($indexRow in $indexRows) {
        $match = [regex]::Match(
            $indexRow,
            '^(100644|100755|120000|160000) ([0-9a-f]{40}|[0-9a-f]{64}) ([0-3])\t(.+)$')
        Assert-ScopeCheck $match.Success 'scope-index-row-shape' -Uncounted:$Uncounted
        $mode = $match.Groups[1].Value
        $objectId = $match.Groups[2].Value
        $stage = $match.Groups[3].Value
        $relativePath = $match.Groups[4].Value
        Assert-ScopeCheck ($stage -ceq '0') 'scope-index-stage-zero' -Uncounted:$Uncounted
        Assert-ScopeCheck (Test-CanonicalRelativePath $relativePath) 'scope-index-path-canonical' -Uncounted:$Uncounted
        if ($objectIdLength -eq 0) {
            $objectIdLength = $objectId.Length
        }
        Assert-ScopeCheck ($objectId.Length -eq $objectIdLength) 'scope-index-object-format' -Uncounted:$Uncounted
        Assert-ScopeCheck (-not $indexByPath.ContainsKey($relativePath)) 'scope-index-path-unique' -Uncounted:$Uncounted
        $indexByPath.Add($relativePath, "$mode`t$objectId`t$stage`t$relativePath")
    }
    $indexPaths = [string[]]$indexByPath.Keys
    [System.Array]::Sort($indexPaths, [System.StringComparer]::Ordinal)
    $indexEntries = [System.Collections.Generic.List[string]]::new()
    foreach ($indexPath in $indexPaths) {
        $indexEntries.Add($indexByPath[$indexPath])
    }
    $indexText = "# staxrip-git-index-v2`nmode`tobject`tstage`tpath`n" +
        (($indexEntries.ToArray() -join "`n") + "`n")
    $indexDigest = Get-BytesSha256 ([System.Text.Encoding]::ASCII.GetBytes($indexText))

    $statusRows = @(Split-NullText (Invoke-Git @(
                'status', '--porcelain=v2', '-z', '--no-renames', '--untracked-files=all', '--')))
    $statusByPath = [System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::Ordinal)
    $statusStaged = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $statusUnstaged = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $statusUntracked = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($statusRow in $statusRows) {
        if ($statusRow.StartsWith('1 ', [System.StringComparison]::Ordinal)) {
            $match = [regex]::Match(
                $statusRow,
                '^1 ([.MADRCUT]{2}) (N\.\.\.|S[.C][.M][.U]) ([0-7]{6}) ([0-7]{6}) ([0-7]{6}) ([0-9a-f]+) ([0-9a-f]+) (.+)$')
            Assert-ScopeCheck $match.Success 'scope-status-ordinary-shape' -Uncounted:$Uncounted
            $xy = $match.Groups[1].Value
            $submodule = $match.Groups[2].Value
            $headMode = $match.Groups[3].Value
            $indexMode = $match.Groups[4].Value
            $worktreeMode = $match.Groups[5].Value
            $headObject = $match.Groups[6].Value
            $indexObject = $match.Groups[7].Value
            $relativePath = $match.Groups[8].Value
            Assert-ScopeCheck (
                $headObject.Length -eq $objectIdLength -and $indexObject.Length -eq $objectIdLength) `
                'scope-status-object-format' -Uncounted:$Uncounted
            Assert-ScopeCheck (Test-CanonicalRelativePath $relativePath) 'scope-status-path-canonical' -Uncounted:$Uncounted
            Assert-ScopeCheck (-not $statusByPath.ContainsKey($relativePath)) 'scope-status-path-unique' -Uncounted:$Uncounted
            $statusByPath.Add(
                $relativePath,
                "1`t$xy`t$submodule`t$headMode`t$indexMode`t$worktreeMode`t$headObject`t$indexObject`t$relativePath")
            if ($xy[0] -cne '.') {
                [void]$statusStaged.Add($relativePath)
            }
            if ($xy[1] -cne '.') {
                [void]$statusUnstaged.Add($relativePath)
            }
        }
        elseif ($statusRow.StartsWith('? ', [System.StringComparison]::Ordinal)) {
            $relativePath = $statusRow.Substring(2)
            Assert-ScopeCheck (Test-CanonicalRelativePath $relativePath) 'scope-status-untracked-path-canonical' -Uncounted:$Uncounted
            Assert-ScopeCheck (-not $statusByPath.ContainsKey($relativePath)) 'scope-status-untracked-path-unique' -Uncounted:$Uncounted
            # Untracked entries carry their content hash in the status rows as well as in
            # the category entries below. An earlier version of this comment claimed this
            # closed a window in which an untracked file could be rewritten between the
            # producer runs and the audit unnoticed. That window never existed: the
            # category scan already content-hashed every untracked file and the snapshot
            # comparison already checked those hashes, proven from a pre-change record on
            # disk. What this actually adds is redundancy in the status section and
            # detection of a file changing between the status scan and the category scan
            # inside one snapshot, so the two sections cannot disagree silently.
            $untrackedFullPath = Join-Path $repositoryRoot ($relativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
            Assert-ScopeCheck (
                [System.IO.File]::Exists($untrackedFullPath)) 'scope-status-untracked-exists' -Uncounted:$Uncounted
            $untrackedSha = (Get-FileHash -LiteralPath $untrackedFullPath -Algorithm SHA256).Hash.ToLowerInvariant()
            $statusByPath.Add($relativePath, "?`t$relativePath`t$untrackedSha")
            [void]$statusUntracked.Add($relativePath)
        }
        else {
            Assert-ScopeCheck $false 'scope-status-record-supported' -Uncounted:$Uncounted
        }
    }
    $statusPaths = [string[]]$statusByPath.Keys
    [System.Array]::Sort($statusPaths, [System.StringComparer]::Ordinal)
    $statusEntries = [System.Collections.Generic.List[string]]::new()
    foreach ($statusPath in $statusPaths) {
        $statusEntries.Add($statusByPath[$statusPath])
    }
    $statusText = "# staxrip-git-status-v2`n" + (($statusEntries.ToArray() -join "`n") + "`n")
    $statusDigest = Get-BytesSha256 ([System.Text.Encoding]::ASCII.GetBytes($statusText))

    $categoryPaths = [ordered]@{
        committed = @(Split-NullText (Invoke-Git @(
                    'diff', '--no-ext-diff', '--no-textconv', '--no-renames',
                    '--name-only', '-z', "$BaseCommit..HEAD", '--')))
        staged = @(Split-NullText (Invoke-Git @(
                    'diff', '--no-ext-diff', '--no-textconv', '--no-renames',
                    '--cached', '--name-only', '-z', '--')))
        unstaged = @(Split-NullText (Invoke-Git @(
                    'diff', '--no-ext-diff', '--no-textconv', '--no-renames',
                    '--name-only', '-z', '--')))
        untracked = @(Split-NullText (Invoke-Git @(
                    'ls-files', '--others', '--exclude-standard', '-z', '--')))
    }
    $allowedDocumentationPrefixes = @(
        'Docs/Architecture/',
        'Docs/Planning/',
        'Docs/Review/',
        'Docs/Unknowns/',
        'Docs/Verification/'
    )
    $counts = [ordered]@{}
    $entries = [System.Collections.Generic.List[object]]::new()
    $categorySets = [System.Collections.Generic.Dictionary[string,System.Collections.Generic.HashSet[string]]]::new(
        [System.StringComparer]::Ordinal)
    $union = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($category in $categoryPaths.Keys) {
        $paths = [string[]]$categoryPaths[$category]
        [System.Array]::Sort($paths, [System.StringComparer]::Ordinal)
        $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($relativePath in $paths) {
            Assert-ScopeCheck ($seen.Add($relativePath)) 'scope-category-path-unique' -Uncounted:$Uncounted
            Assert-ScopeCheck (Test-CanonicalRelativePath $relativePath) 'scope-path-canonical' -Uncounted:$Uncounted
            Assert-ScopeCheck (-not $relativePath.StartsWith('Source/', [System.StringComparison]::Ordinal)) 'scope-source-unchanged' -Uncounted:$Uncounted
            $allowed = $relativePath.StartsWith('CrossPlatform/', [System.StringComparison]::Ordinal) -or
                $relativePath -ceq 'AGENTS.md'
            if (-not $allowed) {
                foreach ($prefix in $allowedDocumentationPrefixes) {
                    if ($relativePath.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
                        $allowed = $true
                        break
                    }
                }
            }
            Assert-ScopeCheck $allowed 'scope-path-allowlisted' -Uncounted:$Uncounted

            $nativePath = $relativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            $fullPath = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $nativePath))
            Assert-ScopeCheck (Test-ContainedPath -Candidate $fullPath -Root $repositoryRoot) 'scope-path-contained' -Uncounted:$Uncounted
            if ([System.IO.File]::Exists($fullPath)) {
                Assert-ScopeCheck (Test-SafeLeaf -Path $fullPath -AllowedRoot $repositoryRoot) 'scope-file-safe' -Uncounted:$Uncounted
                $before = Get-Item -LiteralPath $fullPath -Force
                $sha256 = Get-SafeSha256 -Path $fullPath -AllowedRoot $repositoryRoot
                $after = Get-Item -LiteralPath $fullPath -Force
                Assert-ScopeCheck ($before.Length -eq $after.Length) 'scope-file-length-stable' -Uncounted:$Uncounted
                $presence = 'file'
                $length = [long]$after.Length
            }
            else {
                Assert-ScopeCheck (-not [System.IO.Directory]::Exists($fullPath)) 'scope-deletion-not-directory' -Uncounted:$Uncounted
                Assert-ScopeCheck ($category -cne 'untracked') 'scope-deletion-tracked' -Uncounted:$Uncounted
                $ancestor = [System.IO.Directory]::GetParent($fullPath)
                while ($null -ne $ancestor -and -not [System.IO.Directory]::Exists($ancestor.FullName)) {
                    Assert-ScopeCheck (-not [System.IO.File]::Exists($ancestor.FullName)) 'scope-deletion-parent-not-file' -Uncounted:$Uncounted
                    $ancestor = $ancestor.Parent
                }
                Assert-ScopeCheck ($null -ne $ancestor) 'scope-deletion-parent-present' -Uncounted:$Uncounted
                Assert-ScopeCheck (
                    (Test-SafeDirectory -Path $ancestor.FullName -AllowedRoot $repositoryRoot)) `
                    'scope-deletion-parent-safe' -Uncounted:$Uncounted
                $presence = 'deleted'
                $length = [long]0
                $sha256 = $emptySha256
            }
            [void]$union.Add($relativePath)
            $entries.Add([ordered]@{
                    category = $category
                    path = $relativePath
                    presence = $presence
                    length = $length
                    sha256 = $sha256
                })
        }
        $categorySets.Add($category, $seen)
        $counts[$category] = $paths.Count
    }
    $counts['union'] = $union.Count
    Assert-ScopeCheck ($union.Count -gt 0) 'scope-not-empty' -Uncounted:$Uncounted
    Assert-ScopeCheck (
        (Test-OrdinalStringSetEqual -Left $categorySets['staged'] -Right $statusStaged)) `
        'scope-status-staged-exact' -Uncounted:$Uncounted
    Assert-ScopeCheck (
        (Test-OrdinalStringSetEqual -Left $categorySets['unstaged'] -Right $statusUnstaged)) `
        'scope-status-unstaged-exact' -Uncounted:$Uncounted
    Assert-ScopeCheck (
        (Test-OrdinalStringSetEqual -Left $categorySets['untracked'] -Right $statusUntracked)) `
        'scope-status-untracked-exact' -Uncounted:$Uncounted

    $scopeLines = [System.Collections.Generic.List[string]]::new()
    $scopeLines.Add('# staxrip-current-scope-v2')
    $scopeLines.Add("index`t$indexDigest`t$($indexEntries.Count)")
    $scopeLines.Add("status`t$statusDigest`t$($statusEntries.Count)")
    foreach ($category in @('committed', 'staged', 'unstaged', 'untracked', 'union')) {
        $scopeLines.Add("count`t$category`t$($counts[$category])")
    }
    $scopeLines.Add("category`tpath`tpresence`tlength`tsha256")
    foreach ($entry in $entries) {
        $scopeLines.Add("$($entry.category)`t$($entry.path)`t$($entry.presence)`t$($entry.length)`t$($entry.sha256)")
    }
    $scopeText = ($scopeLines -join "`n") + "`n"
    $changedPaths = [string[]]$union
    [System.Array]::Sort($changedPaths, [System.StringComparer]::Ordinal)
    return [pscustomobject]@{
        Schema = 'staxrip-current-scope-v2'
        Digest = Get-BytesSha256 ([System.Text.Encoding]::ASCII.GetBytes($scopeText))
        IndexDigest = $indexDigest
        IndexEntries = [string[]]$indexEntries.ToArray()
        StatusDigest = $statusDigest
        StatusEntries = [string[]]$statusEntries.ToArray()
        Counts = $counts
        Entries = [object[]]$entries.ToArray()
        CategoryPaths = $categoryPaths
        ChangedPaths = $changedPaths
    }
}

function Test-GitScopeSnapshotsEqual {
    param(
        [Parameter(Mandatory)]$Left,
        [Parameter(Mandatory)]$Right
    )

    if ($Left.Schema -cne $Right.Schema -or
        $Left.Digest -cne $Right.Digest -or
        $Left.IndexDigest -cne $Right.IndexDigest -or
        $Left.StatusDigest -cne $Right.StatusDigest -or
        $Left.IndexEntries.Count -ne $Right.IndexEntries.Count -or
        $Left.StatusEntries.Count -ne $Right.StatusEntries.Count -or
        $Left.Entries.Count -ne $Right.Entries.Count) {
        return $false
    }
    foreach ($category in @('committed', 'staged', 'unstaged', 'untracked', 'union')) {
        if ([long]$Left.Counts[$category] -ne [long]$Right.Counts[$category]) {
            return $false
        }
    }
    for ($index = 0; $index -lt $Left.IndexEntries.Count; $index++) {
        if ([string]$Left.IndexEntries[$index] -cne [string]$Right.IndexEntries[$index]) {
            return $false
        }
    }
    for ($index = 0; $index -lt $Left.StatusEntries.Count; $index++) {
        if ([string]$Left.StatusEntries[$index] -cne [string]$Right.StatusEntries[$index]) {
            return $false
        }
    }
    for ($index = 0; $index -lt $Left.Entries.Count; $index++) {
        $leftEntry = $Left.Entries[$index]
        $rightEntry = $Right.Entries[$index]
        if ([string]$leftEntry.category -cne [string]$rightEntry.category -or
            [string]$leftEntry.path -cne [string]$rightEntry.path -or
            [string]$leftEntry.presence -cne [string]$rightEntry.presence -or
            [long]$leftEntry.length -ne [long]$rightEntry.length -or
            [string]$leftEntry.sha256 -cne [string]$rightEntry.sha256) {
            return $false
        }
    }
    return $true
}

function Read-JsonRecord {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$ExpectedSchema
    )

    Confirm-Check ($Name -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}\.json$') 'json-name-grammar'
    $path = [System.IO.Path]::GetFullPath((Join-Path $evidenceRoot $Name))
    Confirm-Check (Test-SafeLeaf -Path $path -AllowedRoot $evidenceRoot) "json-$Name-safe"
    try {
        $textRecord = Read-SafeTextRecord `
            -Path $path `
            -AllowedRoot $evidenceRoot `
            -MaximumBytes 1048576 `
            -CanonicalLines
        $text = $textRecord.Text
        $options = [System.Text.Json.JsonDocumentOptions]::new()
        $options.AllowTrailingCommas = $false
        $options.CommentHandling = [System.Text.Json.JsonCommentHandling]::Disallow
        $options.MaxDepth = 32
        $document = [System.Text.Json.JsonDocument]::Parse($text, $options)
        $script:JsonDocuments.Add($document)
    }
    catch {
        Stop-Gate -Message "Evidence record is not canonical strict UTF-8 JSON: $Name" -Output $_.Exception.Message
    }
    $root = $document.RootElement
    Confirm-Check ($root.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) "json-$Name-root"
    $schemaValue = [System.Text.Json.JsonElement]::new()
    Confirm-Check ($root.TryGetProperty('schema', [ref]$schemaValue)) "json-$Name-schema-present"
    Confirm-Check (
        $schemaValue.ValueKind -eq [System.Text.Json.JsonValueKind]::String -and
        $schemaValue.GetString() -ceq $ExpectedSchema) "json-$Name-schema"
    return [pscustomobject]@{
        Path = $path
        Text = $text
        Sha256 = $textRecord.Sha256
        Document = $document
        Root = $root
    }
}

function Assert-JsonObjectShape {
    param(
        [Parameter(Mandatory)] [System.Text.Json.JsonElement]$Element,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]]$ExpectedNames,
        [Parameter(Mandatory)] [string]$Id
    )

    Confirm-Check ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) "$Id-object"
    $properties = @($Element.EnumerateObject())
    Confirm-Check ($properties.Count -eq $ExpectedNames.Count) "$Id-property-count"
    $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $fields = [System.Collections.Generic.Dictionary[string,System.Text.Json.JsonElement]]::new(
        [System.StringComparer]::Ordinal)
    foreach ($property in $properties) {
        Confirm-Check ($names.Add($property.Name)) "$Id-property-unique"
        Confirm-Check ($ExpectedNames -ccontains $property.Name) "$Id-property-known"
        $fields.Add($property.Name, $property.Value)
    }
    foreach ($expectedName in $ExpectedNames) {
        Confirm-Check ($names.Contains($expectedName)) "$Id-property-required"
    }
    return ,$fields
}

function Get-UniqueJsonProperty {
    param(
        [Parameter(Mandatory)] [System.Text.Json.JsonElement]$Element,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [System.Text.Json.JsonValueKind]$ExpectedKind,
        [Parameter(Mandatory)] [string]$Id
    )

    Confirm-Check ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) "$Id-parent-object"
    $matches = @($Element.EnumerateObject() | Where-Object {
            $_.Name.Equals($Name, [System.StringComparison]::OrdinalIgnoreCase)
        })
    Confirm-Check ($matches.Count -eq 1) "$Id-unique"
    Confirm-Check ($matches[0].Name -ceq $Name) "$Id-canonical-name"
    Confirm-Check ($matches[0].Value.ValueKind -eq $ExpectedKind) "$Id-type"
    return $matches[0].Value
}

function Get-JsonStringField {
    param(
        [Parameter(Mandatory)]$Fields,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Id
    )

    $element = $Fields[$Name]
    Confirm-Check ($element.ValueKind -eq [System.Text.Json.JsonValueKind]::String) "$Id-type"
    $value = $element.GetString()
    Confirm-Check ($null -ne $value) "$Id-not-null"
    return [string]$value
}

function Get-JsonBooleanField {
    param(
        [Parameter(Mandatory)]$Fields,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Id
    )

    $element = $Fields[$Name]
    Confirm-Check (
        $element.ValueKind -eq [System.Text.Json.JsonValueKind]::True -or
        $element.ValueKind -eq [System.Text.Json.JsonValueKind]::False) "$Id-type"
    return $element.GetBoolean()
}

function Get-JsonIntegerField {
    param(
        [Parameter(Mandatory)]$Fields,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Id,
        [switch]$AllowNegative
    )

    $element = $Fields[$Name]
    Confirm-Check ($element.ValueKind -eq [System.Text.Json.JsonValueKind]::Number) "$Id-type"
    $raw = $element.GetRawText()
    $pattern = if ($AllowNegative) { '^(?:0|-?[1-9][0-9]*)$' } else { '^(?:0|[1-9][0-9]*)$' }
    Confirm-Check ($raw -match $pattern) "$Id-canonical"
    $value = 0
    Confirm-Check ($element.TryGetInt32([ref]$value)) "$Id-range"
    return $value
}

function Get-JsonInt64Field {
    param(
        [Parameter(Mandatory)]$Fields,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Id
    )

    $element = $Fields[$Name]
    Confirm-Check ($element.ValueKind -eq [System.Text.Json.JsonValueKind]::Number) "$Id-type"
    $raw = $element.GetRawText()
    Confirm-Check ($raw -match '^(?:0|[1-9][0-9]*)$') "$Id-canonical"
    $value = [long]0
    Confirm-Check ($element.TryGetInt64([ref]$value)) "$Id-range"
    return $value
}

function Get-JsonArrayItems {
    param(
        [Parameter(Mandatory)] [System.Text.Json.JsonElement]$Element,
        [Parameter(Mandatory)] [string]$Id
    )

    Confirm-Check ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) "$Id-type"
    return @($Element.EnumerateArray())
}

function Assert-ExactStringArray {
    param(
        [Parameter(Mandatory)] [System.Text.Json.JsonElement]$Element,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]]$Expected,
        [Parameter(Mandatory)] [string]$Id
    )

    $items = @(Get-JsonArrayItems -Element $Element -Id $Id)
    Confirm-Check ($items.Count -eq $Expected.Count) "$Id-count"
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        Confirm-Check ($items[$index].ValueKind -eq [System.Text.Json.JsonValueKind]::String) "$Id-item-type"
        Confirm-Check ($items[$index].GetString() -ceq $Expected[$index]) "$Id-item-value"
    }
}

function Test-Sha256Text {
    param([AllowEmptyString()] [string]$Value)
    return $Value -cmatch '^[0-9a-f]{64}$'
}

function Test-CanonicalNonNegativeIntegerText {
    param([AllowEmptyString()] [string]$Value)

    if ($Value -notmatch '^(?:0|[1-9][0-9]*)$') {
        return $false
    }
    $parsed = [long]0
    return [long]::TryParse(
        $Value,
        [System.Globalization.NumberStyles]::None,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$parsed)
}

function Convert-ToInt64 {
    param(
        [Parameter(Mandatory)] [string]$Value,
        [Parameter(Mandatory)] [string]$Id
    )

    Confirm-Check (Test-CanonicalNonNegativeIntegerText $Value) "$Id-grammar"
    $parsed = [long]0
    [void][long]::TryParse(
        $Value,
        [System.Globalization.NumberStyles]::None,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$parsed)
    return $parsed
}

function Test-CanonicalRelativePath {
    param(
        [AllowEmptyString()] [string]$Value,
        [switch]$AllowDot
    )

    if ($AllowDot -and $Value -ceq '.') {
        return $true
    }
    if ($Value.Length -eq 0 -or $Value.Length -gt 2048 -or
        $Value -notmatch '^[\x20-\x7e]+$' -or
        $Value.Contains('\') -or
        $Value.StartsWith('/', [System.StringComparison]::Ordinal) -or
        $Value.EndsWith('/', [System.StringComparison]::Ordinal)) {
        return $false
    }
    foreach ($component in $Value.Split('/')) {
        if (-not (Test-SafeComponent $component)) {
            return $false
        }
    }
    return $true
}

function Test-ByteArraysEqual {
    param(
        [Parameter(Mandatory)] [byte[]]$Left,
        [Parameter(Mandatory)] [byte[]]$Right
    )

    if ($Left.Length -ne $Right.Length) {
        return $false
    }
    for ($index = 0; $index -lt $Left.Length; $index++) {
        if ($Left[$index] -ne $Right[$index]) {
            return $false
        }
    }
    return $true
}

function Get-SafeTreeInventory {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$AllowedRoot,
        [ValidateRange(1, 200000)] [int]$MaximumEntries = 50000
    )

    if (-not (Test-SafeDirectory -Path $Root -AllowedRoot $AllowedRoot)) {
        throw [System.IO.IOException]::new('Tree root is not a safe regular directory.')
    }
    $inventory = [System.Collections.Generic.Dictionary[string,object]]::new(
        [System.StringComparer]::Ordinal)
    $pending = [System.Collections.Generic.Queue[string]]::new()
    $pending.Enqueue($Root)
    while ($pending.Count -gt 0) {
        $directory = $pending.Dequeue()
        foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force)) {
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw [System.IO.IOException]::new('Tree contains a reparse point.')
            }
            $relative = [System.IO.Path]::GetRelativePath($Root, $item.FullName).Replace('\', '/')
            if (-not (Test-CanonicalRelativePath $relative) -or $inventory.ContainsKey($relative)) {
                throw [System.IO.InvalidDataException]::new('Tree contains a non-canonical or duplicate path.')
            }
            if ($item.PSIsContainer) {
                if (-not (Test-SafeDirectory -Path $item.FullName -AllowedRoot $AllowedRoot)) {
                    throw [System.IO.IOException]::new('Tree contains an unsafe directory.')
                }
                $pending.Enqueue($item.FullName)
            }
            elseif (-not (Test-SafeLeaf -Path $item.FullName -AllowedRoot $AllowedRoot)) {
                throw [System.IO.IOException]::new('Tree contains an unsafe file.')
            }
            $inventory.Add($relative, $item)
            if ($inventory.Count -gt $MaximumEntries) {
                throw [System.IO.InvalidDataException]::new('Tree inventory exceeds its bound.')
            }
        }
    }
    return ,$inventory
}

function Assert-ArchiveBindingCondition {
    param(
        [Parameter(Mandatory)] [bool]$Condition,
        [Parameter(Mandatory)] [string]$Id
    )

    switch ($script:ArchiveAssertionMode) {
        'Primary' {
            $script:Checks++
        }
        'Closeout' {
            $script:CloseoutChecks++
        }
        default {
            throw [System.InvalidOperationException]::new(
                'Archive extraction binding assertion mode is not active.')
        }
    }
    if (-not $Condition) {
        throw [System.IO.InvalidDataException]::new("Archive extraction binding failed: $Id")
    }
}

function Test-CanonicalArchiveEntryPath {
    param(
        [AllowEmptyString()] [string]$Path,
        [Parameter(Mandatory)] [bool]$IsDirectory
    )

    if ([string]::IsNullOrEmpty($Path) -or
        $Path -match '[^\x20-\x7e]' -or
        $Path.Contains('\', [System.StringComparison]::Ordinal) -or
        $Path.StartsWith('/', [System.StringComparison]::Ordinal) -or
        $Path.Contains('//', [System.StringComparison]::Ordinal) -or
        ($IsDirectory -and -not $Path.EndsWith('/', [System.StringComparison]::Ordinal)) -or
        (-not $IsDirectory -and $Path.EndsWith('/', [System.StringComparison]::Ordinal))) {
        return $false
    }
    $canonical = if ($IsDirectory) { $Path.Substring(0, $Path.Length - 1) } else { $Path }
    if ([string]::IsNullOrEmpty($canonical)) {
        return $false
    }
    foreach ($segment in $canonical.Split('/')) {
        if ([string]::IsNullOrEmpty($segment) -or
            $segment -in @('.', '..') -or
            $segment.IndexOfAny([char[]]'<>:"|?*') -ge 0 -or
            $segment.EndsWith(' ', [System.StringComparison]::Ordinal) -or
            $segment.EndsWith('.', [System.StringComparison]::Ordinal) -or
            $segment -match '^(?i:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?$') {
            return $false
        }
    }
    return $true
}

function Get-SafeSha512Base64 {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$AllowedRoot
    )

    if (-not (Test-SafeLeaf -Path $Path -AllowedRoot $AllowedRoot)) {
        throw [System.IO.IOException]::new('SHA-512 input is not a safe regular file.')
    }
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        return [System.Convert]::ToBase64String(
            [System.Security.Cryptography.SHA512]::HashData($stream))
    }
    finally {
        $stream.Dispose()
    }
}

function Get-ArchiveExtractionBinding {
    param(
        [Parameter(Mandatory)] [string]$PackageKey,
        [Parameter(Mandatory)] [string]$PackageId,
        [Parameter(Mandatory)] [string]$ArchivePath,
        [Parameter(Mandatory)] [string]$ArchiveName,
        [Parameter(Mandatory)] [string]$PackageDirectory,
        [Parameter(Mandatory)]
        [ValidateSet('Primary', 'Closeout')]
        [string]$AssertionMode
    )

    $script:ArchiveAssertionMode = $AssertionMode
    Assert-ArchiveBindingCondition `
        (Test-SafeDirectory -Path $PackageDirectory -AllowedRoot $packagesRoot) `
        'package-directory-safe'
    Assert-ArchiveBindingCondition `
        (Test-SafeLeaf -Path $ArchivePath -AllowedRoot $packagesRoot) `
        'archive-safe'
    Assert-ArchiveBindingCondition `
        ([System.IO.Path]::GetFileName($ArchivePath) -ceq $ArchiveName) `
        'archive-name-current'

    $tree = Get-SafeTreeInventory `
        -Root $PackageDirectory `
        -AllowedRoot $packagesRoot `
        -MaximumEntries 10000
    $diskFiles = [System.Collections.Generic.Dictionary[string,object]]::new(
        [System.StringComparer]::Ordinal)
    $diskPathsIgnoreCase = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    [long]$diskBytes = 0
    foreach ($entry in $tree.GetEnumerator()) {
        if ($entry.Value.PSIsContainer) {
            continue
        }
        $relativePath = [string]$entry.Key
        $file = $entry.Value
        Assert-ArchiveBindingCondition (Test-CanonicalRelativePath $relativePath) 'disk-path-canonical'
        Assert-ArchiveBindingCondition ($diskPathsIgnoreCase.Add($relativePath)) 'disk-path-case-unique'
        Assert-ArchiveBindingCondition (
            [long]$file.Length -ge 0 -and [long]$file.Length -le 1073741824) 'disk-file-size'
        $diskBytes += [long]$file.Length
        Assert-ArchiveBindingCondition ($diskBytes -le 2147483648) 'disk-total-size'
        $beforeLength = [long]$file.Length
        $sha256 = Get-SafeSha256 -Path $file.FullName -AllowedRoot $packagesRoot
        $after = Get-Item -LiteralPath $file.FullName -Force
        Assert-ArchiveBindingCondition ([long]$after.Length -eq $beforeLength) 'disk-file-stable'
        $diskFiles.Add($relativePath, [pscustomobject]@{
                Length = [long]$after.Length
                Sha256 = $sha256
            })
    }
    Assert-ArchiveBindingCondition ($diskFiles.Count -gt 0 -and $diskFiles.Count -le 10000) 'disk-file-count'

    $sha512SidecarName = "$ArchiveName.sha512"
    $allowedDiskOnly = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($allowedName in @('.nupkg.metadata', $ArchiveName, $sha512SidecarName)) {
        [void]$allowedDiskOnly.Add($allowedName)
        Assert-ArchiveBindingCondition ($diskFiles.ContainsKey($allowedName)) 'disk-only-required'
    }
    Assert-ArchiveBindingCondition ($diskFiles[$sha512SidecarName].Length -eq 88) 'archive-sha512-sidecar-length'
    $sha512SidecarPath = Join-Path $PackageDirectory $sha512SidecarName
    $sidecarBytes = Read-SafeBytes `
        -Path $sha512SidecarPath `
        -AllowedRoot $packagesRoot `
        -MaximumBytes 88
    Assert-ArchiveBindingCondition ($sidecarBytes.Length -eq 88) 'archive-sha512-sidecar-read-length'
    $recordedSidecarSha512 = [System.Text.Encoding]::ASCII.GetString($sidecarBytes)
    Assert-ArchiveBindingCondition (
        $recordedSidecarSha512 -cmatch '^[A-Za-z0-9+/]{86}==$') 'archive-sha512-sidecar-grammar'

    $archiveBefore = Get-Item -LiteralPath $ArchivePath -Force
    $archiveLength = [long]$archiveBefore.Length
    Assert-ArchiveBindingCondition (
        $archiveLength -gt 0 -and $archiveLength -le 1073741824) 'archive-length-bound'
    $archiveSha256Before = Get-SafeSha256 -Path $ArchivePath -AllowedRoot $packagesRoot
    $archiveSha512Before = Get-SafeSha512Base64 -Path $ArchivePath -AllowedRoot $packagesRoot
    Assert-ArchiveBindingCondition (
        $archiveSha512Before -ceq $recordedSidecarSha512) 'archive-sha512-sidecar-current'

    $seenArchivePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $seenArchivePathsIgnoreCase = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    $matchedDiskPayloads = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $archiveOnlyMetadataPaths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal)
    $archiveEntryCount = 0
    $archivePayloadFileCount = 0
    [long]$archiveUncompressedBytes = 0
    $archive = $null
    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
        foreach ($entry in $archive.Entries) {
            $entryPath = [string]$entry.FullName
            $isDirectory = [string]::IsNullOrEmpty($entry.Name)
            Assert-ArchiveBindingCondition `
                (Test-CanonicalArchiveEntryPath -Path $entryPath -IsDirectory $isDirectory) `
                'archive-path-canonical'
            Assert-ArchiveBindingCondition ($seenArchivePaths.Add($entryPath)) 'archive-path-unique'
            Assert-ArchiveBindingCondition ($seenArchivePathsIgnoreCase.Add($entryPath)) 'archive-path-case-unique'

            $externalAttributes = [System.BitConverter]::ToUInt32(
                [System.BitConverter]::GetBytes([int]$entry.ExternalAttributes), 0)
            $unixFileType = (($externalAttributes -shr 16) -band 0xf000)
            if ($isDirectory) {
                Assert-ArchiveBindingCondition ($unixFileType -in @(0, 0x4000)) 'archive-directory-type'
                continue
            }
            Assert-ArchiveBindingCondition ($unixFileType -in @(0, 0x8000)) 'archive-file-type'

            $archiveEntryCount++
            Assert-ArchiveBindingCondition (
                $archiveEntryCount -le 10000 -and $entry.Length -ge 0 -and
                $entry.Length -le 1073741824) 'archive-entry-bound'
            $archiveUncompressedBytes += [long]$entry.Length
            Assert-ArchiveBindingCondition ($archiveUncompressedBytes -le 2147483648) 'archive-total-size'

            $isArchiveOnlyMetadata = $entryPath -ceq '_rels/.rels' -or
                $entryPath -ceq '[Content_Types].xml' -or
                $entryPath -cmatch '^package/services/metadata/core-properties/[0-9a-f]{32}\.psmdcp$'
            if ($isArchiveOnlyMetadata) {
                [void]$archiveOnlyMetadataPaths.Add($entryPath)
                continue
            }

            if ($entryPath.EndsWith('.nuspec', [System.StringComparison]::OrdinalIgnoreCase)) {
                Assert-ArchiveBindingCondition ($entryPath -ceq "$PackageId.nuspec") 'archive-nuspec-name'
                $diskPath = "$($PackageId.ToLowerInvariant()).nuspec"
            }
            else {
                $diskPath = $entryPath
            }
            Assert-ArchiveBindingCondition (-not $allowedDiskOnly.Contains($diskPath)) 'archive-payload-not-disk-only'
            Assert-ArchiveBindingCondition ($diskFiles.ContainsKey($diskPath)) 'archive-payload-on-disk'
            Assert-ArchiveBindingCondition ($matchedDiskPayloads.Add($diskPath)) 'archive-payload-one-to-one'
            $diskFile = $diskFiles[$diskPath]
            Assert-ArchiveBindingCondition (
                [long]$diskFile.Length -eq [long]$entry.Length) 'archive-payload-length'
            $entryStream = $entry.Open()
            try {
                $entrySha256 = [System.Convert]::ToHexString(
                    [System.Security.Cryptography.SHA256]::HashData($entryStream)).ToLowerInvariant()
            }
            finally {
                $entryStream.Dispose()
            }
            Assert-ArchiveBindingCondition (
                $entrySha256 -ceq [string]$diskFile.Sha256) 'archive-payload-sha256'
            $archivePayloadFileCount++
        }
    }
    finally {
        if ($null -ne $archive) {
            $archive.Dispose()
        }
    }

    $corePropertyCount = @($archiveOnlyMetadataPaths | Where-Object {
            $_ -cmatch '^package/services/metadata/core-properties/[0-9a-f]{32}\.psmdcp$'
        }).Count
    Assert-ArchiveBindingCondition ($archiveOnlyMetadataPaths.Count -eq 3) 'archive-only-metadata-count'
    Assert-ArchiveBindingCondition ($archiveOnlyMetadataPaths.Contains('_rels/.rels')) 'archive-rels-present'
    Assert-ArchiveBindingCondition ($archiveOnlyMetadataPaths.Contains('[Content_Types].xml')) 'archive-content-types-present'
    Assert-ArchiveBindingCondition ($corePropertyCount -eq 1) 'archive-core-properties-cardinality'
    $expectedPayloadCount = $diskFiles.Count - $allowedDiskOnly.Count
    Assert-ArchiveBindingCondition (
        $archivePayloadFileCount -eq $expectedPayloadCount -and
        $matchedDiskPayloads.Count -eq $expectedPayloadCount) 'archive-payload-count'
    foreach ($diskPath in $diskFiles.Keys) {
        Assert-ArchiveBindingCondition (
            $allowedDiskOnly.Contains($diskPath) -or $matchedDiskPayloads.Contains($diskPath)) `
            'disk-file-bound'
    }

    $archiveAfter = Get-Item -LiteralPath $ArchivePath -Force
    $archiveSha256After = Get-SafeSha256 -Path $ArchivePath -AllowedRoot $packagesRoot
    $archiveSha512After = Get-SafeSha512Base64 -Path $ArchivePath -AllowedRoot $packagesRoot
    Assert-ArchiveBindingCondition ([long]$archiveAfter.Length -eq $archiveLength) 'archive-length-stable'
    Assert-ArchiveBindingCondition ($archiveSha256After -ceq $archiveSha256Before) 'archive-sha256-stable'
    Assert-ArchiveBindingCondition ($archiveSha512After -ceq $archiveSha512Before) 'archive-sha512-stable'

    $inventoryPaths = [string[]]@($diskFiles.Keys)
    [System.Array]::Sort($inventoryPaths, [System.StringComparer]::Ordinal)
    $inventoryText = [System.Text.StringBuilder]::new()
    foreach ($inventoryPath in $inventoryPaths) {
        $inventoryFile = $diskFiles[$inventoryPath]
        [void]$inventoryText.Append($inventoryPath)
        [void]$inventoryText.Append("`t")
        [void]$inventoryText.Append(
            ([long]$inventoryFile.Length).ToString([System.Globalization.CultureInfo]::InvariantCulture))
        [void]$inventoryText.Append("`t")
        [void]$inventoryText.Append([string]$inventoryFile.Sha256)
        [void]$inventoryText.Append("`n")
    }
    $inventorySha256 = Get-BytesSha256 (
        [System.Text.UTF8Encoding]::new($false).GetBytes($inventoryText.ToString()))

    $result = [pscustomobject]@{
        ArchiveLength = $archiveLength
        ArchiveSha256 = $archiveSha256After
        ArchiveSha512 = $archiveSha512After
        ArchiveFileEntryCount = $archiveEntryCount
        ArchivePayloadFileCount = $archivePayloadFileCount
        ArchiveOnlyMetadataCount = $archiveOnlyMetadataPaths.Count
        DiskFileCount = $diskFiles.Count
        DiskTotalBytes = $diskBytes
        InventorySha256 = $inventorySha256
    }
    $script:ArchiveAssertionMode = $null
    return $result
}

function Get-SourceFileInventory {
    if (-not (Test-SafeDirectory -Path $crossPlatformRoot -AllowedRoot $repositoryRoot)) {
        throw [System.IO.IOException]::new('CrossPlatform source root is unsafe.')
    }
    $files = [System.Collections.Generic.Dictionary[string,System.IO.FileInfo]]::new(
        [System.StringComparer]::Ordinal)
    $pending = [System.Collections.Generic.Queue[string]]::new()
    $pending.Enqueue($crossPlatformRoot)
    while ($pending.Count -gt 0) {
        $directory = $pending.Dequeue()
        foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force)) {
            $relative = [System.IO.Path]::GetRelativePath($crossPlatformRoot, $item.FullName).Replace('\', '/')
            $components = $relative.Split('/')
            $generated = $relative -ceq 'artifacts' -or
                $relative.StartsWith('artifacts/', [System.StringComparison]::Ordinal) -or
                $components -ccontains 'bin' -or
                $components -ccontains 'obj'
            if ($generated) {
                continue
            }
            if (-not (Test-CanonicalRelativePath $relative) -or
                ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw [System.IO.InvalidDataException]::new('Source scope contains an unsafe path.')
            }
            if ($item.PSIsContainer) {
                if (-not (Test-SafeDirectory -Path $item.FullName -AllowedRoot $crossPlatformRoot)) {
                    throw [System.IO.IOException]::new('Source scope contains an unsafe directory.')
                }
                $pending.Enqueue($item.FullName)
            }
            else {
                if (-not (Test-SafeLeaf -Path $item.FullName -AllowedRoot $crossPlatformRoot)) {
                    throw [System.IO.IOException]::new('Source scope contains an unsafe file.')
                }
                $files.Add($relative, [System.IO.FileInfo]$item)
            }
            if ($files.Count -gt 10000) {
                throw [System.IO.InvalidDataException]::new('Source scope exceeds its reviewed bound.')
            }
        }
    }
    return ,$files
}

function Confirm-Sidecar {
    param(
        [Parameter(Mandatory)] [string]$SourcePath,
        [Parameter(Mandatory)] [string]$ExpectedSourceSha256,
        [Parameter(Mandatory)] [string]$SidecarPath,
        [Parameter(Mandatory)] [string]$AllowedRoot,
        [Parameter(Mandatory)] [string]$Id
    )

    Confirm-Check (Test-SafeLeaf -Path $SourcePath -AllowedRoot $AllowedRoot) "$Id-source-safe"
    Confirm-Check (Test-Sha256Text $ExpectedSourceSha256) "$Id-source-sha-grammar"
    Confirm-Check (Test-SafeLeaf -Path $SidecarPath -AllowedRoot $AllowedRoot) "$Id-file-safe"
    $sidecar = Read-CanonicalLines -Path $SidecarPath -AllowedRoot $AllowedRoot -MaximumBytes 512
    Confirm-Check ($sidecar.Lines.Count -eq 1) "$Id-line-count"
    $expected = "$ExpectedSourceSha256  $([System.IO.Path]::GetFileName($SourcePath))"
    Confirm-Check ($sidecar.Lines[0] -ceq $expected) "$Id-value"
    return $sidecar
}

function Confirm-SourceManifest {
    param([Parameter(Mandatory)] [string]$Path)

    $manifest = Read-CanonicalLines -Path $Path -AllowedRoot $evidenceRoot -MaximumBytes 16777216
    Confirm-Check ($manifest.Lines.Count -ge 2) 'source-tsv-row-presence'
    Confirm-Check ($manifest.Lines[0] -ceq "path`tlength`tsha256") 'source-tsv-header'
    Confirm-Check ($manifest.Lines.Count -le 10001) 'source-tsv-row-bound'

    $sourceFiles = Get-SourceFileInventory
    $rowCount = $manifest.Lines.Count - 1
    Confirm-Check ($rowCount -eq $sourceFiles.Count) 'source-tsv-inventory-count'
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $previous = $null
    for ($index = 1; $index -lt $manifest.Lines.Count; $index++) {
        $fields = $manifest.Lines[$index].Split("`t", [System.StringSplitOptions]::None)
        Confirm-Check ($fields.Count -eq 3) 'source-tsv-field-count'
        $relative = $fields[0]
        Confirm-Check (Test-CanonicalRelativePath $relative) 'source-tsv-path-grammar'
        Confirm-Check ($seen.Add($relative)) 'source-tsv-path-unique'
        if ($null -ne $previous) {
            Confirm-Check ([System.StringComparer]::Ordinal.Compare($previous, $relative) -lt 0) 'source-tsv-path-order'
        }
        $previous = $relative
        $length = Convert-ToInt64 -Value $fields[1] -Id 'source-tsv-length'
        Confirm-Check (Test-Sha256Text $fields[2]) 'source-tsv-sha-grammar'
        Confirm-Check ($sourceFiles.ContainsKey($relative)) 'source-tsv-path-current'
        $file = $sourceFiles[$relative]
        Confirm-Check ($file.Length -eq $length) 'source-tsv-length-current'
        Confirm-Check (
            (Get-SafeSha256 -Path $file.FullName -AllowedRoot $crossPlatformRoot) -ceq $fields[2]) `
            'source-tsv-sha-current'
    }
    return $manifest
}

function Confirm-ArtifactManifest {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$PublishedRoot
    )

    $manifest = Read-CanonicalLines -Path $Path -AllowedRoot $evidenceRoot -MaximumBytes 10485760
    Confirm-Check ($manifest.Lines.Count -ge 4) 'artifact-tsv-row-presence'
    Confirm-Check ($manifest.Lines[0] -ceq '# staxrip-artifact-manifest-v1') 'artifact-tsv-schema'
    Confirm-Check ($manifest.Lines[1] -ceq '# mode-source=wsl:Ubuntu') 'artifact-tsv-mode-source'
    Confirm-Check ($manifest.Lines[2] -ceq "path`ttype`tlength`tsha256`tmode") 'artifact-tsv-header'
    Confirm-Check ($manifest.Lines.Count -le 50003) 'artifact-tsv-row-bound'

    $actual = Get-SafeTreeInventory -Root $PublishedRoot -AllowedRoot $publishRoot -MaximumEntries 50000
    $entries = [System.Collections.Generic.Dictionary[string,object]]::new(
        [System.StringComparer]::Ordinal)
    $previous = $null
    for ($index = 3; $index -lt $manifest.Lines.Count; $index++) {
        $fields = $manifest.Lines[$index].Split("`t", [System.StringSplitOptions]::None)
        Confirm-Check ($fields.Count -eq 5) 'artifact-tsv-field-count'
        $relative = $fields[0]
        $entryType = $fields[1]
        Confirm-Check (Test-CanonicalRelativePath $relative) 'artifact-tsv-path-grammar'
        Confirm-Check (-not $entries.ContainsKey($relative)) 'artifact-tsv-path-unique'
        if ($null -ne $previous) {
            Confirm-Check ([System.StringComparer]::Ordinal.Compare($previous, $relative) -lt 0) 'artifact-tsv-path-order'
        }
        $previous = $relative
        Confirm-Check (@('file', 'directory') -ccontains $entryType) 'artifact-tsv-type'
        $length = Convert-ToInt64 -Value $fields[2] -Id 'artifact-tsv-length'
        Confirm-Check (Test-Sha256Text $fields[3]) 'artifact-tsv-sha-grammar'
        Confirm-Check ($fields[4] -match '^[0-7]{4}$') 'artifact-tsv-mode-grammar'
        if ($entryType -ceq 'directory') {
            Confirm-Check ($length -eq 0 -and $fields[3] -ceq $emptySha256) 'artifact-tsv-directory-contract'
        }
        Confirm-Check ($actual.ContainsKey($relative)) 'artifact-tsv-path-current'
        $item = $actual[$relative]
        Confirm-Check (($entryType -ceq 'directory') -eq [bool]$item.PSIsContainer) 'artifact-tsv-type-current'
        if ($entryType -ceq 'file') {
            Confirm-Check ($item.Length -eq $length) 'artifact-tsv-length-current'
            Confirm-Check (
                (Get-SafeSha256 -Path $item.FullName -AllowedRoot $publishRoot) -ceq $fields[3]) `
                'artifact-tsv-sha-current'
        }
        $entries.Add($relative, [pscustomobject]@{
                Path = $relative
                Type = $entryType
                Length = $length
                Sha256 = $fields[3]
                Mode = $fields[4]
            })
    }
    Confirm-Check ($entries.Count -eq $actual.Count) 'artifact-tsv-inventory-count'
    Confirm-Check ($entries.ContainsKey('StaxRip.Server')) 'artifact-tsv-launcher-present'
    $launcher = $entries['StaxRip.Server']
    Confirm-Check ($launcher.Type -ceq 'file') 'artifact-tsv-launcher-type'
    Confirm-Check (([System.Convert]::ToInt32($launcher.Mode, 8) -band 73) -ne 0) 'artifact-tsv-launcher-executable'
    return [pscustomobject]@{
        Bytes = $manifest.Bytes
        Text = $manifest.Text
        Lines = $manifest.Lines
        Sha256 = $manifest.Sha256
        Entries = $entries
    }
}

function Assert-CloseoutCondition {
    param(
        [Parameter(Mandatory)] [bool]$Condition,
        [Parameter(Mandatory)] [string]$Id
    )

    $script:CloseoutChecks++
    if (-not $Condition) {
        throw [System.IO.InvalidDataException]::new("Closeout assertion failed: $Id")
    }
}

function Assert-DependencyClosureCurrent {
    param(
        [Parameter(Mandatory)]$Packages,
        [Parameter(Mandatory)] [string[]]$ExpectedLines
    )

    Assert-CloseoutCondition ($ExpectedLines.Count -ge 2) 'dependency-closure-lines'
    Assert-CloseoutCondition ($ExpectedLines[0] -ceq "package`tpath`tlength`tsha256") 'dependency-closure-header'
    $actualRows = [System.Collections.Generic.List[string]]::new()
    foreach ($packageEntry in $Packages.GetEnumerator()) {
        $packageKey = [string]$packageEntry.Key
        $package = $packageEntry.Value
        $tree = Get-SafeTreeInventory `
            -Root $package.Directory `
            -AllowedRoot $packagesRoot `
            -MaximumEntries 100000
        $files = @($tree.GetEnumerator() | Where-Object { -not $_.Value.PSIsContainer })
        Assert-CloseoutCondition ($files.Count -eq $package.FileCount) 'dependency-closure-package-count'
        foreach ($fileEntry in $files) {
            $relativePath = [string]$fileEntry.Key
            $file = $fileEntry.Value
            Assert-CloseoutCondition (Test-CanonicalRelativePath $relativePath) 'dependency-closure-path'
            Assert-CloseoutCondition (
                (Test-SafeLeaf -Path $file.FullName -AllowedRoot $packagesRoot)) `
                'dependency-closure-file-safe'
            $beforeLength = [long]$file.Length
            $sha256 = Get-SafeSha256 -Path $file.FullName -AllowedRoot $packagesRoot
            $after = Get-Item -LiteralPath $file.FullName -Force
            Assert-CloseoutCondition ($beforeLength -eq [long]$after.Length) 'dependency-closure-file-stable'
            $actualRows.Add("$packageKey`t$relativePath`t$($after.Length)`t$sha256")
        }
    }
    $sortedRows = [string[]]$actualRows.ToArray()
    [System.Array]::Sort($sortedRows, [System.StringComparer]::Ordinal)
    Assert-CloseoutCondition ($sortedRows.Count -eq ($ExpectedLines.Count - 1)) 'dependency-closure-total-count'
    for ($index = 0; $index -lt $sortedRows.Count; $index++) {
        Assert-CloseoutCondition ($sortedRows[$index] -ceq $ExpectedLines[$index + 1]) 'dependency-closure-row-current'
    }
}

function Assert-ArchiveBindingsCurrent {
    param([Parameter(Mandatory)]$Packages)

    $packageKeys = [string[]]@($Packages.Keys)
    [System.Array]::Sort($packageKeys, [System.StringComparer]::Ordinal)
    foreach ($packageKey in $packageKeys) {
        $package = $Packages[$packageKey]
        $binding = Get-ArchiveExtractionBinding `
            -PackageKey $packageKey `
            -PackageId $package.Id `
            -ArchivePath $package.ArchivePath `
            -ArchiveName $package.ArchiveName `
            -PackageDirectory $package.Directory `
            -AssertionMode Closeout
        Assert-CloseoutCondition (
            $binding.ArchiveLength -eq $package.ArchiveLength) 'archive-binding-length-current'
        Assert-CloseoutCondition (
            $binding.ArchiveSha256 -ceq $package.ArchiveSha256) 'archive-binding-sha256-current'
        Assert-CloseoutCondition (
            $binding.ArchiveSha512 -ceq $package.ArchiveSha512) 'archive-binding-sha512-current'
        Assert-CloseoutCondition (
            $binding.ArchiveFileEntryCount -eq $package.ArchiveFileEntryCount) `
            'archive-binding-entry-count-current'
        Assert-CloseoutCondition (
            $binding.ArchivePayloadFileCount -eq $package.ArchivePayloadFileCount) `
            'archive-binding-payload-count-current'
        Assert-CloseoutCondition (
            $binding.ArchiveOnlyMetadataCount -eq $package.ArchiveOnlyMetadataCount) `
            'archive-binding-metadata-count-current'
        Assert-CloseoutCondition (
            $binding.DiskFileCount -eq $package.FileCount) 'archive-binding-disk-count-current'
        Assert-CloseoutCondition (
            $binding.InventorySha256 -ceq $package.InventorySha256) `
            'archive-binding-inventory-sha256-current'
        Assert-CloseoutCondition (
            $binding.DiskTotalBytes -eq $package.InventoryTotalBytes) `
            'archive-binding-inventory-total-bytes-current'
        # Removed: this compared $package.ArchiveExtractionBinding, an in-memory string
        # already asserted against this same literal when the record was first parsed,
        # to that literal again. It re-read nothing, so it could not fail in either
        # closeout, and it inflated the closeout count by one per package. A closeout
        # exists to detect state that changed after the primary read; a check that
        # consults no state cannot do that. The bindings that DO re-read on-disk values
        # are immediately above and remain. Tracked as R-S2-028.
    }
}

function Get-WslArtifactModeMap {
    param([Parameter(Mandatory)] [string]$PublishedRoot)

    # An extension-suffixed lookup returns every PATH match, and a normal user PATH
    # carries wsl.exe twice, so binding .Source to a string parameter throws. Resolve to
    # the first match, which is the application a plain invocation would run. This code
    # path executes only when every prior assertion has passed, which is why no run had
    # ever reached the defect. Tracked as R-S2-047.
    $wsl = @(Get-Command wsl.exe -CommandType Application -ErrorAction SilentlyContinue) |
        Select-Object -First 1
    Assert-CloseoutCondition ($null -ne $wsl) 'artifact-mode-wsl-present'
    $pathResult = Invoke-BoundedProcess `
        -FileName $wsl.Source `
        -Arguments @('-d', 'Ubuntu', '--exec', '/usr/bin/wslpath', '-a', '-u', $PublishedRoot) `
        -WorkingDirectory $repositoryRoot `
        -TimeoutSeconds 30
    Assert-CloseoutCondition ($pathResult.ExitCode -eq 0) 'artifact-mode-wslpath-exit'
    $wslRoot = $pathResult.StdOut.TrimEnd([char[]]@("`r", "`n"))
    Assert-CloseoutCondition (
        $wslRoot.StartsWith('/', [System.StringComparison]::Ordinal) -and
        $wslRoot.Length -le 4096 -and
        $wslRoot -notmatch '[\x00-\x1f\x7f]') `
        'artifact-mode-wslpath-shape'

    $modeScript = @'
set -euo pipefail
root=$1
while IFS= read -r -d '' relative; do
    mode=$(/usr/bin/stat -c %a -- "$root/$relative")
    /usr/bin/printf '%s\t%04d\n' "$relative" "$mode"
done < <(/usr/bin/find "$root" -mindepth 1 -printf '%P\0' | /usr/bin/sort -z)
'@
    $modeResult = Invoke-BoundedProcess `
        -FileName $wsl.Source `
        -Arguments @(
            '-d', 'Ubuntu', '--exec', '/usr/bin/env', '-i',
            'PATH=/usr/bin:/bin', 'LANG=C.UTF-8', 'LC_ALL=C.UTF-8', 'TZ=UTC',
            '/usr/bin/bash', '--noprofile', '--norc', '-c', $modeScript, 'bash', $wslRoot) `
        -WorkingDirectory $repositoryRoot `
        -TimeoutSeconds 30
    Assert-CloseoutCondition ($modeResult.ExitCode -eq 0) 'artifact-mode-inventory-exit'
    Assert-CloseoutCondition ([string]::IsNullOrEmpty($modeResult.StdErr)) 'artifact-mode-inventory-stderr'
    $modeText = $modeResult.StdOut.Replace("`r`n", "`n")
    Assert-CloseoutCondition (-not $modeText.Contains("`r", [System.StringComparison]::Ordinal)) 'artifact-mode-inventory-lf'
    $modeLines = @($modeText.Split("`n", [System.StringSplitOptions]::RemoveEmptyEntries))
    $modes = [System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::Ordinal)
    foreach ($modeLine in $modeLines) {
        $fields = $modeLine.Split("`t", [System.StringSplitOptions]::None)
        Assert-CloseoutCondition ($fields.Count -eq 2) 'artifact-mode-field-count'
        Assert-CloseoutCondition (Test-CanonicalRelativePath $fields[0]) 'artifact-mode-path'
        Assert-CloseoutCondition ($fields[1] -match '^[0-7]{4}$') 'artifact-mode-value'
        Assert-CloseoutCondition (-not $modes.ContainsKey($fields[0])) 'artifact-mode-path-unique'
        $modes.Add($fields[0], $fields[1])
    }
    return ,$modes
}

function Assert-ArtifactTreeCurrent {
    param(
        [Parameter(Mandatory)] [string]$PublishedRoot,
        [Parameter(Mandatory)]$ExpectedEntries
    )

    $actual = Get-SafeTreeInventory `
        -Root $PublishedRoot `
        -AllowedRoot $publishRoot `
        -MaximumEntries 50000
    Assert-CloseoutCondition ($actual.Count -eq $ExpectedEntries.Count) 'artifact-tree-count'
    $currentModes = Get-WslArtifactModeMap -PublishedRoot $PublishedRoot
    Assert-CloseoutCondition ($currentModes.Count -eq $ExpectedEntries.Count) 'artifact-mode-count'
    foreach ($expectedEntry in $ExpectedEntries.GetEnumerator()) {
        $relativePath = [string]$expectedEntry.Key
        $expected = $expectedEntry.Value
        Assert-CloseoutCondition ($actual.ContainsKey($relativePath)) 'artifact-tree-path'
        $item = $actual[$relativePath]
        Assert-CloseoutCondition ($currentModes.ContainsKey($relativePath)) 'artifact-mode-current-path'
        Assert-CloseoutCondition (
            $currentModes[$relativePath] -ceq [string]$expected.Mode) `
            'artifact-mode-current-value'
        $isDirectory = [bool]$item.PSIsContainer
        Assert-CloseoutCondition (($expected.Type -ceq 'directory') -eq $isDirectory) 'artifact-tree-type'
        if (-not $isDirectory) {
            Assert-CloseoutCondition (
                (Test-SafeLeaf -Path $item.FullName -AllowedRoot $publishRoot)) `
                'artifact-tree-file-safe'
            $beforeLength = [long]$item.Length
            $sha256 = Get-SafeSha256 -Path $item.FullName -AllowedRoot $publishRoot
            $after = Get-Item -LiteralPath $item.FullName -Force
            Assert-CloseoutCondition ($beforeLength -eq [long]$after.Length) 'artifact-tree-file-stable'
            Assert-CloseoutCondition ([long]$after.Length -eq [long]$expected.Length) 'artifact-tree-length'
            Assert-CloseoutCondition ($sha256 -ceq [string]$expected.Sha256) 'artifact-tree-sha'
        }
    }
}

function Read-LinuxSnapshot {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [ValidateSet('application', 'runtime-state')] [string]$Policy,
        [Parameter(Mandatory)] [string]$Id
    )

    $snapshot = Read-CanonicalLines -Path $Path -AllowedRoot $evidenceRoot -MaximumBytes 10485760
    Confirm-Check ($snapshot.Lines.Count -ge 2) "$Id-row-presence"
    Confirm-Check (
        $snapshot.Lines[0] -ceq "path`ttype`tlength`tsha256`tmode`tmodified_ns") "$Id-header"
    Confirm-Check ($snapshot.Lines.Count -le 50001) "$Id-row-bound"
    $entries = [System.Collections.Generic.Dictionary[string,object]]::new(
        [System.StringComparer]::Ordinal)
    $allowedTypes = if ($Policy -eq 'application') {
        @('file', 'directory')
    }
    else {
        @('file', 'directory', 'symlink', 'socket', 'fifo', 'character', 'block', 'other')
    }
    $previous = $null
    for ($index = 1; $index -lt $snapshot.Lines.Count; $index++) {
        $fields = $snapshot.Lines[$index].Split("`t", [System.StringSplitOptions]::None)
        Confirm-Check ($fields.Count -eq 6) "$Id-field-count"
        $relative = $fields[0]
        $entryType = $fields[1]
        Confirm-Check (Test-CanonicalRelativePath -Value $relative -AllowDot) "$Id-path-grammar"
        Confirm-Check (-not $entries.ContainsKey($relative)) "$Id-path-unique"
        if ($null -ne $previous) {
            Confirm-Check ([System.StringComparer]::Ordinal.Compare($previous, $relative) -lt 0) "$Id-path-order"
        }
        $previous = $relative
        Confirm-Check ($allowedTypes -ccontains $entryType) "$Id-type"
        $length = Convert-ToInt64 -Value $fields[2] -Id "$Id-length"
        Confirm-Check ($fields[4] -match '^[0-7]{4}$') "$Id-mode"
        [void](Convert-ToInt64 -Value $fields[5] -Id "$Id-modified")
        if ($entryType -in @('file', 'directory')) {
            Confirm-Check (Test-Sha256Text $fields[3]) "$Id-sha"
            if ($entryType -ceq 'directory') {
                Confirm-Check ($length -eq 0 -and $fields[3] -ceq $emptySha256) "$Id-directory"
            }
        }
        else {
            Confirm-Check ($fields[3] -ceq '-') "$Id-special-sha"
            if ($entryType -in @('socket', 'fifo', 'character', 'block')) {
                Confirm-Check ($length -eq 0) "$Id-special-length"
            }
        }
        $entries.Add($relative, [pscustomobject]@{
                Path = $relative
                Type = $entryType
                Length = $length
                Sha256 = $fields[3]
                Mode = $fields[4]
                ModifiedNs = $fields[5]
            })
    }
    Confirm-Check ($entries.ContainsKey('.')) "$Id-root-present"
    $rootEntry = $entries['.']
    Confirm-Check (
        $rootEntry.Type -ceq 'directory' -and
        $rootEntry.Length -eq 0 -and
        $rootEntry.Sha256 -ceq $emptySha256) "$Id-root-contract"
    return [pscustomobject]@{
        Bytes = $snapshot.Bytes
        Text = $snapshot.Text
        Lines = $snapshot.Lines
        Sha256 = $snapshot.Sha256
        Entries = $entries
    }
}

function Confirm-ApplicationSnapshotMatchesManifest {
    param(
        [Parameter(Mandatory)]$SnapshotEntries,
        [Parameter(Mandatory)]$ManifestEntries
    )

    Confirm-Check ($SnapshotEntries.Count -eq ($ManifestEntries.Count + 1)) 'linux-app-manifest-count'
    foreach ($manifestEntry in $ManifestEntries.GetEnumerator()) {
        Confirm-Check ($SnapshotEntries.ContainsKey($manifestEntry.Key)) 'linux-app-manifest-path'
        $snapshot = $SnapshotEntries[$manifestEntry.Key]
        $manifest = $manifestEntry.Value
        Confirm-Check ($snapshot.Type -ceq $manifest.Type) 'linux-app-manifest-type'
        Confirm-Check ($snapshot.Length -eq $manifest.Length) 'linux-app-manifest-length'
        Confirm-Check ($snapshot.Sha256 -ceq $manifest.Sha256) 'linux-app-manifest-sha'
        Confirm-Check ($snapshot.Mode -ceq $manifest.Mode) 'linux-app-manifest-mode'
    }
}

function Test-NuGetContentHash {
    param([AllowEmptyString()] [string]$Value)

    if ($Value -notmatch '^[A-Za-z0-9+/]{86}==$') {
        return $false
    }
    try {
        $bytes = [System.Convert]::FromBase64String($Value)
        return $bytes.Length -eq 64 -and [System.Convert]::ToBase64String($bytes) -ceq $Value
    }
    catch {
        return $false
    }
}

function Confirm-NuGetMetadata {
    param(
        [Parameter(Mandatory)] [string]$PackageDirectory,
        [Parameter(Mandatory)] [string]$ExpectedSource,
        [Parameter(Mandatory)] [string]$ExpectedContentHash
    )

    $metadataPath = [System.IO.Path]::GetFullPath((Join-Path $PackageDirectory '.nupkg.metadata'))
    Confirm-Check (Test-SafeLeaf -Path $metadataPath -AllowedRoot $packagesRoot) 'package-metadata-safe'
    $text = Read-SafeText -Path $metadataPath -AllowedRoot $packagesRoot -MaximumBytes 16384
    $options = [System.Text.Json.JsonDocumentOptions]::new()
    $options.AllowTrailingCommas = $false
    $options.CommentHandling = [System.Text.Json.JsonCommentHandling]::Disallow
    $options.MaxDepth = 8
    $document = $null
    try {
        $document = [System.Text.Json.JsonDocument]::Parse($text, $options)
        $fields = Assert-JsonObjectShape -Element $document.RootElement -ExpectedNames @(
            'version', 'contentHash', 'source') -Id 'package-metadata-shape'
        $version = Get-JsonIntegerField -Fields $fields -Name 'version' -Id 'package-metadata-version'
        Confirm-Check ($version -eq 2) 'package-metadata-version-value'
        Confirm-Check (
            (Get-JsonStringField -Fields $fields -Name 'contentHash' -Id 'package-metadata-hash') -ceq $ExpectedContentHash) `
            'package-metadata-hash-value'
        Confirm-Check (
            (Get-JsonStringField -Fields $fields -Name 'source' -Id 'package-metadata-source') -ceq $ExpectedSource) `
            'package-metadata-source-value'
    }
    finally {
        if ($null -ne $document) {
            $document.Dispose()
        }
    }
}

function Get-EvaluatedAssetMap {
    param(
        [Parameter(Mandatory)] [string[]]$ExpectedProjects,
        [Parameter(Mandatory)]$ExpectedGraph,
        [Parameter(Mandatory)] [string[]]$RequiredPackageIds,
        [Parameter(Mandatory)] [string]$RequiredPackageVersion
    )

    $objectRoot = [System.IO.Path]::GetFullPath((Join-Path $artifactsRoot 'obj'))
    Confirm-Check (Test-SafeDirectory -Path $objectRoot -AllowedRoot $artifactsRoot) 'assets-root-safe'
    $objectInventory = Get-SafeTreeInventory -Root $objectRoot -AllowedRoot $artifactsRoot -MaximumEntries 50000
    $candidates = @($objectInventory.GetEnumerator() |
        Where-Object {
            -not $_.Value.PSIsContainer -and
            [System.IO.Path]::GetFileName($_.Value.FullName) -ceq 'project.assets.json'
        } |
        ForEach-Object { $_.Value })
    Confirm-Check ($candidates.Count -le 20) 'assets-candidate-bound'
    $map = [System.Collections.Generic.Dictionary[string,object]]::new([System.StringComparer]::Ordinal)
    $derivedPackages = [System.Collections.Generic.Dictionary[string,object]]::new(
        [System.StringComparer]::Ordinal)
    $projectPathByLibraryKey = [System.Collections.Generic.Dictionary[string,string]]::new(
        [System.StringComparer]::Ordinal)
    $projectPathByLockLibraryName = [System.Collections.Generic.Dictionary[string,string]]::new(
        [System.StringComparer]::Ordinal)
    foreach ($expectedProject in $ExpectedProjects) {
        $projectName = [System.IO.Path]::GetFileNameWithoutExtension($expectedProject)
        $projectPathByLibraryKey.Add("$projectName/1.0.0", $expectedProject)
        $projectPathByLockLibraryName.Add($projectName.ToLowerInvariant(), $expectedProject)
    }
    $comparison = [System.StringComparison]::Ordinal
    foreach ($candidate in $candidates) {
        Confirm-Check (Test-SafeLeaf -Path $candidate.FullName -AllowedRoot $objectRoot) 'assets-candidate-safe'
        $textRecord = Read-SafeTextRecord `
            -Path $candidate.FullName `
            -AllowedRoot $objectRoot `
            -MaximumBytes 134217728
        $options = [System.Text.Json.JsonDocumentOptions]::new()
        $options.AllowTrailingCommas = $false
        $options.CommentHandling = [System.Text.Json.JsonCommentHandling]::Disallow
        $options.MaxDepth = 128
        $document = $null
        try {
            $document = [System.Text.Json.JsonDocument]::Parse($textRecord.Text, $options)
            $project = Get-UniqueJsonProperty `
                -Element $document.RootElement `
                -Name 'project' `
                -ExpectedKind Object `
                -Id 'assets-project-property'
            $restore = Get-UniqueJsonProperty `
                -Element $project `
                -Name 'restore' `
                -ExpectedKind Object `
                -Id 'assets-restore-property'
            $uniqueName = Get-UniqueJsonProperty `
                -Element $restore `
                -Name 'projectUniqueName' `
                -ExpectedKind String `
                -Id 'assets-unique-name-property'
            $uniquePath = [System.IO.Path]::GetFullPath([string]$uniqueName.GetString())
            foreach ($expectedProject in $ExpectedProjects) {
                $expectedPath = [System.IO.Path]::GetFullPath((Join-Path $crossPlatformRoot $expectedProject.Replace('/', [System.IO.Path]::DirectorySeparatorChar)))
                if ($uniquePath.Equals($expectedPath, $comparison)) {
                    Confirm-Check (-not $map.ContainsKey($expectedProject)) 'assets-project-unique'
                    Confirm-Check (Test-SafeLeaf -Path $expectedPath -AllowedRoot $crossPlatformRoot) 'assets-project-current-safe'

                    $rootFields = Assert-JsonObjectShape `
                        -Element $document.RootElement `
                        -ExpectedNames @(
                            'version', 'targets', 'libraries', 'projectFileDependencyGroups',
                            'packageFolders', 'project') `
                        -Id 'assets-root-shape'
                    $assetsVersion = 0
                    Confirm-Check (
                        $rootFields['version'].ValueKind -eq [System.Text.Json.JsonValueKind]::Number -and
                        $rootFields['version'].TryGetInt32([ref]$assetsVersion) -and
                        $assetsVersion -eq 4 -and
                        $rootFields['version'].GetRawText() -ceq '4') `
                        'assets-version-current'

                    $projectFields = Assert-JsonObjectShape `
                        -Element $rootFields['project'] `
                        -ExpectedNames @('version', 'restore', 'frameworks', 'runtimes') `
                        -Id 'assets-project-shape'
                    Confirm-Check (
                        $projectFields['version'].ValueKind -eq [System.Text.Json.JsonValueKind]::String -and
                        $projectFields['version'].GetString() -ceq '1.0.0') `
                        'assets-project-version'

                    $restoreElement = $projectFields['restore']
                    $projectPathElement = Get-UniqueJsonProperty `
                        -Element $restoreElement `
                        -Name 'projectPath' `
                        -ExpectedKind String `
                        -Id 'assets-project-path-property'
                    Confirm-Check (
                        [System.IO.Path]::GetFullPath([string]$projectPathElement.GetString()).Equals(
                            $expectedPath,
                            $comparison)) `
                        'assets-project-path-current'
                    $packagesPathElement = Get-UniqueJsonProperty `
                        -Element $restoreElement `
                        -Name 'packagesPath' `
                        -ExpectedKind String `
                        -Id 'assets-packages-path-property'
                    Confirm-Check (
                        [System.IO.Path]::GetFullPath([string]$packagesPathElement.GetString()).Equals(
                            $packagesRoot,
                            $comparison)) `
                        'assets-packages-path-current'
                    $originalFrameworksElement = Get-UniqueJsonProperty `
                        -Element $restoreElement `
                        -Name 'originalTargetFrameworks' `
                        -ExpectedKind Array `
                        -Id 'assets-original-frameworks-property'
                    Assert-ExactStringArray `
                        -Element $originalFrameworksElement `
                        -Expected @('net10.0') `
                        -Id 'assets-original-frameworks'
                    $restoreFrameworksElement = Get-UniqueJsonProperty `
                        -Element $restoreElement `
                        -Name 'frameworks' `
                        -ExpectedKind Object `
                        -Id 'assets-restore-frameworks-property'
                    [void](Assert-JsonObjectShape `
                            -Element $restoreFrameworksElement `
                            -ExpectedNames @('net10.0') `
                            -Id 'assets-restore-frameworks-shape')
                    $restoreLockElement = Get-UniqueJsonProperty `
                        -Element $restoreElement `
                        -Name 'restoreLockProperties' `
                        -ExpectedKind Object `
                        -Id 'assets-restore-lock-property'
                    $lockFields = Assert-JsonObjectShape `
                        -Element $restoreLockElement `
                        -ExpectedNames @('restorePackagesWithLockFile', 'restoreLockedMode') `
                        -Id 'assets-restore-lock-shape'
                    Confirm-Check (
                        $lockFields['restorePackagesWithLockFile'].ValueKind -eq [System.Text.Json.JsonValueKind]::String -and
                        $lockFields['restorePackagesWithLockFile'].GetString() -ceq 'true' -and
                        $lockFields['restoreLockedMode'].ValueKind -eq [System.Text.Json.JsonValueKind]::True) `
                        'assets-restore-lock-current'

                    $expectedLibrarySet = [System.Collections.Generic.HashSet[string]]::new(
                        [System.StringComparer]::Ordinal)
                    $pendingProjects = [System.Collections.Generic.Queue[string]]::new()
                    foreach ($referencedProject in @($ExpectedGraph[$expectedProject])) {
                        $pendingProjects.Enqueue([string]$referencedProject)
                    }
                    while ($pendingProjects.Count -gt 0) {
                        $referencedProject = $pendingProjects.Dequeue()
                        $libraryKey = "$([System.IO.Path]::GetFileNameWithoutExtension($referencedProject))/1.0.0"
                        if ($expectedLibrarySet.Add($libraryKey)) {
                            foreach ($transitiveProject in @($ExpectedGraph[$referencedProject])) {
                                $pendingProjects.Enqueue([string]$transitiveProject)
                            }
                        }
                    }
                    $expectedLibraryKeys = [string[]]@($expectedLibrarySet)
                    [System.Array]::Sort($expectedLibraryKeys, [System.StringComparer]::Ordinal)

                    $targetFields = Assert-JsonObjectShape `
                        -Element $rootFields['targets'] `
                        -ExpectedNames @('net10.0', 'net10.0/linux-x64') `
                        -Id 'assets-targets-shape'
                    foreach ($targetName in @('net10.0', 'net10.0/linux-x64')) {
                        $targetLibraries = Assert-JsonObjectShape `
                            -Element $targetFields[$targetName] `
                            -ExpectedNames $expectedLibraryKeys `
                            -Id 'assets-target-library-shape'
                        foreach ($libraryKey in $expectedLibraryKeys) {
                            $targetType = Get-UniqueJsonProperty `
                                -Element $targetLibraries[$libraryKey] `
                                -Name 'type' `
                                -ExpectedKind String `
                                -Id 'assets-target-library-type'
                            Confirm-Check ($targetType.GetString() -ceq 'project') 'assets-target-library-project-only'
                            $targetFramework = Get-UniqueJsonProperty `
                                -Element $targetLibraries[$libraryKey] `
                                -Name 'framework' `
                                -ExpectedKind String `
                                -Id 'assets-target-library-framework'
                            Confirm-Check (
                                $targetFramework.GetString() -ceq '.NETCoreApp,Version=v10.0') `
                                'assets-target-library-framework-current'
                        }
                    }

                    $libraryFields = Assert-JsonObjectShape `
                        -Element $rootFields['libraries'] `
                        -ExpectedNames $expectedLibraryKeys `
                        -Id 'assets-libraries-shape'
                    foreach ($libraryKey in $expectedLibraryKeys) {
                        $libraryValueFields = Assert-JsonObjectShape `
                            -Element $libraryFields[$libraryKey] `
                            -ExpectedNames @('type', 'path', 'msbuildProject') `
                            -Id 'assets-library-shape'
                        Confirm-Check (
                            $libraryValueFields['type'].ValueKind -eq [System.Text.Json.JsonValueKind]::String -and
                            $libraryValueFields['type'].GetString() -ceq 'project') `
                            'assets-library-project-only'
                        $libraryPath = [string]$libraryValueFields['path'].GetString()
                        $msbuildProject = [string]$libraryValueFields['msbuildProject'].GetString()
                        Confirm-Check (
                            $libraryValueFields['path'].ValueKind -eq [System.Text.Json.JsonValueKind]::String -and
                            $libraryValueFields['msbuildProject'].ValueKind -eq [System.Text.Json.JsonValueKind]::String -and
                            $libraryPath -ceq $msbuildProject) `
                            'assets-library-path-fields'
                        $resolvedLibraryPath = [System.IO.Path]::GetFullPath(
                            (Join-Path ([System.IO.Path]::GetDirectoryName($expectedPath)) $libraryPath))
                        $expectedLibraryPath = [System.IO.Path]::GetFullPath(
                            (Join-Path $crossPlatformRoot $projectPathByLibraryKey[$libraryKey]))
                        Confirm-Check (
                            $resolvedLibraryPath.Equals($expectedLibraryPath, $comparison) -and
                            (Test-SafeLeaf -Path $expectedLibraryPath -AllowedRoot $crossPlatformRoot)) `
                            'assets-library-path-current'
                    }

                    $packageFolderFields = Assert-JsonObjectShape `
                        -Element $rootFields['packageFolders'] `
                        -ExpectedNames @($packagesRoot) `
                        -Id 'assets-package-folders-shape'
                    [void](Assert-JsonObjectShape `
                            -Element $packageFolderFields[$packagesRoot] `
                            -ExpectedNames @() `
                            -Id 'assets-package-folder-value')

                    $frameworkFields = Assert-JsonObjectShape `
                        -Element $projectFields['frameworks'] `
                        -ExpectedNames @('net10.0') `
                        -Id 'assets-frameworks-shape'
                    $downloadDependencies = Get-UniqueJsonProperty `
                        -Element $frameworkFields['net10.0'] `
                        -Name 'downloadDependencies' `
                        -ExpectedKind Array `
                        -Id 'assets-download-dependencies-property'
                    $downloadItems = @($downloadDependencies.EnumerateArray())
                    Confirm-Check (
                        $downloadItems.Count -eq $RequiredPackageIds.Count) `
                        'assets-download-dependencies-count'
                    for ($downloadIndex = 0; $downloadIndex -lt $downloadItems.Count; $downloadIndex++) {
                        $downloadFields = Assert-JsonObjectShape `
                            -Element $downloadItems[$downloadIndex] `
                            -ExpectedNames @('name', 'version') `
                            -Id 'assets-download-dependency-shape'
                        Confirm-Check (
                            $downloadFields['name'].ValueKind -eq [System.Text.Json.JsonValueKind]::String -and
                            $downloadFields['name'].GetString() -ceq $RequiredPackageIds[$downloadIndex]) `
                            'assets-download-dependency-id'
                        $requiredRange = "[$RequiredPackageVersion, $RequiredPackageVersion]"
                        Confirm-Check (
                            $downloadFields['version'].ValueKind -eq [System.Text.Json.JsonValueKind]::String -and
                            $downloadFields['version'].GetString() -ceq $requiredRange) `
                            'assets-download-dependency-version'
                        $packageId = [string]$downloadFields['name'].GetString()
                        $packageKey = "$packageId/$RequiredPackageVersion"
                        if (-not $derivedPackages.ContainsKey($packageKey)) {
                            $derivedPackages.Add($packageKey, [pscustomobject]@{
                                    Id = $packageId
                                    Version = $RequiredPackageVersion
                                    Projects = [System.Collections.Generic.HashSet[string]]::new(
                                        [System.StringComparer]::Ordinal)
                                })
                        }
                        Confirm-Check (
                            $derivedPackages[$packageKey].Projects.Add($expectedProject)) `
                            'assets-download-project-membership-unique'
                    }

                    $runtimeFields = Assert-JsonObjectShape `
                        -Element $projectFields['runtimes'] `
                        -ExpectedNames @('linux-x64') `
                        -Id 'assets-runtimes-shape'
                    $linuxRuntimeFields = Assert-JsonObjectShape `
                        -Element $runtimeFields['linux-x64'] `
                        -ExpectedNames @('#import') `
                        -Id 'assets-linux-runtime-shape'
                    Confirm-Check (
                        $linuxRuntimeFields['#import'].ValueKind -eq [System.Text.Json.JsonValueKind]::Array -and
                        @($linuxRuntimeFields['#import'].EnumerateArray()).Count -eq 0) `
                        'assets-linux-runtime-imports-empty'

                    $lockPath = [System.IO.Path]::GetFullPath((Join-Path (
                                [System.IO.Path]::GetDirectoryName($expectedPath)) 'packages.lock.json'))
                    Confirm-Check (Test-SafeLeaf -Path $lockPath -AllowedRoot $crossPlatformRoot) 'assets-lock-safe'
                    $lockRecord = Read-SafeTextRecord `
                        -Path $lockPath `
                        -AllowedRoot $crossPlatformRoot `
                        -MaximumBytes 1048576 `
                        -CanonicalLines
                    $lockDocument = $null
                    try {
                        $lockDocument = [System.Text.Json.JsonDocument]::Parse(
                            $lockRecord.Text,
                            $options)
                        $lockRootFields = Assert-JsonObjectShape `
                            -Element $lockDocument.RootElement `
                            -ExpectedNames @('version', 'dependencies') `
                            -Id 'assets-lock-root-shape'
                        $lockVersion = 0
                        Confirm-Check (
                            $lockRootFields['version'].ValueKind -eq [System.Text.Json.JsonValueKind]::Number -and
                            $lockRootFields['version'].TryGetInt32([ref]$lockVersion) -and
                            $lockVersion -eq 1 -and
                            $lockRootFields['version'].GetRawText() -ceq '1') `
                            'assets-lock-version'
                        $lockTargets = Assert-JsonObjectShape `
                            -Element $lockRootFields['dependencies'] `
                            -ExpectedNames @('net10.0', 'net10.0/linux-x64') `
                            -Id 'assets-lock-targets-shape'
                        [void](Assert-JsonObjectShape `
                                -Element $lockTargets['net10.0/linux-x64'] `
                                -ExpectedNames @() `
                                -Id 'assets-lock-runtime-target-empty')
                        $expectedLockLibraries = [string[]]@($expectedLibraryKeys | ForEach-Object {
                                $_.Substring(0, $_.IndexOf('/')).ToLowerInvariant()
                            })
                        [System.Array]::Sort($expectedLockLibraries, [System.StringComparer]::Ordinal)
                        $lockLibraries = Assert-JsonObjectShape `
                            -Element $lockTargets['net10.0'] `
                            -ExpectedNames $expectedLockLibraries `
                            -Id 'assets-lock-libraries-shape'
                        foreach ($lockLibraryName in $expectedLockLibraries) {
                            Confirm-Check (
                                $projectPathByLockLibraryName.ContainsKey($lockLibraryName)) `
                                'assets-lock-library-derived'
                            $lockedProjectPath = $projectPathByLockLibraryName[$lockLibraryName]
                            $expectedLockedDependencies = [string[]]@($ExpectedGraph[$lockedProjectPath] |
                                ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension([string]$_) })
                            [System.Array]::Sort(
                                $expectedLockedDependencies,
                                [System.StringComparer]::Ordinal)
                            $expectedLockLibraryProperties = if ($expectedLockedDependencies.Count -eq 0) {
                                @('type')
                            }
                            else {
                                @('type', 'dependencies')
                            }
                            $lockLibraryFields = Assert-JsonObjectShape `
                                -Element $lockLibraries[$lockLibraryName] `
                                -ExpectedNames $expectedLockLibraryProperties `
                                -Id 'assets-lock-library-shape'
                            Confirm-Check (
                                $lockLibraryFields['type'].ValueKind -eq [System.Text.Json.JsonValueKind]::String -and
                                $lockLibraryFields['type'].GetString() -ceq 'Project') `
                                'assets-lock-project-only'
                            if ($expectedLockedDependencies.Count -gt 0) {
                                $lockedDependencyFields = Assert-JsonObjectShape `
                                    -Element $lockLibraryFields['dependencies'] `
                                    -ExpectedNames $expectedLockedDependencies `
                                    -Id 'assets-lock-project-dependencies-shape'
                                foreach ($expectedLockedDependency in $expectedLockedDependencies) {
                                    Confirm-Check (
                                        $lockedDependencyFields[$expectedLockedDependency].ValueKind -eq
                                            [System.Text.Json.JsonValueKind]::String -and
                                        $lockedDependencyFields[$expectedLockedDependency].GetString() -ceq
                                            '[1.0.0, )') `
                                        'assets-lock-project-dependency-current'
                                }
                            }
                        }
                    }
                    finally {
                        if ($null -ne $lockDocument) {
                            $lockDocument.Dispose()
                        }
                    }

                    $map.Add($expectedProject, [pscustomobject]@{
                            Path = $candidate.FullName
                            Sha256 = $textRecord.Sha256
                        })
                    break
                }
            }
        }
        finally {
            if ($null -ne $document) {
                $document.Dispose()
            }
        }
    }
    Confirm-Check ($map.Count -eq $ExpectedProjects.Count) 'assets-project-count'
    Confirm-Check ($derivedPackages.Count -eq $RequiredPackageIds.Count) 'assets-derived-package-count'
    foreach ($requiredPackageId in $RequiredPackageIds) {
        $requiredKey = "$requiredPackageId/$RequiredPackageVersion"
        Confirm-Check ($derivedPackages.ContainsKey($requiredKey)) 'assets-derived-package-present'
        Confirm-Check (
            $derivedPackages[$requiredKey].Projects.Count -eq $ExpectedProjects.Count) `
            'assets-derived-package-project-count'
        foreach ($expectedProject in $ExpectedProjects) {
            Confirm-Check (
                $derivedPackages[$requiredKey].Projects.Contains($expectedProject)) `
                'assets-derived-package-project-member'
        }
    }
    return [pscustomobject]@{
        Assets = $map
        Packages = $derivedPackages
    }
}

function Confirm-NoPrivateEvidenceText {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [Parameter(Mandatory)] [string]$Id
    )

    $privateValues = @(
        $repositoryRoot,
        $repositoryRoot.Replace('\', '/'),
        [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
    foreach ($privateValue in $privateValues) {
        Confirm-Check (
            -not $Text.Contains($privateValue, [System.StringComparison]::OrdinalIgnoreCase)) "$Id-private-path"
    }
    Confirm-Check (
        $Text -notmatch '(?i)(?:[A-Z]:[\\/](?:Users|Documents and Settings)[\\/]|/(?:home|Users)/[^/\s]+/)' -and
        $Text -notmatch '(?i)staxrip_session_[0-9a-f]{24}=[0-9a-f]{64}') "$Id-private-shape"
}

function Add-AuditHash {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$AllowedRoot,
        [Parameter(Mandatory)] [string]$ExpectedSha256
    )

    Confirm-Check (Test-SafeLeaf -Path $Path -AllowedRoot $AllowedRoot) 'audit-hash-input-safe'
    Confirm-Check (Test-Sha256Text $ExpectedSha256) 'audit-hash-expected-grammar'
    $currentSha256 = Get-SafeSha256 -Path $Path -AllowedRoot $AllowedRoot
    Confirm-Check ($currentSha256 -ceq $ExpectedSha256) 'audit-hash-validated-bytes-current'
    $relative = Get-RepositoryRelativePath $Path
    Confirm-Check ($script:AuditHashPaths.Add($relative)) 'audit-hash-path-unique'
    $script:AuditHashes.Add([ordered]@{
            path = $relative
            sha256 = $currentSha256
        })
}

function Assert-AuditInputsCurrent {
    param([Parameter(Mandatory)]$AuditInputs)

    foreach ($auditInput in $AuditInputs) {
        Assert-CloseoutCondition (Test-Sha256Text $auditInput.Sha256) 'audit-input-sha-grammar'
        Assert-CloseoutCondition (
            (Test-SafeLeaf -Path $auditInput.Path -AllowedRoot $auditInput.Root)) `
            'audit-input-safe'
        Assert-CloseoutCondition (
            (Get-SafeSha256 -Path $auditInput.Path -AllowedRoot $auditInput.Root) -ceq $auditInput.Sha256) `
            'audit-input-current'
    }
}

function Assert-HeadScopeFailureCurrent {
    param(
        [Parameter(Mandatory)] [string]$ExpectedHead,
        [Parameter(Mandatory)]$ExpectedScope,
        [Parameter(Mandatory)]$RecordedScope
    )

    $observedHead = (Invoke-Git @('rev-parse', '--verify', 'HEAD')).Trim()
    Assert-CloseoutCondition ($observedHead -cmatch '^[0-9a-f]{40}$') 'head-grammar'
    Assert-CloseoutCondition ($observedHead -ceq $ExpectedHead) 'head-current'
    $observedScope = Get-GitScopeSnapshot -Uncounted
    Assert-CloseoutCondition (
        (Test-GitScopeSnapshotsEqual -Left $observedScope -Right $ExpectedScope)) `
        'scope-current'
    Assert-CloseoutCondition (
        (Test-GitScopeSnapshotsEqual -Left $observedScope -Right $RecordedScope)) `
        'scope-record-current'
    Assert-CloseoutCondition (Test-FailureDirectoryEmpty) 'failure-directory-empty'
    Assert-CloseoutCondition (Test-TaskRootEmpty $browserTaskRoot) 'browser-task-root-empty'
    Assert-CloseoutCondition (Test-TaskRootEmpty $httpTaskRoot) 'http-task-root-empty'
    Assert-CloseoutCondition (
        (Test-TaskMarkerAbsent $verifyWorkflowMarkerPath)) 'verify-workflow-marker-absent'
}

try {
    Confirm-RedactionContract
    if (-not (Enter-EvidenceLease)) {
        [Console]::Error.WriteLine('FAIL port-evidence exit=1 evidence=none lease=unavailable')
        exit 1
    }
    Confirm-Check (Test-EvidencePublicationAuthority) 'evidence-publication-authority'
    Confirm-Check (Test-SafeDirectory -Path $repositoryRoot -AllowedRoot $repositoryRoot) 'repository-root-safe'
    Confirm-Check (Test-SafeDirectory -Path $crossPlatformRoot -AllowedRoot $repositoryRoot) 'cross-platform-root-safe'
    Confirm-Check (Test-SafeDirectory -Path $artifactsRoot -AllowedRoot $crossPlatformRoot) 'artifacts-root-safe'
    Confirm-Check (Test-TaskRootEmpty $browserTaskRoot) 'browser-task-root-empty'
    Confirm-Check (Test-TaskRootEmpty $httpTaskRoot) 'http-task-root-empty'
    Confirm-Check (Test-TaskMarkerAbsent $verifyWorkflowMarkerPath) 'verify-workflow-marker-absent'
    Confirm-Check (Ensure-SafeDirectory -Path $evidenceRoot -AllowedRoot $artifactsRoot) 'evidence-root-safe'
    Confirm-Check (Test-EvidencePublicationAuthority) 'failure-root-publication-authority'
    Confirm-Check (Ensure-SafeDirectory -Path $failureRoot -AllowedRoot $artifactsRoot) 'failure-root-safe'
    Confirm-Check (Test-EvidencePublicationAuthority) 'failure-root-publication-authority-current'
    Confirm-Check (
        -not [System.IO.File]::Exists($auditSidecarPath) -and
        -not [System.IO.Directory]::Exists($auditSidecarPath) -and
        -not [System.IO.File]::Exists($auditPath) -and
        -not [System.IO.Directory]::Exists($auditPath)) 'prior-pass-pair-invalidated'
    Confirm-Check ($BaseCommit -cmatch '^[0-9a-f]{40}$') 'base-commit-grammar'

    $currentHead = (Invoke-Git @('rev-parse', '--verify', 'HEAD')).Trim()
    Confirm-Check ($currentHead -cmatch '^[0-9a-f]{40}$') 'current-head-grammar'
    $baseType = (Invoke-Git @('cat-file', '-t', $BaseCommit)).Trim()
    Confirm-Check ($baseType -ceq 'commit') 'base-commit-present'
    [void](Invoke-Git @('merge-base', '--is-ancestor', $BaseCommit, 'HEAD'))
    $scopeSnapshot = Get-GitScopeSnapshot

    $expectedProjects = @(
        'src/StaxRip.Contracts/StaxRip.Contracts.csproj',
        'src/StaxRip.Core/StaxRip.Core.csproj',
        'src/StaxRip.Platform/StaxRip.Platform.csproj',
        'src/StaxRip.Server/StaxRip.Server.csproj',
        'tests/StaxRip.ContractTests/StaxRip.ContractTests.csproj'
    )
    $expectedGraph = [ordered]@{
        'src/StaxRip.Contracts/StaxRip.Contracts.csproj' = @()
        'src/StaxRip.Core/StaxRip.Core.csproj' = @('src/StaxRip.Contracts/StaxRip.Contracts.csproj')
        'src/StaxRip.Platform/StaxRip.Platform.csproj' = @('src/StaxRip.Core/StaxRip.Core.csproj')
        'src/StaxRip.Server/StaxRip.Server.csproj' = @('src/StaxRip.Platform/StaxRip.Platform.csproj')
        'tests/StaxRip.ContractTests/StaxRip.ContractTests.csproj' = @(
            'src/StaxRip.Contracts/StaxRip.Contracts.csproj',
            'src/StaxRip.Core/StaxRip.Core.csproj',
            'src/StaxRip.Platform/StaxRip.Platform.csproj',
            'src/StaxRip.Server/StaxRip.Server.csproj'
        )
    }
    $expectedPackageIds = @(
        'Microsoft.AspNetCore.App.Runtime.linux-x64',
        'Microsoft.NETCore.App.Host.linux-x64',
        'Microsoft.NETCore.App.Runtime.linux-x64'
    )
    $expectedPackageVersion = '10.0.11'
    $expectedRoutes = @('/', '/api/v1/capabilities', '/app.css', '/app.js', '/healthz')
    $expectedAssets = @(
        'Web/app.css|StaxRip.Server.Web.app.css',
        'Web/app.js|StaxRip.Server.Web.app.js',
        'Web/index.html|StaxRip.Server.Web.index.html'
    )
    $expectedCases = @(
        'CT-001', 'CT-002', 'CT-003', 'CT-004', 'CT-005', 'CT-006', 'CT-007',
        'CT-008', 'CT-009', 'CT-010', 'CT-011', 'CT-012', 'CT-013', 'CT-014',
        'CT-015', 'CT-016', 'CT-017', 'CT-018', 'CT-019', 'CT-020', 'CT-021',
        'CT-022',
        'ST-001', 'ST-002', 'ST-003', 'ST-004', 'ST-005', 'ST-006', 'ST-007',
        'ST-008', 'ST-009'
    )

    $static = Read-JsonRecord -Name 'static-gate.json' -ExpectedSchema 'staxrip-static-gate-v1'
    $sourceRecordHash = $static.Sha256
    $staticFields = Assert-JsonObjectShape -Element $static.Root -ExpectedNames @(
        'schema', 'base', 'head', 'scope', 'project_graph', 'routes',
        'embedded_assets', 'test_cases', 'source_manifest') -Id 'static-shape'
    Confirm-Check (
        (Get-JsonStringField -Fields $staticFields -Name 'base' -Id 'static-base') -ceq $BaseCommit) `
        'static-base-value'
    Confirm-Check (
        (Get-JsonStringField -Fields $staticFields -Name 'head' -Id 'static-head') -ceq $currentHead) `
        'static-head-current'

    $scopeFields = Assert-JsonObjectShape -Element $staticFields['scope'] -ExpectedNames @(
        'schema', 'sha256', 'index', 'status', 'counts', 'entries') -Id 'static-scope-shape'
    $recordedScopeSchema = Get-JsonStringField -Fields $scopeFields -Name 'schema' -Id 'static-scope-schema'
    Confirm-Check ($recordedScopeSchema -ceq 'staxrip-current-scope-v2') 'static-scope-schema-value'
    $recordedScopeDigest = Get-JsonStringField -Fields $scopeFields -Name 'sha256' -Id 'static-scope-digest'
    Confirm-Check (Test-Sha256Text $recordedScopeDigest) 'static-scope-digest-grammar'

    $recordedIndexFields = Assert-JsonObjectShape -Element $scopeFields['index'] -ExpectedNames @(
        'sha256', 'count', 'entries') -Id 'static-scope-index-shape'
    $recordedIndexDigest = Get-JsonStringField -Fields $recordedIndexFields -Name 'sha256' -Id 'static-scope-index-digest'
    Confirm-Check (Test-Sha256Text $recordedIndexDigest) 'static-scope-index-digest-grammar'
    $recordedIndexCount = Get-JsonIntegerField -Fields $recordedIndexFields -Name 'count' -Id 'static-scope-index-count'
    $recordedIndexItems = @(Get-JsonArrayItems -Element $recordedIndexFields['entries'] -Id 'static-scope-index-entries')
    Confirm-Check ($recordedIndexItems.Count -eq $recordedIndexCount) 'static-scope-index-entry-count'
    $recordedIndexEntries = [System.Collections.Generic.List[string]]::new()
    foreach ($recordedIndexItem in $recordedIndexItems) {
        Confirm-Check ($recordedIndexItem.ValueKind -eq [System.Text.Json.JsonValueKind]::String) 'static-scope-index-entry-type'
        $recordedIndexEntries.Add([string]$recordedIndexItem.GetString())
    }

    $recordedStatusFields = Assert-JsonObjectShape -Element $scopeFields['status'] -ExpectedNames @(
        'sha256', 'count', 'entries') -Id 'static-scope-status-shape'
    $recordedStatusDigest = Get-JsonStringField -Fields $recordedStatusFields -Name 'sha256' -Id 'static-scope-status-digest'
    Confirm-Check (Test-Sha256Text $recordedStatusDigest) 'static-scope-status-digest-grammar'
    $recordedStatusCount = Get-JsonIntegerField -Fields $recordedStatusFields -Name 'count' -Id 'static-scope-status-count'
    $recordedStatusItems = @(Get-JsonArrayItems -Element $recordedStatusFields['entries'] -Id 'static-scope-status-entries')
    Confirm-Check ($recordedStatusItems.Count -eq $recordedStatusCount) 'static-scope-status-entry-count'
    $recordedStatusEntries = [System.Collections.Generic.List[string]]::new()
    foreach ($recordedStatusItem in $recordedStatusItems) {
        Confirm-Check ($recordedStatusItem.ValueKind -eq [System.Text.Json.JsonValueKind]::String) 'static-scope-status-entry-type'
        $recordedStatusEntries.Add([string]$recordedStatusItem.GetString())
    }

    $recordedCountFields = Assert-JsonObjectShape -Element $scopeFields['counts'] -ExpectedNames @(
        'committed', 'staged', 'unstaged', 'untracked', 'union') -Id 'static-scope-counts-shape'
    $recordedScopeCounts = [ordered]@{}
    foreach ($scopeName in @('committed', 'staged', 'unstaged', 'untracked', 'union')) {
        $recordedScopeCounts[$scopeName] = Get-JsonIntegerField `
            -Fields $recordedCountFields `
            -Name $scopeName `
            -Id "static-scope-count-$scopeName"
    }

    $recordedEntryItems = @(Get-JsonArrayItems -Element $scopeFields['entries'] -Id 'static-scope-entries')
    $recordedScopeEntries = [System.Collections.Generic.List[object]]::new()
    foreach ($recordedEntryItem in $recordedEntryItems) {
        $recordedEntryFields = Assert-JsonObjectShape -Element $recordedEntryItem -ExpectedNames @(
            'category', 'path', 'presence', 'length', 'sha256') -Id 'static-scope-entry-shape'
        $recordedCategory = Get-JsonStringField -Fields $recordedEntryFields -Name 'category' -Id 'static-scope-entry-category'
        $recordedPath = Get-JsonStringField -Fields $recordedEntryFields -Name 'path' -Id 'static-scope-entry-path'
        $recordedPresence = Get-JsonStringField -Fields $recordedEntryFields -Name 'presence' -Id 'static-scope-entry-presence'
        $recordedLength = Get-JsonInt64Field -Fields $recordedEntryFields -Name 'length' -Id 'static-scope-entry-length'
        $recordedSha256 = Get-JsonStringField -Fields $recordedEntryFields -Name 'sha256' -Id 'static-scope-entry-sha'
        Confirm-Check (@('committed', 'staged', 'unstaged', 'untracked') -ccontains $recordedCategory) 'static-scope-entry-category-value'
        Confirm-Check (Test-CanonicalRelativePath $recordedPath) 'static-scope-entry-path-value'
        Confirm-Check (@('file', 'deleted') -ccontains $recordedPresence) 'static-scope-entry-presence-value'
        Confirm-Check (Test-Sha256Text $recordedSha256) 'static-scope-entry-sha-value'
        $recordedScopeEntries.Add([ordered]@{
                category = $recordedCategory
                path = $recordedPath
                presence = $recordedPresence
                length = $recordedLength
                sha256 = $recordedSha256
            })
    }
    $recordedScopeSnapshot = [pscustomobject]@{
        Schema = $recordedScopeSchema
        Digest = $recordedScopeDigest
        IndexDigest = $recordedIndexDigest
        IndexEntries = [string[]]$recordedIndexEntries.ToArray()
        StatusDigest = $recordedStatusDigest
        StatusEntries = [string[]]$recordedStatusEntries.ToArray()
        Counts = $recordedScopeCounts
        Entries = [object[]]$recordedScopeEntries.ToArray()
    }
    Confirm-Check (
        (Test-GitScopeSnapshotsEqual -Left $recordedScopeSnapshot -Right $scopeSnapshot)) `
        'static-scope-current-exact'

    $graphFields = Assert-JsonObjectShape -Element $staticFields['project_graph'] -ExpectedNames $expectedProjects -Id 'static-graph-shape'
    for ($projectIndex = 0; $projectIndex -lt $expectedProjects.Count; $projectIndex++) {
        $project = $expectedProjects[$projectIndex]
        Assert-ExactStringArray -Element $graphFields[$project] -Expected $expectedGraph[$project] -Id "static-graph-$projectIndex"
    }
    Assert-ExactStringArray -Element $staticFields['routes'] -Expected $expectedRoutes -Id 'static-routes'
    Assert-ExactStringArray -Element $staticFields['embedded_assets'] -Expected $expectedAssets -Id 'static-assets'
    Assert-ExactStringArray -Element $staticFields['test_cases'] -Expected $expectedCases -Id 'static-cases'

    $sourceManifestFields = Assert-JsonObjectShape -Element $staticFields['source_manifest'] -ExpectedNames @(
        'path', 'sha256', 'rows') -Id 'static-source-manifest-shape'
    $sourceManifestRelative = Get-JsonStringField -Fields $sourceManifestFields -Name 'path' -Id 'static-source-manifest-path'
    Confirm-Check ($sourceManifestRelative -ceq 'artifacts/evidence/source-tree.tsv') 'static-source-manifest-path-value'
    $sourceManifestPath = Resolve-SafeRelativePath -RelativePath $sourceManifestRelative -Root $crossPlatformRoot -Kind Leaf -Id 'source-manifest'
    $sourceManifestHash = Get-JsonStringField -Fields $sourceManifestFields -Name 'sha256' -Id 'static-source-manifest-hash'
    Confirm-Check (Test-Sha256Text $sourceManifestHash) 'static-source-manifest-hash-grammar'
    $sourceManifest = Confirm-SourceManifest -Path $sourceManifestPath
    Confirm-Check ($sourceManifestHash -ceq $sourceManifest.Sha256) 'static-source-manifest-hash-loaded'
    $sourceRows = Get-JsonIntegerField -Fields $sourceManifestFields -Name 'rows' -Id 'static-source-manifest-rows'
    Confirm-Check ($sourceRows -eq ($sourceManifest.Lines.Count - 1)) 'static-source-manifest-rows-value'

    $dependency = Read-JsonRecord -Name 'dependency-closure.json' -ExpectedSchema 'staxrip-dependency-closure-v2'
    $dependencyFields = Assert-JsonObjectShape -Element $dependency.Root -ExpectedNames @(
        'schema', 'sdk', 'rid', 'source', 'inputs', 'evaluated_projects', 'packages',
        'extracted_closure') -Id 'dependency-shape'
    Confirm-Check (
        (Get-JsonStringField -Fields $dependencyFields -Name 'rid' -Id 'dependency-rid') -ceq 'linux-x64') `
        'dependency-rid-value'

    $globalJsonPath = Resolve-SafeRelativePath -RelativePath 'global.json' -Root $crossPlatformRoot -Kind Leaf -Id 'global-json'
    $globalJsonRecord = Read-SafeTextRecord `
        -Path $globalJsonPath `
        -AllowedRoot $crossPlatformRoot `
        -MaximumBytes 4096 `
        -CanonicalLines
    $globalJsonText = $globalJsonRecord.Text
    $globalOptions = [System.Text.Json.JsonDocumentOptions]::new()
    $globalOptions.AllowTrailingCommas = $false
    $globalOptions.CommentHandling = [System.Text.Json.JsonCommentHandling]::Disallow
    $globalOptions.MaxDepth = 4
    $globalDocument = $null
    try {
        $globalDocument = [System.Text.Json.JsonDocument]::Parse($globalJsonText, $globalOptions)
        $globalFields = Assert-JsonObjectShape -Element $globalDocument.RootElement -ExpectedNames @('sdk') -Id 'global-json-shape'
        $globalSdkFields = Assert-JsonObjectShape -Element $globalFields['sdk'] -ExpectedNames @(
            'version', 'rollForward', 'allowPrerelease') -Id 'global-json-sdk-shape'
        $requestedSdk = Get-JsonStringField -Fields $globalSdkFields -Name 'version' -Id 'global-json-version'
        $rollForward = Get-JsonStringField -Fields $globalSdkFields -Name 'rollForward' -Id 'global-json-roll-forward'
        $allowPrerelease = Get-JsonBooleanField -Fields $globalSdkFields -Name 'allowPrerelease' -Id 'global-json-prerelease'
    }
    finally {
        if ($null -ne $globalDocument) {
            $globalDocument.Dispose()
        }
    }
    Confirm-Check ($requestedSdk -match '^10\.0\.([0-9])([0-9]{2})$') 'global-json-version-value'
    $requestedFeatureBand = [int]$Matches[1]
    $requestedPatch = [int]$Matches[2]
    Confirm-Check ($rollForward -ceq 'latestPatch') 'global-json-roll-forward-value'
    Confirm-Check (-not $allowPrerelease) 'global-json-prerelease-value'

    $sdkFields = Assert-JsonObjectShape -Element $dependencyFields['sdk'] -ExpectedNames @(
        'selected', 'requested', 'roll_forward', 'allow_prerelease') -Id 'dependency-sdk-shape'
    $selectedSdk = Get-JsonStringField -Fields $sdkFields -Name 'selected' -Id 'dependency-sdk-selected'
    Confirm-Check ($selectedSdk -match '^10\.0\.([0-9])([0-9]{2})$') 'dependency-sdk-selected-value'
    $selectedFeatureBand = [int]$Matches[1]
    $selectedPatch = [int]$Matches[2]
    Confirm-Check (
        $selectedFeatureBand -eq $requestedFeatureBand -and $selectedPatch -ge $requestedPatch) `
        'dependency-sdk-selected-compatible'
    Confirm-Check (
        (Get-JsonStringField -Fields $sdkFields -Name 'requested' -Id 'dependency-sdk-requested') -ceq $requestedSdk) `
        'dependency-sdk-requested-current'
    Confirm-Check (
        (Get-JsonStringField -Fields $sdkFields -Name 'roll_forward' -Id 'dependency-sdk-roll') -ceq $rollForward) `
        'dependency-sdk-roll-current'
    Confirm-Check (
        (Get-JsonBooleanField -Fields $sdkFields -Name 'allow_prerelease' -Id 'dependency-sdk-prerelease') -eq $allowPrerelease) `
        'dependency-sdk-prerelease-current'

    $allowedSource = 'https://api.nuget.org/v3/index.json'
    $sourceFields = Assert-JsonObjectShape -Element $dependencyFields['source'] -ExpectedNames @(
        'name', 'url', 'config_sha256', 'author_fingerprint', 'verified_archive_count') -Id 'dependency-source-shape'
    Confirm-Check (
        (Get-JsonStringField -Fields $sourceFields -Name 'name' -Id 'dependency-source-name') -ceq 'nuget.org') `
        'dependency-source-name-value'
    Confirm-Check (
        (Get-JsonStringField -Fields $sourceFields -Name 'url' -Id 'dependency-source-url') -ceq $allowedSource) `
        'dependency-source-url-value'
    $nugetConfigPath = Resolve-SafeRelativePath -RelativePath 'NuGet.config' -Root $crossPlatformRoot -Kind Leaf -Id 'nuget-config'
    $configHash = Get-JsonStringField -Fields $sourceFields -Name 'config_sha256' -Id 'dependency-source-config-hash'
    Confirm-Check (Test-Sha256Text $configHash) 'dependency-source-config-hash-grammar'
    Confirm-Check (
        $configHash -ceq (Get-SafeSha256 -Path $nugetConfigPath -AllowedRoot $crossPlatformRoot)) `
        'dependency-source-config-hash-current'
    Confirm-Check (
        (Get-JsonStringField -Fields $sourceFields -Name 'author_fingerprint' -Id 'dependency-source-author-fingerprint') -ceq
        '566A31882BE208BE4422F7CFD66ED09F5D4524A5994F50CCC8B05EC0528C1353') `
        'dependency-source-author-fingerprint-value'
    Confirm-Check (
        (Get-JsonIntegerField -Fields $sourceFields -Name 'verified_archive_count' -Id 'dependency-source-archive-count') -eq 3) `
        'dependency-source-archive-count-value'

    $expectedInputPaths = [System.Collections.Generic.List[string]]::new()
    foreach ($fixedInput in @('global.json', 'NuGet.config', 'Directory.Build.props', 'StaxRip.CrossPlatform.slnx')) {
        $expectedInputPaths.Add($fixedInput)
    }
    foreach ($project in $expectedProjects) {
        $expectedInputPaths.Add($project)
        $projectDirectory = [System.IO.Path]::GetDirectoryName($project).Replace('\', '/')
        $expectedInputPaths.Add("$projectDirectory/packages.lock.json")
    }
    $sortedExpectedInputs = [string[]]$expectedInputPaths.ToArray()
    [System.Array]::Sort($sortedExpectedInputs, [System.StringComparer]::Ordinal)
    $inputItems = @(Get-JsonArrayItems -Element $dependencyFields['inputs'] -Id 'dependency-inputs')
    Confirm-Check ($inputItems.Count -eq $sortedExpectedInputs.Count) 'dependency-inputs-count'
    $dependencyInputRecords = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $inputItems.Count; $index++) {
        $inputFields = Assert-JsonObjectShape -Element $inputItems[$index] -ExpectedNames @(
            'path', 'sha256') -Id 'dependency-input-shape'
        $relativeInput = Get-JsonStringField -Fields $inputFields -Name 'path' -Id 'dependency-input-path'
        Confirm-Check ($relativeInput -ceq $sortedExpectedInputs[$index]) 'dependency-input-path-value'
        $inputPath = Resolve-SafeRelativePath -RelativePath $relativeInput -Root $crossPlatformRoot -Kind Leaf -Id 'dependency-input-file'
        $inputHash = Get-JsonStringField -Fields $inputFields -Name 'sha256' -Id 'dependency-input-hash'
        Confirm-Check (Test-Sha256Text $inputHash) 'dependency-input-hash-grammar'
        Confirm-Check (
            $inputHash -ceq (Get-SafeSha256 -Path $inputPath -AllowedRoot $crossPlatformRoot)) `
            'dependency-input-hash-current'
        if ($relativeInput -ceq 'global.json') {
            Confirm-Check ($inputHash -ceq $globalJsonRecord.Sha256) 'dependency-global-json-hash-loaded'
        }
        $dependencyInputRecords.Add([pscustomobject]@{
                Path = $inputPath
                Sha256 = $inputHash
            })
    }

    $evaluatedAssetState = Get-EvaluatedAssetMap `
        -ExpectedProjects $expectedProjects `
        -ExpectedGraph $expectedGraph `
        -RequiredPackageIds $expectedPackageIds `
        -RequiredPackageVersion $expectedPackageVersion
    $assetMap = $evaluatedAssetState.Assets
    $derivedAssetPackages = $evaluatedAssetState.Packages
    $evaluatedItems = @(Get-JsonArrayItems -Element $dependencyFields['evaluated_projects'] -Id 'dependency-evaluated')
    Confirm-Check ($evaluatedItems.Count -eq $expectedProjects.Count) 'dependency-evaluated-count'
    for ($index = 0; $index -lt $evaluatedItems.Count; $index++) {
        $evaluatedFields = Assert-JsonObjectShape -Element $evaluatedItems[$index] -ExpectedNames @(
            'project', 'evaluated_assets_sha256') -Id 'dependency-evaluated-shape'
        $evaluatedProject = Get-JsonStringField -Fields $evaluatedFields -Name 'project' -Id 'dependency-evaluated-project'
        Confirm-Check ($evaluatedProject -ceq $expectedProjects[$index]) 'dependency-evaluated-project-value'
        $evaluatedHash = Get-JsonStringField -Fields $evaluatedFields -Name 'evaluated_assets_sha256' -Id 'dependency-evaluated-hash'
        Confirm-Check (Test-Sha256Text $evaluatedHash) 'dependency-evaluated-hash-grammar'
        Confirm-Check ($assetMap[$evaluatedProject].Sha256 -ceq $evaluatedHash) 'dependency-evaluated-hash-current'
    }

    $packageItems = @(Get-JsonArrayItems -Element $dependencyFields['packages'] -Id 'dependency-packages')
    Confirm-Check ($packageItems.Count -eq $expectedPackageIds.Count) 'dependency-package-count'
    $packages = [System.Collections.Generic.Dictionary[string,object]]::new([System.StringComparer]::Ordinal)
    for ($index = 0; $index -lt $packageItems.Count; $index++) {
        $packageFields = Assert-JsonObjectShape -Element $packageItems[$index] -ExpectedNames @(
            'id', 'version', 'source', 'nuget_content_hash', 'extracted_path', 'archive_file',
            'archive_length', 'archive_sha256', 'archive_sha512', 'archive_file_entry_count',
            'archive_payload_file_count', 'archive_only_metadata_count',
            'archive_extraction_binding', 'projects', 'extracted_file_count',
            'extracted_inventory_sha256', 'extracted_inventory_total_bytes') `
            -Id 'dependency-package-shape'
        $packageId = Get-JsonStringField -Fields $packageFields -Name 'id' -Id 'dependency-package-id'
        $packageVersion = Get-JsonStringField -Fields $packageFields -Name 'version' -Id 'dependency-package-version'
        Confirm-Check ($packageId -ceq $expectedPackageIds[$index]) 'dependency-package-id-value'
        Confirm-Check ($packageId -match '^[A-Za-z0-9._+-]+$') 'dependency-package-id-grammar'
        Confirm-Check ($packageVersion -ceq $expectedPackageVersion) 'dependency-package-version-current'
        Confirm-Check (
            (Get-JsonStringField -Fields $packageFields -Name 'source' -Id 'dependency-package-source') -ceq $allowedSource) `
            'dependency-package-source-value'
        $contentHash = Get-JsonStringField -Fields $packageFields -Name 'nuget_content_hash' -Id 'dependency-package-content-hash'
        Confirm-Check (Test-NuGetContentHash $contentHash) 'dependency-package-content-hash-value'
        $extractedRelative = Get-JsonStringField -Fields $packageFields -Name 'extracted_path' -Id 'dependency-package-extracted'
        $expectedExtracted = "$($packageId.ToLowerInvariant())/$packageVersion"
        Confirm-Check ($extractedRelative -ceq $expectedExtracted) 'dependency-package-extracted-value'
        Confirm-Check ($extractedRelative -match '^[A-Za-z0-9._+-]+/[A-Za-z0-9._+-]+$') 'dependency-package-extracted-grammar'
        $packageDirectory = Resolve-SafeRelativePath -RelativePath $extractedRelative -Root $packagesRoot -Kind Directory -Id 'dependency-package-directory'

        $archiveName = Get-JsonStringField `
            -Fields $packageFields `
            -Name 'archive_file' `
            -Id 'dependency-package-archive-file'
        $expectedArchiveName = "$($packageId.ToLowerInvariant()).$packageVersion.nupkg"
        Confirm-Check ($archiveName -ceq $expectedArchiveName) 'dependency-package-archive-file-value'
        Confirm-Check ($archiveName -cmatch '^[a-z0-9._+-]+\.nupkg$') 'dependency-package-archive-file-grammar'
        $archivePath = [System.IO.Path]::GetFullPath((Join-Path $packageDirectory $archiveName))
        Confirm-Check (Test-SafeLeaf -Path $archivePath -AllowedRoot $packagesRoot) 'dependency-package-archive-file-safe'
        $archiveLength = Get-JsonInt64Field `
            -Fields $packageFields `
            -Name 'archive_length' `
            -Id 'dependency-package-archive-length'
        Confirm-Check ($archiveLength -gt 0 -and $archiveLength -le 1073741824) 'dependency-package-archive-length-value'
        $archiveSha256 = Get-JsonStringField `
            -Fields $packageFields `
            -Name 'archive_sha256' `
            -Id 'dependency-package-archive-sha256'
        Confirm-Check (Test-Sha256Text $archiveSha256) 'dependency-package-archive-sha256-value'
        $archiveSha512 = Get-JsonStringField `
            -Fields $packageFields `
            -Name 'archive_sha512' `
            -Id 'dependency-package-archive-sha512'
        Confirm-Check (Test-NuGetContentHash $archiveSha512) 'dependency-package-archive-sha512-value'
        $archiveFileEntryCount = Get-JsonIntegerField `
            -Fields $packageFields `
            -Name 'archive_file_entry_count' `
            -Id 'dependency-package-archive-entry-count'
        Confirm-Check (
            $archiveFileEntryCount -gt 0 -and $archiveFileEntryCount -le 10000) `
            'dependency-package-archive-entry-count-value'
        $archivePayloadFileCount = Get-JsonIntegerField `
            -Fields $packageFields `
            -Name 'archive_payload_file_count' `
            -Id 'dependency-package-archive-payload-count'
        Confirm-Check (
            $archivePayloadFileCount -gt 0 -and $archivePayloadFileCount -le $archiveFileEntryCount) `
            'dependency-package-archive-payload-count-value'
        $archiveOnlyMetadataCount = Get-JsonIntegerField `
            -Fields $packageFields `
            -Name 'archive_only_metadata_count' `
            -Id 'dependency-package-archive-metadata-count'
        Confirm-Check ($archiveOnlyMetadataCount -eq 3) 'dependency-package-archive-metadata-count-value'
        Confirm-Check (
            ($archivePayloadFileCount + $archiveOnlyMetadataCount) -eq $archiveFileEntryCount) `
            'dependency-package-archive-count-sum'
        $archiveExtractionBinding = Get-JsonStringField `
            -Fields $packageFields `
            -Name 'archive_extraction_binding' `
            -Id 'dependency-package-archive-binding'
        Confirm-Check (
            $archiveExtractionBinding -ceq 'zip-path-length-sha256-v1') `
            'dependency-package-archive-binding-value'

        $projectItems = @(Get-JsonArrayItems -Element $packageFields['projects'] -Id 'dependency-package-projects')
        Confirm-Check ($projectItems.Count -gt 0 -and $projectItems.Count -le $expectedProjects.Count) 'dependency-package-project-count'
        $projectNames = [System.Collections.Generic.List[string]]::new()
        $previousProject = $null
        foreach ($projectItem in $projectItems) {
            Confirm-Check ($projectItem.ValueKind -eq [System.Text.Json.JsonValueKind]::String) 'dependency-package-project-type'
            $projectName = [string]$projectItem.GetString()
            Confirm-Check ($expectedProjects -ccontains $projectName) 'dependency-package-project-known'
            if ($null -ne $previousProject) {
                Confirm-Check ([System.StringComparer]::Ordinal.Compare($previousProject, $projectName) -lt 0) 'dependency-package-project-order'
            }
            $previousProject = $projectName
            $projectNames.Add($projectName)
        }
        $fileCount = Get-JsonIntegerField -Fields $packageFields -Name 'extracted_file_count' -Id 'dependency-package-file-count'
        Confirm-Check ($fileCount -gt 0 -and $fileCount -le 10000) 'dependency-package-file-count-value'
        $inventorySha256 = Get-JsonStringField `
            -Fields $packageFields `
            -Name 'extracted_inventory_sha256' `
            -Id 'dependency-package-inventory-sha256'
        Confirm-Check (Test-Sha256Text $inventorySha256) 'dependency-package-inventory-sha256-value'
        $inventoryTotalBytes = Get-JsonInt64Field `
            -Fields $packageFields `
            -Name 'extracted_inventory_total_bytes' `
            -Id 'dependency-package-inventory-total-bytes'
        Confirm-Check (
            $inventoryTotalBytes -ge 0 -and $inventoryTotalBytes -le 2147483648) `
            'dependency-package-inventory-total-bytes-value'
        Confirm-Check (
            $fileCount -eq ($archivePayloadFileCount + 3)) `
            'dependency-package-file-count-binding'
        $packageKey = "$packageId/$packageVersion"
        Confirm-Check ($packageKey -match '^[A-Za-z0-9._+-]+/[A-Za-z0-9._+-]+$') 'dependency-package-key-grammar'
        Confirm-Check (-not $packages.ContainsKey($packageKey)) 'dependency-package-key-unique'
        Confirm-Check ($derivedAssetPackages.ContainsKey($packageKey)) 'dependency-package-derived-from-assets'
        $derivedAssetPackage = $derivedAssetPackages[$packageKey]
        Confirm-Check (
            $derivedAssetPackage.Id -ceq $packageId -and
            $derivedAssetPackage.Version -ceq $packageVersion) `
            'dependency-package-derived-identity'
        $derivedProjectNames = [string[]]@($derivedAssetPackage.Projects)
        [System.Array]::Sort($derivedProjectNames, [System.StringComparer]::Ordinal)
        Confirm-Check ($projectNames.Count -eq $derivedProjectNames.Count) 'dependency-package-derived-project-count'
        for ($projectIndex = 0; $projectIndex -lt $derivedProjectNames.Count; $projectIndex++) {
            Confirm-Check (
                $projectNames[$projectIndex] -ceq $derivedProjectNames[$projectIndex]) `
                'dependency-package-derived-project-member'
        }
        Confirm-NuGetMetadata -PackageDirectory $packageDirectory -ExpectedSource $allowedSource -ExpectedContentHash $contentHash
        $currentArchiveBinding = Get-ArchiveExtractionBinding `
            -PackageKey $packageKey `
            -PackageId $packageId `
            -ArchivePath $archivePath `
            -ArchiveName $archiveName `
            -PackageDirectory $packageDirectory `
            -AssertionMode Primary
        Confirm-Check ($currentArchiveBinding.ArchiveLength -eq $archiveLength) 'dependency-package-archive-length-current'
        Confirm-Check ($currentArchiveBinding.ArchiveSha256 -ceq $archiveSha256) 'dependency-package-archive-sha256-current'
        Confirm-Check ($currentArchiveBinding.ArchiveSha512 -ceq $archiveSha512) 'dependency-package-archive-sha512-current'
        Confirm-Check (
            $currentArchiveBinding.ArchiveFileEntryCount -eq $archiveFileEntryCount) `
            'dependency-package-archive-entry-count-current'
        Confirm-Check (
            $currentArchiveBinding.ArchivePayloadFileCount -eq $archivePayloadFileCount) `
            'dependency-package-archive-payload-count-current'
        Confirm-Check (
            $currentArchiveBinding.ArchiveOnlyMetadataCount -eq $archiveOnlyMetadataCount) `
            'dependency-package-archive-metadata-count-current'
        Confirm-Check ($currentArchiveBinding.DiskFileCount -eq $fileCount) 'dependency-package-archive-disk-count-current'
        Confirm-Check (
            $currentArchiveBinding.InventorySha256 -ceq $inventorySha256) `
            'dependency-package-inventory-sha256-current'
        Confirm-Check (
            $currentArchiveBinding.DiskTotalBytes -eq $inventoryTotalBytes) `
            'dependency-package-inventory-total-bytes-current'
        $packages.Add($packageKey, [pscustomobject]@{
                Id = $packageId
                Version = $packageVersion
                Directory = $packageDirectory
                ExtractedPath = $extractedRelative
                FileCount = $fileCount
                Projects = $projectNames.ToArray()
                ArchivePath = $archivePath
                ArchiveName = $archiveName
                ArchiveLength = $archiveLength
                ArchiveSha256 = $archiveSha256
                ArchiveSha512 = $archiveSha512
                ArchiveFileEntryCount = $archiveFileEntryCount
                ArchivePayloadFileCount = $archivePayloadFileCount
                ArchiveOnlyMetadataCount = $archiveOnlyMetadataCount
                ArchiveExtractionBinding = $archiveExtractionBinding
                InventorySha256 = $inventorySha256
                InventoryTotalBytes = $inventoryTotalBytes
            })
    }
    Confirm-Check ($packages.Count -eq $derivedAssetPackages.Count) 'dependency-package-derived-closure-count'
    foreach ($derivedPackageKey in $derivedAssetPackages.Keys) {
        Confirm-Check ($packages.ContainsKey($derivedPackageKey)) 'dependency-package-derived-closure-member'
    }

    $closureFields = Assert-JsonObjectShape -Element $dependencyFields['extracted_closure'] -ExpectedNames @(
        'path', 'sha256', 'row_count') -Id 'dependency-closure-shape'
    $closureRelative = Get-JsonStringField -Fields $closureFields -Name 'path' -Id 'dependency-closure-path'
    Confirm-Check ($closureRelative -ceq 'artifacts/evidence/dependency-files.tsv') 'dependency-closure-path-value'
    $closurePath = Resolve-SafeRelativePath -RelativePath $closureRelative -Root $crossPlatformRoot -Kind Leaf -Id 'dependency-closure-file'
    $closureHash = Get-JsonStringField -Fields $closureFields -Name 'sha256' -Id 'dependency-closure-hash'
    Confirm-Check (Test-Sha256Text $closureHash) 'dependency-closure-hash-grammar'
    $closureRowCount = Get-JsonIntegerField -Fields $closureFields -Name 'row_count' -Id 'dependency-closure-row-count'
    Confirm-Check ($closureRowCount -gt 0 -and $closureRowCount -le 200000) 'dependency-closure-row-count-value'

    $closure = Read-CanonicalLines -Path $closurePath -AllowedRoot $evidenceRoot -MaximumBytes 268435456
    Confirm-Check ($closureHash -ceq $closure.Sha256) 'dependency-closure-hash-loaded'
    Confirm-Check ($closure.Lines.Count -ge 2) 'dependency-tsv-row-presence'
    Confirm-Check ($closure.Lines[0] -ceq "package`tpath`tlength`tsha256") 'dependency-tsv-header'
    Confirm-Check (($closure.Lines.Count - 1) -eq $closureRowCount) 'dependency-tsv-row-count'
    $packageRowPaths = [System.Collections.Generic.Dictionary[string,System.Collections.Generic.HashSet[string]]]::new(
        [System.StringComparer]::Ordinal)
    foreach ($key in $packages.Keys) {
        $packageRowPaths.Add($key, [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal))
    }
    $previousClosureLine = $null
    for ($index = 1; $index -lt $closure.Lines.Count; $index++) {
        $line = $closure.Lines[$index]
        if ($null -ne $previousClosureLine) {
            Confirm-Check ([System.StringComparer]::Ordinal.Compare($previousClosureLine, $line) -lt 0) 'dependency-tsv-row-order'
        }
        $previousClosureLine = $line
        $fields = $line.Split("`t", [System.StringSplitOptions]::None)
        Confirm-Check ($fields.Count -eq 4) 'dependency-tsv-field-count'
        $packageKey = $fields[0]
        $relativeFile = $fields[1]
        Confirm-Check ($packageKey -match '^[A-Za-z0-9._+-]+/[A-Za-z0-9._+-]+$') 'dependency-tsv-package-grammar'
        Confirm-Check ($packages.ContainsKey($packageKey)) 'dependency-tsv-package-known'
        Confirm-Check (Test-CanonicalRelativePath $relativeFile) 'dependency-tsv-path-grammar'
        Confirm-Check ($packageRowPaths[$packageKey].Add($relativeFile)) 'dependency-tsv-path-unique'
        $length = Convert-ToInt64 -Value $fields[2] -Id 'dependency-tsv-length'
        Confirm-Check (Test-Sha256Text $fields[3]) 'dependency-tsv-sha-grammar'
        $package = $packages[$packageKey]
        $fullFile = Resolve-SafeRelativePath -RelativePath $relativeFile -Root $package.Directory -Kind Leaf -Id 'dependency-tsv-file'
        $file = Get-Item -LiteralPath $fullFile -Force
        Confirm-Check ($file.Length -eq $length) 'dependency-tsv-length-current'
        Confirm-Check (
            (Get-SafeSha256 -Path $fullFile -AllowedRoot $packagesRoot) -ceq $fields[3]) `
            'dependency-tsv-sha-current'
    }
    $summedPackageFiles = 0
    foreach ($packageEntry in $packages.GetEnumerator()) {
        $package = $packageEntry.Value
        $tree = Get-SafeTreeInventory -Root $package.Directory -AllowedRoot $packagesRoot -MaximumEntries 100000
        $actualFilePaths = @($tree.GetEnumerator() | Where-Object { -not $_.Value.PSIsContainer } | ForEach-Object { $_.Key })
        Confirm-Check ($actualFilePaths.Count -eq $package.FileCount) 'dependency-package-inventory-count'
        Confirm-Check ($packageRowPaths[$packageEntry.Key].Count -eq $package.FileCount) 'dependency-package-tsv-count'
        foreach ($actualFilePath in $actualFilePaths) {
            Confirm-Check ($packageRowPaths[$packageEntry.Key].Contains($actualFilePath)) 'dependency-package-inventory-path'
        }
        $summedPackageFiles += $package.FileCount
    }
    Confirm-Check ($summedPackageFiles -eq $closureRowCount) 'dependency-package-total-count'

    $dependencySidecarPath = [System.IO.Path]::GetFullPath((Join-Path $evidenceRoot 'dependency-closure.json.sha256'))
    $dependencySidecar = Confirm-Sidecar `
        -SourcePath $dependency.Path `
        -ExpectedSourceSha256 $dependency.Sha256 `
        -SidecarPath $dependencySidecarPath `
        -AllowedRoot $evidenceRoot `
        -Id 'dependency-sidecar'

    $summary = Read-JsonRecord -Name 'verify-summary.json' -ExpectedSchema 'staxrip-port-verify-v1'
    $summaryFields = Assert-JsonObjectShape -Element $summary.Root -ExpectedNames @(
        'schema', 'base', 'head', 'steps', 'source_record_sha256',
        'dependency_record_sha256', 'publish_root', 'artifact_manifest') -Id 'summary-shape'
    Confirm-Check (
        (Get-JsonStringField -Fields $summaryFields -Name 'base' -Id 'summary-base') -ceq $BaseCommit) `
        'summary-base-value'
    Confirm-Check (
        (Get-JsonStringField -Fields $summaryFields -Name 'head' -Id 'summary-head') -ceq $currentHead) `
        'summary-head-current'
    $summaryStaticHash = Get-JsonStringField -Fields $summaryFields -Name 'source_record_sha256' -Id 'summary-static-hash'
    Confirm-Check (Test-Sha256Text $summaryStaticHash) 'summary-static-hash-grammar'
    Confirm-Check (
        $summaryStaticHash -ceq $sourceRecordHash) `
        'summary-static-hash-current'
    $summaryDependencyHash = Get-JsonStringField -Fields $summaryFields -Name 'dependency_record_sha256' -Id 'summary-dependency-hash'
    Confirm-Check (Test-Sha256Text $summaryDependencyHash) 'summary-dependency-hash-grammar'
    Confirm-Check ($summaryDependencyHash -ceq $dependency.Sha256) 'summary-dependency-hash-loaded'

    $stepItems = @(Get-JsonArrayItems -Element $summaryFields['steps'] -Id 'summary-steps')
    Confirm-Check ($stepItems.Count -in @(9, 10)) 'summary-step-count'
    $expectedStepIds = if ($stepItems.Count -eq 10) {
        @(
            'port-static', 'port-restore-initial', 'port-static-after-locks',
            'port-build-debug', 'port-build-release', 'port-contract-debug',
            'port-contract-release', 'port-contract-failure', 'port-publish-linux',
            'port-artifact-manifest'
        )
    }
    else {
        @(
            'port-static', 'port-restore', 'port-build-debug', 'port-build-release',
            'port-contract-debug', 'port-contract-release', 'port-contract-failure',
            'port-publish-linux', 'port-artifact-manifest'
        )
    }
    for ($index = 0; $index -lt $stepItems.Count; $index++) {
        $expectedStepId = $expectedStepIds[$index]
        if ($expectedStepId -in @('port-contract-debug', 'port-contract-release')) {
            $stepFields = Assert-JsonObjectShape -Element $stepItems[$index] -ExpectedNames @(
                'id', 'exit', 'cases', 'assertions') -Id 'summary-contract-step-shape'
            Confirm-Check (
                (Get-JsonIntegerField -Fields $stepFields -Name 'cases' -Id 'summary-contract-cases') -eq 31) `
                'summary-contract-cases-value'
            Confirm-Check (
                (Get-JsonIntegerField -Fields $stepFields -Name 'assertions' -Id 'summary-contract-assertions') -eq 455) `
                'summary-contract-assertions-value'
        }
        elseif ($expectedStepId -ceq 'port-contract-failure') {
            $stepFields = Assert-JsonObjectShape -Element $stepItems[$index] -ExpectedNames @(
                'id', 'exit', 'expected_nonzero') -Id 'summary-failure-step-shape'
            Confirm-Check (
                (Get-JsonIntegerField -Fields $stepFields -Name 'exit' -Id 'summary-failure-exit') -eq 1) `
                'summary-failure-exit-value'
            Confirm-Check (
                (Get-JsonBooleanField -Fields $stepFields -Name 'expected_nonzero' -Id 'summary-failure-expected') -eq $true) `
                'summary-failure-expected-value'
        }
        else {
            $stepFields = Assert-JsonObjectShape -Element $stepItems[$index] -ExpectedNames @(
                'id', 'exit') -Id 'summary-step-shape'
        }
        Confirm-Check (
            (Get-JsonStringField -Fields $stepFields -Name 'id' -Id 'summary-step-id') -ceq $expectedStepId) `
            'summary-step-id-value'
        if ($expectedStepId -cne 'port-contract-failure') {
            Confirm-Check (
                (Get-JsonIntegerField -Fields $stepFields -Name 'exit' -Id 'summary-step-exit') -eq 0) `
                'summary-step-exit-value'
        }
    }

    $publishedRelative = Get-JsonStringField -Fields $summaryFields -Name 'publish_root' -Id 'summary-publish-root'
    Confirm-Check (
        $publishedRelative.StartsWith('artifacts/publish/', [System.StringComparison]::Ordinal) -and
        (Test-CanonicalRelativePath $publishedRelative)) 'summary-publish-root-value'
    $publishedPath = Resolve-SafeRelativePath -RelativePath $publishedRelative -Root $crossPlatformRoot -Kind Directory -Id 'summary-published-directory'
    Confirm-Check (Test-ContainedPath -Candidate $publishedPath -Root $publishRoot) 'summary-published-directory-scope'

    $artifactFields = Assert-JsonObjectShape -Element $summaryFields['artifact_manifest'] -ExpectedNames @(
        'path', 'sha256') -Id 'summary-artifact-shape'
    $artifactRelative = Get-JsonStringField -Fields $artifactFields -Name 'path' -Id 'summary-artifact-path'
    Confirm-Check ($artifactRelative -ceq 'artifacts/evidence/artifact-linux-x64.tsv') 'summary-artifact-path-value'
    $manifestPath = Resolve-SafeRelativePath -RelativePath $artifactRelative -Root $crossPlatformRoot -Kind Leaf -Id 'artifact-manifest'
    $artifactHash = Get-JsonStringField -Fields $artifactFields -Name 'sha256' -Id 'summary-artifact-hash'
    Confirm-Check (Test-Sha256Text $artifactHash) 'summary-artifact-hash-grammar'
    $manifestSidecarPath = [System.IO.Path]::GetFullPath((Join-Path $evidenceRoot 'artifact-linux-x64.tsv.sha256'))
    $manifest = Confirm-ArtifactManifest -Path $manifestPath -PublishedRoot $publishedPath
    Confirm-Check ($artifactHash -ceq $manifest.Sha256) 'summary-artifact-hash-loaded'
    $manifestSidecar = Confirm-Sidecar `
        -SourcePath $manifestPath `
        -ExpectedSourceSha256 $manifest.Sha256 `
        -SidecarPath $manifestSidecarPath `
        -AllowedRoot $evidenceRoot `
        -Id 'artifact-sidecar'

    $windowsApphostPath = Resolve-SafeRelativePath `
        -RelativePath 'artifacts/bin/StaxRip.Server/release/StaxRip.Server.exe' `
        -Root $crossPlatformRoot `
        -Kind Leaf `
        -Id 'windows-release-apphost'
    $windowsApphostHash = Get-SafeSha256 -Path $windowsApphostPath -AllowedRoot $artifactsRoot

    # The apphost is a configuration-invariant stub: Debug and Release apphosts are
    # byte-identical, so binding it alone leaves the producers' "configuration": "Release"
    # declaration unfalsifiable. What differs is the managed set the apphost loads from
    # its own directory, and binding Server.dll alone would still admit a Debug
    # Core/Contracts/Platform assembly or a tampered runtime configuration beside a
    # genuine Release Server.dll. Each producer records managedSetSha256, a composite
    # over the six runtime-relevant files beside the server it ran: the SHA-256 of the
    # newline-joined lowercase per-file hashes in the fixed order below, with a trailing
    # newline. The recomputation here from the on-disk Release tree is what the producer
    # values must equal, so a Debug run declaring Release fails the audit. The same
    # function exists verbatim in both producers; drift is self-revealing because these
    # comparisons then fail. Tracked in Docs/Review/SLICE-002-Remediation-Backlog.md as
    # R-S2-042.
    $managedSetLeaves = @(
        'StaxRip.Contracts.dll',
        'StaxRip.Core.dll',
        'StaxRip.Platform.dll',
        'StaxRip.Server.deps.json',
        'StaxRip.Server.dll',
        'StaxRip.Server.runtimeconfig.json'
    )
    $managedSetInputs = [System.Collections.Generic.List[object]]::new()
    $managedSetRows = foreach ($managedLeaf in $managedSetLeaves) {
        $managedLeafPath = Resolve-SafeRelativePath `
            -RelativePath ('artifacts/bin/StaxRip.Server/release/' + $managedLeaf) `
            -Root $crossPlatformRoot `
            -Kind Leaf `
            -Id 'windows-release-managed'
        $managedLeafHash = Get-SafeSha256 -Path $managedLeafPath -AllowedRoot $artifactsRoot
        $managedSetInputs.Add([pscustomobject]@{ Path = $managedLeafPath; Sha256 = $managedLeafHash })
        $managedLeafHash
    }
    $windowsManagedSetHash = [System.Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData(
            [System.Text.UTF8Encoding]::new($false).GetBytes(($managedSetRows -join "`n") + "`n"))).ToLowerInvariant()

    $http = Read-JsonRecord -Name 'http-windows.json' -ExpectedSchema 'staxrip-http-windows-v1'
    $httpFields = Assert-JsonObjectShape -Element $http.Root -ExpectedNames @(
        'schema', 'gate', 'result', 'configuration', 'host', 'sourceRecordSha256',
        'serverSha256', 'managedSetSha256', 'checks',
        'lifecycle', 'secretsPersisted') -Id 'http-shape'
    Confirm-Check (
        (Get-JsonStringField -Fields $httpFields -Name 'gate' -Id 'http-gate') -ceq 'port-http-windows') `
        'http-gate-value'
    Confirm-Check (
        (Get-JsonStringField -Fields $httpFields -Name 'result' -Id 'http-result') -ceq 'pass') `
        'http-result-value'
    Confirm-Check (
        (Get-JsonStringField -Fields $httpFields -Name 'configuration' -Id 'http-configuration') -ceq 'Release') `
        'http-configuration-value'
    $httpSourceRecordHash = Get-JsonStringField `
        -Fields $httpFields `
        -Name 'sourceRecordSha256' `
        -Id 'http-source-record-hash'
    Confirm-Check (
        (Test-Sha256Text $httpSourceRecordHash) -and $httpSourceRecordHash -ceq $sourceRecordHash) `
        'http-source-record-hash-current'
    $httpHostFields = Assert-JsonObjectShape -Element $httpFields['host'] -ExpectedNames @(
        'platformId', 'architectureId', 'runtimeVersion') -Id 'http-host-shape'
    Confirm-Check (
        (Get-JsonStringField -Fields $httpHostFields -Name 'platformId' -Id 'http-host-platform') -ceq 'windows') `
        'http-host-platform-value'
    Confirm-Check (
        (Get-JsonStringField -Fields $httpHostFields -Name 'architectureId' -Id 'http-host-architecture') -ceq 'x64') `
        'http-host-architecture-value'
    $httpRuntimeVersion = Get-JsonStringField -Fields $httpHostFields -Name 'runtimeVersion' -Id 'http-host-runtime'
    Confirm-Check ($httpRuntimeVersion -match '^[0-9]+\.[0-9]+\.[0-9]+(?:\.[0-9]+)?$') 'http-host-runtime-value'
    $httpServerHash = Get-JsonStringField -Fields $httpFields -Name 'serverSha256' -Id 'http-server-hash'
    Confirm-Check (Test-Sha256Text $httpServerHash) 'http-server-hash-grammar'
    Confirm-Check ($httpServerHash -ceq $windowsApphostHash) 'http-server-hash-current'
    $httpManagedHash = Get-JsonStringField -Fields $httpFields -Name 'managedSetSha256' -Id 'http-managed-hash'
    Confirm-Check (Test-Sha256Text $httpManagedHash) 'http-managed-hash-grammar'
    Confirm-Check ($httpManagedHash -ceq $windowsManagedSetHash) 'http-managed-hash-current'
    Confirm-Check (
        (Get-JsonIntegerField -Fields $httpFields -Name 'checks' -Id 'http-checks') -gt 0) `
        'http-checks-value'
    Confirm-Check (
        (Get-JsonStringField -Fields $httpFields -Name 'lifecycle' -Id 'http-lifecycle') -ceq 'gate-initiated-kill') `
        'http-lifecycle-value'
    Confirm-Check (
        -not (Get-JsonBooleanField -Fields $httpFields -Name 'secretsPersisted' -Id 'http-secrets')) `
        'http-secrets-value'

    $browser = Read-JsonRecord -Name 'browser.json' -ExpectedSchema 'staxrip-browser-v1'
    $browserFields = Assert-JsonObjectShape -Element $browser.Root -ExpectedNames @(
        'schema', 'gate', 'result', 'configuration', 'browser', 'sourceRecordSha256',
        'serverSha256', 'managedSetSha256',
        'observedNetworkScope', 'checks', 'secretsPersisted') -Id 'browser-shape'
    Confirm-Check (
        (Get-JsonStringField -Fields $browserFields -Name 'gate' -Id 'browser-gate') -ceq 'port-browser') `
        'browser-gate-value'
    Confirm-Check (
        (Get-JsonStringField -Fields $browserFields -Name 'result' -Id 'browser-result') -ceq 'pass') `
        'browser-result-value'
    Confirm-Check (
        (Get-JsonStringField -Fields $browserFields -Name 'configuration' -Id 'browser-configuration') -ceq 'Release') `
        'browser-configuration-value'
    $browserSourceRecordHash = Get-JsonStringField `
        -Fields $browserFields `
        -Name 'sourceRecordSha256' `
        -Id 'browser-source-record-hash'
    Confirm-Check (
        (Test-Sha256Text $browserSourceRecordHash) -and $browserSourceRecordHash -ceq $sourceRecordHash) `
        'browser-source-record-hash-current'
    $browserIdentityFields = Assert-JsonObjectShape -Element $browserFields['browser'] -ExpectedNames @(
        'name', 'version', 'executableSha256') -Id 'browser-identity-shape'
    $browserName = Get-JsonStringField -Fields $browserIdentityFields -Name 'name' -Id 'browser-name'
    Confirm-Check (@('edge', 'chrome') -ccontains $browserName) 'browser-name-value'
    $browserVersion = Get-JsonStringField -Fields $browserIdentityFields -Name 'version' -Id 'browser-version'
    Confirm-Check (
        $browserVersion.Length -le 32 -and $browserVersion -match '^[0-9]+(?:\.[0-9]+)+$') `
        'browser-version-value'
    $browserExecutableHash = Get-JsonStringField -Fields $browserIdentityFields -Name 'executableSha256' -Id 'browser-executable-hash'
    Confirm-Check (Test-Sha256Text $browserExecutableHash) 'browser-executable-hash-value'
    $browserServerHash = Get-JsonStringField -Fields $browserFields -Name 'serverSha256' -Id 'browser-server-hash'
    Confirm-Check (Test-Sha256Text $browserServerHash) 'browser-server-hash-grammar'
    Confirm-Check (
        $browserServerHash -ceq $windowsApphostHash -and $browserServerHash -ceq $httpServerHash) `
        'browser-server-hash-current'
    $browserManagedHash = Get-JsonStringField -Fields $browserFields -Name 'managedSetSha256' -Id 'browser-managed-hash'
    Confirm-Check (Test-Sha256Text $browserManagedHash) 'browser-managed-hash-grammar'
    Confirm-Check (
        $browserManagedHash -ceq $windowsManagedSetHash -and $browserManagedHash -ceq $httpManagedHash) `
        'browser-managed-hash-current'
    Confirm-Check (
        (Get-JsonStringField -Fields $browserFields -Name 'observedNetworkScope' -Id 'browser-network-scope') -ceq `
            'cdp-page-target-after-network-enable') 'browser-network-scope-value'
    Confirm-Check (
        (Get-JsonIntegerField -Fields $browserFields -Name 'checks' -Id 'browser-checks') -gt 0) `
        'browser-checks-value'
    Confirm-Check (
        -not (Get-JsonBooleanField -Fields $browserFields -Name 'secretsPersisted' -Id 'browser-secrets')) `
        'browser-secrets-value'

    $linux = Read-JsonRecord -Name 'linux-runtime.json' -ExpectedSchema 'staxrip-linux-runtime-v1'
    $linuxFields = Assert-JsonObjectShape -Element $linux.Root -ExpectedNames @(
        'schema', 'gate', 'result', 'sourceRecordSha256', 'host', 'artifact',
        'selfContainedProof', 'sandbox',
        'filesystemEvidence', 'httpRoutes', 'childObservation', 'runtimeStateWrites',
        'shutdown', 'hostIdentity', 'checks') -Id 'linux-shape'
    Confirm-Check (
        (Get-JsonStringField -Fields $linuxFields -Name 'gate' -Id 'linux-gate') -ceq 'port-linux-sandbox') `
        'linux-gate-value'
    Confirm-Check (
        (Get-JsonStringField -Fields $linuxFields -Name 'result' -Id 'linux-result') -ceq 'pass') `
        'linux-result-value'
    $linuxSourceRecordHash = Get-JsonStringField `
        -Fields $linuxFields `
        -Name 'sourceRecordSha256' `
        -Id 'linux-source-record-hash'
    Confirm-Check (
        (Test-Sha256Text $linuxSourceRecordHash) -and $linuxSourceRecordHash -ceq $sourceRecordHash) `
        'linux-source-record-hash-current'

    $linuxHostFields = Assert-JsonObjectShape -Element $linuxFields['host'] -ExpectedNames @(
        'platformId', 'architectureId', 'privilege', 'dotnetCommand') -Id 'linux-host-shape'
    Confirm-Check (
        (Get-JsonStringField -Fields $linuxHostFields -Name 'platformId' -Id 'linux-host-platform') -ceq 'linux') `
        'linux-host-platform-value'
    Confirm-Check (
        (Get-JsonStringField -Fields $linuxHostFields -Name 'architectureId' -Id 'linux-host-architecture') -ceq 'x64') `
        'linux-host-architecture-value'
    Confirm-Check (
        (Get-JsonStringField -Fields $linuxHostFields -Name 'privilege' -Id 'linux-host-privilege') -ceq 'non-root') `
        'linux-host-privilege-value'
    $linuxDotnetCommand = Get-JsonStringField -Fields $linuxHostFields -Name 'dotnetCommand' -Id 'linux-host-dotnet'
    Confirm-Check (@('absent', 'present') -ccontains $linuxDotnetCommand) 'linux-host-dotnet-value'

    $linuxArtifactFields = Assert-JsonObjectShape -Element $linuxFields['artifact'] -ExpectedNames @(
        'manifest', 'sha256', 'modeSource') -Id 'linux-artifact-shape'
    Confirm-Check (
        (Get-JsonStringField -Fields $linuxArtifactFields -Name 'manifest' -Id 'linux-artifact-manifest') -ceq `
            'CrossPlatform/artifacts/evidence/artifact-linux-x64.tsv') 'linux-artifact-manifest-value'
    $linuxArtifactHash = Get-JsonStringField -Fields $linuxArtifactFields -Name 'sha256' -Id 'linux-artifact-hash'
    Confirm-Check (Test-Sha256Text $linuxArtifactHash) 'linux-artifact-hash-grammar'
    Confirm-Check (
        $linuxArtifactHash -ceq $artifactHash -and
        $linuxArtifactHash -ceq $manifest.Sha256) `
        'linux-artifact-hash-loaded'
    Confirm-Check (
        (Get-JsonStringField -Fields $linuxArtifactFields -Name 'modeSource' -Id 'linux-artifact-mode') -ceq 'wsl:Ubuntu') `
        'linux-artifact-mode-value'

    $proofFields = Assert-JsonObjectShape -Element $linuxFields['selfContainedProof'] -ExpectedNames @(
        'invalidPath', 'invalidDotnetRoot', 'localHostFxr', 'localCoreClr', 'executed') -Id 'linux-proof-shape'
    foreach ($proofName in @('invalidPath', 'invalidDotnetRoot', 'localHostFxr', 'localCoreClr', 'executed')) {
        Confirm-Check (Get-JsonBooleanField -Fields $proofFields -Name $proofName -Id "linux-proof-$proofName") "linux-proof-$proofName-value"
    }

    # These sandbox assertions are deliberately RESTATEMENTS, not independent proofs. Each
    # corresponds to a probe the producer runs inside the unit, and the producer fails the
    # gate at the probe, so no record carrying a failing value can reach this point. That
    # makes each check here unfalsifiable in isolation, which is normally the defect this
    # slice keeps finding; it is acceptable only because a named probe stands behind every
    # one, and the danger is that the arrangement hides a value with no probe at all.
    #
    # That is exactly what happened, and the repair went further than expected. A home
    # property sat here as a literal with nothing behind it. The first fix added a write
    # probe, and execution then showed that probe was itself vacuous: the unprivileged
    # account is denied on the home roots with no sandboxing at all, so the probe returned
    # the same answer whether the property applied or not, and no write target can isolate
    # it from the strict system protection that already covers every path. The field was
    # removed rather than restated, because a value that cannot be checked should not be
    # recorded.
    #
    # The probes behind what remains are, in producer order: the interface count for
    # privateNetwork, a write outside the writable paths for protectSystem, and NoNewPrivs
    # from the process status file for noNewPrivileges. applicationTreeChanged is the one
    # genuinely independent check here, re-derived below from the recorded snapshot bytes
    # rather than trusted. Before adding a field to this block, name a probe that can fail,
    # or do not add the field.
    $sandboxFields = Assert-JsonObjectShape -Element $linuxFields['sandbox'] -ExpectedNames @(
        'privateNetwork', 'protectSystem', 'noNewPrivileges',
        'applicationTreeChanged') -Id 'linux-sandbox-shape'
    Confirm-Check (
        (Get-JsonBooleanField -Fields $sandboxFields -Name 'privateNetwork' -Id 'linux-sandbox-network')) `
        'linux-sandbox-network-value'
    Confirm-Check (
        (Get-JsonStringField -Fields $sandboxFields -Name 'protectSystem' -Id 'linux-sandbox-system') -ceq 'strict') `
        'linux-sandbox-system-value'
    Confirm-Check (
        (Get-JsonBooleanField -Fields $sandboxFields -Name 'noNewPrivileges' -Id 'linux-sandbox-privileges')) `
        'linux-sandbox-privileges-value'
    Confirm-Check (
        -not (Get-JsonBooleanField -Fields $sandboxFields -Name 'applicationTreeChanged' -Id 'linux-sandbox-tree')) `
        'linux-sandbox-tree-value'

    $filesystemFields = Assert-JsonObjectShape -Element $linuxFields['filesystemEvidence'] -ExpectedNames @(
        'applicationBefore', 'applicationAfter', 'applicationSha256', 'stateBefore',
        'stateAfter', 'stateSha256') -Id 'linux-filesystem-shape'
    $expectedFilesystemPaths = [ordered]@{
        applicationBefore = 'CrossPlatform/artifacts/evidence/linux-runtime-app-before.tsv'
        applicationAfter = 'CrossPlatform/artifacts/evidence/linux-runtime-app-after.tsv'
        stateBefore = 'CrossPlatform/artifacts/evidence/linux-runtime-state-before.tsv'
        stateAfter = 'CrossPlatform/artifacts/evidence/linux-runtime-state-after.tsv'
    }
    $filesystemPaths = @{}
    foreach ($fieldName in $expectedFilesystemPaths.Keys) {
        $recordedPath = Get-JsonStringField -Fields $filesystemFields -Name $fieldName -Id "linux-filesystem-$fieldName"
        Confirm-Check ($recordedPath -ceq $expectedFilesystemPaths[$fieldName]) "linux-filesystem-$fieldName-value"
        $filesystemPaths[$fieldName] = Resolve-SafeRelativePath `
            -RelativePath $recordedPath `
            -Root $repositoryRoot `
            -Kind Leaf `
            -Id "linux-filesystem-$fieldName-file"
    }
    $applicationHash = Get-JsonStringField -Fields $filesystemFields -Name 'applicationSha256' -Id 'linux-filesystem-app-hash'
    Confirm-Check (Test-Sha256Text $applicationHash) 'linux-filesystem-app-hash-grammar'
    $stateHash = Get-JsonStringField -Fields $filesystemFields -Name 'stateSha256' -Id 'linux-filesystem-state-hash'
    Confirm-Check (Test-Sha256Text $stateHash) 'linux-filesystem-state-hash-grammar'

    $appBefore = Read-LinuxSnapshot -Path $filesystemPaths['applicationBefore'] -Policy application -Id 'linux-app-before'
    $appAfter = Read-LinuxSnapshot -Path $filesystemPaths['applicationAfter'] -Policy application -Id 'linux-app-after'
    Confirm-Check ($applicationHash -ceq $appBefore.Sha256) 'linux-filesystem-app-hash-loaded'
    Confirm-Check (Test-ByteArraysEqual -Left $appBefore.Bytes -Right $appAfter.Bytes) 'linux-app-snapshot-unchanged'
    Confirm-ApplicationSnapshotMatchesManifest -SnapshotEntries $appBefore.Entries -ManifestEntries $manifest.Entries
    $stateBefore = Read-LinuxSnapshot -Path $filesystemPaths['stateBefore'] -Policy runtime-state -Id 'linux-state-before'
    $stateAfter = Read-LinuxSnapshot -Path $filesystemPaths['stateAfter'] -Policy runtime-state -Id 'linux-state-after'
    Confirm-Check ($stateHash -ceq $stateBefore.Sha256) 'linux-filesystem-state-hash-loaded'
    Confirm-Check (Test-ByteArraysEqual -Left $stateBefore.Bytes -Right $stateAfter.Bytes) 'linux-state-snapshot-unchanged'

    Assert-ExactStringArray -Element $linuxFields['httpRoutes'] -Expected @(
        '/', '/healthz', '/api/v1/capabilities') -Id 'linux-http-routes'
    $childFields = Assert-JsonObjectShape -Element $linuxFields['childObservation'] -ExpectedNames @(
        'samples', 'observed') -Id 'linux-child-shape'
    Confirm-Check (
        (Get-JsonIntegerField -Fields $childFields -Name 'samples' -Id 'linux-child-samples') -eq 200) `
        'linux-child-samples-value'
    Confirm-Check (
        (Get-JsonIntegerField -Fields $childFields -Name 'observed' -Id 'linux-child-observed') -eq 0) `
        'linux-child-observed-value'
    Confirm-Check (
        (Get-JsonIntegerField -Fields $linuxFields -Name 'runtimeStateWrites' -Id 'linux-runtime-writes') -eq 0) `
        'linux-runtime-writes-value'
    $shutdownFields = Assert-JsonObjectShape -Element $linuxFields['shutdown'] -ExpectedNames @(
        'exitCode', 'stoppedMarker', 'portReleased', 'unitCollected', 'cgroupEmpty') -Id 'linux-shutdown-shape'
    Confirm-Check (
        (Get-JsonIntegerField -Fields $shutdownFields -Name 'exitCode' -Id 'linux-shutdown-exit') -eq 0) `
        'linux-shutdown-exit-value'
    foreach ($shutdownName in @('stoppedMarker', 'portReleased', 'unitCollected', 'cgroupEmpty')) {
        Confirm-Check (
            (Get-JsonBooleanField -Fields $shutdownFields -Name $shutdownName -Id "linux-shutdown-$shutdownName")) `
            "linux-shutdown-$shutdownName-value"
    }
    # Host identity is measured by the producer and the host role is DERIVED here from
    # those measurements. The prior design pinned a producer-hardcoded literal
    # ("independentHost": "not-run") to itself, so no execution on any host could ever
    # vary the value and an honest independent-host record would have been rejected
    # (R-S2-040). The rule for this block: accept any well-formed measurement, derive
    # the role, and constrain the DERIVED role only against what the acceptance record
    # claims. Never pin a field that a legitimate run could legitimately vary.
    $hostIdentityFields = Assert-JsonObjectShape -Element $linuxFields['hostIdentity'] -ExpectedNames @(
        'virt', 'container', 'kernelRelease', 'osId', 'osVersionId',
        'machineIdSha256', 'wslInterop') -Id 'linux-host-identity-shape'
    $hostVirt = Get-JsonStringField -Fields $hostIdentityFields -Name 'virt' -Id 'linux-host-virt'
    Confirm-Check ($hostVirt -cmatch '^[a-z0-9-]{1,32}$') 'linux-host-virt-grammar'
    $hostContainer = Get-JsonStringField -Fields $hostIdentityFields -Name 'container' -Id 'linux-host-container'
    Confirm-Check ($hostContainer -cmatch '^[a-z0-9-]{1,32}$') 'linux-host-container-grammar'
    Confirm-Check (
        (Get-JsonStringField -Fields $hostIdentityFields -Name 'kernelRelease' -Id 'linux-host-kernel') -cmatch `
            '^[A-Za-z0-9._+-]{1,64}$') 'linux-host-kernel-grammar'
    Confirm-Check (
        (Get-JsonStringField -Fields $hostIdentityFields -Name 'osId' -Id 'linux-host-os-id') -cmatch `
            '^[a-z0-9._-]{1,32}$') 'linux-host-os-id-grammar'
    Confirm-Check (
        (Get-JsonStringField -Fields $hostIdentityFields -Name 'osVersionId' -Id 'linux-host-os-version') -cmatch `
            '^[A-Za-z0-9._-]{1,32}$') 'linux-host-os-version-grammar'
    Confirm-Check (
        Test-Sha256Text (Get-JsonStringField -Fields $hostIdentityFields -Name 'machineIdSha256' -Id 'linux-host-machine-id')) `
        'linux-host-machine-id-grammar'
    $hostWslInterop = Get-JsonBooleanField -Fields $hostIdentityFields -Name 'wslInterop' -Id 'linux-host-wsl-interop'
    $derivedHostRole = if ($hostVirt -ceq 'wsl' -or $hostWslInterop) { 'wsl' }
        elseif ($hostContainer -cne 'none') { 'container' }
        elseif ($hostVirt -ceq 'none') { 'bare-metal' }
        else { 'vm' }
    # The acceptance record's LNX-019 row is frozen at "blocked": no audited
    # independent-host evidence exists in this set. A bare-metal record in the evidence
    # directory would make that row false, so it must fail the audit loudly and force
    # the acceptance record and this constraint to be updated together, in that order.
    # The forcing direction is deliberate: stronger evidence than the claim is an error
    # in the claim, never something to absorb silently.
    Confirm-Check ($derivedHostRole -cne 'bare-metal') 'linux-host-role-consistent-with-lnx019'
    Confirm-Check (
        (Get-JsonIntegerField -Fields $linuxFields -Name 'checks' -Id 'linux-checks') -gt 0) `
        'linux-checks-value'

    $reportPath = Resolve-SafeRelativePath -RelativePath 'Docs/Verification/SLICE-002/README.md' -Root $repositoryRoot -Kind Leaf -Id 'report-doc'
    $reviewPath = Resolve-SafeRelativePath -RelativePath 'Docs/Review/SLICE-002-Adversarial-Review.md' -Root $repositoryRoot -Kind Leaf -Id 'review-doc'
    $backlogPath = Resolve-SafeRelativePath -RelativePath 'Docs/Review/SLICE-002-Remediation-Backlog.md' -Root $repositoryRoot -Kind Leaf -Id 'backlog-doc'
    $unknownsPath = Resolve-SafeRelativePath -RelativePath 'Docs/Unknowns/Portability-Unknowns.md' -Root $repositoryRoot -Kind Leaf -Id 'unknowns-doc'
    $reportRecord = Read-CanonicalLines -Path $reportPath -AllowedRoot $repositoryRoot -MaximumBytes 4194304
    $reviewRecord = Read-CanonicalLines -Path $reviewPath -AllowedRoot $repositoryRoot -MaximumBytes 4194304
    $backlogRecord = Read-CanonicalLines -Path $backlogPath -AllowedRoot $repositoryRoot -MaximumBytes 4194304
    $unknownsRecord = Read-CanonicalLines -Path $unknownsPath -AllowedRoot $repositoryRoot -MaximumBytes 4194304
    $reportText = $reportRecord.Text
    $reviewText = $reviewRecord.Text
    $backlogText = $backlogRecord.Text
    $unknownsText = $unknownsRecord.Text

    $criterionNames = @('id', 'status', 'evidence', 'host', 'artifact', 'unknown', 'impact', 'approval', 'rollback')
    $expectedCriterionVectors = @(
        @('LNX-001', 'passed', 'port-static+port-restore+port-build', 'windows-x64', 'CrossPlatform/artifacts/evidence/verify-summary.json', 'none', 'additive-only', 'D-041+D-044', 'bounded-revert'),
        @('LNX-002', 'passed', 'port-contract-debug+port-contract-release+port-contract-failure', 'windows-x64', 'CrossPlatform/artifacts/evidence/verify-summary.json', 'none', 'additive-only', 'D-041', 'bounded-revert'),
        @('LNX-003', 'passed', 'port-static', 'repository', 'CrossPlatform/artifacts/evidence/static-gate.json', 'none', 'Source-unchanged', 'D-041', 'bounded-revert'),
        @('LNX-004', 'passed', 'port-restore+port-publish-linux+port-artifact-manifest', 'windows-x64+wsl-Ubuntu-x64', 'CrossPlatform/artifacts/evidence/artifact-linux-x64.tsv', 'none', 'additive-only', 'D-041+D-044', 'bounded-revert'),
        @('LNX-005', 'passed', 'port-linux-sandbox', 'wsl-Ubuntu-x64', 'CrossPlatform/artifacts/evidence/linux-runtime.json', 'none', 'additive-only', 'D-038+D-041', 'bounded-revert'),
        @('LNX-006', 'passed', 'port-http-windows+port-linux-sandbox', 'windows-x64+wsl-Ubuntu-x64', 'CrossPlatform/artifacts/evidence/linux-runtime.json', 'none', 'additive-only', 'D-040+D-041', 'bounded-revert'),
        @('LNX-007', 'passed', 'port-contract-release+port-linux-sandbox', 'windows-x64+wsl-Ubuntu-x64', 'CrossPlatform/artifacts/evidence/linux-runtime.json', 'none', 'additive-only', 'D-040', 'bounded-revert'),
        @('LNX-008', 'passed', 'port-http-windows', 'windows-x64', 'CrossPlatform/artifacts/evidence/http-windows.json', 'none', 'additive-only', 'D-040', 'bounded-revert'),
        @('LNX-009', 'passed', 'port-http-windows', 'windows-x64', 'CrossPlatform/artifacts/evidence/http-windows.json', 'none', 'additive-only', 'D-040', 'bounded-revert'),
        @('LNX-010', 'passed', 'port-http-windows', 'windows-x64', 'CrossPlatform/artifacts/evidence/http-windows.json', 'none', 'additive-only', 'D-040', 'bounded-revert'),
        @('LNX-011', 'passed', 'port-contract-release+port-linux-sandbox', 'windows-x64+wsl-Ubuntu-x64', 'CrossPlatform/artifacts/evidence/linux-runtime.json', 'none', 'additive-only', 'D-039+D-041', 'bounded-revert'),
        @('LNX-012', 'passed', 'port-static+port-linux-sandbox', 'windows-x64+wsl-Ubuntu-x64', 'CrossPlatform/artifacts/evidence/linux-runtime.json', 'none', 'additive-only', 'D-039+D-040', 'bounded-revert'),
        @('LNX-013', 'passed', 'port-linux-sandbox', 'wsl-Ubuntu-x64', 'CrossPlatform/artifacts/evidence/linux-runtime.json', 'none', 'additive-only', 'D-041', 'bounded-revert'),
        @('LNX-014', 'passed', 'port-static+port-linux-sandbox', 'windows-x64+wsl-Ubuntu-x64', 'CrossPlatform/artifacts/evidence/linux-runtime.json', 'none', 'additive-only', 'D-011+D-041', 'bounded-revert'),
        @('LNX-015', 'passed', 'port-linux-sandbox', 'wsl-Ubuntu-x64', 'CrossPlatform/artifacts/evidence/linux-runtime.json', 'none', 'additive-only', 'D-017+D-041', 'bounded-revert'),
        @('LNX-016', 'passed', 'port-static+port-browser', 'windows-x64', 'CrossPlatform/artifacts/evidence/browser.json', 'none', 'additive-only', 'D-040+D-041', 'bounded-revert'),
        @('LNX-017', 'passed', 'port-http-windows', 'windows-x64', 'CrossPlatform/artifacts/evidence/http-windows.json', 'none', 'additive-only', 'D-040', 'bounded-revert'),
        @('LNX-018', 'passed', 'port-verify+port-linux-sandbox', 'windows-x64+wsl-Ubuntu-x64', 'CrossPlatform/artifacts/evidence/verify-summary.json', 'none', 'hang-timeout-only', 'D-015+D-041', 'bounded-revert'),
        @('LNX-019', 'blocked', 'port-linux-sandbox+R-S2-039', 'independent-Ubuntu-isolation-unavailable', 'CrossPlatform/artifacts/evidence/artifact-linux-x64.tsv', 'R-S2-039', 'independent-host-claim-blocked', 'D-038+D-043', 'bounded-revert'),
        @('LNX-020', 'pending', 'port-evidence', 'repository', 'Docs/Review/SLICE-002-Adversarial-Review.md', 'none', 'documentation-only', 'D-043', 'bounded-revert'),
        @('LNX-021', 'passed', 'port-http-windows', 'windows-x64', 'CrossPlatform/artifacts/evidence/http-windows.json', 'none', 'additive-only', 'D-040', 'bounded-revert'),
        @('LNX-022', 'passed', 'port-browser', 'windows-x64', 'CrossPlatform/artifacts/evidence/browser.json', 'none', 'browser-security-verified-under-documented-editor-exclusion', 'D-040+D-043', 'bounded-revert')
    )
    Confirm-Check ($criterionNames.Count -eq 9) 'report-column-contract-count'
    Confirm-Check ($expectedCriterionVectors.Count -eq 22) 'report-vector-contract-count'
    foreach ($expectedCriterionVector in $expectedCriterionVectors) {
        Confirm-Check ($expectedCriterionVector.Count -eq 9) 'report-vector-column-count'
    }
    $reportArtifactPaths = [System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::Ordinal)
    $reportArtifactPaths.Add('CrossPlatform/artifacts/evidence/verify-summary.json', $summary.Path)
    $reportArtifactPaths.Add('CrossPlatform/artifacts/evidence/static-gate.json', $static.Path)
    $reportArtifactPaths.Add('CrossPlatform/artifacts/evidence/artifact-linux-x64.tsv', $manifestPath)
    $reportArtifactPaths.Add('CrossPlatform/artifacts/evidence/linux-runtime.json', $linux.Path)
    $reportArtifactPaths.Add('CrossPlatform/artifacts/evidence/http-windows.json', $http.Path)
    $reportArtifactPaths.Add('CrossPlatform/artifacts/evidence/browser.json', $browser.Path)
    $reportArtifactPaths.Add('Docs/Review/SLICE-002-Adversarial-Review.md', $reviewPath)

    $criterionHeader = '| ID | Status | Evidence | Host | Artifact | Unknown | Impact | Approval | Rollback |'
    $criterionSeparator = '| --- | --- | --- | --- | --- | --- | --- | --- | --- |'
    $headerIndexes = @(for ($lineIndex = 0; $lineIndex -lt $reportRecord.Lines.Count; $lineIndex++) {
            if ($reportRecord.Lines[$lineIndex] -match '^\s*\|\s*ID\s*\|\s*Status\s*\|\s*Evidence\s*\|\s*Host\s*\|\s*Artifact\s*\|\s*Unknown\s*\|\s*Impact\s*\|\s*Approval\s*\|\s*Rollback\s*\|\s*$') {
                $lineIndex
            }
        })
    Confirm-Check ($headerIndexes.Count -eq 1) 'report-table-header-unique'
    $tableStart = $headerIndexes[0]
    Confirm-Check ($reportRecord.Lines[$tableStart] -ceq $criterionHeader) 'report-table-header-exact'
    $tableTerminator = $tableStart + 2 + $expectedCriterionVectors.Count
    Confirm-Check ($tableTerminator -lt $reportRecord.Lines.Count) 'report-table-bounds'
    Confirm-Check ($reportRecord.Lines[$tableStart + 1] -ceq $criterionSeparator) 'report-table-separator'
    Confirm-Check ($reportRecord.Lines[$tableTerminator] -ceq '') 'report-table-blank-terminator'
    $allCriterionIndexes = @(for ($lineIndex = 0; $lineIndex -lt $reportRecord.Lines.Count; $lineIndex++) {
            if ($reportRecord.Lines[$lineIndex] -match '^\s*\|\s*LNX-[0-9]{3}(?:\s*\||\b)') {
                $lineIndex
            }
        })
    Confirm-Check ($allCriterionIndexes.Count -eq $expectedCriterionVectors.Count) 'report-criterion-row-count'
    for ($rowIndex = 0; $rowIndex -lt $expectedCriterionVectors.Count; $rowIndex++) {
        Confirm-Check ($allCriterionIndexes[$rowIndex] -eq ($tableStart + 2 + $rowIndex)) 'report-criterion-row-contiguous'
    }
    $criterionIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $criteria = [System.Collections.Generic.List[object]]::new()
    for ($rowIndex = 0; $rowIndex -lt $expectedCriterionVectors.Count; $rowIndex++) {
        $line = $reportRecord.Lines[$tableStart + 2 + $rowIndex]
        $fields = $line.Split('|', [System.StringSplitOptions]::None)
        Confirm-Check ($fields.Count -eq 11 -and $fields[0] -ceq '' -and $fields[10] -ceq '') 'report-row-field-count'
        $parsed = [ordered]@{}
        for ($fieldIndex = 0; $fieldIndex -lt $criterionNames.Count; $fieldIndex++) {
            $expectedCell = $expectedCriterionVectors[$rowIndex][$fieldIndex]
            Confirm-Check ($expectedCell.Length -gt 0 -and $expectedCell.Length -le 160) 'report-cell-expected-bound'
            Confirm-Check ($fields[$fieldIndex + 1] -ceq " $expectedCell ") 'report-cell-exact'
            # Store the value read from the document, not the literal expected above. These
            # are equal only because the check on the previous line passed, and storing the
            # expectation instead made every later use of $parsed a comparison between two
            # compile-time constants. That is the same defect class removed elsewhere in
            # this file, so it must not be reintroduced by convenience here.
            $parsed[$criterionNames[$fieldIndex]] = $fields[$fieldIndex + 1].Trim()
        }
        Confirm-Check ($criterionIds.Add($parsed['id'])) 'report-criterion-unique'
        Confirm-Check ($reportArtifactPaths.ContainsKey($parsed['artifact'])) 'report-artifact-known'
        Confirm-Check (
            Test-SafeLeaf -Path $reportArtifactPaths[$parsed['artifact']] -AllowedRoot $repositoryRoot) `
            'report-artifact-current-safe'
        $criteria.Add($parsed)
    }
    # The independent-host row stays blocked, but the reason changed and the record must
    # say which. P-007 was an access problem and is resolved: the gate did run on an
    # independent Ubuntu host. What blocks the claim now is R-S2-039, an environment
    # prerequisite, because that host cannot give an unprivileged user unit a private
    # network namespace. Pinning the superseded reason would have preserved a true status
    # attached to a false explanation.
    Confirm-Check ($criteria[18]['id'] -ceq 'LNX-019' -and
        $criteria[18]['status'] -ceq 'blocked' -and
        $criteria[18]['unknown'] -ceq 'R-S2-039' -and
        $criteria[18]['host'] -ceq 'independent-Ubuntu-isolation-unavailable') 'report-lnx019-vector'
    Confirm-Check ($criteria[21]['id'] -ceq 'LNX-022' -and
        $criteria[21]['status'] -ceq 'passed' -and
        $criteria[21]['evidence'] -ceq 'port-browser' -and
        $criteria[21]['unknown'] -ceq 'none') 'report-lnx022-vector'

    # Review closure is verified substantively, not by a pinned version string. The prior
    # check compared one literal ("Version: 0.2 Final ...") against the document, which
    # made a version stamp the sole evidence of review closure: one keystroke on the
    # artifact under audit could turn the slice green while the document body still
    # reported NO-GO, and the pinned constant itself went stale when the document
    # advanced to 0.3. Three properties replace it: the version line must declare Final
    # with this audit's base commit but may carry any version number; the review must
    # contain no live unresolved-verdict language; and every finding in the backlog must
    # be closed. The backlog's status vocabulary treats fixed, resolved, done, and
    # deferred as closed; open, in progress, ready, and blocked as not closed.
    #
    # Honest scope, because the first version of this comment overstated it: the version
    # line and the verdict wording are each still one-line-editable, and only the backlog
    # status check resists a careless edit, since it spans every finding. These checks are
    # tripwires that make silent or premature closure visible in a SHA-bound document.
    # They are not proof that review happened; that authority stays with the human whose
    # edit to this document is the act of attestation.
    Confirm-Check (
        @($reviewRecord.Lines | Where-Object {
                $_ -cmatch ('^Version: [0-9]+\.[0-9]+ Final\. Date: [0-9]{4}-[0-9]{2}-[0-9]{2}\. ' +
                    "Reviewed base: ``$($BaseCommit.Substring(0, 8))``\.$")
            }).Count -eq 1) 'review-version-final'
    $reviewResultStart = -1
    for ($lineIndex = 0; $lineIndex -lt $reviewRecord.Lines.Count; $lineIndex++) {
        if ($reviewRecord.Lines[$lineIndex] -ceq '## Result') { $reviewResultStart = $lineIndex; break }
    }
    Confirm-Check ($reviewResultStart -ge 0) 'review-result-present'
    # Scanned across the WHOLE document, not one section. The first version of this check
    # read only "## Result", and an independent verification found the hole: the
    # document's live verdict lives in its disposition section, so rewriting Result alone
    # made the check pass while the document still declared the slice unaccepted. That is
    # the same false-green class this check exists to prevent, reproduced inside the fix
    # for it. Scoping by section name would also miss any future section.
    #
    # The pattern distinguishes a LIVE verdict from an accurate historical account by
    # grammatical tense, which is a real and stable distinction here: "returned NO-GO" and
    # "the final NO-GO also required" are history and must stay legal, because forcing
    # their deletion would trade a true record for a green check. "remains NO-GO" and
    # "remain pending" assert an unresolved present state and must block closure.
    Confirm-Check (
        @($reviewRecord.Lines | Where-Object {
                $_ -cmatch '(?i)remains?\s+NO-GO' -or $_ -cmatch '(?i)remains?\s+pending' -or
                $_ -cmatch '(?i)remain\s+(?:open|unresolved|outstanding)'
            }).Count -eq 0) 'review-result-closed'
    $backlogStatusLines = @($backlogRecord.Lines | Where-Object { $_ -cmatch '^- \*\*Status:\*\* ' })
    Confirm-Check ($backlogStatusLines.Count -gt 0) 'backlog-status-present'
    Confirm-Check (
        @($backlogStatusLines | Where-Object {
                $_ -cnotmatch '^- \*\*Status:\*\* (fixed|resolved|done|deferred)\b'
            }).Count -eq 0) 'backlog-findings-closed'
    Confirm-Check (@($reviewRecord.Lines | Where-Object { $_ -ceq '## Independent implementation challenge' }).Count -eq 1) 'review-independent-challenge'
    Confirm-Check (@($reviewRecord.Lines | Where-Object { $_ -ceq '## Runtime findings and remediation' }).Count -eq 1) 'review-runtime-remediation'
    Confirm-Check (@($backlogRecord.Lines | Where-Object { $_ -ceq '# SLICE-002 Remediation Backlog' }).Count -eq 1) 'backlog-title'
    Confirm-Check (@($backlogRecord.Lines | Where-Object { $_ -ceq '## Holes and external boundaries' }).Count -eq 1) 'backlog-external-boundary'
    # This previously required the P-007 entry to read exactly "Status: blocked". P-007 was
    # an access problem and it is resolved: the artifact ran on the independent host. Once
    # the entry was corrected to say so, the check could only be satisfied by restoring a
    # false statement to the document. A checker that can only pass while a record lies is
    # worse than no checker, and it is the same pinned-literal class as R-S2-040 appearing
    # in the documentation block.
    #
    # The property actually worth enforcing is not P-007's status. It is that the
    # independent-host row names a live blocker and that the unknowns document mentions
    # whatever blocker it names. That survives the blocker changing identity, which is
    # exactly what happened here, and it fails if the row cites a blocker the unknowns
    # document never mentions.
    #
    # Scope, stated precisely because an earlier version of this comment overstated it:
    # this is a whole-document substring test, not a heading test. The blocker is currently
    # described inside another entry rather than carrying its own heading, so requiring a
    # heading would fail on an accurate document. The weaker property is what is enforced;
    # do not describe it as stronger than it is.
    $p007 = [regex]::Match($unknownsText, '(?ms)^### P-007:.*?(?=^### |\z)')
    Confirm-Check $p007.Success 'unknown-p007-present'
    Confirm-Check (
        $p007.Value -cmatch '(?m)^- \*\*Status:\*\* (?:blocked|resolved|deferred)$') `
        'unknown-p007-status-grammar'
    $lnx019Blocker = $criteria[18]['unknown']
    Confirm-Check (
        $lnx019Blocker -cne 'none' -and
        $unknownsText.Contains($lnx019Blocker, [System.StringComparison]::Ordinal)) `
        'report-lnx019-blocker-documented'

    $privacyRecords = @(
        [pscustomobject]@{ Id = 'privacy-static'; Text = $static.Text },
        [pscustomobject]@{ Id = 'privacy-source'; Text = $sourceManifest.Text },
        [pscustomobject]@{ Id = 'privacy-dependency'; Text = $dependency.Text },
        [pscustomobject]@{ Id = 'privacy-dependency-tsv'; Text = $closure.Text },
        [pscustomobject]@{ Id = 'privacy-dependency-sidecar'; Text = $dependencySidecar.Text },
        [pscustomobject]@{ Id = 'privacy-summary'; Text = $summary.Text },
        [pscustomobject]@{ Id = 'privacy-artifact'; Text = $manifest.Text },
        [pscustomobject]@{ Id = 'privacy-artifact-sidecar'; Text = $manifestSidecar.Text },
        [pscustomobject]@{ Id = 'privacy-http'; Text = $http.Text },
        [pscustomobject]@{ Id = 'privacy-browser'; Text = $browser.Text },
        [pscustomobject]@{ Id = 'privacy-linux'; Text = $linux.Text },
        [pscustomobject]@{ Id = 'privacy-linux-app-before'; Text = $appBefore.Text },
        [pscustomobject]@{ Id = 'privacy-linux-app-after'; Text = $appAfter.Text },
        [pscustomobject]@{ Id = 'privacy-linux-state-before'; Text = $stateBefore.Text },
        [pscustomobject]@{ Id = 'privacy-linux-state-after'; Text = $stateAfter.Text },
        [pscustomobject]@{ Id = 'privacy-report'; Text = $reportText },
        [pscustomobject]@{ Id = 'privacy-review'; Text = $reviewText },
        [pscustomobject]@{ Id = 'privacy-backlog'; Text = $backlogText },
        [pscustomobject]@{ Id = 'privacy-unknowns'; Text = $unknownsText }
    )
    foreach ($privacyRecord in $privacyRecords) {
        Confirm-NoPrivateEvidenceText -Text $privacyRecord.Text -Id $privacyRecord.Id
    }

    $script:AuditHashes = [System.Collections.Generic.List[object]]::new()
    $script:AuditHashPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $auditInputs = [System.Collections.Generic.List[object]]::new()
    foreach ($record in @(
            [pscustomobject]@{ Path = $static.Path; Root = $evidenceRoot; Sha256 = $static.Sha256 },
            [pscustomobject]@{ Path = $sourceManifestPath; Root = $evidenceRoot; Sha256 = $sourceManifest.Sha256 },
            [pscustomobject]@{ Path = $dependency.Path; Root = $evidenceRoot; Sha256 = $dependency.Sha256 },
            [pscustomobject]@{ Path = $dependencySidecarPath; Root = $evidenceRoot; Sha256 = $dependencySidecar.Sha256 },
            [pscustomobject]@{ Path = $closurePath; Root = $evidenceRoot; Sha256 = $closure.Sha256 },
            [pscustomobject]@{ Path = $summary.Path; Root = $evidenceRoot; Sha256 = $summary.Sha256 },
            [pscustomobject]@{ Path = $manifestPath; Root = $evidenceRoot; Sha256 = $manifest.Sha256 },
            [pscustomobject]@{ Path = $manifestSidecarPath; Root = $evidenceRoot; Sha256 = $manifestSidecar.Sha256 },
            [pscustomobject]@{ Path = $http.Path; Root = $evidenceRoot; Sha256 = $http.Sha256 },
            [pscustomobject]@{ Path = $browser.Path; Root = $evidenceRoot; Sha256 = $browser.Sha256 },
            [pscustomobject]@{ Path = $linux.Path; Root = $evidenceRoot; Sha256 = $linux.Sha256 },
            [pscustomobject]@{ Path = $filesystemPaths['applicationBefore']; Root = $evidenceRoot; Sha256 = $appBefore.Sha256 },
            [pscustomobject]@{ Path = $filesystemPaths['applicationAfter']; Root = $evidenceRoot; Sha256 = $appAfter.Sha256 },
            [pscustomobject]@{ Path = $filesystemPaths['stateBefore']; Root = $evidenceRoot; Sha256 = $stateBefore.Sha256 },
            [pscustomobject]@{ Path = $filesystemPaths['stateAfter']; Root = $evidenceRoot; Sha256 = $stateAfter.Sha256 },
            [pscustomobject]@{ Path = $reportPath; Root = $repositoryRoot; Sha256 = $reportRecord.Sha256 },
            [pscustomobject]@{ Path = $reviewPath; Root = $repositoryRoot; Sha256 = $reviewRecord.Sha256 },
            [pscustomobject]@{ Path = $backlogPath; Root = $repositoryRoot; Sha256 = $backlogRecord.Sha256 },
            [pscustomobject]@{ Path = $unknownsPath; Root = $repositoryRoot; Sha256 = $unknownsRecord.Sha256 })) {
        $auditInputs.Add($record)
    }
    foreach ($inputRecord in $dependencyInputRecords) {
        $auditInputs.Add([pscustomobject]@{
                Path = $inputRecord.Path
                Root = $crossPlatformRoot
                Sha256 = $inputRecord.Sha256
            })
    }
    foreach ($assetEntry in $assetMap.GetEnumerator()) {
        $auditInputs.Add([pscustomobject]@{
                Path = $assetEntry.Value.Path
                Root = $artifactsRoot
                Sha256 = $assetEntry.Value.Sha256
            })
    }
    $auditInputs.Add([pscustomobject]@{
            Path = $windowsApphostPath
            Root = $artifactsRoot
            Sha256 = $windowsApphostHash
        })
    foreach ($managedSetInput in $managedSetInputs) {
        $auditInputs.Add([pscustomobject]@{
                Path = $managedSetInput.Path
                Root = $artifactsRoot
                Sha256 = $managedSetInput.Sha256
            })
    }
    foreach ($auditInput in $auditInputs) {
        Add-AuditHash `
            -Path $auditInput.Path `
            -AllowedRoot $auditInput.Root `
            -ExpectedSha256 $auditInput.Sha256
    }

    $auditHashArray = [object[]]$script:AuditHashes.ToArray()
    for ($index = 1; $index -lt $auditHashArray.Count; $index++) {
        $candidate = $auditHashArray[$index]
        $position = $index - 1
        while ($position -ge 0 -and
            [System.StringComparer]::Ordinal.Compare([string]$auditHashArray[$position].path, [string]$candidate.path) -gt 0) {
            $auditHashArray[$position + 1] = $auditHashArray[$position]
            $position--
        }
        $auditHashArray[$position + 1] = $candidate
    }

    Confirm-Check (Test-EvidencePublicationAuthority) 'prior-evidence-failure-authority'
    Confirm-Check (Remove-SafeFixedLeaf -Path $failurePacketPath -AllowedRoot $failureRoot) 'prior-evidence-failure-cleared'
    Confirm-Check (Test-EvidencePublicationAuthority) 'prior-evidence-failure-authority-current'
    Confirm-Check (Test-FailureDirectoryEmpty) 'failure-directory-clean'
    foreach ($auditInput in $auditInputs) {
        Confirm-Check (
            (Get-SafeSha256 -Path $auditInput.Path -AllowedRoot $auditInput.Root) -ceq $auditInput.Sha256) `
            'audit-hash-final-current'
    }
    $finalHead = (Invoke-Git @('rev-parse', '--verify', 'HEAD')).Trim()
    Confirm-Check ($finalHead -cmatch '^[0-9a-f]{40}$') 'final-head-grammar'
    Confirm-Check ($finalHead -ceq $currentHead) 'final-head-unchanged'
    $finalScopeSnapshot = Get-GitScopeSnapshot
    Confirm-Check (
        (Test-GitScopeSnapshotsEqual -Left $finalScopeSnapshot -Right $scopeSnapshot)) `
        'final-scope-unchanged'
    Confirm-Check (
        (Test-GitScopeSnapshotsEqual -Left $finalScopeSnapshot -Right $recordedScopeSnapshot)) `
        'final-scope-record-exact'

    $script:CurrentCheck = 'prepublication-closeout'
    Assert-CloseoutCondition (Test-EvidencePublicationAuthority) 'prepublication-authority-current'
    Assert-DependencyClosureCurrent -Packages $packages -ExpectedLines $closure.Lines
    Assert-ArchiveBindingsCurrent -Packages $packages
    Assert-ArtifactTreeCurrent -PublishedRoot $publishedPath -ExpectedEntries $manifest.Entries
    Assert-AuditInputsCurrent -AuditInputs $auditInputs
    Assert-HeadScopeFailureCurrent `
        -ExpectedHead $currentHead `
        -ExpectedScope $scopeSnapshot `
        -RecordedScope $recordedScopeSnapshot

    $primaryChecks = $script:Checks
    $prepublicationCloseoutChecks = $script:CloseoutChecks
    $expectedPostpublicationCloseoutChecks = $prepublicationCloseoutChecks + 7
    $expectedCloseoutChecks = $prepublicationCloseoutChecks + $expectedPostpublicationCloseoutChecks
    $finalChecks = $primaryChecks + $expectedCloseoutChecks
    $auditRecord = [ordered]@{
        schema = 'staxrip-evidence-audit-v1'
        gate = $gateId
        result = 'pass'
        base = $BaseCommit
        head = $currentHead
        scope = [ordered]@{
            schema = $scopeSnapshot.Schema
            sha256 = $scopeSnapshot.Digest
            index = [ordered]@{
                sha256 = $scopeSnapshot.IndexDigest
                count = $scopeSnapshot.IndexEntries.Count
                entries = $scopeSnapshot.IndexEntries
            }
            status = [ordered]@{
                sha256 = $scopeSnapshot.StatusDigest
                count = $scopeSnapshot.StatusEntries.Count
                entries = $scopeSnapshot.StatusEntries
            }
            counts = $scopeSnapshot.Counts
            entries = $scopeSnapshot.Entries
        }
        criteria = [object[]]$criteria.ToArray()
        records = [ordered]@{
            source = 'CrossPlatform/artifacts/evidence/static-gate.json'
            dependency = 'CrossPlatform/artifacts/evidence/dependency-closure.json'
            build = 'CrossPlatform/artifacts/evidence/verify-summary.json'
            http = 'CrossPlatform/artifacts/evidence/http-windows.json'
            browser = 'CrossPlatform/artifacts/evidence/browser.json'
            linux = 'CrossPlatform/artifacts/evidence/linux-runtime.json'
            artifact = 'CrossPlatform/artifacts/evidence/artifact-linux-x64.tsv'
        }
        hashes = $auditHashArray
        independent_host = 'blocked:P-007'
        check_breakdown = [ordered]@{
            primary = $primaryChecks
            closeout = $expectedCloseoutChecks
        }
        checks = $finalChecks
    }
    $script:CurrentCheck = 'audit-write'
    Write-SafeUtf8File `
        -Path $auditPath `
        -AllowedRoot $evidenceRoot `
        -Content (ConvertTo-CanonicalJson -InputObject $auditRecord -Depth 16)
    $auditHash = Get-SafeSha256 -Path $auditPath -AllowedRoot $evidenceRoot
    $sidecarStagePath = New-AuditSidecarStage -AuditHash $auditHash
    $publishedAudit = Read-SafeTextRecord `
        -Path $auditPath `
        -AllowedRoot $evidenceRoot `
        -MaximumBytes 1048576 `
        -CanonicalLines
    Assert-CloseoutCondition ($publishedAudit.Sha256 -ceq $auditHash) 'published-audit-loaded-current'

    $script:CurrentCheck = 'postaudit-closeout'
    Assert-CloseoutCondition (Test-EvidencePublicationAuthority) 'postaudit-authority-current'
    Assert-DependencyClosureCurrent -Packages $packages -ExpectedLines $closure.Lines
    Assert-ArchiveBindingsCurrent -Packages $packages
    Assert-ArtifactTreeCurrent -PublishedRoot $publishedPath -ExpectedEntries $manifest.Entries
    Assert-AuditInputsCurrent -AuditInputs $auditInputs
    Assert-HeadScopeFailureCurrent `
        -ExpectedHead $currentHead `
        -ExpectedScope $scopeSnapshot `
        -RecordedScope $recordedScopeSnapshot
    Assert-CloseoutCondition (
        (Get-SafeSha256 -Path $auditPath -AllowedRoot $evidenceRoot) -ceq $auditHash) `
        'published-audit-final-current'
    Assert-CloseoutCondition (Test-EvidencePublicationAuthority) 'sidecar-commit-authority-current'
    Assert-CloseoutCondition (
        (Test-SafeLeaf -Path $sidecarStagePath -AllowedRoot $evidenceRoot)) `
        'sidecar-stage-final-safe'
    Assert-CloseoutCondition (
        (Get-SafeSha256 -Path $sidecarStagePath -AllowedRoot $evidenceRoot) -ceq `
            (Get-BytesSha256 ([System.Text.Encoding]::ASCII.GetBytes("$auditHash  evidence-audit.json`n")))) `
        'sidecar-stage-final-current'
    Assert-CloseoutCondition (
        (Test-SafeLeaf -Path $auditSidecarPath -AllowedRoot $evidenceRoot -AllowMissing) -and
        -not [System.IO.File]::Exists($auditSidecarPath) -and
        -not [System.IO.Directory]::Exists($auditSidecarPath)) `
        'sidecar-target-final-missing'
    $script:CurrentCheck = 'sidecar-commit'
    Commit-AuditSidecarStage -StagePath $sidecarStagePath
    Assert-CloseoutCondition (
        (Test-SafeLeaf -Path $auditSidecarPath -AllowedRoot $evidenceRoot) -and
        (Get-SafeSha256 -Path $auditSidecarPath -AllowedRoot $evidenceRoot) -ceq
            (Get-BytesSha256 ([System.Text.Encoding]::ASCII.GetBytes("$auditHash  evidence-audit.json`n")))) `
        'committed-audit-sidecar-current'
    if ($script:CloseoutChecks -ne $expectedCloseoutChecks) {
        throw [System.IO.InvalidDataException]::new('Closeout assertion count differs from the committed audit contract.')
    }
    if (-not (Exit-EvidenceLease)) {
        throw [System.IO.IOException]::new('The shared evidence writer lease could not be released safely.')
    }
    $timer.Stop()
    try {
        [Console]::Out.WriteLine(
            "PASS $gateId checks=$finalChecks elapsed_ms=$($timer.ElapsedMilliseconds) evidence=CrossPlatform/artifacts/evidence/evidence-audit.json")
    }
    catch {
    }
    exit 0
}
catch {
    Stop-Gate `
        -Message "Unexpected evidence gate error at $script:CurrentCheck." `
        -Output "$($_.Exception.GetType().Name): $($_.Exception.Message)"
}
finally {
    foreach ($document in $script:JsonDocuments) {
        try {
            $document.Dispose()
        }
        catch {
        }
    }
    if ($null -ne $script:SidecarStagePath -and
        (Test-EvidencePublicationAuthority) -and
        (Test-SafeLeaf -Path $script:SidecarStagePath -AllowedRoot $evidenceRoot)) {
        try {
            if (Test-EvidencePublicationAuthority) {
                [System.IO.File]::Delete($script:SidecarStagePath)
                if ((Test-EvidencePublicationAuthority) -and
                    -not [System.IO.File]::Exists($script:SidecarStagePath) -and
                    -not [System.IO.Directory]::Exists($script:SidecarStagePath)) {
                    $script:SidecarStagePath = $null
                }
            }
        }
        catch { }
    }
    if ($script:EvidenceLeaseAcquired) {
        try { [void](Exit-EvidenceLease) } catch { }
    }
    elseif ($null -ne $script:EvidenceLeaseStream) {
        try { $script:EvidenceLeaseStream.Dispose() } catch { }
        $script:EvidenceLeaseStream = $null
    }
}
