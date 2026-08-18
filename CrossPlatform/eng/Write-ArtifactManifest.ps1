[CmdletBinding()]
param(
    [string]$Root,
    [string]$OutputPath,
    [ValidateSet('Wsl')]
    [string]$ModeSource = 'Wsl',
    [ValidateSet('Ubuntu')]
    [string]$WslDistribution = 'Ubuntu',
    [ValidateRange(10, 300)]
    [int]$TimeoutSeconds = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gateId = 'port-artifact-manifest'
$timer = [System.Diagnostics.Stopwatch]::StartNew()
$crossPlatformRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $crossPlatformRoot '..'))
$artifactsRoot = Join-Path $crossPlatformRoot 'artifacts'
$publishRoot = Join-Path $artifactsRoot 'publish'
$evidenceRoot = Join-Path $artifactsRoot 'evidence'
$failureRoot = Join-Path $artifactsRoot 'failures'
$auditPath = Join-Path $evidenceRoot 'evidence-audit.json'
$auditSidecarPath = Join-Path $evidenceRoot 'evidence-audit.json.sha256'
$evidenceLeasePath = Join-Path $evidenceRoot '.evidence-writer.lock'
$emptySha256 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
$script:stopGateActive = $false
$script:stopGateExitCode = 1
$script:evidenceLeaseOwned = $false
$script:evidenceLeaseNonce = $null
$script:evidenceLeaseReceiptValidated = $false
$script:evidencePassPairInvalidated = $false

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Join-Path $publishRoot 'linux-x64'
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $evidenceRoot 'artifact-linux-x64.tsv'
}
$Root = [System.IO.Path]::GetFullPath($Root)
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$hashPath = $OutputPath + '.sha256'

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
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Content)
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

function Get-Sha256 {
    param([Parameter(Mandatory)] [string]$Path)

    if (-not (Test-SafeArtifactLeaf -Path $Path)) {
        throw 'Artifact input is not a safe regular repository-local file.'
    }
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
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
        return -not $item.PSIsContainer -and
            (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0)
    }
    catch {
        return $false
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
    try {
        if (-not (Enter-EvidenceWriterLease)) {
            throw 'The shared evidence writer lease is unavailable.'
        }
        if (-not (Test-EvidenceWriterLeasePublicationAuthority)) {
            throw 'The shared evidence writer lease lacks publication authority.'
        }
        if (-not (Test-SafeArtifactDirectory -Path $failureRoot -Create)) {
            throw 'Failure evidence directory is unsafe.'
        }
        $packetPath = Join-Path $failureRoot "$gateId.txt"
        if (-not (Test-SafeArtifactLeaf -Path $packetPath -AllowMissing -CreateParent)) {
            throw 'Failure evidence leaf is unsafe.'
        }
        $boundedOutput = ((Protect-Text $Output) -split "`r?`n" | Where-Object { $_ -ne '' } | Select-Object -First 40) -join "`n"
        $packet = @(
            "gate=$gateId"
            'criterion=LNX-004'
            "exit=$ExitCode"
            "message=$(Protect-Text $Message)"
            "argv=$(Protect-Text ($Argv | ConvertTo-Json -Compress))"
            'replay=pwsh -NoProfile -NonInteractive -File CrossPlatform/eng/Write-ArtifactManifest.ps1'
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
        Stop-Gate -Message 'The prior artifact-manifest failure packet is not a safe regular leaf.'
    }
    [System.IO.File]::Delete($matches[0].FullName)
    $remaining = @(Get-ChildItem -LiteralPath $failureRoot -Force | Where-Object {
            [string]::Equals($_.Name, $leafName, [System.StringComparison]::Ordinal)
        })
    if ($remaining.Count -ne 0) {
        Stop-Gate -Message 'The prior artifact-manifest failure packet could not be removed after success.'
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

function Test-DescendantPath {
    param(
        [Parameter(Mandatory)] [string]$Candidate,
        [Parameter(Mandatory)] [string]$Parent
    )

    $comparison = if ($IsWindows) { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }
    $prefix = $Parent.TrimEnd([char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)) + [System.IO.Path]::DirectorySeparatorChar
    return $Candidate.StartsWith($prefix, $comparison)
}

function Convert-ToModeText {
    param([Parameter(Mandatory)] [int]$Mode)
    return [System.Convert]::ToString(($Mode -band 511), 8).PadLeft(4, '0')
}

function Assert-NoReparseComponents {
    param([Parameter(Mandatory)] [string]$Path)

    $target = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-DescendantPath -Candidate $target -Parent $crossPlatformRoot) -and $target -ne $crossPlatformRoot) {
        Stop-Gate -Message 'A manifest path escapes the CrossPlatform subtree.'
    }
    $relative = [System.IO.Path]::GetRelativePath($crossPlatformRoot, $target)
    $current = $crossPlatformRoot
    foreach ($component in $relative.Split([char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar), [System.StringSplitOptions]::RemoveEmptyEntries)) {
        $current = Join-Path $current $component
        if (-not (Test-Path -LiteralPath $current)) {
            break
        }
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            Stop-Gate -Message "Manifest input or evidence path resolves through a reparse point: $([System.IO.Path]::GetRelativePath($crossPlatformRoot, $current).Replace('\', '/'))"
        }
    }
}

function Get-WslModeMap {
    param(
        [Parameter(Mandatory)] [string]$WindowsRoot,
        [Parameter(Mandatory)] [string]$Distribution
    )

    # Same class as the auditor's wsl lookup (R-S2-047): an extension-suffixed query
    # returns every PATH match. This site is currently shielded by the wrapper's reduced
    # PATH, but one interactive invocation away from the identical crash.
    $wslCommand = @(Get-Command wsl.exe -CommandType Application -ErrorAction SilentlyContinue) |
        Select-Object -First 1
    if ($null -eq $wslCommand) {
        return $null
    }
    $pathResult = Invoke-BoundedProcess -FileName $wslCommand.Source -Arguments @(
        '-d', $Distribution,
        '--exec', '/usr/bin/env', '-i', 'PATH=/usr/bin:/bin', 'LC_ALL=C.UTF-8',
        '/usr/bin/wslpath', '-a', $WindowsRoot
    ) -WorkingDirectory $crossPlatformRoot -Timeout $TimeoutSeconds
    if ($pathResult.ExitCode -ne 0) {
        Stop-Gate -Message 'WSL could not map the publish root.' -ExitCode $pathResult.ExitCode -Output ($pathResult.StdOut + $pathResult.StdErr) -Argv @('wsl.exe', '-d', $Distribution, '--exec', 'wslpath', '-a', '<publish-root>')
    }
    $linuxRoot = $pathResult.StdOut.Trim()
    if ([string]::IsNullOrWhiteSpace($linuxRoot) -or -not $linuxRoot.StartsWith('/', [System.StringComparison]::Ordinal)) {
        Stop-Gate -Message 'WSL returned an invalid mapped publish root.'
    }

    $bash = @'
set -euo pipefail
root=$1
while IFS= read -r -d '' item; do
    relative=${item#"$root"/}
    mode=$(stat -c '%a' -- "$item")
    printf '%s\0%s\0' "$relative" "$mode"
done < <(find "$root" -mindepth 1 -print0)
'@
    $modeResult = Invoke-BoundedProcess -FileName $wslCommand.Source -Arguments @(
        '-d', $Distribution,
        '--exec', '/usr/bin/env', '-i', 'PATH=/usr/bin:/bin', 'LC_ALL=C.UTF-8',
        '/bin/bash', '--noprofile', '--norc', '-c', $bash, '--', $linuxRoot
    ) -WorkingDirectory $crossPlatformRoot -Timeout $TimeoutSeconds
    if ($modeResult.ExitCode -ne 0) {
        Stop-Gate -Message 'WSL could not enumerate Linux modes for the publish tree.' -ExitCode $modeResult.ExitCode -Output ($modeResult.StdOut + $modeResult.StdErr) -Argv @('wsl.exe', '-d', $Distribution, '--exec', 'bash', '-c', '<mode-enumerator>', '--', '<publish-root>')
    }

    $parts = @($modeResult.StdOut.Split([char]0, [System.StringSplitOptions]::RemoveEmptyEntries))
    if (($parts.Count % 2) -ne 0) {
        Stop-Gate -Message 'WSL mode output has an incomplete path-mode pair.'
    }
    $map = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)
    for ($index = 0; $index -lt $parts.Count; $index += 2) {
        $relative = $parts[$index]
        $modeValue = $parts[$index + 1]
        if ($relative -match '[^\x20-\x7e]' -or $relative.Contains('\')) {
            Stop-Gate -Message 'WSL found an artifact path outside the canonical ASCII grammar.'
        }
        if ($modeValue -notmatch '^[0-7]{3,4}$') {
            Stop-Gate -Message "WSL returned a non-octal mode for $relative."
        }
        $normalizedMode = $modeValue.PadLeft(4, '0')
        if (-not $map.TryAdd($relative, $normalizedMode)) {
            Stop-Gate -Message "WSL returned a duplicate mode row for $relative."
        }
    }
    return $map
}

trap {
    Stop-Gate `
        -Message "Unexpected artifact-manifest gate error at line $($_.InvocationInfo.ScriptLineNumber)." `
        -Output "$($_.Exception.GetType().Name): $($_.Exception.Message)"
}

Assert-RedactionSelfTests
if (-not (Test-DescendantPath -Candidate $Root -Parent $publishRoot)) {
    Stop-Gate -Message 'Artifact Root must stay below CrossPlatform/artifacts/publish/.'
}
if (-not (Test-DescendantPath -Candidate $OutputPath -Parent $evidenceRoot)) {
    Stop-Gate -Message 'OutputPath must stay below CrossPlatform/artifacts/evidence/.'
}
if (Test-DescendantPath -Candidate $OutputPath -Parent $Root) {
    Stop-Gate -Message 'The manifest cannot be written inside the tree it identifies.'
}
if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    Stop-Gate -Message 'The publish root does not exist.'
}
if (-not (Test-SafeArtifactDirectory -Path $evidenceRoot -Create)) {
    Stop-Gate -Message 'The manifest evidence directory is not a safe repository-local path.'
}
Assert-NoReparseComponents $Root
Assert-NoReparseComponents (Split-Path -Parent $OutputPath)
if (Test-Path -LiteralPath $OutputPath) {
    Assert-NoReparseComponents $OutputPath
}
if (Test-Path -LiteralPath $hashPath) {
    Assert-NoReparseComponents $hashPath
}

$rootItem = Get-Item -LiteralPath $Root -Force
if (($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
    Stop-Gate -Message 'The publish root is a reparse point.'
}
$items = @((Get-ChildItem -LiteralPath $Root -Recurse -Force))
if ($items.Count -eq 0) {
    Stop-Gate -Message 'The publish root is empty.'
}
foreach ($item in $items) {
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        $relative = [System.IO.Path]::GetRelativePath($Root, $item.FullName).Replace('\', '/')
        Stop-Gate -Message "The publish tree contains a reparse point: $relative"
    }
}

if (-not $IsWindows) {
    Stop-Gate -Message 'This slice records canonical Linux modes through the reviewed Ubuntu WSL boundary.'
}
$effectiveModeSource = 'Wsl'
$modeMap = Get-WslModeMap -WindowsRoot $Root -Distribution $WslDistribution
if ($null -eq $modeMap) {
    Stop-Gate -Message 'Wsl mode source was requested, but wsl.exe is unavailable.' -ExitCode 127
}
$modeSourceLabel = 'wsl:Ubuntu'

$entries = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
foreach ($item in $items) {
    $relative = [System.IO.Path]::GetRelativePath($Root, $item.FullName).Replace('\', '/')
    if ([string]::IsNullOrWhiteSpace($relative) -or $relative -eq '.') {
        Stop-Gate -Message 'The artifact tree produced an empty relative path.'
    }
    if ($relative -match '[^\x20-\x7e]' -or $relative.StartsWith('/', [System.StringComparison]::Ordinal) -or $relative.Contains('\')) {
        Stop-Gate -Message "Artifact path is outside the canonical ASCII relative-path grammar: $relative"
    }
    $segments = $relative.Split('/')
    if ($segments | Where-Object { $_ -eq '.' -or $_ -eq '..' -or $_ -eq '' } | Select-Object -First 1) {
        Stop-Gate -Message "Artifact path contains an empty or dot segment: $relative"
    }
    if ($entries.ContainsKey($relative)) {
        Stop-Gate -Message "Artifact tree contains a duplicate canonical path: $relative"
    }

    if ($effectiveModeSource -eq 'Wsl') {
        if (-not $modeMap.ContainsKey($relative)) {
            Stop-Gate -Message "WSL mode inventory is missing: $relative"
        }
        $mode = $modeMap[$relative]
    }

    if ($item.PSIsContainer) {
        $entry = [pscustomobject]@{
            Path = $relative
            Type = 'directory'
            Length = 0L
            Sha256 = $emptySha256
            Mode = $mode
        }
    }
    else {
        $lengthBefore = $item.Length
        $lastWriteBefore = $item.LastWriteTimeUtc
        $sha256 = Get-Sha256 $item.FullName
        $item.Refresh()
        if ($item.Length -ne $lengthBefore -or $item.LastWriteTimeUtc -ne $lastWriteBefore) {
            Stop-Gate -Message "Artifact changed while it was hashed: $relative"
        }
        $entry = [pscustomobject]@{
            Path = $relative
            Type = 'file'
            Length = [long]$lengthBefore
            Sha256 = $sha256
            Mode = $mode
        }
    }
    $entries.Add($relative, $entry)
}

if ($effectiveModeSource -eq 'Wsl' -and $modeMap.Count -ne $entries.Count) {
    Stop-Gate -Message "WSL mode inventory count differs from the artifact inventory. WSL=$($modeMap.Count), artifact=$($entries.Count)."
}

$paths = [string[]]@($entries.Keys)
[System.Array]::Sort($paths, [System.StringComparer]::Ordinal)
$rows = [System.Collections.Generic.List[string]]::new()
foreach ($path in $paths) {
    $entry = $entries[$path]
    $rows.Add("$($entry.Path)`t$($entry.Type)`t$($entry.Length)`t$($entry.Sha256)`t$($entry.Mode)")
}
$manifest = @(
    '# staxrip-artifact-manifest-v1'
    "# mode-source=$modeSourceLabel"
    "path`ttype`tlength`tsha256`tmode"
    $rows.ToArray()
) -join "`n"
$manifestContent = $manifest + "`n"
$utf8 = [System.Text.UTF8Encoding]::new($false)
$manifestBytes = $utf8.GetBytes($manifestContent)
$manifestHash = [System.Convert]::ToHexString(
    [System.Security.Cryptography.SHA256]::HashData($manifestBytes)).ToLowerInvariant()
$hashContent = "$manifestHash  $([System.IO.Path]::GetFileName($OutputPath))`n"
$hashContentBytes = $utf8.GetBytes($hashContent)
$hashContentSha256 = [System.Convert]::ToHexString(
    [System.Security.Cryptography.SHA256]::HashData($hashContentBytes)).ToLowerInvariant()

if (-not (Enter-EvidenceWriterLease)) {
    Stop-Gate -Message 'The shared evidence writer lease is unavailable for artifact-manifest publication.'
}
$publicationSucceeded = $false
$leaseReleased = $false
try {
    Write-Utf8File -Path $OutputPath -Content $manifestContent
    Write-Utf8File -Path $hashPath -Content $hashContent

    # The two renames are not a transaction. This final check detects an interleaved writer before PASS.
    if (-not (Test-SafeArtifactLeaf -Path $OutputPath) -or
        -not (Test-SafeArtifactLeaf -Path $hashPath) -or
        (Get-Sha256 $OutputPath) -ne $manifestHash -or
        (Get-Sha256 $hashPath) -ne $hashContentSha256) {
        Stop-Gate -Message 'The published manifest pair changed before final verification.'
    }

    Remove-OwnFailurePacket
    $publicationSucceeded = $true
}
finally {
    $leaseReleased = Exit-EvidenceWriterLease
}
if (-not $publicationSucceeded) {
    Stop-Gate -Message 'Artifact-manifest evidence publication did not complete.'
}
if (-not $leaseReleased) {
    Stop-Gate -Message 'The shared evidence writer lease could not be released after artifact-manifest publication.'
}
$timer.Stop()
$relativeEvidence = [System.IO.Path]::GetRelativePath($repositoryRoot, $OutputPath).Replace('\', '/')
[Console]::Out.WriteLine("PASS $gateId checks=$($entries.Count) elapsed_ms=$($timer.ElapsedMilliseconds) evidence=$relativeEvidence")
exit 0
