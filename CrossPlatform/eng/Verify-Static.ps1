[CmdletBinding()]
param(
    [string]$BaseCommit = '940eaba1134e52260a74cb452a86e3e243ed76c9',
    [ValidateRange(10, 300)]
    [int]$TimeoutSeconds = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gateId = 'port-static'
$timer = [System.Diagnostics.Stopwatch]::StartNew()
$script:Stopping = $false
$script:StopExitCode = 1
$defaultBaseCommit = '940eaba1134e52260a74cb452a86e3e243ed76c9'
$crossPlatformRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $crossPlatformRoot '..'))
$artifactsRoot = Join-Path $crossPlatformRoot 'artifacts'
$evidenceRoot = Join-Path $artifactsRoot 'evidence'
$failureRoot = Join-Path $artifactsRoot 'failures'
$auditPath = Join-Path $evidenceRoot 'evidence-audit.json'
$auditSidecarPath = Join-Path $evidenceRoot 'evidence-audit.json.sha256'
$evidenceLeasePath = Join-Path $evidenceRoot '.evidence-writer.lock'
$emptySha256 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
$script:EvidenceLeaseOwned = $false
$script:EvidenceLeaseNonce = $null
$script:EvidenceLeaseReceiptValidated = $false
$script:EvidencePassPairInvalidated = $false

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
    param(
        [Parameter(Mandatory)] [string]$Path,
        [string]$AllowedRoot = $crossPlatformRoot
    )

    if (-not (Test-SafeExistingLeaf -Path $Path -AllowedRoot $AllowedRoot)) {
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
        $artifactPrefix = $artifactsRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) +
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
                if (-not (Test-Path -LiteralPath $current)) {
                    break
                }
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

function Reset-EvidenceWriterLeaseState {
    $script:EvidenceLeaseOwned = $false
    $script:EvidenceLeaseNonce = $null
    $script:EvidenceLeaseReceiptValidated = $false
    $script:EvidencePassPairInvalidated = $false
}

function Test-ExactOwnedEvidenceWriterReceipt {
    if (-not $script:EvidenceLeaseOwned -or
        [string]::IsNullOrEmpty($script:EvidenceLeaseNonce) -or
        $script:EvidenceLeaseNonce -cnotmatch '^[0-9a-f]{32}$' -or
        -not (Test-SafeExistingLeaf -Path $evidenceLeasePath -AllowedRoot $evidenceRoot)) {
        return $false
    }

    $stream = $null
    try {
        $expected = [System.Text.Encoding]::ASCII.GetBytes("$($script:EvidenceLeaseNonce)`n")
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
    return ($script:EvidenceLeaseOwned -and
        $script:EvidenceLeaseReceiptValidated -and
        $script:EvidencePassPairInvalidated -and
        (Test-ExactOwnedEvidenceWriterReceipt) -and
        (Test-EvidencePassPairAbsent))
}

function Exit-EvidenceWriterLease {
    if (-not $script:EvidenceLeaseOwned) {
        return ([string]::IsNullOrEmpty($script:EvidenceLeaseNonce) -and
            -not $script:EvidenceLeaseReceiptValidated -and
            -not $script:EvidencePassPairInvalidated)
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
    if ($script:EvidenceLeaseOwned) {
        return (Test-EvidenceWriterLeasePublicationAuthority)
    }
    if (-not [string]::IsNullOrEmpty($script:EvidenceLeaseNonce) -or
        $script:EvidenceLeaseReceiptValidated -or
        $script:EvidencePassPairInvalidated -or
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
        $script:EvidenceLeaseOwned = $true
        $script:EvidenceLeaseNonce = $nonce
        $bytes = [System.Text.Encoding]::ASCII.GetBytes("$nonce`n")
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
        $stream.Dispose()
        $stream = $null
        if (-not (Test-ExactOwnedEvidenceWriterReceipt)) {
            return $false
        }
        $script:EvidenceLeaseReceiptValidated = $true

        foreach ($priorPassPath in @($auditSidecarPath, $auditPath)) {
            if ([System.IO.Directory]::Exists($priorPassPath) -or
                ([System.IO.File]::Exists($priorPassPath) -and
                    -not (Test-SafeExistingLeaf -Path $priorPassPath -AllowedRoot $evidenceRoot))) {
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
        $script:EvidencePassPairInvalidated = $true
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
        if (-not $entered -and $script:EvidenceLeaseOwned -and
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
        if (-not (Test-EvidenceWriterLeasePublicationAuthority)) {
            throw [System.IO.IOException]::new('The shared evidence writer lease lacks publication authority.')
        }
        if (-not (Test-SafeArtifactDirectory -Path $failureRoot -Create)) {
            throw [System.IO.IOException]::new('Failure evidence directory is unsafe.')
        }
        $packetPath = Join-Path $failureRoot "$gateId.txt"
        $safeOutput = Protect-Text $Output
        $boundedOutput = ($safeOutput -split "`r?`n" | Where-Object { $_ -ne '' } | Select-Object -First 40) -join "`n"
        $head = 'unknown'
        try {
            $headResult = Invoke-BoundedProcess -FileName 'git' -Arguments @('-C', $repositoryRoot, 'rev-parse', '--verify', 'HEAD') -WorkingDirectory $repositoryRoot -Timeout 10
            if ($headResult.ExitCode -eq 0) { $head = $headResult.StdOut.Trim() }
        }
        catch { }
        $replayBase = if ($BaseCommit -cmatch '^[0-9a-f]{40}$') {
            $BaseCommit
        }
        else {
            $defaultBaseCommit
        }
        $packet = @(
            "gate=$gateId"
            'criterion=LNX-001,LNX-003,LNX-010,LNX-012,LNX-016'
            "exit=$ExitCode"
            "base=$(Protect-Text $BaseCommit)"
            "head=$head"
            "message=$(Protect-Text $Message)"
            "argv=$(Protect-Text ($Argv | ConvertTo-Json -Compress))"
            "replay=pwsh -NoProfile -NonInteractive -File CrossPlatform/eng/Verify-Static.ps1 -BaseCommit '$replayBase'"
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
        Stop-Gate -Message 'The prior static failure packet is not a safe regular leaf.'
    }
    [System.IO.File]::Delete($matches[0].FullName)
    $remaining = @(Get-ChildItem -LiteralPath $failureRoot -Force | Where-Object {
            [string]::Equals($_.Name, $leafName, [System.StringComparison]::Ordinal)
        })
    if ($remaining.Count -ne 0) {
        Stop-Gate -Message 'The prior static failure packet could not be removed after success.'
    }
}

function Invoke-BoundedProcess {
    param(
        [Parameter(Mandatory)] [string]$FileName,
        [Parameter(Mandatory)] [string[]]$Arguments,
        [Parameter(Mandatory)] [string]$WorkingDirectory,
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
    foreach ($name in [string[]]@($startInfo.Environment.Keys)) {
        if ($name.StartsWith('GIT_', [System.StringComparison]::OrdinalIgnoreCase)) {
            $startInfo.Environment.Remove($name) | Out-Null
        }
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

function Invoke-Git {
    param([Parameter(Mandatory)] [string[]]$Arguments)

    $result = Invoke-BoundedProcess -FileName 'git' -Arguments (@('-C', $repositoryRoot) + $Arguments) -WorkingDirectory $repositoryRoot -Timeout $TimeoutSeconds
    if ($result.ExitCode -ne 0) {
        Stop-Gate -Message "git $($Arguments[0]) failed." -ExitCode $result.ExitCode -Output ($result.StdOut + $result.StdErr) -Argv (@('git', '-C', '<repository>') + $Arguments)
    }
    return $result.StdOut
}

function Split-NullOutput {
    param([AllowEmptyString()] [string]$Text)
    if ([string]::IsNullOrEmpty($Text)) {
        return @()
    }
    return @($Text.Split([char]0, [System.StringSplitOptions]::RemoveEmptyEntries))
}

function Sort-Ordinal {
    param([object[]]$Values)
    $strings = [string[]]@($Values | ForEach-Object { [string]$_ })
    [System.Array]::Sort($strings, [System.StringComparer]::Ordinal)
    return $strings
}

function Assert-EqualSet {
    param(
        [Parameter(Mandatory)] [string]$Label,
        [object[]]$Actual,
        [object[]]$Expected
    )

    $actualSorted = @(Sort-Ordinal $Actual)
    $expectedSorted = @(Sort-Ordinal $Expected)
    if ($actualSorted.Count -ne $expectedSorted.Count) {
        Stop-Gate -Message "$Label count differs. Expected $($expectedSorted.Count), actual $($actualSorted.Count)." -Output "expected=$($expectedSorted -join ', ')`nactual=$($actualSorted -join ', ')"
    }
    for ($index = 0; $index -lt $expectedSorted.Count; $index++) {
        if (-not [string]::Equals($actualSorted[$index], $expectedSorted[$index], [System.StringComparison]::Ordinal)) {
            Stop-Gate -Message "$Label differs." -Output "expected=$($expectedSorted -join ', ')`nactual=$($actualSorted -join ', ')"
        }
    }
}

function Get-CrossPlatformRelativePath {
    param([Parameter(Mandatory)] [string]$Path)
    return [System.IO.Path]::GetRelativePath($crossPlatformRoot, $Path).Replace('\', '/')
}

function Test-IsGeneratedBuildPath {
    param([Parameter(Mandatory)] [string]$Path)

    $relative = Get-CrossPlatformRelativePath $Path
    return $relative -eq 'artifacts' -or
        $relative.StartsWith('artifacts/', [System.StringComparison]::OrdinalIgnoreCase) -or
        $relative -match '(^|/)(?:bin|obj)(?:/|$)'
}

function Get-SourceScopeItems {
    $pending = [System.Collections.Generic.Queue[System.IO.DirectoryInfo]]::new()
    $pending.Enqueue((Get-Item -LiteralPath $crossPlatformRoot -Force))
    while ($pending.Count -gt 0) {
        $directory = $pending.Dequeue()
        foreach ($item in @(Get-ChildItem -LiteralPath $directory.FullName -Force)) {
            if (Test-IsGeneratedBuildPath $item.FullName) {
                continue
            }
            Write-Output $item
            if ($item.PSIsContainer -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
                $pending.Enqueue([System.IO.DirectoryInfo]$item)
            }
        }
    }
}

function Read-Text {
    param([Parameter(Mandatory)] [string]$Path)

    if (-not (Test-SafeExistingLeaf -Path $Path -AllowedRoot $repositoryRoot)) {
        Stop-Gate -Message 'A text input is missing, case-mismatched, or resolves through a reparse point.'
    }
    return [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false, $true))
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

function Read-StrictXml {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Label
    )

    $text = Read-Text $Path
    $settings = [System.Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $settings.IgnoreComments = $false
    $settings.IgnoreProcessingInstructions = $false
    $settings.IgnoreWhitespace = $false
    $stringReader = [System.IO.StringReader]::new($text)
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

function Assert-ExactXmlScalar {
    param(
        [Parameter(Mandatory)] [System.Xml.XmlElement]$Element,
        [Parameter(Mandatory)] [string]$ExpectedValue,
        [Parameter(Mandatory)] [string]$Label
    )

    Assert-ExactXmlAttributes $Element @{} $Label
    if ($Element.ChildNodes.Count -ne 1 -or
        $Element.FirstChild.NodeType -ne [System.Xml.XmlNodeType]::Text -or
        [string]$Element.FirstChild.Value -cne $ExpectedValue) {
        Stop-Gate -Message "$Label is not the exact reviewed scalar XML value."
    }
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

function Resolve-SafeCrossPlatformLeaf {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$BaseDirectory,
        [Parameter(Mandatory)] [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or [System.IO.Path]::IsPathRooted($Path)) {
        Stop-Gate -Message "$Label is not a relative path."
    }
    $target = [System.IO.Path]::GetFullPath((Join-Path $BaseDirectory $Path))
    if (-not (Test-PathBelow -Candidate $target -Parent $crossPlatformRoot) -or
        -not (Test-SafeExistingLeaf -Path $target -AllowedRoot $crossPlatformRoot)) {
        Stop-Gate -Message "$Label escapes CrossPlatform, is case-mismatched, or resolves through a reparse point."
    }
    return $target
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
        $version = $values['version'].GetString()
        $rollForward = $values['rollForward'].GetString()
        $allowPrerelease = $values['allowPrerelease'].GetBoolean()
        if ($version -notmatch '^10\.0\.[0-9]{3}$' -or
            $rollForward -cne 'latestPatch' -or
            $allowPrerelease) {
            Stop-Gate -Message 'global.json must pin a stable .NET 10 SDK with latestPatch and no prerelease SDK.'
        }
        return [pscustomobject]@{
            Version = $version
            RollForward = $rollForward
            AllowPrerelease = $allowPrerelease
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

function Test-ExactCaseRepoPath {
    param([Parameter(Mandatory)] [string]$RelativePath)

    $current = $repositoryRoot
    foreach ($component in $RelativePath.Replace('\', '/').Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)) {
        $match = @(Get-ChildItem -LiteralPath $current -Force | Where-Object { [string]::Equals($_.Name, $component, [System.StringComparison]::Ordinal) })
        if ($match.Count -ne 1) {
            return $false
        }
        $current = $match[0].FullName
    }
    return $true
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

function Test-CanonicalRelativePath {
    param([AllowEmptyString()] [string]$Value)

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

function Test-SafeExistingRepoDirectory {
    param([Parameter(Mandatory)] [string]$Path)

    try {
        $target = [System.IO.Path]::GetFullPath($Path)
        if (-not [System.IO.Directory]::Exists($target)) {
            return $false
        }
        $relative = [System.IO.Path]::GetRelativePath($repositoryRoot, $target).Replace('\', '/')
        if ($relative -cne '.' -and -not (Test-CanonicalRelativePath $relative)) {
            return $false
        }
        if ($relative -cne '.' -and -not (Test-PathBelow -Candidate $target -Parent $repositoryRoot)) {
            return $false
        }
        $current = $repositoryRoot
        $components = if ($relative -ceq '.') { @() } else { $relative.Split('/') }
        foreach ($component in $components) {
            $matches = @(Get-ChildItem -LiteralPath $current -Force | Where-Object {
                    $_.Name.Equals($component, [System.StringComparison]::Ordinal)
                })
            if ($matches.Count -ne 1 -or -not $matches[0].PSIsContainer -or
                (($matches[0].Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
                return $false
            }
            $current = $matches[0].FullName
        }
        return $true
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

function Assert-ScopeCheck {
    param(
        [Parameter(Mandatory)] [bool]$Condition,
        [Parameter(Mandatory)] [string]$Id,
        [switch]$Uncounted
    )

    if (-not $Condition) {
        Stop-Gate -Message "Scope assertion failed: $Id"
    }
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

    $indexRows = @(Split-NullOutput (Invoke-Git @('ls-files', '--stage', '-z', '--')))
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

    $statusRows = @(Split-NullOutput (Invoke-Git @(
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
        committed = @(Split-NullOutput (Invoke-Git @(
                    'diff', '--no-ext-diff', '--no-textconv', '--no-renames',
                    '--name-only', '-z', "$BaseCommit..HEAD", '--')))
        staged = @(Split-NullOutput (Invoke-Git @(
                    'diff', '--no-ext-diff', '--no-textconv', '--no-renames',
                    '--cached', '--name-only', '-z', '--')))
        unstaged = @(Split-NullOutput (Invoke-Git @(
                    'diff', '--no-ext-diff', '--no-textconv', '--no-renames',
                    '--name-only', '-z', '--')))
        untracked = @(Split-NullOutput (Invoke-Git @(
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
            Assert-ScopeCheck (
                (Test-PathBelow -Candidate $fullPath -Parent $repositoryRoot)) `
                'scope-path-contained' -Uncounted:$Uncounted
            if ([System.IO.File]::Exists($fullPath)) {
                Assert-ScopeCheck (
                    (Test-SafeExistingLeaf -Path $fullPath -AllowedRoot $repositoryRoot)) `
                    'scope-file-safe' -Uncounted:$Uncounted
                $before = Get-Item -LiteralPath $fullPath -Force
                $sha256 = Get-Sha256 -Path $fullPath -AllowedRoot $repositoryRoot
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
                Assert-ScopeCheck (Test-SafeExistingRepoDirectory $ancestor.FullName) 'scope-deletion-parent-safe' -Uncounted:$Uncounted
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

trap {
    $failureLine = $_.InvocationInfo.ScriptLineNumber
    $failureType = $_.Exception.GetType().Name
    Stop-Gate `
        -Message "Unexpected static gate error at line $failureLine." `
        -Output "${failureType}: $($_.Exception.Message)"
}

Assert-RedactionSelfTests
if ($BaseCommit -cnotmatch '^[0-9a-f]{40}$') {
    Stop-Gate -Message 'BaseCommit is not one exact lowercase SHA-1 commit id.'
}
$baseCheck = Invoke-BoundedProcess -FileName 'git' -Arguments @('-C', $repositoryRoot, 'cat-file', '-e', "$BaseCommit^{commit}") -WorkingDirectory $repositoryRoot -Timeout 10
if ($baseCheck.ExitCode -ne 0) {
    Stop-Gate -Message 'BaseCommit is not a locally available commit.' -ExitCode $baseCheck.ExitCode -Output ($baseCheck.StdOut + $baseCheck.StdErr) -Argv @('git', '-C', '<repository>', 'cat-file', '-e', "$BaseCommit^{commit}")
}
$ancestorCheck = Invoke-BoundedProcess -FileName 'git' -Arguments @('-C', $repositoryRoot, 'merge-base', '--is-ancestor', $BaseCommit, 'HEAD') -WorkingDirectory $repositoryRoot -Timeout 10
if ($ancestorCheck.ExitCode -ne 0) {
    Stop-Gate -Message 'BaseCommit is not an ancestor of HEAD.' -ExitCode $ancestorCheck.ExitCode -Output ($ancestorCheck.StdOut + $ancestorCheck.StdErr) -Argv @('git', '-C', '<repository>', 'merge-base', '--is-ancestor', $BaseCommit, 'HEAD')
}

$head = (Invoke-Git @('rev-parse', '--verify', 'HEAD')).Trim()
if ($head -cnotmatch '^[0-9a-f]{40}$') {
    Stop-Gate -Message 'HEAD is not one exact lowercase SHA-1 commit id.'
}
$scopeSnapshot = Get-GitScopeSnapshot
$committed = [string[]]$scopeSnapshot.CategoryPaths['committed']
$staged = [string[]]$scopeSnapshot.CategoryPaths['staged']
$unstaged = [string[]]$scopeSnapshot.CategoryPaths['unstaged']
$untracked = [string[]]$scopeSnapshot.CategoryPaths['untracked']
$allChanged = [string[]]$scopeSnapshot.ChangedPaths

if (-not (Test-Path -LiteralPath $crossPlatformRoot -PathType Container)) {
    Stop-Gate -Message 'CrossPlatform root is missing.'
}
$sourceScopeItems = @(Get-SourceScopeItems)
$sourceScopeItemsWithRoot = @((Get-Item -LiteralPath $crossPlatformRoot -Force)) + $sourceScopeItems
foreach ($item in $sourceScopeItemsWithRoot) {
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        Stop-Gate -Message "CrossPlatform contains a reparse point: $(Get-CrossPlatformRelativePath $item.FullName)"
    }
}
$indexOutput = Invoke-Git @('ls-files', '--stage', '-z', '--', 'CrossPlatform')
foreach ($indexRow in @(Split-NullOutput $indexOutput)) {
    if ($indexRow.StartsWith('120000 ', [System.StringComparison]::Ordinal)) {
        Stop-Gate -Message 'CrossPlatform contains a tracked symbolic link.' -Output $indexRow
    }
}

$diffCheck = Invoke-BoundedProcess -FileName 'git' -Arguments @('-C', $repositoryRoot, 'diff', '--no-renames', '--check', $BaseCommit, '--') -WorkingDirectory $repositoryRoot -Timeout $TimeoutSeconds
if ($diffCheck.ExitCode -ne 0) {
    Stop-Gate -Message 'git diff --check found whitespace errors.' -ExitCode $diffCheck.ExitCode -Output ($diffCheck.StdOut + $diffCheck.StdErr) -Argv @('git', '-C', '<repository>', 'diff', '--no-renames', '--check', $BaseCommit, '--')
}

$textExtensions = @('.cs', '.csproj', '.props', '.targets', '.slnx', '.json', '.config', '.ps1', '.sh', '.html', '.css', '.js', '.md', '.txt', '.xml')
foreach ($path in $allChanged) {
    $fullPath = Join-Path $repositoryRoot $path
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        continue
    }
    if ($textExtensions -notcontains [System.IO.Path]::GetExtension($path).ToLowerInvariant()) {
        continue
    }
    if (-not (Test-SafeExistingLeaf -Path $fullPath -AllowedRoot $repositoryRoot)) {
        Stop-Gate -Message "Changed text path is missing, case-mismatched, or resolves through a reparse point: $path"
    }
    $bytes = [System.IO.File]::ReadAllBytes($fullPath)
    if ($bytes | Where-Object { $_ -gt 127 } | Select-Object -First 1) {
        Stop-Gate -Message "Changed text is not ASCII: $path"
    }
    if ($bytes.Count -gt 0 -and $bytes[$bytes.Count - 1] -ne 10) {
        Stop-Gate -Message "Changed text lacks a final newline: $path"
    }
    $text = [System.Text.Encoding]::ASCII.GetString($bytes)
    $lineNumber = 0
    foreach ($line in ($text -split "`n")) {
        $lineNumber++
        if ($line.TrimEnd("`r").Length -gt 0 -and $line.TrimEnd("`r") -match '[ \t]+$') {
            Stop-Gate -Message "Changed text has trailing whitespace: ${path}:$lineNumber"
        }
    }
}

$expectedProjects = @(
    'src/StaxRip.Contracts/StaxRip.Contracts.csproj',
    'src/StaxRip.Core/StaxRip.Core.csproj',
    'src/StaxRip.Platform/StaxRip.Platform.csproj',
    'src/StaxRip.Server/StaxRip.Server.csproj',
    'tests/StaxRip.ContractTests/StaxRip.ContractTests.csproj'
)
$globalJsonPath = Join-Path $crossPlatformRoot 'global.json'
Read-ExactGlobalJson $globalJsonPath | Out-Null

$solutionPath = Join-Path $crossPlatformRoot 'StaxRip.CrossPlatform.slnx'
if (-not (Test-SafeExistingLeaf -Path $solutionPath -AllowedRoot $crossPlatformRoot)) {
    Stop-Gate -Message 'Cross-platform solution is missing.'
}
try {
    $solutionXml = Read-StrictXml $solutionPath 'Cross-platform solution'
    $solutionRoot = $solutionXml.DocumentElement
    if ($solutionRoot.LocalName -cne 'Solution') {
        Stop-Gate -Message 'Cross-platform solution root must be Solution.'
    }
    Assert-ExactXmlAttributes $solutionRoot @{} 'Cross-platform solution root'
    $solutionFolders = @(Assert-ExactXmlChildNames $solutionRoot @('Folder', 'Folder') 'Cross-platform solution root')
    $expectedSolutionFolders = @(
        [pscustomobject]@{
            Name = '/src/'
            Projects = $expectedProjects[0..3]
        },
        [pscustomobject]@{
            Name = '/tests/'
            Projects = @($expectedProjects[4])
        }
    )
    $solutionProjects = [System.Collections.Generic.List[string]]::new()
    for ($folderIndex = 0; $folderIndex -lt $expectedSolutionFolders.Count; $folderIndex++) {
        $folder = $solutionFolders[$folderIndex]
        $expectedFolder = $expectedSolutionFolders[$folderIndex]
        Assert-ExactXmlAttributes $folder @{ Name = $expectedFolder.Name } "Solution folder $($expectedFolder.Name)"
        $expectedProjectNames = [string[]]@($expectedFolder.Projects | ForEach-Object { 'Project' })
        $projectNodes = @(Assert-ExactXmlChildNames $folder $expectedProjectNames "Solution folder $($expectedFolder.Name)")
        for ($projectIndex = 0; $projectIndex -lt $expectedFolder.Projects.Count; $projectIndex++) {
            $expectedProject = [string]$expectedFolder.Projects[$projectIndex]
            Assert-EmptyXmlElement $projectNodes[$projectIndex] @{ Path = $expectedProject } "Solution project $expectedProject"
            Resolve-SafeCrossPlatformLeaf $expectedProject $crossPlatformRoot "Solution project $expectedProject" | Out-Null
            $solutionProjects.Add($expectedProject)
        }
    }
}
catch {
    Stop-Gate -Message "Cross-platform solution XML is invalid: $($_.Exception.Message)"
}
Assert-EqualSet -Label 'solution project inventory' -Actual $solutionProjects.ToArray() -Expected $expectedProjects

$actualProjectFiles = @($sourceScopeItems | Where-Object {
        -not $_.PSIsContainer -and $_.Extension -in @('.csproj', '.fsproj', '.vbproj', '.vcxproj')
    } | ForEach-Object { Get-CrossPlatformRelativePath $_.FullName })
Assert-EqualSet -Label 'project file inventory' -Actual $actualProjectFiles -Expected $expectedProjects

$expectedGraph = @{
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
$expectedProjectSdks = @{
    'src/StaxRip.Contracts/StaxRip.Contracts.csproj' = 'Microsoft.NET.Sdk'
    'src/StaxRip.Core/StaxRip.Core.csproj' = 'Microsoft.NET.Sdk'
    'src/StaxRip.Platform/StaxRip.Platform.csproj' = 'Microsoft.NET.Sdk'
    'src/StaxRip.Server/StaxRip.Server.csproj' = 'Microsoft.NET.Sdk.Web'
    'tests/StaxRip.ContractTests/StaxRip.ContractTests.csproj' = 'Microsoft.NET.Sdk'
}
$expectedProjectProperties = @{
    'src/StaxRip.Contracts/StaxRip.Contracts.csproj' = [ordered]@{
        TargetFramework = 'net10.0'; ImplicitUsings = 'enable'; Nullable = 'enable';
        TreatWarningsAsErrors = 'true'; Deterministic = 'true'; RootNamespace = 'StaxRip.Contracts'
    }
    'src/StaxRip.Core/StaxRip.Core.csproj' = [ordered]@{
        TargetFramework = 'net10.0'; ImplicitUsings = 'enable'; Nullable = 'enable';
        TreatWarningsAsErrors = 'true'; Deterministic = 'true'; RootNamespace = 'StaxRip.Core'
    }
    'src/StaxRip.Platform/StaxRip.Platform.csproj' = [ordered]@{
        TargetFramework = 'net10.0'; ImplicitUsings = 'enable'; Nullable = 'enable';
        TreatWarningsAsErrors = 'true'; Deterministic = 'true'; RootNamespace = 'StaxRip.Platform'
    }
    'src/StaxRip.Server/StaxRip.Server.csproj' = [ordered]@{
        TargetFramework = 'net10.0'; ImplicitUsings = 'enable'; Nullable = 'enable';
        TreatWarningsAsErrors = 'true'; Deterministic = 'true'; RootNamespace = 'StaxRip.Server';
        EnableDefaultContentItems = 'false'
    }
    'tests/StaxRip.ContractTests/StaxRip.ContractTests.csproj' = [ordered]@{
        OutputType = 'Exe'
    }
}
$expectedProjectItemGroups = @{
    'src/StaxRip.Contracts/StaxRip.Contracts.csproj' = @()
    'src/StaxRip.Core/StaxRip.Core.csproj' = @(
        [pscustomobject]@{
            Items = @(
                [pscustomobject]@{ Name = 'ProjectReference'; Attributes = @{ Include = '..\StaxRip.Contracts\StaxRip.Contracts.csproj' } }
            )
        }
    )
    'src/StaxRip.Platform/StaxRip.Platform.csproj' = @(
        [pscustomobject]@{
            Items = @(
                [pscustomobject]@{ Name = 'ProjectReference'; Attributes = @{ Include = '..\StaxRip.Core\StaxRip.Core.csproj' } }
            )
        }
    )
    'src/StaxRip.Server/StaxRip.Server.csproj' = @(
        [pscustomobject]@{
            Items = @(
                [pscustomobject]@{ Name = 'ProjectReference'; Attributes = @{ Include = '..\StaxRip.Platform\StaxRip.Platform.csproj' } }
            )
        },
        [pscustomobject]@{
            Items = @(
                [pscustomobject]@{ Name = 'EmbeddedResource'; Attributes = @{ Include = 'Web\index.html'; LogicalName = 'StaxRip.Server.Web.index.html' } },
                [pscustomobject]@{ Name = 'EmbeddedResource'; Attributes = @{ Include = 'Web\app.css'; LogicalName = 'StaxRip.Server.Web.app.css' } },
                [pscustomobject]@{ Name = 'EmbeddedResource'; Attributes = @{ Include = 'Web\app.js'; LogicalName = 'StaxRip.Server.Web.app.js' } }
            )
        }
    )
    'tests/StaxRip.ContractTests/StaxRip.ContractTests.csproj' = @(
        [pscustomobject]@{
            Items = @(
                [pscustomobject]@{ Name = 'ProjectReference'; Attributes = @{ Include = '../../src/StaxRip.Contracts/StaxRip.Contracts.csproj' } },
                [pscustomobject]@{ Name = 'ProjectReference'; Attributes = @{ Include = '../../src/StaxRip.Core/StaxRip.Core.csproj' } },
                [pscustomobject]@{ Name = 'ProjectReference'; Attributes = @{ Include = '../../src/StaxRip.Platform/StaxRip.Platform.csproj' } },
                [pscustomobject]@{ Name = 'ProjectReference'; Attributes = @{ Include = '../../src/StaxRip.Server/StaxRip.Server.csproj' } }
            )
        },
        [pscustomobject]@{
            Items = @(
                [pscustomobject]@{ Name = 'FrameworkReference'; Attributes = @{ Include = 'Microsoft.AspNetCore.App' } }
            )
        }
    )
}
$actualGraph = [ordered]@{}
foreach ($project in $expectedProjects) {
    $projectPath = Resolve-SafeCrossPlatformLeaf $project $crossPlatformRoot "Project $project"
    try {
        $projectXml = Read-StrictXml $projectPath "Project $project"
    }
    catch {
        Stop-Gate -Message "Project XML is invalid: $project"
    }
    $projectRoot = $projectXml.DocumentElement
    if ($projectRoot.LocalName -cne 'Project') {
        Stop-Gate -Message "Project XML root differs from the reviewed graph: $project"
    }
    Assert-ExactXmlAttributes $projectRoot @{ Sdk = $expectedProjectSdks[$project] } "Project root $project"
    $expectedProperties = $expectedProjectProperties[$project]
    $expectedItemGroups = @($expectedProjectItemGroups[$project])
    $expectedRootChildren = @('PropertyGroup') + @($expectedItemGroups | ForEach-Object { 'ItemGroup' })
    $rootChildren = @(Assert-ExactXmlChildNames $projectRoot $expectedRootChildren "Project root $project")
    $propertyGroup = $rootChildren[0]
    Assert-ExactXmlAttributes $propertyGroup @{} "PropertyGroup in $project"
    $propertyNames = [string[]]@($expectedProperties.Keys)
    $propertyNodes = @(Assert-ExactXmlChildNames $propertyGroup $propertyNames "PropertyGroup in $project")
    for ($propertyIndex = 0; $propertyIndex -lt $propertyNames.Count; $propertyIndex++) {
        $propertyName = $propertyNames[$propertyIndex]
        Assert-ExactXmlScalar $propertyNodes[$propertyIndex] ([string]$expectedProperties[$propertyName]) "Property $propertyName in $project"
    }

    $references = [System.Collections.Generic.List[string]]::new()
    for ($groupIndex = 0; $groupIndex -lt $expectedItemGroups.Count; $groupIndex++) {
        $itemGroup = $rootChildren[$groupIndex + 1]
        Assert-ExactXmlAttributes $itemGroup @{} "ItemGroup $groupIndex in $project"
        $expectedItems = @($expectedItemGroups[$groupIndex].Items)
        $expectedItemNames = [string[]]@($expectedItems | ForEach-Object { $_.Name })
        $itemNodes = @(Assert-ExactXmlChildNames $itemGroup $expectedItemNames "ItemGroup $groupIndex in $project")
        for ($itemIndex = 0; $itemIndex -lt $expectedItems.Count; $itemIndex++) {
            $expectedItem = $expectedItems[$itemIndex]
            $item = $itemNodes[$itemIndex]
            Assert-EmptyXmlElement $item $expectedItem.Attributes "$($expectedItem.Name) in $project"
            if ($expectedItem.Name -ceq 'ProjectReference') {
                $include = [string]$expectedItem.Attributes.Include
                $targetPath = Resolve-SafeCrossPlatformLeaf $include (Split-Path -Parent $projectPath) "ProjectReference in $project"
                $references.Add((Get-CrossPlatformRelativePath $targetPath))
            }
            elseif ($expectedItem.Name -ceq 'EmbeddedResource') {
                $include = [string]$expectedItem.Attributes.Include
                Resolve-SafeCrossPlatformLeaf $include (Split-Path -Parent $projectPath) "EmbeddedResource in $project" | Out-Null
            }
        }
    }
    Assert-EqualSet -Label "project graph for $project" -Actual $references.ToArray() -Expected $expectedGraph[$project]
    $actualGraph[$project] = @(Sort-Ordinal $references.ToArray())
}

$packageSyntaxFiles = @($sourceScopeItems | Where-Object {
        -not $_.PSIsContainer -and $_.Extension -in @('.csproj', '.props', '.targets')
    })
$centralBuildDefinitions = @($packageSyntaxFiles | Where-Object { $_.Extension -in @('.props', '.targets') } | ForEach-Object { Get-CrossPlatformRelativePath $_.FullName })
Assert-EqualSet -Label 'central build definition inventory' -Actual $centralBuildDefinitions -Expected @('Directory.Build.props')
foreach ($packageSyntaxFile in $packageSyntaxFiles) {
    $buildDefinitionText = Read-Text $packageSyntaxFile.FullName
    if ($buildDefinitionText -cmatch '<\s*(?:PackageReference|PackageDownload|PackageVersion|GlobalPackageReference)\b') {
        Stop-Gate -Message "Project package declaration syntax is forbidden: $(Get-CrossPlatformRelativePath $packageSyntaxFile.FullName)"
    }
    if ($buildDefinitionText -cmatch '<\s*(?:Import|UsingTask|Target|Exec)\b') {
        Stop-Gate -Message "Custom MSBuild import or task execution is forbidden in the bootstrap: $(Get-CrossPlatformRelativePath $packageSyntaxFile.FullName)"
    }
}

$expectedCentralProperties = [ordered]@{
    TargetFramework = 'net10.0'
    LangVersion = 'latest'
    Nullable = 'enable'
    ImplicitUsings = 'enable'
    TreatWarningsAsErrors = 'true'
    AnalysisLevel = 'latest-recommended'
    EnableNETAnalyzers = 'true'
    EnforceCodeStyleInBuild = 'true'
    GenerateDocumentationFile = 'true'
    NoWarn = '$(NoWarn);CS1591'
    CheckForOverflowUnderflow = 'true'
    Deterministic = 'true'
    ContinuousIntegrationBuild = 'true'
    InvariantGlobalization = 'true'
    UseArtifactsOutput = 'true'
    ArtifactsPath = '$(MSBuildThisFileDirectory)artifacts'
    RestorePackagesPath = '$(MSBuildThisFileDirectory)artifacts/nuget'
    RestorePackagesWithLockFile = 'true'
    NuGetAudit = 'false'
    DebugType = 'portable'
}
try {
    $centralPropsPath = Resolve-SafeCrossPlatformLeaf 'Directory.Build.props' $crossPlatformRoot 'Directory.Build.props'
    $centralPropsXml = Read-StrictXml $centralPropsPath 'Directory.Build.props'
    $centralRoot = $centralPropsXml.DocumentElement
    if ($centralRoot.LocalName -cne 'Project') {
        Stop-Gate -Message 'Directory.Build.props root must be Project.'
    }
    Assert-ExactXmlAttributes $centralRoot @{} 'Directory.Build.props root'
    $centralRootChildren = @(Assert-ExactXmlChildNames $centralRoot @('PropertyGroup') 'Directory.Build.props root')
    $centralPropertyGroup = $centralRootChildren[0]
    Assert-ExactXmlAttributes $centralPropertyGroup @{} 'Directory.Build.props PropertyGroup'
    $centralPropertyNames = [string[]]@($expectedCentralProperties.Keys)
    $centralPropertyNodes = @(Assert-ExactXmlChildNames $centralPropertyGroup $centralPropertyNames 'Directory.Build.props PropertyGroup')
    for ($propertyIndex = 0; $propertyIndex -lt $centralPropertyNames.Count; $propertyIndex++) {
        $propertyName = $centralPropertyNames[$propertyIndex]
        Assert-ExactXmlScalar $centralPropertyNodes[$propertyIndex] ([string]$expectedCentralProperties[$propertyName]) "Directory.Build.props property $propertyName"
    }
}
catch {
    Stop-Gate -Message "Directory.Build.props validation failed: $($_.Exception.Message)"
}

$currentProjectPaths = @(Split-NullOutput (Invoke-Git @('ls-files', '-z', '--', 'Source/*.sln', 'Source/*.vbproj', 'Source/*.vcxproj', 'Source/**/*.vbproj', 'Source/**/*.vcxproj')))
foreach ($currentProject in $currentProjectPaths) {
    $currentProjectPath = Join-Path $repositoryRoot $currentProject
    if ((Read-Text $currentProjectPath) -match '(?i)CrossPlatform') {
        Stop-Gate -Message "Current project references the new subtree: $currentProject"
    }
}

$sourceRootPrefix = (Join-Path $crossPlatformRoot 'src') + [System.IO.Path]::DirectorySeparatorChar
$sourceFiles = @($sourceScopeItems | Where-Object {
        -not $_.PSIsContainer -and $_.Extension -eq '.cs' -and $_.FullName.StartsWith($sourceRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)
    })
if ($sourceFiles.Count -eq 0) {
    Stop-Gate -Message 'No cross-platform source files were found.'
}
$layerRules = @(
    [pscustomobject]@{ Layer = 'src\StaxRip.Contracts'; Pattern = '(?m)^\s*using\s+Microsoft\.AspNetCore\b|\bMicrosoft\.AspNetCore\.'; Rule = 'Contracts cannot reference ASP.NET Core.' },
    [pscustomobject]@{ Layer = 'src\StaxRip.Contracts'; Pattern = '(?m)^\s*using\s+System\.IO\s*;|\b(?:File|Directory|FileInfo|DirectoryInfo|DriveInfo|FileStream|FileSystemWatcher)\s*[\.(]'; Rule = 'Contracts cannot use filesystem APIs.' },
    [pscustomobject]@{ Layer = 'src\StaxRip.Contracts'; Pattern = '\b(?:System\.Diagnostics\.)?Process(?:StartInfo)?\b|\bMicrosoft\.Win32\b|\bBinaryFormatter\b|\bSystem\.Windows\.Forms\b'; Rule = 'Contracts cannot use process, registry, legacy serialization, or WinForms APIs.' },
    [pscustomobject]@{ Layer = 'src\StaxRip.Core'; Pattern = '(?m)^\s*using\s+Microsoft\.AspNetCore\b|\bMicrosoft\.AspNetCore\.'; Rule = 'Core cannot reference ASP.NET Core.' },
    [pscustomobject]@{ Layer = 'src\StaxRip.Core'; Pattern = '\b(?:System\.Diagnostics\.)?Process(?:StartInfo)?\b|\bMicrosoft\.Win32\b|\bBinaryFormatter\b|\bSystem\.Windows\.Forms\b|\bStaxRip\.Project\b'; Rule = 'Core cannot use current UI, process, registry, persistence, or project APIs.' }
)
foreach ($rule in $layerRules) {
    $layerPath = Join-Path $crossPlatformRoot $rule.Layer
    $layerPrefix = $layerPath + [System.IO.Path]::DirectorySeparatorChar
    foreach ($file in @($sourceFiles | Where-Object { $_.FullName.StartsWith($layerPrefix, [System.StringComparison]::OrdinalIgnoreCase) })) {
        if ((Read-Text $file.FullName) -cmatch $rule.Pattern) {
            Stop-Gate -Message "$($rule.Rule) File: $(Get-CrossPlatformRelativePath $file.FullName)"
        }
    }
}

$productBanPattern = '\b(?:System\.Diagnostics\.)?Process(?:StartInfo)?\b|\bProcess\.Start\s*\(|\bEnvironment\.GetEnvironmentVariable\s*\(|\bEnvironment\.(?:CommandLine|CurrentDirectory)\b|\bDirectory\.GetCurrentDirectory\s*\(|\b(?:File|Directory|FileInfo|DirectoryInfo|DriveInfo|FileStream|FileSystemWatcher)\s*[\.(]|\b(?:HttpClient|WebClient|WebRequest)\b|\b(?:BinaryFormatter|LosFormatter)\b|\b(?:UseStaticFiles|MapStaticAssets|PhysicalFileProvider)\s*\('
# D-045 and D-046 amend the boundary deliberately, not erode it: each crossing is
# sanctioned in exactly one named product file with a narrowed ban of its own, the
# resolver fails when a named file is absent so no carve-out outlives its file, and
# every other product file keeps the full ban. The bounded-execution primitive may use
# process APIs and the single File.Exists its no-search rule requires; the media file
# probe may read file metadata through FileInfo and nothing else, and process APIs
# stay banned inside it. A second execution path, a second filesystem reader, or scope
# creep inside either named file still stops this gate.
$boundedPrimitivePath = Resolve-SafeCrossPlatformLeaf 'BoundedProcess.cs' (Join-Path $crossPlatformRoot 'src\StaxRip.Platform') 'BoundedProcess.cs'
$boundedPrimitiveBanPattern = '\bEnvironment\.GetEnvironmentVariable\s*\(|\bEnvironment\.(?:CommandLine|CurrentDirectory)\b|\bDirectory\.GetCurrentDirectory\s*\(|\bFile\.(?!Exists\b)\w+|\b(?:Directory|FileInfo|DirectoryInfo|DriveInfo|FileStream|FileSystemWatcher)\s*[\.(]|\b(?:HttpClient|WebClient|WebRequest)\b|\b(?:BinaryFormatter|LosFormatter)\b|\b(?:UseStaticFiles|MapStaticAssets|PhysicalFileProvider)\s*\('
$mediaProbePath = Resolve-SafeCrossPlatformLeaf 'MediaFileProbe.cs' (Join-Path $crossPlatformRoot 'src\StaxRip.Platform') 'MediaFileProbe.cs'
$mediaProbeBanPattern = '\b(?:System\.Diagnostics\.)?Process(?:StartInfo)?\b|\bProcess\.Start\s*\(|\bEnvironment\.GetEnvironmentVariable\s*\(|\bEnvironment\.(?:CommandLine|CurrentDirectory)\b|\bDirectory\.GetCurrentDirectory\s*\(|\bFile\.\w+|\b(?:Directory|DirectoryInfo|DriveInfo|FileStream|FileSystemWatcher)\s*[\.(]|\b(?:HttpClient|WebClient|WebRequest)\b|\b(?:BinaryFormatter|LosFormatter)\b|\b(?:UseStaticFiles|MapStaticAssets|PhysicalFileProvider)\s*\('
foreach ($file in $sourceFiles) {
    $banPattern = if ($file.FullName -eq $boundedPrimitivePath) { $boundedPrimitiveBanPattern }
    elseif ($file.FullName -eq $mediaProbePath) { $mediaProbeBanPattern }
    else { $productBanPattern }
    if ((Read-Text $file.FullName) -cmatch $banPattern) {
        Stop-Gate -Message "Product source crosses the bootstrap process, filesystem, external-network, serialization, or physical-asset boundary: $(Get-CrossPlatformRelativePath $file.FullName)"
    }
}

$serverRoot = Join-Path $crossPlatformRoot 'src\StaxRip.Server'
$serverPrefix = $serverRoot + [System.IO.Path]::DirectorySeparatorChar
$serverText = (@($sourceFiles | Where-Object { $_.FullName.StartsWith($serverPrefix, [System.StringComparison]::OrdinalIgnoreCase) } | Sort-Object FullName | ForEach-Object { Read-Text $_.FullName })) -join "`n"
$serverAppPath = Resolve-SafeCrossPlatformLeaf 'ServerApp.cs' $serverRoot 'ServerApp.cs'
$serverAppText = Read-Text $serverAppPath
$emptyBuilderCalls = [regex]::Matches($serverAppText, '\bWebApplication\.CreateEmptyBuilder\s*\(\s*options\s*\)')
$kestrelCoreCalls = [regex]::Matches($serverAppText, '\bUseKestrelCore\s*\(\s*\)')
if ($emptyBuilderCalls.Count -ne 1 -or $kestrelCoreCalls.Count -ne 1) {
    Stop-Gate -Message 'ServerApp must use exactly one CreateEmptyBuilder(options) and one UseKestrelCore() call.'
}
if ($serverText -match '\bWebApplication\.(?:CreateBuilder|CreateSlimBuilder)\s*\(') {
    Stop-Gate -Message 'Product source must not restore ambient WebApplication builder configuration.'
}
$routeMatches = [regex]::Matches($serverText, '\bMapGet\s*\(\s*"([^"]+)"')
$actualRoutes = @($routeMatches | ForEach-Object { $_.Groups[1].Value })
$expectedRoutes = @('/', '/app.css', '/app.js', '/healthz', '/api/v1/capabilities')
Assert-EqualSet -Label 'literal GET route inventory' -Actual $actualRoutes -Expected $expectedRoutes
# D-046 amends the route law deliberately: exactly one POST route, the media-facts
# endpoint, carries the one request body the server accepts. Every other
# registration shape stays banned, both inventories are literal markers, and the
# published routes record is the union the audit re-checks against its own copy.
$postRouteMatches = [regex]::Matches($serverText, '\bMapPost\s*\(\s*"([^"]+)"')
$actualPostRoutes = @($postRouteMatches | ForEach-Object { $_.Groups[1].Value })
Assert-EqualSet -Label 'literal POST route inventory' -Actual $actualPostRoutes -Expected @('/api/v1/media-facts')
$allMapGetCalls = [regex]::Matches($serverText, '\bMapGet\s*\(')
$allMapPostCalls = [regex]::Matches($serverText, '\bMapPost\s*\(')
if ($allMapGetCalls.Count -ne $routeMatches.Count -or
    $allMapPostCalls.Count -ne $postRouteMatches.Count -or
    $serverText -match '\bMap(?:Put|Patch|Delete|Methods|Controllers|ControllerRoute|Fallback|Group|BlazorHub|RazorPages)\s*\(' -or
    $serverText -match '\bMap\s*\(') {
    Stop-Gate -Message 'Server source registers a route outside the exact six literal route markers.'
}

$serverProjectPath = Join-Path $serverRoot 'StaxRip.Server.csproj'
$serverProject = Read-StrictXml $serverProjectPath 'Server project'
if ([string]$serverProject.DocumentElement.PropertyGroup.EnableDefaultContentItems -cne 'false') {
    Stop-Gate -Message 'Server must disable default content discovery and use only embedded allowlisted assets.'
}
$embeddedResources = @($serverProject.SelectNodes('/Project/ItemGroup/EmbeddedResource'))
$embeddedPairs = [System.Collections.Generic.List[string]]::new()
foreach ($resource in $embeddedResources) {
    $include = ([string]$resource.Include).Replace('\', '/')
    $logicalName = [string]$resource.LogicalName
    $embeddedPairs.Add("$include|$logicalName")
}
$expectedEmbeddedPairs = @(
    'Web/app.css|StaxRip.Server.Web.app.css',
    'Web/app.js|StaxRip.Server.Web.app.js',
    'Web/index.html|StaxRip.Server.Web.index.html'
)
Assert-EqualSet -Label 'embedded resource allowlist' -Actual $embeddedPairs.ToArray() -Expected $expectedEmbeddedPairs

$webRoot = Join-Path $serverRoot 'Web'
$actualWebAssets = @(Get-ChildItem -LiteralPath $webRoot -Recurse -File | ForEach-Object { [System.IO.Path]::GetRelativePath($webRoot, $_.FullName).Replace('\', '/') })
Assert-EqualSet -Label 'web asset allowlist' -Actual $actualWebAssets -Expected @('app.css', 'app.js', 'index.html')
$indexText = Read-Text (Join-Path $webRoot 'index.html')
$cssText = Read-Text (Join-Path $webRoot 'app.css')
$javascriptText = Read-Text (Join-Path $webRoot 'app.js')
$allAssetText = $indexText + "`n" + $cssText + "`n" + $javascriptText
if ($allAssetText -match '(?i)https?:|(?<!:)//[A-Za-z0-9]|\b(?:localStorage|sessionStorage|indexedDB|document\.cookie|sendBeacon|WebSocket|EventSource|XMLHttpRequest)\b|\beval\s*\(|\bnew\s+Function\b') {
    Stop-Gate -Message 'Embedded assets contain an external URL, JavaScript-readable storage, telemetry-capable transport, or dynamic code path.'
}
if ($cssText -match '(?i)@import\b|url\s*\(') {
    Stop-Gate -Message 'Embedded CSS imports or resolves another asset.'
}
if ($indexText -match '(?i)<style\b|\sstyle\s*=|\son[a-z]+\s*=|<form\b|<input\b|showOpenFilePicker') {
    Stop-Gate -Message 'Embedded HTML contains inline style or event code, a form, an input, or a file picker.'
}
$scriptTags = [regex]::Matches($indexText, '(?is)<script\b([^>]*)>')
if ($scriptTags.Count -ne 1 -or $scriptTags[0].Groups[1].Value -notmatch '(?i)\bsrc\s*=\s*["'']\/app\.js["'']') {
    Stop-Gate -Message 'Embedded HTML must contain only the exact external /app.js script tag.'
}
$styleLinks = [regex]::Matches($indexText, '(?is)<link\b[^>]*\brel\s*=\s*["'']stylesheet["''][^>]*>')
if ($styleLinks.Count -ne 1 -or $styleLinks[0].Value -notmatch '(?i)\bhref\s*=\s*["'']\/app\.css["'']') {
    Stop-Gate -Message 'Embedded HTML must contain only the exact /app.css stylesheet link.'
}
$fetchMatches = [regex]::Matches($javascriptText, '(?s)\bfetch\s*\(\s*(["''])(.*?)\1')
if ($fetchMatches.Count -ne 1 -or $fetchMatches[0].Groups[2].Value -ne '/api/v1/capabilities') {
    Stop-Gate -Message 'Embedded JavaScript must make exactly one literal request to /api/v1/capabilities.'
}

$testRoot = Join-Path $crossPlatformRoot 'tests\StaxRip.ContractTests'
$testManifestPath = Join-Path $testRoot 'TEST-CASE-MANIFEST.txt'
$testCaseIds = @()
if (-not (Test-Path -LiteralPath $testManifestPath -PathType Leaf)) {
    Stop-Gate -Message 'TEST-CASE-MANIFEST.txt is required for the reviewed test baseline.'
}
if (Test-Path -LiteralPath $testManifestPath -PathType Leaf) {
    $testCaseIds = @((Read-Text $testManifestPath) -split "`r?`n" | Where-Object { $_ -ne '' -and -not $_.StartsWith('#', [System.StringComparison]::Ordinal) })
    if ($testCaseIds.Count -eq 0) {
        Stop-Gate -Message 'TEST-CASE-MANIFEST.txt contains no case ids.'
    }
    foreach ($caseId in $testCaseIds) {
        if ($caseId -notmatch '^(?:CT|ST)-[0-9]{3}$') {
            Stop-Gate -Message "Invalid contract case id in TEST-CASE-MANIFEST.txt: $caseId"
        }
    }
    if (@($testCaseIds | Select-Object -Unique).Count -ne $testCaseIds.Count) {
        Stop-Gate -Message 'TEST-CASE-MANIFEST.txt contains duplicate case ids.'
    }

    $expectedTestCaseIds = @(
        'CT-001', 'CT-002', 'CT-003', 'CT-004', 'CT-005', 'CT-006', 'CT-007',
        'CT-008', 'CT-009', 'CT-010', 'CT-011', 'CT-012', 'CT-013', 'CT-014',
        'CT-015', 'CT-016', 'CT-017', 'CT-018', 'CT-019', 'CT-020', 'CT-021',
        'CT-022', 'CT-023', 'CT-024', 'CT-025', 'CT-026', 'CT-027', 'CT-028',
        'CT-029', 'CT-030', 'CT-031', 'CT-032', 'CT-033', 'CT-034', 'CT-035', 'CT-036',
        'ST-001', 'ST-002', 'ST-003', 'ST-004', 'ST-005', 'ST-006', 'ST-007',
        'ST-008', 'ST-009', 'ST-010'
    )
    Assert-EqualSet -Label 'reviewed contract test id baseline' -Actual $testCaseIds -Expected $expectedTestCaseIds

    $testPrefix = $testRoot + [System.IO.Path]::DirectorySeparatorChar
    $testText = (@($sourceScopeItems | Where-Object {
                -not $_.PSIsContainer -and $_.Extension -eq '.cs' -and $_.FullName.StartsWith($testPrefix, [System.StringComparison]::OrdinalIgnoreCase)
            } | Sort-Object FullName | ForEach-Object { Read-Text $_.FullName })) -join "`n"
    $caseMatches = [regex]::Matches($testText, '\bnew\s*\(\s*"((?:CT|ST)-[0-9]{3})"')
    $sourceCaseIds = @($caseMatches | ForEach-Object { $_.Groups[1].Value })
    Assert-EqualSet -Label 'contract test case manifest' -Actual $sourceCaseIds -Expected $testCaseIds
    if ($testText -notmatch '--self-test-failure') {
        Stop-Gate -Message 'Contract harness does not expose the required forced-failure self-test.'
    }
    if ($testText -match '(?i)#if\s+false|\[\s*Ignore\b|\bSkip\s*=') {
        Stop-Gate -Message 'Contract harness contains a skipped or disabled test marker.'
    }
}

$docsRoot = Join-Path $repositoryRoot 'Docs'
foreach ($doc in @(Get-ChildItem -LiteralPath $docsRoot -Recurse -File -Filter '*.md')) {
    $docText = Read-Text $doc.FullName
    if ($docText -match '`Source/CrossPlatform(?:/[^`]*)?`') {
        Stop-Gate -Message "Documentation cites the rejected nested Source/CrossPlatform location: $([System.IO.Path]::GetRelativePath($repositoryRoot, $doc.FullName).Replace('\', '/'))"
    }
    foreach ($codeSpan in [regex]::Matches($docText, '`([^`\r\n]+)`')) {
        foreach ($match in [regex]::Matches($codeSpan.Groups[1].Value, '(?<![A-Za-z0-9_.-])(CrossPlatform/[^\s`"''<>|]+)')) {
            $candidate = $match.Groups[1].Value.TrimEnd([char[]]@('.', ',', ';', ':', ')'))
            $candidate = $candidate -replace ':[0-9]+$', ''
            if ($candidate -match '[*?<>$\[\]{}]' -or $candidate.StartsWith('CrossPlatform/artifacts/', [System.StringComparison]::Ordinal) -or $candidate.StartsWith('CrossPlatform/obj/', [System.StringComparison]::Ordinal)) {
                continue
            }
            $candidatePath = Join-Path $repositoryRoot $candidate
            if (-not (Test-Path -LiteralPath $candidatePath) -or -not (Test-ExactCaseRepoPath $candidate)) {
                $docRelative = [System.IO.Path]::GetRelativePath($repositoryRoot, $doc.FullName).Replace('\', '/')
                Stop-Gate -Message "Documentation cites a missing or case-mismatched CrossPlatform path: $candidate in $docRelative"
            }
        }
    }
}

$manifestRows = [System.Collections.Generic.List[string]]::new()
$manifestFiles = @($sourceScopeItems | Where-Object { -not $_.PSIsContainer })
foreach ($file in $manifestFiles) {
    $relative = Get-CrossPlatformRelativePath $file.FullName
    $manifestRows.Add("$relative`t$($file.Length)`t$(Get-Sha256 $file.FullName)")
}
$sortedManifestRows = @(Sort-Ordinal $manifestRows.ToArray())
$script:CurrentCheck = 'evidence-output'
if (-not (Test-SafeArtifactDirectory -Path $evidenceRoot -Create)) {
    Stop-Gate -Message 'Static evidence directory is not a safe repository-local path.'
}
$sourceManifestPath = Join-Path $evidenceRoot 'source-tree.tsv'
$sourceManifestContent = (@('path', 'length', 'sha256') -join "`t") + "`n" + ($sortedManifestRows -join "`n") + "`n"
if (-not (Enter-EvidenceWriterLease)) {
    Stop-Gate -Message 'The shared evidence writer lease is unavailable for static publication.'
}
$publicationSucceeded = $false
$leaseReleased = $false
try {
    Write-Utf8File -Path $sourceManifestPath -Content $sourceManifestContent

    $finalHead = (Invoke-Git @('rev-parse', '--verify', 'HEAD')).Trim()
    if ($finalHead -cne $head) {
        Stop-Gate -Message 'HEAD changed while the static evidence record was being constructed.'
    }
    $finalScopeSnapshot = Get-GitScopeSnapshot
    if (-not (Test-GitScopeSnapshotsEqual -Left $scopeSnapshot -Right $finalScopeSnapshot)) {
        Stop-Gate -Message 'The canonical Git scope changed while the static evidence record was being constructed.'
    }
    $staticRecord = [ordered]@{
        schema = 'staxrip-static-gate-v1'
        base = $BaseCommit
        head = $head
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
        project_graph = $actualGraph
        routes = @(Sort-Ordinal ($actualRoutes + $actualPostRoutes))
        embedded_assets = @(Sort-Ordinal $embeddedPairs.ToArray())
        test_cases = @(Sort-Ordinal $testCaseIds)
        source_manifest = [ordered]@{
            path = 'artifacts/evidence/source-tree.tsv'
            sha256 = Get-Sha256 $sourceManifestPath
            rows = $sortedManifestRows.Count
        }
    }
    $staticRecordPath = Join-Path $evidenceRoot 'static-gate.json'
    Write-Utf8File -Path $staticRecordPath -Content (ConvertTo-CanonicalJson -InputObject $staticRecord -Depth 16)

    Remove-OwnFailurePacket
    $publicationSucceeded = $true
}
finally {
    $leaseReleased = Exit-EvidenceWriterLease
}
if (-not $publicationSucceeded) {
    Stop-Gate -Message 'Static evidence publication did not complete.'
}
if (-not $leaseReleased) {
    Stop-Gate -Message 'The shared evidence writer lease could not be released after static publication.'
}
$timer.Stop()
$relativeEvidence = Get-CrossPlatformRelativePath $staticRecordPath
$checks = $allChanged.Count + $expectedProjects.Count + $actualRoutes.Count + $embeddedPairs.Count + $testCaseIds.Count + $sortedManifestRows.Count
[Console]::Out.WriteLine("PASS $gateId checks=$checks elapsed_ms=$($timer.ElapsedMilliseconds) evidence=$relativeEvidence")
exit 0
