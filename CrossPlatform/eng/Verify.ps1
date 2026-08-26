[CmdletBinding()]
param(
    [string]$BaseCommit = '940eaba1134e52260a74cb452a86e3e243ed76c9',
    [switch]$InitialRestore,
    [switch]$IncludeLinuxPublish,
    [string]$PublishDirectory,
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$WslDistribution = 'Ubuntu'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gateId = 'port-verify'
$timer = [System.Diagnostics.Stopwatch]::StartNew()
$crossPlatformRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $crossPlatformRoot '..'))
$artifactsRoot = Join-Path $crossPlatformRoot 'artifacts'
$evidenceRoot = Join-Path $artifactsRoot 'evidence'
$failureRoot = Join-Path $artifactsRoot 'failures'
$logRoot = Join-Path $artifactsRoot 'logs'
$publishRoot = Join-Path $artifactsRoot 'publish'
$packagesRoot = Join-Path $artifactsRoot 'nuget'
$temporaryRoot = Join-Path $artifactsRoot 'tmp'
$auditPath = Join-Path $evidenceRoot 'evidence-audit.json'
$auditSidecarPath = Join-Path $evidenceRoot 'evidence-audit.json.sha256'
$evidenceLeasePath = Join-Path $evidenceRoot '.evidence-writer.lock'
$workflowMarkerPath = Join-Path $temporaryRoot '.port-verify-running'
$script:stopGateActive = $false
$script:stopGateExitCode = 1
$script:evidenceLeaseOwned = $false
$script:evidenceLeaseNonce = $null
$script:evidenceLeaseReceiptValidated = $false
$script:evidencePassPairInvalidated = $false
$script:workflowMarkerOwned = $false
$script:workflowMarkerNonce = $null
$script:preserveWorkflowMarker = $false

function Write-Utf8File {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Content
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-SafeArtifactLeaf -Path $fullPath -AllowMissing -CreateParent)) {
        throw 'Artifact output is not a safe repository-local file.'
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
        if (-not (Test-SafeArtifactLeaf -Path $fullPath -AllowMissing -CreateParent)) {
            throw 'Artifact output became unsafe before replacement.'
        }
        [System.IO.File]::Move($temporaryPath, $fullPath, $true)
    }
    finally {
        if ($null -ne $stream) {
            try {
                $stream.Dispose()
            }
            catch {
                # Cleanup must not replace the write failure that triggered the gate.
            }
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
            # A failed best-effort unlink must not hide the primary gate result.
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

    if (-not (Test-SafeArtifactLeaf -Path $Path)) {
        throw 'Artifact input is not a safe regular repository-local file.'
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

function Protect-Text {
    param([AllowEmptyString()] [string]$Text)

    $safe = $Text.Replace("`r`n", "`n").Replace("`r", "`n")
    $privatePaths = @(
        $repositoryRoot,
        [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile),
        [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData),
        [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique | Sort-Object Length -Descending
    foreach ($privatePath in $privatePaths) {
        foreach ($pathForm in @($privatePath, $privatePath.Replace('\', '/')) | Select-Object -Unique) {
            $safe = [regex]::Replace(
                $safe,
                [regex]::Escape($pathForm),
                '<redacted-path>',
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        }
    }
    $safe = [regex]::Replace(
        $safe,
        '(?im)^[^\r\n]*?(?:"(?:authorization|proxy-authorization|cookie|set-cookie)"|''(?:authorization|proxy-authorization|cookie|set-cookie)''|\b(?:authorization|proxy-authorization|cookie|set-cookie)\b)\s*[:=][^\r\n]*$',
        '<redacted-sensitive-header-line>')
    $safe = [regex]::Replace(
        $safe,
        '(?i)\b(Basic|Bearer|Digest|Negotiate|NTLM)\s+[^\s,;]+',
        '$1 <redacted>')
    $safe = [regex]::Replace(
        $safe,
        '(?i)\b(https?|wss?)://[^/\s:@]+:[^@\s/]+@',
        '$1://<redacted>@')
    $safe = [regex]::Replace(
        $safe,
        '(?im)(["'']?(?:access_token|refresh_token|id_token|api_key|client_secret|token|secret)["'']?\s*[:=]\s*)(?:"(?:\\.|[^"\r\n])*"|''[^''\r\n]*''|[^\s,;&}\r\n]+)',
        '$1<redacted>')
    return $safe
}

function Assert-RedactionSelfTests {
    $secrets = @(
        'synthetic-crlf-authorization',
        'synthetic-crlf-cookie',
        'synthetic-crlf-token')
    $safe = Protect-Text (
        "Authorization: Bearer $($secrets[0])`r`n" +
        "Cookie: session=$($secrets[1])`r`n" +
        "access_token=$($secrets[2])")
    if ($safe.Contains("`r", [System.StringComparison]::Ordinal) -or
        ($secrets | Where-Object {
                $safe.Contains($_, [System.StringComparison]::Ordinal)
            } | Select-Object -First 1)) {
        throw [System.InvalidOperationException]::new('Multi-line CRLF redaction self-test failed.')
    }
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

function Test-SafeArtifactLeaf {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [switch]$AllowMissing,
        [switch]$CreateParent
    )

    try {
        $target = [System.IO.Path]::GetFullPath($Path)
        $prefix = $artifactsRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) +
            [System.IO.Path]::DirectorySeparatorChar
        if (-not $target.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
        $parent = Split-Path -Parent $target
        if (-not (Test-SafeArtifactDirectory -Path $parent -Create:$CreateParent)) {
            return $false
        }
        if (-not (Test-Path -LiteralPath $target)) {
            return $AllowMissing
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

function Test-OwnedWorkflowMarker {
    if (-not $script:workflowMarkerOwned -or
        [string]::IsNullOrEmpty($script:workflowMarkerNonce) -or
        $script:workflowMarkerNonce -cnotmatch '^[0-9a-f]{32}$' -or
        -not (Test-SafeArtifactLeaf -Path $workflowMarkerPath)) {
        return $false
    }

    try {
        $actual = [System.IO.File]::ReadAllBytes($workflowMarkerPath)
        $expected = [System.Text.Encoding]::ASCII.GetBytes("$($script:workflowMarkerNonce)`n")
        if ($actual.Length -ne $expected.Length) {
            return $false
        }
        for ($index = 0; $index -lt $expected.Length; $index++) {
            if ($actual[$index] -ne $expected[$index]) {
                return $false
            }
        }
        return $true
    }
    catch {
        return $false
    }
}

function New-WorkflowMarker {
    if (-not (Test-EvidenceWriterLeasePublicationAuthority) -or
        $script:workflowMarkerOwned -or
        -not (Test-SafeArtifactDirectory -Path $temporaryRoot -Create) -or
        [System.IO.Directory]::Exists($workflowMarkerPath) -or
        [System.IO.File]::Exists($workflowMarkerPath)) {
        return $false
    }

    $nonce = [System.Guid]::NewGuid().ToString('N')
    $stream = $null
    try {
        $stream = [System.IO.File]::Open(
            $workflowMarkerPath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None)
        $script:workflowMarkerOwned = $true
        $script:workflowMarkerNonce = $nonce
        $bytes = [System.Text.Encoding]::ASCII.GetBytes("$nonce`n")
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
        $stream.Dispose()
        $stream = $null
        return Test-OwnedWorkflowMarker
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $stream) {
            try { $stream.Dispose() } catch { }
        }
    }
}

function Remove-OwnedWorkflowMarker {
    if (-not (Test-EvidenceWriterLeasePublicationAuthority) -or
        -not (Test-OwnedWorkflowMarker)) {
        return $false
    }

    try {
        [System.IO.File]::Delete($workflowMarkerPath)
        if ([System.IO.File]::Exists($workflowMarkerPath) -or
            [System.IO.Directory]::Exists($workflowMarkerPath)) {
            return $false
        }
        $script:workflowMarkerOwned = $false
        $script:workflowMarkerNonce = $null
        return $true
    }
    catch {
        return $false
    }
}

function Assert-OwnedWorkflowMarker {
    param([Parameter(Mandatory)] [string]$Step)

    if (-not (Test-OwnedWorkflowMarker)) {
        Stop-Gate -Message 'The verification workflow marker is missing or its ownership receipt changed.' -Step $Step
    }
}

function Reset-EvidenceWriterLeaseState {
    $script:evidenceLeaseOwned = $false
    $script:evidenceLeaseNonce = $null
    $script:evidenceLeaseReceiptValidated = $false
    $script:evidencePassPairInvalidated = $false
}

function Test-ExactOwnedEvidenceWriterReceipt {
    if (-not $script:evidenceLeaseOwned -or
        [string]::IsNullOrEmpty($script:evidenceLeaseNonce) -or
        $script:evidenceLeaseNonce -cnotmatch '^[0-9a-f]{32}$' -or
        -not (Test-SafeArtifactLeaf -Path $evidenceLeasePath)) {
        return $false
    }

    $stream = $null
    try {
        $expected = [System.Text.Encoding]::ASCII.GetBytes("$($script:evidenceLeaseNonce)`n")
        $stream = [System.IO.File]::Open(
            $evidenceLeasePath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::Read)
        if ($stream.Length -ne $expected.Length) {
            return $false
        }
        for ($index = 0; $index -lt $expected.Length; $index++) {
            if ($stream.ReadByte() -ne $expected[$index]) {
                return $false
            }
        }
        return ($stream.ReadByte() -eq -1)
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $stream) {
            try { $stream.Dispose() } catch { }
        }
    }
}

function Test-EvidencePassPairAbsent {
    foreach ($priorPassPath in @($auditSidecarPath, $auditPath)) {
        if ([System.IO.File]::Exists($priorPassPath) -or
            [System.IO.Directory]::Exists($priorPassPath)) {
            return $false
        }
    }
    return $true
}

function Test-EvidenceWriterLeasePublicationAuthority {
    return ($script:evidenceLeaseOwned -and
        $script:evidenceLeaseReceiptValidated -and
        $script:evidencePassPairInvalidated -and
        (Test-ExactOwnedEvidenceWriterReceipt) -and
        (Test-EvidencePassPairAbsent))
}

function Exit-EvidenceWriterLease {
    if (-not $script:evidenceLeaseOwned) {
        return ([string]::IsNullOrEmpty($script:evidenceLeaseNonce) -and
            -not $script:evidenceLeaseReceiptValidated -and
            -not $script:evidencePassPairInvalidated)
    }
    if (-not (Test-ExactOwnedEvidenceWriterReceipt)) {
        return $false
    }

    try {
        [System.IO.File]::Delete($evidenceLeasePath)
        if ([System.IO.File]::Exists($evidenceLeasePath) -or
            [System.IO.Directory]::Exists($evidenceLeasePath)) {
            return $false
        }
        Reset-EvidenceWriterLeaseState
        return $true
    }
    catch {
        return $false
    }
}

function Enter-EvidenceWriterLease {
    if ($script:evidenceLeaseOwned) {
        return (Test-EvidenceWriterLeasePublicationAuthority)
    }
    if (-not [string]::IsNullOrEmpty($script:evidenceLeaseNonce) -or
        $script:evidenceLeaseReceiptValidated -or
        $script:evidencePassPairInvalidated -or
        -not (Test-SafeArtifactDirectory -Path $evidenceRoot -Create) -or
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
        $script:evidenceLeaseOwned = $true
        $script:evidenceLeaseNonce = $nonce
        $bytes = [System.Text.Encoding]::ASCII.GetBytes("$nonce`n")
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
        $stream.Dispose()
        $stream = $null
        if (-not (Test-ExactOwnedEvidenceWriterReceipt)) {
            return $false
        }
        $script:evidenceLeaseReceiptValidated = $true

        foreach ($priorPassPath in @($auditSidecarPath, $auditPath)) {
            if ([System.IO.Directory]::Exists($priorPassPath) -or
                ([System.IO.File]::Exists($priorPassPath) -and
                    -not (Test-SafeArtifactLeaf -Path $priorPassPath))) {
                return $false
            }
        }
        foreach ($priorPassPath in @($auditSidecarPath, $auditPath)) {
            if ([System.IO.File]::Exists($priorPassPath)) {
                [System.IO.File]::Delete($priorPassPath)
            }
        }
        if (-not (Test-EvidencePassPairAbsent)) {
            return $false
        }
        $script:evidencePassPairInvalidated = $true
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
        if (-not $entered -and $script:evidenceLeaseOwned -and
            (Test-ExactOwnedEvidenceWriterReceipt)) {
            [void](Exit-EvidenceWriterLease)
        }
    }
}

function Stop-Gate {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [int]$ExitCode = 1,
        [AllowEmptyString()] [string]$Output = '',
        [string]$Step = 'wrapper',
        [string[]]$Argv = @()
    )

    if ($ExitCode -eq 0) {
        $ExitCode = 1
    }

    if ($script:stopGateActive) {
        [Console]::Error.WriteLine("FAIL $gateId exit=$script:stopGateExitCode evidence=none")
        exit $script:stopGateExitCode
    }
    $script:stopGateActive = $true
    $script:stopGateExitCode = $ExitCode

    $wrotePacket = $false
    $relativePacket = 'none'
    $leaseAcquired = $false
    try {
        if (-not (Enter-EvidenceWriterLease)) {
            throw 'The shared evidence writer lease is unavailable.'
        }
        if (-not (Test-EvidenceWriterLeasePublicationAuthority)) {
            throw 'The shared evidence writer lease lacks publication authority.'
        }
        $leaseAcquired = $true
        if (-not (Test-SafeArtifactDirectory -Path $failureRoot -Create)) {
            throw 'Failure evidence directory is unsafe.'
        }
        $packetPath = Join-Path $failureRoot "$gateId.txt"
        if (-not (Test-SafeArtifactLeaf -Path $packetPath -AllowMissing -CreateParent)) {
            throw 'Failure evidence leaf is unsafe.'
        }
        $boundedOutput = ((Protect-Text $Output) -split "`r?`n" | Where-Object { $_ -ne '' } | Select-Object -First 40) -join "`n"
        $head = 'unknown'
        try {
            $headResult = Invoke-BoundedProcess -FileName 'git' -Arguments @('-C', $repositoryRoot, 'rev-parse', '--verify', 'HEAD') -WorkingDirectory $repositoryRoot -Environment @{} -Timeout 10
            if ($headResult.ExitCode -eq 0) {
                $head = $headResult.StdOut.Trim()
            }
        }
        catch {
            # Failure reporting must not hide the original gate error.
        }
        $packet = @(
            "gate=$gateId"
            "step=$Step"
            'criterion=LNX-001,LNX-002,LNX-003,LNX-004,LNX-018'
            "exit=$ExitCode"
            "base=$BaseCommit"
            "head=$head"
            "message=$(Protect-Text $Message)"
            "argv=$(Protect-Text ($Argv | ConvertTo-Json -Compress))"
            'replay=pwsh -NoProfile -NonInteractive -File CrossPlatform/eng/Verify.ps1'
            'output_begin'
            $boundedOutput
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
        if ($leaseAcquired -and
            $script:workflowMarkerOwned -and
            -not $script:preserveWorkflowMarker -and
            -not (Remove-OwnedWorkflowMarker)) {
            $wrotePacket = $false
            $relativePacket = 'none'
        }
        if ($leaseAcquired -and -not (Exit-EvidenceWriterLease)) {
            $wrotePacket = $false
            $relativePacket = 'none'
        }
    }
    [Console]::Error.WriteLine("FAIL $gateId exit=$ExitCode evidence=$(if ($wrotePacket) { $relativePacket } else { 'none' })")
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
        Stop-Gate -Message 'The prior wrapper failure packet is not a safe regular leaf.'
    }
    [System.IO.File]::Delete($matches[0].FullName)
    $remaining = @(Get-ChildItem -LiteralPath $failureRoot -Force | Where-Object {
            [string]::Equals($_.Name, $leafName, [System.StringComparison]::Ordinal)
        })
    if ($remaining.Count -ne 0) {
        Stop-Gate -Message 'The prior wrapper failure packet could not be removed after success.'
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
    foreach ($entry in $Environment.GetEnumerator()) {
        $startInfo.Environment[[string]$entry.Key] = [string]$entry.Value
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $stdoutMemory = [System.IO.MemoryStream]::new()
    $stderrMemory = [System.IO.MemoryStream]::new()
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
            if ($outputOverflow -and -not $terminationRequested) {
                $terminationRequested = $true
                $terminationDeadline = [System.DateTime]::UtcNow.AddSeconds(10)
                if (-not $process.HasExited) {
                    try { $process.Kill($true) } catch { }
                }
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

function Save-StepLog {
    param(
        [Parameter(Mandatory)] [string]$Step,
        [Parameter(Mandatory)] [object]$Result
    )

    $logPath = Join-Path $logRoot "$gateId-$Step.log"
    $content = Protect-Text ($Result.StdOut + $Result.StdErr)
    Write-Utf8File -Path $logPath -Content ($content.TrimEnd() + "`n")
    return $logPath
}

function Invoke-RequiredStep {
    param(
        [Parameter(Mandatory)] [string]$Step,
        [Parameter(Mandatory)] [string]$FileName,
        [Parameter(Mandatory)] [string[]]$Arguments,
        [Parameter(Mandatory)] [int]$Timeout,
        [hashtable]$Environment = @{},
        [string]$SuccessPattern = ''
    )

    Assert-OwnedWorkflowMarker -Step $Step
    $result = Invoke-BoundedProcess -FileName $FileName -Arguments $Arguments -WorkingDirectory $crossPlatformRoot -Environment $Environment -Timeout $Timeout
    Assert-OwnedWorkflowMarker -Step $Step
    Save-StepLog -Step $Step -Result $result | Out-Null
    if ($result.ExitCode -ne 0) {
        Stop-Gate -Message "Required step '$Step' failed." -ExitCode $result.ExitCode -Output ($result.StdOut + $result.StdErr) -Step $Step -Argv (@([System.IO.Path]::GetFileName($FileName)) + $Arguments)
    }
    if (-not [string]::IsNullOrWhiteSpace($SuccessPattern)) {
        $compactOutput = $result.StdOut.TrimEnd([char[]]"`r`n")
        $matches = [regex]::Matches($compactOutput, $SuccessPattern)
        if ($matches.Count -ne 1 -or -not [string]::IsNullOrWhiteSpace($result.StdErr)) {
            Stop-Gate -Message "Required step '$Step' did not emit its one exact compact PASS line." -Output ($result.StdOut + $result.StdErr) -Step $Step -Argv (@([System.IO.Path]::GetFileName($FileName)) + $Arguments)
        }
    }
    return $result
}

function Test-DescendantPath {
    param(
        [Parameter(Mandatory)] [string]$Candidate,
        [Parameter(Mandatory)] [string]$Parent
    )

    $comparison = if ($IsWindows) { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }
    $prefix = $Parent.TrimEnd([char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)) + [System.IO.Path]::DirectorySeparatorChar
    return $Candidate.StartsWith($prefix, $comparison)
}

function Assert-NoReparseComponents {
    param([Parameter(Mandatory)] [string]$Path)

    $target = [System.IO.Path]::GetFullPath($Path)
    if ($target -ne $crossPlatformRoot -and
        -not (Test-DescendantPath -Candidate $target -Parent $crossPlatformRoot)) {
        Stop-Gate -Message 'A verification path escapes the CrossPlatform subtree.'
    }
    $relative = [System.IO.Path]::GetRelativePath($crossPlatformRoot, $target)
    $current = $crossPlatformRoot
    foreach ($component in $relative.Split(
            [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar),
            [System.StringSplitOptions]::RemoveEmptyEntries)) {
        $current = Join-Path $current $component
        if (-not (Test-Path -LiteralPath $current)) {
            break
        }
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            Stop-Gate -Message "A verification path resolves through a reparse point: $([System.IO.Path]::GetRelativePath($crossPlatformRoot, $current).Replace('\', '/'))"
        }
    }
}

trap {
    Stop-Gate `
        -Message "Unexpected verification-wrapper error at line $($_.InvocationInfo.ScriptLineNumber)." `
        -Output "$($_.Exception.GetType().Name): $($_.Exception.Message)"
}

Assert-RedactionSelfTests
if ([System.IO.File]::Exists($workflowMarkerPath) -or
    [System.IO.Directory]::Exists($workflowMarkerPath)) {
    Stop-Gate -Message 'Another verification wrapper is active, or its workflow marker requires manual recovery.' -Step 'wrapper-marker'
}
if (-not (Enter-EvidenceWriterLease)) {
    Stop-Gate -Message 'The shared evidence writer lease is unavailable for workflow startup.' -Step 'wrapper-marker'
}
$workflowMarkerCreated = $false
$startupLeaseReleased = $false
try {
    $workflowMarkerCreated = New-WorkflowMarker
}
finally {
    $startupLeaseReleased = Exit-EvidenceWriterLease
}
if (-not $workflowMarkerCreated) {
    Stop-Gate -Message 'The verification workflow marker could not be created with an exact ownership receipt.' -Step 'wrapper-marker'
}
if (-not $startupLeaseReleased) {
    Stop-Gate -Message 'The shared evidence writer lease could not be released after workflow startup.' -Step 'wrapper-marker'
}
Assert-OwnedWorkflowMarker -Step 'wrapper-marker'

foreach ($directory in @(
        $artifactsRoot,
        $evidenceRoot,
        $failureRoot,
        $logRoot,
        $publishRoot,
        $packagesRoot,
        (Join-Path $artifactsRoot 'dotnet-cli-home'),
        (Join-Path $artifactsRoot 'nuget-configuration-defaults'),
        (Join-Path $artifactsRoot 'nuget-http-cache'),
        (Join-Path $artifactsRoot 'nuget-plugin-cache'),
        (Join-Path $artifactsRoot 'nuget-scratch'),
        $temporaryRoot)) {
    Assert-NoReparseComponents $directory
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    Assert-NoReparseComponents $directory
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

$pwshCommand = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue
if ($null -eq $pwshCommand) {
    Stop-Gate -Message 'pwsh is unavailable.' -ExitCode 127
}
$dotnetCommand = Get-Command dotnet -CommandType Application -ErrorAction SilentlyContinue
if ($null -eq $dotnetCommand) {
    Stop-Gate -Message 'dotnet is unavailable.' -ExitCode 127
}
$gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue
if ($null -eq $gitCommand) {
    Stop-Gate -Message 'git is unavailable.' -ExitCode 127
}
if ($IsWindows) {
    $cleanToolDirectories = @(
        (Split-Path -Parent $pwshCommand.Source),
        (Split-Path -Parent $dotnetCommand.Source),
        (Split-Path -Parent $gitCommand.Source),
        [Environment]::SystemDirectory
    ) | Select-Object -Unique
    $environment['PATH'] = $cleanToolDirectories -join [System.IO.Path]::PathSeparator
}

$steps = [System.Collections.Generic.List[object]]::new()
$staticArguments = @('-NoProfile', '-NonInteractive', '-File', (Join-Path $PSScriptRoot 'Verify-Static.ps1'), '-BaseCommit', $BaseCommit)
$staticResult = Invoke-RequiredStep -Step 'static' -FileName $pwshCommand.Source -Arguments $staticArguments -Timeout 60 -Environment $environment -SuccessPattern '^PASS port-static checks=[0-9]+ elapsed_ms=[0-9]+ evidence=artifacts/evidence/static-gate\.json\s*$'
$steps.Add([ordered]@{ id = 'port-static'; exit = 0 })

$restoreArguments = @('-NoProfile', '-NonInteractive', '-File', (Join-Path $PSScriptRoot 'Restore.ps1'))
if ($InitialRestore) {
    $restoreArguments += '-Initial'
}
$restoreGate = if ($InitialRestore) { 'port-restore-initial' } else { 'port-restore' }
$restoreResult = Invoke-RequiredStep -Step 'restore' -FileName $pwshCommand.Source -Arguments $restoreArguments -Timeout 650 -Environment $environment -SuccessPattern "^PASS $restoreGate checks=[0-9]+ elapsed_ms=[0-9]+ evidence=artifacts/evidence/dependency-closure\.json\s*$"
$steps.Add([ordered]@{ id = $restoreGate; exit = 0 })
if ($InitialRestore) {
    Invoke-RequiredStep -Step 'static-after-locks' -FileName $pwshCommand.Source -Arguments $staticArguments -Timeout 60 -Environment $environment -SuccessPattern '^PASS port-static checks=[0-9]+ elapsed_ms=[0-9]+ evidence=artifacts/evidence/static-gate\.json\s*$' | Out-Null
    $steps.Add([ordered]@{ id = 'port-static-after-locks'; exit = 0 })
}

$buildResults = @{}
foreach ($configuration in @('Debug', 'Release')) {
    $step = "build-$($configuration.ToLowerInvariant())"
    $arguments = @(
        'build', 'StaxRip.CrossPlatform.slnx',
        '--configuration', $configuration,
        '--no-restore',
        '--no-incremental',
        '--warnaserror',
        '--nologo',
        '--disable-build-servers'
    )
    $buildResults[$configuration] = Invoke-RequiredStep -Step $step -FileName $dotnetCommand.Source -Arguments $arguments -Timeout 180 -Environment $environment
    $steps.Add([ordered]@{ id = "port-build-$($configuration.ToLowerInvariant())"; exit = 0 })
}

$manifestPath = Join-Path $crossPlatformRoot 'tests\StaxRip.ContractTests\TEST-CASE-MANIFEST.txt'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    Stop-Gate -Message 'Contract case manifest is missing.' -Step 'contract'
}
$manifestCaseCount = @([System.IO.File]::ReadAllLines($manifestPath) | Where-Object { $_ -ne '' -and -not $_.StartsWith('#', [System.StringComparison]::Ordinal) }).Count
if ($manifestCaseCount -ne 56) {
    Stop-Gate -Message "Contract case manifest count differs from the reviewed baseline of 56: $manifestCaseCount" -Step 'contract'
}

$contractCounts = @{}
$contractPattern = '^PASS port-contract cases=(61) assertions=(747) failures=0 elapsed_ms=[0-9]+\s*$'
foreach ($configuration in @('Debug', 'Release')) {
    $step = "contract-$($configuration.ToLowerInvariant())"
    $arguments = @(
        'run',
        '--project', 'tests/StaxRip.ContractTests/StaxRip.ContractTests.csproj',
        '--configuration', $configuration,
        '--no-build',
        '--no-restore',
        '--', '--concise'
    )
    $result = Invoke-RequiredStep -Step $step -FileName $dotnetCommand.Source -Arguments $arguments -Timeout 120 -Environment $environment -SuccessPattern $contractPattern
    $match = [regex]::Match($result.StdOut.TrimEnd([char[]]"`r`n"), $contractPattern)
    $caseCount = [int]$match.Groups[1].Value
    $assertionCount = [int]$match.Groups[2].Value
    if ($caseCount -ne $manifestCaseCount -or $assertionCount -ne 747) {
        Stop-Gate -Message "Contract $configuration counts do not match the reviewed 61-case, 747-assertion baseline." -Output $result.StdOut -Step $step
    }
    $contractCounts[$configuration] = [pscustomobject]@{ Cases = $caseCount; Assertions = $assertionCount }
    $steps.Add([ordered]@{ id = "port-contract-$($configuration.ToLowerInvariant())"; exit = 0; cases = $caseCount; assertions = $assertionCount })
}
if ($contractCounts.Debug.Cases -ne $contractCounts.Release.Cases -or $contractCounts.Debug.Assertions -ne $contractCounts.Release.Assertions) {
    Stop-Gate -Message 'Debug and Release contract counts differ.' -Step 'contract'
}

$failureArguments = @(
    'run',
    '--project', 'tests/StaxRip.ContractTests/StaxRip.ContractTests.csproj',
    '--configuration', 'Release',
    '--no-build',
    '--no-restore',
    '--', '--self-test-failure'
)
Assert-OwnedWorkflowMarker -Step 'contract-failure'
$failureResult = Invoke-BoundedProcess -FileName $dotnetCommand.Source -Arguments $failureArguments -WorkingDirectory $crossPlatformRoot -Environment $environment -Timeout 30
Assert-OwnedWorkflowMarker -Step 'contract-failure'
Save-StepLog -Step 'contract-failure' -Result $failureResult | Out-Null
$expectedFailureLine = 'FAIL port-contract case=HARNESS-FAILURE type=TestFailureException message=forced failure did not fail; expected=1 actual=2'
if ($failureResult.ExitCode -ne 1 -or
    -not [string]::IsNullOrWhiteSpace($failureResult.StdOut) -or
    $failureResult.StdErr.TrimEnd([char[]]"`r`n") -cne $expectedFailureLine) {
    Stop-Gate -Message 'Forced-failure self-test did not produce the exact reviewed exit and bounded output.' -Output ($failureResult.StdOut + $failureResult.StdErr) -Step 'contract-failure' -Argv (@('dotnet') + $failureArguments)
}
$steps.Add([ordered]@{ id = 'port-contract-failure'; exit = $failureResult.ExitCode; expected_nonzero = $true })

$publishedRelative = $null
$artifactManifestRelative = $null
if ($IncludeLinuxPublish) {
    if ([string]::IsNullOrWhiteSpace($PublishDirectory)) {
        $PublishDirectory = Join-Path $publishRoot 'linux-x64'
    }
    $PublishDirectory = [System.IO.Path]::GetFullPath($PublishDirectory)
    if (-not (Test-DescendantPath -Candidate $PublishDirectory -Parent $publishRoot)) {
        Stop-Gate -Message 'Linux publish output must stay below CrossPlatform/artifacts/publish/.' -Step 'publish-linux'
    }
    if (Test-Path -LiteralPath $PublishDirectory) {
        Assert-NoReparseComponents $PublishDirectory
        $publishItem = Get-Item -LiteralPath $PublishDirectory -Force
        if (($publishItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            Stop-Gate -Message 'Linux publish output is a reparse point.' -Step 'publish-linux'
        }
        if (@(Get-ChildItem -LiteralPath $PublishDirectory -Force).Count -ne 0) {
            Stop-Gate -Message 'Linux publish output is not empty. Pass a new empty path; the gate does not delete prior evidence.' -Step 'publish-linux'
        }
    }
    else {
        Assert-NoReparseComponents $PublishDirectory
        [System.IO.Directory]::CreateDirectory($PublishDirectory) | Out-Null
        Assert-NoReparseComponents $PublishDirectory
    }

    $publishArguments = @(
        'publish', 'src/StaxRip.Server/StaxRip.Server.csproj',
        '--configuration', 'Release',
        '--runtime', 'linux-x64',
        '--self-contained', 'true',
        '--no-restore',
        '--output', $PublishDirectory,
        '--nologo',
        '--disable-build-servers'
    )
    Assert-NoReparseComponents $publishRoot
    Assert-NoReparseComponents $PublishDirectory
    Invoke-RequiredStep -Step 'publish-linux' -FileName $dotnetCommand.Source -Arguments $publishArguments -Timeout 300 -Environment $environment | Out-Null
    $launcherPath = Join-Path $PublishDirectory 'StaxRip.Server'
    if (-not (Test-Path -LiteralPath $launcherPath -PathType Leaf)) {
        Stop-Gate -Message 'Linux publish output lacks the StaxRip.Server launcher.' -Step 'publish-linux'
    }

    $artifactManifestPath = Join-Path $evidenceRoot 'artifact-linux-x64.tsv'
    $manifestArguments = @(
        '-NoProfile', '-NonInteractive', '-File', (Join-Path $PSScriptRoot 'Write-ArtifactManifest.ps1'),
        '-Root', $PublishDirectory,
        '-OutputPath', $artifactManifestPath,
        '-WslDistribution', $WslDistribution
    )
    if (-not $IsWindows) {
        Stop-Gate -Message 'This slice records canonical Linux modes through the reviewed Ubuntu WSL boundary.' -Step 'artifact-manifest'
    }
    $manifestArguments += @('-ModeSource', 'Wsl')
    Invoke-RequiredStep -Step 'artifact-manifest' -FileName $pwshCommand.Source -Arguments $manifestArguments -Timeout 120 -Environment $environment -SuccessPattern '^PASS port-artifact-manifest checks=[0-9]+ elapsed_ms=[0-9]+ evidence=CrossPlatform/artifacts/evidence/artifact-linux-x64\.tsv\s*$' | Out-Null
    $publishedRelative = [System.IO.Path]::GetRelativePath($crossPlatformRoot, $PublishDirectory).Replace('\', '/')
    $artifactManifestRelative = 'artifacts/evidence/artifact-linux-x64.tsv'
    $steps.Add([ordered]@{ id = 'port-publish-linux'; exit = 0 })
    $steps.Add([ordered]@{ id = 'port-artifact-manifest'; exit = 0 })
}

Assert-OwnedWorkflowMarker -Step 'wrapper-publication'
$headResult = Invoke-BoundedProcess -FileName $gitCommand.Source -Arguments @('-C', $repositoryRoot, 'rev-parse', '--verify', 'HEAD') -WorkingDirectory $repositoryRoot -Environment $environment -Timeout 10
Assert-OwnedWorkflowMarker -Step 'wrapper-publication'
$head = if ($headResult.ExitCode -eq 0) { $headResult.StdOut.Trim() } else { 'unknown' }
$staticRecordPath = Join-Path $evidenceRoot 'static-gate.json'
$dependencyRecordPath = Join-Path $evidenceRoot 'dependency-closure.json'
$summaryPath = Join-Path $evidenceRoot 'verify-summary.json'
if (-not (Enter-EvidenceWriterLease)) {
    $script:preserveWorkflowMarker = $true
    Stop-Gate -Message 'The shared evidence writer lease is unavailable for wrapper publication.'
}
$publicationSucceeded = $false
$workflowMarkerRemoved = $false
$leaseReleased = $false
try {
    $summary = [ordered]@{
        schema = 'staxrip-port-verify-v1'
        base = $BaseCommit
        head = $head
        steps = $steps
        source_record_sha256 = Get-Sha256 $staticRecordPath
        dependency_record_sha256 = Get-Sha256 $dependencyRecordPath
        publish_root = $publishedRelative
        artifact_manifest = if ($null -ne $artifactManifestRelative) {
            [ordered]@{
                path = $artifactManifestRelative
                sha256 = Get-Sha256 (Join-Path $crossPlatformRoot $artifactManifestRelative)
            }
        }
        else {
            $null
        }
    }
    Write-Utf8File -Path $summaryPath -Content (ConvertTo-CanonicalJson -InputObject $summary -Depth 10)
    Remove-OwnFailurePacket
    $workflowMarkerRemoved = Remove-OwnedWorkflowMarker
    if (-not $workflowMarkerRemoved) {
        throw 'The verification workflow marker could not be removed with its exact ownership receipt.'
    }
    $publicationSucceeded = $true
}
finally {
    $leaseReleased = Exit-EvidenceWriterLease
}
if (-not $publicationSucceeded) {
    Stop-Gate -Message 'Wrapper evidence publication did not complete.'
}
if (-not $workflowMarkerRemoved) {
    Stop-Gate -Message 'The verification workflow marker was not removed after wrapper publication.'
}
if (-not $leaseReleased) {
    Stop-Gate -Message 'The shared evidence writer lease could not be released after wrapper publication.'
}
$timer.Stop()
$checks = $steps.Count + $contractCounts.Debug.Assertions + $contractCounts.Release.Assertions
[Console]::Out.WriteLine("PASS $gateId checks=$checks elapsed_ms=$($timer.ElapsedMilliseconds) evidence=artifacts/evidence/verify-summary.json")
exit 0
