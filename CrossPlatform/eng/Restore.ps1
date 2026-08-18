[CmdletBinding()]
param(
    [switch]$Initial,
    [ValidateRange(30, 1800)]
    [int]$TimeoutSeconds = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gateId = if ($Initial) { 'port-restore-initial' } else { 'port-restore' }
$timer = [System.Diagnostics.Stopwatch]::StartNew()
$script:Stopping = $false
$script:StopExitCode = 1
$crossPlatformRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $crossPlatformRoot '..'))
$artifactsRoot = Join-Path $crossPlatformRoot 'artifacts'
$evidenceRoot = Join-Path $artifactsRoot 'evidence'
$failureRoot = Join-Path $artifactsRoot 'failures'
$logRoot = Join-Path $artifactsRoot 'logs'
$auditPath = Join-Path $evidenceRoot 'evidence-audit.json'
$auditSidecarPath = Join-Path $evidenceRoot 'evidence-audit.json.sha256'
$evidenceLeasePath = Join-Path $evidenceRoot '.evidence-writer.lock'
$configPath = Join-Path $crossPlatformRoot 'NuGet.config'
$globalJsonPath = Join-Path $crossPlatformRoot 'global.json'
$centralPropsPath = Join-Path $crossPlatformRoot 'Directory.Build.props'
$solutionPath = Join-Path $crossPlatformRoot 'StaxRip.CrossPlatform.slnx'
$serverProjectPath = Join-Path $crossPlatformRoot 'src\StaxRip.Server\StaxRip.Server.csproj'
$packagesRoot = Join-Path $artifactsRoot 'nuget'
$allowedSource = 'https://api.nuget.org/v3/index.json'
$microsoftAuthorFingerprint = '566A31882BE208BE4422F7CFD66ED09F5D4524A5994F50CCC8B05EC0528C1353'
$script:EvidenceLeaseAcquired = $false
$script:EvidenceLeaseValidated = $false
$script:EvidencePassPairInvalidated = $false
$script:EvidenceLeaseNonce = $null
$script:RepositoryHead = 'unknown'

function Test-PathBelow {
    param(
        [Parameter(Mandatory)] [string]$Candidate,
        [Parameter(Mandatory)] [string]$Parent
    )

    try {
        $candidatePath = [System.IO.Path]::GetFullPath($Candidate)
        $parentPath = [System.IO.Path]::GetFullPath($Parent)
        $prefix = $parentPath.TrimEnd(
            [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)) +
            [System.IO.Path]::DirectorySeparatorChar
        $comparison = if ($IsWindows) {
            [System.StringComparison]::OrdinalIgnoreCase
        }
        else {
            [System.StringComparison]::Ordinal
        }
        return $candidatePath.StartsWith($prefix, $comparison)
    }
    catch {
        return $false
    }
}

function Test-SafeExistingLeaf {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$AllowedRoot
    )

    try {
        $target = [System.IO.Path]::GetFullPath($Path)
        $root = [System.IO.Path]::GetFullPath($AllowedRoot)
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

function Test-SafeWritableArtifactLeaf {
    param([Parameter(Mandatory)] [string]$Path)

    try {
        $target = [System.IO.Path]::GetFullPath($Path)
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

function Write-Utf8File {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Content
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-SafeWritableArtifactLeaf -Path $fullPath)) {
        throw [System.IO.IOException]::new('Artifact output is not a safe writable regular leaf.')
    }

    $parent = Split-Path -Parent $fullPath
    $temporaryPath = Join-Path $parent ('.' + [System.IO.Path]::GetFileName($fullPath) + '.' + [System.Guid]::NewGuid().ToString('N') + '.tmp')
    $normalizedContent = $Content.Replace("`r`n", "`n")
    if ($normalizedContent.Contains("`r", [System.StringComparison]::Ordinal)) {
        throw [System.IO.InvalidDataException]::new('Artifact output contains a bare carriage return.')
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
        if (-not (Test-SafeWritableArtifactLeaf -Path $fullPath)) {
            throw [System.IO.IOException]::new('Artifact output did not remain a safe writable regular leaf.')
        }
        [System.IO.File]::Move($temporaryPath, $fullPath, $true)
    }
    finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
        try {
            if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
                $temporaryItem = Get-Item -LiteralPath $temporaryPath -Force
                if (($temporaryItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
                    [System.IO.File]::Delete($temporaryPath)
                }
            }
        }
        catch {
            # Temp cleanup must not replace the primary gate result.
        }
    }
}

function Normalize-GeneratedLockFile {
    param([Parameter(Mandatory)] [string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-SafeExistingLeaf -Path $fullPath -AllowedRoot $crossPlatformRoot)) {
        throw [System.IO.IOException]::new('Generated lock file is not a safe regular leaf.')
    }

    $content = [System.IO.File]::ReadAllText($fullPath, [System.Text.UTF8Encoding]::new($false, $true))
    $normalizedContent = $content.Replace("`r`n", "`n")
    if ($normalizedContent.Contains("`r", [System.StringComparison]::Ordinal)) {
        throw [System.IO.InvalidDataException]::new('Generated lock file contains a bare carriage return.')
    }
    $normalizedContent = $normalizedContent.TrimEnd([char]10) + "`n"
    if ($content -ceq $normalizedContent) {
        return
    }

    $parent = Split-Path -Parent $fullPath
    $temporaryPath = Join-Path $parent ('.' + [System.IO.Path]::GetFileName($fullPath) + '.' + [System.Guid]::NewGuid().ToString('N') + '.tmp')
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
        if (-not (Test-SafeExistingLeaf -Path $fullPath -AllowedRoot $crossPlatformRoot)) {
            throw [System.IO.IOException]::new('Generated lock file did not remain a safe regular leaf.')
        }
        [System.IO.File]::Move($temporaryPath, $fullPath, $true)
    }
    finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
        try {
            if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
                $temporaryItem = Get-Item -LiteralPath $temporaryPath -Force
                if (($temporaryItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
                    [System.IO.File]::Delete($temporaryPath)
                }
            }
        }
        catch {
            # Temp cleanup must not replace the primary gate result.
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

function Get-Sha256 {
    param([Parameter(Mandatory)] [string]$Path)

    if (-not (Test-SafeExistingLeaf -Path $Path -AllowedRoot $crossPlatformRoot)) {
        Stop-Gate -Message 'A hash input is missing, case-mismatched, or resolves through a reparse point.'
    }
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $hash = [System.Security.Cryptography.SHA256]::HashData($stream)
        return [System.Convert]::ToHexString($hash).ToLowerInvariant()
    }
    finally {
        $stream.Dispose()
    }
}

function Get-Sha512Base64 {
    param([Parameter(Mandatory)] [string]$Path)

    if (-not (Test-SafeExistingLeaf -Path $Path -AllowedRoot $crossPlatformRoot)) {
        Stop-Gate -Message 'An archive hash input is missing, case-mismatched, or resolves through a reparse point.'
    }
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $hash = [System.Security.Cryptography.SHA512]::HashData($stream)
        return [System.Convert]::ToBase64String($hash)
    }
    finally {
        $stream.Dispose()
    }
}

function Assert-CanonicalArchiveEntryPath {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [bool]$IsDirectory,
        [Parameter(Mandatory)] [string]$PackageKey
    )

    if ([string]::IsNullOrEmpty($Path) -or
        $Path.Length -gt 4096 -or
        $Path -match '[^\x20-\x7e]' -or
        $Path.Contains('\', [System.StringComparison]::Ordinal) -or
        $Path.StartsWith('/', [System.StringComparison]::Ordinal) -or
        $Path.Contains('//', [System.StringComparison]::Ordinal) -or
        ($IsDirectory -and -not $Path.EndsWith('/', [System.StringComparison]::Ordinal)) -or
        (-not $IsDirectory -and $Path.EndsWith('/', [System.StringComparison]::Ordinal))) {
        Stop-Gate -Message "Package $PackageKey has a noncanonical archive entry path."
    }

    $canonical = if ($IsDirectory) { $Path.Substring(0, $Path.Length - 1) } else { $Path }
    if ([string]::IsNullOrEmpty($canonical)) {
        Stop-Gate -Message "Package $PackageKey has an empty archive entry path."
    }
    $segments = $canonical.Split('/')
    if ($segments.Count -gt 256) {
        Stop-Gate -Message "Package $PackageKey has too many archive path components."
    }
    foreach ($segment in $segments) {
        if ([string]::IsNullOrEmpty($segment) -or
            $segment.Length -gt 255 -or
            $segment -in @('.', '..') -or
            $segment.IndexOfAny([char[]]'<>:"|?*') -ge 0 -or
            $segment.EndsWith(' ', [System.StringComparison]::Ordinal) -or
            $segment.EndsWith('.', [System.StringComparison]::Ordinal) -or
            $segment -match '^(?i:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?$') {
            Stop-Gate -Message "Package $PackageKey has an unsafe archive entry segment."
        }
    }
}

function Get-PackageDiskInventory {
    param(
        [Parameter(Mandatory)] [string]$PackageKey,
        [Parameter(Mandatory)] [string]$PackageDirectory
    )

    $files = [System.Collections.Generic.Dictionary[string,object]]::new([System.StringComparer]::Ordinal)
    [long]$totalBytes = 0
    foreach ($file in @(Get-ChildItem -LiteralPath $PackageDirectory -Recurse -Force)) {
        if (($file.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            Stop-Gate -Message "Package $PackageKey contains an unsafe extracted path."
        }
        if ($file.PSIsContainer) {
            continue
        }
        if (-not (Test-SafeExistingLeaf -Path $file.FullName -AllowedRoot $packagesRoot)) {
            Stop-Gate -Message "Package $PackageKey contains an unsafe extracted file."
        }
        $relativeFile = [System.IO.Path]::GetRelativePath($PackageDirectory, $file.FullName).Replace('\', '/')
        $segments = $relativeFile.Split('/')
        if ($relativeFile.Length -gt 4096 -or $segments.Count -gt 256 -or
            $relativeFile -match '[^\x20-\x7e]' -or $relativeFile.Contains('\') -or
            ($segments | Where-Object {
                    $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' -or $_.Length -gt 255
                } | Select-Object -First 1)) {
            Stop-Gate -Message "Package $PackageKey contains a path that cannot be represented canonically."
        }
        if ($file.Length -lt 0 -or $file.Length -gt 1073741824) {
            Stop-Gate -Message "Package $PackageKey has an extracted file outside the bounded size limit."
        }
        $totalBytes += [long]$file.Length
        if ($files.Count -ge 10000 -or $totalBytes -gt 2147483648) {
            Stop-Gate -Message "Package $PackageKey exceeds the bounded extracted inventory limits."
        }
        $fileLength = [long]$file.Length
        $fileSha256 = Get-Sha256 $file.FullName
        $fileAfter = Get-Item -LiteralPath $file.FullName -Force
        if ([long]$fileAfter.Length -ne $fileLength) {
            Stop-Gate -Message "Package $PackageKey contains a file that changed during inventory."
        }
        if (-not $files.TryAdd($relativeFile, [pscustomobject]@{
                    Length = $fileLength
                    Sha256 = $fileSha256
                })) {
            Stop-Gate -Message "Package $PackageKey has duplicate extracted relative paths."
        }
    }

    $relativePaths = [string[]]$files.Keys
    [System.Array]::Sort($relativePaths, [System.StringComparer]::Ordinal)
    $inventoryHash = [System.Security.Cryptography.IncrementalHash]::CreateHash(
        [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    try {
        $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
        foreach ($relativePath in $relativePaths) {
            $fileRecord = $files[$relativePath]
            $rowBytes = $utf8.GetBytes(
                "$relativePath`t$($fileRecord.Length)`t$($fileRecord.Sha256)`n")
            $inventoryHash.AppendData($rowBytes)
        }
        $inventorySha256 = [System.Convert]::ToHexString(
            $inventoryHash.GetHashAndReset()).ToLowerInvariant()
    }
    finally {
        $inventoryHash.Dispose()
    }
    return [pscustomobject]@{
        Files = $files
        FileCount = $files.Count
        TotalBytes = $totalBytes
        InventorySha256 = $inventorySha256
    }
}

function Confirm-SignedArchiveExtractionBinding {
    param(
        [Parameter(Mandatory)] [string]$PackageKey,
        [Parameter(Mandatory)] [string]$PackageId,
        [Parameter(Mandatory)] [string]$ArchivePath,
        [Parameter(Mandatory)] [string]$ArchiveName,
        [Parameter(Mandatory)] [string]$PackageDirectory,
        [Parameter(Mandatory)] [System.Collections.Generic.Dictionary[string,object]]$DiskFiles
    )

    $sha512SidecarName = "$ArchiveName.sha512"
    $sha512SidecarPath = Join-Path $PackageDirectory $sha512SidecarName
    if (-not (Test-SafeExistingLeaf -Path $sha512SidecarPath -AllowedRoot $packagesRoot)) {
        Stop-Gate -Message "The raw archive SHA-512 sidecar is missing or unsafe for $PackageKey."
    }
    $sidecarStream = $null
    try {
        $sidecarStream = [System.IO.File]::Open(
            $sha512SidecarPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::Read)
        if ($sidecarStream.Length -ne 88) {
            Stop-Gate -Message "The raw archive SHA-512 sidecar has an invalid byte length for $PackageKey."
        }
        $sidecarBytes = [byte[]]::new(88)
        $sidecarOffset = 0
        while ($sidecarOffset -lt $sidecarBytes.Length) {
            $readCount = $sidecarStream.Read(
                $sidecarBytes,
                $sidecarOffset,
                $sidecarBytes.Length - $sidecarOffset)
            if ($readCount -eq 0) {
                Stop-Gate -Message "The raw archive SHA-512 sidecar ended early for $PackageKey."
            }
            $sidecarOffset += $readCount
        }
        if ($sidecarStream.ReadByte() -ne -1 -or $sidecarStream.Length -ne 88) {
            Stop-Gate -Message "The raw archive SHA-512 sidecar changed during its bounded read for $PackageKey."
        }
    }
    finally {
        if ($null -ne $sidecarStream) {
            $sidecarStream.Dispose()
        }
    }
    $recordedArchiveSha512 = [System.Text.Encoding]::ASCII.GetString($sidecarBytes)
    if ($recordedArchiveSha512 -notmatch '^[A-Za-z0-9+/]{86}==$') {
        Stop-Gate -Message "The raw archive SHA-512 sidecar has an invalid shape for $PackageKey."
    }
    $archiveSha512 = Get-Sha512Base64 $ArchivePath
    if ($archiveSha512 -cne $recordedArchiveSha512) {
        Stop-Gate -Message "The retained archive bytes do not match the NuGet SHA-512 sidecar for $PackageKey."
    }

    $allowedDiskOnly = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($allowed in @('.nupkg.metadata', $ArchiveName, $sha512SidecarName)) {
        [void]$allowedDiskOnly.Add($allowed)
    }
    foreach ($requiredDiskOnly in $allowedDiskOnly) {
        if (-not $DiskFiles.ContainsKey($requiredDiskOnly)) {
            Stop-Gate -Message "The extracted package lacks a required NuGet-owned archive sidecar for $PackageKey."
        }
    }

    $seenArchivePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $seenArchivePathsIgnoreCase = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $matchedDiskPayloads = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $archiveOnlyMetadataPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $archiveTotalEntryCount = 0
    $archiveEntryCount = 0
    $archivePayloadCount = 0
    $archiveNuspecCount = 0
    [long]$archiveUncompressedBytes = 0
    $archive = $null
    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
        foreach ($entry in $archive.Entries) {
            $archiveTotalEntryCount++
            if ($archiveTotalEntryCount -gt 10000) {
                Stop-Gate -Message "Package $PackageKey exceeds the bounded total ZIP entry count."
            }
            $entryPath = [string]$entry.FullName
            $isDirectory = [string]::IsNullOrEmpty($entry.Name)
            Assert-CanonicalArchiveEntryPath -Path $entryPath -IsDirectory $isDirectory -PackageKey $PackageKey
            if (-not $seenArchivePaths.Add($entryPath) -or -not $seenArchivePathsIgnoreCase.Add($entryPath)) {
                Stop-Gate -Message "Package $PackageKey has duplicate or case-colliding archive entry paths."
            }

            $externalAttributes = [System.BitConverter]::ToUInt32(
                [System.BitConverter]::GetBytes([int]$entry.ExternalAttributes), 0)
            $unixFileType = (($externalAttributes -shr 16) -band 0xf000)
            if ($isDirectory) {
                if ($unixFileType -notin @(0, 0x4000)) {
                    Stop-Gate -Message "Package $PackageKey contains a non-directory archive entry marked as a directory."
                }
                continue
            }
            if ($unixFileType -notin @(0, 0x8000)) {
                Stop-Gate -Message "Package $PackageKey contains a nonregular archive entry."
            }

            $archiveEntryCount++
            if ($archiveEntryCount -gt 10000 -or $entry.Length -lt 0 -or $entry.Length -gt 1073741824) {
                Stop-Gate -Message "Package $PackageKey exceeds the bounded archive entry limits."
            }
            $archiveUncompressedBytes += $entry.Length
            if ($archiveUncompressedBytes -gt 2147483648) {
                Stop-Gate -Message "Package $PackageKey exceeds the bounded uncompressed archive size."
            }

            $isArchiveOnlyMetadata = $entryPath -ceq '_rels/.rels' -or
                $entryPath -ceq '[Content_Types].xml' -or
                $entryPath -cmatch '^package/services/metadata/core-properties/[0-9a-f]{32}\.psmdcp$'
            if ($isArchiveOnlyMetadata) {
                [void]$archiveOnlyMetadataPaths.Add($entryPath)
                continue
            }

            if ($entryPath.EndsWith('.nuspec', [System.StringComparison]::OrdinalIgnoreCase)) {
                if ($entryPath -cne "$PackageId.nuspec") {
                    Stop-Gate -Message "Package $PackageKey contains an extra or case-mismatched nuspec entry."
                }
                $archiveNuspecCount++
            }
            $diskPath = if ($entryPath -ceq "$PackageId.nuspec") {
                "$($PackageId.ToLowerInvariant()).nuspec"
            }
            else {
                $entryPath
            }
            if ($allowedDiskOnly.Contains($diskPath) -or
                -not $DiskFiles.ContainsKey($diskPath) -or
                -not $matchedDiskPayloads.Add($diskPath)) {
                Stop-Gate -Message "Package $PackageKey archive payload does not map one-to-one to the extracted cache."
            }

            $diskFile = $DiskFiles[$diskPath]
            if ([long]$diskFile.Length -ne [long]$entry.Length) {
                Stop-Gate -Message "Package $PackageKey archive and extracted lengths differ."
            }
            $entryStream = $entry.Open()
            try {
                $entryHash = [System.Convert]::ToHexString(
                    [System.Security.Cryptography.SHA256]::HashData($entryStream)).ToLowerInvariant()
            }
            finally {
                $entryStream.Dispose()
            }
            if ($entryHash -cne [string]$diskFile.Sha256) {
                Stop-Gate -Message "Package $PackageKey archive and extracted hashes differ."
            }
            $archivePayloadCount++
        }
    }
    catch {
        if ($_.Exception.Message -like 'CHECK:*') { throw }
        Stop-Gate -Message "The retained archive could not be bound to the extracted cache for $PackageKey."
    }
    finally {
        if ($null -ne $archive) {
            $archive.Dispose()
        }
    }

    $expectedPayloadCount = $DiskFiles.Count - $allowedDiskOnly.Count
    $corePropertyCount = @($archiveOnlyMetadataPaths | Where-Object {
            $_ -cmatch '^package/services/metadata/core-properties/[0-9a-f]{32}\.psmdcp$'
        }).Count
    if ($archiveOnlyMetadataPaths.Count -ne 3 -or
        -not $archiveOnlyMetadataPaths.Contains('_rels/.rels') -or
        -not $archiveOnlyMetadataPaths.Contains('[Content_Types].xml') -or
        $corePropertyCount -ne 1) {
        Stop-Gate -Message "Package $PackageKey does not contain the exact three reviewed archive-only metadata files."
    }
    if ($archiveNuspecCount -ne 1) {
        Stop-Gate -Message "Package $PackageKey does not contain exactly one canonical package nuspec entry."
    }
    if ($archivePayloadCount -ne $expectedPayloadCount -or
        $matchedDiskPayloads.Count -ne $expectedPayloadCount) {
        Stop-Gate -Message "Package $PackageKey has unbound archive or extracted payload files."
    }
    foreach ($diskPath in $DiskFiles.Keys) {
        if (-not $allowedDiskOnly.Contains($diskPath) -and -not $matchedDiskPayloads.Contains($diskPath)) {
            Stop-Gate -Message "Package $PackageKey has an extracted file absent from the signed archive payload."
        }
    }

    $archiveItem = Get-Item -LiteralPath $ArchivePath -Force
    $archiveLength = [long]$archiveItem.Length
    $archiveSha256 = Get-Sha256 $ArchivePath
    $archiveAfter = Get-Item -LiteralPath $ArchivePath -Force
    if ([long]$archiveAfter.Length -ne $archiveLength) {
        Stop-Gate -Message "The retained archive changed while it was being bound for $PackageKey."
    }
    return [pscustomobject]@{
        ArchiveLength = $archiveLength
        ArchiveSha256 = $archiveSha256
        ArchiveSha512 = $archiveSha512
        ArchiveTotalEntryCount = $archiveTotalEntryCount
        ArchiveEntryCount = $archiveEntryCount
        ArchivePayloadFileCount = $archivePayloadCount
        ArchiveOnlyMetadataCount = $archiveOnlyMetadataPaths.Count
        ArchiveUncompressedBytes = $archiveUncompressedBytes
    }
}

function Protect-Text {
    param([AllowEmptyString()] [string]$Text)

    $safe = $Text.Replace("`r`n", "`n").Replace("`r", "`n")
    $privatePaths = @(
        $repositoryRoot,
        [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile),
        [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData),
        [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique |
        Sort-Object Length -Descending

    foreach ($privatePath in $privatePaths) {
        foreach ($pathForm in @($privatePath, $privatePath.Replace('\', '/')) | Select-Object -Unique) {
            $safe = [regex]::Replace(
                $safe,
                [regex]::Escape($pathForm),
                '<redacted-path>',
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        }
    }

    $secretNamePattern = '(?:authorization|proxy-authorization|cookie|set-cookie|access_token|refresh_token|id_token|api_key|client_secret|token|secret)'
    $safe = [regex]::Replace(
        $safe,
        "(?i)(?<prefix>[`"']?$secretNamePattern[`"']?\s*[:=]\s*)`"(?:\\.|[^`"\r\n])*`"",
        {
            param($match)
            return $match.Groups['prefix'].Value + '"<redacted>"'
        })
    $safe = [regex]::Replace(
        $safe,
        "(?i)(?<prefix>[`"']?$secretNamePattern[`"']?\s*[:=]\s*)'(?:\\.|[^'\r\n])*'",
        {
            param($match)
            return $match.Groups['prefix'].Value + "'<redacted>'"
        })
    $safe = [regex]::Replace(
        $safe,
        "(?im)(?<prefix>[`"']?$secretNamePattern[`"']?\s*[:=]\s*)`"(?=[^`"\r\n]*$)[^\r\n]*$",
        '${prefix}"<redacted>"')
    $safe = [regex]::Replace(
        $safe,
        "(?im)(?<prefix>[`"']?$secretNamePattern[`"']?\s*[:=]\s*)'(?=[^'\r\n]*$)[^\r\n]*$",
        "`${prefix}'<redacted>'")
    $safe = [regex]::Replace(
        $safe,
        "(?im)(?<prefix>[`"']?$secretNamePattern[`"']?\s*[:=]\s*)(?![`"'])[^\r\n]*$",
        '${prefix}<redacted>')

    $credentialSchemePattern = '(?:basic|bearer|digest|negotiate|ntlm|token)'
    $safe = [regex]::Replace(
        $safe,
        "(?i)`"(?<scheme>$credentialSchemePattern)\s+(?:\\.|[^`"\r\n])*`"",
        {
            param($match)
            return '"' + $match.Groups['scheme'].Value + ' <redacted>"'
        })
    $safe = [regex]::Replace(
        $safe,
        "(?i)'(?<scheme>$credentialSchemePattern)\s+(?:\\.|[^'\r\n])*'",
        {
            param($match)
            return "'" + $match.Groups['scheme'].Value + " <redacted>'"
        })
    $safe = [regex]::Replace(
        $safe,
        "(?im)`"(?<scheme>$credentialSchemePattern)\s+(?=[^`"\r\n]*$)[^\r\n]*$",
        '"${scheme} <redacted>"')
    $safe = [regex]::Replace(
        $safe,
        "(?im)'(?<scheme>$credentialSchemePattern)\s+(?=[^'\r\n]*$)[^\r\n]*$",
        "'`${scheme} <redacted>'")
    $safe = [regex]::Replace(
        $safe,
        "(?im)(?<![`"'])\b(?<scheme>$credentialSchemePattern)\s+[^\r\n]*$",
        '${scheme} <redacted>')
    $safe = [regex]::Replace(
        $safe,
        '(?i)\b(?<scheme>[a-z][a-z0-9+.-]*://)[^/\s@]+@',
        '${scheme}<redacted>@')
    return $safe
}

function Assert-RedactionSelfTests {
    $quotedJson = '{"Authorization":"Bearer synthetic-json-credential","other":"retained"}'
    $quotedJsonSafe = Protect-Text $quotedJson
    if ($quotedJsonSafe.Contains('synthetic-json-credential', [System.StringComparison]::Ordinal) -or
        -not $quotedJsonSafe.Contains('"other":"retained"', [System.StringComparison]::Ordinal) -or
        -not $quotedJsonSafe.Contains('<redacted>', [System.StringComparison]::Ordinal)) {
        throw [System.InvalidOperationException]::new('Quoted JSON credential redaction self-test failed.')
    }

    $prefixedHeader = ('x' * 40) + ' Authorization: Basic synthetic-prefixed-credential'
    $prefixedHeaderSafe = Protect-Text $prefixedHeader
    if ($prefixedHeaderSafe.Contains('synthetic-prefixed-credential', [System.StringComparison]::Ordinal) -or
        -not $prefixedHeaderSafe.Contains('<redacted>', [System.StringComparison]::Ordinal)) {
        throw [System.InvalidOperationException]::new('Prefixed header redaction self-test failed.')
    }

    foreach ($scheme in @('Basic', 'Bearer', 'Digest', 'Negotiate', 'NTLM', 'token')) {
        $credential = "synthetic-$($scheme.ToLowerInvariant())-credential"
        $schemeSafe = Protect-Text "$scheme $credential"
        if ($schemeSafe.Contains($credential, [System.StringComparison]::Ordinal) -or
            -not $schemeSafe.Contains('<redacted>', [System.StringComparison]::Ordinal)) {
            throw [System.InvalidOperationException]::new('Credential-scheme redaction self-test failed.')
        }
    }

    $tokenJsonSafe = Protect-Text '{"token":"synthetic-token-assignment","other":true}'
    $uriSafe = Protect-Text 'https://synthetic-user:synthetic-password@example.invalid/path'
    $malformedQuotedSafe = Protect-Text 'event Authorization: "Bearer synthetic-unclosed-credential'
    if ($tokenJsonSafe.Contains('synthetic-token-assignment', [System.StringComparison]::Ordinal) -or
        $uriSafe.Contains('synthetic-user', [System.StringComparison]::Ordinal) -or
        $uriSafe.Contains('synthetic-password', [System.StringComparison]::Ordinal) -or
        $malformedQuotedSafe.Contains('synthetic-unclosed-credential', [System.StringComparison]::Ordinal)) {
        throw [System.InvalidOperationException]::new('Token or URI-userinfo redaction self-test failed.')
    }

    $multiLineSecrets = @(
        'synthetic-crlf-authorization',
        'synthetic-crlf-cookie',
        'synthetic-crlf-token')
    $multiLineSafe = Protect-Text (
        "Authorization: Bearer $($multiLineSecrets[0])`r`n" +
        "Cookie: session=$($multiLineSecrets[1])`r`n" +
        "access_token=$($multiLineSecrets[2])")
    if ($multiLineSafe.Contains("`r", [System.StringComparison]::Ordinal) -or
        ($multiLineSecrets | Where-Object {
                $multiLineSafe.Contains($_, [System.StringComparison]::Ordinal)
            } | Select-Object -First 1)) {
        throw [System.InvalidOperationException]::new('Multi-line CRLF redaction self-test failed.')
    }
}

function ConvertTo-BoundedPacketField {
    param(
        [AllowEmptyString()] [string]$Text,
        [ValidateRange(1, 32)] [int]$MaximumLines = 8,
        [ValidateRange(16, 2048)] [int]$MaximumLineCharacters = 512,
        [ValidateRange(64, 8192)] [int]$MaximumCharacters = 2048
    )

    $safe = (Protect-Text $Text).Replace("`r`n", "`n").Replace("`r", "`n")
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in @($safe -split "`n" | Select-Object -First $MaximumLines)) {
        $boundedLine = if ($line.Length -gt $MaximumLineCharacters) {
            $line.Substring(0, $MaximumLineCharacters)
        }
        else {
            $line
        }
        $lines.Add($boundedLine)
    }
    $result = $lines -join '\n'
    if ($result.Length -gt $MaximumCharacters) {
        $result = $result.Substring(0, $MaximumCharacters)
    }
    return $result
}

function ConvertTo-BoundedPacketOutput {
    param([AllowEmptyString()] [string]$Text)

    $safe = (Protect-Text $Text).Replace("`r`n", "`n").Replace("`r", "`n")
    $lines = [System.Collections.Generic.List[string]]::new()
    $characterCount = 0
    foreach ($line in @($safe -split "`n")) {
        if ($lines.Count -ge 40) {
            break
        }
        $boundedLine = if ($line.Length -gt 512) { $line.Substring(0, 512) } else { $line }
        $additionalCharacters = $boundedLine.Length + $(if ($lines.Count -gt 0) { 1 } else { 0 })
        if ($characterCount + $additionalCharacters -gt 8192) {
            $remaining = 8192 - $characterCount - $(if ($lines.Count -gt 0) { 1 } else { 0 })
            if ($remaining -gt 0) {
                $lines.Add($boundedLine.Substring(0, [Math]::Min($remaining, $boundedLine.Length)))
            }
            break
        }
        $lines.Add($boundedLine)
        $characterCount += $additionalCharacters
    }
    return $lines -join "`n"
}

function Test-SafeArtifactDirectory {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [switch]$Create
    )

    try {
        $target = [System.IO.Path]::GetFullPath($Path)
        $prefix = $artifactsRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) +
            [System.IO.Path]::DirectorySeparatorChar
        if ($target -ne $artifactsRoot -and
            -not $target.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
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
                [System.IO.Directory]::CreateDirectory($target) | Out-Null
            }
        }
        return Test-Path -LiteralPath $target -PathType Container
    }
    catch {
        return $false
    }
}

function Test-EvidenceLeaseReceipt {
    if (-not $script:EvidenceLeaseAcquired -or
        [string]::IsNullOrEmpty($script:EvidenceLeaseNonce) -or
        $script:EvidenceLeaseNonce -cnotmatch '^[0-9a-f]{32}$') {
        return $false
    }
    try {
        if (-not (Test-SafeExistingLeaf -Path $evidenceLeasePath -AllowedRoot $evidenceRoot)) {
            return $false
        }
        $receipt = [System.IO.File]::Open(
            $evidenceLeasePath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::Read)
        try {
            if ($receipt.Length -ne 33) {
                return $false
            }
            $bytes = [byte[]]::new(33)
            $offset = 0
            while ($offset -lt $bytes.Length) {
                $count = $receipt.Read($bytes, $offset, $bytes.Length - $offset)
                if ($count -eq 0) {
                    return $false
                }
                $offset += $count
            }
            if ($receipt.ReadByte() -ne -1 -or $receipt.Length -ne 33) {
                return $false
            }
            return [System.Text.Encoding]::ASCII.GetString($bytes) -ceq
                "$($script:EvidenceLeaseNonce)`n"
        }
        finally {
            $receipt.Dispose()
        }
    }
    catch {
        return $false
    }
}

function Test-EvidencePassPairInvalidated {
    return $script:EvidencePassPairInvalidated -and
        -not [System.IO.File]::Exists($auditSidecarPath) -and
        -not [System.IO.Directory]::Exists($auditSidecarPath) -and
        -not [System.IO.File]::Exists($auditPath) -and
        -not [System.IO.Directory]::Exists($auditPath)
}

function Remove-ExactEvidenceWriterLease {
    if (-not $script:EvidenceLeaseAcquired) {
        return $true
    }
    try {
        if (-not (Test-EvidenceLeaseReceipt)) {
            return $false
        }
        [System.IO.File]::Delete($evidenceLeasePath)
        if ([System.IO.File]::Exists($evidenceLeasePath) -or
            [System.IO.Directory]::Exists($evidenceLeasePath)) {
            return $false
        }
        $script:EvidenceLeaseAcquired = $false
        $script:EvidenceLeaseValidated = $false
        $script:EvidencePassPairInvalidated = $false
        $script:EvidenceLeaseNonce = $null
        return $true
    }
    catch {
        return $false
    }
}

function Enter-EvidenceWriterLease {
    if ($script:EvidenceLeaseAcquired) {
        return $script:EvidenceLeaseValidated -and
            (Test-EvidenceLeaseReceipt) -and
            (Test-EvidencePassPairInvalidated)
    }
    if ($script:EvidenceLeaseValidated -or
        $script:EvidencePassPairInvalidated -or
        $null -ne $script:EvidenceLeaseNonce) {
        return $false
    }
    if (-not (Test-SafeArtifactDirectory -Path $evidenceRoot -Create) -or
        [System.IO.Directory]::Exists($evidenceLeasePath) -or
        [System.IO.File]::Exists($evidenceLeasePath)) {
        return $false
    }

    $nonce = [System.Guid]::NewGuid().ToString('N')
    $stream = $null
    $entered = $false
    try {
        $stream = [System.IO.File]::Open(
            $evidenceLeasePath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None)
        $bytes = [System.Text.Encoding]::ASCII.GetBytes("$nonce`n")
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
        $stream.Dispose()
        $stream = $null
        $script:EvidenceLeaseAcquired = $true
        $script:EvidenceLeaseNonce = $nonce
        if (-not (Test-EvidenceLeaseReceipt)) {
            return $false
        }
        $script:EvidenceLeaseValidated = $true

        foreach ($priorPassPath in @($auditSidecarPath, $auditPath)) {
            if ([System.IO.Directory]::Exists($priorPassPath) -or
                ([System.IO.File]::Exists($priorPassPath) -and
                    -not (Test-SafeExistingLeaf -Path $priorPassPath -AllowedRoot $evidenceRoot))) {
                return $false
            }
            if ([System.IO.File]::Exists($priorPassPath)) {
                [System.IO.File]::Delete($priorPassPath)
            }
            if ([System.IO.File]::Exists($priorPassPath) -or
                [System.IO.Directory]::Exists($priorPassPath)) {
                return $false
            }
        }
        $script:EvidencePassPairInvalidated = $true
        if (-not (Test-EvidenceLeaseReceipt) -or
            -not (Test-EvidencePassPairInvalidated)) {
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

function Exit-EvidenceWriterLease {
    return Remove-ExactEvidenceWriterLease
}

function Stop-Gate {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [int]$ExitCode = 1,
        [string]$Replay = 'pwsh -NoProfile -NonInteractive -File CrossPlatform/eng/Restore.ps1',
        [AllowEmptyString()] [string]$Output = '',
        [string[]]$Argv = @()
    )

    if ($ExitCode -eq 0) { $ExitCode = 1 }
    if ($script:Stopping) {
        try { [Console]::Error.WriteLine("FAIL $gateId exit=$script:StopExitCode evidence=none") } catch { }
        exit $script:StopExitCode
    }
    $script:Stopping = $true
    $script:StopExitCode = $ExitCode
    $wrotePacket = $false
    $relativePacket = 'none'
    try {
        if (-not (Enter-EvidenceWriterLease)) {
            throw [System.IO.IOException]::new('The shared evidence writer lease is unavailable.')
        }
        if (-not (Test-SafeArtifactDirectory -Path $failureRoot -Create)) {
            throw [System.IO.IOException]::new('Failure evidence directory is unsafe.')
        }
        $packetPath = Join-Path $failureRoot ($gateId + '.txt')
        $bounded = ConvertTo-BoundedPacketOutput $Output
        $safeMessage = ConvertTo-BoundedPacketField $Message
        $safeArgv = ConvertTo-BoundedPacketField ($Argv | ConvertTo-Json -Compress)
        $safeReplay = ConvertTo-BoundedPacketField $Replay
        $packet = @(
            "gate=$gateId"
            'criterion=LNX-001,LNX-004'
            "exit=$ExitCode"
            "head=$($script:RepositoryHead)"
            "message=$safeMessage"
            "argv=$safeArgv"
            "replay=$safeReplay"
            'output_begin'
            $bounded
            'output_end'
        ) -join "`n"
        Write-Utf8File -Path $packetPath -Content ($packet + "`n")
        $relativePacket = [System.IO.Path]::GetRelativePath($repositoryRoot, $packetPath).Replace('\', '/')
        $wrotePacket = $true
    }
    catch {
        $wrotePacket = $false
        $relativePacket = 'none'
    }
    finally {
        if (-not (Exit-EvidenceWriterLease)) {
            $wrotePacket = $false
            $relativePacket = 'none'
        }
    }
    try {
        [Console]::Error.WriteLine("FAIL $gateId exit=$ExitCode evidence=$(if ($wrotePacket) { $relativePacket } else { 'none' })")
    }
    catch { }
    exit $ExitCode
}

function Remove-OwnFailurePacket {
    if (-not (Test-SafeArtifactDirectory -Path $failureRoot -Create)) {
        Stop-Gate -Message 'The failure evidence directory is not a safe repository-local path.'
    }
    $leafName = "$gateId.txt"
    $matches = @(Get-ChildItem -LiteralPath $failureRoot -Force | Where-Object {
            [string]::Equals($_.Name, $leafName, [System.StringComparison]::Ordinal)
        })
    if ($matches.Count -eq 0) {
        return
    }
    if ($matches.Count -ne 1 -or $matches[0].PSIsContainer -or
        (($matches[0].Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
        Stop-Gate -Message 'The prior restore failure packet is not a safe regular leaf.'
    }
    [System.IO.File]::Delete($matches[0].FullName)
    $remaining = @(Get-ChildItem -LiteralPath $failureRoot -Force | Where-Object {
            [string]::Equals($_.Name, $leafName, [System.StringComparison]::Ordinal)
        })
    if ($remaining.Count -ne 0) {
        Stop-Gate -Message 'The prior restore failure packet could not be removed after success.'
    }
}

function Invoke-BoundedProcess {
    param(
        [Parameter(Mandatory)] [string]$FileName,
        [Parameter(Mandatory)] [string[]]$Arguments,
        [Parameter(Mandatory)] [string]$WorkingDirectory,
        [Parameter(Mandatory)] [hashtable]$Environment,
        [Parameter(Mandatory)] [int]$Timeout,
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
        $executableDirectory = Split-Path -Parent ([System.IO.Path]::GetFullPath($FileName))
        $startInfo.Environment['SystemRoot'] = $windowsDirectory
        $startInfo.Environment['WINDIR'] = $windowsDirectory
        $startInfo.Environment['ComSpec'] = Join-Path $systemDirectory 'cmd.exe'
        $startInfo.Environment['PATH'] = @($executableDirectory, $systemDirectory) -join [System.IO.Path]::PathSeparator
        $startInfo.Environment['PATHEXT'] = '.COM;.EXE;.BAT;.CMD'
    }
    else {
        $startInfo.Environment['PATH'] = '/usr/bin:/bin'
    }
    foreach ($argument in $Arguments) {
        $startInfo.ArgumentList.Add($argument)
    }
    foreach ($entry in $Environment.GetEnumerator()) {
        $startInfo.Environment[[string]$entry.Key] = [string]$entry.Value
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $stdoutMemory = [System.IO.MemoryStream]::new()
    $stderrMemory = [System.IO.MemoryStream]::new()
    $readCancellation = [System.Threading.CancellationTokenSource]::new()
    $started = $false
    $reaped = $false
    try {
        if (-not $process.Start()) {
            throw "Failed to start $FileName."
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
        $deadline = [System.DateTime]::UtcNow.AddSeconds($Timeout)
        $terminationDeadline = [System.DateTime]::MaxValue
        $postExitDrainDeadline = [System.DateTime]::MaxValue
        while (-not ($stdoutEnded -and $stderrEnded -and $process.HasExited)) {
            if (-not $stdoutEnded -and $null -eq $stdoutTask) {
                $stdoutTask = $stdoutStream.ReadAsync(
                    $stdoutBuffer,
                    0,
                    $stdoutBuffer.Length,
                    $readCancellation.Token)
            }
            if (-not $stderrEnded -and $null -eq $stderrTask) {
                $stderrTask = $stderrStream.ReadAsync(
                    $stderrBuffer,
                    0,
                    $stderrBuffer.Length,
                    $readCancellation.Token)
            }

            $now = [System.DateTime]::UtcNow
            if ($process.HasExited -and
                $postExitDrainDeadline -eq [System.DateTime]::MaxValue -and
                -not ($stdoutEnded -and $stderrEnded)) {
                $postExitDrainDeadline = $now.AddSeconds(10)
            }
            if (-not $terminationRequested -and $now -ge $postExitDrainDeadline) {
                $timedOut = $true
                $terminationRequested = $true
                $terminationDeadline = $now
            }
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
        if ($null -ne $stdoutTask -or $null -ne $stderrTask) {
            $readCancellation.Cancel()
            try { $process.StandardOutput.Dispose() } catch { }
            try { $process.StandardError.Dispose() } catch { }
            foreach ($pendingRead in @($stdoutTask, $stderrTask)) {
                if ($null -ne $pendingRead) {
                    try { [void]$pendingRead.Wait(500) } catch { }
                }
            }
        }
        $encoding = [System.Text.UTF8Encoding]::new($false, $false)
        $stdout = $encoding.GetString($stdoutMemory.ToArray())
        $stderr = $encoding.GetString($stderrMemory.ToArray())
        return [pscustomobject]@{
            ExitCode = if (-not $reaped) { 126 } elseif ($timedOut) { 124 } elseif ($outputOverflow) { 125 } else { $process.ExitCode }
            TimedOut = $timedOut
            OutputOverflow = $outputOverflow
            ProcessReaped = $reaped
            StdOut = $stdout
            StdErr = $stderr
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
        $readCancellation.Dispose()
        $process.Dispose()
    }
}

function Get-RelativePath {
    param([Parameter(Mandatory)] [string]$Path)
    return [System.IO.Path]::GetRelativePath($crossPlatformRoot, $Path).Replace('\', '/')
}

function Assert-NoReparsePoint {
    param([Parameter(Mandatory)] [string]$Path)

    $item = Get-Item -LiteralPath $Path -Force
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        Stop-Gate -Message "A dependency input resolves through a reparse point: $(Get-RelativePath $Path)"
    }
}

function Assert-NoReparseComponents {
    param([Parameter(Mandatory)] [string]$Path)

    $target = [System.IO.Path]::GetFullPath($Path)
    $prefix = $crossPlatformRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) +
        [System.IO.Path]::DirectorySeparatorChar
    if ($target -ne $crossPlatformRoot -and
        -not $target.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        Stop-Gate -Message 'A restore path escapes the CrossPlatform subtree.'
    }
    $relative = [System.IO.Path]::GetRelativePath($crossPlatformRoot, $target)
    $current = $crossPlatformRoot
    $rootItem = Get-Item -LiteralPath $current -Force
    if (($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        Stop-Gate -Message 'The CrossPlatform root is a reparse point.'
    }
    foreach ($component in $relative.Split(
            [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar),
            [System.StringSplitOptions]::RemoveEmptyEntries)) {
        $current = Join-Path $current $component
        if (-not (Test-Path -LiteralPath $current)) {
            break
        }
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            Stop-Gate -Message "A restore path resolves through a reparse point: $(Get-RelativePath $current)"
        }
    }
}

function Assert-ExactXmlAttributes {
    param(
        [Parameter(Mandatory)] [System.Xml.XmlElement]$Element,
        [Parameter(Mandatory)] [hashtable]$Expected,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($Element.Attributes.Count -ne $Expected.Count) {
        Stop-Gate -Message "$Label has an unapproved XML attribute count."
    }
    foreach ($attribute in @($Element.Attributes)) {
        if (-not $Expected.ContainsKey($attribute.LocalName) -or
            [string]$attribute.Value -cne [string]$Expected[$attribute.LocalName]) {
            Stop-Gate -Message "$Label has an unapproved XML attribute: $($attribute.LocalName)"
        }
    }
}

function Read-Text {
    param([Parameter(Mandatory)] [string]$Path)

    if (-not (Test-SafeExistingLeaf -Path $Path -AllowedRoot $crossPlatformRoot)) {
        Stop-Gate -Message 'A restore input is missing, case-mismatched, or resolves through a reparse point.'
    }
    return [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false, $true))
}

function Read-StrictXml {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Label
    )

    $settings = [System.Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $settings.IgnoreComments = $false
    $settings.IgnoreProcessingInstructions = $false
    $settings.IgnoreWhitespace = $false
    $stringReader = [System.IO.StringReader]::new((Read-Text $Path))
    $reader = $null
    try {
        $reader = [System.Xml.XmlReader]::Create($stringReader, $settings)
        $document = [System.Xml.XmlDocument]::new()
        $document.XmlResolver = $null
        $document.PreserveWhitespace = $true
        $document.Load($reader)
        if ($null -eq $document.DocumentElement) {
            Stop-Gate -Message "$Label has no document element."
        }
        foreach ($node in @($document.ChildNodes)) {
            if ($node -eq $document.DocumentElement -or
                $node.NodeType -in @(
                    [System.Xml.XmlNodeType]::XmlDeclaration,
                    [System.Xml.XmlNodeType]::Whitespace,
                    [System.Xml.XmlNodeType]::SignificantWhitespace)) {
                continue
            }
            Stop-Gate -Message "$Label contains an unapproved document-level XML node."
        }
        return ,$document
    }
    finally {
        if ($null -ne $reader) {
            $reader.Dispose()
        }
        $stringReader.Dispose()
    }
}

function Get-XmlElementChildren {
    param([Parameter(Mandatory)] [System.Xml.XmlElement]$Element)

    $children = [System.Collections.Generic.List[System.Xml.XmlElement]]::new()
    foreach ($node in @($Element.ChildNodes)) {
        if ($node.NodeType -eq [System.Xml.XmlNodeType]::Element) {
            $children.Add([System.Xml.XmlElement]$node)
            continue
        }
        if ($node.NodeType -in @(
                [System.Xml.XmlNodeType]::Whitespace,
                [System.Xml.XmlNodeType]::SignificantWhitespace)) {
            continue
        }
        Stop-Gate -Message "XML element $($Element.LocalName) contains unapproved text, comment, or processing content."
    }
    return $children.ToArray()
}

function Assert-ExactXmlChildNames {
    param(
        [Parameter(Mandatory)] [System.Xml.XmlElement]$Element,
        [Parameter(Mandatory)] [string[]]$ExpectedNames,
        [Parameter(Mandatory)] [string]$Label
    )

    $children = @(Get-XmlElementChildren $Element)
    if ($children.Count -ne $ExpectedNames.Count) {
        Stop-Gate -Message "$Label has an unapproved XML child count."
    }
    for ($index = 0; $index -lt $ExpectedNames.Count; $index++) {
        if ($children[$index].LocalName -cne $ExpectedNames[$index]) {
            Stop-Gate -Message "$Label has an unapproved XML child at index $index."
        }
    }
    return $children
}

function Assert-EmptyXmlElement {
    param(
        [Parameter(Mandatory)] [System.Xml.XmlElement]$Element,
        [Parameter(Mandatory)] [hashtable]$ExpectedAttributes,
        [Parameter(Mandatory)] [string]$Label
    )

    Assert-ExactXmlAttributes $Element $ExpectedAttributes $Label
    if ($Element.ChildNodes.Count -ne 0) {
        Stop-Gate -Message "$Label must not contain XML child content."
    }
}

function Read-ExactGlobalJson {
    param([Parameter(Mandatory)] [string]$Path)

    $document = $null
    try {
        $document = [System.Text.Json.JsonDocument]::Parse((Read-Text $Path))
        $root = $document.RootElement
        if ($root.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            Stop-Gate -Message 'global.json root must be an object.'
        }
        $rootProperties = @($root.EnumerateObject())
        if ($rootProperties.Count -ne 1 -or $rootProperties[0].Name -cne 'sdk') {
            Stop-Gate -Message 'global.json must contain only the sdk object.'
        }
        $sdk = $rootProperties[0].Value
        if ($sdk.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            Stop-Gate -Message 'global.json sdk must be an object.'
        }
        $sdkProperties = @($sdk.EnumerateObject())
        $expectedNames = @('version', 'rollForward', 'allowPrerelease')
        if ($sdkProperties.Count -ne $expectedNames.Count) {
            Stop-Gate -Message 'global.json sdk property inventory differs from the reviewed bootstrap.'
        }
        $values = @{}
        foreach ($property in $sdkProperties) {
            if ($expectedNames -cnotcontains $property.Name -or $values.ContainsKey($property.Name)) {
                Stop-Gate -Message "global.json contains an unapproved or duplicate sdk property: $($property.Name)"
            }
            $values[$property.Name] = $property.Value
        }
        if ($values['version'].ValueKind -ne [System.Text.Json.JsonValueKind]::String -or
            $values['rollForward'].ValueKind -ne [System.Text.Json.JsonValueKind]::String -or
            $values['allowPrerelease'].ValueKind -notin @(
                [System.Text.Json.JsonValueKind]::True,
                [System.Text.Json.JsonValueKind]::False)) {
            Stop-Gate -Message 'global.json sdk property types differ from the reviewed bootstrap.'
        }
        return [pscustomobject]@{
            Version = $values['version'].GetString()
            RollForward = $values['rollForward'].GetString()
            AllowPrerelease = $values['allowPrerelease'].GetBoolean()
        }
    }
    catch {
        Stop-Gate -Message "global.json is invalid: $($_.Exception.Message)"
    }
    finally {
        if ($null -ne $document) {
            $document.Dispose()
        }
    }
}

function Assert-ExactAssetJsonObjectShape {
    param(
        [Parameter(Mandatory)] [System.Text.Json.JsonElement]$Element,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]]$ExpectedNames,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($Element.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
        throw [System.IO.InvalidDataException]::new("$Label must be a JSON object.")
    }
    $properties = @($Element.EnumerateObject())
    if ($properties.Count -ne $ExpectedNames.Count) {
        throw [System.IO.InvalidDataException]::new("$Label has an unexpected property count.")
    }
    $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $fields = [System.Collections.Generic.Dictionary[string,System.Text.Json.JsonElement]]::new(
        [System.StringComparer]::Ordinal)
    foreach ($property in $properties) {
        if (-not $names.Add($property.Name) -or
            $ExpectedNames -cnotcontains $property.Name) {
            throw [System.IO.InvalidDataException]::new("$Label has a duplicate or unknown property.")
        }
        $fields.Add($property.Name, $property.Value)
    }
    foreach ($expectedName in $ExpectedNames) {
        if (-not $names.Contains($expectedName)) {
            throw [System.IO.InvalidDataException]::new("$Label lacks a required property.")
        }
    }
    return ,$fields
}

function Get-CanonicalAssetJsonProperty {
    param(
        [Parameter(Mandatory)] [System.Text.Json.JsonElement]$Element,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [System.Text.Json.JsonValueKind]$ExpectedKind,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($Element.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
        throw [System.IO.InvalidDataException]::new("$Label parent must be a JSON object.")
    }
    $matches = @($Element.EnumerateObject() | Where-Object {
            $_.Name.Equals($Name, [System.StringComparison]::OrdinalIgnoreCase)
        })
    if ($matches.Count -ne 1 -or
        $matches[0].Name -cne $Name -or
        $matches[0].Value.ValueKind -ne $ExpectedKind) {
        throw [System.IO.InvalidDataException]::new("$Label is missing, duplicated, mis-cased, or has the wrong type.")
    }
    return $matches[0].Value
}

function Assert-ExactAssetStringArray {
    param(
        [Parameter(Mandatory)] [System.Text.Json.JsonElement]$Element,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]]$Expected,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($Element.ValueKind -ne [System.Text.Json.JsonValueKind]::Array) {
        throw [System.IO.InvalidDataException]::new("$Label must be a JSON array.")
    }
    $items = @($Element.EnumerateArray())
    if ($items.Count -ne $Expected.Count) {
        throw [System.IO.InvalidDataException]::new("$Label has an unexpected item count.")
    }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ($items[$index].ValueKind -ne [System.Text.Json.JsonValueKind]::String -or
            $items[$index].GetString() -cne $Expected[$index]) {
            throw [System.IO.InvalidDataException]::new("$Label has an unexpected ordered item.")
        }
    }
}

function Get-EvaluatedAssetProjectIdentity {
    param([Parameter(Mandatory)] [string]$JsonText)

    $options = [System.Text.Json.JsonDocumentOptions]::new()
    $options.AllowTrailingCommas = $false
    $options.CommentHandling = [System.Text.Json.JsonCommentHandling]::Disallow
    $options.MaxDepth = 128
    $document = [System.Text.Json.JsonDocument]::Parse($JsonText, $options)
    try {
        $project = Get-CanonicalAssetJsonProperty `
            -Element $document.RootElement `
            -Name 'project' `
            -ExpectedKind Object `
            -Label 'Evaluated asset project'
        $restore = Get-CanonicalAssetJsonProperty `
            -Element $project `
            -Name 'restore' `
            -ExpectedKind Object `
            -Label 'Evaluated asset restore'
        $uniqueName = Get-CanonicalAssetJsonProperty `
            -Element $restore `
            -Name 'projectUniqueName' `
            -ExpectedKind String `
            -Label 'Evaluated asset project identity'
        $identity = [string]$uniqueName.GetString()
        if ([string]::IsNullOrWhiteSpace($identity)) {
            throw [System.IO.InvalidDataException]::new('Evaluated asset project identity is empty.')
        }
        return $identity
    }
    finally {
        $document.Dispose()
    }
}

function Confirm-EvaluatedAssetPolicy {
    param(
        [Parameter(Mandatory)] [string]$JsonText,
        [Parameter(Mandatory)] [string]$ExpectedProject,
        [Parameter(Mandatory)] [System.Collections.IDictionary]$ExpectedGraph,
        [Parameter(Mandatory)] [string[]]$ExpectedProjects,
        [Parameter(Mandatory)] [string[]]$RequiredPackageIds,
        [Parameter(Mandatory)] [string]$RequiredPackageVersion
    )

    $expectedPath = [System.IO.Path]::GetFullPath((Join-Path $crossPlatformRoot $ExpectedProject))
    if (-not (Test-SafeExistingLeaf -Path $expectedPath -AllowedRoot $crossPlatformRoot)) {
        throw [System.IO.InvalidDataException]::new('Expected project input is not a safe regular file.')
    }
    $projectPathByLibraryKey = [System.Collections.Generic.Dictionary[string,string]]::new(
        [System.StringComparer]::Ordinal)
    foreach ($knownProject in $ExpectedProjects) {
        $projectName = [System.IO.Path]::GetFileNameWithoutExtension($knownProject)
        $projectPathByLibraryKey.Add("$projectName/1.0.0", $knownProject)
    }
    $expectedLibrarySet = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal)
    $pendingProjects = [System.Collections.Generic.Queue[string]]::new()
    foreach ($referencedProject in @($ExpectedGraph[$ExpectedProject])) {
        $pendingProjects.Enqueue([string]$referencedProject)
    }
    while ($pendingProjects.Count -gt 0) {
        $referencedProject = $pendingProjects.Dequeue()
        if (-not $ExpectedGraph.Contains($referencedProject)) {
            throw [System.IO.InvalidDataException]::new('Expected project graph contains an unknown project.')
        }
        $libraryKey = "$([System.IO.Path]::GetFileNameWithoutExtension($referencedProject))/1.0.0"
        if ($expectedLibrarySet.Add($libraryKey)) {
            foreach ($transitiveProject in @($ExpectedGraph[$referencedProject])) {
                $pendingProjects.Enqueue([string]$transitiveProject)
            }
        }
    }
    $expectedLibraryKeys = [string[]]@($expectedLibrarySet)
    [System.Array]::Sort($expectedLibraryKeys, [System.StringComparer]::Ordinal)

    $options = [System.Text.Json.JsonDocumentOptions]::new()
    $options.AllowTrailingCommas = $false
    $options.CommentHandling = [System.Text.Json.JsonCommentHandling]::Disallow
    $options.MaxDepth = 128
    $document = [System.Text.Json.JsonDocument]::Parse($JsonText, $options)
    try {
        $rootFields = Assert-ExactAssetJsonObjectShape `
            -Element $document.RootElement `
            -ExpectedNames @(
                'version', 'targets', 'libraries', 'projectFileDependencyGroups',
                'packageFolders', 'project') `
            -Label 'Evaluated asset root'
        $assetVersion = 0
        if ($rootFields['version'].ValueKind -ne [System.Text.Json.JsonValueKind]::Number -or
            -not $rootFields['version'].TryGetInt32([ref]$assetVersion) -or
            $assetVersion -ne 4 -or
            $rootFields['version'].GetRawText() -cne '4') {
            throw [System.IO.InvalidDataException]::new('Evaluated asset version is not exactly 4.')
        }

        $projectFields = Assert-ExactAssetJsonObjectShape `
            -Element $rootFields['project'] `
            -ExpectedNames @('version', 'restore', 'frameworks', 'runtimes') `
            -Label 'Evaluated asset project'
        if ($projectFields['version'].ValueKind -ne [System.Text.Json.JsonValueKind]::String -or
            $projectFields['version'].GetString() -cne '1.0.0') {
            throw [System.IO.InvalidDataException]::new('Evaluated asset project version is not exactly 1.0.0.')
        }

        $restore = $projectFields['restore']
        $uniqueName = Get-CanonicalAssetJsonProperty $restore 'projectUniqueName' String 'Evaluated asset unique name'
        $projectPath = Get-CanonicalAssetJsonProperty $restore 'projectPath' String 'Evaluated asset project path'
        $packagesPath = Get-CanonicalAssetJsonProperty $restore 'packagesPath' String 'Evaluated asset packages path'
        if (-not [System.IO.Path]::GetFullPath([string]$uniqueName.GetString()).Equals(
                $expectedPath,
                [System.StringComparison]::Ordinal) -or
            -not [System.IO.Path]::GetFullPath([string]$projectPath.GetString()).Equals(
                $expectedPath,
                [System.StringComparison]::Ordinal) -or
            -not [System.IO.Path]::GetFullPath([string]$packagesPath.GetString()).Equals(
                $packagesRoot,
                [System.StringComparison]::Ordinal)) {
            throw [System.IO.InvalidDataException]::new('Evaluated asset restore paths differ from the reviewed inputs.')
        }
        $originalFrameworks = Get-CanonicalAssetJsonProperty `
            $restore 'originalTargetFrameworks' Array 'Evaluated asset original frameworks'
        Assert-ExactAssetStringArray $originalFrameworks @('net10.0') 'Evaluated asset original frameworks'
        $restoreFrameworks = Get-CanonicalAssetJsonProperty `
            $restore 'frameworks' Object 'Evaluated asset restore frameworks'
        [void](Assert-ExactAssetJsonObjectShape `
                $restoreFrameworks @('net10.0') 'Evaluated asset restore frameworks')
        $restoreLock = Get-CanonicalAssetJsonProperty `
            $restore 'restoreLockProperties' Object 'Evaluated asset restore lock'
        $restoreLockFields = Assert-ExactAssetJsonObjectShape `
            $restoreLock @('restorePackagesWithLockFile', 'restoreLockedMode') 'Evaluated asset restore lock'
        if ($restoreLockFields['restorePackagesWithLockFile'].ValueKind -ne [System.Text.Json.JsonValueKind]::String -or
            $restoreLockFields['restorePackagesWithLockFile'].GetString() -cne 'true' -or
            $restoreLockFields['restoreLockedMode'].ValueKind -ne [System.Text.Json.JsonValueKind]::True) {
            throw [System.IO.InvalidDataException]::new('Evaluated asset restore lock policy differs from the reviewed mode.')
        }

        $targetFields = Assert-ExactAssetJsonObjectShape `
            $rootFields['targets'] @('net10.0', 'net10.0/linux-x64') 'Evaluated asset targets'
        foreach ($targetName in @('net10.0', 'net10.0/linux-x64')) {
            $targetLibraries = Assert-ExactAssetJsonObjectShape `
                $targetFields[$targetName] $expectedLibraryKeys "Evaluated target $targetName libraries"
            foreach ($libraryKey in $expectedLibraryKeys) {
                $targetType = Get-CanonicalAssetJsonProperty `
                    $targetLibraries[$libraryKey] 'type' String 'Evaluated target library type'
                $targetFramework = Get-CanonicalAssetJsonProperty `
                    $targetLibraries[$libraryKey] 'framework' String 'Evaluated target library framework'
                if ($targetType.GetString() -cne 'project' -or
                    $targetFramework.GetString() -cne '.NETCoreApp,Version=v10.0') {
                    throw [System.IO.InvalidDataException]::new('Evaluated target library is not an approved project library.')
                }
            }
        }

        $libraryFields = Assert-ExactAssetJsonObjectShape `
            $rootFields['libraries'] $expectedLibraryKeys 'Evaluated asset libraries'
        foreach ($libraryKey in $expectedLibraryKeys) {
            $libraryValueFields = Assert-ExactAssetJsonObjectShape `
                $libraryFields[$libraryKey] @('type', 'path', 'msbuildProject') 'Evaluated project library'
            if ($libraryValueFields['type'].ValueKind -ne [System.Text.Json.JsonValueKind]::String -or
                $libraryValueFields['type'].GetString() -cne 'project' -or
                $libraryValueFields['path'].ValueKind -ne [System.Text.Json.JsonValueKind]::String -or
                $libraryValueFields['msbuildProject'].ValueKind -ne [System.Text.Json.JsonValueKind]::String) {
                throw [System.IO.InvalidDataException]::new('Evaluated library has an unapproved type or path shape.')
            }
            $libraryPath = [string]$libraryValueFields['path'].GetString()
            $msbuildProject = [string]$libraryValueFields['msbuildProject'].GetString()
            $resolvedLibraryPath = [System.IO.Path]::GetFullPath(
                (Join-Path ([System.IO.Path]::GetDirectoryName($expectedPath)) $libraryPath))
            $expectedLibraryPath = [System.IO.Path]::GetFullPath(
                (Join-Path $crossPlatformRoot $projectPathByLibraryKey[$libraryKey]))
            if ($libraryPath -cne $msbuildProject -or
                -not $resolvedLibraryPath.Equals($expectedLibraryPath, [System.StringComparison]::Ordinal) -or
                -not (Test-SafeExistingLeaf -Path $expectedLibraryPath -AllowedRoot $crossPlatformRoot)) {
                throw [System.IO.InvalidDataException]::new('Evaluated project library path differs from the reviewed graph.')
            }
        }

        $packageFolderFields = Assert-ExactAssetJsonObjectShape `
            $rootFields['packageFolders'] @($packagesRoot) 'Evaluated asset package folders'
        [void](Assert-ExactAssetJsonObjectShape `
                $packageFolderFields[$packagesRoot] @() 'Evaluated asset package folder value')

        $frameworkFields = Assert-ExactAssetJsonObjectShape `
            $projectFields['frameworks'] @('net10.0') 'Evaluated asset frameworks'
        $downloadDependencies = Get-CanonicalAssetJsonProperty `
            $frameworkFields['net10.0'] 'downloadDependencies' Array 'Evaluated asset downloads'
        $downloadItems = @($downloadDependencies.EnumerateArray())
        if ($downloadItems.Count -ne $RequiredPackageIds.Count) {
            throw [System.IO.InvalidDataException]::new('Evaluated asset download count differs from the reviewed closure.')
        }
        $downloads = [System.Collections.Generic.List[object]]::new()
        for ($downloadIndex = 0; $downloadIndex -lt $downloadItems.Count; $downloadIndex++) {
            $downloadFields = Assert-ExactAssetJsonObjectShape `
                $downloadItems[$downloadIndex] @('name', 'version') 'Evaluated asset download'
            $requiredRange = "[$RequiredPackageVersion, $RequiredPackageVersion]"
            if ($downloadFields['name'].ValueKind -ne [System.Text.Json.JsonValueKind]::String -or
                $downloadFields['name'].GetString() -cne $RequiredPackageIds[$downloadIndex] -or
                $downloadFields['version'].ValueKind -ne [System.Text.Json.JsonValueKind]::String -or
                $downloadFields['version'].GetString() -cne $requiredRange) {
                throw [System.IO.InvalidDataException]::new('Evaluated asset download tuple differs from the reviewed closure.')
            }
            $downloads.Add([pscustomobject]@{
                    Id = [string]$downloadFields['name'].GetString()
                    Version = $RequiredPackageVersion
                })
        }

        $runtimeFields = Assert-ExactAssetJsonObjectShape `
            $projectFields['runtimes'] @('linux-x64') 'Evaluated asset runtimes'
        $linuxRuntimeFields = Assert-ExactAssetJsonObjectShape `
            $runtimeFields['linux-x64'] @('#import') 'Evaluated Linux runtime'
        Assert-ExactAssetStringArray `
            $linuxRuntimeFields['#import'] @() 'Evaluated Linux runtime imports'
        return $downloads.ToArray()
    }
    finally {
        $document.Dispose()
    }
}

function Assert-EvaluatedAssetPolicySelfTests {
    param(
        [Parameter(Mandatory)] [string]$ExpectedProject,
        [Parameter(Mandatory)] [System.Collections.IDictionary]$ExpectedGraph,
        [Parameter(Mandatory)] [string[]]$ExpectedProjects,
        [Parameter(Mandatory)] [string[]]$RequiredPackageIds,
        [Parameter(Mandatory)] [string]$RequiredPackageVersion
    )

    $expectedPath = [System.IO.Path]::GetFullPath((Join-Path $crossPlatformRoot $ExpectedProject))
    $packageFolders = [ordered]@{}
    $packageFolders[$packagesRoot] = [ordered]@{}
    $downloads = @($RequiredPackageIds | ForEach-Object {
            [ordered]@{
                name = $_
                version = "[$RequiredPackageVersion, $RequiredPackageVersion]"
            }
        })
    $fixture = [ordered]@{
        version = 4
        targets = [ordered]@{
            'net10.0' = [ordered]@{}
            'net10.0/linux-x64' = [ordered]@{}
        }
        libraries = [ordered]@{}
        projectFileDependencyGroups = [ordered]@{}
        packageFolders = $packageFolders
        project = [ordered]@{
            version = '1.0.0'
            restore = [ordered]@{
                projectUniqueName = $expectedPath
                projectPath = $expectedPath
                packagesPath = $packagesRoot
                originalTargetFrameworks = @('net10.0')
                frameworks = [ordered]@{ 'net10.0' = [ordered]@{} }
                restoreLockProperties = [ordered]@{
                    restorePackagesWithLockFile = 'true'
                    restoreLockedMode = $true
                }
            }
            frameworks = [ordered]@{
                'net10.0' = [ordered]@{ downloadDependencies = $downloads }
            }
            runtimes = [ordered]@{
                'linux-x64' = [ordered]@{ '#import' = @() }
            }
        }
    }
    $fixtureJson = ConvertTo-Json -InputObject $fixture -Depth 16 -Compress
    $result = @(Confirm-EvaluatedAssetPolicy `
            -JsonText $fixtureJson `
            -ExpectedProject $ExpectedProject `
            -ExpectedGraph $ExpectedGraph `
            -ExpectedProjects $ExpectedProjects `
            -RequiredPackageIds $RequiredPackageIds `
            -RequiredPackageVersion $RequiredPackageVersion)
    if ($result.Count -ne $RequiredPackageIds.Count) {
        throw [System.InvalidOperationException]::new('Valid evaluated asset policy self-test failed.')
    }

    $duplicateDownloadJson = $fixtureJson.Replace(
        $RequiredPackageIds[1],
        $RequiredPackageIds[0])
    $duplicateRejected = $false
    try {
        [void](Confirm-EvaluatedAssetPolicy `
                -JsonText $duplicateDownloadJson `
                -ExpectedProject $ExpectedProject `
                -ExpectedGraph $ExpectedGraph `
                -ExpectedProjects $ExpectedProjects `
                -RequiredPackageIds $RequiredPackageIds `
                -RequiredPackageVersion $RequiredPackageVersion)
    }
    catch [System.IO.InvalidDataException] {
        $duplicateRejected = $true
    }
    if (-not $duplicateRejected) {
        throw [System.InvalidOperationException]::new('Duplicate evaluated download self-test was accepted.')
    }

    $duplicateDocument = [System.Text.Json.JsonDocument]::Parse('{"alpha":1,"alpha":2}')
    $duplicatePropertyRejected = $false
    try {
        [void](Assert-ExactAssetJsonObjectShape `
                $duplicateDocument.RootElement @('alpha') 'Synthetic duplicate property')
    }
    catch [System.IO.InvalidDataException] {
        $duplicatePropertyRejected = $true
    }
    finally {
        $duplicateDocument.Dispose()
    }
    if (-not $duplicatePropertyRejected) {
        throw [System.InvalidOperationException]::new('Duplicate asset property self-test was accepted.')
    }
}

trap {
    Stop-Gate `
        -Message "Unexpected restore gate error at line $($_.InvocationInfo.ScriptLineNumber)." `
        -Output "$($_.Exception.GetType().Name): $($_.Exception.Message)"
}

Assert-RedactionSelfTests
if (-not (Enter-EvidenceWriterLease)) {
    try { [Console]::Error.WriteLine("FAIL $gateId exit=1 evidence=none") } catch { }
    exit 1
}

$gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue
if ($null -ne $gitCommand) {
    try {
        $headResult = Invoke-BoundedProcess `
            -FileName $gitCommand.Source `
            -Arguments @('-C', $repositoryRoot, 'rev-parse', '--verify', 'HEAD') `
            -WorkingDirectory $repositoryRoot `
            -Environment @{} `
            -Timeout 10 `
            -MaximumStdOutBytes 1024 `
            -MaximumStdErrBytes 1024 `
            -MaximumCombinedBytes 2048
        $candidateHead = $headResult.StdOut.Trim()
        if ($headResult.ExitCode -eq 0 -and
            $headResult.ProcessReaped -and
            -not $headResult.TimedOut -and
            -not $headResult.OutputOverflow -and
            $candidateHead -cmatch '^[0-9a-f]{40,64}$') {
            $script:RepositoryHead = $candidateHead
        }
    }
    catch {
        $script:RepositoryHead = 'unknown'
    }
}

foreach ($requiredPath in @($configPath, $globalJsonPath, $centralPropsPath, $solutionPath, $serverProjectPath)) {
    if (-not (Test-SafeExistingLeaf -Path $requiredPath -AllowedRoot $crossPlatformRoot)) {
        Stop-Gate -Message "Required restore input is missing: $(Get-RelativePath $requiredPath)"
    }
}

try {
    $nugetConfig = Read-StrictXml $configPath 'NuGet.config'
    $configuration = $nugetConfig.DocumentElement
    if ($configuration.LocalName -cne 'configuration') {
        Stop-Gate -Message 'NuGet.config root must be configuration.'
    }
    Assert-ExactXmlAttributes $configuration @{} 'NuGet configuration root'
    $sections = @(Assert-ExactXmlChildNames $configuration @('config', 'packageSources', 'trustedSigners', 'packageSourceMapping') 'NuGet configuration root')

    $expectedConfig = [ordered]@{
        globalPackagesFolder = 'artifacts/nuget'
        httpCachePath = 'artifacts/nuget-http-cache'
        pluginsCachePath = 'artifacts/nuget-plugin-cache'
        signatureValidationMode = 'require'
        updatePackageLastAccessTime = 'false'
    }

    $configSection = $sections[0]
    Assert-ExactXmlAttributes $configSection @{} 'NuGet config section'
    $configEntryNames = [string[]]@($expectedConfig.Keys | ForEach-Object { 'add' })
    $configEntries = @(Assert-ExactXmlChildNames $configSection $configEntryNames 'NuGet config section')
    $configKeys = [string[]]@($expectedConfig.Keys)
    for ($index = 0; $index -lt $configKeys.Count; $index++) {
        $key = $configKeys[$index]
        Assert-EmptyXmlElement $configEntries[$index] @{
            key = $key
            value = [string]$expectedConfig[$key]
        } "NuGet config entry $key"
    }

    $packageSources = $sections[1]
    Assert-ExactXmlAttributes $packageSources @{} 'NuGet packageSources section'
    $sourceChildren = @(Assert-ExactXmlChildNames $packageSources @('clear', 'add') 'NuGet packageSources section')
    Assert-EmptyXmlElement $sourceChildren[0] @{} 'NuGet packageSources clear element'
    Assert-EmptyXmlElement $sourceChildren[1] @{
        key = 'nuget.org'
        value = $allowedSource
        protocolVersion = '3'
    } 'NuGet package source'

    $trustedSigners = $sections[2]
    Assert-ExactXmlAttributes $trustedSigners @{} 'NuGet trustedSigners section'
    $trustedSignerChildren = @(Assert-ExactXmlChildNames $trustedSigners @('author') 'NuGet trustedSigners section')
    $microsoftSigner = $trustedSignerChildren[0]
    Assert-ExactXmlAttributes $microsoftSigner @{ name = 'microsoft' } 'NuGet Microsoft trusted signer'
    $signerCertificates = @(Assert-ExactXmlChildNames $microsoftSigner @('certificate') 'NuGet Microsoft trusted signer')
    Assert-EmptyXmlElement $signerCertificates[0] @{
        fingerprint = $microsoftAuthorFingerprint
        hashAlgorithm = 'SHA256'
        allowUntrustedRoot = 'false'
    } 'NuGet Microsoft trusted signer certificate'

    $mappingSection = $sections[3]
    Assert-ExactXmlAttributes $mappingSection @{} 'NuGet packageSourceMapping section'
    $mappingChildren = @(Assert-ExactXmlChildNames $mappingSection @('packageSource') 'NuGet packageSourceMapping section')
    $mapping = $mappingChildren[0]
    Assert-ExactXmlAttributes $mapping @{ key = 'nuget.org' } 'NuGet source mapping'
    $mappingPatterns = @(Assert-ExactXmlChildNames $mapping @('package') 'NuGet source mapping')
    Assert-EmptyXmlElement $mappingPatterns[0] @{ pattern = 'Microsoft.*' } 'NuGet source mapping pattern'
}
catch {
    Stop-Gate -Message "NuGet.config validation failed: $($_.Exception.Message)"
}

$expectedProjects = @(
    'src/StaxRip.Contracts/StaxRip.Contracts.csproj',
    'src/StaxRip.Core/StaxRip.Core.csproj',
    'src/StaxRip.Platform/StaxRip.Platform.csproj',
    'src/StaxRip.Server/StaxRip.Server.csproj',
    'tests/StaxRip.ContractTests/StaxRip.ContractTests.csproj'
)
$expectedProjectGraph = [ordered]@{
    'src/StaxRip.Contracts/StaxRip.Contracts.csproj' = @()
    'src/StaxRip.Core/StaxRip.Core.csproj' = @(
        'src/StaxRip.Contracts/StaxRip.Contracts.csproj')
    'src/StaxRip.Platform/StaxRip.Platform.csproj' = @(
        'src/StaxRip.Core/StaxRip.Core.csproj')
    'src/StaxRip.Server/StaxRip.Server.csproj' = @(
        'src/StaxRip.Platform/StaxRip.Platform.csproj')
    'tests/StaxRip.ContractTests/StaxRip.ContractTests.csproj' = @(
        'src/StaxRip.Contracts/StaxRip.Contracts.csproj',
        'src/StaxRip.Core/StaxRip.Core.csproj',
        'src/StaxRip.Platform/StaxRip.Platform.csproj',
        'src/StaxRip.Server/StaxRip.Server.csproj')
}
$requiredRuntimePackages = @(
    'Microsoft.AspNetCore.App.Runtime.linux-x64',
    'Microsoft.NETCore.App.Host.linux-x64',
    'Microsoft.NETCore.App.Runtime.linux-x64'
)
$requiredRuntimePackageVersion = '10.0.11'
foreach ($project in $expectedProjects) {
    $projectPath = Join-Path $crossPlatformRoot $project
    if (-not (Test-SafeExistingLeaf -Path $projectPath -AllowedRoot $crossPlatformRoot)) {
        Stop-Gate -Message "Required project is missing, case-mismatched, or resolves through a reparse point: $project"
    }
    $lockPath = Join-Path (Split-Path -Parent $projectPath) 'packages.lock.json'
    if ((Test-Path -LiteralPath $lockPath) -and
        -not (Test-SafeExistingLeaf -Path $lockPath -AllowedRoot $crossPlatformRoot)) {
        Stop-Gate -Message "Project lock destination is not a safe regular file: $(Get-RelativePath $lockPath)"
    }
}

Assert-EvaluatedAssetPolicySelfTests `
    -ExpectedProject 'src/StaxRip.Contracts/StaxRip.Contracts.csproj' `
    -ExpectedGraph $expectedProjectGraph `
    -ExpectedProjects $expectedProjects `
    -RequiredPackageIds $requiredRuntimePackages `
    -RequiredPackageVersion $requiredRuntimePackageVersion

if (-not $Initial) {
    $missingLocks = @()
    foreach ($project in $expectedProjects) {
        $lockPath = Join-Path (Split-Path -Parent (Join-Path $crossPlatformRoot $project)) 'packages.lock.json'
        if (-not (Test-SafeExistingLeaf -Path $lockPath -AllowedRoot $crossPlatformRoot)) {
            $missingLocks += Get-RelativePath $lockPath
        }
    }
    if ($missingLocks.Count -gt 0) {
        Stop-Gate -Message "Locked restore requires every project lock file. Missing: $($missingLocks -join ', ')" -Replay 'pwsh -NoProfile -NonInteractive -File CrossPlatform/eng/Restore.ps1 -Initial'
    }
}

foreach ($directory in @(
        $artifactsRoot,
        $evidenceRoot,
        $failureRoot,
        $logRoot,
        $packagesRoot,
        (Join-Path $artifactsRoot 'dotnet-cli-home'),
        (Join-Path $artifactsRoot 'nuget-configuration-defaults'),
        (Join-Path $artifactsRoot 'nuget-http-cache'),
        (Join-Path $artifactsRoot 'nuget-plugin-cache'),
        (Join-Path $artifactsRoot 'nuget-scratch'),
        (Join-Path $artifactsRoot 'obj'),
        (Join-Path $artifactsRoot 'tmp'))) {
    Assert-NoReparseComponents $directory
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    Assert-NoReparseComponents $directory
}
foreach ($scanRoot in @($packagesRoot, (Join-Path $artifactsRoot 'obj'))) {
    foreach ($item in @(Get-ChildItem -LiteralPath $scanRoot -Recurse -Force -ErrorAction SilentlyContinue)) {
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            Stop-Gate -Message 'An existing restore output tree contains a reparse point.'
        }
    }
}

$environment = @{
    DOTNET_CLI_HOME = (Join-Path $artifactsRoot 'dotnet-cli-home')
    DOTNET_CLI_TELEMETRY_OPTOUT = '1'
    DOTNET_NOLOGO = '1'
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
    DOTNET_CLI_WORKLOAD_UPDATE_NOTIFY_DISABLE = '1'
    DOTNET_ADD_GLOBAL_TOOLS_TO_PATH = '0'
    DOTNET_GENERATE_ASPNET_CERTIFICATE = '0'
    DOTNET_CLI_USE_MSBUILD_SERVER = '0'
    DOTNET_NUGET_SIGNATURE_VERIFICATION = 'true'
    MSBUILDDISABLENODEREUSE = '1'
    NUGET_PACKAGES = $packagesRoot
    NUGET_HTTP_CACHE_PATH = (Join-Path $artifactsRoot 'nuget-http-cache')
    NUGET_PLUGINS_CACHE_PATH = (Join-Path $artifactsRoot 'nuget-plugin-cache')
    NUGET_SCRATCH = (Join-Path $artifactsRoot 'nuget-scratch')
    NUGET_XMLDOC_MODE = 'skip'
    TEMP = (Join-Path $artifactsRoot 'tmp')
    TMP = (Join-Path $artifactsRoot 'tmp')
    'ProgramFiles(x86)' = (Join-Path $artifactsRoot 'nuget-configuration-defaults')
    ProgramData = (Join-Path $artifactsRoot 'nuget-configuration-defaults')
    ALLUSERSPROFILE = (Join-Path $artifactsRoot 'nuget-configuration-defaults')
    USERPROFILE = (Join-Path $artifactsRoot 'nuget-configuration-defaults')
    APPDATA = (Join-Path $artifactsRoot 'nuget-configuration-defaults')
    LOCALAPPDATA = (Join-Path $artifactsRoot 'nuget-configuration-defaults')
}

$dotnetCommand = Get-Command dotnet -CommandType Application -ErrorAction SilentlyContinue
if ($null -eq $dotnetCommand) {
    Stop-Gate -Message 'The pinned .NET SDK command is unavailable.' -ExitCode 127
}

$globalPolicy = Read-ExactGlobalJson $globalJsonPath
$requestedSdk = [string]$globalPolicy.Version
$rollForward = [string]$globalPolicy.RollForward
$allowPrerelease = [bool]$globalPolicy.AllowPrerelease
if ($requestedSdk -notmatch '^10\.0\.([0-9])([0-9]{2})$' -or $rollForward -ne 'latestPatch' -or $allowPrerelease) {
    Stop-Gate -Message 'global.json must pin a stable .NET 10 SDK feature band with latestPatch policy.'
}
$requestedFeatureBand = [int]$Matches[1]
$requestedPatch = [int]$Matches[2]
$versionResult = Invoke-BoundedProcess -FileName $dotnetCommand.Source -Arguments @('--version') -WorkingDirectory $crossPlatformRoot -Environment $environment -Timeout 30
if ($versionResult.ExitCode -ne 0) {
    Stop-Gate -Message 'The selected .NET SDK version could not be queried.' -ExitCode $versionResult.ExitCode -Output ($versionResult.StdOut + $versionResult.StdErr) -Argv @('dotnet', '--version')
}
$actualSdk = $versionResult.StdOut.Trim()
if ($actualSdk -notmatch '^10\.0\.([0-9])([0-9]{2})$') {
    Stop-Gate -Message "The selected SDK is outside the stable .NET 10 patch grammar: $actualSdk"
}
$actualFeatureBand = [int]$Matches[1]
$actualPatch = [int]$Matches[2]
if ($actualFeatureBand -ne $requestedFeatureBand -or $actualPatch -lt $requestedPatch) {
    Stop-Gate -Message "The selected SDK $actualSdk does not satisfy global.json $requestedSdk with latestPatch policy."
}

$commonRestoreArguments = @(
    '--configfile', $configPath,
    '--packages', $packagesRoot,
    '--no-http-cache',
    '--nologo',
    '--disable-build-servers'
)
if ($Initial) {
    $commonRestoreArguments += @('--use-lock-file', '--force-evaluate')
}
else {
    $commonRestoreArguments += '--locked-mode'
}

$commands = @(
    [pscustomobject]@{
        Name = 'solution'
        Arguments = @('restore', $solutionPath, '--runtime', 'linux-x64') + $commonRestoreArguments
    },
    [pscustomobject]@{
        Name = 'server-linux-x64'
        Arguments = @('restore', $serverProjectPath, '--runtime', 'linux-x64') + $commonRestoreArguments
    }
)

foreach ($command in $commands) {
    $result = Invoke-BoundedProcess -FileName $dotnetCommand.Source -Arguments $command.Arguments -WorkingDirectory $crossPlatformRoot -Environment $environment -Timeout $TimeoutSeconds
    $combinedOutput = $result.StdOut + $result.StdErr
    $logPath = Join-Path $logRoot ("$gateId-$($command.Name).log")
    Write-Utf8File -Path $logPath -Content ((Protect-Text $combinedOutput).TrimEnd() + "`n")
    if ($result.ExitCode -ne 0) {
        $replaySuffix = if ($Initial) { ' -Initial' } else { '' }
        Stop-Gate -Message "dotnet restore step '$($command.Name)' failed." -ExitCode $result.ExitCode -Replay "pwsh -NoProfile -NonInteractive -File CrossPlatform/eng/Restore.ps1$replaySuffix" -Output $combinedOutput -Argv (@('dotnet') + $command.Arguments)
    }
}

if ($Initial) {
    foreach ($project in $expectedProjects) {
        $lockPath = Join-Path (Split-Path -Parent (Join-Path $crossPlatformRoot $project)) 'packages.lock.json'
        Normalize-GeneratedLockFile -Path $lockPath
    }
}

$missingLocks = @()
foreach ($project in $expectedProjects) {
    $lockPath = Join-Path (Split-Path -Parent (Join-Path $crossPlatformRoot $project)) 'packages.lock.json'
    if (-not (Test-SafeExistingLeaf -Path $lockPath -AllowedRoot $crossPlatformRoot)) {
        $missingLocks += Get-RelativePath $lockPath
    }
}
if ($missingLocks.Count -gt 0) {
    Stop-Gate -Message "Restore did not produce every required lock file: $($missingLocks -join ', ')"
}

$assetsByProject = @{}
$assetObjectRoot = Join-Path $artifactsRoot 'obj'
$assetCandidates = @(Get-ChildItem -LiteralPath $assetObjectRoot -Recurse -File -Filter 'project.assets.json' -ErrorAction SilentlyContinue)
if ($assetCandidates.Count -gt 20) {
    Stop-Gate -Message 'The evaluated dependency asset candidate count exceeds the reviewed bound.'
}
$jsonProbeProjectPath = [System.IO.Path]::GetFullPath(
    (Join-Path $artifactsRoot 'diagnostic\StaxRip.JsonProbe.csproj'))
$jsonProbeAssetPath = [System.IO.Path]::GetFullPath(
    (Join-Path $artifactsRoot 'obj\StaxRip.JsonProbe\project.assets.json'))
$jsonProbeSeen = $false
foreach ($assetFile in $assetCandidates) {
    Assert-NoReparsePoint $assetFile.FullName
    try {
        if ([long]$assetFile.Length -lt 1 -or [long]$assetFile.Length -gt 134217728) {
            throw [System.IO.InvalidDataException]::new('Evaluated dependency file exceeds the reviewed size bound.')
        }
        $assetText = Read-Text $assetFile.FullName
        $projectUniqueName = Get-EvaluatedAssetProjectIdentity $assetText
        $projectFullPath = [System.IO.Path]::GetFullPath($projectUniqueName)
        if ($projectFullPath.Equals($jsonProbeProjectPath, [System.StringComparison]::Ordinal)) {
            $candidatePath = [System.IO.Path]::GetFullPath($assetFile.FullName)
            if ($jsonProbeSeen -or
                -not $candidatePath.Equals($jsonProbeAssetPath, [System.StringComparison]::Ordinal) -or
                -not (Test-SafeExistingLeaf -Path $candidatePath -AllowedRoot $artifactsRoot)) {
                throw [System.IO.InvalidDataException]::new('Generated JSON probe asset identity is duplicated or misplaced.')
            }
            $jsonProbeSeen = $true
            continue
        }
        if (-not (Test-PathBelow -Candidate $projectFullPath -Parent $crossPlatformRoot)) {
            throw [System.IO.InvalidDataException]::new('Evaluated asset project identity escapes the reviewed CrossPlatform tree.')
        }
        $projectRelative = Get-RelativePath $projectFullPath
        if ($expectedProjects -cnotcontains $projectRelative) {
            throw [System.IO.InvalidDataException]::new('Evaluated asset project identity is outside the exact five-project set.')
        }
        if (-not (Test-SafeExistingLeaf -Path $projectFullPath -AllowedRoot $crossPlatformRoot)) {
            Stop-Gate -Message "Evaluated project path is case-mismatched or resolves through a reparse point: $projectRelative"
        }
        if ($assetsByProject.ContainsKey($projectRelative)) {
            Stop-Gate -Message "Multiple evaluated asset files were found for $projectRelative."
        }
        $downloads = @(Confirm-EvaluatedAssetPolicy `
                -JsonText $assetText `
                -ExpectedProject $projectRelative `
                -ExpectedGraph $expectedProjectGraph `
                -ExpectedProjects $expectedProjects `
                -RequiredPackageIds $requiredRuntimePackages `
                -RequiredPackageVersion $requiredRuntimePackageVersion)
        $assetsByProject[$projectRelative] = [pscustomobject]@{
            Path = $assetFile.FullName
            Downloads = $downloads
        }
    }
    catch {
        Stop-Gate -Message "Could not parse evaluated dependency file $(Get-RelativePath $assetFile.FullName): $($_.Exception.Message)"
    }
}

$missingAssets = @($expectedProjects | Where-Object { -not $assetsByProject.ContainsKey($_) })
if ($missingAssets.Count -gt 0 -or $assetsByProject.Count -ne $expectedProjects.Count) {
    Stop-Gate -Message "Evaluated dependency files are missing for: $($missingAssets -join ', ')"
}

$packageMap = @{}
foreach ($project in $expectedProjects) {
    foreach ($download in @($assetsByProject[$project].Downloads)) {
            $id = [string]$download.Id
            $version = [string]$download.Version
            $key = "$id/$version"
            $packagePath = "$($id.ToLowerInvariant())/$version"
            if (-not $packageMap.ContainsKey($key)) {
                $packageMap[$key] = [pscustomobject]@{
                    Id = $id
                    Version = $version
                    ContentHash = ''
                    PackagePath = $packagePath
                    Projects = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
                }
            }
            elseif ($packageMap[$key].PackagePath -cne $packagePath) {
                Stop-Gate -Message "Evaluated PackageDownload entries disagree about the path for $key."
            }
            if (-not $packageMap[$key].Projects.Add($project)) {
                Stop-Gate -Message "Evaluated PackageDownload membership is duplicated for $key."
            }
    }
}

$expectedPackageKeys = [string[]]@($requiredRuntimePackages | ForEach-Object {
        "$_/$requiredRuntimePackageVersion"
    })
[System.Array]::Sort($expectedPackageKeys, [System.StringComparer]::Ordinal)
$actualPackageKeys = [string[]]@($packageMap.Keys)
[System.Array]::Sort($actualPackageKeys, [System.StringComparer]::Ordinal)
if ($actualPackageKeys.Count -ne $expectedPackageKeys.Count) {
    Stop-Gate -Message 'The evaluated package set count differs from the three reviewed packs at 10.0.11.'
}
for ($packageIndex = 0; $packageIndex -lt $expectedPackageKeys.Count; $packageIndex++) {
    if ($actualPackageKeys[$packageIndex] -cne $expectedPackageKeys[$packageIndex]) {
        Stop-Gate -Message 'The evaluated package set differs from the three reviewed packs at 10.0.11.'
    }
}

$packageKeys = [string[]]@($packageMap.Keys)
[System.Array]::Sort($packageKeys, [System.StringComparer]::Ordinal)
$closureRows = [System.Collections.Generic.List[string]]::new()
$packageRecords = [System.Collections.Generic.List[object]]::new()
$verifiedPackageArchives = [System.Collections.Generic.List[string]]::new()
$packageBindingReceipts = [System.Collections.Generic.List[object]]::new()
foreach ($key in $packageKeys) {
    $package = $packageMap[$key]
    if ([string]::IsNullOrWhiteSpace($package.PackagePath)) {
        Stop-Gate -Message "The evaluated package $key lacks an extracted path."
    }
    if ($key -notmatch '^[A-Za-z0-9._+-]+/[A-Za-z0-9._+-]+$' -or $package.PackagePath -notmatch '^[A-Za-z0-9._+-]+/[A-Za-z0-9._+-]+$') {
        Stop-Gate -Message "The evaluated package identity or path is outside the canonical ASCII grammar: $key"
    }

    $packageDirectory = [System.IO.Path]::GetFullPath((Join-Path $packagesRoot $package.PackagePath))
    if (-not $packageDirectory.StartsWith($packagesRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        Stop-Gate -Message "The evaluated path for $key escapes the repository-local package cache."
    }
    if (-not (Test-Path -LiteralPath $packageDirectory -PathType Container)) {
        Stop-Gate -Message "The extracted package directory is missing for $key."
    }
    Assert-NoReparseComponents $packageDirectory

    foreach ($item in @(Get-ChildItem -LiteralPath $packageDirectory -Recurse -Force)) {
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            Stop-Gate -Message "The extracted package $key contains a reparse point."
        }
    }

    $metadataPath = Join-Path $packageDirectory '.nupkg.metadata'
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        Stop-Gate -Message "NuGet metadata is missing for $key."
    }
    try {
        $metadata = Read-Text $metadataPath | ConvertFrom-Json
    }
    catch {
        Stop-Gate -Message "NuGet metadata is invalid for $key."
    }
    if ([string]$metadata.source -ne $allowedSource) {
        Stop-Gate -Message "Package $key came from a source outside D-044."
    }
    $metadataContentHash = [string]$metadata.contentHash
    if ([string]::IsNullOrWhiteSpace($metadataContentHash)) {
        Stop-Gate -Message "NuGet metadata has no content hash for $key."
    }
    if (-not [string]::IsNullOrWhiteSpace($package.ContentHash) -and $metadataContentHash -cne $package.ContentHash) {
        Stop-Gate -Message "NuGet metadata and evaluated assets disagree on the content hash for $key."
    }
    $package.ContentHash = $metadataContentHash

    $archiveName = "$($package.Id.ToLowerInvariant()).$($package.Version).nupkg"
    $archivePath = Join-Path $packageDirectory $archiveName
    if (-not (Test-SafeExistingLeaf -Path $archivePath -AllowedRoot $packagesRoot) -or
        (Get-Item -LiteralPath $archivePath -Force).Length -le 0) {
        Stop-Gate -Message "The retained package archive is missing, empty, or unsafe for $key."
    }
    $verifiedPackageArchives.Add($archivePath)

    $diskInventory = Get-PackageDiskInventory -PackageKey $key -PackageDirectory $packageDirectory
    $diskFiles = $diskInventory.Files
    $archiveBinding = Confirm-SignedArchiveExtractionBinding `
        -PackageKey $key `
        -PackageId $package.Id `
        -ArchivePath $archivePath `
        -ArchiveName $archiveName `
        -PackageDirectory $packageDirectory `
        -DiskFiles $diskFiles
    $packageProjects = [string[]]@($package.Projects)
    [System.Array]::Sort($packageProjects, [System.StringComparer]::Ordinal)
    $packageBindingReceipts.Add([pscustomobject]@{
            Key = $key
            Id = $package.Id
            Version = $package.Version
            ContentHash = $package.ContentHash
            ExtractedPath = $package.PackagePath.Replace('\', '/')
            Projects = $packageProjects
            ArchivePath = $archivePath
            ArchiveName = $archiveName
            PackageDirectory = $packageDirectory
            ExpectedBinding = $archiveBinding
            ExpectedInventorySha256 = $diskInventory.InventorySha256
            ExpectedInventoryTotalBytes = $diskInventory.TotalBytes
            ExpectedInventoryFileCount = $diskInventory.FileCount
        })
}

if ($verifiedPackageArchives.Count -ne $requiredRuntimePackages.Count) {
    Stop-Gate -Message 'The signature-verification archive count does not match the reviewed closure.'
}
$verifyArguments = @('nuget', 'verify') + $verifiedPackageArchives.ToArray() + @(
    '--all',
    '--certificate-fingerprint', $microsoftAuthorFingerprint,
    '--verbosity', 'minimal'
)
$verifyResult = Invoke-BoundedProcess `
    -FileName $dotnetCommand.Source `
    -Arguments $verifyArguments `
    -WorkingDirectory $crossPlatformRoot `
    -Environment $environment `
    -Timeout $TimeoutSeconds
$verifyOutput = $verifyResult.StdOut + $verifyResult.StdErr
Write-Utf8File `
    -Path (Join-Path $logRoot "$gateId-signatures.log") `
    -Content ((Protect-Text $verifyOutput).TrimEnd() + "`n")
if ($verifyResult.ExitCode -ne 0) {
    Stop-Gate `
        -Message 'The exact retained package archives failed Microsoft author-signature verification.' `
        -ExitCode $verifyResult.ExitCode `
        -Replay "pwsh -NoProfile -NonInteractive -File CrossPlatform/eng/Restore.ps1$(if ($Initial) { ' -Initial' })" `
        -Output $verifyOutput `
        -Argv (@('dotnet') + $verifyArguments)
}
foreach ($receipt in $packageBindingReceipts) {
    $currentInventory = Get-PackageDiskInventory `
        -PackageKey $receipt.Key `
        -PackageDirectory $receipt.PackageDirectory
    $currentDiskFiles = $currentInventory.Files
    $currentBinding = Confirm-SignedArchiveExtractionBinding `
        -PackageKey $receipt.Key `
        -PackageId $receipt.Id `
        -ArchivePath $receipt.ArchivePath `
        -ArchiveName $receipt.ArchiveName `
        -PackageDirectory $receipt.PackageDirectory `
        -DiskFiles $currentDiskFiles
    if ($currentInventory.InventorySha256 -cne $receipt.ExpectedInventorySha256 -or
        $currentInventory.TotalBytes -ne $receipt.ExpectedInventoryTotalBytes -or
        $currentInventory.FileCount -ne $receipt.ExpectedInventoryFileCount -or
        $currentBinding.ArchiveSha256 -cne $receipt.ExpectedBinding.ArchiveSha256 -or
        $currentBinding.ArchiveSha512 -cne $receipt.ExpectedBinding.ArchiveSha512 -or
        $currentBinding.ArchiveLength -ne $receipt.ExpectedBinding.ArchiveLength -or
        $currentBinding.ArchiveTotalEntryCount -ne $receipt.ExpectedBinding.ArchiveTotalEntryCount -or
        $currentBinding.ArchiveEntryCount -ne $receipt.ExpectedBinding.ArchiveEntryCount -or
        $currentBinding.ArchivePayloadFileCount -ne $receipt.ExpectedBinding.ArchivePayloadFileCount -or
        $currentBinding.ArchiveOnlyMetadataCount -ne $receipt.ExpectedBinding.ArchiveOnlyMetadataCount -or
        $currentBinding.ArchiveUncompressedBytes -ne $receipt.ExpectedBinding.ArchiveUncompressedBytes) {
        Stop-Gate -Message "The signed archive or extracted cache changed during verification for $($receipt.Key)."
    }

    $diskRelativePaths = [string[]]$currentDiskFiles.Keys
    [System.Array]::Sort($diskRelativePaths, [System.StringComparer]::Ordinal)
    foreach ($relativeFile in $diskRelativePaths) {
        $fileRecord = $currentDiskFiles[$relativeFile]
        $closureRows.Add(
            "$($receipt.Key)`t$relativeFile`t$($fileRecord.Length)`t$($fileRecord.Sha256)")
    }
    $packageRecords.Add([ordered]@{
        id = $receipt.Id
        version = $receipt.Version
        source = $allowedSource
        nuget_content_hash = $receipt.ContentHash
        extracted_path = $receipt.ExtractedPath
        archive_file = $receipt.ArchiveName
        archive_length = $currentBinding.ArchiveLength
        archive_sha256 = $currentBinding.ArchiveSha256
        archive_sha512 = $currentBinding.ArchiveSha512
        archive_file_entry_count = $currentBinding.ArchiveEntryCount
        archive_payload_file_count = $currentBinding.ArchivePayloadFileCount
        archive_only_metadata_count = $currentBinding.ArchiveOnlyMetadataCount
        archive_extraction_binding = 'zip-path-length-sha256-v1'
        projects = $receipt.Projects
        extracted_file_count = $currentInventory.FileCount
        extracted_inventory_sha256 = $currentInventory.InventorySha256
        extracted_inventory_total_bytes = $currentInventory.TotalBytes
    })
}

if (-not (Enter-EvidenceWriterLease)) {
    Stop-Gate -Message 'The shared evidence writer lease is unavailable for restore publication.'
}
$closurePath = Join-Path $evidenceRoot 'dependency-files.tsv'
$closureHeader = "package`tpath`tlength`tsha256"
$sortedClosureRows = [string[]]$closureRows.ToArray()
[System.Array]::Sort($sortedClosureRows, [System.StringComparer]::Ordinal)
$closureContent = $closureHeader + "`n"
if ($sortedClosureRows.Count -gt 0) {
    $closureContent += ($sortedClosureRows -join "`n") + "`n"
}
Write-Utf8File -Path $closurePath -Content $closureContent
$closureHash = Get-Sha256 $closurePath

$inputPaths = [System.Collections.Generic.List[string]]::new()
foreach ($fixedInput in @('global.json', 'NuGet.config', 'Directory.Build.props', 'StaxRip.CrossPlatform.slnx')) {
    $inputPaths.Add((Join-Path $crossPlatformRoot $fixedInput))
}
foreach ($project in $expectedProjects) {
    $projectPath = Join-Path $crossPlatformRoot $project
    $inputPaths.Add($projectPath)
    $inputPaths.Add((Join-Path (Split-Path -Parent $projectPath) 'packages.lock.json'))
}
$inputRecords = [System.Collections.Generic.List[object]]::new()
$relativeInputPaths = [string[]]@($inputPaths | ForEach-Object { Get-RelativePath $_ })
[System.Array]::Sort($relativeInputPaths, [System.StringComparer]::Ordinal)
foreach ($relativeInput in $relativeInputPaths) {
    $fullInput = Join-Path $crossPlatformRoot $relativeInput
    $inputRecords.Add([ordered]@{
        path = $relativeInput
        sha256 = Get-Sha256 $fullInput
    })
}

$assetRecords = [System.Collections.Generic.List[object]]::new()
foreach ($project in $expectedProjects) {
    $assetRecords.Add([ordered]@{
        project = $project
        evaluated_assets_sha256 = Get-Sha256 $assetsByProject[$project].Path
    })
}

$dependencyRecord = [ordered]@{
    schema = 'staxrip-dependency-closure-v2'
    sdk = [ordered]@{
        selected = $actualSdk
        requested = $requestedSdk
        roll_forward = $rollForward
        allow_prerelease = $allowPrerelease
    }
    rid = 'linux-x64'
    source = [ordered]@{
        name = 'nuget.org'
        url = $allowedSource
        config_sha256 = Get-Sha256 $configPath
        author_fingerprint = $microsoftAuthorFingerprint
        verified_archive_count = $verifiedPackageArchives.Count
    }
    inputs = $inputRecords
    evaluated_projects = $assetRecords
    packages = $packageRecords
    extracted_closure = [ordered]@{
        path = 'artifacts/evidence/dependency-files.tsv'
        sha256 = $closureHash
        row_count = $sortedClosureRows.Count
    }
}

$recordPath = Join-Path $evidenceRoot 'dependency-closure.json'
$recordJson = ConvertTo-CanonicalJson -InputObject $dependencyRecord -Depth 12
Write-Utf8File -Path $recordPath -Content $recordJson
$recordHashPath = Join-Path $evidenceRoot 'dependency-closure.json.sha256'
Write-Utf8File -Path $recordHashPath -Content ("$(Get-Sha256 $recordPath)  dependency-closure.json`n")

Remove-OwnFailurePacket
if (-not (Exit-EvidenceWriterLease)) {
    Stop-Gate -Message 'The shared evidence writer lease could not be released after restore publication.'
}
$timer.Stop()
$relativeEvidence = Get-RelativePath $recordPath
$checks = $expectedProjects.Count + $packageRecords.Count + $verifiedPackageArchives.Count + $sortedClosureRows.Count + $inputRecords.Count
[Console]::Out.WriteLine("PASS $gateId checks=$checks elapsed_ms=$($timer.ElapsedMilliseconds) evidence=$relativeEvidence")
exit 0
