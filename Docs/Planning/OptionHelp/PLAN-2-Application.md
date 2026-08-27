# Option Help Implementation Plan 2: Loader, Harness, Help Window, Dialog

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make reviewed option help visible in the SVT-AV1 dialog: hover tooltip, description strip, per-value notes, F1 and right-click details with generated facts, search over help text; all rendered through an HTML trust boundary, with a VB parser proven against the same fixtures as the validator.

**Architecture:** `Source/General/OptionHelp.vb` is a dependency-free parser and catalog (also compiled by a standalone harness project). `HelpDocument` gains node-based writers; `HelpForm` gains typed `staxrip:` routes, a scheme policy, and per-window temp cleanup. `CommandLineForm` resolves a stanza per parameter, binds several help targets per option, adds the strip, F1, accessibility, value notes, search, and the details window. `GlobalCommands.ExportOptionHelpFacts` feeds the validator's reconciliation.

**Tech Stack:** VB.NET on .NET Framework 4.8 (Windows Forms, `WebBrowser`), MSBuild 17, PowerShell 7 for the validator, Git.

**Spec:** `Docs/Planning/OPTION-HELP.md` (v0.2), sections 5.1 to 5.6, 6.7, 6.8, 10, 11.

## Global Constraints

- Prerequisite: plan 1 complete (`worktree-option-help` has Tasks 1 to 6 committed; `Source\packages` copied; validator passes on the repository).
- Work in `C:\DEV\StaxRip\.claude\worktrees\option-help`; commit after every task with the `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` trailer.
- Build: `& 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe' 'Source\StaxRip.vbproj' -t:Build -p:Configuration=Debug -p:Platform=x64 -m -nologo -verbosity:minimal` from the worktree root; harness build: same command with `'Source\Tests\OptionHelp\OptionHelpTests.vbproj'`.
- `Source/General/OptionHelp.vb` references only the .NET Framework base class library: no `g.`, no StaxRip extension methods, no `Package`, no `CommandLineParam`. It carries its own `Imports`.
- Authored text never reaches `HelpDocument.WriteRaw`, `WriteElement`, `WriteParagraph`, or `WriteTable`; only `WriteNodes`, `WriteNodesTable`, and `WriteLinkList` from Task 4.
- Command-line generation is not edited in this plan. `OptionParam.GetEmittedValue` (plan 1) is the only value routine.
- Only `reviewed` stanzas display. A `draft` in the chain shows nothing.
- `.vbproj` files are ASCII only (`Source/Build.ps1` scans them).

---

## File structure

| File | Responsibility |
| --- | --- |
| `Source/General/OptionHelp.vb` | `OptionHelpParser`, `OptionHelpFile`, `OptionHelpStanza`, `OptionHelpValue`, `OptionHelpError`, `OptionHelpNode`, `OptionHelpDump`, `OptionHelpJson`, `OptionHelpCatalog`, `OptionHelpResolution`, `OptionHelpRoute` |
| `Source/Tests/OptionHelp/OptionHelpTests.vbproj`, `Program.vb` | Standalone harness: runs the plan 1 fixtures through the VB parser and catalog |
| `Source/General/General.vb` (`HelpDocument`) | `WriteNodes`, `WriteNodesTable`, `WriteLinkList`, `Path` property, charset, no font import |
| `Source/Forms/HelpForm.vb` | `RouteAction`, scheme policy, temp-file cleanup on close |
| `Source/Forms/CommandLineForm.vb` and `.Designer.vb` | Targets per item, tooltips, strip, F1, accessibility, value notes, search, details window |
| `Source/General/GlobalCommands.vb`, `Docs/Usage/Command-Line-Interface.md` | `ExportOptionHelpFacts` command and its documentation |
| `Source/StaxRip.vbproj` | `Compile` entry for `OptionHelp.vb` |
| `Docs/OptionHelp/svt-av1.md` | First reviewed stanza (`svt-av1.preset`) and verification headers, used for the end-to-end check |

---

### Task 1: `OptionHelp.vb` parser, dump, JSON, and the harness project

**Files:**
- Create: `Source/General/OptionHelp.vb`
- Create: `Source/Tests/OptionHelp/OptionHelpTests.vbproj`, `Source/Tests/OptionHelp/Program.vb`
- Modify: `Source/StaxRip.vbproj` (add `<Compile Include="General\OptionHelp.vb" />` after the line `<Compile Include="General\Help.vb" />`)
- Modify: `Source/Video/VideoEncoderCommandLine.vb` (delete the temporary `OptionHelpJson` class added in plan 1 Task 5)

**Interfaces:**
- Produces: `OptionHelpParser.ParseBytes(bytes As Byte(), name As String) As OptionHelpFile`, `OptionHelpParser.Parse(text As String, name As String) As OptionHelpFile`, `OptionHelpParser.PlainText(text As String) As String`, `OptionHelpParser.ParseInline(text As String) As List(Of OptionHelpNode)`, `OptionHelpDump.Write(file As OptionHelpFile) As String`, `OptionHelpJson.Quote`, `OptionHelpJson.Array`; `OptionHelpStanza` members `Id`, `Line`, `FileName`, `Status`, `IsReviewed`, `Label`, `Use`, `Summary`, `UsedWhen`, `WhenToChange`, `EncoderDefault`, `Example`, `Related As List(Of String)`, `Values As List(Of OptionHelpValue)`, `References As List(Of String)`, `HasField`, `GetField`; `OptionHelpFile` members `Name`, `Encoder`, `Locale`, `Header`, `HeaderOrder`, `Stanzas`, `Errors`, `HasFileErrors`, `Inherits`, `FindStanza`.
- Consumes: plan 1 fixtures under `Source/Tools/OptionHelp/fixtures/` (`md/*.md`, `expected/*.txt`, `chain/`).

- [ ] **Step 1: Create the harness project and a `Program.vb` that fails to compile**

`Source/Tests/OptionHelp/OptionHelpTests.vbproj`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="15.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <BaseIntermediateOutputPath>..\..\obj\OptionHelpTests\obj\</BaseIntermediateOutputPath>
  </PropertyGroup>
  <Import Project="$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props" Condition="Exists('$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props')" />
  <PropertyGroup>
    <Configuration Condition=" '$(Configuration)' == '' ">Debug</Configuration>
    <Platform Condition=" '$(Platform)' == '' ">x64</Platform>
    <ProjectGuid>{7B1C2E9A-4D3F-4E8B-9C21-0A6F5D2B8E41}</ProjectGuid>
    <OutputType>Exe</OutputType>
    <StartupObject>OptionHelpTests.Program</StartupObject>
    <RootNamespace>OptionHelpTests</RootNamespace>
    <AssemblyName>OptionHelpTests</AssemblyName>
    <MyType>Console</MyType>
    <TargetFrameworkVersion>v4.8</TargetFrameworkVersion>
    <Deterministic>true</Deterministic>
    <OptionExplicit>On</OptionExplicit>
    <OptionStrict>On</OptionStrict>
    <OptionInfer>On</OptionInfer>
    <OptionCompare>Binary</OptionCompare>
    <OutputPath>..\..\obj\OptionHelpTests\bin\</OutputPath>
    <PlatformTarget>x64</PlatformTarget>
    <DebugType>portable</DebugType>
    <DefineDebug>true</DefineDebug>
    <DefineTrace>true</DefineTrace>
    <WarningLevel>1</WarningLevel>
  </PropertyGroup>
  <ItemGroup>
    <Reference Include="System" />
    <Reference Include="System.Core" />
  </ItemGroup>
  <ItemGroup>
    <Import Include="Microsoft.VisualBasic" />
    <Import Include="System" />
    <Import Include="System.Collections.Generic" />
    <Import Include="System.Linq" />
  </ItemGroup>
  <ItemGroup>
    <Compile Include="Program.vb" />
    <Compile Include="..\..\General\OptionHelp.vb">
      <Link>OptionHelp.vb</Link>
    </Compile>
  </ItemGroup>
  <Import Project="$(MSBuildToolsPath)\Microsoft.VisualBasic.targets" />
</Project>
```

`Source/Tests/OptionHelp/Program.vb`:

```vb
Imports System.IO
Imports System.Text

Module Program
    Function Main(args As String()) As Integer
        If args.Length < 1 Then
            Console.Error.WriteLine("usage: OptionHelpTests <fixturesRoot>")
            Return 2
        End If

        Dim root = args(0)
        Dim failures = 0
        Dim count = 0

        For Each md In Directory.GetFiles(Path.Combine(root, "md"), "*.md").OrderBy(Function(p) Path.GetFileName(p), StringComparer.Ordinal)
            count += 1
            Dim expectedPath = Path.Combine(root, "expected", Path.GetFileNameWithoutExtension(md) & ".txt")
            Dim expected = File.ReadAllText(expectedPath).Replace(vbCrLf, vbLf)
            Dim parsed = OptionHelpParser.ParseBytes(File.ReadAllBytes(md), Path.GetFileName(md))
            Dim actual = OptionHelpDump.Write(parsed)

            If expected <> actual Then
                failures += 1
                ReportDifference(Path.GetFileName(md), expected, actual)
            End If
        Next

        Dim chainDir = Path.Combine(root, "chain")
        Dim files As New Dictionary(Of String, Byte())(StringComparer.Ordinal)

        For Each f In Directory.GetFiles(chainDir, "*.md")
            files(Path.GetFileName(f)) = File.ReadAllBytes(f)
        Next

        For Each line In File.ReadAllLines(Path.Combine(chainDir, "cases.txt"))
            If line.Trim() = "" Then Continue For
            count += 1
            Dim parts = line.Split({" => "}, StringSplitOptions.None)
            Dim lhs = parts(0).Split(" "c)
            Dim catalog = OptionHelpCatalog.FromFiles(files, lhs(0))
            Dim actual = "none"

            If catalog IsNot Nothing Then
                Dim r = catalog.Resolve(lhs(1))
                If r.Outcome <> "none" Then actual = r.Outcome & ":" & r.FileName
            End If

            If actual <> parts(1) Then
                failures += 1
                Console.Error.WriteLine("FAIL chain '" & line & "' actual '" & actual & "'")
            End If
        Next

        Console.Error.WriteLine("harness: " & count & " cases, " & failures & " failures")
        Return If(failures > 0, 1, 0)
    End Function

    Sub ReportDifference(name As String, expected As String, actual As String)
        Dim el = expected.Split(vbLf(0))
        Dim al = actual.Split(vbLf(0))

        For i = 0 To Math.Max(el.Length, al.Length) - 1
            Dim e = If(i < el.Length, el(i), "<missing>")
            Dim a = If(i < al.Length, al(i), "<missing>")

            If e <> a Then
                Console.Error.WriteLine("FAIL " & name & " line " & (i + 1) & vbLf & "  expected: " & e & vbLf & "  actual:   " & a)
                Exit For
            End If
        Next
    End Sub
End Module
```

Run: `& 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe' 'Source\Tests\OptionHelp\OptionHelpTests.vbproj' -t:Build -p:Configuration=Debug -p:Platform=x64 -m -nologo -verbosity:minimal`
Expected: build FAILS with `'OptionHelpParser' is not declared` (and the catalog type), because `OptionHelp.vb` does not exist yet.

- [ ] **Step 2: Write `OptionHelp.vb` (parser, dump, JSON; the catalog and route come in Tasks 2 and 4)**

`Source/General/OptionHelp.vb`:

```vb
Imports System.IO
Imports System.Linq
Imports System.Text
Imports System.Text.RegularExpressions

' Plain-English option help: grammar parser, catalog, and rendering model.
' This file must stay free of StaxRip dependencies; Source/Tests/OptionHelp compiles it alone.

Public Class OptionHelpError
    Property Line As Integer
    Property Level As String
    Property Code As String
    Property Message As String
End Class

Public Class OptionHelpValue
    Property Value As String
    Property Note As String
    Property Line As Integer
End Class

Public Class OptionHelpNode
    Property Kind As String ' text, code, link
    Property Text As String
    Property Url As String

    Shared Function TextNode(text As String) As OptionHelpNode
        Return New OptionHelpNode With {.Kind = "text", .Text = text}
    End Function
End Class

Public Class OptionHelpStanza
    Property Id As String
    Property Line As Integer
    Property FileName As String = ""
    Property FieldOrder As New List(Of String)
    Property FieldsByName As New Dictionary(Of String, String)(StringComparer.Ordinal)
    Property Values As New List(Of OptionHelpValue)
    Property References As New List(Of String)
    Property Status As String = ""

    Function HasField(name As String) As Boolean
        Return FieldsByName.ContainsKey(name)
    End Function

    Function GetField(name As String) As String
        Dim value As String = Nothing
        If FieldsByName.TryGetValue(name, value) Then Return value
        Return Nothing
    End Function

    ReadOnly Property IsReviewed As Boolean
        Get
            Return Status = "reviewed"
        End Get
    End Property

    ReadOnly Property Label As String
        Get
            Return GetField("Label")
        End Get
    End Property

    ReadOnly Property Use As String
        Get
            Return GetField("Use")
        End Get
    End Property

    ReadOnly Property Summary As String
        Get
            Return GetField("Summary")
        End Get
    End Property

    ReadOnly Property UsedWhen As String
        Get
            Return GetField("Used when")
        End Get
    End Property

    ReadOnly Property WhenToChange As String
        Get
            Return GetField("When to change")
        End Get
    End Property

    ReadOnly Property EncoderDefault As String
        Get
            Return GetField("Encoder default")
        End Get
    End Property

    ReadOnly Property Example As String
        Get
            Return GetField("Example")
        End Get
    End Property

    ReadOnly Property Related As List(Of String)
        Get
            Dim raw = GetField("Related")
            If String.IsNullOrWhiteSpace(raw) Then Return New List(Of String)
            Return raw.Split(","c).Select(Function(s) s.Trim()).Where(Function(s) s <> "").ToList()
        End Get
    End Property
End Class

Public Class OptionHelpFile
    Property Name As String
    Property Encoder As String
    Property Locale As String
    Property HeaderOrder As New List(Of String)
    Property Header As New Dictionary(Of String, String)(StringComparer.Ordinal)
    Property Stanzas As New List(Of OptionHelpStanza)
    Property Errors As New List(Of OptionHelpError)

    ReadOnly Property HasFileErrors As Boolean
        Get
            Return Errors.Any(Function(e) e.Level = "FILE")
        End Get
    End Property

    ReadOnly Property Inherits As String
        Get
            Dim value As String = Nothing
            If Header.TryGetValue("Inherits", value) Then Return value
            Return Nothing
        End Get
    End Property

    Function FindStanza(id As String) As OptionHelpStanza
        For Each s In Stanzas
            If s.Id = id Then Return s
        Next
        Return Nothing
    End Function
End Class

Public Class OptionHelpParser
    Public Shared ReadOnly HeaderKeys As String() = {"Schema", "Encoder", "Locale", "Title", "Source", "Inherits",
        "Allowed-Missing", "Minimum-Reviewed", "Reviewed-Complete",
        "Verified-Encoder-Version", "Verified-Encoder-Build", "Verified-Date", "Documentation"}
    Public Shared ReadOnly FieldOrder As String() = {"Label", "Use", "Summary", "Used when", "When to change",
        "Encoder default", "Example", "Values", "Related", "References", "Status"}
    Public Shared ReadOnly SharedIds As String() = {"staxrip", "concepts", "shared"}
    Public Const IdPattern As String = "^[a-z0-9-]+(\.[a-z0-9-]+)+$"
    Public Const LinkPattern As String = "\[([^\[\]]+)\]\((https?://[^\s()]+)\)"
    Private Const EncoderPattern As String = "^[a-z0-9-]+$"
    Private Const NoteLimit As Integer = 120
    Private Shared ReadOnly FieldLimits As New Dictionary(Of String, Integer)(StringComparer.Ordinal) From {
        {"Label", 60}, {"Summary", 200}, {"Used when", 200}, {"When to change", 400}, {"Encoder default", 40}, {"Example", 300}}
    Private Shared ReadOnly HeaderLine As New Regex("^([A-Z][A-Za-z-]*): ?(.*)$")
    Private Shared ReadOnly FieldLine As New Regex("^([A-Z][A-Za-z]*(?: [a-z]+)*): ?(.*)$")
    Private Shared ReadOnly LinkRegex As New Regex(LinkPattern)
    Private Shared ReadOnly InlineTextFields As String() = {"Summary", "Used when", "When to change", "Example", "Encoder default", "Label"}

    Shared Function ParseBytes(bytes As Byte(), name As String) As OptionHelpFile
        Dim pending As New List(Of OptionHelpError)

        If bytes.Length >= 3 AndAlso bytes(0) = &HEF AndAlso bytes(1) = &HBB AndAlso bytes(2) = &HBF Then
            pending.Add(NewError(1, "FILE", "E1", "UTF-8 byte order mark is not allowed"))
            bytes = bytes.Skip(3).ToArray()
        End If

        Dim text As String

        Try
            text = New UTF8Encoding(False, True).GetString(bytes)
        Catch ex As DecoderFallbackException
            pending.Add(NewError(1, "FILE", "E1", "File is not valid UTF-8"))
            text = New UTF8Encoding(False, False).GetString(bytes)
        End Try

        Dim file = Parse(text, name)
        file.Errors.AddRange(pending)
        Return file
    End Function

    Shared Function Parse(text As String, name As String) As OptionHelpFile
        Dim file As New OptionHelpFile With {.Name = name}
        Dim base = Regex.Replace(name, "\.md$", "")
        Dim nameParts = base.Split({"."c}, 2)
        file.Encoder = nameParts(0)
        file.Locale = If(nameParts.Length > 1, nameParts(1), "en")

        Dim lines = text.Replace(vbCrLf, vbLf).Split(vbLf(0))
        Dim stanza As OptionHelpStanza = Nothing
        Dim currentField As String = Nothing
        Dim seenContent = False
        Dim lastFieldIndex = -1

        For i = 0 To lines.Length - 1
            Dim lineNo = i + 1
            Dim line = lines(i)
            Dim trimmed = line.Trim()

            If Regex.IsMatch(trimmed, "^<!--.*-->$") Then Continue For

            If Not seenContent AndAlso trimmed.StartsWith("# ") Then
                seenContent = True
                Continue For
            End If

            If trimmed = "" Then
                currentField = Nothing
                Continue For
            End If

            seenContent = True

            If line.StartsWith("## ") Then
                Dim id = line.Substring(3).Trim()
                stanza = New OptionHelpStanza With {.Id = id, .Line = lineNo, .FileName = name}
                file.Stanzas.Add(stanza)
                currentField = Nothing
                lastFieldIndex = -1
                If Not Regex.IsMatch(id, IdPattern) Then file.Errors.Add(NewError(lineNo, "STANZA", "E1", "Invalid stanza id '" & id & "'"))
                Continue For
            End If

            If stanza Is Nothing Then
                Dim hm = HeaderLine.Match(line)

                If hm.Success Then
                    Dim key = hm.Groups(1).Value
                    Dim value = hm.Groups(2).Value.Trim()

                    If Not HeaderKeys.Contains(key) Then
                        file.Errors.Add(NewError(lineNo, "FILE", "E1", "Unknown header key '" & key & "'"))
                    ElseIf file.Header.ContainsKey(key) Then
                        file.Errors.Add(NewError(lineNo, "FILE", "E1", "Duplicate header key '" & key & "'"))
                    Else
                        file.Header(key) = value
                        file.HeaderOrder.Add(key)
                    End If
                Else
                    file.Errors.Add(NewError(lineNo, "FILE", "E1", "Text before the first stanza is not a header line"))
                End If

                Continue For
            End If

            Dim fm = FieldLine.Match(line)

            If fm.Success Then
                Dim field = fm.Groups(1).Value
                Dim value = fm.Groups(2).Value.Trim()
                Dim index = Array.IndexOf(FieldOrder, field)

                If index < 0 Then
                    file.Errors.Add(NewError(lineNo, "STANZA", "E3", "Unknown field '" & field & "'"))
                    currentField = Nothing
                    Continue For
                End If

                If stanza.HasField(field) Then
                    file.Errors.Add(NewError(lineNo, "STANZA", "E3", "Duplicate field '" & field & "'"))
                    currentField = Nothing
                    Continue For
                End If

                If index < lastFieldIndex Then file.Errors.Add(NewError(lineNo, "STANZA", "E3", "Field '" & field & "' is out of order"))
                lastFieldIndex = index

                If (field = "Values" OrElse field = "References") AndAlso value <> "" Then
                    file.Errors.Add(NewError(lineNo, "STANZA", "E3", "Field '" & field & "' must have no text on its line"))
                    value = ""
                End If

                stanza.FieldsByName(field) = value
                stanza.FieldOrder.Add(field)
                If field = "Status" Then stanza.Status = value
                currentField = field
                Continue For
            End If

            If line.StartsWith("- ") Then
                Dim item = line.Substring(2).Trim()

                If currentField = "Values" Then
                    Dim sep = item.IndexOf(": ", StringComparison.Ordinal)

                    If sep < 1 Then
                        file.Errors.Add(NewError(lineNo, "STANZA", "E3", "Value bullet needs ""<value>: <note>"""))
                    Else
                        stanza.Values.Add(New OptionHelpValue With {.Value = item.Substring(0, sep), .Note = item.Substring(sep + 2).Trim(), .Line = lineNo})
                    End If
                ElseIf currentField = "References" Then
                    stanza.References.Add(item)
                    If Not Regex.IsMatch(item, "^https?://\S+$") Then file.Errors.Add(NewError(lineNo, "STANZA", "E13", "Reference must be an http or https URL: '" & item & "'"))
                Else
                    file.Errors.Add(NewError(lineNo, "STANZA", "E3", "Bullet outside Values or References"))
                End If

                Continue For
            End If

            If currentField IsNot Nothing AndAlso currentField <> "Values" AndAlso currentField <> "References" Then
                stanza.FieldsByName(currentField) = (stanza.FieldsByName(currentField) & " " & trimmed).Trim()
            Else
                file.Errors.Add(NewError(lineNo, "STANZA", "E3", "Text outside a field"))
            End If
        Next

        Validate(file)
        Return file
    End Function

    Private Shared Sub Validate(file As OptionHelpFile)
        Dim h = file.Header
        Dim errors = file.Errors
        Dim isShared = SharedIds.Contains(file.Encoder)

        If Not h.ContainsKey("Schema") OrElse h("Schema") <> "1" Then errors.Add(NewError(1, "FILE", "E1", "Schema must be 1"))

        If Not h.ContainsKey("Encoder") Then
            errors.Add(NewError(1, "FILE", "E1", "Encoder header is required"))
        ElseIf Not Regex.IsMatch(h("Encoder"), EncoderPattern) OrElse h("Encoder") <> file.Encoder Then
            errors.Add(NewError(1, "FILE", "E1", "Encoder '" & h("Encoder") & "' must match the file name '" & file.Encoder & "'"))
        End If

        If Not h.ContainsKey("Locale") Then
            errors.Add(NewError(1, "FILE", "E1", "Locale header is required"))
        ElseIf h("Locale") <> file.Locale Then
            errors.Add(NewError(1, "FILE", "E1", "Locale '" & h("Locale") & "' must match the file name locale '" & file.Locale & "'"))
        End If

        If Not h.ContainsKey("Title") Then errors.Add(NewError(1, "FILE", "E1", "Title header is required"))

        Dim anyReviewed = file.Stanzas.Any(Function(s) s.Status = "reviewed")

        If Not isShared Then
            For Each key In {"Source", "Allowed-Missing", "Minimum-Reviewed", "Reviewed-Complete"}
                If Not h.ContainsKey(key) Then errors.Add(NewError(1, "FILE", "E1", key & " header is required for an encoder file"))
            Next

            For Each key In {"Allowed-Missing", "Minimum-Reviewed"}
                If h.ContainsKey(key) AndAlso Not Regex.IsMatch(h(key), "^\d+$") Then errors.Add(NewError(1, "FILE", "E1", key & " must be a non-negative integer"))
            Next

            If h.ContainsKey("Reviewed-Complete") AndAlso h("Reviewed-Complete") <> "true" AndAlso h("Reviewed-Complete") <> "false" Then
                errors.Add(NewError(1, "FILE", "E1", "Reviewed-Complete must be true or false"))
            End If

            If anyReviewed Then
                Dim missing = {"Verified-Encoder-Version", "Verified-Encoder-Build", "Verified-Date", "Documentation"}.Where(Function(k) Not h.ContainsKey(k)).ToArray()
                If missing.Length > 0 Then errors.Add(NewError(1, "FILE", "E1", "Reviewed stanzas require headers: " & String.Join(", ", missing)))
            End If

            If h.ContainsKey("Verified-Date") AndAlso Not Regex.IsMatch(h("Verified-Date"), "^\d{4}-\d{2}-\d{2}$") Then errors.Add(NewError(1, "FILE", "E1", "Verified-Date must be an ISO date"))
            If h.ContainsKey("Documentation") AndAlso Not Regex.IsMatch(h("Documentation"), "^https?://\S+$") Then errors.Add(NewError(1, "FILE", "E1", "Documentation must be an http or https URL"))

            If h.ContainsKey("Inherits") AndAlso (Not Regex.IsMatch(h("Inherits"), EncoderPattern) OrElse SharedIds.Contains(h("Inherits"))) Then
                errors.Add(NewError(1, "FILE", "E1", "Inherits must name an encoder file"))
            End If
        ElseIf h.ContainsKey("Inherits") Then
            errors.Add(NewError(1, "FILE", "E1", "Shared files cannot inherit"))
        End If

        Dim seen As New HashSet(Of String)(StringComparer.Ordinal)

        For Each s In file.Stanzas
            If Not seen.Add(s.Id) Then errors.Add(NewError(s.Line, "FILE", "E8", "Duplicate stanza id '" & s.Id & "'"))
            Dim hasUse = s.HasField("Use")

            If hasUse Then
                For Each k In s.FieldOrder
                    If k <> "Label" AndAlso k <> "Use" AndAlso k <> "Status" Then errors.Add(NewError(s.Line, "STANZA", "E3", "Field '" & k & "' is not allowed with Use"))
                Next
            End If

            If Not s.HasField("Status") Then
                errors.Add(NewError(s.Line, "STANZA", "E3", "Status is required"))
            ElseIf s.Status <> "draft" AndAlso s.Status <> "reviewed" Then
                errors.Add(NewError(s.Line, "STANZA", "E3", "Status must be draft or reviewed, not '" & s.Status & "'"))
            End If

            If Not hasUse Then
                If Not s.HasField("Summary") OrElse s.GetField("Summary") = "" Then
                    errors.Add(NewError(s.Line, "STANZA", "E2", "Summary is required"))
                ElseIf Not s.GetField("Summary").EndsWith(".") Then
                    errors.Add(NewError(s.Line, "STANZA", "E2", "Summary must end with a period"))
                End If

                If s.Status = "reviewed" AndAlso Not s.HasField("When to change") Then errors.Add(NewError(s.Line, "STANZA", "E2", "When to change is required on a reviewed stanza"))
            End If

            For Each k In s.FieldOrder
                Dim limit As Integer

                If FieldLimits.TryGetValue(k, limit) AndAlso s.GetField(k).Length > limit Then
                    errors.Add(NewError(s.Line, "STANZA", "E2", k & " exceeds " & limit & " characters"))
                End If

                If InlineTextFields.Contains(k) Then
                    Dim m = TestInline(s.GetField(k))
                    If m IsNot Nothing Then errors.Add(NewError(s.Line + s.FieldOrder.IndexOf(k) + 1, "STANZA", "E13", k & ": " & m))
                End If
            Next

            For Each v In s.Values
                If v.Note.Length > NoteLimit Then errors.Add(NewError(v.Line, "STANZA", "E2", "Value note exceeds " & NoteLimit & " characters"))
                Dim m = TestInline(v.Note)
                If m IsNot Nothing Then errors.Add(NewError(v.Line, "STANZA", "E13", "Value note: " & m))
            Next
        Next
    End Sub

    Shared Function TestInline(text As String) As String
        If text Is Nothing Then Return Nothing
        Dim ticks = text.Count(Function(c) c = "`"c)
        If ticks Mod 2 = 1 Then Return "Unmatched backtick"
        Dim stripped = LinkRegex.Replace(text, "")
        If stripped.Contains("[") OrElse stripped.Contains("]") Then Return "Malformed link; only [text](http://...) or [text](https://...) is allowed"
        Return Nothing
    End Function

    Shared Function PlainText(text As String) As String
        If text Is Nothing Then Return ""
        Return LinkRegex.Replace(text, "$1").Replace("`", "")
    End Function

    ''' <summary>Splits text into text, code, and link nodes. Unbalanced markup is treated as text.</summary>
    Shared Function ParseInline(text As String) As List(Of OptionHelpNode)
        Dim nodes As New List(Of OptionHelpNode)
        If String.IsNullOrEmpty(text) Then Return nodes
        Dim pos = 0

        For Each m As Match In LinkRegex.Matches(text)
            If m.Index > pos Then AddTextAndCode(nodes, text.Substring(pos, m.Index - pos))
            nodes.Add(New OptionHelpNode With {.Kind = "link", .Text = m.Groups(1).Value, .Url = m.Groups(2).Value})
            pos = m.Index + m.Length
        Next

        If pos < text.Length Then AddTextAndCode(nodes, text.Substring(pos))
        Return nodes
    End Function

    Private Shared Sub AddTextAndCode(nodes As List(Of OptionHelpNode), segment As String)
        Dim parts = segment.Split("`"c)

        If parts.Length Mod 2 = 0 Then
            nodes.Add(OptionHelpNode.TextNode(segment))
            Exit Sub
        End If

        For i = 0 To parts.Length - 1
            If parts(i) = "" Then Continue For
            nodes.Add(New OptionHelpNode With {.Kind = If(i Mod 2 = 1, "code", "text"), .Text = parts(i)})
        Next
    End Sub

    Private Shared Function NewError(line As Integer, level As String, code As String, message As String) As OptionHelpError
        Return New OptionHelpError With {.Line = line, .Level = level, .Code = code, .Message = message}
    End Function
End Class

Public Class OptionHelpDump
    Shared Function Write(file As OptionHelpFile) As String
        Dim sb As New StringBuilder
        sb.Append("FILE ").Append(file.Name).Append(vbLf)

        For Each key In file.HeaderOrder
            sb.Append("H ").Append(key).Append("=").Append(file.Header(key)).Append(vbLf)
        Next

        For Each s In file.Stanzas
            sb.Append("S ").Append(s.Id).Append(" ").Append(s.Line).Append(vbLf)

            For Each f In s.FieldOrder
                sb.Append("F ").Append(f).Append("=").Append(s.FieldsByName(f)).Append(vbLf)

                If f = "Values" Then
                    For Each v In s.Values
                        sb.Append("V ").Append(v.Value).Append("=").Append(v.Note).Append(vbLf)
                    Next
                End If

                If f = "References" Then
                    For Each r In s.References
                        sb.Append("R ").Append(r).Append(vbLf)
                    Next
                End If
            Next
        Next

        For Each e In file.Errors.OrderBy(Function(x) x.Line).ThenBy(Function(x) x.Code, StringComparer.Ordinal)
            sb.Append("ERR ").Append(e.Line).Append(" ").Append(e.Level).Append(" ").Append(e.Code).Append(vbLf)
        Next

        sb.Append("END").Append(vbLf)
        Return sb.ToString()
    End Function
End Class

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
                    If AscW(c) < 32 Then sb.Append("\u" & AscW(c).ToString("x4")) Else sb.Append(c)
            End Select
        Next

        Return sb.Append("""").ToString()
    End Function

    Shared Function Array(values As IEnumerable(Of String)) As String
        If values Is Nothing Then Return "[]"
        Return "[" & String.Join(",", values.Select(Function(v) Quote(v))) & "]"
    End Function
End Class
```

Then delete the temporary `OptionHelpJson` class from `Source/Video/VideoEncoderCommandLine.vb` (the one plan 1 Task 5 added at the end of the namespace) and add `<Compile Include="General\OptionHelp.vb" />` to `Source/StaxRip.vbproj` right after `<Compile Include="General\Help.vb" />`.

- [ ] **Step 3: Build the harness and run it against the fixtures (chain cases will fail until Task 2)**

Run the harness build command. Expected: the build FAILS with `'OptionHelpCatalog' is not declared` because `Program.vb` references the catalog. Temporarily comment out the chain block in `Program.vb` (from `Dim chainDir` to the end of that `For Each line` loop) to check the parser alone, build again, then run:

```powershell
& 'Source\obj\OptionHelpTests\bin\OptionHelpTests.exe' 'Source\Tools\OptionHelp\fixtures'
```

Expected: `harness: 9 cases, 0 failures`, exit code 0. If a dump differs, the PowerShell parser from plan 1 is the reference: compare `Check-OptionHelp.ps1 -Dump <fixture>` with the VB dump line by line and fix the VB side. Restore the chain block before committing (the build will fail again until Task 2 lands; that is expected and the commit is still made).

- [ ] **Step 4: Build StaxRip**

Run the StaxRip build command. Expected: exit code 0. (`OptionHelp.vb` compiles inside StaxRip; nothing uses the catalog yet.)

- [ ] **Step 5: Commit**

```bash
git add Source/General/OptionHelp.vb Source/Tests/OptionHelp Source/StaxRip.vbproj Source/Video/VideoEncoderCommandLine.vb
git commit -m "General: add the option-help parser and its standalone harness" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Catalog: chain resolution, draft shadowing, aliases, lookups, embedded loading

**Files:**
- Modify: `Source/General/OptionHelp.vb` (append `OptionHelpResolution` and `OptionHelpCatalog`)

**Interfaces:**
- Produces: `OptionHelpCatalog.Get(encoderId As String) As OptionHelpCatalog` (cached; `Nothing` when no help or chain invalid), `OptionHelpCatalog.FromFiles(files As IDictionary(Of String, Byte()), encoderId As String) As OptionHelpCatalog`, `OptionHelpCatalog.Log As Action(Of String)` (shared), `Resolve(identity As String) As OptionHelpResolution` (`Outcome` is `reviewed`, `alias`, `draft`, or `none`; `Stanza` is the displayable stanza for `reviewed` and `alias`; `FileName`), `Lookup(id As String) As OptionHelpStanza` (reviewed only, aliases followed, all loaded files including `concepts` and `shared`), `ValueNote(stanza As OptionHelpStanza, emittedValue As String) As String`, `Shared SearchText(stanza As OptionHelpStanza, identity As String) As String` (lower-case).

- [ ] **Step 1: Append the catalog**

Append to `Source/General/OptionHelp.vb`:

```vb
Public Class OptionHelpResolution
    Property Outcome As String = "none"
    Property FileName As String
    Property Stanza As OptionHelpStanza
    Property AliasStanza As OptionHelpStanza
End Class

Public Class OptionHelpCatalog
    Public Shared Property Log As Action(Of String)
    Private Shared ReadOnly Cache As New Dictionary(Of String, OptionHelpCatalog)(StringComparer.Ordinal)
    Private Shared ReadOnly CacheLock As New Object
    Private ReadOnly Files As New Dictionary(Of String, OptionHelpFile)(StringComparer.Ordinal)

    Public ReadOnly Property EncoderId As String
    Public ReadOnly Property Chain As New List(Of OptionHelpFile)

    Private Sub New(encoderId As String)
        Me.EncoderId = encoderId
    End Sub

    Public Shared Function [Get](encoderId As String) As OptionHelpCatalog
        If String.IsNullOrEmpty(encoderId) Then Return Nothing

        SyncLock CacheLock
            Dim cached As OptionHelpCatalog = Nothing
            If Cache.TryGetValue(encoderId, cached) Then Return cached
            Dim catalog = FromFiles(ReadEmbedded(), encoderId)
            Cache(encoderId) = catalog
            Return catalog
        End SyncLock
    End Function

    ''' <summary>Reads every embedded resource whose name contains ".OptionHelp." and ends with ".md", keyed by file name.</summary>
    Public Shared Function ReadEmbedded() As Dictionary(Of String, Byte())
        Dim result As New Dictionary(Of String, Byte())(StringComparer.Ordinal)
        Dim asm = GetType(OptionHelpCatalog).Assembly
        Const marker = ".OptionHelp."

        For Each res In asm.GetManifestResourceNames()
            Dim at = res.IndexOf(marker, StringComparison.Ordinal)
            If at < 0 OrElse Not res.EndsWith(".md", StringComparison.Ordinal) Then Continue For

            Using stream = asm.GetManifestResourceStream(res)
                Using ms As New MemoryStream
                    stream.CopyTo(ms)
                    result(res.Substring(at + marker.Length)) = ms.ToArray()
                End Using
            End Using
        Next

        Return result
    End Function

    Public Shared Function FromFiles(files As IDictionary(Of String, Byte()), encoderId As String) As OptionHelpCatalog
        Dim catalog As New OptionHelpCatalog(encoderId)

        For Each kv In files
            Dim parsed = OptionHelpParser.ParseBytes(kv.Value, kv.Key)
            If parsed.Locale <> "en" Then Continue For

            For Each e In parsed.Errors
                Log?.Invoke("OptionHelp " & kv.Key & ":" & e.Line & " " & e.Code & " " & e.Message)
            Next

            catalog.Files(parsed.Encoder) = parsed
        Next

        Dim current = encoderId
        Dim seen As New HashSet(Of String)(StringComparer.Ordinal)

        While Not String.IsNullOrEmpty(current)
            If Not seen.Add(current) Then
                Log?.Invoke("OptionHelp: inheritance cycle at '" & current & "'")
                Return Nothing
            End If

            Dim f As OptionHelpFile = Nothing

            If Not catalog.Files.TryGetValue(current, f) Then
                Log?.Invoke("OptionHelp: no file for encoder '" & current & "'")
                Return Nothing
            End If

            catalog.Chain.Add(f)
            current = f.Inherits
        End While

        Dim staxrip As OptionHelpFile = Nothing
        If catalog.Files.TryGetValue("staxrip", staxrip) Then catalog.Chain.Add(staxrip)

        For Each f In catalog.Chain
            If f.HasFileErrors Then
                Log?.Invoke("OptionHelp: '" & f.Name & "' has file-level errors; help for '" & encoderId & "' is disabled")
                Return Nothing
            End If
        Next

        Return catalog
    End Function

    Private Function FindAny(id As String) As OptionHelpStanza
        If String.IsNullOrEmpty(id) Then Return Nothing
        Dim fileId = id.Split("."c)(0)
        Dim f As OptionHelpFile = Nothing
        If Not Files.TryGetValue(fileId, f) OrElse f.HasFileErrors Then Return Nothing
        Return f.FindStanza(id)
    End Function

    Public Function Resolve(identity As String) As OptionHelpResolution
        Dim r As New OptionHelpResolution
        If String.IsNullOrEmpty(identity) OrElse identity = "none" Then Return r

        For Each f In Chain
            Dim s = f.FindStanza(identity)
            If s Is Nothing Then Continue For
            r.FileName = f.Name

            If Not s.IsReviewed Then
                r.Outcome = "draft"
                r.Stanza = s
                Return r
            End If

            If s.HasField("Use") Then
                Dim target = FindAny(s.Use)

                If target Is Nothing OrElse Not target.IsReviewed OrElse target.HasField("Use") Then
                    r.Outcome = "draft"
                    r.Stanza = s
                    Return r
                End If

                r.Outcome = "alias"
                r.Stanza = target
                r.AliasStanza = s
                r.FileName = target.FileName
                Return r
            End If

            r.Outcome = "reviewed"
            r.Stanza = s
            Return r
        Next

        Return r
    End Function

    ''' <summary>A reviewed stanza by id from any loaded file, for Related links. Aliases are followed once.</summary>
    Public Function Lookup(id As String) As OptionHelpStanza
        Dim s = FindAny(id)
        If s Is Nothing OrElse Not s.IsReviewed Then Return Nothing

        If s.HasField("Use") Then
            Dim target = FindAny(s.Use)
            If target Is Nothing OrElse Not target.IsReviewed OrElse target.HasField("Use") Then Return Nothing
            Return target
        End If

        Return s
    End Function

    Public Function ValueNote(stanza As OptionHelpStanza, emittedValue As String) As String
        If stanza Is Nothing OrElse emittedValue Is Nothing Then Return Nothing

        For Each v In stanza.Values
            If v.Value = emittedValue Then Return v.Note
        Next

        Return Nothing
    End Function

    Public Shared Function SearchText(stanza As OptionHelpStanza, identity As String) As String
        Dim parts As New List(Of String) From {identity, stanza.Id, stanza.Label, stanza.Summary, stanza.UsedWhen, stanza.WhenToChange, stanza.Example}
        parts.AddRange(stanza.Values.Select(Function(v) v.Note))
        parts.AddRange(stanza.Related)
        Return String.Join(" ", parts.Where(Function(p) Not String.IsNullOrEmpty(p)).Select(Function(p) OptionHelpParser.PlainText(p))).ToLowerInvariant()
    End Function
End Class
```

- [ ] **Step 2: Build the harness and run all cases**

Restore the chain block in `Program.vb` if it is still commented out, build the harness, run it. Expected: `harness: 18 cases, 0 failures` (9 dumps + 9 chain cases), matching the validator's chain expectations exactly.

- [ ] **Step 3: Build StaxRip, commit**

Run the StaxRip build (exit code 0), then:

```bash
git add Source/General/OptionHelp.vb Source/Tests/OptionHelp/Program.vb
git commit -m "General: resolve option help through the inheritance chain with draft shadowing" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: `ExportOptionHelpFacts` command and the reconciliation run

**Files:**
- Modify: `Source/General/GlobalCommands.vb` (add the command after `ImportVideoEncoderCommandLineFromTextFile`, line 477-480)
- Modify: `Docs/Usage/Command-Line-Interface.md` (insert after the `### -ExitWithoutSaving` section, before `### -ExtractHdrMetadata:sourcePath`)

**Interfaces:**
- Produces: the StaxRip command `-ExportOptionHelpFacts:<filePath>` writing `{"schemaVersion":1,"encoders":[...],"errors":[...]}`; consumed by `Check-OptionHelp.ps1 -CompareFacts` (plan 1 Task 4).
- Consumes: `CommandLineParams.ExportOptionHelpFacts()` and `OptionHelpJson` (plan 1 Task 5, plan 2 Task 1).

- [ ] **Step 1: Add the command**

In `Source/General/GlobalCommands.vb`, after the `ImportVideoEncoderCommandLineFromTextFile` method:

```vb
    <Command("Writes the option help facts of every encoder with a help file to a JSON file for Check-OptionHelp.ps1 -CompareFacts.")>
    Sub ExportOptionHelpFacts(<DispName("File Path")> filePath As String)
        Dim sb As New StringBuilder("{""schemaVersion"":1,""encoders"":[")
        Dim first = True
        Dim problems As New List(Of String)

        For Each t In GetType(CommandLineParams).Assembly.GetTypes().OrderBy(Function(x) x.FullName, StringComparer.Ordinal)
            If t.IsAbstract OrElse Not GetType(CommandLineParams).IsAssignableFrom(t) Then Continue For
            If t.GetConstructor(Type.EmptyTypes) Is Nothing Then Continue For

            Try
                Dim instance = DirectCast(Activator.CreateInstance(t), CommandLineParams)
                If String.IsNullOrEmpty(instance.OptionHelpId) Then Continue For
                If Not first Then sb.Append(",")
                first = False
                sb.Append(instance.ExportOptionHelpFacts())
            Catch ex As Exception
                problems.Add(t.Name & ": " & ex.Message)
            End Try
        Next

        sb.Append("],""errors"":" & OptionHelpJson.Array(problems) & "}")
        File.WriteAllText(filePath, sb.ToString(), New UTF8Encoding(False))
    End Sub
```

`GlobalCommands.vb` already imports `System.Text`; `System.IO` comes from the project imports; `CommandLineParams` needs `Imports StaxRip.VideoEncoderCommandLine` at the top of the file if it is not already there (add it after `Imports StaxRip.UI`).

- [ ] **Step 2: Document the command**

Insert into `Docs/Usage/Command-Line-Interface.md` after the `-ExitWithoutSaving` section:

```markdown
### -ExportOptionHelpFacts:filePath

Writes the option help facts of every encoder with a help file to a JSON file for Check-OptionHelp.ps1 -CompareFacts.

| Parameter |
| --- |
| File Path \<string\> |

```

- [ ] **Step 3: Build, run the export, reconcile**

Build StaxRip. Then prepare a runnable dev build once (ignored paths only):

```powershell
cmd /c mklink /J "Source\bin\Apps" "C:\StaxRip\Apps"
```

The junction lets the dev build find the tools; do not run tool updates from the dev build, because they would write into the installed `Apps` tree. Launch `Source\bin\StaxRip.exe` once; on first start it asks for a settings directory because the startup path is new; choose a fresh folder under `J:\TEMP\claude\...\scratchpad\StaxRipDevSettings` so the installed settings stay untouched. Then close it and run:

```powershell
& 'Source\bin\StaxRip.exe' '-ExportOptionHelpFacts:J:\TEMP\claude\c--DEV-StaxRip\cd295f73-6a7a-4720-87b2-705b360e3125\scratchpad\facts.json' '-Exit'
pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -CompareFacts 'J:\TEMP\claude\c--DEV-StaxRip\cd295f73-6a7a-4720-87b2-705b360e3125\scratchpad\facts.json'
```

Expected: `facts: no differences`, exit code 0. If the CLI run opens the main window instead of exiting, run the command from the running application (the command menu editor lists it under its description) and then close the window; the comparison is what matters. If differences appear, they are real: the text extractor and the application disagree, and the extractor (plan 1 Task 3) must be fixed to match the application, never the reverse.

- [ ] **Step 4: Commit**

```bash
git add Source/General/GlobalCommands.vb Docs/Usage/Command-Line-Interface.md
git commit -m "Commands: export option help facts for the validator's reconciliation" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Help window hygiene and the rendering trust boundary

**Files:**
- Modify: `Source/General/General.vb` (`HelpDocument`, lines 439-740)
- Modify: `Source/Forms/HelpForm.vb`
- Modify: `Source/General/OptionHelp.vb` (append `OptionHelpRoute`)

**Interfaces:**
- Produces: `HelpDocument.Path As String` (read-only), `HelpDocument.WriteNodes(elementName As String, nodes As IEnumerable(Of OptionHelpNode))`, `HelpDocument.WriteNodesTable(rows As IEnumerable(Of KeyValuePair(Of String, IEnumerable(Of OptionHelpNode))))`, `HelpDocument.WriteLinkList(links As IEnumerable(Of KeyValuePair(Of String, String)))`; `HelpForm.RouteAction As Action(Of OptionHelpRoute)`; `OptionHelpRoute.Kind` (`ConsoleHelp` or `Option`), `OptionHelpRoute.Id`, `OptionHelpRoute.TryParse(uri As Uri, ByRef route As OptionHelpRoute) As Boolean`.

- [ ] **Step 1: Route type**

Append to `Source/General/OptionHelp.vb`:

```vb
Public Class OptionHelpRoute
    Property Kind As String
    Property Id As String

    ''' <summary>Accepts exactly staxrip://console-help and staxrip://option/&lt;id&gt;; everything else is rejected.</summary>
    Shared Function TryParse(uri As Uri, ByRef route As OptionHelpRoute) As Boolean
        route = Nothing
        If uri Is Nothing OrElse Not uri.IsAbsoluteUri OrElse uri.Scheme <> "staxrip" Then Return False
        Dim path = uri.AbsolutePath.Trim("/"c)

        If uri.Host = "console-help" AndAlso path = "" Then
            route = New OptionHelpRoute With {.Kind = "ConsoleHelp"}
            Return True
        End If

        If uri.Host = "option" AndAlso Regex.IsMatch(path, OptionHelpParser.IdPattern) Then
            route = New OptionHelpRoute With {.Kind = "Option", .Id = path}
            Return True
        End If

        Return False
    End Function
End Class
```

- [ ] **Step 2: `HelpDocument` changes**

In `Source/General/General.vb`, class `HelpDocument`:

1. Change `Private ReadOnly Path As String` to `Public ReadOnly Property Path As String` and keep the constructor assignment (`Me.Path = path` becomes `_Path = path`; with an auto-property, write `Path = path` in the constructor, which VB allows for read-only auto-properties).
2. In `WriteStart(title, showTitle)`, delete the line `@import url(https://fonts.googleapis.com/css?family=Lato:700,900);` from the style block, and after `Writer.WriteStartElement("head")` add:

```vb
        Writer.WriteStartElement("meta")
        Writer.WriteAttributeString("charset", "utf-8")
        Writer.WriteEndElement()
```

3. Add these methods after `WriteTable(title, text, list, sort)`:

```vb
    Private Shared Function IsAllowedHref(url As String) As Boolean
        If url Is Nothing Then Return False
        Return url.StartsWith("http://", StringComparison.Ordinal) OrElse
               url.StartsWith("https://", StringComparison.Ordinal) OrElse
               url.StartsWith("staxrip://", StringComparison.Ordinal)
    End Function

    Private Sub WriteNodeContent(nodes As IEnumerable(Of OptionHelpNode))
        For Each n In nodes
            Select Case n.Kind
                Case "code"
                    Writer.WriteElementString("code", n.Text)
                Case "link"
                    If IsAllowedHref(n.Url) Then
                        Writer.WriteStartElement("a")
                        Writer.WriteAttributeString("href", n.Url)
                        Writer.WriteString(n.Text)
                        Writer.WriteEndElement()
                    Else
                        Writer.WriteString(n.Text)
                    End If
                Case Else
                    Writer.WriteString(n.Text)
            End Select
        Next
    End Sub

    ''' <summary>Writes authored text as encoded nodes. Never passes authored text to WriteRaw.</summary>
    Sub WriteNodes(elementName As String, nodes As IEnumerable(Of OptionHelpNode))
        Writer.WriteStartElement(elementName)
        WriteNodeContent(nodes)
        Writer.WriteEndElement()
    End Sub

    Sub WriteNodesTable(rows As IEnumerable(Of KeyValuePair(Of String, IEnumerable(Of OptionHelpNode))))
        Writer.WriteStartElement("table")
        Writer.WriteAttributeString("border", "1")
        Writer.WriteAttributeString("cellspacing", "0")
        Writer.WriteAttributeString("cellpadding", "3")

        For Each row In rows
            Writer.WriteStartElement("tr")
            Writer.WriteElementString("td", row.Key)
            Writer.WriteStartElement("td")
            WriteNodeContent(row.Value)
            Writer.WriteEndElement()
            Writer.WriteEndElement()
        Next

        Writer.WriteEndElement()
    End Sub

    Sub WriteLinkList(links As IEnumerable(Of KeyValuePair(Of String, String)))
        Writer.WriteStartElement("ul")

        For Each link In links
            Writer.WriteStartElement("li")

            If IsAllowedHref(link.Value) Then
                Writer.WriteStartElement("a")
                Writer.WriteAttributeString("href", link.Value)
                Writer.WriteString(link.Key)
                Writer.WriteEndElement()
            Else
                Writer.WriteString(link.Key)
            End If

            Writer.WriteEndElement()
        Next

        Writer.WriteEndElement()
    End Sub
```

`XmlTextWriter.WriteString` and `WriteAttributeString` encode `<`, `>`, `&`, and quotes, which is the boundary.

- [ ] **Step 3: `HelpForm` changes**

In `Source/Forms/HelpForm.vb`:

1. Add fields and a property after `Private DocumentValue As HelpDocument`:

```vb
    Private DocumentPath As String
    Property RouteAction As Action(Of OptionHelpRoute)
```

2. In the `Doc` getter, replace the two lines that create the path and register the `MainForm.Disposed` handler with:

```vb
                Dim path = IO.Path.Combine(Folder.Temp, Guid.NewGuid.ToString + ".htm")
                DocumentPath = path
                DocumentValue = New HelpDocument(path)
```

3. Replace `OnFormClosed`:

```vb
    Protected Overrides Sub OnFormClosed(e As FormClosedEventArgs)
        If DocumentPath <> "" AndAlso File.Exists(DocumentPath) Then
            Try
                FileHelp.Delete(DocumentPath)
            Catch
            End Try
        End If

        Dispose()
    End Sub
```

4. Replace `Browser_Navigating`:

```vb
    Sub Browser_Navigating(sender As Object, e As WebBrowserNavigatingEventArgs) Handles Browser.Navigating
        Dim url = e.Url
        If url Is Nothing OrElse Not url.IsAbsoluteUri Then Exit Sub

        Select Case url.Scheme
            Case "staxrip"
                e.Cancel = True
                Dim route As OptionHelpRoute = Nothing

                If OptionHelpRoute.TryParse(url, route) Then
                    RouteAction?.Invoke(route)
                Else
                    g.WriteDebugLog("HelpForm: rejected internal route " + url.ToString)
                End If
            Case "http", "https"
                e.Cancel = True
                g.ShellExecute(url.ToString)
            Case "about", "file"
                ' The control's blank page and local help documents.
            Case Else
                e.Cancel = True
                g.WriteDebugLog("HelpForm: blocked navigation to " + url.Scheme + ":")
        End Select
    End Sub
```

`file` stays allowed because every existing help window navigates to its own temp document and some help content links to local files; authored option-help text cannot produce a `file` link because `WriteNodeContent` only emits `http`, `https`, and `staxrip` hrefs. `javascript`, `data`, `res`, and unknown schemes are cancelled for every help window.

- [ ] **Step 4: Build, check an existing help window, commit**

Build StaxRip (exit code 0). Launch the dev build, open any options dialog, use the menu `Help about this dialog`: the window renders as before (Tahoma text, no font request), and after closing it the `.htm` file is gone from `%TEMP%`'s StaxRip temp folder (`Folder.Temp`). Then:

```bash
git add Source/General/General.vb Source/Forms/HelpForm.vb Source/General/OptionHelp.vb
git commit -m "Help: encode authored text, type internal links, delete temp documents on close" -m "Removes the unused Google Fonts import and adds a charset declaration. Applies to every help window." -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: `CommandLineForm`: targets per item, tooltips, accessibility, value notes, search, F1

**Files:**
- Modify: `Source/Forms/CommandLineForm.vb` (fields, `Sub New`, `InitUI` lines 132-329, `Item` class, `CommandLineForm_HelpRequested` line 337, `cbGoTo_TextChanged` line 381)

**Interfaces:**
- Produces: `Item.Targets As List(Of Control)`, `Item.Stanza As OptionHelpStanza`, `Item.Identity As String`; `Private Catalog As OptionHelpCatalog`; `AttachOptionHelp(item As Item)`; `FindFocusedItem() As Item`; `FindItemByIdentity(id As String) As Item`; `ShowOptionHelp(item As Item)` is declared here as a stub and implemented in Task 7; `SetDescription(item As Item)` is declared here as a stub and implemented in Task 6.
- Consumes: `OptionHelpCatalog`, `OptionHelpParser.PlainText`, `OptionParam.GetEmittedValue`, `CommandLineParam.OptionHelpIdentity`, `CommandLineParams.OptionHelpId`.

- [ ] **Step 1: Fields and construction**

Add after `Private GoToComboBoxCts As CancellationTokenSource`:

```vb
    Private OptionHelpTips As ToolTip
    Private Catalog As OptionHelpCatalog
```

In `Sub New`, after `Me.Params = params` and before `InitUI()`:

```vb
        OptionHelpTips = New ToolTip(components) With {.AutoPopDelay = 20000, .InitialDelay = 700, .ReshowDelay = 300}
        OptionHelpCatalog.Log = AddressOf g.WriteDebugLog
        Catalog = OptionHelpCatalog.Get(params.OptionHelpId)
```

- [ ] **Step 2: Replace the `Item` class**

```vb
    Public Class Item
        Property Page As SimpleUI.FlowPage
        Property Control As Control
        Property Param As CommandLineParam
        Property Targets As New List(Of Control)
        Property Stanza As OptionHelpStanza
        Property Identity As String
    End Class
```

- [ ] **Step 3: Replace `InitUI`**

Replace the whole `Sub InitUI()` with:

```vb
    Sub InitUI()
        Dim flowPanels As New List(Of Control)
        Dim currentFlow As SimpleUI.FlowPage = Nothing

        For x = 0 To Params.Items.Count - 1
            Dim param = Params.Items(x)
            Dim parent As FlowLayoutPanelEx = SimpleUI.GetFlowPage(param.Path)
            currentFlow = DirectCast(parent, SimpleUI.FlowPage)
            Dim helpControl As Control = Nothing
            Dim targets As New List(Of Control)

            If Not flowPanels.Contains(parent) Then
                flowPanels.Add(parent)
                parent.SuspendLayout()
            End If

            Dim help As String = Nothing

            If param.Switch <> "" Then
                help += param.Switch + BR
            End If

            If param.HelpSwitch <> "" Then
                help += param.HelpSwitch + BR
            End If

            If param.NoSwitch <> "" Then
                help += param.NoSwitch + BR
            End If

            Dim switches = param.Switches

            If Not switches.NothingOrEmpty Then
                help += switches.Join(BR) + BR
            End If

            help += BR

            If TypeOf param Is NumParam Then
                Dim nParam = DirectCast(param, NumParam)

                If nParam.Config(0) > Double.MinValue Then
                    help += "Minimum: " & nParam.Config(0) & BR
                End If

                If nParam.Config(1) < Double.MaxValue Then
                    help += "Maximum: " & nParam.Config(1) & BR
                End If
            End If

            help += BR

            If Not param.URLs.NothingOrEmpty Then
                help += String.Join(BR, param.URLs.Select(Function(val) "[" + val + " " + val + "]"))
            End If

            If param.Help <> "" Then
                help += param.Help
            End If

            If help <> "" Then
                If help.Contains(BR2 + BR) Then
                    help = help.Replace(BR2 + BR, BR2)
                End If

                If help.EndsWith(BR) Then
                    help = help.Trim
                End If
            End If

            Dim identity = param.OptionHelpIdentity(Params.OptionHelpId)
            Dim stanza As OptionHelpStanza = Nothing

            If Catalog IsNot Nothing Then
                Dim resolution = Catalog.Resolve(identity)

                If resolution.Outcome = "reviewed" OrElse resolution.Outcome = "alias" Then
                    stanza = resolution.Stanza
                End If
            End If

            Dim item As New Item With {.Page = currentFlow, .Param = param, .Stanza = stanza, .Identity = identity}

            If param.Label <> "" Then
                SimpleUI.AddLabel(parent, param.Label).MarginTop = FontHeight \ 2
            End If

            If TypeOf param Is LineParam Then
                Dim line = SimpleUI.AddLine(parent, "", 2, 2)
                DirectCast(param, LineParam).InitParam(line)
            ElseIf TypeOf param Is BoolParam Then
                Dim checkBox = SimpleUI.AddBool(parent)
                checkBox.Text = param.Text

                If stanza IsNot Nothing Then
                    checkBox.HelpAction = Sub() ShowOptionHelp(item)
                ElseIf param.HelpSwitch <> "" Then
                    Dim helpOptions = param.GetSwitches
                    checkBox.HelpAction = Sub() Params.ShowHelp(helpOptions)
                Else
                    checkBox.Help = help
                End If

                checkBox.MarginLeft = param.LeftMargin
                DirectCast(param, BoolParam).InitParam(checkBox)
                helpControl = checkBox
                targets.Add(checkBox)
            ElseIf TypeOf param Is NumParam Then
                Dim tempNumParam = DirectCast(param, NumParam)
                Dim nParam = DirectCast(param, NumParam)
                Dim numBlock = SimpleUI.AddNum(parent)

                If param.Text <> "" Then
                    numBlock.Label.Text = If(param.Text.EndsWithEx(":"), param.Text, param.Text + ":")
                End If

                If stanza IsNot Nothing Then
                    numBlock.Label.HelpAction = Sub() ShowOptionHelp(item)
                ElseIf param.HelpSwitch <> "" Then
                    Dim helpOptions = param.GetSwitches
                    numBlock.Label.HelpAction = Sub() Params.ShowHelp(helpOptions)
                Else
                    numBlock.Label.Help = help
                End If

                numBlock.NumEdit.Config = nParam.Config

                If nParam.HintText <> "" Then
                    SimpleUI.AddLabel(numBlock, nParam.HintText)
                End If

                AddHandler numBlock.Label.MouseDoubleClick, Sub() tempNumParam.Value = tempNumParam.DefaultValue
                DirectCast(param, NumParam).InitParam(numBlock.NumEdit)
                helpControl = numBlock.Label
                targets.Add(numBlock.Label)
                targets.Add(numBlock.NumEdit)
            ElseIf TypeOf param Is OptionParam Then
                Dim tempOptionParam = DirectCast(param, OptionParam)
                Dim oParam = DirectCast(param, OptionParam)
                Dim menuBlock = SimpleUI.AddMenu(Of Integer)(parent)
                menuBlock.Label.Text = If(param.Text.EndsWith(":"), param.Text, param.Text + ":")

                If stanza IsNot Nothing Then
                    menuBlock.Label.HelpAction = Sub() ShowOptionHelp(item)
                    menuBlock.Button.HelpAction = Sub() ShowOptionHelp(item)
                ElseIf param.HelpSwitch <> "" Then
                    Dim helpOptions = param.GetSwitches
                    menuBlock.Label.HelpAction = Sub() Params.ShowHelp(helpOptions)
                    menuBlock.Button.HelpAction = Sub() Params.ShowHelp(helpOptions)
                Else
                    menuBlock.Help = help
                End If

                If oParam.HintText <> "" Then
                    SimpleUI.AddLabel(menuBlock, oParam.HintText)
                End If

                helpControl = menuBlock.Label
                targets.Add(menuBlock.Label)
                targets.Add(menuBlock.Button)
                AddHandler menuBlock.Label.MouseDoubleClick, Sub() tempOptionParam.ValueChangedUser(tempOptionParam.DefaultValue)

                Dim max = oParam.Options.Select(Function(txt) txt.Length).Max

                If tempOptionParam.Expanded OrElse max > 24 Then
                    menuBlock.Button.Expand = True
                End If

                For x2 = 0 To oParam.Options.Length - 1
                    Dim menuItem = menuBlock.Button.Add(oParam.Options(x2), x2)

                    If stanza IsNot Nothing Then
                        Dim note = Catalog.ValueNote(stanza, oParam.GetEmittedValue(x2))

                        If note <> "" Then
                            menuItem.ToolTipText = OptionHelpParser.PlainText(note)
                        End If
                    End If
                Next

                oParam.InitParam(menuBlock.Button)
            ElseIf TypeOf param Is StringParam Then
                Dim tempItem = DirectCast(param, StringParam)
                Dim textBlock As SimpleUI.TextBlock

                If tempItem.BrowseFileFilter <> "" Then
                    Dim textButtonBlock = SimpleUI.AddTextButton(parent)
                    textButtonBlock.BrowseFile(tempItem.BrowseFileFilter)
                    textBlock = textButtonBlock
                ElseIf tempItem.Menu <> "" Then
                    Dim textMenuBlock = SimpleUI.AddTextMenu(parent)
                    textMenuBlock.AddMenu(tempItem.Menu)
                    textBlock = textMenuBlock
                Else
                    textBlock = SimpleUI.AddText(parent)
                End If

                textBlock.Label.Text = If(param.Text.EndsWith(":"), param.Text, param.Text + ":")

                If stanza IsNot Nothing Then
                    textBlock.Label.HelpAction = Sub() ShowOptionHelp(item)
                ElseIf param.HelpSwitch <> "" Then
                    Dim helpOptions = param.GetSwitches
                    textBlock.Label.HelpAction = Sub() Params.ShowHelp(helpOptions)
                Else
                    textBlock.Label.Help = help
                End If

                helpControl = textBlock.Label
                targets.Add(textBlock.Label)
                targets.Add(textBlock.Edit)
                AddHandler textBlock.Label.MouseDoubleClick, Sub() tempItem.Value = tempItem.DefaultValue
                textBlock.Edit.Expand = tempItem.Expand
                tempItem.InitParam(textBlock)
            End If

            If helpControl IsNot Nothing Then
                item.Control = helpControl
                item.Targets.AddRange(targets)
                Items.Add(item)

                If stanza IsNot Nothing Then
                    AttachOptionHelp(item)
                End If
            End If
        Next

        For Each panel In flowPanels
            panel.ResumeLayout()
        Next
    End Sub
```

The only behavioral differences from the old `InitUI` for parameters without a stanza: `helpControl` is now per-iteration, so a `LineParam` no longer receives an `Item` that points at the previous control. Everything else is byte-for-byte the previous logic.

- [ ] **Step 4: Add the helper methods (with stubs for Tasks 6 and 7)**

Add after `InitUI`:

```vb
    Private Sub AttachOptionHelp(item As Item)
        Dim caption = item.Param.Text.TrimEnd(":"c).Trim()
        Dim summary = OptionHelpParser.PlainText(item.Stanza.Summary)
        Dim tip = summary + BR + "Press F1 or right-click for details"

        For Each target In item.Targets
            OptionHelpTips.SetToolTip(target, tip)
            AddHandler target.MouseEnter, Sub() SetDescription(item)
            AddHandler target.Enter, Sub() SetDescription(item)

            If Not TypeOf target Is Label Then
                target.AccessibleName = caption
                target.AccessibleDescription = summary
            End If
        Next
    End Sub

    Private Function FindFocusedItem() As Item
        Return Items.FirstOrDefault(Function(i) i.Targets.Any(Function(t) t.ContainsFocus))
    End Function

    Private Function FindItemByIdentity(id As String) As Item
        Return Items.FirstOrDefault(Function(i) i.Identity = id)
    End Function

    Private Sub SetDescription(item As Item)
        ' Task 6 replaces this stub with the description strip update.
    End Sub

    Private Sub ShowOptionHelp(item As Item)
        ' Task 7 replaces this stub with the details window.
        Params.ShowHelp(item.Param.GetSwitches)
    End Sub
```

- [ ] **Step 5: F1 and search**

Replace `CommandLineForm_HelpRequested`:

```vb
    Sub CommandLineForm_HelpRequested(sender As Object, hlpevent As HelpEventArgs) Handles Me.HelpRequested
        If ModifierKeys = Keys.None Then
            Dim item = FindFocusedItem()

            If item IsNot Nothing AndAlso item.Stanza IsNot Nothing Then
                hlpevent.Handled = True
                ShowOptionHelp(item)
            Else
                ShowHelp()
            End If
        End If
    End Sub
```

In `cbGoTo_TextChanged`, inside the second `For Each item In Items` loop, after the block that checks `item.Param.Text.ToLowerEx.Contains(find)` (the first `If ... Then matchedItems.Add(item) End If` of that loop), add:

```vb
                If item.Stanza IsNot Nothing AndAlso OptionHelpCatalog.SearchText(item.Stanza, item.Identity).Contains(find) Then
                    matchedItems.Add(item)
                End If
```

- [ ] **Step 6: Build and commit**

Build StaxRip (exit code 0). Nothing displays yet because no stanza is reviewed; the x265 dialog must open and behave exactly as before (open it once). Commit:

```bash
git add Source/Forms/CommandLineForm.vb
git commit -m "CommandLineForm: bind option help to every control of an option, with F1 and search" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Description strip

**Files:**
- Modify: `Source/Forms/CommandLineForm.Designer.vb`
- Modify: `Source/Forms/CommandLineForm.vb` (`Sub New`, `SetDescription`)

**Interfaces:**
- Produces: `Friend WithEvents lblDescription As StaxRip.UI.LabelEx` in `tlpMain` row 1; `SetDescription(item)` implemented.

- [ ] **Step 1: Designer edits**

In `Source/Forms/CommandLineForm.Designer.vb`:

1. After `Me.rtbCommandLine = New StaxRip.UI.CommandLineRichTextBox()` add `Me.lblDescription = New StaxRip.UI.LabelEx()`.
2. Before the `'tlpMain` comment block, add:

```vb
        '
        'lblDescription
        '
        Me.lblDescription.Anchor = CType((System.Windows.Forms.AnchorStyles.Left Or System.Windows.Forms.AnchorStyles.Right), System.Windows.Forms.AnchorStyles)
        Me.lblDescription.AutoEllipsis = True
        Me.lblDescription.AutoSize = False
        Me.tlpMain.SetColumnSpan(Me.lblDescription, 4)
        Me.lblDescription.Location = New System.Drawing.Point(15, 428)
        Me.lblDescription.Margin = New System.Windows.Forms.Padding(15, 0, 15, 8)
        Me.lblDescription.Name = "lblDescription"
        Me.lblDescription.Size = New System.Drawing.Size(1279, 60)
        Me.lblDescription.TabIndex = 12
        Me.lblDescription.UseMnemonic = False
```

3. Replace the six `Me.tlpMain.Controls.Add(...)` lines with:

```vb
        Me.tlpMain.Controls.Add(Me.bnCancel, 3, 3)
        Me.tlpMain.Controls.Add(Me.bnMenu, 1, 3)
        Me.tlpMain.Controls.Add(Me.bnOK, 2, 3)
        Me.tlpMain.Controls.Add(Me.cbGoTo, 0, 3)
        Me.tlpMain.Controls.Add(Me.SimpleUI, 0, 0)
        Me.tlpMain.Controls.Add(Me.lblDescription, 0, 1)
        Me.tlpMain.Controls.Add(Me.tlpRTB, 0, 2)
```

4. Change `Me.tlpMain.RowCount = 3` to `Me.tlpMain.RowCount = 4` and add one more `Me.tlpMain.RowStyles.Add(New System.Windows.Forms.RowStyle())` after the existing three `RowStyles.Add` lines.
5. Add `Friend WithEvents lblDescription As StaxRip.UI.LabelEx` next to the other `Friend WithEvents` declarations.

- [ ] **Step 2: Initial text and height**

In `Sub New`, after the three lines added in Task 5 Step 1:

```vb
        lblDescription.Height = FontHeight * 3 + 6
        lblDescription.Text = "Point at an option, or move focus to it, to see what it does. Press F1 for details."
```

Replace the `SetDescription` stub:

```vb
    Private Sub SetDescription(item As Item)
        If item.Stanza Is Nothing Then Exit Sub
        Dim caption = item.Param.Text.TrimEnd(":"c).Trim()
        Dim text = caption + ": " + OptionHelpParser.PlainText(item.Stanza.Summary)
        Dim whenToChange = item.Stanza.WhenToChange

        If whenToChange <> "" Then
            text += BR + "When to change: " + OptionHelpParser.PlainText(whenToChange)
        End If

        lblDescription.Text = text
    End Sub
```

- [ ] **Step 3: Build, look, commit**

Build StaxRip. Open the x265 dialog in the dev build: the strip shows the initial sentence above the command line, the dialog is about three text lines taller, both themes color the strip like other labels (`LabelEx` themes itself), and the layout at 100 percent DPI has no overlap. Commit:

```bash
git add Source/Forms/CommandLineForm.vb Source/Forms/CommandLineForm.Designer.vb
git commit -m "CommandLineForm: add the description strip above the command line" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Details window with generated facts and typed routes

**Files:**
- Modify: `Source/Forms/CommandLineForm.vb` (`ShowOptionHelp` stub, add `ShowStanza`)

**Interfaces:**
- Produces: `ShowOptionHelp(item As Item)` and `ShowStanza(stanza As OptionHelpStanza, item As Item)`.
- Consumes: `HelpDocument.WriteNodes`, `WriteNodesTable`, `WriteLinkList`, `HelpForm.RouteAction`, `OptionHelpRoute`, `Catalog.Lookup`, `Catalog.ValueNote`, `OptionParam.GetEmittedValue`, `StringPairList`.

- [ ] **Step 1: Replace the stub**

```vb
    Private Sub ShowOptionHelp(item As Item)
        ShowStanza(item.Stanza, item)
    End Sub

    Private Sub ShowStanza(stanza As OptionHelpStanza, item As Item)
        Dim caption As String

        If item IsNot Nothing Then
            caption = item.Param.Text.TrimEnd(":"c).Trim()
        ElseIf stanza.Label <> "" Then
            caption = stanza.Label
        Else
            caption = stanza.Id
        End If

        Dim form As New HelpForm()
        Dim doc = form.Doc
        doc.WriteStart(caption)

        If item IsNot Nothing Then
            Dim facts As New List(Of KeyValuePair(Of String, IEnumerable(Of OptionHelpNode)))
            Dim op = TryCast(item.Param, OptionParam)
            Dim np = TryCast(item.Param, NumParam)
            Dim bp = TryCast(item.Param, BoolParam)

            If op IsNot Nothing Then
                If op.Value >= 0 AndAlso op.Value < op.Options.Length Then facts.Add(Fact("Current value", op.Options(op.Value)))
                If op.DefaultValue >= 0 AndAlso op.DefaultValue < op.Options.Length Then facts.Add(Fact("StaxRip default", op.Options(op.DefaultValue)))
            ElseIf np IsNot Nothing Then
                facts.Add(Fact("Current value", np.Value.ToString))
                facts.Add(Fact("StaxRip default", np.DefaultValue.ToString))

                If np.Config IsNot Nothing AndAlso np.Config.Length >= 2 AndAlso np.Config(0) > Double.MinValue AndAlso np.Config(1) < Double.MaxValue Then
                    Dim range = np.Config(0) & " to " & np.Config(1)
                    If np.Config.Length > 2 AndAlso np.Config(2) <> 0 Then range += " in steps of " & np.Config(2)
                    facts.Add(Fact("Valid range", range))
                End If
            ElseIf bp IsNot Nothing Then
                facts.Add(Fact("Current value", If(bp.Value, "On", "Off")))
                facts.Add(Fact("StaxRip default", If(bp.DefaultValue, "On", "Off")))
            End If

            If stanza.EncoderDefault <> "" Then facts.Add(New KeyValuePair(Of String, IEnumerable(Of OptionHelpNode))("Encoder default", OptionHelpParser.ParseInline(stanza.EncoderDefault)))
            Dim switches = item.Param.GetSwitches.OrderBy(Function(s) s, StringComparer.Ordinal).ToArray
            If switches.Length > 0 Then facts.Add(Fact("Switches", String.Join(", ", switches)))
            If facts.Count > 0 Then doc.WriteNodesTable(facts)
        End If

        doc.WriteH2("What it does")
        doc.WriteNodes("p", OptionHelpParser.ParseInline(stanza.Summary))

        If stanza.UsedWhen <> "" Then
            doc.WriteH2("Used when")
            doc.WriteNodes("p", OptionHelpParser.ParseInline(stanza.UsedWhen))
        End If

        If stanza.WhenToChange <> "" Then
            doc.WriteH2("When to change it")
            doc.WriteNodes("p", OptionHelpParser.ParseInline(stanza.WhenToChange))
        End If

        If stanza.Example <> "" Then
            doc.WriteH2("Example")
            doc.WriteNodes("p", OptionHelpParser.ParseInline(stanza.Example))
        End If

        If item IsNot Nothing AndAlso TypeOf item.Param Is OptionParam Then
            Dim op = DirectCast(item.Param, OptionParam)
            Dim rows As New List(Of KeyValuePair(Of String, IEnumerable(Of OptionHelpNode)))

            For i = 0 To op.Options.Length - 1
                Dim note = Catalog.ValueNote(stanza, op.GetEmittedValue(i))
                rows.Add(New KeyValuePair(Of String, IEnumerable(Of OptionHelpNode))(op.Options(i), OptionHelpParser.ParseInline(If(note, ""))))
            Next

            doc.WriteH2("Values")
            doc.WriteNodesTable(rows)
        End If

        Dim related As New List(Of KeyValuePair(Of String, String))

        For Each id In stanza.Related
            Dim target = Catalog.Lookup(id)
            If target Is Nothing Then Continue For
            Dim label = If(target.Label <> "", target.Label, id)
            related.Add(New KeyValuePair(Of String, String)(label, "staxrip://option/" + id))
        Next

        If related.Count > 0 Then
            doc.WriteH2("Related")
            doc.WriteLinkList(related)
        End If

        If stanza.References.Count > 0 Then
            doc.WriteH2("References")
            doc.WriteLinkList(stanza.References.Select(Function(r) New KeyValuePair(Of String, String)(r, r)))
        End If

        If item IsNot Nothing AndAlso item.Param.HelpSwitch <> "" Then
            doc.WriteH2("More")
            doc.WriteLinkList({New KeyValuePair(Of String, String)("Show the encoder's own help for " + item.Param.HelpSwitch, "staxrip://console-help")})
        End If

        form.RouteAction = Sub(route As OptionHelpRoute)
                               If route.Kind = "ConsoleHelp" Then
                                   If item IsNot Nothing Then Params.ShowHelp(item.Param.GetSwitches)
                               ElseIf route.Kind = "Option" Then
                                   Dim other = FindItemByIdentity(route.Id)

                                   If other IsNot Nothing AndAlso other.Stanza IsNot Nothing Then
                                       form.Close()
                                       ShowOptionHelp(other)
                                   Else
                                       Dim target = Catalog.Lookup(route.Id)

                                       If target IsNot Nothing Then
                                           form.Close()
                                           ShowStanza(target, Nothing)
                                       End If
                                   End If
                               End If
                           End Sub

        form.Show()
    End Sub

    Private Shared Function Fact(name As String, value As String) As KeyValuePair(Of String, IEnumerable(Of OptionHelpNode))
        Return New KeyValuePair(Of String, IEnumerable(Of OptionHelpNode))(name, {OptionHelpNode.TextNode(value)})
    End Function
```

`StringParam` values are deliberately not shown, so a path never reaches the temp document.

- [ ] **Step 2: Build and commit**

Build StaxRip (exit code 0). Commit:

```bash
git add Source/Forms/CommandLineForm.vb
git commit -m "CommandLineForm: show option details with generated facts and typed links" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: End-to-end check with the first reviewed stanza, verification headers, and close-out record

**Files:**
- Modify: `Docs/OptionHelp/svt-av1.md` (verification headers and the `svt-av1.preset` stanza)
- Modify: `Docs/OptionHelp/concepts.md` (`concept.compression-efficiency`)

**Interfaces:**
- Produces: the first visible help in the SVT-AV1 dialog; the verification header values that plan 3 keeps.

- [ ] **Step 1: Verification headers from the bundled build**

Run `C:\StaxRip\Apps\Encoders\SvtAv1EncApp\SvtAv1EncApp.exe --version`. On 2026-08-26 it printed `SVT-AV1 v4.2.0+71+88-17cd99550 [Mod by Patman] (release)`. Replace the header of `Docs/OptionHelp/svt-av1.md` with:

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
Verified-Encoder-Version: SVT-AV1 v4.2.0+71+88-17cd99550 [Mod by Patman] (release)
Verified-Encoder-Build: 17cd99550
Verified-Date: 2026-08-26
Documentation: https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md
```

If the printed version differs, use what the binary prints and today's date.

- [ ] **Step 2: The preset stanza and its glossary entry**

Append to `svt-av1.md` (facts checked against `SvtAv1EncApp.exe --help`, which prints `--preset` with default 8 and range -1 to 13, and against `Source/Encoding/SvtAv1Enc.vb:528-544`, where StaxRip's own default is 9):

```markdown
## svt-av1.preset
Label: Preset
Summary: Controls the tradeoff between encoding speed and compression. Lower numbers usually make a smaller file at similar quality, but the encode can take much longer.
When to change: StaxRip starts you at 9. Try 6 for a final encode when a smaller file is worth the extra time; use 10 or higher for quick tests.
Encoder default: 8
Example: Encode the same 60-second sample at presets 9, 6, and 4. Compare the time and file size before committing the whole video.
Values:
- 0: Extremely slow. Mainly useful for experiments.
- 4: High compression efficiency with a large encoding-time cost.
- 6: Slower than StaxRip's default, with better compression efficiency.
- 8: The encoder's own default.
- 9: StaxRip's default and a practical starting point.
- 13: Fastest, with the largest compression tradeoff.
Related: svt-av1.crf, concept.compression-efficiency
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md
Status: reviewed
```

Append to `concepts.md`:

```markdown
## concept.compression-efficiency
Label: Compression efficiency
Summary: How small a file the encoder can make for a given picture quality. Better efficiency means a smaller file that looks the same, usually at the cost of encoding time.
When to change: Not a setting; a way to compare choices such as presets.
Status: reviewed
```

`svt-av1.crf` does not exist yet, so the validator reports E6 for the `Related` line until plan 3 adds it. For this task only, temporarily set `Related: concept.compression-efficiency`, and restore the two-entry line in plan 3 when `svt-av1.crf` lands.

- [ ] **Step 3: Validate, build, run**

```powershell
pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1
```

Expected: `ENCODER svt-av1 total=100 excluded=1 reviewed=1 draft=0 missing=99 ... result=PASS`, `RESULT PASS`. Then build StaxRip and launch `Source\bin\StaxRip.exe`, select the SVT-AV1 encoder, open its options, and check, in this order: hover on `Preset` shows the summary and the F1 line; the strip shows `Preset: ...` and `When to change: ...`; the dropdown shows a note on `6: Medium`; F1 with the dropdown focused opens the details window whose facts table shows `Current value`, `StaxRip default`, `Encoder default 8`, `Valid range` absent (dropdown), and `Switches --preset`; the `Related` link opens the glossary entry; `Show the encoder's own help for --preset` opens the console help at the switch; searching `slow` finds Preset; every other SVT-AV1 option still shows the console help on right-click and nothing on hover; the x265 dialog is unchanged.

- [ ] **Step 4: Maintainer checklist V4 and V6**

Hand the maintainer this list; record their answers in the pull request:

1. Tooltip on the label, the dropdown button, and a numeric editor (once plan 3 adds one) — present, readable, disappears after about 20 seconds.
2. Strip updates on hover and when tabbing to the control; keeps its text on mouse leave; long text ends with an ellipsis.
3. F1 on a focused option opens its details; F1 with focus in the search box opens the dialog help as before.
4. Right-click on the label opens the same details.
5. Narrator reads the accessible name and the summary on the dropdown button.
6. A disabled editor's label still shows the tooltip.
7. Light and dark themes; 100 and 150 percent DPI; a 1366 by 768 display.
8. V6: for a saved SVT-AV1 template and an x265 template, `Copy Command Line` in the dev build and in the installed v2.52.5 produce byte-identical text.

- [ ] **Step 5: Reconcile facts again, push, and write the close-out record**

Run the `-ExportOptionHelpFacts` and `-CompareFacts` pair from Task 3 Step 3 again (expected `facts: no differences`), run the harness (18 cases, 0 failures) and the self-test (23 cases, 0 failures), then:

```bash
git add Docs/OptionHelp/svt-av1.md Docs/OptionHelp/concepts.md
git commit -m "Docs: first reviewed SVT-AV1 stanza with verification headers" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
git push origin worktree-option-help
```

Write the close-out per `AGENTS.md` into the pull request description when the branch is opened: behavior changed (help surfaces; help-window hygiene for every window; `GetArgs` calls `GetEmittedValue`), checks run (build configuration, harness, self-test, facts comparison, V4 answers, V6 diffs), the untested boundary (displays above 200 percent, translations), unknowns (U-OH-1 resolved by enumeration; U-OH-2 judged in V4), security and privacy impact (no network from help windows; no text-field values in temp documents), documentation touched (`AGENTS.md`, `Docs/OptionHelp/README.md`, `Docs/Usage/Command-Line-Interface.md`), approval gates crossed (project file entries, `GetArgs` extraction, help-window changes, all pre-approved in the spec), follow-up (plan 3 content).

---

## Self-review against the spec (plan 2 scope)

| Spec item | Task |
| --- | --- |
| 5.1 loader types, resource discovery, lazy load under a lock, logging, fail closed | 1, 2 |
| 5.3 targets per item, carry-over fix, tooltip instance, right-click, F1 fallback, accessibility, value notes, strip, details window with generated facts, search over all fields | 5, 6, 7 |
| 5.4 node rendering, typed routes, scheme policy, temp cleanup, no font import, charset | 4 |
| 5.5 `Compile` entry | 1 |
| 5.6 failure handling (chain invalid disables help; stanza errors drop stanzas) | 2 |
| 6.7 export command and reconciliation | 3, 8 |
| 6.8 harness | 1, 2 |
| 10 V1, V2, V3, V4, V5, V6, V8 | 8 (V1, V2 via the validator; V3 every task; V4, V6 maintainer) |
| 11 rollback (commits are separable), privacy statement | 4, 7 |

Not in this plan: the remaining 93 stanzas (plan 3); W2 (plan 3 close-out, once `Label` fields exist across the corpus).
