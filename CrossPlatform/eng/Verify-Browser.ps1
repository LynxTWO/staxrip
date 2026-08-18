[CmdletBinding()]
param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",

    [string]$BrowserPath,

    [string]$ServerPath,

    [Parameter(DontShow)]
    [switch]$ServeFixture,

    [Parameter(DontShow)]
    [string]$TargetOrigin,

    [Parameter(DontShow)]
    [string]$FixturePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-FixtureProducer {
    param(
        [Parameter(Mandatory)][string]$Origin,
        [Parameter(Mandatory)][string]$HtmlPath
    )

    $expectedFixture = [System.IO.Path]::GetFullPath(
        (Join-Path $PSScriptRoot "fixtures\hostile-browser.html"))
    $actualFixture = [System.IO.Path]::GetFullPath($HtmlPath)
    if (-not [string]::Equals($expectedFixture, $actualFixture, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not [System.IO.File]::Exists($actualFixture)) {
        throw [System.InvalidOperationException]::new("FIXTURE_PATH")
    }

    $originUri = $null
    if (-not [System.Uri]::TryCreate($Origin, [System.UriKind]::Absolute, [ref]$originUri) -or
        $originUri.Scheme -cne "http" -or
        $originUri.Host -cne "127.0.0.1" -or
        $originUri.Port -le 0 -or
        $originUri.AbsolutePath -cne "/" -or
        $originUri.Query.Length -ne 0 -or
        $originUri.Fragment.Length -ne 0) {
        throw [System.InvalidOperationException]::new("FIXTURE_ORIGIN")
    }

    $html = [System.IO.File]::ReadAllText($actualFixture, [System.Text.Encoding]::UTF8)
    $placeholder = "__TARGET_ORIGIN__"
    $firstPlaceholder = $html.IndexOf($placeholder, [System.StringComparison]::Ordinal)
    $lastPlaceholder = $html.LastIndexOf($placeholder, [System.StringComparison]::Ordinal)
    if ($firstPlaceholder -lt 0 -or $firstPlaceholder -ne $lastPlaceholder) {
        throw [System.InvalidOperationException]::new("FIXTURE_PLACEHOLDER")
    }
    $html = $html.Replace($placeholder, $originUri.AbsoluteUri)
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Server.ExclusiveAddressUse = $true
    $listener.Start()
    try {
        $port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
        [Console]::Out.WriteLine("FIXTURE_READY http://127.0.0.1:$port/")
        [Console]::Out.Flush()
        $stopping = $false

        while (-not $stopping) {
            $client = $listener.AcceptTcpClient()
            try {
                $stream = $client.GetStream()
                try {
                    $stream.ReadTimeout = 5000
                    $stream.WriteTimeout = 5000
                    $requestBuffer = [System.IO.MemoryStream]::new()
                    try {
                        $tail = ""
                        while ($requestBuffer.Length -lt 8192 -and $tail -cne "`r`n`r`n") {
                            $next = $stream.ReadByte()
                            if ($next -lt 0) { break }
                            $requestBuffer.WriteByte([byte]$next)
                            $tail = ($tail + [char]$next)
                            if ($tail.Length -gt 4) { $tail = $tail.Substring($tail.Length - 4) }
                        }
                        $requestText = [System.Text.Encoding]::ASCII.GetString($requestBuffer.ToArray())
                    }
                    finally {
                        $requestBuffer.Dispose()
                    }

                    $firstLineEnd = $requestText.IndexOf("`r`n", [System.StringComparison]::Ordinal)
                    $firstLine = if ($firstLineEnd -gt 0) { $requestText.Substring(0, $firstLineEnd) } else { "" }
                    $parts = $firstLine.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
                    $method = if ($parts.Count -ge 1) { $parts[0] } else { "" }
                    $path = if ($parts.Count -ge 2) { $parts[1] } else { "" }

                    $status = "404 Not Found"
                    $contentType = "text/plain; charset=utf-8"
                    $body = "Not found."
                    if ($method -ceq "GET" -and $path -ceq "/") {
                        $status = "200 OK"
                        $contentType = "text/html; charset=utf-8"
                        $body = $html
                    }
                    elseif ($method -ceq "GET" -and $path -ceq "/__stop") {
                        $status = "200 OK"
                        $body = "Stopping."
                        $stopping = $true
                    }

                    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
                    $allowedOrigin = $originUri.GetLeftPart([System.UriPartial]::Authority)
                    $headers = "HTTP/1.1 $status`r`n" +
                        "Content-Type: $contentType`r`n" +
                        "Content-Length: $($bodyBytes.Length)`r`n" +
                        "Cache-Control: no-store`r`n" +
                        "X-Content-Type-Options: nosniff`r`n" +
                        "Content-Security-Policy: default-src 'none'; connect-src $allowedOrigin; frame-src $allowedOrigin`r`n" +
                        "Connection: close`r`n`r`n"
                    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headers)
                    $stream.Write($headerBytes, 0, $headerBytes.Length)
                    $stream.Write($bodyBytes, 0, $bodyBytes.Length)
                    $stream.Flush()
                }
                finally {
                    $stream.Dispose()
                }
            }
            catch [System.IO.IOException] {
                # Browser policy cancellation can close a fixture connection mid-response.
            }
            catch [System.Net.Sockets.SocketException] {
                # A reset is scoped to this synthetic client; keep the fixture available.
            }
            finally {
                $client.Dispose()
            }
        }
    }
    finally {
        $listener.Stop()
    }

    [Console]::Out.WriteLine("FIXTURE_STOPPED")
    [Console]::Out.Flush()
}

if ($ServeFixture) {
    try {
        Invoke-FixtureProducer $TargetOrigin $FixturePath
        exit 0
    }
    catch {
        [Console]::Error.WriteLine("FIXTURE_ERROR")
        exit 1
    }
}

$gateId = "port-browser"
# Diagnostic-only channel for R-S2-038. Declared at script scope because Set-StrictMode
# is Latest and the cleanup summary reads it even when cleanup never ran.
$script:CleanupSurvivorDiagnostics = @()
$startedAt = [System.Diagnostics.Stopwatch]::StartNew()
$script:CheckCount = 0
$script:CurrentCheck = "preflight"
$script:ProducerExit = $null
$script:Server = $null
$script:Fixture = $null
$script:Browser = $null
$script:CdpSocket = $null
$script:CdpCommandId = 0
$script:CdpEvents = [System.Collections.Generic.List[object]]::new()
$script:CleanupState = $null
$script:EvidenceLeaseAcquired = $false
$script:EvidenceLeaseReceiptValidated = $false
$script:EvidencePassPairInvalidated = $false
$script:EvidenceLeaseNonce = $null
$maximumConsoleCharacters = 16384
$maximumCdpMessageBytes = 1048576

function Initialize-BrowserGateNativeHelpers {
    if ($null -ne ('StaxRip.CrossPlatform.BrowserGate.NativeMethods' -as [type])) {
        return
    }

    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Win32.SafeHandles;

namespace StaxRip.CrossPlatform.BrowserGate
{
    public static class NativeMethods
    {
        private const uint FileNameNormalized = 0;

        [DllImport("shell32.dll", SetLastError = true)]
        private static extern IntPtr CommandLineToArgvW(
            [MarshalAs(UnmanagedType.LPWStr)] string commandLine,
            out int argumentCount);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr LocalFree(IntPtr memory);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern uint GetFinalPathNameByHandleW(
            SafeFileHandle file,
            StringBuilder path,
            uint pathLength,
            uint flags);

        public static string[] ParseCommandLine(string commandLine)
        {
            if (commandLine == null)
            {
                throw new ArgumentNullException(nameof(commandLine));
            }

            int argumentCount;
            IntPtr arguments = CommandLineToArgvW(commandLine, out argumentCount);
            if (arguments == IntPtr.Zero)
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }

            try
            {
                var result = new string[argumentCount];
                for (int index = 0; index < argumentCount; index++)
                {
                    IntPtr argument = Marshal.ReadIntPtr(arguments, index * IntPtr.Size);
                    result[index] = Marshal.PtrToStringUni(argument) ?? String.Empty;
                }
                return result;
            }
            finally
            {
                LocalFree(arguments);
            }
        }

        public static string CanonicalizeExistingFile(string path)
        {
            if (String.IsNullOrWhiteSpace(path))
            {
                throw new ArgumentException("A path is required.", nameof(path));
            }

            using (var stream = new FileStream(
                Path.GetFullPath(path),
                FileMode.Open,
                FileAccess.Read,
                FileShare.ReadWrite | FileShare.Delete))
            {
                var buffer = new StringBuilder(512);
                uint length = GetFinalPathNameByHandleW(
                    stream.SafeFileHandle,
                    buffer,
                    (uint)buffer.Capacity,
                    FileNameNormalized);
                if (length == 0)
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                }
                if (length >= buffer.Capacity)
                {
                    buffer = new StringBuilder(checked((int)length + 1));
                    length = GetFinalPathNameByHandleW(
                        stream.SafeFileHandle,
                        buffer,
                        (uint)buffer.Capacity,
                        FileNameNormalized);
                    if (length == 0 || length >= buffer.Capacity)
                    {
                        throw new Win32Exception(Marshal.GetLastWin32Error());
                    }
                }

                string result = buffer.ToString();
                const string uncPrefix = @"\\?\UNC\";
                const string devicePrefix = @"\\?\";
                if (result.StartsWith(uncPrefix, StringComparison.OrdinalIgnoreCase))
                {
                    result = @"\\" + result.Substring(uncPrefix.Length);
                }
                else if (result.StartsWith(devicePrefix, StringComparison.OrdinalIgnoreCase))
                {
                    result = result.Substring(devicePrefix.Length);
                }
                return Path.GetFullPath(result);
            }
        }
    }

    public sealed class BoundedProcessCapture : IDisposable
    {
        private sealed class BufferState : IDisposable
        {
            private readonly byte[] retained;
            private readonly object sync = new object();
            private readonly AutoResetEvent changed = new AutoResetEvent(false);
            private int retainedCount;
            private long totalCount;
            private bool completed;

            public BufferState(int maximumBytes)
            {
                retained = new byte[maximumBytes];
            }

            public void Append(byte[] buffer, int count)
            {
                lock (sync)
                {
                    totalCount = checked(totalCount + count);
                    int copyCount = Math.Min(count, retained.Length - retainedCount);
                    if (copyCount > 0)
                    {
                        Buffer.BlockCopy(buffer, 0, retained, retainedCount, copyCount);
                        retainedCount += copyCount;
                    }
                }
                changed.Set();
            }

            public void Complete()
            {
                lock (sync)
                {
                    completed = true;
                }
                changed.Set();
            }

            public bool TryGetFirstLine(int timeoutMilliseconds, out string line)
            {
                var timer = Stopwatch.StartNew();
                while (true)
                {
                    lock (sync)
                    {
                        for (int index = 0; index < retainedCount; index++)
                        {
                            if (retained[index] == (byte)'\n')
                            {
                                int length = index;
                                if (length > 0 && retained[length - 1] == (byte)'\r')
                                {
                                    length--;
                                }
                                line = new UTF8Encoding(false, true).GetString(retained, 0, length);
                                return true;
                            }
                        }
                        if (completed || retainedCount == retained.Length)
                        {
                            line = null;
                            return false;
                        }
                    }

                    int remaining = timeoutMilliseconds - checked((int)Math.Min(timer.ElapsedMilliseconds, Int32.MaxValue));
                    if (remaining <= 0 || !changed.WaitOne(Math.Min(remaining, 100)))
                    {
                        if (remaining <= 0)
                        {
                            line = null;
                            return false;
                        }
                    }
                }
            }

            public string GetText()
            {
                lock (sync)
                {
                    return new UTF8Encoding(false, true).GetString(retained, 0, retainedCount);
                }
            }

            public long TotalCount
            {
                get { lock (sync) { return totalCount; } }
            }

            public bool Exceeded
            {
                get { lock (sync) { return totalCount > retained.Length; } }
            }

            public void Dispose()
            {
                changed.Dispose();
            }
        }

        private readonly BufferState stdout;
        private readonly BufferState stderr;
        private Task stdoutTask;
        private Task stderrTask;

        public BoundedProcessCapture(int maximumBytesPerStream)
        {
            if (maximumBytesPerStream < 1024)
            {
                throw new ArgumentOutOfRangeException(nameof(maximumBytesPerStream));
            }
            stdout = new BufferState(maximumBytesPerStream);
            stderr = new BufferState(maximumBytesPerStream);
        }

        public void Start(Process process)
        {
            if (process == null)
            {
                throw new ArgumentNullException(nameof(process));
            }
            if (stdoutTask != null || stderrTask != null)
            {
                throw new InvalidOperationException("Capture was already started.");
            }

            stdoutTask = Task.Run(() => Pump(process.StandardOutput.BaseStream, stdout));
            stderrTask = Task.Run(() => Pump(process.StandardError.BaseStream, stderr));
        }

        private static void Pump(Stream stream, BufferState target)
        {
            var buffer = new byte[4096];
            try
            {
                int count;
                while ((count = stream.Read(buffer, 0, buffer.Length)) > 0)
                {
                    target.Append(buffer, count);
                }
            }
            finally
            {
                target.Complete();
            }
        }

        public bool TryGetFirstStdoutLine(int timeoutMilliseconds, out string line)
        {
            return stdout.TryGetFirstLine(timeoutMilliseconds, out line);
        }

        public bool WaitForCompletion(int timeoutMilliseconds)
        {
            if (stdoutTask == null || stderrTask == null)
            {
                return false;
            }
            return Task.WaitAll(new[] { stdoutTask, stderrTask }, timeoutMilliseconds);
        }

        public string StdoutText { get { return stdout.GetText(); } }
        public string StderrText { get { return stderr.GetText(); } }
        public long StdoutBytes { get { return stdout.TotalCount; } }
        public long StderrBytes { get { return stderr.TotalCount; } }
        public bool StdoutExceeded { get { return stdout.Exceeded; } }
        public bool StderrExceeded { get { return stderr.Exceeded; } }

        public void Dispose()
        {
            stdout.Dispose();
            stderr.Dispose();
        }
    }
}
'@
}

function Confirm-Check {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][ValidatePattern("^[a-z0-9][a-z0-9-]{1,79}$")][string]$Id
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

function Get-CanonicalExistingFilePath {
    param([Parameter(Mandatory)][string]$Path)

    $canonical = [StaxRip.CrossPlatform.BrowserGate.NativeMethods]::CanonicalizeExistingFile(
        (Get-FullPath $Path))
    if (-not [System.IO.File]::Exists($canonical)) {
        throw [System.IO.FileNotFoundException]::new("CHECK:canonical-executable-missing")
    }
    return $canonical
}

function ConvertFrom-WindowsCommandLine {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$CommandLine)

    return [StaxRip.CrossPlatform.BrowserGate.NativeMethods]::ParseCommandLine($CommandLine)
}

function Test-ExactProfileArgument {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$ProfileDirectory
    )

    $expected = "--user-data-dir=$(Get-FullPath $ProfileDirectory)"
    $matches = 0
    foreach ($argument in $Arguments) {
        if ([string]::Equals($argument, $expected, [System.StringComparison]::OrdinalIgnoreCase)) {
            $matches++
        }
    }
    return $matches -eq 1
}

function Confirm-CommandLineParserSelfTest {
    $sampleProfile = 'C:\gate scratch\profile-01'
    $commandLine = '"C:\Program Files\Browser\browser.exe" --headless=new ' +
        '"--user-data-dir=C:\gate scratch\profile-01" about:blank'
    $arguments = @(ConvertFrom-WindowsCommandLine $commandLine)
    Confirm-Check ($arguments.Count -eq 4) "browser-argv-self-test-count"
    Confirm-Check ($arguments[0] -ceq 'C:\Program Files\Browser\browser.exe') "browser-argv-self-test-executable"
    Confirm-Check ($arguments[1] -ceq '--headless=new') "browser-argv-self-test-switch"
    Confirm-Check ($arguments[2] -ceq '--user-data-dir=C:\gate scratch\profile-01') "browser-argv-self-test-profile"
    Confirm-Check ($arguments[3] -ceq 'about:blank') "browser-argv-self-test-target"
    Confirm-Check (Test-ExactProfileArgument $arguments $sampleProfile) "browser-profile-argument-self-test-positive"

    $prefixCollision = @(
        'browser.exe',
        'prefix--user-data-dir=C:\gate scratch\profile-01',
        'about:blank')
    Confirm-Check (-not (Test-ExactProfileArgument $prefixCollision $sampleProfile)) `
        "browser-profile-argument-self-test-prefix"

    $suffixCollision = @(
        'browser.exe',
        '--user-data-dir=C:\gate scratch\profile-01-other',
        'about:blank')
    Confirm-Check (-not (Test-ExactProfileArgument $suffixCollision $sampleProfile)) `
        "browser-profile-argument-self-test-suffix"

    $splitArgument = @(
        'browser.exe',
        '--user-data-dir',
        'C:\gate scratch\profile-01',
        'about:blank')
    Confirm-Check (-not (Test-ExactProfileArgument $splitArgument $sampleProfile)) `
        "browser-profile-argument-self-test-split"

    $duplicateArgument = @(
        'browser.exe',
        '--user-data-dir=C:\gate scratch\profile-01',
        '--user-data-dir=C:\gate scratch\profile-01')
    Confirm-Check (-not (Test-ExactProfileArgument $duplicateArgument $sampleProfile)) `
        "browser-profile-argument-self-test-duplicate"
}

function New-StartedProcessReceipt {
    param(
        [Parameter(Mandatory)][System.Diagnostics.Process]$Process,
        [Parameter(Mandatory)][string]$CanonicalExecutablePath,
        [Parameter(Mandatory)][string]$Role
    )

    $Process.Refresh()
    return [pscustomobject]@{
        Pid = [int]$Process.Id
        StartTimeUtcTicks = [long]$Process.StartTime.ToUniversalTime().Ticks
        ExecutablePath = $CanonicalExecutablePath
        Role = $Role
        IsBrowserRoot = $null
        ProfileArgumentVerified = $false
    }
}

function Get-LiveReceiptProcess {
    param([Parameter(Mandatory)]$Receipt)

    $candidate = $null
    try {
        $candidate = Get-Process -Id $Receipt.Pid -ErrorAction Stop
        $candidate.Refresh()
        if ([long]$candidate.StartTime.ToUniversalTime().Ticks -ne [long]$Receipt.StartTimeUtcTicks) {
            $candidate.Dispose()
            return $null
        }
        $actualExecutable = Get-CanonicalExistingFilePath $candidate.MainModule.FileName
        if (-not [string]::Equals(
                $actualExecutable,
                $Receipt.ExecutablePath,
                [System.StringComparison]::OrdinalIgnoreCase)) {
            $candidate.Dispose()
            return $null
        }
        return $candidate
    }
    catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
        if ($null -ne $candidate) { $candidate.Dispose() }
        return $null
    }
    catch [System.ArgumentException] {
        if ($null -ne $candidate) { $candidate.Dispose() }
        return $null
    }
    catch [System.InvalidOperationException] {
        if ($null -ne $candidate) { $candidate.Dispose() }
        return $null
    }
    catch {
        if ($null -ne $candidate) { $candidate.Dispose() }
        throw
    }
}

function Test-ReceiptProcessGone {
    param([Parameter(Mandatory)]$Receipt)

    $live = Get-LiveReceiptProcess $Receipt
    if ($null -eq $live) { return $true }
    $live.Dispose()
    return $false
}

function Wait-ReceiptProcessGone {
    param(
        [Parameter(Mandatory)]$Receipt,
        [ValidateRange(100, 30000)][int]$TimeoutMilliseconds = 10000
    )

    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    do {
        if (Test-ReceiptProcessGone $Receipt) {
            return $true
        }
        Start-Sleep -Milliseconds 50
    } while ($timer.ElapsedMilliseconds -lt $TimeoutMilliseconds)
    return Test-ReceiptProcessGone $Receipt
}

function Stop-ReceiptProcess {
    param(
        [Parameter(Mandatory)]$Receipt,
        [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9-]{1,79}$')][string]$Id,
        [ValidateRange(100, 30000)][int]$TimeoutMilliseconds = 10000
    )

    $live = Get-LiveReceiptProcess $Receipt
    if ($null -eq $live) {
        return
    }
    try {
        # The PID, start time, and canonical executable were revalidated above.
        $live.Kill($true)
    }
    finally {
        $live.Dispose()
    }
    if (-not (Wait-ReceiptProcessGone $Receipt $TimeoutMilliseconds)) {
        throw [System.TimeoutException]::new("CHECK:$Id")
    }
}

function Stop-StartedProcessHandle {
    param(
        [Parameter(Mandatory)]$Producer,
        [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9-]{1,79}$')][string]$Id
    )

    if (-not $Producer.StartedHandleOwned) { return }
    $Producer.Process.Refresh()
    if ($Producer.Process.HasExited) { return }
    # This fallback is limited to the exact Process instance returned by Start.
    # It is used only when receipt construction itself failed.
    $Producer.Process.Kill($true)
    if (-not $Producer.Process.WaitForExit(10000)) {
        throw [System.TimeoutException]::new("CHECK:$Id")
    }
}

function Get-CapturedText {
    param(
        [Parameter(Mandatory)]$Capture,
        [Parameter(Mandatory)][ValidateSet('Stdout', 'Stderr')][string]$Stream,
        [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9-]{1,79}$')][string]$Id
    )

    $exceeded = if ($Stream -ceq 'Stdout') { $Capture.StdoutExceeded } else { $Capture.StderrExceeded }
    Confirm-Check (-not $exceeded) "$Id-bound"
    $text = if ($Stream -ceq 'Stdout') { $Capture.StdoutText } else { $Capture.StderrText }
    $normalized = $text.Replace("`r`n", "`n")
    Confirm-Check (-not $normalized.Contains("`r", [System.StringComparison]::Ordinal)) "$Id-line-endings"
    return $normalized.TrimEnd([char]10)
}

function Complete-ProducerCapture {
    param(
        [Parameter(Mandatory)]$Producer,
        [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9-]{1,79}$')][string]$Id,
        [switch]$ValidateBounds
    )

    if ($null -eq $Producer.Capture) { return }
    Confirm-Check ($Producer.Capture.WaitForCompletion(10000)) "$Id-drain-timeout"
    if ($ValidateBounds) {
        Confirm-Check (-not $Producer.Capture.StdoutExceeded) "$Id-stdout-bound"
        Confirm-Check (-not $Producer.Capture.StderrExceeded) "$Id-stderr-bound"
    }
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
    Confirm-Check ($fullPath.StartsWith(
        $fullRoot + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase)) $Id
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

function Test-EvidenceLeaseReceipt {
    if (-not $script:EvidenceLeaseAcquired -or
        $script:EvidenceLeaseNonce -cnotmatch '^[0-9a-f]{32}$' -or
        -not (Test-SafeExistingLeaf -Path $evidenceLeasePath -AllowedRoot $evidenceRoot)) {
        return $false
    }
    $stream = $null
    try {
        $stream = [System.IO.File]::Open(
            $evidenceLeasePath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::Read)
        if ($stream.Length -ne 33) { return $false }
        $bytes = [byte[]]::new(33)
        $offset = 0
        while ($offset -lt $bytes.Length) {
            $count = $stream.Read($bytes, $offset, $bytes.Length - $offset)
            if ($count -eq 0) { return $false }
            $offset += $count
        }
        return $stream.ReadByte() -eq -1 -and
            $stream.Length -eq 33 -and
            [System.Text.Encoding]::ASCII.GetString($bytes) -ceq "$($script:EvidenceLeaseNonce)`n"
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

function Test-EvidencePassPairInvalidated {
    return $script:EvidencePassPairInvalidated -and
        -not [System.IO.File]::Exists($auditSidecarPath) -and
        -not [System.IO.Directory]::Exists($auditSidecarPath) -and
        -not [System.IO.File]::Exists($auditPath) -and
        -not [System.IO.Directory]::Exists($auditPath)
}

function Remove-SafeEvidenceLeaf {
    param([Parameter(Mandatory)][string]$Path)

    if ([System.IO.Directory]::Exists($Path)) { return $false }
    if (-not [System.IO.File]::Exists($Path)) { return $true }
    if (-not (Test-SafeExistingLeaf -Path $Path -AllowedRoot $evidenceRoot)) { return $false }
    [System.IO.File]::Delete($Path)
    return -not [System.IO.File]::Exists($Path) -and -not [System.IO.Directory]::Exists($Path)
}

function Remove-ExactEvidenceWriterLease {
    if (-not $script:EvidenceLeaseAcquired) {
        return -not $script:EvidenceLeaseReceiptValidated -and
            -not $script:EvidencePassPairInvalidated -and
            $null -eq $script:EvidenceLeaseNonce
    }
    if (-not (Test-EvidenceLeaseReceipt)) { return $false }
    try {
        [System.IO.File]::Delete($evidenceLeasePath)
        if ([System.IO.File]::Exists($evidenceLeasePath) -or
            [System.IO.Directory]::Exists($evidenceLeasePath)) {
            return $false
        }
        $script:EvidenceLeaseAcquired = $false
        $script:EvidenceLeaseReceiptValidated = $false
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
        return $script:EvidenceLeaseReceiptValidated -and
            (Test-EvidenceLeaseReceipt) -and
            (Test-EvidencePassPairInvalidated)
    }
    if ($script:EvidenceLeaseReceiptValidated -or
        $script:EvidencePassPairInvalidated -or
        $null -ne $script:EvidenceLeaseNonce) {
        return $false
    }
    if (-not (Test-SafeArtifactDirectory -Path $evidenceRoot -Create) -or
        [System.IO.File]::Exists($evidenceLeasePath) -or
        [System.IO.Directory]::Exists($evidenceLeasePath)) {
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
        if (-not (Test-EvidenceLeaseReceipt)) { return $false }
        $script:EvidenceLeaseReceiptValidated = $true

        # A new producer result invalidates the previous aggregate pass before
        # either the producer evidence or its failure packet can change.
        if (-not (Remove-SafeEvidenceLeaf $auditSidecarPath)) { return $false }
        if (-not (Remove-SafeEvidenceLeaf $auditPath)) { return $false }
        if ([System.IO.File]::Exists($auditSidecarPath) -or
            [System.IO.Directory]::Exists($auditSidecarPath) -or
            [System.IO.File]::Exists($auditPath) -or
            [System.IO.Directory]::Exists($auditPath)) {
            return $false
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

function Test-RunOwnershipReceipt {
    param(
        [Parameter(Mandatory)][string]$RunDirectory,
        [Parameter(Mandatory)][string]$TaskRoot,
        [Parameter(Mandatory)][string]$OwnerNonce
    )

    if ($OwnerNonce -cnotmatch '^[0-9a-f]{32}$') { return $false }
    $ownerPath = Join-Path $RunDirectory '.browser-run-owner'
    if (-not (Test-SafeExistingLeaf -Path $ownerPath -AllowedRoot $TaskRoot)) { return $false }
    try {
        return [System.IO.File]::ReadAllText(
            $ownerPath,
            [System.Text.Encoding]::ASCII) -ceq "$OwnerNonce`n"
    }
    catch {
        return $false
    }
}

function Remove-ValidatedTaskDirectory {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$TaskRoot,
        [Parameter(Mandatory)][string]$OwnerNonce
    )
    if (-not [System.IO.Directory]::Exists($Path)) { return }
    $fullPath = Get-FullPath $Path
    $fullRoot = Get-FullPath $TaskRoot
    $parent = [System.IO.Directory]::GetParent($fullPath)
    $leaf = [System.IO.Path]::GetFileName($fullPath)
    if ($null -eq $parent -or
        -not [string]::Equals($parent.FullName, $fullRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        $leaf -notmatch "^run-[0-9a-f]{32}$") {
        throw [System.InvalidOperationException]::new("CHECK:cleanup-target")
    }
    Confirm-NoReparseComponents $fullRoot $crossPlatformRoot "browser-cleanup-root-no-reparse"
    Confirm-NoReparseComponents $fullPath $crossPlatformRoot "browser-cleanup-target-no-reparse"
    Confirm-Check `
        (Test-RunOwnershipReceipt $fullPath $fullRoot $OwnerNonce) `
        "browser-cleanup-owner-receipt"

    $ownerPath = Join-Path $fullPath '.browser-run-owner'
    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    # Diagnostic capture only. This records which path refused deletion and the exact
    # operating-system error, which the catch blocks below previously discarded. Two
    # separate cleanup timeouts had to be diagnosed by reading the retained tree off
    # disk because the packet named only the check. The deletion budget, the retry
    # cadence, and every pass or fail decision are deliberately unchanged. Tracked in
    # Docs/Review/SLICE-002-Remediation-Backlog.md as R-S2-038.
    $deleteFailures = [ordered]@{}
    $script:CleanupSurvivorDiagnostics = @()
    function Add-DeleteFailure {
        param([string]$FullName, [System.Management.Automation.ErrorRecord]$Record)

        $relative = $FullName
        if ($relative.StartsWith($fullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            $relative = $relative.Substring($fullPath.Length)
        }
        $relative = $relative.TrimStart([char[]]@('\', '/')).Replace('\', '/')
        if ($relative.Length -gt 160) { $relative = $relative.Substring(0, 160) }
        $deleteFailures[$relative] = '{0} hr=0x{1:X8}' -f `
            $Record.Exception.GetType().Name, $Record.Exception.HResult
    }

    do {
        Confirm-Check `
            (Test-RunOwnershipReceipt $fullPath $fullRoot $OwnerNonce) `
            "browser-cleanup-owner-revalidate"
        $items = @(Get-ChildItem -LiteralPath $fullPath -Recurse -Force)
        foreach ($item in @($items | Where-Object {
                    ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
                } | Sort-Object { $_.FullName.Length } -Descending)) {
            Confirm-Check (Test-PathBelow $item.FullName $fullPath) "browser-cleanup-reparse-contained"
            try {
                if ($item.PSIsContainer) {
                    [System.IO.Directory]::Delete($item.FullName, $false)
                }
                else {
                    [System.IO.File]::Delete($item.FullName)
                }
            }
            catch [System.IO.IOException] { Add-DeleteFailure $item.FullName $_ }
            catch [System.UnauthorizedAccessException] { Add-DeleteFailure $item.FullName $_ }
        }
        foreach ($item in @($items | Where-Object {
                    -not $_.PSIsContainer -and
                    ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0 -and
                    -not [string]::Equals(
                        (Get-FullPath $_.FullName),
                        (Get-FullPath $ownerPath),
                        [System.StringComparison]::OrdinalIgnoreCase)
                } | Sort-Object { $_.FullName.Length } -Descending)) {
            Confirm-Check (Test-PathBelow $item.FullName $fullPath) "browser-cleanup-file-contained"
            try { [System.IO.File]::Delete($item.FullName) }
            catch [System.IO.IOException] { Add-DeleteFailure $item.FullName $_ }
            catch [System.UnauthorizedAccessException] { Add-DeleteFailure $item.FullName $_ }
        }
        foreach ($item in @($items | Where-Object {
                    $_.PSIsContainer -and
                    ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0
                } | Sort-Object { $_.FullName.Length } -Descending)) {
            Confirm-Check (Test-PathBelow $item.FullName $fullPath) "browser-cleanup-directory-contained"
            try { [System.IO.Directory]::Delete($item.FullName, $false) }
            catch [System.IO.IOException] { Add-DeleteFailure $item.FullName $_ }
            catch [System.UnauthorizedAccessException] { Add-DeleteFailure $item.FullName $_ }
        }

        $remaining = @(Get-ChildItem -LiteralPath $fullPath -Force | Where-Object {
                -not [string]::Equals(
                    (Get-FullPath $_.FullName),
                    (Get-FullPath $ownerPath),
                    [System.StringComparison]::OrdinalIgnoreCase)
            })
        if ($remaining.Count -eq 0) {
            Confirm-Check `
                (Test-RunOwnershipReceipt $fullPath $fullRoot $OwnerNonce) `
                "browser-cleanup-owner-final"
            [System.IO.File]::Delete($ownerPath)
            [System.IO.Directory]::Delete($fullPath, $false)
            Confirm-Check (-not [System.IO.Directory]::Exists($fullPath)) "browser-cleanup-target-removed"
            return
        }
        Start-Sleep -Milliseconds 100
    } while ($timer.ElapsedMilliseconds -lt 10000)
    # Publish the survivors out of band. The thrown message must stay exactly
    # "CHECK:<id>" because the failure path matches it with an anchored pattern, so the
    # diagnostic cannot ride along in the message text.
    $script:CleanupSurvivorDiagnostics = @(
        $deleteFailures.GetEnumerator() |
            Select-Object -First 8 |
            ForEach-Object { '{0} [{1}]' -f $_.Key, $_.Value })
    throw [System.TimeoutException]::new("CHECK:browser-cleanup-tree-timeout")
}

function Get-SourceRecordSha256 {
    param([Parameter(Mandatory)][string]$EvidenceRoot)

    $sourceRecordLeaf = "static-gate.json"
    $sourceRecordMatches = @(Get-ChildItem -LiteralPath $EvidenceRoot -Force | Where-Object {
            [string]::Equals($_.Name, $sourceRecordLeaf, [System.StringComparison]::Ordinal)
        })
    Confirm-Check ($sourceRecordMatches.Count -eq 1) "browser-source-record-unique"

    $sourceRecordItem = $sourceRecordMatches[0]
    $expectedSourceRecordPath = Get-FullPath (Join-Path $EvidenceRoot $sourceRecordLeaf)
    Confirm-Check (
        [string]::Equals(
            (Get-FullPath $sourceRecordItem.FullName),
            $expectedSourceRecordPath,
            [System.StringComparison]::OrdinalIgnoreCase)) "browser-source-record-path"
    Confirm-Check (-not $sourceRecordItem.PSIsContainer) "browser-source-record-not-directory"
    Confirm-Check (
        (($sourceRecordItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0)) `
        "browser-source-record-no-reparse"
    Confirm-Check `
        (Test-SafeExistingLeaf -Path $sourceRecordItem.FullName -AllowedRoot $EvidenceRoot) `
        "browser-source-record-safe"

    $sourceRecordSha256 = (Get-FileHash -LiteralPath $sourceRecordItem.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    Confirm-Check ($sourceRecordSha256 -match "^[0-9a-f]{64}$") "browser-source-record-hash"
    Confirm-Check `
        (Test-SafeExistingLeaf -Path $sourceRecordItem.FullName -AllowedRoot $EvidenceRoot) `
        "browser-source-record-still-safe"
    return $sourceRecordSha256
}

# Composite identity of the managed set the apphost loads. SHA-256 over the
# newline-joined lowercase per-file hashes of the six runtime-relevant files, in this
# exact order, with a trailing newline. The same function exists verbatim in
# Verify-Http.ps1 and Verify-Evidence.ps1; drift between copies is self-revealing
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
        [Parameter(Mandatory)]$VerifiedBrowser,
        [Parameter(Mandatory)][string]$VerifiedServerPath
    )
    Confirm-Check (Test-EvidenceLeaseReceipt) "browser-success-publication-lease"
    Confirm-Check (Test-EvidencePassPairInvalidated) "browser-success-audit-invalidated"
    Confirm-NoReparseComponents $EvidenceRoot $crossPlatformRoot "browser-evidence-root-no-reparse"
    [void][System.IO.Directory]::CreateDirectory($EvidenceRoot)
    Confirm-NoReparseComponents $EvidenceRoot $crossPlatformRoot "browser-evidence-root-created"
    $sourceRecordSha256 = Get-SourceRecordSha256 $EvidenceRoot
    Confirm-Check (-not [string]::IsNullOrWhiteSpace($VerifiedBrowser.CdpName)) "browser-evidence-cdp-name"
    Confirm-Check (-not [string]::IsNullOrWhiteSpace($VerifiedBrowser.CdpVersion)) "browser-evidence-cdp-version"
    $currentBrowserHash = (Get-FileHash -LiteralPath $VerifiedBrowser.ExecutablePath -Algorithm SHA256).Hash.ToLowerInvariant()
    Confirm-Check ($currentBrowserHash -ceq $VerifiedBrowser.ExecutableSha256) "browser-executable-hash-still-current"
    $recordPath = Join-Path $EvidenceRoot "browser.json"
    Confirm-NoReparseComponents $recordPath $crossPlatformRoot "browser-evidence-leaf-no-reparse"
    # Named before record construction so a failure while hashing (missing or locked
    # file) is attributed to this step instead of the previous check id.
    $script:CurrentCheck = "browser-evidence-write"
    $record = [ordered]@{
        schema = "staxrip-browser-v1"
        gate = $gateId
        result = "pass"
        configuration = $Configuration
        sourceRecordSha256 = $sourceRecordSha256
        browser = [ordered]@{
            name = $VerifiedBrowser.CdpName
            version = $VerifiedBrowser.CdpVersion
            executableSha256 = $currentBrowserHash
        }
        serverSha256 = (Get-FileHash -LiteralPath $VerifiedServerPath -Algorithm SHA256).Hash.ToLowerInvariant()
        # Same managed-set binding as the HTTP gate: the apphost stub is identical
        # between configurations, so this composite is what makes the configuration
        # claim falsifiable. Tracked as R-S2-042.
        managedSetSha256 = (Get-ManagedSetSha256 -ServerDirectory (Split-Path -Parent $VerifiedServerPath))
        observedNetworkScope = "cdp-page-target-after-network-enable"
        checks = $script:CheckCount
        secretsPersisted = $false
    }
    Write-AtomicUtf8Artifact `
        -Path $recordPath `
        -Content (ConvertTo-CanonicalJson -InputObject $record -Depth 8)
}

function Protect-SensitiveConsoleText {
    param([AllowEmptyString()][string]$Text)

    $normalized = $Text.Replace("`r`n", "`n").Replace("`r", "`n")
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
            $normalized = [System.Text.RegularExpressions.Regex]::Replace(
                $normalized,
                [System.Text.RegularExpressions.Regex]::Escape($pathForm),
                '<redacted-path>',
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
                    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
        }
    }
    $safe = [System.Text.RegularExpressions.Regex]::Replace(
        $normalized,
        # The quoted form must cover the credential family as well as the four header
        # names. The assignment rule below requires the name to be followed directly by
        # ":" or "=", so a quoted JSON key such as {"token":"..."} never matched it and
        # a bearer token in a DevTools or CDP payload went undetected. The closing quote
        # is required immediately after the name, so "tokenizer" still does not match.
        # Tracked in Docs/Review/SLICE-002-Remediation-Backlog.md as R-S2-036.
        '(?im)^[^\r\n]*?["''](?:Authorization|Proxy-Authorization|Cookie|Set-Cookie|access[_-]?token|refresh[_-]?token|id[_-]?token|token|client[_-]?secret|secret|api[_-]?key|password)["'']\s*:[^\r\n]*$',
        '<redacted-sensitive-header-line>')
    $safe = [System.Text.RegularExpressions.Regex]::Replace(
        $safe,
        '(?im)^(?<prefix>[^\r\n]*?)(?<name>\b(?:Authorization|Proxy-Authorization|Cookie|Set-Cookie))[\t ]*:[^\r\n]*$',
        '${prefix}${name}: <redacted>')
    $safe = [System.Text.RegularExpressions.Regex]::Replace(
        $safe,
        '(?i)\b(access[_-]?token|refresh[_-]?token|id[_-]?token|token|secret|api[_-]?key|password)[\t ]*[:=][\t ]*(?:"[^"]*"|''[^'']*''|[^\s;,]+)',
        '$1=<redacted>')
    $safe = [System.Text.RegularExpressions.Regex]::Replace(
        $safe,
        '(?i)staxrip_session_[0-9a-f]{24}=[0-9a-f]{64}',
        'staxrip_session_<redacted>')
    $safe = [System.Text.RegularExpressions.Regex]::Replace(
        $safe,
        '(?i)\b(?<scheme>[a-z][a-z0-9+.-]*://)[^/\s@]+@',
        '${scheme}<redacted>@',
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
    return $safe
}

function Confirm-NoTokenText {
    param([AllowEmptyString()][string]$Text, [Parameter(Mandatory)][string]$Id)

    # Compare against the same line-ending normalization the redactor applies, so this
    # check tests only "did a redaction rule fire". Protect-SensitiveConsoleText
    # normalizes CRLF and bare CR to LF before applying any rule. Comparing its output
    # against the raw text therefore failed every payload containing CR regardless of
    # content, and the DevTools endpoints return CRLF JSON on Windows. Because the same
    # normalized string is on both sides, normalization cannot mask a redaction. Tracked
    # in Docs/Review/SLICE-002-Remediation-Backlog.md as R-S2-034.
    #
    # The quoted-JSON gap this comment used to describe was closed by R-S2-036: the
    # quoted-name rule now covers the credential family, not only the four header names,
    # and the self-test carries a case for each quoted form so the rule cannot be
    # reverted silently.
    $normalized = $Text.Replace("`r`n", "`n").Replace("`r", "`n")
    $protected = Protect-SensitiveConsoleText $Text
    Confirm-Check ([string]::Equals($protected, $normalized, [System.StringComparison]::Ordinal)) $Id
}

function Confirm-RedactionSelfTest {
    $sample = "Authorization: Bearer bearer-value`r`n" +
        "Authorization: opaque-value`r`n" +
        "Proxy-Authorization: Basic basic-value`r`n" +
        "Cookie: session=cookie-value`r`n" +
        "Set-Cookie: session=set-cookie-value; HttpOnly`r`n" +
        (('x' * 40) + " Authorization: Bearer long-prefix-value`r`n") +
        '{"Authorization":"Bearer json-value"}' + "`r`n" +
        # The four quoted credential-family keys below guard R-S2-036. Without them the
        # only quoted case was "Authorization", which the rule already covered before that
        # widening, so the widening could have been reverted with every self-test still
        # green. An independent verification proved exactly that by mutation. These four
        # make the guard real: revert the rule and this test goes red.
        '{"token":"json-token-value"}' + "`r`n" +
        '{"password":"json-password-value"}' + "`r`n" +
        '{"secret":"json-secret-value"}' + "`r`n" +
        '{"api_key":"json-api-key-value"}' + "`r`n" +
        "access_token=assignment-value`r`n" +
        "endpoint=https://synthetic-user:synthetic-password@example.invalid/path`r`n" +
        "path=$repositoryRoot"
    $expected = "Authorization: <redacted>`n" +
        "Authorization: <redacted>`n" +
        "Proxy-Authorization: <redacted>`n" +
        "Cookie: <redacted>`n" +
        "Set-Cookie: <redacted>`n" +
        (('x' * 40) + " Authorization: <redacted>`n") +
        "<redacted-sensitive-header-line>`n" +
        "<redacted-sensitive-header-line>`n" +
        "<redacted-sensitive-header-line>`n" +
        "<redacted-sensitive-header-line>`n" +
        "<redacted-sensitive-header-line>`n" +
        "access_token=<redacted>`n" +
        "endpoint=https://<redacted>@example.invalid/path`n" +
        "path=<redacted-path>"
    Confirm-Check (
        (Protect-SensitiveConsoleText $sample) -ceq $expected) `
        "browser-redaction-self-test-positive"

    $nearMiss = "Authorization note only`nCookieJar: synthetic`ntokenizer=enabled"
    Confirm-Check (
        (Protect-SensitiveConsoleText $nearMiss) -ceq $nearMiss) `
        "browser-redaction-self-test-near-miss"
}

function Start-BrowserTestServer {
    param(
        [Parameter(Mandatory)][string]$Executable,
        [Parameter(Mandatory)][string]$WorkingDirectory
    )
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Executable
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.ArgumentList.Add("--urls")
    $startInfo.ArgumentList.Add("http://0.0.0.0:61301")
    $startInfo.Environment["ASPNETCORE_URLS"] = "http://0.0.0.0:61302"
    $startInfo.Environment["ASPNETCORE_HTTP_PORTS"] = "61303"
    $startInfo.Environment["Kestrel__Endpoints__Hostile__Url"] = "http://0.0.0.0:61304"
    $startInfo.Environment["ASPNETCORE_HOSTINGSTARTUPASSEMBLIES"] = "Hostile.Startup.Assembly"
    $startInfo.Environment["ASPNETCORE_PREVENTHOSTINGSTARTUP"] = "false"

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $capture = [StaxRip.CrossPlatform.BrowserGate.BoundedProcessCapture]::new($maximumConsoleCharacters)
    $server = [pscustomobject]@{
        Process = $process
        Receipt = $null
        StartedHandleOwned = $false
        Capture = $capture
        BaseUri = $null
        Port = 0
        ReadyLine = $null
        Stopped = $false
    }
    $script:Server = $server
    if (-not $process.Start()) {
        throw [System.InvalidOperationException]::new("CHECK:browser-server-start")
    }
    $server.StartedHandleOwned = $true
    $server.Receipt = New-StartedProcessReceipt $process $Executable "server"
    $capture.Start($process)
    Confirm-Check $true "browser-server-start"
    $readyLine = $null
    if (-not $capture.TryGetFirstStdoutLine(20000, [ref]$readyLine)) {
        throw [System.TimeoutException]::new("CHECK:browser-server-ready-timeout")
    }
    $match = if ($null -eq $readyLine) {
        $null
    }
    else {
        [System.Text.RegularExpressions.Regex]::Match(
            $readyLine,
            "^READY http://127\.0\.0\.1:([1-9][0-9]{0,4})/$",
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
    }
    if ($null -eq $match -or -not $match.Success) {
        if ($process.HasExited) { $script:ProducerExit = $process.ExitCode }
        throw [System.InvalidOperationException]::new("CHECK:browser-server-ready-shape")
    }
    $server.BaseUri = [uri]$readyLine.Substring("READY ".Length)
    $server.Port = [int]$match.Groups[1].Value
    $server.ReadyLine = $readyLine
    return $server
}

function Stop-BrowserTestServer {
    param([Parameter(Mandatory)]$Server)
    if ($Server.Stopped) { return }
    if (Test-ReceiptProcessGone $Server.Receipt) {
        $Server.Process.Refresh()
        $script:ProducerExit = $Server.Process.ExitCode
        throw [System.InvalidOperationException]::new("CHECK:browser-server-unexpected-exit")
    }
    Stop-ReceiptProcess $Server.Receipt "browser-server-exit-timeout"
    Complete-ProducerCapture $Server "browser-server-capture" -ValidateBounds
    $stdout = Get-CapturedText $Server.Capture "Stdout" "browser-server-stdout"
    $stderr = Get-CapturedText $Server.Capture "Stderr" "browser-server-stderr"
    Confirm-Check ($stdout -ceq $Server.ReadyLine) "browser-server-no-extra-stdout"
    Confirm-Check ([string]::IsNullOrWhiteSpace($stderr)) "browser-server-no-stderr"
    Confirm-NoTokenText ($stdout + $stderr) "browser-server-no-token-log"
    $Server.Stopped = $true

    # The falsifying event is the socket exception from Start, not the boolean. Asserting
    # a literal meant this check could not fail, and worse, the exception did not carry a
    # "CHECK:<id>" message, so the failure walker never updated the current check id and a
    # leaked port was reported under the previous passing id, which is the credential-log
    # check. A leaked port presenting as a credential leak is the most misleading
    # attribution in this gate. Capture the outcome and assert it.
    $portReleased = $false
    $probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Server.Port)
    $probe.Server.ExclusiveAddressUse = $true
    try {
        $probe.Start()
        $portReleased = $true
    }
    catch [System.Net.Sockets.SocketException] { $portReleased = $false }
    finally {
        $probe.Stop()
    }
    Confirm-Check $portReleased "browser-server-port-released"
}

function Start-FixtureProcess {
    param(
        [Parameter(Mandatory)][string]$Origin,
        [Parameter(Mandatory)][string]$HtmlPath,
        [Parameter(Mandatory)][string]$WorkingDirectory
    )
    $pwshPath = [System.Environment]::ProcessPath
    Confirm-Check (-not [string]::IsNullOrWhiteSpace($pwshPath) -and [System.IO.File]::Exists($pwshPath)) "fixture-pwsh-path"
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $pwshPath
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @(
        "-NoLogo", "-NoProfile", "-NonInteractive", "-File", $PSCommandPath,
        "-ServeFixture", "-TargetOrigin", $Origin, "-FixturePath", $HtmlPath)) {
        $startInfo.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $capture = [StaxRip.CrossPlatform.BrowserGate.BoundedProcessCapture]::new($maximumConsoleCharacters)
    $fixture = [pscustomobject]@{
        Process = $process
        Receipt = $null
        StartedHandleOwned = $false
        Capture = $capture
        BaseUri = $null
        Port = 0
        ReadyLine = $null
        Stopped = $false
    }
    $script:Fixture = $fixture
    if (-not $process.Start()) {
        throw [System.InvalidOperationException]::new("CHECK:fixture-process-start")
    }
    $fixture.StartedHandleOwned = $true
    $fixture.Receipt = New-StartedProcessReceipt `
        $process `
        (Get-CanonicalExistingFilePath $pwshPath) `
        "fixture"
    $capture.Start($process)
    Confirm-Check $true "fixture-process-start"
    $readyLine = $null
    if (-not $capture.TryGetFirstStdoutLine(10000, [ref]$readyLine)) {
        throw [System.TimeoutException]::new("CHECK:fixture-ready-timeout")
    }
    $match = if ($null -eq $readyLine) {
        $null
    }
    else {
        [System.Text.RegularExpressions.Regex]::Match(
            $readyLine,
            "^FIXTURE_READY http://127\.0\.0\.1:([1-9][0-9]{0,4})/$",
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
    }
    if ($null -eq $match -or -not $match.Success) {
        if ($process.HasExited) { $script:ProducerExit = $process.ExitCode }
        throw [System.InvalidOperationException]::new("CHECK:fixture-ready-shape")
    }
    $fixture.BaseUri = [uri]$readyLine.Substring("FIXTURE_READY ".Length)
    $fixture.Port = [int]$match.Groups[1].Value
    $fixture.ReadyLine = $readyLine
    return $fixture
}

function Stop-FixtureProcess {
    param([Parameter(Mandatory)]$Fixture)
    if ($Fixture.Stopped) { return }
    if (Test-ReceiptProcessGone $Fixture.Receipt) {
        $Fixture.Process.Refresh()
        $script:ProducerExit = $Fixture.Process.ExitCode
        throw [System.InvalidOperationException]::new("CHECK:fixture-unexpected-exit")
    }
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.UseProxy = $false
    $client = [System.Net.Http.HttpClient]::new($handler, $true)
    $client.Timeout = [System.TimeSpan]::FromSeconds(5)
    try {
        $response = $client.GetAsync([uri]::new($Fixture.BaseUri, "/__stop")).GetAwaiter().GetResult()
        try { Confirm-Check ([int]$response.StatusCode -eq 200) "fixture-stop-status" }
        finally { $response.Dispose() }
    }
    finally {
        $client.Dispose()
    }
    Confirm-Check (Wait-ReceiptProcessGone $Fixture.Receipt 10000) "fixture-exit-timeout"
    Complete-ProducerCapture $Fixture "fixture-capture" -ValidateBounds
    $stdout = Get-CapturedText $Fixture.Capture "Stdout" "fixture-stdout"
    $stderr = Get-CapturedText $Fixture.Capture "Stderr" "fixture-stderr"
    Confirm-Check ($stdout -ceq ($Fixture.ReadyLine + "`nFIXTURE_STOPPED")) "fixture-stopped-marker"
    Confirm-Check ([string]::IsNullOrWhiteSpace($stderr)) "fixture-no-stderr"
    $Fixture.Process.Refresh()
    Confirm-Check ($Fixture.Process.ExitCode -eq 0) "fixture-exit-zero"
    $Fixture.Stopped = $true

    # Same repair as the server port above: assert the observed outcome, not a literal,
    # so a fixture port that was never released fails under its own id instead of the
    # previous passing one.
    $portReleased = $false
    $probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Fixture.Port)
    $probe.Server.ExclusiveAddressUse = $true
    try {
        $probe.Start()
        $portReleased = $true
    }
    catch [System.Net.Sockets.SocketException] { $portReleased = $false }
    finally {
        $probe.Stop()
    }
    Confirm-Check $portReleased "fixture-port-released"
}

function Start-HeadlessBrowser {
    param(
        [Parameter(Mandatory)][string]$Executable,
        [Parameter(Mandatory)][string]$ProfileDirectory,
        [Parameter(Mandatory)][string]$WorkingDirectory
    )
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Executable
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $arguments = @(
        "--headless=new",
        "--incognito",
        "--disable-gpu",
        "--disable-extensions",
        "--disable-default-apps",
        "--disable-background-networking",
        "--disable-component-update",
        "--disable-domain-reliability",
        "--disable-sync",
        "--disable-client-side-phishing-detection",
        "--safebrowsing-disable-auto-update",
        "--metrics-recording-only",
        "--no-first-run",
        "--no-default-browser-check",
        "--no-pings",
        "--no-proxy-server",
        "--disable-features=AutofillServerCommunication,CertificateTransparencyComponentUpdater,MediaRouter,OptimizationHints,Translate",
        "--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1",
        "--remote-debugging-address=127.0.0.1",
        "--remote-debugging-port=0",
        "--remote-allow-origins=*",
        "--log-level=3",
        "--user-data-dir=$ProfileDirectory",
        "about:blank"
    )
    foreach ($argument in $arguments) { $startInfo.ArgumentList.Add($argument) }
    $canonicalExecutable = Get-CanonicalExistingFilePath $Executable
    $executableSha256 = (Get-FileHash -LiteralPath $canonicalExecutable -Algorithm SHA256).Hash.ToLowerInvariant()
    Confirm-Check ($executableSha256 -match '^[0-9a-f]{64}$') "browser-executable-hash-prelaunch"

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $capture = [StaxRip.CrossPlatform.BrowserGate.BoundedProcessCapture]::new($maximumConsoleCharacters)
    $browser = [pscustomobject]@{
        Process = $process
        Receipt = $null
        StartedHandleOwned = $false
        Capture = $capture
        ExecutableName = [System.IO.Path]::GetFileName($canonicalExecutable)
        ExecutablePath = $canonicalExecutable
        ExecutableSha256 = $executableSha256
        ProfileDirectory = Get-FullPath $ProfileDirectory
        OwnedReceipts = [System.Collections.Generic.Dictionary[int, object]]::new()
        CdpName = $null
        CdpVersion = $null
        CdpRootReceipt = $null
        LauncherHandoff = $null
        LaunchLowerBoundUtcTicks = [System.DateTime]::UtcNow.AddSeconds(-1).Ticks
        Stopped = $false
    }
    $script:Browser = $browser
    if (-not $process.Start()) {
        throw [System.InvalidOperationException]::new("CHECK:browser-process-start")
    }
    $browser.StartedHandleOwned = $true
    $browser.Receipt = New-StartedProcessReceipt $process $canonicalExecutable "browser-launcher"
    $browser.Receipt.IsBrowserRoot = $true
    $browser.OwnedReceipts.Add($browser.Receipt.Pid, $browser.Receipt)
    $capture.Start($process)
    Confirm-Check $true "browser-process-start"
    return $browser
}

function Register-BrowserReceipt {
    param(
        [Parameter(Mandatory)]$Browser,
        [Parameter(Mandatory)]$Receipt
    )

    if ($Browser.OwnedReceipts.ContainsKey($Receipt.Pid)) {
        $existing = $Browser.OwnedReceipts[$Receipt.Pid]
        if ($existing.StartTimeUtcTicks -eq $Receipt.StartTimeUtcTicks -and
            [string]::Equals(
                $existing.ExecutablePath,
                $Receipt.ExecutablePath,
                [System.StringComparison]::OrdinalIgnoreCase)) {
            $existing.IsBrowserRoot = $Receipt.IsBrowserRoot
            $existing.ProfileArgumentVerified = $Receipt.ProfileArgumentVerified
            return $existing
        }
        $oldLive = Get-LiveReceiptProcess $existing
        if ($null -ne $oldLive) {
            $oldLive.Dispose()
            throw [System.InvalidOperationException]::new("CHECK:browser-process-receipt-collision")
        }
        [void]$Browser.OwnedReceipts.Remove($Receipt.Pid)
    }
    $Browser.OwnedReceipts.Add($Receipt.Pid, $Receipt)
    return $Receipt
}

function Get-ExactProfileBrowserReceipts {
    param([Parameter(Mandatory)]$Browser)

    $receipts = [System.Collections.Generic.List[object]]::new()
    $candidates = @(Get-CimInstance `
        -ClassName Win32_Process `
        -Filter "Name = '$($Browser.ExecutableName)'" `
        -ErrorAction Stop)
    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrEmpty($candidate.CommandLine)) { continue }
        $arguments = @(ConvertFrom-WindowsCommandLine $candidate.CommandLine)
        if (-not (Test-ExactProfileArgument $arguments $Browser.ProfileDirectory)) { continue }

        if ([string]::IsNullOrWhiteSpace($candidate.ExecutablePath)) {
            throw [System.InvalidOperationException]::new("CHECK:browser-owned-executable-missing")
        }
        $candidateExecutable = Get-CanonicalExistingFilePath $candidate.ExecutablePath
        if (-not [string]::Equals(
                $candidateExecutable,
                $Browser.ExecutablePath,
                [System.StringComparison]::OrdinalIgnoreCase)) {
            throw [System.InvalidOperationException]::new("CHECK:browser-owned-executable-mismatch")
        }

        $live = $null
        try {
            $live = Get-Process -Id ([int]$candidate.ProcessId) -ErrorAction Stop
            $live.Refresh()
            $startTicks = [long]$live.StartTime.ToUniversalTime().Ticks
        }
        catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
            continue
        }
        finally {
            if ($null -ne $live) { $live.Dispose() }
        }
        if ($startTicks -lt [long]$Browser.LaunchLowerBoundUtcTicks) {
            throw [System.InvalidOperationException]::new("CHECK:browser-owned-start-before-launch")
        }

        $receipt = [pscustomobject]@{
            Pid = [int]$candidate.ProcessId
            StartTimeUtcTicks = $startTicks
            ExecutablePath = $candidateExecutable
            Role = "browser-profile"
            IsBrowserRoot = @($arguments | Where-Object {
                    $_.StartsWith('--type=', [System.StringComparison]::Ordinal)
                }).Count -eq 0
            ProfileArgumentVerified = $true
        }
        $receipt = Register-BrowserReceipt $Browser $receipt
        $receipts.Add($receipt)
    }
    return @($receipts)
}

function Get-RevalidatedOwnedBrowserProcess {
    param(
        [Parameter(Mandatory)]$Browser,
        [Parameter(Mandatory)]$Receipt
    )

    $matches = @(Get-ExactProfileBrowserReceipts $Browser | Where-Object {
            $_.Pid -eq $Receipt.Pid -and
            $_.StartTimeUtcTicks -eq $Receipt.StartTimeUtcTicks -and
            [string]::Equals(
                $_.ExecutablePath,
                $Receipt.ExecutablePath,
                [System.StringComparison]::OrdinalIgnoreCase)
        })
    if ($matches.Count -eq 0) { return $null }
    if ($matches.Count -ne 1) {
        throw [System.InvalidOperationException]::new("CHECK:browser-owned-revalidation-ambiguous")
    }
    return Get-LiveReceiptProcess $Receipt
}

function Stop-RevalidatedOwnedBrowserProcess {
    param(
        [Parameter(Mandatory)]$Browser,
        [Parameter(Mandatory)]$Receipt
    )

    $live = Get-RevalidatedOwnedBrowserProcess $Browser $Receipt
    if ($null -eq $live) { return }
    try {
        # Exact argv ownership, PID, start time, and canonical executable were
        # revalidated immediately before this forceful tree termination.
        $live.Kill($true)
    }
    finally {
        $live.Dispose()
    }
}

function Wait-ProfileBrowserProcessesGone {
    param(
        [Parameter(Mandatory)]$Browser,
        [ValidateRange(100, 30000)][int]$TimeoutMilliseconds = 10000
    )

    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $zeroPasses = 0
    do {
        $remaining = @(Get-ExactProfileBrowserReceipts $Browser)
        if ($remaining.Count -eq 0) {
            $zeroPasses++
            if ($zeroPasses -ge 5) { return $true }
        }
        else {
            $zeroPasses = 0
        }
        Start-Sleep -Milliseconds 100
    } while ($timer.ElapsedMilliseconds -lt $TimeoutMilliseconds)
    return $false
}

function Stop-ProfileBrowserProcesses {
    param(
        [Parameter(Mandatory)]$Browser,
        [ValidateRange(100, 30000)][int]$TimeoutMilliseconds = 10000
    )

    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $zeroPasses = 0
    do {
        $owned = @(Get-ExactProfileBrowserReceipts $Browser)
        if ($owned.Count -eq 0) {
            $zeroPasses++
            if ($zeroPasses -ge 5) {
                return
            }
        }
        else {
            $zeroPasses = 0
            foreach ($receipt in $owned) {
                Stop-RevalidatedOwnedBrowserProcess $Browser $receipt
            }
        }
        Start-Sleep -Milliseconds 100
    } while ($timer.ElapsedMilliseconds -lt $TimeoutMilliseconds)

    if (@(Get-ExactProfileBrowserReceipts $Browser).Count -ne 0) {
        throw [System.TimeoutException]::new("CHECK:browser-profile-force-reap-timeout")
    }
}

function Wait-DevToolsPort {
    param(
        [Parameter(Mandatory)][string]$ProfileDirectory,
        [Parameter(Mandatory)]$Browser
    )
    $portFile = Join-Path $ProfileDirectory "DevToolsActivePort"
    $deadline = [System.DateTime]::UtcNow.AddSeconds(20)
    do {
        if ($Browser.Process.HasExited -and $Browser.Process.ExitCode -ne 0) {
            $script:ProducerExit = $Browser.Process.ExitCode
            throw [System.InvalidOperationException]::new("CHECK:browser-exited-before-devtools")
        }
        if ([System.IO.File]::Exists($portFile)) {
            try {
                $lines = [System.IO.File]::ReadAllLines($portFile)
                if ($lines.Count -ge 2 -and $lines[0] -match "^[1-9][0-9]{0,4}$") {
                    $port = [int]$lines[0]
                    if ($port -le 65535) { return $port }
                }
            }
            catch [System.IO.IOException] { }
        }
        Start-Sleep -Milliseconds 50
    } while ([System.DateTime]::UtcNow -lt $deadline)
    throw [System.TimeoutException]::new("CHECK:devtools-port-timeout")
}

function Connect-Cdp {
    param([Parameter(Mandatory)][int]$Port)
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.UseProxy = $false
    $client = [System.Net.Http.HttpClient]::new($handler, $true)
    $client.Timeout = [System.TimeSpan]::FromSeconds(5)
    try {
        $json = $client.GetStringAsync("http://127.0.0.1:$Port/json/list").GetAwaiter().GetResult()
    }
    finally {
        $client.Dispose()
    }
    Confirm-NoTokenText $json "devtools-list-no-token"
    $targets = @($json | ConvertFrom-Json)
    $page = @($targets | Where-Object { $_.type -ceq "page" } | Select-Object -First 1)
    Confirm-Check ($page.Count -eq 1) "devtools-page-target"
    $webSocketUri = $null
    Confirm-Check ([System.Uri]::TryCreate($page[0].webSocketDebuggerUrl, [System.UriKind]::Absolute, [ref]$webSocketUri)) "devtools-websocket-uri"
    Confirm-Check ($webSocketUri.Scheme -ceq "ws" -and $webSocketUri.Host -ceq "127.0.0.1" -and $webSocketUri.Port -eq $Port) "devtools-loopback-only"
    $socket = [System.Net.WebSockets.ClientWebSocket]::new()
    $socket.Options.Proxy = $null
    $socket.Options.SetRequestHeader("Origin", "http://127.0.0.1:$Port")
    $timeout = [System.Threading.CancellationTokenSource]::new([System.TimeSpan]::FromSeconds(10))
    try {
        [void]$socket.ConnectAsync($webSocketUri, $timeout.Token).GetAwaiter().GetResult()
    }
    finally {
        $timeout.Dispose()
    }
    Confirm-Check ($socket.State -eq [System.Net.WebSockets.WebSocketState]::Open) "devtools-websocket-open"
    $script:CdpSocket = $socket
}

function Connect-CdpBrowser {
    param([Parameter(Mandatory)][int]$Port)

    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.UseProxy = $false
    $client = [System.Net.Http.HttpClient]::new($handler, $true)
    $client.Timeout = [System.TimeSpan]::FromSeconds(5)
    try {
        $json = $client.GetStringAsync("http://127.0.0.1:$Port/json/version").GetAwaiter().GetResult()
    }
    finally {
        $client.Dispose()
    }
    Confirm-NoTokenText $json "devtools-version-no-token"
    $version = $json | ConvertFrom-Json
    Confirm-Check ($null -ne $version.PSObject.Properties['webSocketDebuggerUrl']) "devtools-browser-websocket-present"
    $webSocketUri = $null
    Confirm-Check (
        [System.Uri]::TryCreate(
            [string]$version.webSocketDebuggerUrl,
            [System.UriKind]::Absolute,
            [ref]$webSocketUri)) "devtools-browser-websocket-uri"
    Confirm-Check (
        $webSocketUri.Scheme -ceq "ws" -and
        $webSocketUri.Host -ceq "127.0.0.1" -and
        $webSocketUri.Port -eq $Port -and
        $webSocketUri.AbsolutePath.StartsWith(
            "/devtools/browser/",
            [System.StringComparison]::Ordinal)) "devtools-browser-loopback-only"

    $socket = [System.Net.WebSockets.ClientWebSocket]::new()
    $socket.Options.Proxy = $null
    $socket.Options.SetRequestHeader("Origin", "http://127.0.0.1:$Port")
    $timeout = [System.Threading.CancellationTokenSource]::new([System.TimeSpan]::FromSeconds(10))
    try {
        [void]$socket.ConnectAsync($webSocketUri, $timeout.Token).GetAwaiter().GetResult()
    }
    finally {
        $timeout.Dispose()
    }
    Confirm-Check (
        $socket.State -eq [System.Net.WebSockets.WebSocketState]::Open) `
        "devtools-browser-websocket-connected"
    $script:CdpSocket = $socket
}

function Confirm-CdpBrowserIdentity {
    param([Parameter(Mandatory)]$Browser)

    $processResult = Invoke-CdpCommand "SystemInfo.getProcessInfo" $null
    Confirm-Check ($null -ne $processResult) "browser-cdp-process-result"
    $browserProcesses = @($processResult.processInfo | Where-Object { $_.type -ceq 'browser' })
    Confirm-Check ($browserProcesses.Count -eq 1) "browser-cdp-browser-process-single"
    $cdpProcessId = [long]$browserProcesses[0].id
    Confirm-Check ($cdpProcessId -gt 0 -and $cdpProcessId -le [int]::MaxValue) "browser-cdp-browser-process-id"

    $profileReceipts = @(Get-ExactProfileBrowserReceipts $Browser)
    $rootReceipts = @($profileReceipts | Where-Object {
            $_.Pid -eq [int]$cdpProcessId -and
            $_.IsBrowserRoot -eq $true -and
            $_.ProfileArgumentVerified -eq $true
        })
    Confirm-Check ($rootReceipts.Count -eq 1) "browser-cdp-root-profile-receipt"
    $rootProcess = Get-RevalidatedOwnedBrowserProcess $Browser $rootReceipts[0]
    Confirm-Check ($null -ne $rootProcess) "browser-cdp-root-revalidated"
    $rootProcess.Dispose()
    $Browser.CdpRootReceipt = $rootReceipts[0]
    $Browser.LauncherHandoff = $Browser.CdpRootReceipt.Pid -ne $Browser.Receipt.Pid

    $identity = Invoke-CdpCommand "Browser.getVersion" $null
    Confirm-Check ($null -ne $identity) "browser-cdp-version-result"
    $product = [string]$identity.product
    Confirm-Check (-not [string]::IsNullOrWhiteSpace($product)) "browser-cdp-product-present"
    $expectedFamily = if ($Browser.ExecutableName -ceq "msedge.exe") { "Edg" } else { "Chrome" }
    $expectedName = if ($expectedFamily -ceq "Edg") { "edge" } else { "chrome" }
    $match = [System.Text.RegularExpressions.Regex]::Match(
        $product,
        "^$expectedFamily/([0-9]+(?:\.[0-9]+)+)$",
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
    Confirm-Check $match.Success "browser-cdp-product-family-version"
    $cdpVersion = $match.Groups[1].Value
    Confirm-Check ($cdpVersion.Length -le 32) "browser-cdp-version-bound"

    $fileVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo(
        $Browser.ExecutablePath).FileVersion
    Confirm-Check (
        -not [string]::IsNullOrWhiteSpace($fileVersion) -and
        $fileVersion -match '^[0-9]+(?:\.[0-9]+)+$') "browser-file-version-shape"
    Confirm-Check ($cdpVersion -ceq $fileVersion) "browser-cdp-file-version-match"

    $canonicalNow = Get-CanonicalExistingFilePath $Browser.ExecutablePath
    Confirm-Check (
        [string]::Equals(
            $canonicalNow,
            $Browser.Receipt.ExecutablePath,
            [System.StringComparison]::OrdinalIgnoreCase)) "browser-cdp-executable-path-match"
    $hashNow = (Get-FileHash -LiteralPath $canonicalNow -Algorithm SHA256).Hash.ToLowerInvariant()
    Confirm-Check ($hashNow -ceq $Browser.ExecutableSha256) "browser-cdp-executable-hash-match"

    $Browser.CdpName = $expectedName
    $Browser.CdpVersion = $cdpVersion
}

function Add-CdpEvent {
    param([Parameter(Mandatory)]$Message)
    if ($script:CdpEvents.Count -ge 256) {
        throw [System.InvalidOperationException]::new("CHECK:cdp-event-bound")
    }
    $method = [string]$Message.method
    $safe = $null
    if ($method -ceq "Network.requestWillBeSent") {
        $initiator = $Message.params.initiator
        $initiatorRequestIdProperty = $initiator.PSObject.Properties['requestId']
        $safe = [pscustomobject]@{
            Method = $method
            RequestId = [string]$Message.params.requestId
            HttpMethod = [string]$Message.params.request.method
            Url = [string]$Message.params.request.url
            DocumentUrl = [string]$Message.params.documentURL
            Type = [string]$Message.params.type
            InitiatorType = [string]$initiator.type
            InitiatorRequestId = if ($null -eq $initiatorRequestIdProperty) { '' } else { [string]$initiatorRequestIdProperty.Value }
        }
    }
    elseif ($method -ceq "Network.responseReceived") {
        $headers = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($property in $Message.params.response.headers.PSObject.Properties) {
            if (-not $property.Name.Equals("Set-Cookie", [System.StringComparison]::OrdinalIgnoreCase) -and
                -not $property.Name.Equals("Cookie", [System.StringComparison]::OrdinalIgnoreCase)) {
                $headers[$property.Name] = [string]$property.Value
            }
        }
        $safe = [pscustomobject]@{
            Method = $method
            RequestId = [string]$Message.params.requestId
            Url = [string]$Message.params.response.url
            Status = [int]$Message.params.response.status
            Headers = $headers
        }
    }
    elseif ($method -ceq 'Network.responseReceivedExtraInfo') {
        $safe = [pscustomobject]@{
            Method = $method
            RequestId = [string]$Message.params.requestId
            Status = [int]$Message.params.statusCode
        }
    }
    elseif ($method -ceq "Network.loadingFailed") {
        $blockedReasonProperty = $Message.params.PSObject.Properties["blockedReason"]
        $corsStatusProperty = $Message.params.PSObject.Properties['corsErrorStatus']
        $corsError = ''
        if ($null -ne $corsStatusProperty) {
            $corsErrorProperty = $corsStatusProperty.Value.PSObject.Properties['corsError']
            if ($null -ne $corsErrorProperty) {
                $corsError = [string]$corsErrorProperty.Value
            }
        }
        $safe = [pscustomobject]@{
            Method = $method
            RequestId = [string]$Message.params.requestId
            Type = [string]$Message.params.type
            BlockedReason = if ($null -eq $blockedReasonProperty) { "" } else { [string]$blockedReasonProperty.Value }
            CorsError = $corsError
        }
    }
    elseif ($method -ceq "Page.frameDetached") {
        $safe = [pscustomobject]@{
            Method = $method
            Reason = [string]$Message.params.reason
        }
    }
    elseif ($method -ceq "Log.entryAdded") {
        $text = [string]$Message.params.entry.text
        Confirm-NoTokenText $text "browser-log-no-token"
        $frameDenial = $text.Contains("Refused to display", [System.StringComparison]::OrdinalIgnoreCase) -or
            $text.Contains("frame-ancestors", [System.StringComparison]::OrdinalIgnoreCase) -or
            $text.Contains("X-Frame-Options", [System.StringComparison]::OrdinalIgnoreCase)
        $cspDenial = $text.Contains("Content Security Policy", [System.StringComparison]::OrdinalIgnoreCase) -or
            $text.Contains("script-src", [System.StringComparison]::OrdinalIgnoreCase)
        $safe = [pscustomobject]@{
            Method = $method
            FrameDenial = $frameDenial
            CspDenial = $cspDenial
        }
    }
    if ($null -ne $safe) { $script:CdpEvents.Add($safe) }
}

function Receive-CdpMessage {
    $memory = [System.IO.MemoryStream]::new()
    try {
        do {
            $buffer = [byte[]]::new(32768)
            $segment = [System.ArraySegment[byte]]::new($buffer)
            $timeout = [System.Threading.CancellationTokenSource]::new([System.TimeSpan]::FromSeconds(10))
            try {
                $received = $script:CdpSocket.ReceiveAsync($segment, $timeout.Token).GetAwaiter().GetResult()
            }
            finally {
                $timeout.Dispose()
            }
            if ($received.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
                throw [System.InvalidOperationException]::new("CHECK:cdp-closed")
            }
            if (($memory.Length + $received.Count) -gt $maximumCdpMessageBytes) {
                throw [System.InvalidOperationException]::new("CHECK:cdp-message-bound")
            }
            $memory.Write($buffer, 0, $received.Count)
        } while (-not $received.EndOfMessage)
        $text = [System.Text.Encoding]::UTF8.GetString($memory.ToArray())
        $message = $text | ConvertFrom-Json
        $methodProperty = $message.PSObject.Properties["method"]
        if ($null -eq $methodProperty -or
            -not ([string]$methodProperty.Value).StartsWith("Network.", [System.StringComparison]::Ordinal)) {
            Confirm-NoTokenText $text "cdp-message-no-token"
        }
        $text = $null
        return $message
    }
    finally {
        $memory.Dispose()
    }
}

function Invoke-CdpCommand {
    param(
        [Parameter(Mandatory)][string]$Method,
        [hashtable]$Parameters
    )
    $script:CdpCommandId++
    $id = $script:CdpCommandId
    $command = [ordered]@{ id = $id; method = $Method }
    if ($null -ne $Parameters) { $command.params = $Parameters }
    $json = $command | ConvertTo-Json -Compress -Depth 20
    Confirm-NoTokenText $json "cdp-command-no-token"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $segment = [System.ArraySegment[byte]]::new($bytes)
    $timeout = [System.Threading.CancellationTokenSource]::new([System.TimeSpan]::FromSeconds(10))
    try {
        [void]$script:CdpSocket.SendAsync(
            $segment,
            [System.Net.WebSockets.WebSocketMessageType]::Text,
            $true,
            $timeout.Token).GetAwaiter().GetResult()
    }
    finally {
        $timeout.Dispose()
    }
    $json = $null
    $bytes = $null

    while ($true) {
        $message = Receive-CdpMessage
        $idProperty = $message.PSObject.Properties["id"]
        if ($null -ne $idProperty -and [int]$idProperty.Value -eq $id) {
            Confirm-Check ($null -eq $message.PSObject.Properties["error"]) "cdp-command-success"
            $resultProperty = $message.PSObject.Properties["result"]
            if ($null -eq $resultProperty) { return $null }
            return $resultProperty.Value
        }
        if ($null -ne $message.PSObject.Properties["method"]) {
            Add-CdpEvent $message
        }
    }
}

function Invoke-CdpValue {
    param(
        [Parameter(Mandatory)][string]$Expression,
        [switch]$AwaitPromise
    )
    $parameters = @{
        expression = $Expression
        returnByValue = $true
        awaitPromise = [bool]$AwaitPromise
    }
    $result = Invoke-CdpCommand "Runtime.evaluate" $parameters
    Confirm-Check ($null -eq $result.PSObject.Properties["exceptionDetails"]) "runtime-evaluate-no-exception"
    $remote = $result.result
    $valueProperty = $remote.PSObject.Properties["value"]
    if ($null -eq $valueProperty) { return $null }
    return $valueProperty.Value
}

function Navigate-Cdp {
    param([Parameter(Mandatory)][string]$Url)
    $result = Invoke-CdpCommand "Page.navigate" @{ url = $Url }
    Confirm-Check ($null -eq $result.PSObject.Properties["errorText"]) "page-navigate-success"
    $deadline = [System.DateTime]::UtcNow.AddSeconds(15)
    do {
        $stateJson = Invoke-CdpValue "JSON.stringify({url: window.location.href, ready: document.readyState})"
        $state = $stateJson | ConvertFrom-Json
        if ([string]$state.url -ceq $Url -and [string]$state.ready -ceq "complete") { return }
        Start-Sleep -Milliseconds 50
    } while ([System.DateTime]::UtcNow -lt $deadline)
    throw [System.TimeoutException]::new("CHECK:page-load-timeout")
}

function Wait-ConnectedMarker {
    $deadline = [System.DateTime]::UtcNow.AddSeconds(15)
    do {
        $state = Invoke-CdpValue "document.documentElement.dataset.engineState || ''"
        if ($state -ceq "connected") { return }
        if ($state -ceq "error") { throw [System.InvalidOperationException]::new("CHECK:dom-engine-error") }
        Start-Sleep -Milliseconds 50
    } while ([System.DateTime]::UtcNow -lt $deadline)
    throw [System.TimeoutException]::new("CHECK:dom-connected-timeout")
}

function Get-NetworkRequests {
    return @($script:CdpEvents | Where-Object { $_.Method -ceq "Network.requestWillBeSent" })
}

function Confirm-AllowedNetworkOrigins {
    param(
        [Parameter(Mandatory)][object[]]$Events,
        [Parameter(Mandatory)][string[]]$AllowedAuthorities,
        [Parameter(Mandatory)][string]$Id
    )
    foreach ($event in $Events) {
        $uri = $null
        if ([System.Uri]::TryCreate($event.Url, [System.UriKind]::Absolute, [ref]$uri) -and
            ($uri.Scheme -ceq "http" -or $uri.Scheme -ceq "https")) {
            Confirm-Check ($AllowedAuthorities -ccontains $uri.GetLeftPart([System.UriPartial]::Authority)) $Id
        }
    }
}

function Stop-HeadlessBrowser {
    param([Parameter(Mandatory)]$Browser)
    if ($Browser.Stopped) { return }
    if ($null -ne $script:CdpSocket -and
        $script:CdpSocket.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
        try { [void](Invoke-CdpCommand "Browser.close" $null) } catch { }
    }
    if (-not (Wait-ProfileBrowserProcessesGone $Browser 10000)) {
        Stop-ProfileBrowserProcesses $Browser
        throw [System.TimeoutException]::new("CHECK:browser-profile-process-exit-timeout")
    }
    if (-not (Wait-ReceiptProcessGone $Browser.Receipt 10000)) {
        Stop-ReceiptProcess $Browser.Receipt "browser-launcher-force-reap-timeout"
        throw [System.TimeoutException]::new("CHECK:browser-exit-timeout")
    }
    Complete-ProducerCapture $Browser "browser-capture" -ValidateBounds
    $stdout = Get-CapturedText $Browser.Capture "Stdout" "browser-stdout"
    $stderr = Get-CapturedText $Browser.Capture "Stderr" "browser-stderr"
    Confirm-NoTokenText ($stdout + $stderr) "browser-console-no-token"
    $Browser.Process.Refresh()
    if ($Browser.Process.ExitCode -ne 0) {
        $script:ProducerExit = $Browser.Process.ExitCode
        throw [System.InvalidOperationException]::new("CHECK:browser-exit-zero")
    }
    $Browser.Stopped = $true
}

function Invoke-RunCleanup {
    param(
        [Parameter(Mandatory)][string]$RunDirectory,
        [Parameter(Mandatory)][string]$TaskRoot,
        [Parameter(Mandatory)][bool]$MayRemoveRunDirectory
    )

    $savedCheck = $script:CurrentCheck
    $errors = [System.Collections.Generic.List[string]]::new()
    try {
        if ($null -ne $script:CdpSocket) {
            try {
                if ($script:CdpSocket.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
                    try { [void](Invoke-CdpCommand "Browser.close" $null) } catch { }
                }
                $script:CdpSocket.Dispose()
                $script:CdpSocket = $null
            }
            catch {
                $errors.Add($_.Exception.GetType().Name)
            }
        }

        if ($null -ne $script:Browser) {
            try { Stop-ProfileBrowserProcesses $script:Browser 10000 }
            catch { $errors.Add($_.Exception.GetType().Name) }
            if ($null -ne $script:Browser.Receipt) {
                try { Stop-ReceiptProcess $script:Browser.Receipt "browser-cleanup-launcher-reap" }
                catch { $errors.Add($_.Exception.GetType().Name) }
            }
            else {
                try { Stop-StartedProcessHandle $script:Browser "browser-cleanup-launcher-handle-reap" }
                catch { $errors.Add($_.Exception.GetType().Name) }
            }
        }

        foreach ($producer in @($script:Fixture, $script:Server)) {
            if ($null -eq $producer) { continue }
            if ($null -eq $producer.Receipt) {
                try { Stop-StartedProcessHandle $producer "browser-cleanup-producer-handle-reap" }
                catch { $errors.Add($_.Exception.GetType().Name) }
                continue
            }
            try { Stop-ReceiptProcess $producer.Receipt "browser-cleanup-producer-reap" }
            catch { $errors.Add($_.Exception.GetType().Name) }
        }

        foreach ($producer in @($script:Browser, $script:Fixture, $script:Server)) {
            if ($null -eq $producer -or $null -eq $producer.Capture) { continue }
            try {
                if (-not $producer.Capture.WaitForCompletion(10000)) {
                    $errors.Add("CaptureDrainTimeout")
                }
            }
            catch {
                $errors.Add($_.Exception.GetType().Name)
            }
        }

        $browserRemaining = 0
        if ($null -ne $script:Browser) {
            try { $browserRemaining = @(Get-ExactProfileBrowserReceipts $script:Browser).Count }
            catch {
                $browserRemaining = -1
                $errors.Add($_.Exception.GetType().Name)
            }
        }

        $producerRemaining = 0
        foreach ($producer in @($script:Fixture, $script:Server)) {
            if ($null -eq $producer) { continue }
            if ($null -ne $producer.Receipt) {
                try {
                    if (-not (Test-ReceiptProcessGone $producer.Receipt)) { $producerRemaining++ }
                }
                catch {
                    $producerRemaining = -1
                    $errors.Add($_.Exception.GetType().Name)
                    break
                }
            }
            elseif ($producer.StartedHandleOwned) {
                try {
                    $producer.Process.Refresh()
                    if (-not $producer.Process.HasExited) { $producerRemaining++ }
                }
                catch {
                    $producerRemaining = -1
                    $errors.Add($_.Exception.GetType().Name)
                    break
                }
            }
        }
        $ownedRemaining = if ($browserRemaining -lt 0 -or $producerRemaining -lt 0) {
            -1
        }
        else {
            $browserRemaining + $producerRemaining
        }

        if ($MayRemoveRunDirectory -and $ownedRemaining -eq 0 -and
            [System.IO.Directory]::Exists($RunDirectory)) {
            try {
                Remove-ValidatedTaskDirectory `
                    -Path $RunDirectory `
                    -TaskRoot $TaskRoot `
                    -OwnerNonce $runOwnershipNonce
            }
            catch { $errors.Add($_.Exception.GetType().Name) }
        }

        $runRetained = [System.IO.Directory]::Exists($RunDirectory)
        $profileRetained = -not [string]::IsNullOrWhiteSpace($profileDirectory) -and
            [System.IO.Directory]::Exists($profileDirectory)
        $taskEntryCount = if ([System.IO.Directory]::Exists($TaskRoot)) {
            @(Get-ChildItem -LiteralPath $TaskRoot -Force).Count
        }
        else {
            0
        }
        return [pscustomobject]@{
            Complete = $ownedRemaining -eq 0 -and -not $runRetained -and $errors.Count -eq 0
            OwnedProcessesRemaining = $ownedRemaining
            RunRetained = $runRetained
            ProfileRetained = $profileRetained
            TaskRootEmpty = $taskEntryCount -eq 0
            ErrorCount = $errors.Count
            ErrorTypes = @($errors | Sort-Object -Unique | Select-Object -First 8)
            SurvivorDiagnostics = @($script:CleanupSurvivorDiagnostics)
        }
    }
    finally {
        $script:CurrentCheck = $savedCheck
    }
}

function Write-FailurePacket {
    param(
        [Parameter(Mandatory)][string]$FailureRoot,
        [Parameter(Mandatory)][System.Exception]$Exception,
        [Parameter(Mandatory)]$CleanupState
    )
    $primaryCheck = $script:CurrentCheck
    $outerType = $Exception.GetType().Name
    $cause = $Exception
    for ($depth = 0; $depth -lt 8 -and $null -ne $cause.InnerException; $depth++) {
        $cause = $cause.InnerException
    }
    try {
        Confirm-Check (Test-EvidenceLeaseReceipt) "browser-failure-publication-lease"
        Confirm-Check (Test-EvidencePassPairInvalidated) "browser-failure-audit-invalidated"
        Confirm-NoReparseComponents $FailureRoot $crossPlatformRoot "browser-failure-root-precreate"
        [void][System.IO.Directory]::CreateDirectory($FailureRoot)
        Confirm-NoReparseComponents $FailureRoot $crossPlatformRoot "browser-failure-root-created"
        $path = Join-Path $FailureRoot ("port-browser-" + $Configuration.ToLowerInvariant() + ".json")
        Confirm-NoReparseComponents $path $crossPlatformRoot "browser-failure-leaf-no-reparse"
        $packet = [ordered]@{
            gate = $gateId
            check = $primaryCheck
            exceptionType = $outerType
            causeType = $cause.GetType().Name
            producerExit = $script:ProducerExit
            configuration = $Configuration
            elapsedMs = $startedAt.ElapsedMilliseconds
            replay = "pwsh -NoProfile -NonInteractive -File CrossPlatform/eng/Verify-Browser.ps1 -BrowserPath <installed-browser>"
            stdoutRetained = $false
            stderrRetained = $false
            cookieContentsInspected = $false
            cleanupComplete = [bool]$CleanupState.Complete
            cleanupErrorCount = [int]$CleanupState.ErrorCount
            cleanupErrorTypes = @($CleanupState.ErrorTypes)
            cleanupSurvivors = @($CleanupState.SurvivorDiagnostics)
            ownedProcessesRemaining = [int]$CleanupState.OwnedProcessesRemaining
            taskRootEmpty = [bool]$CleanupState.TaskRootEmpty
            runRetained = [bool]$CleanupState.RunRetained
            profileRetained = [bool]$CleanupState.ProfileRetained
        } | ConvertTo-Json -Compress
        Write-AtomicUtf8Artifact -Path $path -Content $packet
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

    Assert-FailureCleanupState `
        (Test-EvidenceLeaseReceipt) `
        "browser-failure-cleanup-lease"

    $failureDirectoryName = [System.IO.Path]::GetFileName($FailureRoot)
    Assert-FailureCleanupState `
        ([string]::Equals($failureDirectoryName, "failures", [System.StringComparison]::Ordinal)) `
        "browser-failure-cleanup-root-name"
    Assert-FailureCleanupState `
        (Test-SafeArtifactDirectory -Path $ArtifactsRoot) `
        "browser-failure-cleanup-artifacts-root-safe"

    $failureRootMatches = @(Get-ChildItem -LiteralPath $ArtifactsRoot -Force | Where-Object {
            [string]::Equals($_.Name, $failureDirectoryName, [System.StringComparison]::Ordinal)
        })
    Assert-FailureCleanupState `
        ($failureRootMatches.Count -le 1) `
        "browser-failure-cleanup-root-unique"
    if ($failureRootMatches.Count -eq 0) {
        return
    }

    $failureRootItem = $failureRootMatches[0]
    Assert-FailureCleanupState `
        $failureRootItem.PSIsContainer `
        "browser-failure-cleanup-root-directory"
    Assert-FailureCleanupState `
        (($failureRootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) `
        "browser-failure-cleanup-root-no-reparse"
    Assert-FailureCleanupState `
        ([string]::Equals(
            (Get-FullPath $failureRootItem.FullName),
            (Get-FullPath $FailureRoot),
            [System.StringComparison]::OrdinalIgnoreCase)) `
        "browser-failure-cleanup-root-path"
    Assert-FailureCleanupState `
        (Test-SafeArtifactDirectory -Path $FailureRoot) `
        "browser-failure-cleanup-root-safe"

    $failureLeaf = "port-browser-$($Configuration.ToLowerInvariant()).json"
    $failureMatches = @(Get-ChildItem -LiteralPath $FailureRoot -Force | Where-Object {
            [string]::Equals($_.Name, $failureLeaf, [System.StringComparison]::Ordinal)
        })
    Assert-FailureCleanupState `
        ($failureMatches.Count -le 1) `
        "browser-failure-cleanup-leaf-unique"
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
        "browser-failure-cleanup-leaf-path"
    Assert-FailureCleanupState `
        (-not $failureItem.PSIsContainer) `
        "browser-failure-cleanup-leaf-not-directory"
    Assert-FailureCleanupState `
        (($failureItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) `
        "browser-failure-cleanup-leaf-no-reparse"
    Assert-FailureCleanupState `
        (Test-SafeExistingLeaf -Path $failureItem.FullName -AllowedRoot $FailureRoot) `
        "browser-failure-cleanup-leaf-safe"

    $script:CurrentCheck = "browser-failure-cleanup-leaf-delete"
    [System.IO.File]::Delete($failureItem.FullName)

    $remainingMatches = @(Get-ChildItem -LiteralPath $FailureRoot -Force | Where-Object {
            [string]::Equals($_.Name, $failureLeaf, [System.StringComparison]::Ordinal)
        })
    Assert-FailureCleanupState `
        ($remainingMatches.Count -eq 0) `
        "browser-failure-cleanup-leaf-removed"
}

$crossPlatformRoot = Get-FullPath (Join-Path $PSScriptRoot "..")
$repositoryRoot = Get-FullPath (Join-Path $crossPlatformRoot "..")
$artifactsRoot = Get-FullPath (Join-Path $crossPlatformRoot "artifacts")
$taskRoot = Get-FullPath (Join-Path $artifactsRoot "tmp\port-browser")
$failureRoot = Get-FullPath (Join-Path $artifactsRoot "failures")
$evidenceRoot = Get-FullPath (Join-Path $artifactsRoot "evidence")
$auditPath = Get-FullPath (Join-Path $evidenceRoot "evidence-audit.json")
$auditSidecarPath = Get-FullPath (Join-Path $evidenceRoot "evidence-audit.json.sha256")
$evidenceLeasePath = Get-FullPath (Join-Path $evidenceRoot ".evidence-writer.lock")
$runLeaf = "run-" + [System.Guid]::NewGuid().ToString("N")
$runDirectory = Join-Path $taskRoot $runLeaf
$cleanupAllowed = $false
$profileDirectory = $null
$runOwnershipNonce = $null

Initialize-BrowserGateNativeHelpers

try {
    Confirm-Check $IsWindows "browser-windows-host-required"
    Confirm-CommandLineParserSelfTest
    Confirm-RedactionSelfTest
    Confirm-Check (-not [string]::IsNullOrWhiteSpace($BrowserPath)) "browser-path-required"
    $BrowserPath = Get-CanonicalExistingFilePath $BrowserPath
    Confirm-Check ([System.IO.File]::Exists($BrowserPath)) "browser-executable-exists"
    Confirm-Check (@("msedge.exe", "chrome.exe") -ccontains [System.IO.Path]::GetFileName($BrowserPath)) "browser-executable-name"

    if ([string]::IsNullOrWhiteSpace($ServerPath)) {
        $pivot = $Configuration.ToLowerInvariant()
        $ServerPath = Join-Path $artifactsRoot "bin\StaxRip.Server\$pivot\StaxRip.Server.exe"
    }
    $ServerPath = Get-CanonicalExistingFilePath $ServerPath
    Confirm-Check ([System.IO.File]::Exists($ServerPath)) "browser-server-apphost-exists"
    Confirm-Check ([System.IO.Path]::GetFileName($ServerPath) -ceq "StaxRip.Server.exe") "browser-server-apphost-name"

    Confirm-NoReparseComponents $taskRoot $crossPlatformRoot "browser-task-root-precreate"
    Confirm-Check (Enter-EvidenceWriterLease) "browser-runtime-lease-acquire"
    [void][System.IO.Directory]::CreateDirectory($taskRoot)
    Confirm-NoReparseComponents $taskRoot $crossPlatformRoot "browser-task-root-created"
    $taskEntries = @(Get-ChildItem -LiteralPath $taskRoot -Force)
    $staleRuns = @($taskEntries | Where-Object { $_.Name -cmatch '^run-[0-9a-f]{32}$' })
    Confirm-Check ($staleRuns.Count -eq 0) "browser-stale-run-root"
    Confirm-Check ($taskEntries.Count -eq 0) "browser-task-root-empty-preflight"
    $runDirectory = Confirm-DescendantPath $runDirectory $taskRoot "browser-run-directory-scope"
    [void][System.IO.Directory]::CreateDirectory($runDirectory)
    Confirm-NoReparseComponents $runDirectory $crossPlatformRoot "browser-run-directory-created"
    $runOwnershipNonce = [System.Guid]::NewGuid().ToString('N')
    $runOwnerPath = Join-Path $runDirectory '.browser-run-owner'
    $ownerStream = [System.IO.File]::Open(
        $runOwnerPath,
        [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None)
    try {
        $ownerBytes = [System.Text.Encoding]::ASCII.GetBytes("$runOwnershipNonce`n")
        $ownerStream.Write($ownerBytes, 0, $ownerBytes.Length)
        $ownerStream.Flush($true)
    }
    finally {
        $ownerStream.Dispose()
    }
    Confirm-Check `
        (Test-RunOwnershipReceipt $runDirectory $taskRoot $runOwnershipNonce) `
        "browser-run-owner-receipt"
    $cleanupAllowed = $true
    $serverWorking = Join-Path $runDirectory "hostile-working"
    $fixtureWorking = Join-Path $runDirectory "fixture-working"
    $profileDirectory = Join-Path $runDirectory "browser-profile"
    foreach ($directory in @($serverWorking, $fixtureWorking, $profileDirectory)) {
        [void][System.IO.Directory]::CreateDirectory($directory)
    }
    [System.IO.File]::WriteAllText(
        (Join-Path $serverWorking "appsettings.json"),
        "{`"Urls`":`"http://0.0.0.0:61305`"}",
        [System.Text.UTF8Encoding]::new($false))

    $server = Start-BrowserTestServer $ServerPath $serverWorking
    $targetOrigin = $server.BaseUri.GetLeftPart([System.UriPartial]::Authority)
    $fixtureHtml = Get-FullPath (Join-Path $PSScriptRoot "fixtures\hostile-browser.html")
    $fixture = Start-FixtureProcess $server.BaseUri.AbsoluteUri $fixtureHtml $fixtureWorking
    Confirm-Check ($fixture.Port -ne $server.Port) "browser-origin-port-separation"

    $browser = Start-HeadlessBrowser $BrowserPath $profileDirectory $runDirectory
    $devToolsPort = Wait-DevToolsPort $profileDirectory $browser
    Confirm-Check ($devToolsPort -ne $server.Port -and $devToolsPort -ne $fixture.Port) "devtools-port-separation"
    Connect-CdpBrowser $devToolsPort
    Confirm-CdpBrowserIdentity $browser
    $script:CdpSocket.Dispose()
    $script:CdpSocket = $null
    Connect-Cdp $devToolsPort
    [void](Invoke-CdpCommand "Page.enable" $null)
    [void](Invoke-CdpCommand "Runtime.enable" $null)
    [void](Invoke-CdpCommand "Network.enable" @{ maxTotalBufferSize = 1048576; maxResourceBufferSize = 262144 })
    [void](Invoke-CdpCommand "Log.enable" $null)

    $script:CdpEvents.Clear()
    Navigate-Cdp $server.BaseUri.AbsoluteUri
    Wait-ConnectedMarker
    $marker = Invoke-CdpValue "document.body.dataset.appMarker + '|' + document.documentElement.dataset.engineState + '|' + document.getElementById('connection-result').dataset.result"
    Confirm-Check ($marker -ceq "staxrip-local-engine-shell|connected|connected") "browser-connected-dom-marker"

    $targetRequests = Get-NetworkRequests
    Confirm-AllowedNetworkOrigins $targetRequests @($targetOrigin) "browser-target-no-third-party"
    $targetPaths = @($targetRequests | ForEach-Object {
        $requestUri = [uri]$_.Url
        $requestUri.AbsolutePath
    } | Sort-Object -Unique)
    foreach ($requiredPath in @("/", "/app.css", "/app.js", "/api/v1/capabilities")) {
        Confirm-Check ($targetPaths -ccontains $requiredPath) "browser-target-request-set"
    }

    Navigate-Cdp ([uri]::new($server.BaseUri, "/api/v1/capabilities").AbsoluteUri)
    $visibleCookie = Invoke-CdpValue "document.cookie"
    Confirm-Check ([string]::IsNullOrEmpty([string]$visibleCookie)) "browser-cookie-httponly-at-cookie-path"

    Navigate-Cdp $server.BaseUri.AbsoluteUri
    Wait-ConnectedMarker
    [void](Invoke-CdpValue "(() => { delete window.__staxripInlineProbe; const script = document.createElement('script'); script.textContent = 'window.__staxripInlineProbe = true'; document.documentElement.appendChild(script); return true; })()")
    $inlineRan = Invoke-CdpValue "new Promise(resolve => setTimeout(() => resolve(window.__staxripInlineProbe === true), 250))" -AwaitPromise
    Confirm-Check ($inlineRan -eq $false) "browser-csp-inline-blocked"

    $script:CdpEvents.Clear()
    Navigate-Cdp $fixture.BaseUri.AbsoluteUri
    $hostileMarker = Invoke-CdpValue "document.body.dataset.hostileProbe || ''"
    Confirm-Check ($hostileMarker -ceq "ready") "browser-hostile-origin-loaded"
    $targetLiteral = $targetOrigin
    $crossOriginResultJson = Invoke-CdpValue @"
(async () => {
  const result = { simpleReadable: false, customReadable: false };
  try {
    const response = await fetch('$targetLiteral/healthz', {
      method: 'GET', mode: 'cors', credentials: 'include', cache: 'no-store'
    });
    await response.text();
    result.simpleReadable = true;
  } catch (_) { }
  try {
    const response = await fetch('$targetLiteral/api/v1/capabilities', {
      method: 'GET', mode: 'cors', credentials: 'include', cache: 'no-store',
      headers: { 'X-StaxRip-Client': 'web' }
    });
    await response.text();
    result.customReadable = true;
  } catch (_) { }
  await new Promise(resolve => setTimeout(resolve, 500));
  return JSON.stringify(result);
})()
"@ -AwaitPromise
    $crossOriginResult = $crossOriginResultJson | ConvertFrom-Json
    Confirm-Check ($crossOriginResult.simpleReadable -eq $false) "browser-simple-cross-origin-read-denied"
    Confirm-Check ($crossOriginResult.customReadable -eq $false) "browser-custom-cross-origin-read-denied"

    $hostileRequests = Get-NetworkRequests
    $fixtureOrigin = $fixture.BaseUri.GetLeftPart([System.UriPartial]::Authority)
    Confirm-AllowedNetworkOrigins $hostileRequests @($targetOrigin, $fixtureOrigin) "browser-hostile-no-third-party"
    $fixtureDocument = $fixture.BaseUri.AbsoluteUri
    $healthGets = @($hostileRequests | Where-Object {
            $_.DocumentUrl -ceq $fixtureDocument -and
            $_.HttpMethod -ceq "GET" -and
            $_.Url -ceq "$targetOrigin/healthz"
        })
    $apiLogicalGets = @($hostileRequests | Where-Object {
            $_.DocumentUrl -ceq $fixtureDocument -and
            $_.HttpMethod -ceq "GET" -and
            $_.Url -ceq "$targetOrigin/api/v1/capabilities"
        })
    $apiLogicalIds = @($apiLogicalGets | ForEach-Object { $_.RequestId })
    $apiPreflights = @($hostileRequests | Where-Object {
            $_.HttpMethod -ceq "OPTIONS" -and
            $_.Url -ceq "$targetOrigin/api/v1/capabilities" -and
            $_.Type -cin @('Other', 'Preflight') -and
            $_.InitiatorType -ceq 'preflight' -and
            $apiLogicalIds -ccontains $_.InitiatorRequestId
        })
    Confirm-Check ($healthGets.Count -eq 1) "browser-simple-request-observed"
    Confirm-Check ($apiLogicalGets.Count -eq 1) "browser-custom-logical-request-observed"
    Confirm-Check ($apiPreflights.Count -eq 1) "browser-custom-preflight-observed"

    $responses = @($script:CdpEvents | Where-Object { $_.Method -ceq "Network.responseReceived" })
    $apiResponses = @($responses | Where-Object { $apiLogicalIds -ccontains $_.RequestId })
    $extraResponses = @($script:CdpEvents | Where-Object { $_.Method -ceq 'Network.responseReceivedExtraInfo' })
    $healthExtraResponses = @($extraResponses | Where-Object { $healthGets.RequestId -ccontains $_.RequestId })
    $preflightExtraResponses = @($extraResponses | Where-Object { $apiPreflights.RequestId -ccontains $_.RequestId })
    $apiExtraResponses = @($extraResponses | Where-Object { $apiLogicalIds -ccontains $_.RequestId })
    $loadingFailures = @($script:CdpEvents | Where-Object { $_.Method -ceq 'Network.loadingFailed' })
    $apiFailures = @($loadingFailures | Where-Object { $apiLogicalIds -ccontains $_.RequestId })
    Confirm-Check (
        $healthExtraResponses.Count -eq 1 -and
        $healthExtraResponses[0].Status -eq 403) `
        "browser-simple-origin-rejected"
    Confirm-Check (
        $preflightExtraResponses.Count -eq 1 -and
        $preflightExtraResponses[0].Status -eq 403) `
        "browser-custom-preflight-rejected"
    Confirm-Check (
        $apiResponses.Count -eq 0 -and
        $apiExtraResponses.Count -eq 0) `
        "browser-custom-api-no-response"
    Confirm-Check (
        $apiFailures.Count -eq 1 -and
        -not [string]::IsNullOrWhiteSpace($apiFailures[0].CorsError)) `
        "browser-custom-api-cors-failed"
    foreach ($response in $responses) {
        foreach ($name in $response.Headers.Keys) {
            Confirm-Check (-not $name.StartsWith("Access-Control-Allow-", [System.StringComparison]::OrdinalIgnoreCase)) "browser-no-cors-permission"
        }
    }
    $frameResponses = @($responses | Where-Object { $_.Url -ceq $server.BaseUri.AbsoluteUri })
    Confirm-Check ($frameResponses.Count -ge 1) "browser-frame-response-observed"
    $framePolicy = $false
    foreach ($frameResponse in $frameResponses) {
        if ($frameResponse.Headers.ContainsKey("X-Frame-Options") -and
            $frameResponse.Headers["X-Frame-Options"] -ceq "DENY" -and
            $frameResponse.Headers.ContainsKey("Content-Security-Policy") -and
            $frameResponse.Headers["Content-Security-Policy"].Contains("frame-ancestors 'none'", [System.StringComparison]::Ordinal)) {
            $framePolicy = $true
        }
    }
    Confirm-Check $framePolicy "browser-frame-denial-policy-observed"

    $frameTree = Invoke-CdpCommand "Page.getFrameTree" $null
    $frameTreeJson = $frameTree | ConvertTo-Json -Compress -Depth 20
    Confirm-NoTokenText $frameTreeJson "browser-frame-tree-no-token"
    $logFrameDenial = @($script:CdpEvents | Where-Object { $_.Method -ceq "Log.entryAdded" -and $_.FrameDenial }).Count -gt 0
    $frameRequestIds = @($hostileRequests | Where-Object {
        $_.HttpMethod -ceq "GET" -and $_.Type -ceq "Document" -and $_.Url -ceq $server.BaseUri.AbsoluteUri
    } | ForEach-Object { $_.RequestId })
    Confirm-Check ($frameRequestIds.Count -eq 1) "browser-frame-request-correlated"
    $frameLoadingFailure = @($script:CdpEvents | Where-Object {
        $_.Method -ceq "Network.loadingFailed" -and
        $_.Type -ceq "Document" -and
        $frameRequestIds -ccontains $_.RequestId -and
        -not [string]::IsNullOrWhiteSpace($_.BlockedReason)
    }).Count -eq 1
    $unreachableFrame = $frameTreeJson.Contains("unreachableUrl", [System.StringComparison]::Ordinal) -or
        -not $frameTreeJson.Contains($server.BaseUri.AbsoluteUri, [System.StringComparison]::Ordinal)
    Confirm-Check ($logFrameDenial -or $frameLoadingFailure -or ($unreachableFrame -and $frameRequestIds.Count -eq 1)) "browser-frame-denial-enforced"

    $finalRootProcess = Get-RevalidatedOwnedBrowserProcess $browser $browser.CdpRootReceipt
    Confirm-Check ($null -ne $finalRootProcess) "browser-cdp-root-current-before-close"
    $finalRootProcess.Dispose()
    Stop-HeadlessBrowser $browser
    if ($null -ne $script:CdpSocket) {
        $script:CdpSocket.Dispose()
        $script:CdpSocket = $null
    }
    Stop-FixtureProcess $fixture
    Stop-BrowserTestServer $server

    $script:CleanupState = Invoke-RunCleanup $runDirectory $taskRoot $cleanupAllowed
    Confirm-Check $script:CleanupState.Complete "browser-success-cleanup-complete"
    Confirm-Check ($script:CleanupState.OwnedProcessesRemaining -eq 0) "browser-success-owned-processes-zero"
    Confirm-Check (-not $script:CleanupState.ProfileRetained) "browser-success-profile-removed"
    Confirm-Check (-not $script:CleanupState.RunRetained) "browser-success-run-removed"
    Confirm-Check $script:CleanupState.TaskRootEmpty "browser-success-task-root-empty"
    Confirm-Check (@(Get-ExactProfileBrowserReceipts $browser).Count -eq 0) "browser-success-profile-processes-rechecked"
    $cleanupAllowed = $false

    Confirm-Check (Enter-EvidenceWriterLease) "browser-success-publication-lease-current"
    Remove-OwnFailurePacket -ArtifactsRoot $artifactsRoot -FailureRoot $failureRoot
    Write-SuccessRecord $evidenceRoot $browser $ServerPath
    $leaseReleased = Exit-EvidenceWriterLease
    Confirm-Check $leaseReleased "browser-success-publication-lease-release"
    $startedAt.Stop()
    Write-Output "PASS $gateId checks=$script:CheckCount elapsed_ms=$($startedAt.ElapsedMilliseconds) evidence=CrossPlatform/artifacts/evidence/browser.json"
    exit 0
}
catch {
    $exception = $_.Exception
    $exceptionType = $exception.GetType().Name
    try {
        $script:CleanupState = Invoke-RunCleanup $runDirectory $taskRoot $cleanupAllowed
    }
    catch {
        $taskRootEmpty = $false
        try {
            $taskRootEmpty = -not [System.IO.Directory]::Exists($taskRoot) -or
                @(Get-ChildItem -LiteralPath $taskRoot -Force).Count -eq 0
        }
        catch { }
        $script:CleanupState = [pscustomobject]@{
            Complete = $false
            OwnedProcessesRemaining = -1
            RunRetained = [System.IO.Directory]::Exists($runDirectory)
            ProfileRetained = -not [string]::IsNullOrWhiteSpace($profileDirectory) -and
                [System.IO.Directory]::Exists($profileDirectory)
            TaskRootEmpty = $taskRootEmpty
            ErrorCount = 1
            ErrorTypes = @('CleanupStateUnavailable')
        }
    }

    $cause = $exception
    for ($depth = 0; $depth -lt 8; $depth++) {
        if ($cause.Message -cmatch '^CHECK:([a-z0-9][a-z0-9-]{1,79})$') {
            $script:CurrentCheck = $Matches[1]
        }
        if ($null -eq $cause.InnerException) {
            break
        }
        $cause = $cause.InnerException
    }
    $causeType = $cause.GetType().Name
    $failurePublished = $false
    try {
        if (Enter-EvidenceWriterLease) {
            Write-FailurePacket $failureRoot $exception $script:CleanupState
            $failurePublished = $true
        }
    }
    catch { }
    $leaseReleased = Exit-EvidenceWriterLease
    if (-not $leaseReleased) { $failurePublished = $false }
    $startedAt.Stop()
    try {
        $failureEvidence = if ($failurePublished) {
            "CrossPlatform/artifacts/failures/port-browser-$($Configuration.ToLowerInvariant()).json"
        }
        else {
            "none"
        }
        [Console]::Error.WriteLine(
            "FAIL $gateId check=$script:CurrentCheck type=$exceptionType cause=$causeType cleanup=$($script:CleanupState.Complete) evidence=$failureEvidence")
    }
    catch { }
    if ($script:ProducerExit -is [int] -and $script:ProducerExit -ne 0) {
        exit $script:ProducerExit
    }
    exit 1
}
finally {
    if ($null -ne $script:CdpSocket) {
        try { $script:CdpSocket.Dispose() } catch { }
    }
    foreach ($producer in @($script:Browser, $script:Fixture, $script:Server)) {
        if ($null -eq $producer) { continue }
        try { $producer.Process.Dispose() } catch { }
        try {
            if ($null -ne $producer.Capture -and $producer.Capture.WaitForCompletion(1)) {
                $producer.Capture.Dispose()
            }
        }
        catch { }
    }
    if ($script:EvidenceLeaseAcquired) { try { [void](Exit-EvidenceWriterLease) } catch { } }
}
