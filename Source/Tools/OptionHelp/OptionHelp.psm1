Set-StrictMode -Version Latest

$script:HeaderKeys = @('Schema', 'Encoder', 'Locale', 'Title', 'Source', 'Inherits',
    'Allowed-Missing', 'Minimum-Reviewed', 'Reviewed-Complete',
    'Verified-Encoder-Version', 'Verified-Encoder-Build', 'Verified-Date', 'Documentation')
$script:FieldOrder = @('Label', 'Use', 'Summary', 'Used when', 'When to change',
    'Encoder default', 'Example', 'Values', 'Related', 'References', 'Status')
$script:FieldLimits = @{ 'Label' = 60; 'Summary' = 200; 'Used when' = 200; 'When to change' = 400;
    'Encoder default' = 40; 'Example' = 300 }
$script:NoteLimit = 120
$script:SharedIds = @('staxrip', 'concepts', 'shared')
$script:IdPattern = '^[a-z0-9-]+(\.[a-z0-9-]+)+$'
$script:EncoderPattern = '^[a-z0-9-]+$'
$script:LinkPattern = '\[([^\[\]]+)\]\((https?://[^\s()]+)\)'

function New-OhError {
    param([int]$Line, [string]$Level, [string]$Code, [string]$Message)
    [pscustomobject]@{ Line = $Line; Level = $Level; Code = $Code; Message = $Message }
}

function New-OhStanza {
    param([string]$Id, [int]$Line)
    [pscustomobject]@{
        Id = $Id; Line = $Line; Fields = [ordered]@{}; Values = [System.Collections.Generic.List[object]]::new()
        References = [System.Collections.Generic.List[string]]::new(); Status = ''
    }
}

function Read-OptionHelpFile {
    param([Parameter(Mandatory)][string]$Path)
    $name = [System.IO.Path]::GetFileName($Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $errors = [System.Collections.Generic.List[object]]::new()
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $errors.Add((New-OhError 1 'FILE' 'E1' 'UTF-8 byte order mark is not allowed'))
        $bytes = $bytes[3..($bytes.Length - 1)]
    }
    $text = ''
    try {
        $text = [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes)
    }
    catch {
        $errors.Add((New-OhError 1 'FILE' 'E1' 'File is not valid UTF-8'))
        $text = [System.Text.UTF8Encoding]::new($false, $false).GetString($bytes)
    }
    $file = ConvertFrom-OptionHelpText -Text $text -Name $name
    foreach ($e in $errors) { $file.Errors.Add($e) }
    return $file
}

function ConvertFrom-OptionHelpText {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text, [Parameter(Mandatory)][string]$Name)

    $errors = [System.Collections.Generic.List[object]]::new()
    $header = [ordered]@{}
    $stanzas = [System.Collections.Generic.List[object]]::new()

    $base = $Name -replace '\.md$', ''
    $nameParts = $base.Split('.', 2)
    $nameEncoder = $nameParts[0]
    $nameLocale = if ($nameParts.Length -gt 1) { $nameParts[1] } else { 'en' }

    $lines = $Text.Replace("`r`n", "`n").Split("`n")
    $stanza = $null
    $currentField = $null
    $seenContent = $false
    $lastFieldIndex = -1

    for ($i = 0; $i -lt $lines.Length; $i++) {
        $lineNo = $i + 1
        $line = $lines[$i]
        $trimmed = $line.Trim()

        if ($trimmed -match '^<!--.*-->$') { continue }
        if (-not $seenContent -and $trimmed -match '^# ') { $seenContent = $true; continue }
        if ($trimmed -eq '') { $currentField = $null; continue }
        $seenContent = $true

        if ($line -match '^## (.*)$') {
            $id = $Matches[1].Trim()
            $stanza = New-OhStanza -Id $id -Line $lineNo
            $stanzas.Add($stanza)
            $currentField = $null
            $lastFieldIndex = -1
            if ($id -notmatch $script:IdPattern) {
                $errors.Add((New-OhError $lineNo 'STANZA' 'E1' "Invalid stanza id '$id'"))
            }
            continue
        }

        if ($null -eq $stanza) {
            if ($line -match '^([A-Z][A-Za-z-]*): ?(.*)$') {
                $key = $Matches[1]; $value = $Matches[2].Trim()
                if ($script:HeaderKeys -notcontains $key) {
                    $errors.Add((New-OhError $lineNo 'FILE' 'E1' "Unknown header key '$key'"))
                }
                elseif ($header.Contains($key)) {
                    $errors.Add((New-OhError $lineNo 'FILE' 'E1' "Duplicate header key '$key'"))
                }
                else { $header[$key] = $value }
            }
            else {
                $errors.Add((New-OhError $lineNo 'FILE' 'E1' 'Text before the first stanza is not a header line'))
            }
            continue
        }

        if ($line -match '^([A-Z][A-Za-z]*(?: [a-z]+)*): ?(.*)$') {
            $field = $Matches[1]; $value = $Matches[2].Trim()
            $index = [array]::IndexOf($script:FieldOrder, $field)
            if ($index -lt 0) {
                $errors.Add((New-OhError $lineNo 'STANZA' 'E3' "Unknown field '$field'"))
                $currentField = $null
                continue
            }
            if ($stanza.Fields.Contains($field)) {
                $errors.Add((New-OhError $lineNo 'STANZA' 'E3' "Duplicate field '$field'"))
                $currentField = $null
                continue
            }
            if ($index -lt $lastFieldIndex) {
                $errors.Add((New-OhError $lineNo 'STANZA' 'E3' "Field '$field' is out of order"))
            }
            $lastFieldIndex = $index
            if (($field -eq 'Values' -or $field -eq 'References') -and $value -ne '') {
                $errors.Add((New-OhError $lineNo 'STANZA' 'E3' "Field '$field' must have no text on its line"))
                $value = ''
            }
            $stanza.Fields[$field] = $value
            if ($field -eq 'Status') { $stanza.Status = $value }
            $currentField = $field
            continue
        }

        if ($line -match '^- (.*)$') {
            $item = $Matches[1].Trim()
            if ($currentField -eq 'Values') {
                $sep = $item.IndexOf(': ')
                if ($sep -lt 1) {
                    $errors.Add((New-OhError $lineNo 'STANZA' 'E3' 'Value bullet needs "<value>: <note>"'))
                }
                else {
                    $stanza.Values.Add([pscustomobject]@{ Value = $item.Substring(0, $sep); Note = $item.Substring($sep + 2).Trim(); Line = $lineNo })
                }
            }
            elseif ($currentField -eq 'References') {
                $stanza.References.Add($item)
                if ($item -notmatch '^https?://\S+$') {
                    $errors.Add((New-OhError $lineNo 'STANZA' 'E13' "Reference must be an http or https URL: '$item'"))
                }
            }
            else {
                $errors.Add((New-OhError $lineNo 'STANZA' 'E3' 'Bullet outside Values or References'))
            }
            continue
        }

        if ($null -ne $currentField -and $currentField -ne 'Values' -and $currentField -ne 'References') {
            $stanza.Fields[$currentField] = ($stanza.Fields[$currentField] + ' ' + $trimmed).Trim()
        }
        else {
            $errors.Add((New-OhError $lineNo 'STANZA' 'E3' 'Text outside a field'))
        }
    }

    $file = [pscustomobject]@{
        Name = $Name; Encoder = $nameEncoder; Locale = $nameLocale
        Header = $header; Stanzas = $stanzas; Errors = $errors
    }
    Complete-OhValidation -File $file
    return $file
}

function ConvertTo-OptionHelpDump {
    param([Parameter(Mandatory)]$File)
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append("FILE $($File.Name)`n")
    foreach ($key in $File.Header.Keys) { [void]$sb.Append("H $key=$($File.Header[$key])`n") }
    foreach ($s in $File.Stanzas) {
        [void]$sb.Append("S $($s.Id) $($s.Line)`n")
        foreach ($f in $s.Fields.Keys) {
            [void]$sb.Append("F $f=$($s.Fields[$f])`n")
            if ($f -eq 'Values') { foreach ($v in $s.Values) { [void]$sb.Append("V $($v.Value)=$($v.Note)`n") } }
            if ($f -eq 'References') { foreach ($r in $s.References) { [void]$sb.Append("R $r`n") } }
        }
    }
    $sorted = $File.Errors | Sort-Object -Property @{ Expression = 'Line' }, @{ Expression = 'Code' }
    foreach ($e in $sorted) { [void]$sb.Append("ERR $($e.Line) $($e.Level) $($e.Code)`n") }
    [void]$sb.Append("END`n")
    return $sb.ToString()
}

function Invoke-OptionHelpSelfTest {
    param([Parameter(Mandatory)][string]$FixturesRoot)
    $failures = 0
    $count = 0
    foreach ($md in Get-ChildItem (Join-Path $FixturesRoot 'md') -Filter '*.md' | Sort-Object Name) {
        $count++
        $expectedPath = Join-Path $FixturesRoot ('expected\' + ($md.Name -replace '\.md$', '.txt'))
        $expected = [System.IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n")
        $actual = ConvertTo-OptionHelpDump -File (Read-OptionHelpFile -Path $md.FullName)
        if ($expected -ne $actual) {
            $failures++
            $el = $expected.Split("`n"); $al = $actual.Split("`n")
            for ($i = 0; $i -lt [Math]::Max($el.Length, $al.Length); $i++) {
                $e = if ($i -lt $el.Length) { $el[$i] } else { '<missing>' }
                $a = if ($i -lt $al.Length) { $al[$i] } else { '<missing>' }
                if ($e -ne $a) {
                    [Console]::Error.WriteLine("FAIL $($md.Name) line $($i + 1)`n  expected: $e`n  actual:   $a")
                    break
                }
            }
        }
    }
    # Tasks 3 and 4 append the chain, repo, ratchet, and facts self-tests here.
    [Console]::Error.WriteLine("self-test: $count dump cases, $failures failures")
    if ($failures -gt 0) { return 1 }
    return 0
}

function Test-OhInline {
    param([AllowEmptyString()][string]$Text)
    $ticks = @($Text.ToCharArray() | Where-Object { $_ -eq '`' }).Count
    if ($ticks % 2 -eq 1) { return 'Unmatched backtick' }
    $stripped = [regex]::Replace($Text, $script:LinkPattern, '')
    if ($stripped.Contains('[') -or $stripped.Contains(']')) { return 'Malformed link; only [text](http://...) or [text](https://...) is allowed' }
    return $null
}

function ConvertTo-OhPlainText {
    param([AllowEmptyString()][string]$Text)
    $t = [regex]::Replace($Text, $script:LinkPattern, '$1')
    return $t.Replace('`', '')
}

function Complete-OhValidation {
    param([Parameter(Mandatory)]$File)
    $h = $File.Header
    $errors = $File.Errors
    $isShared = $script:SharedIds -contains $File.Encoder

    if (-not $h.Contains('Schema') -or $h['Schema'] -ne '1') { $errors.Add((New-OhError 1 'FILE' 'E1' 'Schema must be 1')) }
    if (-not $h.Contains('Encoder')) { $errors.Add((New-OhError 1 'FILE' 'E1' 'Encoder header is required')) }
    elseif ($h['Encoder'] -notmatch $script:EncoderPattern -or $h['Encoder'] -ne $File.Encoder) {
        $errors.Add((New-OhError 1 'FILE' 'E1' "Encoder '$($h['Encoder'])' must match the file name '$($File.Encoder)'"))
    }
    if (-not $h.Contains('Locale')) { $errors.Add((New-OhError 1 'FILE' 'E1' 'Locale header is required')) }
    elseif ($h['Locale'] -ne $File.Locale) { $errors.Add((New-OhError 1 'FILE' 'E1' "Locale '$($h['Locale'])' must match the file name locale '$($File.Locale)'")) }
    if (-not $h.Contains('Title')) { $errors.Add((New-OhError 1 'FILE' 'E1' 'Title header is required')) }

    $anyReviewed = @($File.Stanzas | Where-Object { $_.Status -eq 'reviewed' }).Count -gt 0
    if (-not $isShared) {
        foreach ($key in @('Source', 'Allowed-Missing', 'Minimum-Reviewed', 'Reviewed-Complete')) {
            if (-not $h.Contains($key)) { $errors.Add((New-OhError 1 'FILE' 'E1' "$key header is required for an encoder file")) }
        }
        foreach ($key in @('Allowed-Missing', 'Minimum-Reviewed')) {
            if ($h.Contains($key) -and $h[$key] -notmatch '^\d+$') { $errors.Add((New-OhError 1 'FILE' 'E1' "$key must be a non-negative integer")) }
        }
        if ($h.Contains('Reviewed-Complete') -and $h['Reviewed-Complete'] -notin @('true', 'false')) {
            $errors.Add((New-OhError 1 'FILE' 'E1' 'Reviewed-Complete must be true or false'))
        }
        if ($anyReviewed) {
            $missing = @(@('Verified-Encoder-Version', 'Verified-Encoder-Build', 'Verified-Date', 'Documentation') | Where-Object { -not $h.Contains($_) })
            if ($missing.Count -gt 0) { $errors.Add((New-OhError 1 'FILE' 'E1' "Reviewed stanzas require headers: $($missing -join ', ')")) }
        }
        if ($h.Contains('Verified-Date') -and $h['Verified-Date'] -notmatch '^\d{4}-\d{2}-\d{2}$') { $errors.Add((New-OhError 1 'FILE' 'E1' 'Verified-Date must be an ISO date')) }
        if ($h.Contains('Documentation') -and $h['Documentation'] -notmatch '^https?://\S+$') { $errors.Add((New-OhError 1 'FILE' 'E1' 'Documentation must be an http or https URL')) }
        if ($h.Contains('Inherits') -and ($h['Inherits'] -notmatch $script:EncoderPattern -or $script:SharedIds -contains $h['Inherits'])) {
            $errors.Add((New-OhError 1 'FILE' 'E1' 'Inherits must name an encoder file'))
        }
        elseif ($h.Contains('Inherits')) {
            # Chains are resolved by Task 3; the parser only records that a base is named.
            $File | Add-Member -NotePropertyName 'Inherits' -NotePropertyValue $h['Inherits'] -Force
        }
    }
    elseif ($h.Contains('Inherits')) { $errors.Add((New-OhError 1 'FILE' 'E1' 'Shared files cannot inherit')) }

    $seen = @{}
    foreach ($s in $File.Stanzas) {
        if ($seen.ContainsKey($s.Id)) { $errors.Add((New-OhError $s.Line 'FILE' 'E8' "Duplicate stanza id '$($s.Id)'")) } else { $seen[$s.Id] = $true }
        $f = $s.Fields
        $hasUse = $f.Contains('Use')
        if ($hasUse) {
            foreach ($k in $f.Keys) { if ($k -notin @('Label', 'Use', 'Status')) { $errors.Add((New-OhError $s.Line 'STANZA' 'E3' "Field '$k' is not allowed with Use")) } }
        }
        if (-not $f.Contains('Status')) { $errors.Add((New-OhError $s.Line 'STANZA' 'E3' 'Status is required')) }
        elseif ($s.Status -notin @('draft', 'reviewed')) { $errors.Add((New-OhError $s.Line 'STANZA' 'E3' "Status must be draft or reviewed, not '$($s.Status)'")) }
        if (-not $hasUse) {
            if (-not $f.Contains('Summary') -or $f['Summary'] -eq '') { $errors.Add((New-OhError $s.Line 'STANZA' 'E2' 'Summary is required')) }
            elseif (-not $f['Summary'].EndsWith('.')) { $errors.Add((New-OhError $s.Line 'STANZA' 'E2' 'Summary must end with a period')) }
            if ($s.Status -eq 'reviewed' -and -not $f.Contains('When to change')) { $errors.Add((New-OhError $s.Line 'STANZA' 'E2' 'When to change is required on a reviewed stanza')) }
        }
        foreach ($k in $f.Keys) {
            if ($script:FieldLimits.ContainsKey($k) -and $f[$k].Length -gt $script:FieldLimits[$k]) {
                $errors.Add((New-OhError $s.Line 'STANZA' 'E2' "$k exceeds $($script:FieldLimits[$k]) characters"))
            }
            if ($k -in @('Summary', 'Used when', 'When to change', 'Example', 'Encoder default', 'Label')) {
                $m = Test-OhInline -Text $f[$k]
                if ($m) { $errors.Add((New-OhError ($s.Line + [array]::IndexOf(@($f.Keys), $k) + 1) 'STANZA' 'E13' "$k`: $m")) }
            }
        }
        foreach ($v in $s.Values) {
            if ($v.Note.Length -gt $script:NoteLimit) { $errors.Add((New-OhError $v.Line 'STANZA' 'E2' "Value note exceeds $($script:NoteLimit) characters")) }
            $m = Test-OhInline -Text $v.Note
            if ($m) { $errors.Add((New-OhError $v.Line 'STANZA' 'E13' "Value note: $m")) }
        }
    }
}

Export-ModuleMember -Function Read-OptionHelpFile, ConvertFrom-OptionHelpText, ConvertTo-OptionHelpDump, Invoke-OptionHelpSelfTest, Test-OhInline, ConvertTo-OhPlainText
