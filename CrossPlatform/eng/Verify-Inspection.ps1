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
$evidenceRoot = Join-Path $crossPlatformRoot 'artifacts\evidence'
$failureRoot = Join-Path $crossPlatformRoot 'artifacts\failures'
$workRoot = Join-Path $crossPlatformRoot 'artifacts\tasks\inspection-gate'
$script:CheckCount = 0
$script:CurrentCheck = 'startup'

function Stop-Gate {
    param([Parameter(Mandatory)][string]$Message)

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

# Build the gate's own media world under the artifacts tree: committed media copies,
# a garbage golden for the malformed case, a sleep probe for the cancellation case,
# and a junction directory inside the root for the reparse-component case.
$script:CurrentCheck = 'stage-media-world'
if (Test-Path -LiteralPath $workRoot) {
    Remove-Item -LiteralPath $workRoot -Recurse -Force
}
$mediaDir = Join-Path $workRoot 'media'
New-Item -ItemType Directory -Force -Path $mediaDir | Out-Null
Copy-Item -LiteralPath (Join-Path $fixtureRoot 'media\cfr-h264-aac.mp4') -Destination (Join-Path $mediaDir 'cfr-h264-aac.mp4')
Copy-Item -LiteralPath (Join-Path $fixtureRoot 'cfr-h264-aac.mp4.win-26.05.json') -Destination (Join-Path $workRoot 'cfr-h264-aac.mp4.win-26.05.json')
Copy-Item -LiteralPath (Join-Path $fixtureRoot 'media\cfr-h264-aac.mp4') -Destination (Join-Path $mediaDir 'malformed-probe.mkv')
[System.IO.File]::WriteAllText((Join-Path $workRoot 'malformed-probe.mkv.win-26.05.json'), "this is not a json document`n")
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
        (Join-Path $workRoot 'cfr-h264-aac.mp4.win-26.05.json'),
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

# Publish the evidence record. New producer evidence invalidates any standing audit
# first, because a record written after an audit attempt is unaudited and the stale
# audit must not keep certifying a set that no longer exists.
$script:CurrentCheck = 'write-evidence'
New-Item -ItemType Directory -Force -Path $evidenceRoot | Out-Null
foreach ($staleAudit in @('evidence-audit.json', 'evidence-audit.json.sha256')) {
    $stalePath = Join-Path $evidenceRoot $staleAudit
    if (Test-Path -LiteralPath $stalePath) {
        Remove-Item -LiteralPath $stalePath -Force
    }
}
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
$json = ($record | ConvertTo-Json -Depth 6).Replace("`r`n", "`n")
[System.IO.File]::WriteAllText((Join-Path $evidenceRoot 'inspection.json'), $json + "`n")
if (Test-Path -LiteralPath (Join-Path $failureRoot 'port-inspection.txt')) {
    Remove-Item -LiteralPath (Join-Path $failureRoot 'port-inspection.txt') -Force
}
Remove-Item -LiteralPath $workRoot -Recurse -Force

$stopwatch.Stop()
Write-Output "PASS port-inspection checks=$script:CheckCount elapsed_ms=$($stopwatch.ElapsedMilliseconds) evidence=CrossPlatform/artifacts/evidence/inspection.json"
exit 0
