# Option Help Implementation Plan 1: Validator, Parameter Model, Repository Files

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the grammar authority (`Check-OptionHelp.ps1`), the parameter-model changes that give every option a stable identity, and the repository files (skeleton content, README, `AGENTS.md`, `.gitattributes`), so that a clean validator run on the real repository passes with SVT-AV1 at 100 allowed-missing.

**Architecture:** A PowerShell 7 module (`OptionHelp.psm1`) implements the file grammar, a text-level VB extractor, chain resolution, the exact-counter ratchet, and a self-test over committed fixtures; a thin script (`Check-OptionHelp.ps1`) is the CLI. `Source/Video/VideoEncoderCommandLine.vb` gains `OptionHelpId`, `OptionHelpKey`, `PrimaryHelpSwitch`, `OptionHelpIdentity`, `GetEmittedValue`, and `ExportOptionHelpFacts`; `SvtAv1Enc.vb` binds SVT-AV1. Nothing here touches the dialog; plan 2 does that.

**Tech Stack:** PowerShell 7.6 (`pwsh`), VB.NET on .NET Framework 4.8 built with `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe`, Git.

**Spec:** `Docs/Planning/OPTION-HELP.md` (v0.2). Sections cited per task.

## Global Constraints

- Work in the worktree `C:\DEV\StaxRip\.claude\worktrees\option-help` on branch `worktree-option-help`; never run git commands against the main tree.
- Commit after every task; end commit messages with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- File grammar exactly as spec 4.2 to 4.4: UTF-8 without BOM, LF, Unicode allowed; header keys and field names and limits from 4.3; IDs match `^[a-z0-9-]+(\.[a-z0-9-]+)+$`.
- Reserved shared encoder ids: `staxrip`, `concepts`, `shared`. Every other `Encoder` is an encoder file that requires `Source`, `Allowed-Missing`, `Minimum-Reviewed`, `Reviewed-Complete`.
- Primary switch order (spec 4.4): explicit `.HelpSwitch`, else `.Switch`, else `.NoSwitch`, else first `.Switches` entry.
- Derived identity: `<OptionHelpId>.<primary switch without leading dashes>`; `OptionHelpKey = "none"` excludes a parameter.
- Emitted value for a dropdown index (spec 5.2): `Values(index)` when `Values` exists, else the index as text when `IntegerValue`, else the option text lower-cased with spaces removed.
- Error codes E1 to E13 and warnings W1 to W3 exactly as spec 6.3; the canonical dump in Task 1 carries codes and lines, never messages.
- `Source/Build.ps1` scans every `*.ps1` and `*.vbproj` under `Source` and throws on any byte above 127: PowerShell and project files in this plan are ASCII only. Markdown and `.vb` files are exempt.
- Build command for the managed project (from `Docs/Verification/Clean-Build-Dry-Run.md`): `& 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe' 'Source\StaxRip.vbproj' -t:Build -p:Configuration=Debug -p:Platform=x64 -m -nologo -verbosity:minimal`. The worktree has no `Source\packages`; Task 5 copies it from `C:\DEV\StaxRip\Source\packages` (three package folders, hashes recorded in that document). Never run `Source/Build.ps1`, `BuildAndPack.ps1`, or `Release.ps1`.
- No new NuGet packages anywhere.

---

## File structure

| File | Responsibility |
| --- | --- |
| `Source/Tools/OptionHelp/OptionHelp.psm1` | Grammar parser, canonical dump, VB extractor, chain resolution, repository check, report, ratchet, facts comparison |
| `Source/Tools/OptionHelp/Check-OptionHelp.ps1` | CLI: `-RepoRoot`, `-Encoder`, `-Json`, `-AdvanceRatchet`, `-SelfTest`, `-CompareFacts`, `-Dump` |
| `Source/Tools/OptionHelp/README.md` | Usage, rule table, known blind spots |
| `Source/Tools/OptionHelp/fixtures/md/*.md` and `fixtures/expected/*.txt` | Parser fixtures and their canonical dumps (shared with the VB harness in plan 2) |
| `Source/Tools/OptionHelp/fixtures/chain/` | Resolution fixture: five files and `cases.txt` |
| `Source/Tools/OptionHelp/fixtures/repo/` and `fixtures/repo-clean/` | Fake repositories for coverage rules, ratchet, and facts comparison |
| `Source/Video/VideoEncoderCommandLine.vb` | Parameter identity and value routines, facts export |
| `Source/Encoding/SvtAv1Enc.vb` | `OptionHelpId` override and 16 explicit keys |
| `Docs/OptionHelp/README.md` | Writing rules, template, drafting workflow, validator usage |
| `Docs/OptionHelp/svt-av1.md`, `staxrip.md`, `concepts.md` | Skeleton content files |
| `.gitattributes`, `AGENTS.md` | LF rule for content and fixtures; option-help paragraph |

### Canonical dump format (contract between the two parsers)

One line per element, in file order, then errors sorted by line then code:

```
FILE <name-as-given>
H <Key>=<value>
S <id> <line>
F <Field>=<joined text>
V <value>=<note>
R <url>
ERR <line> <FILE|STANZA> <code>
END
```

`H` lines list header keys in file order. `F`, `V`, `R` lines belong to the most recent `S`. Text is the joined continuation text with single spaces. An alias stanza shows `F Use=<id>`.

---

### Task 1: Module skeleton, grammar parser, canonical dump, self-test runner

**Files:**
- Create: `Source/Tools/OptionHelp/OptionHelp.psm1`
- Create: `Source/Tools/OptionHelp/Check-OptionHelp.ps1`
- Create: `Source/Tools/OptionHelp/fixtures/md/clean.md`
- Create: `Source/Tools/OptionHelp/fixtures/expected/clean.txt`

**Interfaces:**
- Produces: `ConvertFrom-OptionHelpText -Text <string> -Name <string>` returning an object with `Name`, `Encoder`, `Locale`, `Header` (ordered dictionary), `Stanzas` (list of objects with `Id`, `Line`, `Fields` (ordered dictionary), `Values` (list of `@{Value;Note}`), `References` (list), `Status`), `Errors` (list of `@{Line;Level;Code;Message}`); `Read-OptionHelpFile -Path` doing byte-level checks then calling the former; `ConvertTo-OptionHelpDump -File <obj>` returning the canonical dump text; `Invoke-OptionHelpSelfTest -FixturesRoot` returning 0 or 1.

- [ ] **Step 1: Write the clean fixture and its expected dump**

`Source/Tools/OptionHelp/fixtures/md/clean.md` (LF endings, no BOM):

```markdown
# Fake encoder option help

Schema: 1
Encoder: fake
Locale: en
Title: Fake Encoder
Source: Source/Encoding/FakeEnc.vb
Allowed-Missing: 0
Minimum-Reviewed: 2
Reviewed-Complete: false
Verified-Encoder-Version: FakeEnc 1.0
Verified-Encoder-Build: v1.0
Verified-Date: 2026-08-26
Documentation: https://example.invalid/fake/v1.0/Parameters.md

<!-- A comment line is ignored anywhere. -->

## fake.alpha
Label: Alpha
Summary: Controls the first thing. Higher values make the file smaller
  but slower to produce.
Used when: Rate control is Quality.
When to change: Raise it when the file is too large; lower it when the picture looks soft.
Encoder default: 3
Example: Try 2, 3, and 4 on a short clip and compare `--alpha` results.
Values:
- 2: A little sharper and larger.
- 4: Smaller with some loss.
Related: fake.beta, concept.size
References:
- https://example.invalid/fake/v1.0/Parameters.md#alpha
Status: reviewed

## fake.beta
Label: Beta
Summary: Turns the second thing on. See [the guide](https://example.invalid/guide).
When to change: Leave it on unless the encoder warns about it.
Status: reviewed

## fake.gamma
Summary: A draft with only a summary.
Status: draft

## fake.delta
Label: Delta
Use: shared.delta
Status: reviewed
```

`Source/Tools/OptionHelp/fixtures/expected/clean.txt`:

```
FILE clean.md
H Schema=1
H Encoder=fake
H Locale=en
H Title=Fake Encoder
H Source=Source/Encoding/FakeEnc.vb
H Allowed-Missing=0
H Minimum-Reviewed=2
H Reviewed-Complete=false
H Verified-Encoder-Version=FakeEnc 1.0
H Verified-Encoder-Build=v1.0
H Verified-Date=2026-08-26
H Documentation=https://example.invalid/fake/v1.0/Parameters.md
S fake.alpha 18
F Label=Alpha
F Summary=Controls the first thing. Higher values make the file smaller but slower to produce.
F Used when=Rate control is Quality.
F When to change=Raise it when the file is too large; lower it when the picture looks soft.
F Encoder default=3
F Example=Try 2, 3, and 4 on a short clip and compare `--alpha` results.
F Values=
V 2=A little sharper and larger.
V 4=Smaller with some loss.
F Related=fake.beta, concept.size
F References=
R https://example.invalid/fake/v1.0/Parameters.md#alpha
F Status=reviewed
S fake.beta 34
F Label=Beta
F Summary=Turns the second thing on. See [the guide](https://example.invalid/guide).
F When to change=Leave it on unless the encoder warns about it.
F Status=reviewed
S fake.gamma 40
F Summary=A draft with only a summary.
F Status=draft
S fake.delta 44
F Label=Delta
F Use=shared.delta
F Status=reviewed
END
```

Note the line numbers: `fake.alpha` is on line 18 of the fixture, `fake.beta` on 34, `fake.gamma` on 40, `fake.delta` on 44. Count them after saving; if your editor added or removed a blank line, fix the fixture, not the expectation.

- [ ] **Step 2: Write the self-test runner and CLI so the fixture can fail**

`Source/Tools/OptionHelp/Check-OptionHelp.ps1`:

```powershell
#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$Encoder,
    [switch]$Json,
    [switch]$AdvanceRatchet,
    [switch]$SelfTest,
    [string]$CompareFacts,
    [string]$Dump
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'OptionHelp.psm1') -Force

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
}

if ($Dump) {
    $file = Read-OptionHelpFile -Path $Dump
    [Console]::Out.Write((ConvertTo-OptionHelpDump -File $file))
    exit 0
}

if ($SelfTest) {
    exit (Invoke-OptionHelpSelfTest -FixturesRoot (Join-Path $PSScriptRoot 'fixtures'))
}

# Tasks 3 and 4 add the repository check, ratchet, JSON, and facts comparison here.
[Console]::Error.WriteLine('Repository check is not implemented yet.')
exit 1
```

`Source/Tools/OptionHelp/OptionHelp.psm1`, first part:

```powershell
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

Export-ModuleMember -Function Read-OptionHelpFile, ConvertFrom-OptionHelpText, ConvertTo-OptionHelpDump, Invoke-OptionHelpSelfTest
```

- [ ] **Step 3: Run the self-test and confirm it passes on the clean fixture**

Run: `pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -SelfTest`
Expected: `self-test: 1 dump cases, 0 failures` on stderr, exit code 0. If the first difference is a stanza line number, recount the fixture's lines.

- [ ] **Step 4: Prove the runner detects a mismatch**

Temporarily change `F Label=Alpha` to `F Label=Alpha2` in `clean.txt`, run the self-test, expect `FAIL clean.md line 14` and exit code 1, then restore the line and run again to see exit code 0.

- [ ] **Step 5: Commit**

```bash
git add Source/Tools/OptionHelp
git commit -m "Tools: add the option-help grammar parser and self-test runner" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Parser validation rules (E1 header, E2 limits, E3 structure, E8 duplicates, E13 markup) with one fixture per rule

**Files:**
- Modify: `Source/Tools/OptionHelp/OptionHelp.psm1` (add `Test-OhInline`, `ConvertTo-OhPlainText`, `Complete-OhValidation`; call the latter at the end of `ConvertFrom-OptionHelpText`)
- Create: fixtures `md/e1-header.md`, `md/e1-name.md`, `md/e2-limits.md`, `md/e3-fields.md`, `md/e8-duplicate.md`, `md/e13-markup.md`, `md/unicode.md`, `md/shadow-variant.md` and their `expected/*.txt`

**Interfaces:**
- Produces: `Test-OhInline -Text` returning `$null` or a message; `ConvertTo-OhPlainText -Text` (backticks removed, links replaced by their text) used by the report and by plan 2's expectations; `ConvertFrom-OptionHelpText` now emits E1, E2, E3, E8, E13 per spec 6.3.

- [ ] **Step 1: Write the fixtures and expectations**

`md/e1-header.md` (missing Locale and Title, wrong Schema, unknown key, Inherits on a shared file, missing counters):

```markdown
Schema: 2
Encoder: e1-header
Source: Source/Encoding/E1.vb
Colour: blue
Inherits: base

## e1-header.alpha
Summary: Fine.
When to change: Fine.
Status: reviewed
```

`expected/e1-header.txt`:

```
FILE e1-header.md
H Schema=2
H Encoder=e1-header
H Source=Source/Encoding/E1.vb
H Inherits=base
S e1-header.alpha 7
F Summary=Fine.
F When to change=Fine.
F Status=reviewed
ERR 1 FILE E1
ERR 1 FILE E1
ERR 1 FILE E1
ERR 1 FILE E1
ERR 1 FILE E1
ERR 1 FILE E1
ERR 1 FILE E1
ERR 4 FILE E1
END
```

The seven line-1 errors are, in the order the code below produces them: unsupported Schema, missing Locale, missing Title, missing Allowed-Missing, missing Minimum-Reviewed, missing Reviewed-Complete, and missing verification headers (one error naming all four missing keys). `Inherits: base` is accepted by the parser; chains are resolved in Task 3. Line 4 is the unknown key `Colour`. If your count differs, list the errors with `-Dump` and reconcile against `Complete-OhValidation` rather than editing the expectation to match.

`md/e1-name.md` (file name `e1-name` but header says another encoder and locale):

```markdown
Schema: 1
Encoder: other
Locale: de
Title: Mismatch
Source: Source/Encoding/E1.vb
Allowed-Missing: 0
Minimum-Reviewed: 0
Reviewed-Complete: false
```

`expected/e1-name.txt`:

```
FILE e1-name.md
H Schema=1
H Encoder=other
H Locale=de
H Title=Mismatch
H Source=Source/Encoding/E1.vb
H Allowed-Missing=0
H Minimum-Reviewed=0
H Reviewed-Complete=false
ERR 1 FILE E1
ERR 1 FILE E1
END
```

`md/e2-limits.md`:

```markdown
Schema: 1
Encoder: e2-limits
Locale: en
Title: Limits
Source: Source/Encoding/E2.vb
Allowed-Missing: 0
Minimum-Reviewed: 0
Reviewed-Complete: false

## e2-limits.nosummary
Status: reviewed

## e2-limits.noperiod
Summary: Ends without a period
Status: draft

## e2-limits.long
Summary: This summary is deliberately far longer than the two hundred character limit that the grammar allows for a summary, so that the validator has to reject it with the length rule instead of accepting it silently as fine.
Status: draft

## e2-limits.reviewed-without-when
Summary: Fine.
Status: reviewed

## e2-limits.longnote
Summary: Fine.
When to change: Fine.
Values:
- 1: This note is deliberately longer than one hundred and twenty characters so that the note length rule fires on it, as the grammar says it must.
Status: reviewed
```

`expected/e2-limits.txt`:

```
FILE e2-limits.md
H Schema=1
H Encoder=e2-limits
H Locale=en
H Title=Limits
H Source=Source/Encoding/E2.vb
H Allowed-Missing=0
H Minimum-Reviewed=0
H Reviewed-Complete=false
S e2-limits.nosummary 10
F Status=reviewed
S e2-limits.noperiod 13
F Summary=Ends without a period
F Status=draft
S e2-limits.long 17
F Summary=This summary is deliberately far longer than the two hundred character limit that the grammar allows for a summary, so that the validator has to reject it with the length rule instead of accepting it silently as fine.
F Status=draft
S e2-limits.reviewed-without-when 21
F Summary=Fine.
F Status=reviewed
S e2-limits.longnote 25
F Summary=Fine.
F When to change=Fine.
F Values=
V 1=This note is deliberately longer than one hundred and twenty characters so that the note length rule fires on it, as the grammar says it must.
F Status=reviewed
ERR 1 FILE E1
ERR 10 STANZA E2
ERR 10 STANZA E2
ERR 13 STANZA E2
ERR 17 STANZA E2
ERR 21 STANZA E2
ERR 29 STANZA E2
END
```

Line 1 E1 is the missing verification headers, because reviewed stanzas exist. Line 10 has two E2 errors: missing Summary and missing When to change on a reviewed stanza.

`md/e3-fields.md`:

```markdown
Schema: 1
Encoder: e3-fields
Locale: en
Title: Fields
Source: Source/Encoding/E3.vb
Allowed-Missing: 0
Minimum-Reviewed: 0
Reviewed-Complete: false

## e3-fields.alpha
Status: draft
Summary: Out of order.
Summary: Duplicate.
Tip: Unknown field.
- 1: bullet outside values
Values: text on the values line
Stray text.

## not-an-id
Summary: Fine.
Status: draft

## e3-fields.alias
Use: shared.thing
Summary: Not allowed with Use.
Status: draft

## e3-fields.nostatus
Summary: Fine.
```

`expected/e3-fields.txt`:

```
FILE e3-fields.md
H Schema=1
H Encoder=e3-fields
H Locale=en
H Title=Fields
H Source=Source/Encoding/E3.vb
H Allowed-Missing=0
H Minimum-Reviewed=0
H Reviewed-Complete=false
S e3-fields.alpha 10
F Status=draft
F Summary=Out of order.
F Values=
S not-an-id 19
F Summary=Fine.
F Status=draft
S e3-fields.alias 23
F Use=shared.thing
F Summary=Not allowed with Use.
F Status=draft
S e3-fields.nostatus 28
F Summary=Fine.
ERR 12 STANZA E3
ERR 13 STANZA E3
ERR 14 STANZA E3
ERR 15 STANZA E3
ERR 16 STANZA E3
ERR 17 STANZA E3
ERR 19 STANZA E1
ERR 23 STANZA E3
ERR 28 STANZA E3
END
```

`md/e8-duplicate.md`:

```markdown
Schema: 1
Encoder: e8-duplicate
Locale: en
Title: Duplicate
Source: Source/Encoding/E8.vb
Allowed-Missing: 0
Minimum-Reviewed: 0
Reviewed-Complete: false

## e8-duplicate.alpha
Summary: First.
Status: draft

## e8-duplicate.alpha
Summary: Second.
Status: draft
```

`expected/e8-duplicate.txt`:

```
FILE e8-duplicate.md
H Schema=1
H Encoder=e8-duplicate
H Locale=en
H Title=Duplicate
H Source=Source/Encoding/E8.vb
H Allowed-Missing=0
H Minimum-Reviewed=0
H Reviewed-Complete=false
S e8-duplicate.alpha 10
F Summary=First.
F Status=draft
S e8-duplicate.alpha 14
F Summary=Second.
F Status=draft
ERR 14 FILE E8
END
```

`md/e13-markup.md`:

```markdown
Schema: 1
Encoder: e13-markup
Locale: en
Title: Markup
Source: Source/Encoding/E13.vb
Allowed-Missing: 0
Minimum-Reviewed: 0
Reviewed-Complete: false

## e13-markup.backtick
Summary: An unmatched `backtick here.
Status: draft

## e13-markup.badlink
Summary: A [broken link](javascript:alert(1)) and a [half link.
Status: draft

## e13-markup.badref
Summary: Fine.
References:
- file:///C:/secret.txt
- //example.invalid/protocol-relative
Status: draft

## e13-markup.html
Summary: Angle brackets <b>are</b> plain text and allowed.
Status: draft
```

`expected/e13-markup.txt`:

```
FILE e13-markup.md
H Schema=1
H Encoder=e13-markup
H Locale=en
H Title=Markup
H Source=Source/Encoding/E13.vb
H Allowed-Missing=0
H Minimum-Reviewed=0
H Reviewed-Complete=false
S e13-markup.backtick 10
F Summary=An unmatched `backtick here.
F Status=draft
S e13-markup.badlink 14
F Summary=A [broken link](javascript:alert(1)) and a [half link.
F Status=draft
S e13-markup.badref 18
F Summary=Fine.
F References=
R file:///C:/secret.txt
R //example.invalid/protocol-relative
F Status=draft
S e13-markup.html 25
F Summary=Angle brackets <b>are</b> plain text and allowed.
F Status=draft
ERR 11 STANZA E13
ERR 15 STANZA E13
ERR 21 STANZA E13
ERR 22 STANZA E13
END
```

`md/unicode.md` (Unicode is allowed; save as UTF-8 without BOM):

```markdown
Schema: 1
Encoder: unicode
Locale: de
Title: Umlaute
Source: Source/Encoding/U.vb
Allowed-Missing: 0
Minimum-Reviewed: 0
Reviewed-Complete: false

## unicode.alpha
Summary: Größere Werte machen die Datei kleiner.
Status: draft
```

`expected/unicode.txt`:

```
FILE unicode.md
H Schema=1
H Encoder=unicode
H Locale=de
H Title=Umlaute
H Source=Source/Encoding/U.vb
H Allowed-Missing=0
H Minimum-Reviewed=0
H Reviewed-Complete=false
S unicode.alpha 10
F Summary=Größere Werte machen die Datei kleiner.
F Status=draft
END
```

`md/shadow-variant.md` is a valid variant file used again by the chain fixture; it parses clean:

```markdown
Schema: 1
Encoder: shadow-variant
Locale: en
Title: Shadow Variant
Source: Source/Encoding/ShadowVariant.vb
Inherits: shadow-base
Allowed-Missing: 0
Minimum-Reviewed: 0
Reviewed-Complete: false

## shadow-base.alpha
Summary: The variant author thinks the base text is wrong here.
Status: draft
```

`expected/shadow-variant.txt`:

```
FILE shadow-variant.md
H Schema=1
H Encoder=shadow-variant
H Locale=en
H Title=Shadow Variant
H Source=Source/Encoding/ShadowVariant.vb
H Inherits=shadow-base
H Allowed-Missing=0
H Minimum-Reviewed=0
H Reviewed-Complete=false
S shadow-base.alpha 11
F Summary=The variant author thinks the base text is wrong here.
F Status=draft
END
```

- [ ] **Step 2: Run the self-test and confirm the new fixtures fail**

Run: `pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -SelfTest`
Expected: failures for `e1-header`, `e1-name`, `e2-limits`, `e3-fields`, `e8-duplicate`, `e13-markup` (no ERR lines yet); `clean`, `unicode`, `shadow-variant` pass. Exit code 1.

- [ ] **Step 3: Add the validation functions**

Add to `OptionHelp.psm1` before `Export-ModuleMember`, and add `Test-OhInline, ConvertTo-OhPlainText` to the export list:

```powershell
function Test-OhInline {
    param([AllowEmptyString()][string]$Text)
    $ticks = ($Text.ToCharArray() | Where-Object { $_ -eq '`' }).Count
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
            $missing = @('Verified-Encoder-Version', 'Verified-Encoder-Build', 'Verified-Date', 'Documentation') | Where-Object { -not $h.Contains($_) }
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
```

Then add this as the last statement of `ConvertFrom-OptionHelpText` before `return $file`:

```powershell
    Complete-OhValidation -File $file
```

The E13 line for an inline-markup error is the stanza line plus the field's position, which puts it on the field's own line for stanzas whose fields are on consecutive lines, as every fixture in this plan has.

- [ ] **Step 4: Run the self-test until every fixture passes**

Run: `pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -SelfTest`
Expected: `self-test: 9 dump cases, 0 failures`, exit code 0. When a fixture fails, print `-Dump <fixture>` and decide whether the code or the expectation is wrong by reading spec 6.3; do not edit an expectation to silence a rule the spec requires.

- [ ] **Step 5: Commit**

```bash
git add Source/Tools/OptionHelp
git commit -m "Tools: validate option-help headers, fields, limits, and markup" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: VB parameter extraction, chain resolution, and their fixtures

**Files:**
- Modify: `Source/Tools/OptionHelp/OptionHelp.psm1` (add `Get-VbParameters`, `Get-VbOptionHelpId`, `Get-OhChain`, `Resolve-OhId`, chain self-test)
- Create: `Source/Tools/OptionHelp/fixtures/vb/FakeEnc.vb`, `fixtures/expected/vb-FakeEnc.txt`
- Create: `Source/Tools/OptionHelp/fixtures/chain/shadow-base.md`, `chain/shadow-variant.md`, `chain/staxrip.md`, `chain/concepts.md`, `chain/shared.md`, `chain/cases.txt`

**Interfaces:**
- Produces: `Get-VbParameters -Path -EncoderId` returning a list of `@{Name; Type; Line; Identity; Excluded; Switches (string[] sorted ordinal); Caption; EmittedValues (string[]); Errors (list)}`; `Get-VbOptionHelpId -Path` returning the id string or `$null`; `Get-OhChain -Files <hashtable name->file> -EncoderId` returning the ordered list of files or throwing on a cycle or unknown base; `Resolve-OhId -Chain -Files -Id` returning `@{Outcome ('reviewed'|'draft'|'none'|'alias'); File; Stanza}`.

- [ ] **Step 1: Write the VB fixture and its expected extraction dump**

`Source/Tools/OptionHelp/fixtures/vb/FakeEnc.vb`:

```vb
Imports StaxRip.VideoEncoderCommandLine

Public Class FakeEncParams
    Inherits CommandLineParams

    Public Overrides ReadOnly Property OptionHelpId As String
        Get
            Return "fake"
        End Get
    End Property

    Property Alpha As New NumParam With {
        .Switch = "--alpha",
        .Text = "Alpha",
        .Config = {0, 10, 1},
        .Init = 3}

    Property Beta As New OptionParam With {
        .Switch = "--beta",
        .Text = "Beta",
        .Options = {"0: Off (default)", "1: On"},
        .Values = {"0", "1"},
        .Init = 0}

    Property Gamma As New OptionParam With {
        .Switch = "--gamma",
        .Text = "Gamma",
        .IntegerValue = True,
        .Options = {"0: VQ", "1: PSNR (default)", "2: SSIM"},
        .Init = 1}

    Property Delta As New OptionParam With {
        .Switch = "--delta",
        .Text = "Delta",
        .Options = {"Ultra Fast", "Very Slow", "0: ""quoted"" text"},
        .Init = 0}

    Property Epsilon As New OptionParam With {
        .Switches = {"--pass", "--passes", "--stats"},
        .Text = "Passes",
        .Options = {"1-pass", "2-pass"},
        .Values = {"1", "2"}}

    Property Zeta As New NumParam With {
        .HelpSwitch = "--zeta",
        .Text = "Zeta",
        .ArgsFunc = Function() "--zeta 1"}

    Property Eta As New BoolParam With {
        .Switch = "--eta",
        .NoSwitch = "--no-eta",
        .Text = "Eta",
        .Init = True}

    Property Chunks As New NumParam With {
        .OptionHelpKey = "staxrip.chunks",
        .Text = "Chunks",
        .Config = {1, 128},
        .Init = 1}

    Property Hidden As New StringParam With {
        .OptionHelpKey = "none",
        .Switch = "--hidden",
        .Text = "Hidden"}

    Property NoKey As New StringParam With {
        .Text = "Custom"}

    'Property Commented As New NumParam With {
    '    .Switch = "--commented",
    '    .Text = "Commented"}

    Overrides ReadOnly Property Items As List(Of CommandLineParam)
        Get
            If ItemsValue Is Nothing Then
                ItemsValue = New List(Of CommandLineParam)
                Add("Basic", Alpha, Beta, Gamma, Delta, Epsilon, Zeta, Eta,
                    New NumParam With {.Switch = "--inline", .Text = "Inline", .Config = {0, 5}},
                    New LineParam(),
                    Chunks, Hidden, NoKey)
                Add("Weird", New WeirdParam With {.Switch = "--weird", .Text = "Weird"})
                Dim built As New NumParam
                Add("Other", built)
            End If
            Return ItemsValue
        End Get
    End Property
End Class
```

`Source/Tools/OptionHelp/fixtures/expected/vb-FakeEnc.txt` (format: `P <line> <Name|-> <Type> id=<identity|-> excluded=<true|false> caption=<caption> switches=<comma list> values=<comma list>`; then `ERR <line> <code>`):

```
OPTIONHELPID fake
P 12 Alpha NumParam id=fake.alpha excluded=false caption=Alpha switches=--alpha values=
P 18 Beta OptionParam id=fake.beta excluded=false caption=Beta switches=--beta values=0,1
P 25 Gamma OptionParam id=fake.gamma excluded=false caption=Gamma switches=--gamma values=0,1,2
P 32 Delta OptionParam id=fake.delta excluded=false caption=Delta switches=--delta values=ultrafast,veryslow,0:"quoted"text
P 38 Epsilon OptionParam id=fake.pass excluded=false caption=Passes switches=--pass,--passes,--stats values=1,2
P 44 Zeta NumParam id=fake.zeta excluded=false caption=Zeta switches=--zeta values=
P 49 Eta BoolParam id=fake.eta excluded=false caption=Eta switches=--eta,--no-eta values=
P 55 Chunks NumParam id=staxrip.chunks excluded=false caption=Chunks switches= values=
P 61 Hidden StringParam id=- excluded=true caption=Hidden switches=--hidden values=
P 66 NoKey StringParam id=- excluded=false caption=Custom switches= values=
P 78 - NumParam id=fake.inline excluded=false caption=Inline switches=--inline values=
ERR 66 E10
ERR 81 E11
ERR 82 E11
```

Line 81 is `New WeirdParam` (unknown type); line 82 is `New NumParam` without `With {`. Line 78 is the inline declaration inside `Add`. Switches are listed in the order Switch, NoSwitch, HelpSwitch, Switches (the runtime `GetSwitches` order), then sorted ordinally for display in plan 2; the dump keeps declaration order so the fixture stays readable.

- [ ] **Step 2: Add the extractor**

Add to `OptionHelp.psm1` and export `Get-VbParameters, Get-VbOptionHelpId, ConvertTo-OhVbDump`:

```powershell
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
    param([string]$Init, [string]$Member)
    $m = [regex]::Match($Init, '\.' + [regex]::Escape($Member) + '\s*=\s*\{')
    if (-not $m.Success) { return $null }
    return (Read-OhVbStrings -Text $Init -Start ($m.Index + $m.Length - 1)).Items
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
```

Add to `Invoke-OptionHelpSelfTest`, before the summary line:

```powershell
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
```

- [ ] **Step 3: Run the self-test; fix line numbers, not rules**

Run: `pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -SelfTest`
Expected: `self-test: 10 dump cases, 0 failures`. If a `P` line number differs, count lines in `FakeEnc.vb`; the numbers in the expectation assume the file exactly as printed above.

- [ ] **Step 4: Write the chain fixture**

`fixtures/chain/shadow-base.md`:

```markdown
Schema: 1
Encoder: shadow-base
Locale: en
Title: Shadow Base
Source: Source/Encoding/ShadowBase.vb
Allowed-Missing: 0
Minimum-Reviewed: 0
Reviewed-Complete: false
Verified-Encoder-Version: 1
Verified-Encoder-Build: 1
Verified-Date: 2026-08-26
Documentation: https://example.invalid/base

## shadow-base.alpha
Summary: Base text for alpha.
When to change: Never.
Status: reviewed

## shadow-base.beta
Summary: Base text for beta.
When to change: Never.
Status: reviewed

## shadow-base.gamma
Summary: Base draft for gamma.
Status: draft

## shadow-base.delta
Use: shared.delta
Status: reviewed

## shadow-base.epsilon
Use: shared.epsilon-draft
Status: reviewed
```

`fixtures/chain/shadow-variant.md`: copy `fixtures/md/shadow-variant.md` from Task 2 exactly.

`fixtures/chain/staxrip.md`:

```markdown
Schema: 1
Encoder: staxrip
Locale: en
Title: StaxRip

## staxrip.chunks
Summary: Splits the encode into pieces.
When to change: Rarely.
Status: reviewed
```

`fixtures/chain/concepts.md`:

```markdown
Schema: 1
Encoder: concepts
Locale: en
Title: Glossary

## concept.size
Summary: File size is how many bytes the result takes.
When to change: Not applicable.
Status: reviewed
```

`fixtures/chain/shared.md`:

```markdown
Schema: 1
Encoder: shared
Locale: en
Title: Shared

## shared.delta
Summary: Shared text for delta.
When to change: Shared advice.
Status: reviewed

## shared.epsilon-draft
Summary: Not ready.
Status: draft
```

`fixtures/chain/cases.txt` (`<encoder> <id> => <outcome>[:<file>]`; the file is the one whose stanza decided the outcome):

```
shadow-variant shadow-base.alpha => draft:shadow-variant.md
shadow-variant shadow-base.beta => reviewed:shadow-base.md
shadow-variant shadow-base.gamma => draft:shadow-base.md
shadow-variant shadow-base.delta => alias:shared.md
shadow-variant shadow-base.epsilon => draft:shadow-base.md
shadow-variant staxrip.chunks => reviewed:staxrip.md
shadow-variant concept.size => none
shadow-base shadow-base.alpha => reviewed:shadow-base.md
shadow-base shadow-base.zeta => none
```

`concept.size` resolves to `none` for a parameter lookup because `concepts` is not in the chain; `Related` lookups use a different function in plan 2. An alias whose target is a draft (`epsilon`) resolves as `draft` because both sides must be reviewed.

- [ ] **Step 5: Add chain resolution and its self-test**

Add to `OptionHelp.psm1` and export `Get-OhChain, Resolve-OhId, Read-OhDirectory`:

```powershell
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
    if ($Files.ContainsKey('staxrip')) { $chain.Add($Files['staxrip']) }
    return $chain
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
```

Add to `Invoke-OptionHelpSelfTest`, before the summary line:

```powershell
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
```

- [ ] **Step 6: Run the self-test**

Run: `pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -SelfTest`
Expected: `self-test: 19 dump cases, 0 failures` (9 md, 1 vb, 9 chain cases).

- [ ] **Step 7: Commit**

```bash
git add Source/Tools/OptionHelp
git commit -m "Tools: extract VB parameters and resolve option-help chains" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Repository check, counters, report, `-Json`, `-AdvanceRatchet`, `-CompareFacts`, fake-repository fixtures

**Files:**
- Modify: `Source/Tools/OptionHelp/OptionHelp.psm1`, `Source/Tools/OptionHelp/Check-OptionHelp.ps1`
- Create: `Source/Tools/OptionHelp/fixtures/repo/...`, `fixtures/repo-clean/...`, `fixtures/facts/fake-export.json`, `fixtures/expected/report-repo.txt`, `fixtures/expected/report-repo-clean.txt`, `fixtures/expected/ratchet-repo-clean.txt`, `fixtures/expected/compare-facts.txt`
- Create: `Source/Tools/OptionHelp/README.md`

**Interfaces:**
- Produces: `Test-OptionHelpRepository -RepoRoot [-Encoder]` returning a report object `@{Encoders (list of @{Encoder; Total; Excluded; Reviewed; Draft; Missing; AllowedMissing; MinimumReviewed; ReviewedComplete; Pass; MissingIds (list of @{Id; Caption})}); Errors (list of @{File; Line; Code; Message}); Warnings (same shape); Pass}`; `Format-OptionHelpReport -Report` (deterministic text); `Update-OptionHelpRatchet -RepoRoot -Report`; `Compare-OptionHelpFacts -RepoRoot -FactsPath` returning a list of E11 errors; exit codes per spec 6.1.
- Consumes: everything from Tasks 1 to 3.

- [ ] **Step 1: Write the fake repositories**

`fixtures/repo/Source/Encoding/FakeEnc.vb`: copy `fixtures/vb/FakeEnc.vb` exactly.

`fixtures/repo/Source/Encoding/OtherEnc.vb` (no help file, so W1):

```vb
Public Class OtherEncParams
    Inherits CommandLineParams

    Property Alpha As New NumParam With {
        .Switch = "--alpha",
        .Text = "Alpha"}
End Class
```

`fixtures/repo/Source/Encoding/BadIdEnc.vb` (overrides the wrong id, so E9):

```vb
Public Class BadIdEncParams
    Inherits CommandLineParams

    Public Overrides ReadOnly Property OptionHelpId As String
        Get
            Return "wrong"
        End Get
    End Property

    Property Alpha As New NumParam With {
        .Switch = "--alpha",
        .Text = "Alpha"}
End Class
```

`fixtures/repo/Source/StaxRip.vbproj` (only `fake.md` is embedded; `badid.md` is not, so E12; `ghost.md` is embedded but has no file, so E12):

```xml
<Project>
  <ItemGroup>
    <EmbeddedResource Include="..\Docs\OptionHelp\fake.md">
      <Link>OptionHelp\fake.md</Link>
    </EmbeddedResource>
    <EmbeddedResource Include="..\Docs\OptionHelp\staxrip.md">
      <Link>OptionHelp\staxrip.md</Link>
    </EmbeddedResource>
    <EmbeddedResource Include="..\Docs\OptionHelp\concepts.md">
      <Link>OptionHelp\concepts.md</Link>
    </EmbeddedResource>
    <EmbeddedResource Include="..\Docs\OptionHelp\ghost.md">
      <Link>OptionHelp\ghost.md</Link>
    </EmbeddedResource>
  </ItemGroup>
</Project>
```

`fixtures/repo/Docs/OptionHelp/fake.md`:

```markdown
Schema: 1
Encoder: fake
Locale: en
Title: Fake Encoder
Source: Source/Encoding/FakeEnc.vb
Allowed-Missing: 2
Minimum-Reviewed: 3
Reviewed-Complete: false
Verified-Encoder-Version: FakeEnc 1.0
Verified-Encoder-Build: v1.0
Verified-Date: 2026-08-26
Documentation: https://example.invalid/fake/v1.0/Parameters.md

## fake.alpha
Label: Alfa
Summary: Alpha text.
When to change: Rarely.
Values:
- 3: Values on a numeric parameter are an error.
Related: fake.beta, concept.size, fake.nothing
Status: reviewed

## fake.beta
Summary: Beta text.
When to change: Rarely.
Values:
- 1: Turns it on.
- 3: Not a value beta has.
Status: reviewed

## fake.gamma
Summary: Gamma text.
Status: draft

## fake.orphan
Summary: No parameter has this id.
Status: draft

## fake.delta
Use: shared.missing
Status: reviewed
```

`fixtures/repo/Docs/OptionHelp/badid.md`:

```markdown
Schema: 1
Encoder: badid
Locale: en
Title: Bad Id
Source: Source/Encoding/BadIdEnc.vb
Allowed-Missing: 1
Minimum-Reviewed: 0
Reviewed-Complete: false
```

`fixtures/repo/Docs/OptionHelp/staxrip.md`: copy `fixtures/chain/staxrip.md`. `fixtures/repo/Docs/OptionHelp/concepts.md`: copy `fixtures/chain/concepts.md`.

Expected report `fixtures/expected/report-repo.txt`:

```
ENCODER badid total=1 excluded=0 reviewed=0 draft=0 missing=1 allowed-missing=1 minimum-reviewed=0 reviewed-complete=false result=PASS
MISSING badid.alpha Alpha
ENCODER fake total=10 excluded=1 reviewed=3 draft=2 missing=4 allowed-missing=2 minimum-reviewed=3 reviewed-complete=false result=FAIL
MISSING fake.pass Passes
MISSING fake.zeta Zeta
MISSING fake.eta Eta
MISSING fake.inline Inline
E10 Source/Encoding/FakeEnc.vb:66 Parameter 'NoKey' (Custom) has no identity; set OptionHelpKey
E11 Source/Encoding/FakeEnc.vb:81 Unrecognized parameter type 'WeirdParam'
E11 Source/Encoding/FakeEnc.vb:82 Parameter of type 'NumParam' is not declared with 'With {'
E12 Docs/OptionHelp/badid.md:1 No EmbeddedResource entry in Source/StaxRip.vbproj
E12 Source/StaxRip.vbproj:1 EmbeddedResource 'ghost.md' has no file
E4 Docs/OptionHelp/fake.md:14 Values on non-option parameter fake.alpha
E4 Docs/OptionHelp/fake.md:28 Value '3' is not an emitted value of fake.beta
E5 Docs/OptionHelp/fake.md:35 Orphan stanza 'fake.orphan'
E6 Docs/OptionHelp/fake.md:20 Related target 'fake.nothing' does not exist
E6 Docs/OptionHelp/fake.md:40 Use target 'shared.missing' does not exist or is not reviewed
E7 Docs/OptionHelp/fake.md:1 missing 4 exceeds Allowed-Missing 2
E9 Source/Encoding/BadIdEnc.vb:1 OptionHelpId is 'wrong', expected 'badid'
W1 Source/Encoding/OtherEnc.vb no help file
W3 fake Hidden excluded
RESULT FAIL
```

Notes on the numbers: `fake` has 11 extracted parameters (`P` lines); `Hidden` is excluded, so `total=10`; `NoKey` has no identity (E10) and is neither missing nor covered. `fake.alpha` and `fake.beta` are reviewed and `staxrip.chunks` resolves through the chain's `staxrip.md`, so `reviewed=3`; `fake.gamma` is a draft and `fake.delta` is an alias whose target does not exist, which resolves as a draft and also reports E6, so `draft=2`; the four `MISSING` lines follow declaration order. `reviewed=3` meets `Minimum-Reviewed: 3`, so only one E7 fires. `fake.alpha` is a `NumParam`, so its `Values` block is the non-option E4 at the stanza line; `fake.beta` emits `0` and `1`, so its `- 3:` bullet is the other E4. Errors sort by code as text, which is why `E10` to `E12` precede `E4`; within a code they sort by file, line, and message. Line numbers refer to `fake.md` as printed above: `## fake.alpha` is line 14, its `Related` is line 20, the beta `- 3:` bullet is line 28, `## fake.orphan` is line 35, and `Use:` under `fake.delta` is line 40. The `Label: Alfa` line deliberately differs from the caption `Alpha`; plan 3 adds the W2 warning for it, which is why the expectation has no W2 line yet.

`fixtures/repo-clean/` is the same layout with one encoder that passes:

`fixtures/repo-clean/Source/Encoding/CleanEnc.vb`:

```vb
Public Class CleanEncParams
    Inherits CommandLineParams

    Public Overrides ReadOnly Property OptionHelpId As String
        Get
            Return "clean"
        End Get
    End Property

    Property Alpha As New NumParam With {
        .Switch = "--alpha",
        .Text = "Alpha"}

    Property Beta As New OptionParam With {
        .Switch = "--beta",
        .Text = "Beta",
        .IntegerValue = True,
        .Options = {"0: Off", "1: On"}}
End Class
```

`fixtures/repo-clean/Source/StaxRip.vbproj`:

```xml
<Project>
  <ItemGroup>
    <EmbeddedResource Include="..\Docs\OptionHelp\clean.md">
      <Link>OptionHelp\clean.md</Link>
    </EmbeddedResource>
  </ItemGroup>
</Project>
```

`fixtures/repo-clean/Docs/OptionHelp/clean.md`:

```markdown
Schema: 1
Encoder: clean
Locale: en
Title: Clean
Source: Source/Encoding/CleanEnc.vb
Allowed-Missing: 2
Minimum-Reviewed: 0
Reviewed-Complete: false
Verified-Encoder-Version: 1
Verified-Encoder-Build: 1
Verified-Date: 2026-08-26
Documentation: https://example.invalid/clean

## clean.alpha
Summary: Alpha.
When to change: Rarely.
Status: reviewed

## clean.beta
Summary: Beta.
Status: draft
```

`fixtures/expected/report-repo-clean.txt`:

```
ENCODER clean total=2 excluded=0 reviewed=1 draft=1 missing=0 allowed-missing=2 minimum-reviewed=0 reviewed-complete=false result=PASS
RESULT PASS
```

`fixtures/expected/ratchet-repo-clean.txt` is the header of `clean.md` after `-AdvanceRatchet` (only the two counter lines change):

```
Allowed-Missing: 0
Minimum-Reviewed: 1
```

`fixtures/facts/fake-export.json` (what the application would export for `fake`, with one deliberate difference: `fake.beta` emits `0,2`):

```json
{
  "schemaVersion": 1,
  "encoders": [
    {
      "encoder": "fake",
      "parameters": [
        { "identity": "fake.alpha", "excluded": false, "caption": "Alpha", "switches": ["--alpha"], "values": [] },
        { "identity": "fake.beta", "excluded": false, "caption": "Beta", "switches": ["--beta"], "values": ["0", "2"] }
      ]
    }
  ]
}
```

`fixtures/expected/compare-facts.txt`:

```
E11 fake.beta values differ: application '0,2' extractor '0,1'
E11 fake.gamma missing from the application export
E11 fake.delta missing from the application export
E11 fake.pass missing from the application export
E11 fake.zeta missing from the application export
E11 fake.eta missing from the application export
E11 staxrip.chunks missing from the application export
E11 fake.inline missing from the application export
```

- [ ] **Step 2: Add the repository check, report, ratchet, and comparison**

Add to `OptionHelp.psm1` and export `Test-OptionHelpRepository, Format-OptionHelpReport, Update-OptionHelpRatchet, Compare-OptionHelpFacts`:

```powershell
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

    foreach ($f in $files.Values) {
        foreach ($e in $f.Errors) { $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = $e.Line; Code = $e.Code; Message = $e.Message }) }
        if ($resources -notcontains $f.Name) { $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = 1; Code = 'E12'; Message = 'No EmbeddedResource entry in Source/StaxRip.vbproj' }) }
    }
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
        $covered = @{}
        foreach ($p in $params) {
            if ($p.Excluded) { $excluded++; $warnings.Add([pscustomobject]@{ File = $f.Encoder; Line = 0; Code = 'W3'; Message = "$($p.Name) excluded" }); continue }
            if (-not $p.Identity) { continue }
            $r = Resolve-OhId -Chain $chain -Files $files -Id $p.Identity
            switch ($r.Outcome) {
                'reviewed' { $reviewed++; $covered[$p.Identity] = $true }
                'alias' { $reviewed++; $covered[$p.Identity] = $true }
                'draft' { $draft++; $covered[$p.Identity] = $true }
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
        $allIds = [System.Collections.Generic.List[string]]::new($identities)
        foreach ($i in $inheritors) { if ($allParams.ContainsKey($i)) { foreach ($p in $allParams[$i]) { if ($p.Identity) { $allIds.Add($p.Identity) } } } }
        foreach ($s in $f.Stanzas) {
            if ($allIds -notcontains $s.Id) { $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = $s.Line; Code = 'E5'; Message = "Orphan stanza '$($s.Id)'" }) }
            if ($s.Fields.Contains('Related')) {
                foreach ($rel in ($s.Fields['Related'] -split ',\s*')) {
                    $target = $null
                    foreach ($other in $files.Values) { $t = Find-OhStanza -File $other -Id $rel; if ($t) { $target = $t; break } }
                    if (-not $target) { $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = ($s.Line + [array]::IndexOf(@($s.Fields.Keys), 'Related') + 1 + $s.Values.Count); Code = 'E6'; Message = "Related target '$rel' does not exist" }) }
                }
            }
            if ($s.Fields.Contains('Use')) {
                $r2 = Resolve-OhId -Chain @($f) -Files $files -Id $s.Id
                if ($r2.Outcome -ne 'alias') { $errors.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($f.Name)"; Line = ($s.Line + 1); Code = 'E6'; Message = "Use target '$($s.Fields['Use'])' does not exist or is not reviewed" }) }
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
    param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)]$Report)
    if (-not $Report.Pass) { throw 'Refusing to advance the ratchet after a failed validation' }
    foreach ($e in $Report.Encoders) {
        $path = Join-Path $RepoRoot "Docs\OptionHelp\$($e.Encoder).md"
        $text = [System.IO.File]::ReadAllText($path)
        $newAllowed = [Math]::Min($e.AllowedMissing, $e.Missing)
        $newMinimum = [Math]::Max($e.MinimumReviewed, $e.Reviewed)
        $updated = [regex]::Replace($text, '(?m)^Allowed-Missing: \d+$', "Allowed-Missing: $newAllowed")
        $updated = [regex]::Replace($updated, '(?m)^Minimum-Reviewed: \d+$', "Minimum-Reviewed: $newMinimum")
        if ($updated -ne $text) {
            $tmp = "$path.tmp"
            [System.IO.File]::WriteAllText($tmp, $updated, [System.Text.UTF8Encoding]::new($false))
            [System.IO.File]::Move($tmp, $path, $true)
        }
    }
}

function Compare-OptionHelpFacts {
    param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][string]$FactsPath)
    $facts = Get-Content -Raw $FactsPath | ConvertFrom-Json
    $files = Read-OhDirectory -Directory (Join-Path $RepoRoot 'Docs\OptionHelp')
    $out = [System.Collections.Generic.List[string]]::new()
    foreach ($enc in $facts.encoders) {
        if (-not $files.ContainsKey($enc.encoder)) { $out.Add("E11 $($enc.encoder) has no help file"); continue }
        $f = $files[$enc.encoder]
        $extraction = Get-VbParameters -Path (Join-Path $RepoRoot $f.Header['Source']) -EncoderId $enc.encoder
        $app = @{}
        foreach ($p in $enc.parameters) { if (-not $p.excluded) { $app[$p.identity] = $p } }
        foreach ($p in $extraction.Parameters) {
            if ($p.Excluded -or -not $p.Identity) { continue }
            if (-not $app.ContainsKey($p.Identity)) { $out.Add("E11 $($p.Identity) missing from the application export"); continue }
            $a = $app[$p.Identity]
            if (($a.switches -join ',') -ne ($p.Switches -join ',')) { $out.Add("E11 $($p.Identity) switches differ: application '$($a.switches -join ',')' extractor '$($p.Switches -join ',')'") }
            if (($a.values -join ',') -ne ($p.EmittedValues -join ',')) { $out.Add("E11 $($p.Identity) values differ: application '$($a.values -join ',')' extractor '$($p.EmittedValues -join ',')'") }
            if ($a.caption -ne $p.Caption) { $out.Add("E11 $($p.Identity) caption differs: application '$($a.caption)' extractor '$($p.Caption)'") }
            $app.Remove($p.Identity)
        }
        foreach ($k in $app.Keys) { $out.Add("E11 $k missing from the extractor") }
    }
    return $out
}
```

Replace the tail of `Check-OptionHelp.ps1` (everything after the `-SelfTest` block) with:

```powershell
if ($CompareFacts) {
    $diff = Compare-OptionHelpFacts -RepoRoot $RepoRoot -FactsPath $CompareFacts
    foreach ($d in $diff) { [Console]::Error.WriteLine($d) }
    if ($diff.Count -gt 0) { exit 1 }
    [Console]::Error.WriteLine('facts: no differences')
    exit 0
}

$report = Test-OptionHelpRepository -RepoRoot $RepoRoot -Encoder $Encoder
if ($Json) {
    [Console]::Out.Write(($report | ConvertTo-Json -Depth 6))
}
else {
    [Console]::Out.Write((Format-OptionHelpReport -Report $report))
}
if ($AdvanceRatchet) {
    if (-not $report.Pass) { [Console]::Error.WriteLine('Ratchet not advanced: validation failed'); exit 1 }
    Update-OptionHelpRatchet -RepoRoot $RepoRoot -Report $report
    [Console]::Error.WriteLine('Ratchet advanced')
}
if ($report.Pass) { exit 0 }
exit 1
```

Add to `Invoke-OptionHelpSelfTest` before the summary line:

```powershell
    foreach ($repo in @('repo', 'repo-clean')) {
        $count++
        $expected = [System.IO.File]::ReadAllText((Join-Path $FixturesRoot "expected\report-$repo.txt")).Replace("`r`n", "`n")
        $actual = Format-OptionHelpReport -Report (Test-OptionHelpRepository -RepoRoot (Join-Path $FixturesRoot $repo))
        if ($expected -ne $actual) { $failures++; [Console]::Error.WriteLine("FAIL report-$repo`n--- expected`n$expected`n--- actual`n$actual") }
    }
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
    # Facts comparison against the fake repository.
    $count++
    $diff = Compare-OptionHelpFacts -RepoRoot (Join-Path $FixturesRoot 'repo') -FactsPath (Join-Path $FixturesRoot 'facts\fake-export.json')
    $expected = [System.IO.File]::ReadAllText((Join-Path $FixturesRoot 'expected\compare-facts.txt')).Replace("`r`n", "`n").TrimEnd("`n")
    if (($diff -join "`n") -ne $expected) { $failures++; [Console]::Error.WriteLine("FAIL compare-facts`n--- expected`n$expected`n--- actual`n$($diff -join "`n")") }
```

- [ ] **Step 3: Run the self-test and reconcile the fake-repository expectation**

Run: `pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -SelfTest`
Expected: `self-test: 23 dump cases, 0 failures`. The `report-repo` case is the one most likely to differ on first run; print the actual report, check each line against spec 6.3 and the fixture, and correct whichever of code or expectation contradicts the spec. The order of `compare-facts.txt` lines follows extraction order, which is declaration order in `FakeEnc.vb`.

- [ ] **Step 4: Write the script README**

`Source/Tools/OptionHelp/README.md`:

```markdown
# Check-OptionHelp

Validates `Docs/OptionHelp/*.md` against the grammar in `Docs/Planning/OPTION-HELP.md` and against the parameters declared in `Source/Encoding/*.vb`.

## Usage

```powershell
pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1              # report, exit 1 on any error
pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -SelfTest    # fixture suite
pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -Encoder svt-av1
pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -Json > report.json
pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -AdvanceRatchet
pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -CompareFacts facts.json
pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -Dump Docs/OptionHelp/svt-av1.md
```

`-Json` writes only JSON to stdout; diagnostics go to stderr. `-AdvanceRatchet` runs only after a clean validation, lowers `Allowed-Missing` and raises `Minimum-Reviewed` to the current counts, never the other way, and never touches `Reviewed-Complete`. `-CompareFacts` takes the file written by the StaxRip command `-ExportOptionHelpFacts:<path>` and reports every difference between the application's view of the parameters and this script's extraction as E11.

## Rules

| Code | Level | Meaning |
| --- | --- | --- |
| E1 | file | Grammar or header violation, unknown Schema, name and header disagree, bad inheritance |
| E2 | stanza | Summary missing, overlong, or not ending with a period; When to change missing on a reviewed stanza; limits |
| E3 | stanza | Unknown, duplicate, or out-of-order field; Status missing or invalid; text or bullet in the wrong place |
| E4 | stanza | A value note names a value the option does not emit |
| E5 | stanza | Orphan stanza |
| E6 | stanza | Related or Use target missing, or Use target not reviewed |
| E7 | file | A counter crossed its bound |
| E8 | file | Duplicate stanza id |
| E9 | source | OptionHelpId override missing or wrong |
| E10 | source | Parameter without identity |
| E11 | source | Parameter construction the extractor does not recognize, or a difference from the application export |
| E12 | project | Help file and EmbeddedResource entries do not pair up; Source path outside the repository or with different case |
| E13 | stanza | Bad URL scheme, malformed link, unmatched backtick |
| W1 | source | Encoder file with no help file |
| W2 | stanza | Label differs from the VB caption |
| W3 | source | Excluded parameters |

## Known blind spots

The extractor reads text. It understands `New OptionParam|NumParam|BoolParam|StringParam ... With { ... }` declared as properties or inline inside `Add(...)`, with full-line comments removed. Anything else that constructs a parameter is E11, not silently invisible. Parameters that are declared but never added to `Items` count toward totals unless excluded with `OptionHelpKey = "none"`. Run `-CompareFacts` against a fresh application export before a close-out to reconcile.
```

The W2 rule is implemented in plan 2's close-out task once `Label` fields exist in real content; it is listed here so the table is complete.

- [ ] **Step 5: Commit**

```bash
git add Source/Tools/OptionHelp
git commit -m "Tools: check option-help coverage with exact counters, ratchet, and facts comparison" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Parameter model: identity, primary switch, emitted value, facts export, SVT-AV1 binding

**Files:**
- Modify: `Source/Video/VideoEncoderCommandLine.vb` (`CommandLineParams` at lines 8-70, `CommandLineParam` at lines 195-284, `OptionParam.GetArgs` at lines 653-676)
- Modify: `Source/Encoding/SvtAv1Enc.vb` (lines 444-448, 451, 455, 465, 477, 483, 490, 497, 504, 511, 1211, 1224, 1238, 1247, 1256, 1265, 1274)
- Create: `Source/Tools/OptionHelp/fixtures/vb/RealSvtAv1.txt` is not needed; the real file is checked by Task 6

**Interfaces:**
- Produces: `CommandLineParams.OptionHelpId As String` (overridable, default `Nothing`); `CommandLineParams.ExportOptionHelpFacts() As String` (JSON object for one encoder, see shape below); `CommandLineParam.OptionHelpKey As String`; `CommandLineParam.PrimaryHelpSwitch() As String`; `CommandLineParam.OptionHelpIdentity(encoderId As String) As String` (`Nothing` when none, `"none"` when excluded); `OptionParam.GetEmittedValue(index As Integer) As String`.

- [ ] **Step 1: Prepare the build once**

```powershell
Copy-Item 'C:\DEV\StaxRip\Source\packages' 'C:\DEV\StaxRip\.claude\worktrees\option-help\Source\packages' -Recurse
& 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe' 'Source\StaxRip.vbproj' -t:Build -p:Configuration=Debug -p:Platform=x64 -m -nologo -verbosity:minimal
```

Expected: exit code 0 and `Source\bin\StaxRip.exe` before any edit. `Source/packages` and `Source/bin` are ignored by `.gitignore`; `git status --short` must stay empty.

- [ ] **Step 2: Add the identity members to `CommandLineParam`**

In `Source/Video/VideoEncoderCommandLine.vb`, inside `Public MustInherit Class CommandLineParam`, after `Property Weight As Integer`:

```vb
        Property OptionHelpKey As String

        ''' <summary>The one switch help is keyed on: explicit HelpSwitch, else Switch, else NoSwitch, else the first Switches entry.</summary>
        Function PrimaryHelpSwitch() As String
            If HelpSwitch <> "" Then Return HelpSwitch
            If Switch <> "" Then Return Switch
            If NoSwitch <> "" Then Return NoSwitch

            If Not Switches.NothingOrEmpty Then
                For Each i In Switches
                    If i <> "" Then Return i
                Next
            End If

            Return Nothing
        End Function

        ''' <summary>Stable option-help identity: the explicit key, "none" when excluded, else encoderId.switch, else Nothing.</summary>
        Function OptionHelpIdentity(encoderId As String) As String
            If OptionHelpKey <> "" Then Return OptionHelpKey
            Dim sw = PrimaryHelpSwitch()
            If encoderId = "" OrElse sw Is Nothing Then Return Nothing
            Return encoderId + "." + sw.TrimStart("-"c)
        End Function
```

- [ ] **Step 3: Make `Add` use the documented order**

In `CommandLineParams.Add` (line 39-45), replace:

```vb
                If i.HelpSwitch = "" Then
                    Dim switches = i.GetSwitches

                    If Not switches.NothingOrEmpty Then
                        i.HelpSwitch = switches(0)
                    End If
                End If
```

with:

```vb
                If i.HelpSwitch = "" Then
                    i.HelpSwitch = i.PrimaryHelpSwitch()
                End If
```

`PrimaryHelpSwitch` returns `Nothing` for a switch-less parameter; VB string comparison treats `Nothing` and `""` alike everywhere `HelpSwitch` is tested, so behavior is unchanged.

- [ ] **Step 4: Add `OptionHelpId` and the facts export to `CommandLineParams`**

Inside `Public MustInherit Class CommandLineParams`, after `MustOverride ReadOnly Property Package As Package`:

```vb
        ''' <summary>The Docs/OptionHelp file id for this encoder, or Nothing when it has no help file.</summary>
        Overridable ReadOnly Property OptionHelpId As String
            Get
                Return Nothing
            End Get
        End Property

        ''' <summary>JSON facts for Check-OptionHelp.ps1 -CompareFacts: one object per parameter in Items order.</summary>
        Function ExportOptionHelpFacts() As String
            Dim names As New Dictionary(Of CommandLineParam, String)

            For Each prop In Me.GetType.GetProperties()
                If GetType(CommandLineParam).IsAssignableFrom(prop.PropertyType) AndAlso prop.GetIndexParameters().Length = 0 Then
                    Dim value = TryCast(prop.GetValue(Me), CommandLineParam)
                    If value IsNot Nothing AndAlso Not names.ContainsKey(value) Then names(value) = prop.Name
                End If
            Next

            Dim sb As New StringBuilder
            sb.Append("{""encoder"":" + OptionHelpJson.Quote(OptionHelpId) + ",""parameters"":[")
            Dim first = True

            For Each param In Items
                If TypeOf param Is LineParam Then Continue For
                If Not first Then sb.Append(",")
                first = False
                Dim identity = param.OptionHelpIdentity(OptionHelpId)
                Dim excluded = identity = "none"
                Dim values As String() = {}
                Dim op = TryCast(param, OptionParam)

                If op IsNot Nothing AndAlso op.Options IsNot Nothing Then
                    values = Enumerable.Range(0, op.Options.Length).Select(Function(i) op.GetEmittedValue(i)).ToArray
                End If

                sb.Append("{""name"":" + OptionHelpJson.Quote(If(names.ContainsKey(param), names(param), "-")))
                sb.Append(",""type"":" + OptionHelpJson.Quote(param.GetType.Name))
                sb.Append(",""identity"":" + OptionHelpJson.Quote(If(excluded, Nothing, identity)))
                sb.Append(",""excluded"":" + If(excluded, "true", "false"))
                sb.Append(",""caption"":" + OptionHelpJson.Quote(param.Text))
                sb.Append(",""switches"":" + OptionHelpJson.Array(param.GetSwitches))
                sb.Append(",""values"":" + OptionHelpJson.Array(values) + "}")
            Next

            sb.Append("]}")
            Return sb.ToString
        End Function
```

`OptionHelpJson` is defined in plan 2 Task 1 (`Source/General/OptionHelp.vb`). Until plan 2 Task 1 lands, add this minimal version at the end of `Source/Video/VideoEncoderCommandLine.vb` inside the namespace, and delete it in plan 2 Task 1 when the full module arrives:

```vb
    Public Class OptionHelpJson
        Shared Function Quote(value As String) As String
            If value Is Nothing Then Return "null"
            Dim sb As New StringBuilder("""")

            For Each c In value
                Select Case c
                    Case """"c : sb.Append("\""")
                    Case "\"c : sb.Append("\\")
                    Case ControlChars.Lf : sb.Append("\n")
                    Case ControlChars.Cr : sb.Append("\r")
                    Case ControlChars.Tab : sb.Append("\t")
                    Case Else
                        If AscW(c) < 32 Then sb.Append("\u" + AscW(c).ToString("x4")) Else sb.Append(c)
                End Select
            Next

            Return sb.Append("""").ToString
        End Function

        Shared Function Array(values As IEnumerable(Of String)) As String
            If values Is Nothing Then Return "[]"
            Return "[" + String.Join(",", values.Select(Function(v) Quote(v))) + "]"
        End Function
    End Class
```

`GetSwitches` returns Switch, NoSwitch, HelpSwitch, Switches in insertion order; the validator's `Switches` list uses the same order (Task 3), so `-CompareFacts` compares like with like.

- [ ] **Step 5: Extract `GetEmittedValue` and make `GetArgs` call it**

In `Public Class OptionParam`, add after `ReadOnly Property ValueText As String ... End Property`:

```vb
        ''' <summary>The value string GetArgs emits for a dropdown index, without the switch.</summary>
        Function GetEmittedValue(index As Integer) As String
            If Values IsNot Nothing Then Return Values(index)
            If IntegerValue Then Return index.ToString
            Return Options(index).ToLowerInvariant.Replace(" ", "")
        End Function
```

Replace the body of `Overrides Function GetArgs() As String` (currently lines 653-676) with:

```vb
        Overrides Function GetArgs() As String
            If Not Visible Then Return Nothing

            If ArgsFunc Is Nothing Then
                If Value <> DefaultValue OrElse AlwaysOn Then
                    Dim v = GetEmittedValue(Value)

                    If Values IsNot Nothing AndAlso v.StartsWith("--") Then
                        Return v
                    ElseIf Switch <> "" Then
                        Return Switch + If(String.IsNullOrWhiteSpace(v), "", Params.Separator & v)
                    End If
                End If
            Else
                Return ArgsFunc.Invoke
            End If
        End Function
```

Equivalence argument, to be checked by the reviewer of this task against the old body: the old `Values` branch returned `Values(Value)` when it started with `--`, else `Switch + separator + Values(Value)` when `Switch` was set; the old `IntegerValue` branch returned `Switch + separator & Value`, and an integer never trips `IsNullOrWhiteSpace`; the old text branch matched the new one; every fall-through still returns `Nothing`.

- [ ] **Step 6: Bind SVT-AV1**

In `Source/Encoding/SvtAv1Enc.vb`, after the `Package` override that ends at line 448, add:

```vb
    Public Overrides ReadOnly Property OptionHelpId As String
        Get
            Return "svt-av1"
        End Get
    End Property
```

Then add one `.OptionHelpKey` line as the first initializer of each of these declarations (the line numbers are from before this edit; search by property name):

| Property | Line | Add |
| --- | --- | --- |
| `OverrideTargetFileName` | 451 | `.OptionHelpKey = "staxrip.override-target-file-name",` |
| `TargetFileName` | 455 | `.OptionHelpKey = "staxrip.target-file-name",` |
| `TargetFileNamePreview` | 465 | `.OptionHelpKey = "staxrip.target-file-name-preview",` |
| `Decoder` | 477 | `.OptionHelpKey = "staxrip.decoder",` |
| `PipingToolAVS` | 483 | `.OptionHelpKey = "staxrip.pipe",` |
| `PipingToolVS` | 490 | `.OptionHelpKey = "staxrip.pipe",` |
| `CompCheck` | 497 | `.OptionHelpKey = "staxrip.comp-check",` |
| `CompCheckAimedQuality` | 504 | `.OptionHelpKey = "staxrip.aimed-quality",` |
| `Chunks` | 511 | `.OptionHelpKey = "staxrip.chunks",` |
| `ContentLightLevel` | 1211 | `.OptionHelpKey = "none",` |
| `MaxCLL` | 1224 | `.OptionHelpKey = "svt-av1.content-light.max-cll",` |
| `MaxFALL` | 1238 | `.OptionHelpKey = "svt-av1.content-light.max-fall",` |
| `Custom` | 1247 | `.OptionHelpKey = "staxrip.custom",` |
| `CustomFirstPass` | 1256 | `.OptionHelpKey = "staxrip.custom",` |
| `CustomSecondPass` | 1265 | `.OptionHelpKey = "staxrip.custom",` |
| `CustomThirdPass` | 1274 | `.OptionHelpKey = "staxrip.custom",` |

Example for `Chunks` after the edit:

```vb
    Property Chunks As New NumParam With {
        .OptionHelpKey = "staxrip.chunks",
        .Text = "Chunks",
        .Config = {1, 128},
        .Init = 1}
```

- [ ] **Step 7: Build and check the extractor against the real file**

Run the MSBuild command from Step 1. Expected: exit code 0, no new warnings.

Then run:

```powershell
pwsh -NoProfile -Command "Import-Module Source/Tools/OptionHelp/OptionHelp.psm1; $x = Get-VbParameters -Path Source/Encoding/SvtAv1Enc.vb -EncoderId svt-av1; $x.OptionHelpId; $x.Parameters.Count; @($x.Parameters | Where-Object Excluded).Count; $x.Errors | Format-Table"
```

Expected: `svt-av1`, `101`, `1`, and no errors. If E10 appears, a switch-less parameter was missed in Step 6; if E11 appears, the real file has a construction the fixture did not anticipate, and the extractor must be extended before continuing (record the construction in the script README).

- [ ] **Step 8: Commit**

```bash
git add Source/Video/VideoEncoderCommandLine.vb Source/Encoding/SvtAv1Enc.vb
git commit -m "Video: give every option a stable help identity and one emitted-value routine" -m "Adds OptionHelpId, OptionHelpKey, PrimaryHelpSwitch, OptionHelpIdentity, GetEmittedValue, and ExportOptionHelpFacts; binds SVT-AV1 with 16 explicit keys. GetArgs now calls GetEmittedValue; behavior is unchanged." -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Repository files: `.gitattributes`, skeleton content, authoring README, `AGENTS.md`, first clean real run

**Files:**
- Modify: `.gitattributes`, `AGENTS.md` (insert after the `## Writing rules` section, line 90-92)
- Create: `Docs/OptionHelp/README.md`, `Docs/OptionHelp/svt-av1.md`, `Docs/OptionHelp/staxrip.md`, `Docs/OptionHelp/concepts.md`
- Modify: `Source/StaxRip.vbproj` (EmbeddedResource entries; the `Compile` entry for `OptionHelp.vb` is plan 2)

**Interfaces:**
- Produces: the three skeleton files that plan 2 embeds and plan 3 fills; the passing baseline `ENCODER svt-av1 total=100 ... missing=100 allowed-missing=100 ... result=PASS`.

- [ ] **Step 1: `.gitattributes`**

Append:

```
Docs/OptionHelp/** text eol=lf
Source/Tools/OptionHelp/fixtures/** text eol=lf
```

Then renormalize the files created so far: `git add --renormalize Source/Tools/OptionHelp` and check `git status --short` shows only `.gitattributes` and, if any fixture had CRLF, those fixtures.

- [ ] **Step 2: Skeleton content files**

`Docs/OptionHelp/svt-av1.md`:

```markdown
# SVT-AV1 option help

Schema: 1
Encoder: svt-av1
Locale: en
Title: SVT-AV1
Source: Source/Encoding/SvtAv1Enc.vb
Allowed-Missing: 100
Minimum-Reviewed: 0
Reviewed-Complete: false
```

`Docs/OptionHelp/staxrip.md`:

```markdown
# StaxRip-owned option help

Schema: 1
Encoder: staxrip
Locale: en
Title: StaxRip
```

`Docs/OptionHelp/concepts.md`:

```markdown
# Glossary

Schema: 1
Encoder: concepts
Locale: en
Title: Glossary
```

- [ ] **Step 3: Project resource entries**

In `Source/StaxRip.vbproj`, immediately before the line `    <None Include="..\README.md">`, insert:

```xml
    <EmbeddedResource Include="..\Docs\OptionHelp\svt-av1.md">
      <Link>OptionHelp\svt-av1.md</Link>
    </EmbeddedResource>
    <EmbeddedResource Include="..\Docs\OptionHelp\staxrip.md">
      <Link>OptionHelp\staxrip.md</Link>
    </EmbeddedResource>
    <EmbeddedResource Include="..\Docs\OptionHelp\concepts.md">
      <Link>OptionHelp\concepts.md</Link>
    </EmbeddedResource>
```

- [ ] **Step 4: Authoring README**

`Docs/OptionHelp/README.md`:

```markdown
# Writing option help

Every option in an encoder dialog gets one stanza in the encoder's file here. The text shows as a tooltip, in the description strip above the command line, and in the details window (F1 or right-click). The grammar and the rules are defined in `Docs/Planning/OPTION-HELP.md`; this page is the short version for authors.

## The stanza

```markdown
## svt-av1.preset
Label: Preset
Summary: One or two sentences. What it changes in the encode, ending with a period.
Used when: Only if the option is ignored in some mode; say which mode uses it.
When to change: The situation, the tradeoff, and a practical first action.
Encoder default: 8
Example: A concrete thing to try, with enough context to reproduce it.
Values:
- 6: A note for a value worth explaining. Not every value needs one.
Related: svt-av1.crf, concept.compression-efficiency
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md
Status: draft
```

Field order is fixed. `Summary` and `Status` are required; `When to change` is required once the stanza is `reviewed`. Limits: Label 60, Summary 200, Used when 200, When to change 400, Encoder default 40, Example 300, value notes 120 characters. Inline markup is backticks for a literal switch or value and `[text](https://...)` for a link; nothing else.

## Stanza ids

The heading is the option's stable id, `<encoder>.<switch without dashes>` for ordinary options (`svt-av1.preset` for `--preset`). Controls that share a switch or have no switch carry an explicit `OptionHelpKey` in the VB declaration; `Check-OptionHelp.ps1` prints the id of every option it cannot find text for, so you never have to derive one by hand.

## Writing rules

1. The first sentence names the observable effect on picture quality, file size, encoding speed, decoding compatibility, resource use, or workflow.
2. `When to change` names the situation, the tradeoff, and a practical first action.
3. Current value, StaxRip default, and valid range come from the application; put them in prose only when they are stable and version-verified.
4. Use a number when it helps the decision. Never add a number to satisfy the template.
5. State exact ranges plainly. Label performance, time, size, and quality outcomes as measured examples and include enough test context to reproduce them.
6. Define an unfamiliar term inline or link it to a reviewed glossary entry through `Related`.
7. Say "leave it at the default" when that is the honest advice. Avoid "best", "sweet spot", and universal claims unless the evidence supports them.
8. Explain interactions and inactive modes. Use `Used when` to tell the user when an option is ignored.
9. Use original wording and link the evidence. x264 and x265 documentation is GPL and StaxRip is MIT.
10. A stanza becomes `reviewed` only after a human readability review in the real interface and technical verification against the bundled encoder version named in the file header.

## Drafting workflow

Anyone, and any tool, may draft. The maintainer's standing preference: draft the prose with whichever model or writer produces the warmest, clearest friend-to-friend English, at the drafter's judgment. The gate is rule 10, not the tool. On a feature branch, `reviewed` means the technical verification is done and the maintainer's readability review on the real dialog happens before merge; on `master` it means both have happened.

Sources for SVT-AV1: the bundled `Apps\Encoders\SvtAv1EncApp\SvtAv1EncApp.exe --help` and `--version` output, the SVT-AV1 `Docs/Parameters.md` at the tag matching the bundled build, and Patman's release notes for PMod-specific behavior. Where the bundled build and upstream disagree, the bundled build wins and the stanza says so.

## Checking your work

```powershell
pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1
```

The report lists every option without text (`MISSING`), every rule violation with a file and line, and whether each encoder is within its counters. Adding a parameter in VB fails the check until at least a `draft` stanza exists. When a batch of stanzas is done, run with `-AdvanceRatchet` so the counters follow; when every option of an encoder is reviewed, set `Reviewed-Complete: true` by hand.

## Files

| File | Holds |
| --- | --- |
| `<encoder>.md` | Every option of that encoder |
| `<variant>.md` with `Inherits: <base>` | Only the variant's additions and overrides; a `draft` here hides the base text |
| `staxrip.md` | The controls StaxRip adds to every dialog: Decoder, Pipe, Custom, target file name, Chunks, Comp. Check, Aimed Quality |
| `concepts.md` | Glossary entries such as `concept.psnr`, reached only through `Related` |
| `shared.md` | Reusable option prose, reached only through `Use:`; created when a second encoder needs it |
```

- [ ] **Step 5: `AGENTS.md` paragraph**

Insert after the `## Writing rules` section (after line 92, before `## Pull request close-out`):

```markdown
## Option help

Encoder option help lives in `Docs/OptionHelp/*.md` under the grammar in `Docs/Planning/OPTION-HELP.md`; `Docs/OptionHelp/README.md` is the authoring guide. Run `pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1` before a pull request that touches `Source/Encoding/*.vb` or `Docs/OptionHelp/`; a new parameter needs at least a draft stanza. Draft the prose with whichever model or writer produces the warmest, clearest friend-to-friend English; a stanza becomes `reviewed` only after technical verification against the bundled encoder version and a human readability review in the real dialog.
```

- [ ] **Step 6: Run the validator on the real repository**

Run: `pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1`
Expected output begins with:

```
ENCODER svt-av1 total=100 excluded=1 reviewed=0 draft=0 missing=100 allowed-missing=100 minimum-reviewed=0 reviewed-complete=false result=PASS
```

followed by 94 `MISSING` lines (one per id; the counters count parameters, so `missing=100` while the ten parameters that share ids print once), `W1` for every other encoder file under `Source/Encoding/` (AOMEnc, NVEnc, QSVEnc, Rav1e, the four other SvtAv1 files, VCEEnc, VvencffappEnc, ffmpegEnc, x264Enc, x265Enc, and any other file that inherits `CommandLineParams`), `W3 svt-av1 ContentLightLevel excluded`, and `RESULT PASS` with exit code 0. The `MISSING` count is 94 because ten parameters share ids (`--keyint`, `--pass`, `Pipe`, and the four `Custom` boxes) while `total` counts parameters.

Then run `-SelfTest` once more; expected 23 cases, 0 failures.

- [ ] **Step 7: Build and commit**

Run the MSBuild command from Task 5 Step 1; expected exit code 0 (the resources embed even though nothing reads them yet).

```bash
git add .gitattributes AGENTS.md Docs/OptionHelp Source/StaxRip.vbproj Source/Tools/OptionHelp
git commit -m "Docs: add the option-help skeleton, authoring guide, and repository rules" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
git push origin worktree-option-help
```

---

## Self-review against the spec (plan 1 scope)

| Spec item | Task |
| --- | --- |
| 4.2 grammar, 4.3 headers and fields and limits | 1, 2 |
| 4.4 identity, primary switch, derived ids, `none`, lookup with draft shadowing and `Use` | 3 (validator), 5 (runtime members) |
| 5.2 parameter model members, `GetEmittedValue`, facts export | 5 |
| 5.5 `.gitattributes`, `AGENTS.md`, resource entries | 6 |
| 6.1 interface, 6.2 extraction and E11, 6.3 rules E1-E13 and W1, W3 | 1-4 (W2 in plan 2 close-out) |
| 6.4 counters and ratchet | 4 |
| 6.5 fixtures including security cases | 2, 4 |
| 6.7 facts comparison (validator side) | 4; the command itself is plan 2 |
| 8 step 1 deliverables | 4, 6 |

Not in this plan: `Source/General/OptionHelp.vb`, the harness, the dialog, the help window (plan 2); all stanzas (plan 3).
