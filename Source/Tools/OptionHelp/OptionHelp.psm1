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
        Id = $Id; Line = $Line; Fields = [ordered]@{}; FieldLines = [ordered]@{}; Values = [System.Collections.Generic.List[object]]::new()
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
            $stanza.FieldLines[$field] = $lineNo
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

$script:ParamTypes = @('OptionParam', 'NumParam', 'BoolParam', 'StringParam')

function Read-OhVbStrings {
    # Parses a VB brace array like {"a", "b ""c"""} starting at $Text[$Start] which must be '{'.
    # Returns @{ Items = string[]; End = index of the closing brace }.
    param([string]$Text, [int]$Start)
    $items = [System.Collections.Generic.List[string]]::new()
    $i = $Start + 1
    while ($i -lt $Text.Length) {
        $c = $Text[$i]
        if ($c -eq '}') { return @{ Items = $items.ToArray(); End = $i } }
        if ($c -eq '"') {
            $sb = [System.Text.StringBuilder]::new()
            $i++
            while ($i -lt $Text.Length) {
                if ($Text[$i] -eq '"') {
                    if ($i + 1 -lt $Text.Length -and $Text[$i + 1] -eq '"') { [void]$sb.Append('"'); $i += 2; continue }
                    break
                }
                [void]$sb.Append($Text[$i]); $i++
            }
            $items.Add($sb.ToString())
        }
        $i++
    }
    return @{ Items = $items.ToArray(); End = $Text.Length - 1 }
}

function Read-OhVbString {
    # Returns the string literal value of `.Name = "..."` inside an initializer, or $null.
    param([string]$Init, [string]$Member)
    $m = [regex]::Match($Init, '\.' + [regex]::Escape($Member) + '\s*=\s*"((?:[^"]|"")*)"')
    if ($m.Success) { return $m.Groups[1].Value.Replace('""', '"') }
    return $null
}

function Read-OhVbArray {
    # Under Set-StrictMode, a bare array return unrolls: a one-element array becomes a scalar
    # and an empty array becomes $null. The comma operator keeps the array intact both ways so
    # that callers can safely use .Length and [0] on the result.
    param([string]$Init, [string]$Member)
    $m = [regex]::Match($Init, '\.' + [regex]::Escape($Member) + '\s*=\s*\{')
    if (-not $m.Success) { return ,@() }
    $items = (Read-OhVbStrings -Text $Init -Start ($m.Index + $m.Length - 1)).Items
    return ,$items
}

function Get-VbOptionHelpId {
    param([Parameter(Mandatory)][string]$Path)
    $text = [System.IO.File]::ReadAllText($Path)
    $m = [regex]::Match($text, 'OptionHelpId\s+As\s+String[\s\S]*?Return\s+"([a-z0-9-]+)"')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

function Get-VbParameters {
    param([Parameter(Mandatory)][string]$Path, [AllowEmptyString()][string]$EncoderId)
    $raw = [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $lines = $raw.Split("`n")
    # Blank out full-line comments but keep line positions.
    for ($i = 0; $i -lt $lines.Length; $i++) { if ($lines[$i] -match "^\s*'") { $lines[$i] = '' } }
    $text = $lines -join "`n"
    $result = [System.Collections.Generic.List[object]]::new()
    $errors = [System.Collections.Generic.List[object]]::new()

    foreach ($m in [regex]::Matches($text, 'New\s+([A-Za-z_]\w*Param)\b')) {
        $type = $m.Groups[1].Value
        $lineNo = ($text.Substring(0, $m.Index) -split "`n").Length
        if ($type -eq 'LineParam' -or $type -eq 'CommandLineParam') { continue }
        if ($script:ParamTypes -notcontains $type) {
            $errors.Add((New-OhError $lineNo 'FILE' 'E11' "Unrecognized parameter type '$type'"))
            continue
        }
        $after = $text.Substring($m.Index + $m.Length)
        $w = [regex]::Match($after, '^\s*(\(\))?\s*With\s*\{')
        if (-not $w.Success) {
            $errors.Add((New-OhError $lineNo 'FILE' 'E11' "Parameter of type '$type' is not declared with 'With {'"))
            continue
        }
        $braceStart = $m.Index + $m.Length + $w.Length - 1
        $depth = 0; $j = $braceStart; $inString = $false
        while ($j -lt $text.Length) {
            $c = $text[$j]
            if ($inString) { if ($c -eq '"') { if ($j + 1 -lt $text.Length -and $text[$j + 1] -eq '"') { $j++ } else { $inString = $false } } }
            elseif ($c -eq '"') { $inString = $true }
            elseif ($c -eq '{') { $depth++ }
            elseif ($c -eq '}') { $depth--; if ($depth -eq 0) { break } }
            $j++
        }
        $init = $text.Substring($braceStart, $j - $braceStart + 1)
        $lineStart = $text.LastIndexOf("`n", $m.Index) + 1
        $prefix = $text.Substring($lineStart, $m.Index - $lineStart)
        $nameMatch = [regex]::Match($prefix, 'Property\s+(\w+)\s+As\s*$')
        $name = if ($nameMatch.Success) { $nameMatch.Groups[1].Value } else { '-' }

        $key = Read-OhVbString $init 'OptionHelpKey'
        $helpSwitch = Read-OhVbString $init 'HelpSwitch'
        $switch = Read-OhVbString $init 'Switch'
        $noSwitch = Read-OhVbString $init 'NoSwitch'
        $switches = Read-OhVbArray $init 'Switches'
        $caption = Read-OhVbString $init 'Text'
        $values = Read-OhVbArray $init 'Values'
        $options = Read-OhVbArray $init 'Options'
        $integerValue = $init -match '\.IntegerValue\s*=\s*True'

        $all = [System.Collections.Generic.List[string]]::new()
        foreach ($s in @($switch, $noSwitch, $helpSwitch)) { if ($s -and $all -notcontains $s) { $all.Add($s) } }
        if ($switches) { foreach ($s in $switches) { if ($s -and $all -notcontains $s) { $all.Add($s) } } }

        $primary = if ($helpSwitch) { $helpSwitch } elseif ($switch) { $switch } elseif ($noSwitch) { $noSwitch } elseif ($switches -and $switches.Length -gt 0) { $switches[0] } else { $null }
        $excluded = $false; $identity = $null
        if ($key -eq 'none') { $excluded = $true }
        elseif ($key) { $identity = $key }
        elseif ($primary -and $EncoderId) { $identity = $EncoderId + '.' + ($primary -replace '^-+', '') }
        if (-not $excluded) {
            if (-not $identity) { $errors.Add((New-OhError $lineNo 'FILE' 'E10' "Parameter '$name' ($caption) has no identity; set OptionHelpKey")) }
            elseif ($identity -notmatch $script:IdPattern) { $errors.Add((New-OhError $lineNo 'FILE' 'E10' "Identity '$identity' is not a valid id")) }
        }

        $emitted = @()
        if ($type -eq 'OptionParam') {
            if ($values) { $emitted = $values }
            elseif ($integerValue -and $options) { $emitted = @(0..($options.Length - 1) | ForEach-Object { "$_" }) }
            elseif ($options) { $emitted = @($options | ForEach-Object { $_.ToLowerInvariant().Replace(' ', '') }) }
        }

        $result.Add([pscustomobject]@{
            Name = $name; Type = $type; Line = $lineNo; Identity = $identity; Excluded = $excluded
            Switches = $all.ToArray(); Caption = $caption; EmittedValues = $emitted; Errors = $errors
        })
    }
    return [pscustomobject]@{ Parameters = $result; Errors = $errors; OptionHelpId = (Get-VbOptionHelpId -Path $Path) }
}

function ConvertTo-OhVbDump {
    param([Parameter(Mandatory)]$Extraction)
    $sb = [System.Text.StringBuilder]::new()
    $id = if ($Extraction.OptionHelpId) { $Extraction.OptionHelpId } else { '-' }
    [void]$sb.Append("OPTIONHELPID $id`n")
    foreach ($p in $Extraction.Parameters) {
        $pid = if ($p.Identity) { $p.Identity } else { '-' }
        [void]$sb.Append("P $($p.Line) $($p.Name) $($p.Type) id=$pid excluded=$($p.Excluded.ToString().ToLower()) caption=$($p.Caption) switches=$($p.Switches -join ',') values=$($p.EmittedValues -join ',')`n")
    }
    foreach ($e in ($Extraction.Errors | Sort-Object Line, Code)) { [void]$sb.Append("ERR $($e.Line) $($e.Code)`n") }
    return $sb.ToString()
}

function Read-OhDirectory {
    # Returns a hashtable: encoder id -> parsed file, for English files in a directory.
    param([Parameter(Mandatory)][string]$Directory)
    $files = @{}
    foreach ($f in Get-ChildItem $Directory -Filter '*.md' | Sort-Object Name) {
        if ($f.Name -eq 'README.md') { continue }
        $parsed = Read-OptionHelpFile -Path $f.FullName
        if ($parsed.Locale -ne 'en') { continue }
        $files[$parsed.Encoder] = $parsed
    }
    return $files
}

function Get-OhChain {
    param([Parameter(Mandatory)][hashtable]$Files, [Parameter(Mandatory)][string]$EncoderId)
    $chain = [System.Collections.Generic.List[object]]::new()
    $seen = @{}
    $current = $EncoderId
    while ($current) {
        if ($seen.ContainsKey($current)) { throw "Inheritance cycle at '$current'" }
        if (-not $Files.ContainsKey($current)) { throw "Unknown encoder file '$current'" }
        $seen[$current] = $true
        $file = $Files[$current]
        $chain.Add($file)
        $current = if ($file.Header.Contains('Inherits')) { $file.Header['Inherits'] } else { $null }
    }
    if ($EncoderId -ne 'staxrip' -and $Files.ContainsKey('staxrip')) { $chain.Add($Files['staxrip']) }
    return ,$chain
}

function Find-OhStanza {
    param([Parameter(Mandatory)]$File, [Parameter(Mandatory)][string]$Id)
    foreach ($s in $File.Stanzas) { if ($s.Id -eq $Id) { return $s } }
    return $null
}

function Resolve-OhId {
    param([Parameter(Mandatory)]$Chain, [Parameter(Mandatory)][hashtable]$Files, [Parameter(Mandatory)][string]$Id)
    foreach ($file in $Chain) {
        $s = Find-OhStanza -File $file -Id $Id
        if ($null -eq $s) { continue }
        if ($s.Status -ne 'reviewed') { return @{ Outcome = 'draft'; File = $file.Name; Stanza = $s } }
        if ($s.Fields.Contains('Use')) {
            $targetId = $s.Fields['Use']
            $targetFileId = $targetId.Split('.')[0]
            if (-not $Files.ContainsKey($targetFileId)) { return @{ Outcome = 'draft'; File = $file.Name; Stanza = $s } }
            $t = Find-OhStanza -File $Files[$targetFileId] -Id $targetId
            if ($null -eq $t -or $t.Status -ne 'reviewed' -or $t.Fields.Contains('Use')) { return @{ Outcome = 'draft'; File = $file.Name; Stanza = $s } }
            return @{ Outcome = 'alias'; File = $Files[$targetFileId].Name; Stanza = $t; Alias = $s }
        }
        return @{ Outcome = 'reviewed'; File = $file.Name; Stanza = $s }
    }
    return @{ Outcome = 'none'; File = $null; Stanza = $null }
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
    foreach ($vb in Get-ChildItem (Join-Path $FixturesRoot 'vb') -Filter '*.vb' | Sort-Object Name) {
        $count++
        $expectedPath = Join-Path $FixturesRoot ('expected\vb-' + ($vb.Name -replace '\.vb$', '.txt'))
        $expected = [System.IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n")
        $extraction = Get-VbParameters -Path $vb.FullName -EncoderId 'fake'
        $actual = ConvertTo-OhVbDump -Extraction $extraction
        if ($expected -ne $actual) {
            $failures++
            [Console]::Error.WriteLine("FAIL vb-$($vb.Name)`n--- expected`n$expected`n--- actual`n$actual")
        }
    }

    $chainDir = Join-Path $FixturesRoot 'chain'
    $files = Read-OhDirectory -Directory $chainDir
    foreach ($case in [System.IO.File]::ReadAllLines((Join-Path $chainDir 'cases.txt'))) {
        if ($case.Trim() -eq '') { continue }
        $count++
        $parts = $case -split ' => '
        $lhs = $parts[0].Split(' ')
        $chain = Get-OhChain -Files $files -EncoderId $lhs[0]
        $r = Resolve-OhId -Chain $chain -Files $files -Id $lhs[1]
        $actual = if ($r.Outcome -eq 'none') { 'none' } else { "$($r.Outcome):$($r.File)" }
        if ($actual -ne $parts[1]) { $failures++; [Console]::Error.WriteLine("FAIL chain '$case' actual '$actual'") }
    }

    foreach ($repo in @('repo', 'repo-clean')) {
        $count++
        $expected = [System.IO.File]::ReadAllText((Join-Path $FixturesRoot "expected\report-$repo.txt")).Replace("`r`n", "`n")
        $actual = Format-OptionHelpReport -Report (Test-OptionHelpRepository -RepoRoot (Join-Path $FixturesRoot $repo))
        if ($expected -ne $actual) { $failures++; [Console]::Error.WriteLine("FAIL report-$repo`n--- expected`n$expected`n--- actual`n$actual") }
    }
    # A -Encoder typo that names no English file must fail loudly, not print an empty RESULT PASS.
    $count++
    $expected = [System.IO.File]::ReadAllText((Join-Path $FixturesRoot 'expected\report-repo-bogus.txt')).Replace("`r`n", "`n")
    $actual = Format-OptionHelpReport -Report (Test-OptionHelpRepository -RepoRoot (Join-Path $FixturesRoot 'repo') -Encoder 'bogus')
    if ($expected -ne $actual) { $failures++; [Console]::Error.WriteLine("FAIL report-repo-bogus`n--- expected`n$expected`n--- actual`n$actual") }
    # Ratchet: copy repo-clean to a temp dir, advance, compare the two counter lines.
    $count++
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("optionhelp-ratchet-" + [guid]::NewGuid().ToString('N'))
    Copy-Item (Join-Path $FixturesRoot 'repo-clean') $tmp -Recurse
    try {
        $rep = Test-OptionHelpRepository -RepoRoot $tmp
        Update-OptionHelpRatchet -RepoRoot $tmp -Report $rep
        $after = [System.IO.File]::ReadAllText((Join-Path $tmp 'Docs\OptionHelp\clean.md')).Replace("`r`n", "`n")
        $lines = @(($after -split "`n") | Where-Object { $_ -match '^(Allowed-Missing|Minimum-Reviewed): ' })
        $expected = [System.IO.File]::ReadAllText((Join-Path $FixturesRoot 'expected\ratchet-repo-clean.txt')).Replace("`r`n", "`n").TrimEnd("`n")
        if (($lines -join "`n") -ne $expected) { $failures++; [Console]::Error.WriteLine("FAIL ratchet`n--- expected`n$expected`n--- actual`n$($lines -join "`n")") }
    }
    finally { Remove-Item $tmp -Recurse -Force }
    # Ratchet CRLF safety: same fixture, but clean.md is converted to CRLF before advancing. The
    # counters must land on the same values as the LF case, and the CR count must be unchanged,
    # proving the regex rewrote only the digits and never touched the line endings.
    $count++
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("optionhelp-ratchet-crlf-" + [guid]::NewGuid().ToString('N'))
    Copy-Item (Join-Path $FixturesRoot 'repo-clean') $tmp -Recurse
    try {
        $cleanPath = Join-Path $tmp 'Docs\OptionHelp\clean.md'
        $lf = [System.IO.File]::ReadAllText($cleanPath).Replace("`r`n", "`n")
        $crlf = $lf.Replace("`n", "`r`n")
        [System.IO.File]::WriteAllText($cleanPath, $crlf, [System.Text.UTF8Encoding]::new($false))
        $crBefore = @([System.IO.File]::ReadAllBytes($cleanPath) | Where-Object { $_ -eq 0x0D }).Count
        $rep = Test-OptionHelpRepository -RepoRoot $tmp
        Update-OptionHelpRatchet -RepoRoot $tmp -Report $rep
        $afterBytes = [System.IO.File]::ReadAllBytes($cleanPath)
        $crAfter = @($afterBytes | Where-Object { $_ -eq 0x0D }).Count
        $after = [System.Text.UTF8Encoding]::new($false).GetString($afterBytes).Replace("`r`n", "`n")
        $lines = @(($after -split "`n") | Where-Object { $_ -match '^(Allowed-Missing|Minimum-Reviewed): ' })
        $expected = [System.IO.File]::ReadAllText((Join-Path $FixturesRoot 'expected\ratchet-repo-clean.txt')).Replace("`r`n", "`n").TrimEnd("`n")
        if (($lines -join "`n") -ne $expected) { $failures++; [Console]::Error.WriteLine("FAIL ratchet-crlf counters`n--- expected`n$expected`n--- actual`n$($lines -join "`n")") }
        if ($crAfter -ne $crBefore) { $failures++; [Console]::Error.WriteLine("FAIL ratchet-crlf CR count changed: before=$crBefore after=$crAfter") }
    }
    finally { Remove-Item $tmp -Recurse -Force }
    # Facts comparison against the fake repository.
    $count++
    $diff = Compare-OptionHelpFacts -RepoRoot (Join-Path $FixturesRoot 'repo') -FactsPath (Join-Path $FixturesRoot 'facts\fake-export.json')
    $expected = [System.IO.File]::ReadAllText((Join-Path $FixturesRoot 'expected\compare-facts.txt')).Replace("`r`n", "`n").TrimEnd("`n")
    if (($diff -join "`n") -ne $expected) { $failures++; [Console]::Error.WriteLine("FAIL compare-facts`n--- expected`n$expected`n--- actual`n$($diff -join "`n")") }
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
                if ($m) { $errors.Add((New-OhError $s.FieldLines[$k] 'STANZA' 'E13' "$k`: $m")) }
            }
        }
        foreach ($v in $s.Values) {
            if ($v.Note.Length -gt $script:NoteLimit) { $errors.Add((New-OhError $v.Line 'STANZA' 'E2' "Value note exceeds $($script:NoteLimit) characters")) }
            $m = Test-OhInline -Text $v.Note
            if ($m) { $errors.Add((New-OhError $v.Line 'STANZA' 'E13' "Value note: $m")) }
        }
    }
}

function Get-OhResourceEntries {
    param([string]$ProjectPath)
    $entries = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path $ProjectPath)) { return $entries }
    $text = [System.IO.File]::ReadAllText($ProjectPath)
    foreach ($m in [regex]::Matches($text, '<EmbeddedResource\s+Include="\.\.\\Docs\\OptionHelp\\([^"]+)"')) { $entries.Add($m.Groups[1].Value) }
    return $entries
}

function Test-OhPathCase {
    # True when every segment of the relative path exists with exactly this case on disk.
    param([string]$RepoRoot, [string]$RelativePath)
    $current = $RepoRoot
    foreach ($segment in $RelativePath.Replace('\', '/').Split('/')) {
        if ($segment -eq '') { continue }
        $entry = Get-ChildItem -LiteralPath $current -Force | Where-Object { $_.Name -ceq $segment } | Select-Object -First 1
        if ($null -eq $entry) { return $false }
        $current = $entry.FullName
    }
    return $true
}

function Test-OptionHelpRepository {
    param([Parameter(Mandatory)][string]$RepoRoot, [string]$Encoder)
    $RepoRoot = (Resolve-Path $RepoRoot).Path
    $docs = Join-Path $RepoRoot 'Docs\OptionHelp'
    $files = Read-OhDirectory -Directory $docs
    $errors = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[object]]::new()
    $encoders = [System.Collections.Generic.List[object]]::new()
    $resources = Get-OhResourceEntries -ProjectPath (Join-Path $RepoRoot 'Source\StaxRip.vbproj')

    # A -Encoder that names no English file must fail loudly instead of scoping every later loop
    # down to nothing and passing with an empty report.
    if ($Encoder -and -not $files.ContainsKey($Encoder)) {
        $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$Encoder.md"; Line = 1; Code = 'E1'; Message = "No help file for encoder '$Encoder'" })
    }

    # File-level parse errors and the file-to-resource E12 check: scoped to -Encoder when given.
    foreach ($f in $files.Values) {
        if ($Encoder -and $f.Encoder -ne $Encoder) { continue }
        foreach ($e in $f.Errors) { $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = $e.Line; Code = $e.Code; Message = $e.Message }) }
        $hits = @($resources | Where-Object { $_ -ceq $f.Name }).Count
        if ($hits -eq 0) { $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = 1; Code = 'E12'; Message = 'No EmbeddedResource entry in Source/StaxRip.vbproj' }) }
        elseif ($hits -gt 1) { $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = 1; Code = 'E12'; Message = "Duplicate EmbeddedResource entries ($hits) in Source/StaxRip.vbproj" }) }
    }

    # Repository-wide checks: only when not scoped to a single -Encoder.
    if (-not $Encoder) {
        foreach ($r in $resources) {
            if (-not (Test-Path (Join-Path $docs $r))) { $errors.Add([pscustomobject]@{ File = 'Source/StaxRip.vbproj'; Line = 1; Code = 'E12'; Message = "EmbeddedResource '$r' has no file" }) }
        }

        # W1: encoder sources without a help file.
        $sourcesWithFile = @($files.Values | Where-Object { $_.Header.Contains('Source') } | ForEach-Object { $_.Header['Source'].Replace('\', '/') })
        foreach ($vb in Get-ChildItem (Join-Path $RepoRoot 'Source\Encoding') -Filter '*.vb' | Sort-Object Name) {
            $rel = "Source/Encoding/$($vb.Name)"
            if ($sourcesWithFile -notcontains $rel) {
                $text = [System.IO.File]::ReadAllText($vb.FullName)
                if ($text -match 'Inherits\s+CommandLineParams') { $warnings.Add([pscustomobject]@{ File = $rel; Line = 0; Code = 'W1'; Message = 'no help file' }) }
            }
        }
    }

    $allParams = @{}
    foreach ($f in ($files.Values | Sort-Object Encoder)) {
        if ($script:SharedIds -contains $f.Encoder) { continue }
        if ($Encoder -and $f.Encoder -ne $Encoder) { continue }
        $h = $f.Header
        $sourceRel = if ($h.Contains('Source')) { $h['Source'] } else { $null }
        if (-not $sourceRel) { continue }
        if ($sourceRel -match '\.\.' -or -not (Test-OhPathCase -RepoRoot $RepoRoot -RelativePath $sourceRel)) {
            $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = 1; Code = 'E12'; Message = "Source path '$sourceRel' is outside the repository or its case does not match" })
            continue
        }
        $extraction = Get-VbParameters -Path (Join-Path $RepoRoot $sourceRel) -EncoderId $f.Encoder
        foreach ($e in $extraction.Errors) { $errors.Add([pscustomobject]@{ File = $sourceRel; Line = $e.Line; Code = $e.Code; Message = $e.Message }) }
        if ($extraction.OptionHelpId -ne $f.Encoder) {
            $shown = if ($extraction.OptionHelpId) { $extraction.OptionHelpId } else { 'missing' }
            $errors.Add([pscustomobject]@{ File = $sourceRel; Line = 1; Code = 'E9'; Message = "OptionHelpId is '$shown', expected '$($f.Encoder)'" })
        }
        $allParams[$f.Encoder] = $extraction.Parameters
    }

    foreach ($f in ($files.Values | Sort-Object Encoder)) {
        if ($script:SharedIds -contains $f.Encoder) { continue }
        if ($Encoder -and $f.Encoder -ne $Encoder) { continue }
        if (-not $allParams.ContainsKey($f.Encoder)) { continue }
        try { $chain = Get-OhChain -Files $files -EncoderId $f.Encoder }
        catch { $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = 1; Code = 'E1'; Message = $_.Exception.Message }); continue }
        $params = $allParams[$f.Encoder]
        $reviewed = 0; $draft = 0; $missingList = [System.Collections.Generic.List[object]]::new(); $excluded = 0
        foreach ($p in $params) {
            if ($p.Excluded) { $excluded++; $warnings.Add([pscustomobject]@{ File = $f.Encoder; Line = 0; Code = 'W3'; Message = "$($p.Name) excluded" }); continue }
            if (-not $p.Identity) { continue }
            $r = Resolve-OhId -Chain $chain -Files $files -Id $p.Identity
            switch ($r.Outcome) {
                'reviewed' { $reviewed++ }
                'alias' { $reviewed++ }
                'draft' { $draft++ }
                default { $missingList.Add([pscustomobject]@{ Id = $p.Identity; Caption = $p.Caption }) }
            }
            # E4: value notes must name emitted values.
            if ($r.Stanza -and $p.Type -eq 'OptionParam') {
                foreach ($v in $r.Stanza.Values) {
                    if ($p.EmittedValues -notcontains $v.Value) { $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($r.File)"; Line = $v.Line; Code = 'E4'; Message = "Value '$($v.Value)' is not an emitted value of $($p.Identity)" }) }
                }
            }
            elseif ($r.Stanza -and $r.Stanza.Values.Count -gt 0) {
                $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($r.File)"; Line = $r.Stanza.Line; Code = 'E4'; Message = "Values on non-option parameter $($p.Identity)" })
            }
        }
        $total = @($params | Where-Object { -not $_.Excluded }).Count
        $identities = @($params | Where-Object { $_.Identity } | ForEach-Object { $_.Identity })
        # E5 orphans and E6 links for stanzas in this encoder's own file.
        $inheritors = @($files.Values | Where-Object { $_.Header.Contains('Inherits') -and $_.Header['Inherits'] -eq $f.Encoder } | ForEach-Object { $_.Encoder })
        $allIds = [System.Collections.Generic.List[string]]::new([string[]]$identities)
        foreach ($i in $inheritors) { if ($allParams.ContainsKey($i)) { foreach ($p in $allParams[$i]) { if ($p.Identity) { $allIds.Add($p.Identity) } } } }
        foreach ($s in $f.Stanzas) {
            if ($allIds -notcontains $s.Id) { $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = $s.Line; Code = 'E5'; Message = "Orphan stanza '$($s.Id)'" }) }
            if ($s.Fields.Contains('Related')) {
                foreach ($rel in ($s.Fields['Related'] -split ',\s*')) {
                    $target = $null
                    foreach ($other in $files.Values) { $t = Find-OhStanza -File $other -Id $rel; if ($t) { $target = $t; break } }
                    if (-not $target) { $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = $s.FieldLines['Related']; Code = 'E6'; Message = "Related target '$rel' does not exist" }) }
                }
            }
            if ($s.Fields.Contains('Use')) {
                $r2 = Resolve-OhId -Chain @($f) -Files $files -Id $s.Id
                if ($r2.Outcome -ne 'alias') { $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = $s.FieldLines['Use']; Code = 'E6'; Message = "Use target '$($s.Fields['Use'])' does not exist or is not reviewed" }) }
            }
        }
        $allowed = [int]$f.Header['Allowed-Missing']; $minimum = [int]$f.Header['Minimum-Reviewed']; $complete = $f.Header['Reviewed-Complete'] -eq 'true'
        $pass = $true
        if ($missingList.Count -gt $allowed) { $pass = $false; $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = 1; Code = 'E7'; Message = "missing $($missingList.Count) exceeds Allowed-Missing $allowed" }) }
        if ($reviewed -lt $minimum) { $pass = $false; $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = 1; Code = 'E7'; Message = "reviewed $reviewed is below Minimum-Reviewed $minimum" }) }
        if ($complete -and ($missingList.Count -gt 0 -or $draft -gt 0)) { $pass = $false; $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = 1; Code = 'E7'; Message = 'Reviewed-Complete is true but not every parameter is reviewed' }) }
        $encoders.Add([pscustomobject]@{
            Encoder = $f.Encoder; Total = $total; Excluded = $excluded; Reviewed = $reviewed; Draft = $draft; Missing = $missingList.Count
            AllowedMissing = $allowed; MinimumReviewed = $minimum; ReviewedComplete = $complete; Pass = $pass; MissingIds = $missingList
        })
    }
    $overall = ($errors.Count -eq 0)
    return [pscustomobject]@{ Encoders = $encoders; Errors = $errors; Warnings = $warnings; Pass = $overall }
}

function Format-OptionHelpReport {
    param([Parameter(Mandatory)]$Report)
    $sb = [System.Text.StringBuilder]::new()
    foreach ($e in ($Report.Encoders | Sort-Object Encoder)) {
        $res = if ($e.Pass) { 'PASS' } else { 'FAIL' }
        [void]$sb.Append("ENCODER $($e.Encoder) total=$($e.Total) excluded=$($e.Excluded) reviewed=$($e.Reviewed) draft=$($e.Draft) missing=$($e.Missing) allowed-missing=$($e.AllowedMissing) minimum-reviewed=$($e.MinimumReviewed) reviewed-complete=$($e.ReviewedComplete.ToString().ToLower()) result=$res`n")
        $printed = @{}
        foreach ($m in $e.MissingIds) {
            if ($printed.ContainsKey($m.Id)) { continue }
            $printed[$m.Id] = $true
            [void]$sb.Append("MISSING $($m.Id) $($m.Caption)`n")
        }
    }
    foreach ($e in ($Report.Errors | Sort-Object Code, File, Line, Message)) { [void]$sb.Append("$($e.Code) $($e.File):$($e.Line) $($e.Message)`n") }
    foreach ($w in ($Report.Warnings | Sort-Object Code, File, Message)) { [void]$sb.Append("$($w.Code) $($w.File) $($w.Message)`n") }
    [void]$sb.Append("RESULT $(if ($Report.Pass) { 'PASS' } else { 'FAIL' })`n")
    return $sb.ToString()
}

function Update-OptionHelpRatchet {
    # Writes every changed file to a .tmp sibling first, then moves every .tmp into place only
    # once all writes succeeded, so a failure anywhere before the moves leaves every real file
    # byte-identical. The finally sweeps up any .tmp a partial run left behind. The counter regex
    # uses a lookahead for the end of line instead of consuming it, so it matches a line ending in
    # either \n or \r\n without eating the \r: a bare \d+$ never matches on a CRLF checkout because
    # in .NET (?m) mode $ sits immediately before \n, and \r is still sitting in that gap.
    param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)]$Report)
    if (-not $Report.Pass) { throw 'Refusing to advance the ratchet after a failed validation' }
    $moves = [System.Collections.Generic.List[object]]::new()
    try {
        foreach ($e in $Report.Encoders) {
            $path = Join-Path $RepoRoot "Docs\OptionHelp\$($e.Encoder).md"
            $text = [System.IO.File]::ReadAllText($path)
            $newAllowed = [Math]::Min($e.AllowedMissing, $e.Missing)
            $newMinimum = [Math]::Max($e.MinimumReviewed, $e.Reviewed)
            $updated = [regex]::Replace($text, '(?m)^Allowed-Missing: \d+(?=\r?$)', "Allowed-Missing: $newAllowed")
            $updated = [regex]::Replace($updated, '(?m)^Minimum-Reviewed: \d+(?=\r?$)', "Minimum-Reviewed: $newMinimum")
            if ($updated -ne $text) {
                $tmp = "$path.tmp"
                [System.IO.File]::WriteAllText($tmp, $updated, [System.Text.UTF8Encoding]::new($false))
                $moves.Add([pscustomobject]@{ Tmp = $tmp; Path = $path })
            }
        }
        foreach ($mv in $moves) { [System.IO.File]::Move($mv.Tmp, $mv.Path, $true) }
    }
    finally {
        foreach ($mv in $moves) { if (Test-Path -LiteralPath $mv.Tmp) { Remove-Item -LiteralPath $mv.Tmp -Force } }
    }
}

function Compare-OptionHelpFacts {
    param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][string]$FactsPath)
    $facts = Get-Content -Raw $FactsPath | ConvertFrom-Json
    $out = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $facts.PSObject.Properties['encoders']) {
        $out.Add("E11 $FactsPath has no encoders array")
        return $out
    }
    $files = Read-OhDirectory -Directory (Join-Path $RepoRoot 'Docs\OptionHelp')
    foreach ($enc in $facts.encoders) {
        if (-not $files.ContainsKey($enc.encoder)) { $out.Add("E11 $($enc.encoder) has no help file"); continue }
        $f = $files[$enc.encoder]
        $sourceRel = if ($f.Header.Contains('Source')) { $f.Header['Source'] } else { $null }
        if (-not $sourceRel -or $sourceRel -match '\.\.' -or -not (Test-OhPathCase -RepoRoot $RepoRoot -RelativePath $sourceRel)) {
            $out.Add("E11 $($enc.encoder) Source path is missing, outside the repository, or its case does not match")
            continue
        }
        $extraction = Get-VbParameters -Path (Join-Path $RepoRoot $sourceRel) -EncoderId $enc.encoder
        # Key both sides by identity regardless of exclusion, so an exclusion mismatch is caught
        # explicitly instead of silently dropping one side's entry.
        $app = @{}
        foreach ($p in $enc.parameters) { if ($p.identity) { $app[$p.identity] = $p } }
        foreach ($p in $extraction.Parameters) {
            if (-not $p.Identity) { continue }
            if (-not $app.ContainsKey($p.Identity)) { $out.Add("E11 $($p.Identity) missing from the application export"); continue }
            $a = $app[$p.Identity]
            if ([bool]$a.excluded -ne [bool]$p.Excluded) {
                $out.Add("E11 $($p.Identity) excluded differs: application '$($a.excluded.ToString().ToLower())' extractor '$($p.Excluded.ToString().ToLower())'")
                $app.Remove($p.Identity)
                continue
            }
            if (-not $p.Excluded) {
                if (($a.switches -join ',') -ne ($p.Switches -join ',')) { $out.Add("E11 $($p.Identity) switches differ: application '$($a.switches -join ',')' extractor '$($p.Switches -join ',')'") }
                if (($a.values -join ',') -ne ($p.EmittedValues -join ',')) { $out.Add("E11 $($p.Identity) values differ: application '$($a.values -join ',')' extractor '$($p.EmittedValues -join ',')'") }
                if ($a.caption -ne $p.Caption) { $out.Add("E11 $($p.Identity) caption differs: application '$($a.caption)' extractor '$($p.Caption)'") }
            }
            $app.Remove($p.Identity)
        }
        foreach ($k in $app.Keys) { $out.Add("E11 $k missing from the extractor") }
    }
    return $out
}

Export-ModuleMember -Function Read-OptionHelpFile, ConvertFrom-OptionHelpText, ConvertTo-OptionHelpDump, Invoke-OptionHelpSelfTest, Test-OhInline, ConvertTo-OhPlainText, Get-VbParameters, Get-VbOptionHelpId, ConvertTo-OhVbDump, Get-OhChain, Resolve-OhId, Read-OhDirectory, Test-OptionHelpRepository, Format-OptionHelpReport, Update-OptionHelpRatchet, Compare-OptionHelpFacts
