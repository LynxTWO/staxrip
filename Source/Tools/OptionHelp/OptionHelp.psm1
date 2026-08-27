Set-StrictMode -Version Latest

$script:HeaderKeys = @('Schema', 'Encoder', 'Locale', 'Title', 'Source', 'Inherits',
    'Allowed-Missing', 'Minimum-Reviewed', 'Reviewed-Complete',
    'Verified-Encoder-Version', 'Verified-Encoder-Build', 'Verified-Date', 'Documentation')
$script:FieldOrder = @('Label', 'Use', 'Summary', 'Used when', 'When to change',
    'Encoder default', 'Example', 'Values', 'Related', 'References', 'Status')
$script:FieldLimits = [hashtable]::new([System.StringComparer]::Ordinal)
$script:FieldLimits['Label'] = 60
$script:FieldLimits['Summary'] = 200
$script:FieldLimits['Used when'] = 200
$script:FieldLimits['When to change'] = 400
$script:FieldLimits['Encoder default'] = 40
$script:FieldLimits['Example'] = 300
$script:NoteLimit = 120
$script:SharedIds = @('staxrip', 'concepts', 'shared')
# Continuation lines join the text of every other field; on these three the joined text would be a
# silently different identifier, status, or link list, so a continuation is an error and is dropped.
$script:NoContinuationFields = @('Status', 'Use', 'Related')
$script:IdPattern = '^[a-z0-9-]+(\.[a-z0-9-]+)+$'
$script:EncoderPattern = '^[a-z0-9-]+$'
$script:LinkPattern = '\[([^\[\]]+)\]\((https?://[^\s()]+)\)'
# VB line-break tokens that a caption may be concatenated with; the extractor joins the literals
# around them with one space so a two-line caption compares equal to the application's own string.
$script:VbBreakToken = '(?:BR|vbLf|vbCrLf|vbNewLine|ControlChars\.Lf|ControlChars\.CrLf|ControlChars\.NewLine)'
$script:VbLiteral = '"(?:[^"]|"")*"'

function New-OhMap {
    # An identifier-keyed hashtable. Ordinal so that 'Fake' and 'fake' are two different encoders.
    [System.Collections.Hashtable]::new([System.StringComparer]::Ordinal)
}

function New-OhOrderedMap {
    # An identifier-keyed dictionary that keeps insertion order, ordinal for the same reason.
    [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
}

function Get-OhSorted {
    # Sorts $Items by the parallel $Keys with the ordinal string comparer, so the report and the
    # dump order the same way on every machine regardless of the current culture.
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Keys,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Items)
    # The sorted items are written to the pipeline one by one, so every call site can wrap the
    # call in @() or feed it straight to foreach and get the elements, never a nested array.
    if ($Keys.Length -lt 2) { return $Items }
    # Both arrays are passed as [array] and the comparer as IComparer so that PowerShell binds the
    # non-generic Array.Sort(Array, Array, IComparer): the generic overload converts a mismatched
    # items array and sorts the copy, leaving the caller's items in their original order.
    $k = [object[]]@($Keys)
    $v = [object[]]@($Items)
    [System.Array]::Sort([array]$k, [array]$v, [System.Collections.IComparer][System.StringComparer]::Ordinal)
    return $v
}

function Get-OhSortKey {
    # One tab-separated string per sort; numbers are zero-padded so that an ordinal text sort
    # orders them numerically.
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Parts)
    $out = foreach ($p in $Parts) { if ($p -is [int]) { '{0:D8}' -f $p } else { [string]$p } }
    return (@($out) -join "`t")
}

function New-OhError {
    param([int]$Line, [string]$Level, [string]$Code, [string]$Message)
    [pscustomobject]@{ Line = $Line; Level = $Level; Code = $Code; Message = $Message }
}

function New-OhStanza {
    param([string]$Id, [int]$Line)
    [pscustomobject]@{
        Id = $Id; Line = $Line; Fields = (New-OhOrderedMap); FieldLines = (New-OhOrderedMap); Values = [System.Collections.Generic.List[object]]::new()
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
    $header = New-OhOrderedMap
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
            if ($id -cnotmatch $script:IdPattern) {
                $errors.Add((New-OhError $lineNo 'STANZA' 'E1' "Invalid stanza id '$id'"))
            }
            continue
        }

        if ($null -eq $stanza) {
            # The shape test stays case-insensitive on purpose: 'encoder: fake' is then captured as
            # a key and rejected by the case-sensitive key lookup with the error that names it,
            # instead of falling through to the vaguer 'not a header line'.
            if ($line -match '^([A-Z][A-Za-z-]*): ?(.*)$') {
                $key = $Matches[1]; $value = $Matches[2].Trim()
                if ($script:HeaderKeys -cnotcontains $key) {
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

        # Case-insensitive for the same reason as the header: 'summary: x' is caught as an unknown
        # field rather than joined silently into whatever field came before it. The name itself is
        # then matched case-sensitively, because Array.IndexOf compares strings ordinally.
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
            if (($field -ceq 'Values' -or $field -ceq 'References') -and $value -ne '') {
                $errors.Add((New-OhError $lineNo 'STANZA' 'E3' "Field '$field' must have no text on its line"))
                $value = ''
            }
            $stanza.Fields[$field] = $value
            $stanza.FieldLines[$field] = $lineNo
            if ($field -ceq 'Status') { $stanza.Status = $value }
            $currentField = $field
            continue
        }

        if ($line -match '^- (.*)$') {
            $item = $Matches[1].Trim()
            if ($currentField -ceq 'Values') {
                $sep = $item.IndexOf(': ')
                if ($sep -lt 1) {
                    $errors.Add((New-OhError $lineNo 'STANZA' 'E3' 'Value bullet needs "<value>: <note>"'))
                }
                else {
                    $stanza.Values.Add([pscustomobject]@{ Value = $item.Substring(0, $sep); Note = $item.Substring($sep + 2).Trim(); Line = $lineNo })
                }
            }
            elseif ($currentField -ceq 'References') {
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

        if ($null -ne $currentField -and $currentField -cne 'Values' -and $currentField -cne 'References') {
            if ($script:NoContinuationFields -ccontains $currentField) {
                $errors.Add((New-OhError $lineNo 'STANZA' 'E3' "Continuation is not allowed for '$currentField'"))
            }
            else {
                $stanza.Fields[$currentField] = ($stanza.Fields[$currentField] + ' ' + $trimmed).Trim()
            }
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
            if ($f -ceq 'Values') { foreach ($v in $s.Values) { [void]$sb.Append("V $($v.Value)=$($v.Note)`n") } }
            if ($f -ceq 'References') { foreach ($r in $s.References) { [void]$sb.Append("R $r`n") } }
        }
    }
    # Line first, then the code as text ('E13' sorts between 'E1' and 'E3'), then level and message
    # so that two errors on one line always land in the same order; both parsers share this order.
    $items = @($File.Errors)
    $keys = [string[]]@($items | ForEach-Object { Get-OhSortKey -Parts @($_.Line, $_.Code, $_.Level, $_.Message) })
    foreach ($e in (Get-OhSorted -Keys $keys -Items $items)) { [void]$sb.Append("ERR $($e.Line) $($e.Level) $($e.Code)`n") }
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
    # Returns the string value of `.Name = "..."` inside an initializer, or $null. A caption may be
    # split over two lines in the dialog with `"a" + BR + "b"` (or `& BR &`, vbLf, vbCrLf); the
    # literals around such a token are joined with one space so the value compares equal to the
    # single-line caption the application reports for the same control.
    param([string]$Init, [string]$Member)
    $chain = $script:VbLiteral + '(?:\s*[+&]\s*' + $script:VbBreakToken + '\s*[+&]\s*' + $script:VbLiteral + ')*'
    $m = [regex]::Match($Init, '\.' + [regex]::Escape($Member) + '\s*=\s*(' + $chain + ')')
    if (-not $m.Success) { return $null }
    $parts = foreach ($lm in [regex]::Matches($m.Groups[1].Value, $script:VbLiteral)) {
        $lm.Value.Substring(1, $lm.Value.Length - 2).Replace('""', '"')
    }
    return (@($parts) -join ' ')
}

function ConvertTo-OhCaption {
    # Captions are compared after collapsing every run of whitespace to one space, so a caption the
    # application joins with a newline and one this script joins with a space are the same caption.
    param([AllowNull()][AllowEmptyString()][string]$Text)
    if ($null -eq $Text) { return '' }
    return ([regex]::Replace($Text, '\s+', ' ')).Trim()
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
        if ($type -ceq 'LineParam' -or $type -ceq 'CommandLineParam') { continue }
        if ($script:ParamTypes -cnotcontains $type) {
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
        foreach ($s in @($switch, $noSwitch, $helpSwitch)) { if ($s -and $all -cnotcontains $s) { $all.Add($s) } }
        if ($switches) { foreach ($s in $switches) { if ($s -and $all -cnotcontains $s) { $all.Add($s) } } }

        $primary = if ($helpSwitch) { $helpSwitch } elseif ($switch) { $switch } elseif ($noSwitch) { $noSwitch } elseif ($switches -and $switches.Length -gt 0) { $switches[0] } else { $null }
        $excluded = $false; $identity = $null
        if ($key -ceq 'none') { $excluded = $true }
        elseif ($key) { $identity = $key }
        elseif ($primary -and $EncoderId) { $identity = $EncoderId + '.' + ($primary -replace '^-+', '') }
        if (-not $excluded) {
            if (-not $identity) { $errors.Add((New-OhError $lineNo 'FILE' 'E10' "Parameter '$name' ($caption) has no identity; set OptionHelpKey")) }
            elseif ($identity -cnotmatch $script:IdPattern) { $errors.Add((New-OhError $lineNo 'FILE' 'E10' "Identity '$identity' is not a valid id")) }
        }

        $emitted = @()
        if ($type -ceq 'OptionParam') {
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
        $paramId = if ($p.Identity) { $p.Identity } else { '-' }
        [void]$sb.Append("P $($p.Line) $($p.Name) $($p.Type) id=$paramId excluded=$($p.Excluded.ToString().ToLower()) caption=$($p.Caption) switches=$($p.Switches -join ',') values=$($p.EmittedValues -join ',')`n")
    }
    $items = @($Extraction.Errors)
    $keys = [string[]]@($items | ForEach-Object { Get-OhSortKey -Parts @($_.Line, $_.Code, $_.Message) })
    foreach ($e in (Get-OhSorted -Keys $keys -Items $items)) { [void]$sb.Append("ERR $($e.Line) $($e.Code)`n") }
    return $sb.ToString()
}

function Read-OhDirectory {
    # Parses every help file in a directory, English and translations alike. Files is an ordinal
    # map from encoder id to the English file; Others holds the translations and any English file
    # a duplicate displaced, so a caller can surface their parse errors too. The canonical English
    # name is <encoder>.md and it sorts after <encoder>.en.md, so the later file in ordinal name
    # order wins the slot and the file it displaces is the one reported as the duplicate.
    param([Parameter(Mandatory)][string]$Directory)
    $files = New-OhMap
    $others = [System.Collections.Generic.List[object]]::new()
    $errors = [System.Collections.Generic.List[object]]::new()
    $slots = New-OhMap
    $entries = @(Get-ChildItem -LiteralPath $Directory -Filter '*.md' -File)
    $keys = [string[]]@($entries | ForEach-Object { $_.Name })
    foreach ($f in (Get-OhSorted -Keys $keys -Items $entries)) {
        if ($f.Name -ceq 'README.md') { continue }
        $parsed = Read-OptionHelpFile -Path $f.FullName
        $slot = "$($parsed.Encoder)|$($parsed.Locale)"
        if ($slots.ContainsKey($slot)) {
            $prev = $slots[$slot]
            $errors.Add([pscustomobject]@{ Name = $prev.Name; Encoder = $parsed.Encoder; Line = 1; Code = 'E1'
                    Message = "Duplicate help file for encoder '$($parsed.Encoder)' locale '$($parsed.Locale)'"
                })
            if ($prev.Locale -ceq 'en') { $others.Add($prev) }
        }
        $slots[$slot] = $parsed
        if ($parsed.Locale -cne 'en') { $others.Add($parsed); continue }
        $files[$parsed.Encoder] = $parsed
    }
    return [pscustomobject]@{ Files = $files; Others = $others; Errors = $errors }
}

function Get-OhChain {
    param([Parameter(Mandatory)][hashtable]$Files, [Parameter(Mandatory)][string]$EncoderId)
    $chain = [System.Collections.Generic.List[object]]::new()
    $seen = New-OhMap
    $current = $EncoderId
    while ($current) {
        if ($seen.ContainsKey($current)) { throw "Inheritance cycle at '$current'" }
        if (-not $Files.ContainsKey($current)) { throw "Unknown encoder file '$current'" }
        $seen[$current] = $true
        $file = $Files[$current]
        $chain.Add($file)
        $current = if ($file.Header.Contains('Inherits')) { $file.Header['Inherits'] } else { $null }
    }
    if ($EncoderId -cne 'staxrip' -and $Files.ContainsKey('staxrip')) { $chain.Add($Files['staxrip']) }
    return ,$chain
}

function Find-OhStanza {
    param([Parameter(Mandatory)]$File, [Parameter(Mandatory)][string]$Id)
    foreach ($s in $File.Stanzas) { if ($s.Id -ceq $Id) { return $s } }
    return $null
}

function Split-OhId {
    # An id is <namespace>.<local part>; the local part keeps any further dots.
    param([Parameter(Mandatory)][string]$Id)
    $dot = $Id.IndexOf('.')
    if ($dot -lt 1) { return [pscustomobject]@{ Namespace = ''; Local = $Id } }
    return [pscustomobject]@{ Namespace = $Id.Substring(0, $dot); Local = $Id.Substring($dot + 1) }
}

function Resolve-OhId {
    # An identity in the parameter's own encoder namespace is resolved namespace-relative: each
    # file in the chain is probed for <that file's encoder>.<local part>, so a variant inherits
    # every base stanza without repeating base ids and overrides one by defining the same local
    # part in its own namespace. An identity in any other namespace (staxrip, shared, concept, or
    # a foreign encoder) is probed verbatim in each chain file.
    param(
        [Parameter(Mandatory)]$Chain, [Parameter(Mandatory)][hashtable]$Files,
        [Parameter(Mandatory)][string]$Id, [AllowEmptyString()][string]$HomeEncoder)
    $parts = Split-OhId -Id $Id
    $ownNamespace = ($HomeEncoder -and $parts.Namespace -ceq $HomeEncoder)
    foreach ($file in $Chain) {
        $probe = if ($ownNamespace) { "$($file.Encoder).$($parts.Local)" } else { $Id }
        $s = Find-OhStanza -File $file -Id $probe
        if ($null -eq $s) { continue }
        if ($s.Status -cne 'reviewed') { return @{ Outcome = 'draft'; File = $file.Name; Stanza = $s } }
        if ($s.Fields.Contains('Use')) {
            $targetId = $s.Fields['Use']
            $targetFileId = (Split-OhId -Id $targetId).Namespace
            if (-not $Files.ContainsKey($targetFileId)) { return @{ Outcome = 'draft'; File = $file.Name; Stanza = $s } }
            $t = Find-OhStanza -File $Files[$targetFileId] -Id $targetId
            if ($null -eq $t -or $t.Status -cne 'reviewed' -or $t.Fields.Contains('Use')) { return @{ Outcome = 'draft'; File = $file.Name; Stanza = $s } }
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
    $mdFiles = @(Get-ChildItem -LiteralPath (Join-Path $FixturesRoot 'md') -Filter '*.md' -File)
    foreach ($md in (Get-OhSorted -Keys ([string[]]@($mdFiles | ForEach-Object { $_.Name })) -Items $mdFiles)) {
        $count++
        $expectedPath = Join-Path $FixturesRoot ('expected/' + ($md.Name -replace '\.md$', '.txt'))
        $expected = [System.IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n")
        $actual = ConvertTo-OptionHelpDump -File (Read-OptionHelpFile -Path $md.FullName)
        if ($expected -cne $actual) {
            $failures++
            $el = $expected.Split("`n"); $al = $actual.Split("`n")
            for ($i = 0; $i -lt [Math]::Max($el.Length, $al.Length); $i++) {
                $e = if ($i -lt $el.Length) { $el[$i] } else { '<missing>' }
                $a = if ($i -lt $al.Length) { $al[$i] } else { '<missing>' }
                if ($e -cne $a) {
                    [Console]::Error.WriteLine("FAIL $($md.Name) line $($i + 1)`n  expected: $e`n  actual:   $a")
                    break
                }
            }
        }
    }
    $vbFiles = @(Get-ChildItem -LiteralPath (Join-Path $FixturesRoot 'vb') -Filter '*.vb' -File)
    foreach ($vb in (Get-OhSorted -Keys ([string[]]@($vbFiles | ForEach-Object { $_.Name })) -Items $vbFiles)) {
        $count++
        $expectedPath = Join-Path $FixturesRoot ('expected/vb-' + ($vb.Name -replace '\.vb$', '.txt'))
        $expected = [System.IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n")
        $extraction = Get-VbParameters -Path $vb.FullName -EncoderId 'fake'
        $actual = ConvertTo-OhVbDump -Extraction $extraction
        if ($expected -cne $actual) {
            $failures++
            [Console]::Error.WriteLine("FAIL vb-$($vb.Name)`n--- expected`n$expected`n--- actual`n$actual")
        }
    }

    $chainDir = Join-Path $FixturesRoot 'chain'
    $files = (Read-OhDirectory -Directory $chainDir).Files
    foreach ($case in [System.IO.File]::ReadAllLines((Join-Path $chainDir 'cases.txt'))) {
        if ($case.Trim() -eq '') { continue }
        $count++
        $parts = $case -split ' => '
        $lhs = $parts[0].Split(' ')
        # The left-hand encoder is both the chain root and the home encoder of the identity.
        $chain = Get-OhChain -Files $files -EncoderId $lhs[0]
        $r = Resolve-OhId -Chain $chain -Files $files -Id $lhs[1] -HomeEncoder $lhs[0]
        $actual = if ($r.Outcome -ceq 'none') { 'none' } else { "$($r.Outcome):$($r.File)" }
        if ($actual -cne $parts[1]) { $failures++; [Console]::Error.WriteLine("FAIL chain '$case' actual '$actual'") }
    }

    foreach ($repo in @('repo', 'repo-clean')) {
        $count++
        $expected = [System.IO.File]::ReadAllText((Join-Path $FixturesRoot "expected/report-$repo.txt")).Replace("`r`n", "`n")
        $actual = Format-OptionHelpReport -Report (Test-OptionHelpRepository -RepoRoot (Join-Path $FixturesRoot $repo))
        if ($expected -cne $actual) { $failures++; [Console]::Error.WriteLine("FAIL report-$repo`n--- expected`n$expected`n--- actual`n$actual") }
    }
    # A -Encoder typo that names no English file must fail loudly, not print an empty RESULT PASS.
    $count++
    $expected = [System.IO.File]::ReadAllText((Join-Path $FixturesRoot 'expected/report-repo-bogus.txt')).Replace("`r`n", "`n")
    $actual = Format-OptionHelpReport -Report (Test-OptionHelpRepository -RepoRoot (Join-Path $FixturesRoot 'repo') -Encoder 'bogus')
    if ($expected -cne $actual) { $failures++; [Console]::Error.WriteLine("FAIL report-repo-bogus`n--- expected`n$expected`n--- actual`n$actual") }
    # Ratchet: copy repo-clean to a temp dir, advance, compare the two counter lines.
    $count++
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("optionhelp-ratchet-" + [guid]::NewGuid().ToString('N'))
    Copy-Item (Join-Path $FixturesRoot 'repo-clean') $tmp -Recurse
    try {
        $rep = Test-OptionHelpRepository -RepoRoot $tmp
        Update-OptionHelpRatchet -RepoRoot $tmp -Report $rep
        $after = [System.IO.File]::ReadAllText((Join-Path $tmp 'Docs/OptionHelp/clean.md')).Replace("`r`n", "`n")
        $lines = @(($after -split "`n") | Where-Object { $_ -match '^(Allowed-Missing|Minimum-Reviewed): ' })
        $expected = [System.IO.File]::ReadAllText((Join-Path $FixturesRoot 'expected/ratchet-repo-clean.txt')).Replace("`r`n", "`n").TrimEnd("`n")
        if (($lines -join "`n") -cne $expected) { $failures++; [Console]::Error.WriteLine("FAIL ratchet`n--- expected`n$expected`n--- actual`n$($lines -join "`n")") }
    }
    finally { Remove-Item $tmp -Recurse -Force }
    # Ratchet CRLF safety: same fixture, but clean.md is converted to CRLF before advancing. The
    # counters must land on the same values as the LF case, and the CR count must be unchanged,
    # proving the regex rewrote only the digits and never touched the line endings.
    $count++
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("optionhelp-ratchet-crlf-" + [guid]::NewGuid().ToString('N'))
    Copy-Item (Join-Path $FixturesRoot 'repo-clean') $tmp -Recurse
    try {
        $cleanPath = Join-Path $tmp 'Docs/OptionHelp/clean.md'
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
        $expected = [System.IO.File]::ReadAllText((Join-Path $FixturesRoot 'expected/ratchet-repo-clean.txt')).Replace("`r`n", "`n").TrimEnd("`n")
        if (($lines -join "`n") -cne $expected) { $failures++; [Console]::Error.WriteLine("FAIL ratchet-crlf counters`n--- expected`n$expected`n--- actual`n$($lines -join "`n")") }
        if ($crAfter -ne $crBefore) { $failures++; [Console]::Error.WriteLine("FAIL ratchet-crlf CR count changed: before=$crBefore after=$crAfter") }
    }
    finally { Remove-Item $tmp -Recurse -Force }
    # Facts comparison against the fake repository.
    $count++
    $diff = Compare-OptionHelpFacts -RepoRoot (Join-Path $FixturesRoot 'repo') -FactsPath (Join-Path $FixturesRoot 'facts/fake-export.json')
    $expected = [System.IO.File]::ReadAllText((Join-Path $FixturesRoot 'expected/compare-facts.txt')).Replace("`r`n", "`n").TrimEnd("`n")
    if (($diff -join "`n") -cne $expected) { $failures++; [Console]::Error.WriteLine("FAIL compare-facts`n--- expected`n$expected`n--- actual`n$($diff -join "`n")") }
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
    $isShared = $script:SharedIds -ccontains $File.Encoder

    if (-not $h.Contains('Schema') -or $h['Schema'] -cne '1') { $errors.Add((New-OhError 1 'FILE' 'E1' 'Schema must be 1')) }
    if (-not $h.Contains('Encoder')) { $errors.Add((New-OhError 1 'FILE' 'E1' 'Encoder header is required')) }
    elseif ($h['Encoder'] -cnotmatch $script:EncoderPattern -or $h['Encoder'] -cne $File.Encoder) {
        $errors.Add((New-OhError 1 'FILE' 'E1' "Encoder '$($h['Encoder'])' must match the file name '$($File.Encoder)'"))
    }
    if (-not $h.Contains('Locale')) { $errors.Add((New-OhError 1 'FILE' 'E1' 'Locale header is required')) }
    elseif ($h['Locale'] -cne $File.Locale) { $errors.Add((New-OhError 1 'FILE' 'E1' "Locale '$($h['Locale'])' must match the file name locale '$($File.Locale)'")) }
    if (-not $h.Contains('Title')) { $errors.Add((New-OhError 1 'FILE' 'E1' 'Title header is required')) }

    $anyReviewed = @($File.Stanzas | Where-Object { $_.Status -ceq 'reviewed' }).Count -gt 0
    if (-not $isShared) {
        foreach ($key in @('Source', 'Allowed-Missing', 'Minimum-Reviewed', 'Reviewed-Complete')) {
            if (-not $h.Contains($key)) { $errors.Add((New-OhError 1 'FILE' 'E1' "$key header is required for an encoder file")) }
        }
        foreach ($key in @('Allowed-Missing', 'Minimum-Reviewed')) {
            if ($h.Contains($key) -and $h[$key] -cnotmatch '^\d+$') { $errors.Add((New-OhError 1 'FILE' 'E1' "$key must be a non-negative integer")) }
        }
        if ($h.Contains('Reviewed-Complete') -and $h['Reviewed-Complete'] -cnotin @('true', 'false')) {
            $errors.Add((New-OhError 1 'FILE' 'E1' 'Reviewed-Complete must be true or false'))
        }
        if ($anyReviewed) {
            $missing = @(@('Verified-Encoder-Version', 'Verified-Encoder-Build', 'Verified-Date', 'Documentation') | Where-Object { -not $h.Contains($_) })
            if ($missing.Count -gt 0) { $errors.Add((New-OhError 1 'FILE' 'E1' "Reviewed stanzas require headers: $($missing -join ', ')")) }
        }
        if ($h.Contains('Verified-Date') -and $h['Verified-Date'] -cnotmatch '^\d{4}-\d{2}-\d{2}$') { $errors.Add((New-OhError 1 'FILE' 'E1' 'Verified-Date must be an ISO date')) }
        if ($h.Contains('Documentation') -and $h['Documentation'] -notmatch '^https?://\S+$') { $errors.Add((New-OhError 1 'FILE' 'E1' 'Documentation must be an http or https URL')) }
        if ($h.Contains('Inherits') -and ($h['Inherits'] -cnotmatch $script:EncoderPattern -or $script:SharedIds -ccontains $h['Inherits'])) {
            $errors.Add((New-OhError 1 'FILE' 'E1' 'Inherits must name an encoder file'))
        }
        elseif ($h.Contains('Inherits')) {
            # Chains are resolved by Task 3; the parser only records that a base is named.
            $File | Add-Member -NotePropertyName 'Inherits' -NotePropertyValue $h['Inherits'] -Force
        }
    }
    elseif ($h.Contains('Inherits')) { $errors.Add((New-OhError 1 'FILE' 'E1' 'Shared files cannot inherit')) }

    $seen = New-OhMap
    foreach ($s in $File.Stanzas) {
        if ($seen.ContainsKey($s.Id)) { $errors.Add((New-OhError $s.Line 'FILE' 'E8' "Duplicate stanza id '$($s.Id)'")) } else { $seen[$s.Id] = $true }
        $f = $s.Fields
        $hasUse = $f.Contains('Use')
        if ($hasUse) {
            foreach ($k in $f.Keys) { if ($k -cnotin @('Label', 'Use', 'Status')) { $errors.Add((New-OhError $s.Line 'STANZA' 'E3' "Field '$k' is not allowed with Use")) } }
        }
        if (-not $f.Contains('Status')) { $errors.Add((New-OhError $s.Line 'STANZA' 'E3' 'Status is required')) }
        elseif ($s.Status -cnotin @('draft', 'reviewed')) { $errors.Add((New-OhError $s.Line 'STANZA' 'E3' "Status must be draft or reviewed, not '$($s.Status)'")) }
        if (-not $hasUse) {
            if (-not $f.Contains('Summary') -or $f['Summary'] -eq '') { $errors.Add((New-OhError $s.Line 'STANZA' 'E2' 'Summary is required')) }
            elseif (-not $f['Summary'].EndsWith('.')) { $errors.Add((New-OhError $s.Line 'STANZA' 'E2' 'Summary must end with a period')) }
            if ($s.Status -ceq 'reviewed' -and -not $f.Contains('When to change')) { $errors.Add((New-OhError $s.Line 'STANZA' 'E2' 'When to change is required on a reviewed stanza')) }
        }
        foreach ($k in $f.Keys) {
            if ($script:FieldLimits.ContainsKey($k) -and $f[$k].Length -gt $script:FieldLimits[$k]) {
                $errors.Add((New-OhError $s.Line 'STANZA' 'E2' "$k exceeds $($script:FieldLimits[$k]) characters"))
            }
            if ($k -cin @('Summary', 'Used when', 'When to change', 'Example', 'Encoder default', 'Label')) {
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
    # One object per <EmbeddedResource> item under Docs\OptionHelp: the file name, and the
    # <LogicalName> the item declares or $null when it declares none. VB names an embedded resource
    # <RootNamespace>.<file name> and ignores the folder and the <Link>, so the LogicalName is the
    # only thing that puts the '.OptionHelp.' marker the loader enumerates into the manifest name.
    param([string]$ProjectPath)
    $entries = [System.Collections.Generic.List[object]]::new()
    if (-not (Test-Path $ProjectPath)) { return $entries }
    $text = [System.IO.File]::ReadAllText($ProjectPath)
    # Singleline so that the element body, which spans lines, is captured by group 2; the lazy
    # quantifier stops at this item's own closing tag rather than the last one in the file.
    $pattern = '<EmbeddedResource\s+Include="\.\.\\Docs\\OptionHelp\\([^"]+)"\s*(?:/>|>(.*?)</EmbeddedResource>)'
    foreach ($m in [regex]::Matches($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
        $logical = $null
        if ($m.Groups[2].Success) {
            $inner = [regex]::Match($m.Groups[2].Value, '<LogicalName>([^<]*)</LogicalName>')
            if ($inner.Success) { $logical = $inner.Groups[1].Value }
        }
        $entries.Add([pscustomobject]@{ Name = $m.Groups[1].Value; LogicalName = $logical })
    }
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

function Get-OhDescendants {
    # Every encoder whose Inherits chain reaches $EncoderId, transitively; $EncoderId is not in it.
    # The ids go to the pipeline one by one, so a caller's @() gets the ids and never an array
    # holding an array, which would silently match no encoder at all.
    param([Parameter(Mandatory)][hashtable]$Files, [Parameter(Mandatory)][string]$EncoderId)
    $found = New-OhMap
    $frontier = [System.Collections.Generic.List[string]]::new()
    $frontier.Add($EncoderId)
    while ($frontier.Count -gt 0) {
        $current = $frontier[0]
        $frontier.RemoveAt(0)
        foreach ($f in $Files.Values) {
            if (-not $f.Header.Contains('Inherits')) { continue }
            if ($f.Header['Inherits'] -cne $current) { continue }
            if ($f.Encoder -ceq $EncoderId -or $found.ContainsKey($f.Encoder)) { continue }
            $found[$f.Encoder] = $true
            $frontier.Add($f.Encoder)
        }
    }
    return @($found.Keys)
}

function Add-OhLinkErrors {
    # E6 for one file's stanzas. This runs for the shared files too; only E5 is exempt for them.
    param(
        [Parameter(Mandatory)]$File, [Parameter(Mandatory)][hashtable]$Files,
        [Parameter(Mandatory)]$Errors)
    foreach ($s in $File.Stanzas) {
        if ($s.Fields.Contains('Related')) {
            foreach ($rel in ($s.Fields['Related'] -split ',\s*')) {
                $target = $null
                foreach ($other in $Files.Values) { $t = Find-OhStanza -File $other -Id $rel; if ($t) { $target = $t; break } }
                if (-not $target) { $Errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($File.Name)"; Line = $s.FieldLines['Related']; Code = 'E6'; Message = "Related target '$rel' does not exist" }) }
            }
        }
        if ($s.Fields.Contains('Use')) {
            $r2 = Resolve-OhId -Chain @($File) -Files $Files -Id $s.Id -HomeEncoder $File.Encoder
            if ($r2.Outcome -cne 'alias') { $Errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($File.Name)"; Line = $s.FieldLines['Use']; Code = 'E6'; Message = "Use target '$($s.Fields['Use'])' does not exist or is not reviewed" }) }
        }
    }
}

function Test-OptionHelpRepository {
    param([Parameter(Mandatory)][string]$RepoRoot, [string]$Encoder)
    $RepoRoot = (Resolve-Path $RepoRoot).Path
    $docs = Join-Path $RepoRoot 'Docs/OptionHelp'
    $directory = Read-OhDirectory -Directory $docs
    $files = $directory.Files
    $errors = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[object]]::new()
    $encoders = [System.Collections.Generic.List[object]]::new()
    $resources = Get-OhResourceEntries -ProjectPath (Join-Path $RepoRoot 'Source/StaxRip.vbproj')
    # Every English file, ordinal by encoder id, so every loop below runs in the same order twice.
    $englishFiles = @(Get-OhSorted -Keys ([string[]]@($files.Values | ForEach-Object { $_.Encoder })) -Items ([object[]]@($files.Values)))

    # A -Encoder that names no English file must fail loudly instead of scoping every later loop
    # down to nothing and passing with an empty report.
    if ($Encoder -and -not $files.ContainsKey($Encoder)) {
        $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$Encoder.md"; Line = 1; Code = 'E1'; Message = "No help file for encoder '$Encoder'" })
    }

    # Parse errors and the file-to-resource E12 check, for translations and displaced duplicates as
    # much as for the English files: spec 5.5 gives every content file a resource entry. Both are
    # scoped to -Encoder when it is given.
    $allFiles = [System.Collections.Generic.List[object]]::new()
    foreach ($f in $englishFiles) { $allFiles.Add($f) }
    foreach ($f in $directory.Others) { $allFiles.Add($f) }
    foreach ($f in $allFiles) {
        if ($Encoder -and $f.Encoder -cne $Encoder) { continue }
        foreach ($e in $f.Errors) { $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = $e.Line; Code = $e.Code; Message = $e.Message }) }
        $hits = @($resources | Where-Object { $_.Name -ceq $f.Name }).Count
        if ($hits -eq 0) { $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = 1; Code = 'E12'; Message = 'No EmbeddedResource entry in Source/StaxRip.vbproj' }) }
        elseif ($hits -gt 1) { $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = 1; Code = 'E12'; Message = "Duplicate EmbeddedResource entries ($hits) in Source/StaxRip.vbproj" }) }
    }
    foreach ($e in $directory.Errors) {
        if ($Encoder -and $e.Encoder -cne $Encoder) { continue }
        $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($e.Name)"; Line = $e.Line; Code = $e.Code; Message = $e.Message })
    }

    # Repository-wide checks: only when not scoped to a single -Encoder.
    if (-not $Encoder) {
        foreach ($r in $resources) {
            if (-not (Test-OhPathCase -RepoRoot $docs -RelativePath $r.Name)) {
                $errors.Add([pscustomobject]@{ File = 'Source/StaxRip.vbproj'; Line = 1; Code = 'E12'; Message = "EmbeddedResource '$($r.Name)' has no file" })
                continue
            }
            # An entry that names no file cannot be loaded at all, so the missing file is the only
            # thing worth saying about it; every entry that does name one must carry the LogicalName
            # the loader's resource enumeration depends on.
            $expected = "StaxRip.OptionHelp.$($r.Name)"
            if ($r.LogicalName -cne $expected) {
                $errors.Add([pscustomobject]@{ File = 'Source/StaxRip.vbproj'; Line = 1; Code = 'E12'; Message = "EmbeddedResource '$($r.Name)' lacks LogicalName '$expected'" })
            }
        }

        # W1: encoder sources without a help file.
        $sourcesWithFile = @($englishFiles | Where-Object { $_.Header.Contains('Source') } | ForEach-Object { $_.Header['Source'].Replace('\', '/') })
        $vbFiles = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'Source/Encoding') -Filter '*.vb' -File)
        foreach ($vb in (Get-OhSorted -Keys ([string[]]@($vbFiles | ForEach-Object { $_.Name })) -Items $vbFiles)) {
            $rel = "Source/Encoding/$($vb.Name)"
            if ($sourcesWithFile -cnotcontains $rel) {
                $text = [System.IO.File]::ReadAllText($vb.FullName)
                if ($text -match 'Inherits\s+CommandLineParams') { $warnings.Add([pscustomobject]@{ File = $rel; Line = 0; Code = 'W1'; Message = 'no help file' }) }
            }
        }
    }

    # Extraction runs for every encoder file even in the scoped mode, because E5 needs the
    # parameters of the encoders that inherit from the selected one; only the errors are scoped.
    $allParams = New-OhMap
    foreach ($f in $englishFiles) {
        if ($script:SharedIds -ccontains $f.Encoder) { continue }
        $inScope = (-not $Encoder) -or ($f.Encoder -ceq $Encoder)
        $h = $f.Header
        $sourceRel = if ($h.Contains('Source')) { $h['Source'] } else { $null }
        if (-not $sourceRel) { continue }
        if ($sourceRel -match '\.\.' -or -not (Test-OhPathCase -RepoRoot $RepoRoot -RelativePath $sourceRel)) {
            if ($inScope) { $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = 1; Code = 'E12'; Message = "Source path '$sourceRel' is outside the repository or its case does not match" }) }
            continue
        }
        $extraction = Get-VbParameters -Path (Join-Path $RepoRoot $sourceRel) -EncoderId $f.Encoder
        if ($inScope) {
            foreach ($e in $extraction.Errors) { $errors.Add([pscustomobject]@{ File = $sourceRel; Line = $e.Line; Code = $e.Code; Message = $e.Message }) }
            if ($extraction.OptionHelpId -cne $f.Encoder) {
                $shown = if ($extraction.OptionHelpId) { $extraction.OptionHelpId } else { 'missing' }
                $errors.Add([pscustomobject]@{ File = $sourceRel; Line = 1; Code = 'E9'; Message = "OptionHelpId is '$shown', expected '$($f.Encoder)'" })
            }
        }
        $allParams[$f.Encoder] = $extraction.Parameters
    }

    # E4 is judged per stanza, over the union of the emitted values of every parameter that
    # resolves to it, so a value note on a stanza two controls share is valid when either control
    # emits it and each bad value is reported once. Groups are keyed by the stanza's file and line.
    $valueGroups = New-OhOrderedMap

    foreach ($f in $englishFiles) {
        if ($script:SharedIds -ccontains $f.Encoder) { continue }
        if ($Encoder -and $f.Encoder -cne $Encoder) { continue }
        if (-not $allParams.ContainsKey($f.Encoder)) { continue }
        try { $chain = Get-OhChain -Files $files -EncoderId $f.Encoder }
        catch { $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = 1; Code = 'E1'; Message = $_.Exception.Message }); continue }
        $params = $allParams[$f.Encoder]
        $reviewed = 0; $draft = 0; $missingList = [System.Collections.Generic.List[object]]::new(); $excluded = 0
        foreach ($p in $params) {
            if ($p.Excluded) { $excluded++; $warnings.Add([pscustomobject]@{ File = $f.Encoder; Line = 0; Code = 'W3'; Message = "$($p.Name) excluded" }); continue }
            if (-not $p.Identity) { continue }
            $r = Resolve-OhId -Chain $chain -Files $files -Id $p.Identity -HomeEncoder $f.Encoder
            switch ($r.Outcome) {
                'reviewed' { $reviewed++ }
                'alias' { $reviewed++ }
                'draft' { $draft++ }
                default { $missingList.Add([pscustomobject]@{ Id = $p.Identity; Caption = $p.Caption }) }
            }
            if ($r.Stanza) {
                $groupKey = "$($r.File)|$($r.Stanza.Line)"
                if (-not $valueGroups.Contains($groupKey)) {
                    $valueGroups[$groupKey] = [pscustomobject]@{
                        File = $r.File; Stanza = $r.Stanza; AnyOption = $false
                        Emitted = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
                    }
                }
                $group = $valueGroups[$groupKey]
                if ($p.Type -ceq 'OptionParam') {
                    $group.AnyOption = $true
                    foreach ($v in $p.EmittedValues) { [void]$group.Emitted.Add($v) }
                }
            }
        }
        $total = @($params | Where-Object { -not $_.Excluded }).Count
        # E5: a stanza in an encoder file must be in that file's own namespace, and its local part
        # must match the local part of an own-namespace identity of this encoder or of any encoder
        # that inherits from it, transitively.
        $localParts = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($owner in (@($f.Encoder) + @(Get-OhDescendants -Files $files -EncoderId $f.Encoder))) {
            if (-not $allParams.ContainsKey($owner)) { continue }
            foreach ($p in $allParams[$owner]) {
                if (-not $p.Identity) { continue }
                $split = Split-OhId -Id $p.Identity
                if ($split.Namespace -ceq $owner) { [void]$localParts.Add($split.Local) }
            }
        }
        foreach ($s in $f.Stanzas) {
            $split = Split-OhId -Id $s.Id
            if ($split.Namespace -cne $f.Encoder -or -not $localParts.Contains($split.Local)) {
                $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = $s.Line; Code = 'E5'; Message = "Orphan stanza '$($s.Id)'" })
            }
        }
        Add-OhLinkErrors -File $f -Files $files -Errors $errors
        # The parser already reported a counter header that is not a non-negative integer; count it
        # as 0 here so the report still prints, and show the header text itself in the row.
        $allowedText = if ($f.Header.Contains('Allowed-Missing')) { [string]$f.Header['Allowed-Missing'] } else { '0' }
        $minimumText = if ($f.Header.Contains('Minimum-Reviewed')) { [string]$f.Header['Minimum-Reviewed'] } else { '0' }
        $allowed = if ($allowedText -cmatch '^\d+$') { [int]$allowedText } else { 0 }
        $minimum = if ($minimumText -cmatch '^\d+$') { [int]$minimumText } else { 0 }
        $complete = $f.Header['Reviewed-Complete'] -ceq 'true'
        $pass = $true
        if ($missingList.Count -gt $allowed) { $pass = $false; $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = 1; Code = 'E7'; Message = "missing $($missingList.Count) exceeds Allowed-Missing $allowed" }) }
        if ($reviewed -lt $minimum) { $pass = $false; $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = 1; Code = 'E7'; Message = "reviewed $reviewed is below Minimum-Reviewed $minimum" }) }
        if ($complete -and ($missingList.Count -gt 0 -or $draft -gt 0)) { $pass = $false; $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = 1; Code = 'E7'; Message = 'Reviewed-Complete is true but not every parameter is reviewed' }) }
        $encoders.Add([pscustomobject]@{
            Encoder = $f.Encoder; File = $f.Name; Total = $total; Excluded = $excluded; Reviewed = $reviewed; Draft = $draft; Missing = $missingList.Count
            AllowedMissing = $allowed; MinimumReviewed = $minimum; AllowedMissingText = $allowedText; MinimumReviewedText = $minimumText
            ReviewedComplete = $complete; Pass = $pass; MissingIds = $missingList
        })
    }

    # E6 for the shared files: they carry no parameters, so E5 stays exempt, but a Related or Use
    # target that does not exist is the same defect there as in an encoder file.
    foreach ($f in $englishFiles) {
        if ($script:SharedIds -cnotcontains $f.Encoder) { continue }
        if ($Encoder -and $f.Encoder -cne $Encoder) { continue }
        Add-OhLinkErrors -File $f -Files $files -Errors $errors
    }

    foreach ($groupKey in @($valueGroups.Keys)) {
        $group = $valueGroups[$groupKey]
        if ($group.AnyOption) {
            foreach ($v in $group.Stanza.Values) {
                if (-not $group.Emitted.Contains($v.Value)) {
                    $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($group.File)"; Line = $v.Line; Code = 'E4'; Message = "Value '$($v.Value)' is not an emitted value of $($group.Stanza.Id)" })
                }
            }
        }
        elseif ($group.Stanza.Values.Count -gt 0) {
            $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($group.File)"; Line = $group.Stanza.Line; Code = 'E4'; Message = "Values on non-option parameter $($group.Stanza.Id)" })
        }
    }

    $overall = ($errors.Count -eq 0)
    return [pscustomobject]@{ Encoders = $encoders; Errors = $errors; Warnings = $warnings; Pass = $overall }
}

function Format-OptionHelpReport {
    param([Parameter(Mandatory)]$Report)
    $sb = [System.Text.StringBuilder]::new()
    $rows = @($Report.Encoders)
    foreach ($e in (Get-OhSorted -Keys ([string[]]@($rows | ForEach-Object { $_.Encoder })) -Items $rows)) {
        $res = if ($e.Pass) { 'PASS' } else { 'FAIL' }
        [void]$sb.Append("ENCODER $($e.Encoder) total=$($e.Total) excluded=$($e.Excluded) reviewed=$($e.Reviewed) draft=$($e.Draft) missing=$($e.Missing) allowed-missing=$($e.AllowedMissingText) minimum-reviewed=$($e.MinimumReviewedText) reviewed-complete=$($e.ReviewedComplete.ToString().ToLower()) result=$res`n")
        $printed = New-OhMap
        foreach ($m in $e.MissingIds) {
            if ($printed.ContainsKey($m.Id)) { continue }
            $printed[$m.Id] = $true
            [void]$sb.Append("MISSING $($m.Id) $($m.Caption)`n")
        }
    }
    $errs = @($Report.Errors)
    $errKeys = [string[]]@($errs | ForEach-Object { Get-OhSortKey -Parts @($_.Code, $_.File, $_.Line, $_.Message) })
    foreach ($e in (Get-OhSorted -Keys $errKeys -Items $errs)) { [void]$sb.Append("$($e.Code) $($e.File):$($e.Line) $($e.Message)`n") }
    $warns = @($Report.Warnings)
    $warnKeys = [string[]]@($warns | ForEach-Object { Get-OhSortKey -Parts @($_.Code, $_.File, $_.Message) })
    foreach ($w in (Get-OhSorted -Keys $warnKeys -Items $warns)) { [void]$sb.Append("$($w.Code) $($w.File) $($w.Message)`n") }
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
            # The file the report counted, not <encoder>.md: an encoder's English file can be
            # named <encoder>.en.md, and the ratchet must rewrite the file that was read.
            $path = Join-Path $RepoRoot "Docs/OptionHelp/$($e.File)"
            $text = [System.IO.File]::ReadAllText($path)
            $newAllowed = [Math]::Min($e.AllowedMissing, $e.Missing)
            $newMinimum = [Math]::Max($e.MinimumReviewed, $e.Reviewed)
            $updated = [regex]::Replace($text, '(?m)^Allowed-Missing: \d+(?=\r?$)', "Allowed-Missing: $newAllowed")
            $updated = [regex]::Replace($updated, '(?m)^Minimum-Reviewed: \d+(?=\r?$)', "Minimum-Reviewed: $newMinimum")
            if ($updated -cne $text) {
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

function Get-OhJsonField {
    # Strict mode makes a missing property an error, and an export written by an older build may
    # be missing one, so every read of the parsed JSON goes through this.
    param([Parameter(Mandatory)]$Object, [Parameter(Mandatory)][string]$Name)
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Get-OhFactsKey {
    # Two controls can share one identity, so the declaring property name is the key when there is
    # one; an inline parameter carries '-' as its name on both sides and falls back to its identity.
    param([AllowNull()][AllowEmptyString()][string]$Name, [AllowNull()][AllowEmptyString()][string]$Identity)
    if ($Name -and $Name -cne '-') { return $Name }
    if ($Identity) { return $Identity }
    return $null
}

function Compare-OptionHelpFacts {
    param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][string]$FactsPath)
    $facts = Get-Content -Raw $FactsPath | ConvertFrom-Json
    $out = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $facts.PSObject.Properties['encoders']) {
        $out.Add("E11 $FactsPath has no encoders array")
        return $out
    }
    $files = (Read-OhDirectory -Directory (Join-Path $RepoRoot 'Docs/OptionHelp')).Files
    foreach ($enc in $facts.encoders) {
        if (-not $files.ContainsKey($enc.encoder)) { $out.Add("E11 $($enc.encoder) has no help file"); continue }
        $f = $files[$enc.encoder]
        $sourceRel = if ($f.Header.Contains('Source')) { $f.Header['Source'] } else { $null }
        if (-not $sourceRel -or $sourceRel -match '\.\.' -or -not (Test-OhPathCase -RepoRoot $RepoRoot -RelativePath $sourceRel)) {
            $out.Add("E11 $($enc.encoder) Source path is missing, outside the repository, or its case does not match")
            continue
        }
        $extraction = Get-VbParameters -Path (Join-Path $RepoRoot $sourceRel) -EncoderId $enc.encoder
        # Key both sides by the declaring property name, so two controls that share one identity
        # are still two entries and neither hides the other; inline parameters have no property
        # name ('-' on both sides) and fall back to their identity. Excluded parameters are keyed
        # the same way and compared, which is what makes an exclusion mismatch reachable at all --
        # but only when the application exported an entry for them at all; see below.
        $app = New-OhMap
        foreach ($p in $enc.parameters) {
            $key = Get-OhFactsKey -Name ([string](Get-OhJsonField -Object $p -Name 'name')) -Identity ([string](Get-OhJsonField -Object $p -Name 'identity'))
            if ($key) { $app[$key] = $p }
        }
        foreach ($p in $extraction.Parameters) {
            $key = Get-OhFactsKey -Name $p.Name -Identity $p.Identity
            if (-not $key) { continue }
            if (-not $app.ContainsKey($key)) {
                # An excluded declaration the application never exported is not a difference. The
                # extractor reads declarations out of the text; the application exports Items, the
                # parameters it actually registered. OptionHelpKey = "none" says "this parameter is
                # not shown", and never reaching Items says exactly the same thing, so the two sides
                # already agree and there is nothing to report. A parameter that is not excluded is
                # still reported, and so is one the application exported but the extractor did not.
                if ([bool]$p.Excluded) { continue }
                $out.Add("E11 $key missing from the application export"); continue
            }
            $a = $app[$key]
            $app.Remove($key)
            $appExcluded = [bool](Get-OhJsonField -Object $a -Name 'excluded')
            if ($appExcluded -ne [bool]$p.Excluded) {
                $out.Add("E11 $key excluded differs: application '$($appExcluded.ToString().ToLower())' extractor '$($p.Excluded.ToString().ToLower())'")
                continue
            }
            if ($p.Excluded) { continue }
            $appIdentity = [string](Get-OhJsonField -Object $a -Name 'identity')
            $extractorIdentity = if ($p.Identity) { [string]$p.Identity } else { '' }
            if ($appIdentity -cne $extractorIdentity) { $out.Add("E11 $key identity differs: application '$appIdentity' extractor '$extractorIdentity'") }
            $appSwitches = (Get-OhJsonField -Object $a -Name 'switches') -join ','
            if ($appSwitches -cne ($p.Switches -join ',')) { $out.Add("E11 $key switches differ: application '$appSwitches' extractor '$($p.Switches -join ',')'") }
            $appValues = (Get-OhJsonField -Object $a -Name 'values') -join ','
            if ($appValues -cne ($p.EmittedValues -join ',')) { $out.Add("E11 $key values differ: application '$appValues' extractor '$($p.EmittedValues -join ',')'") }
            $appCaption = ConvertTo-OhCaption -Text ([string](Get-OhJsonField -Object $a -Name 'caption'))
            $extractorCaption = ConvertTo-OhCaption -Text $p.Caption
            if ($appCaption -cne $extractorCaption) { $out.Add("E11 $key caption differs: application '$appCaption' extractor '$extractorCaption'") }
        }
        foreach ($k in @(Get-OhSorted -Keys ([string[]]@($app.Keys)) -Items ([object[]]@($app.Keys)))) { $out.Add("E11 $k missing from the extractor") }
    }
    return $out
}

Export-ModuleMember -Function Read-OptionHelpFile, ConvertFrom-OptionHelpText, ConvertTo-OptionHelpDump, Invoke-OptionHelpSelfTest, Test-OhInline, ConvertTo-OhPlainText, ConvertTo-OhCaption, Get-VbParameters, Get-VbOptionHelpId, ConvertTo-OhVbDump, Get-OhChain, Resolve-OhId, Split-OhId, Read-OhDirectory, Test-OptionHelpRepository, Format-OptionHelpReport, Update-OptionHelpRatchet, Compare-OptionHelpFacts
