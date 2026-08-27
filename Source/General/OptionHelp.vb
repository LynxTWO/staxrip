Imports Microsoft.VisualBasic
Imports System.IO
Imports System.Linq
Imports System.Text
Imports System.Text.RegularExpressions

' Plain-English option help: grammar parser, catalog, and rendering model.
' This file must stay free of StaxRip dependencies; Source/Tests/OptionHelp compiles it alone.
' Source/Tools/OptionHelp/OptionHelp.psm1 is the reference implementation of the same grammar;
' both parsers must print the same canonical dump for every file, so every identifier comparison
' here is ordinal and case-sensitive and every rule below mirrors a rule over there.
' StaxRip's ShortcutModule publishes g, p, and s to every file in the project, and an inferred
' For Each binds an existing name instead of declaring a new one, so no loop variable here may be
' called g, p, or s: inside StaxRip that loop would silently walk the wrong type.

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
    ' The source line each field was read from, so an inline-markup error points at the field
    ' itself and not at a line counted from the stanza head.
    Property FieldLines As New Dictionary(Of String, Integer)(StringComparer.Ordinal)
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
            Return String.Equals(Status, "reviewed", StringComparison.Ordinal)
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
            Return raw.Split(","c).Select(Function(t) t.Trim()).Where(Function(t) t.Length > 0).ToList()
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
            Return Errors.Any(Function(x) String.Equals(x.Level, "FILE", StringComparison.Ordinal))
        End Get
    End Property

    ReadOnly Property [Inherits] As String
        Get
            Dim value As String = Nothing
            If Header.TryGetValue("Inherits", value) Then Return value
            Return Nothing
        End Get
    End Property

    Function FindStanza(id As String) As OptionHelpStanza
        For Each st In Stanzas
            If String.Equals(st.Id, id, StringComparison.Ordinal) Then Return st
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
    Private Const UrlPattern As String = "^https?://\S+$"
    Private Const NoteLimit As Integer = 120
    Private Shared ReadOnly FieldLimits As New Dictionary(Of String, Integer)(StringComparer.Ordinal) From {
        {"Label", 60}, {"Summary", 200}, {"Used when", 200}, {"When to change", 400}, {"Encoder default", 40}, {"Example", 300}}
    ' The two shape tests are case-insensitive on purpose, exactly as the reference parser is: an
    ' 'encoder: fake' line is then captured as a key and rejected by the case-sensitive key lookup
    ' with the error that names it, instead of being joined silently into the line before it.
    Private Shared ReadOnly HeaderLine As New Regex("^([A-Z][A-Za-z-]*): ?(.*)$", RegexOptions.IgnoreCase Or RegexOptions.CultureInvariant)
    Private Shared ReadOnly FieldLine As New Regex("^([A-Z][A-Za-z]*(?: [a-z]+)*): ?(.*)$", RegexOptions.IgnoreCase Or RegexOptions.CultureInvariant)
    Private Shared ReadOnly LinkRegex As New Regex(LinkPattern)
    ' A URL scheme is case-insensitive, and the reference parser tests these two the same way.
    Private Shared ReadOnly UrlRegex As New Regex(UrlPattern, RegexOptions.IgnoreCase Or RegexOptions.CultureInvariant)
    Private Shared ReadOnly InlineTextFields As String() = {"Summary", "Used when", "When to change", "Example", "Encoder default", "Label"}
    ' Continuation lines join the text of every other field; on these three the joined text would be
    ' a silently different identifier, status, or link list, so a continuation is an error and is dropped.
    Private Shared ReadOnly NoContinuationFields As String() = {"Status", "Use", "Related"}

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
        Dim base = Regex.Replace(name, "\.md$", "", RegexOptions.IgnoreCase Or RegexOptions.CultureInvariant)
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

            If Not seenContent AndAlso trimmed.StartsWith("# ", StringComparison.Ordinal) Then
                seenContent = True
                Continue For
            End If

            If trimmed.Length = 0 Then
                currentField = Nothing
                Continue For
            End If

            seenContent = True

            If line.StartsWith("## ", StringComparison.Ordinal) Then
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

                    If Not HeaderKeys.Contains(key, StringComparer.Ordinal) Then
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

                If (String.Equals(field, "Values", StringComparison.Ordinal) OrElse
                    String.Equals(field, "References", StringComparison.Ordinal)) AndAlso value.Length > 0 Then
                    file.Errors.Add(NewError(lineNo, "STANZA", "E3", "Field '" & field & "' must have no text on its line"))
                    value = ""
                End If

                stanza.FieldsByName(field) = value
                stanza.FieldLines(field) = lineNo
                stanza.FieldOrder.Add(field)
                If String.Equals(field, "Status", StringComparison.Ordinal) Then stanza.Status = value
                currentField = field
                Continue For
            End If

            If line.StartsWith("- ", StringComparison.Ordinal) Then
                Dim item = line.Substring(2).Trim()

                If String.Equals(currentField, "Values", StringComparison.Ordinal) Then
                    Dim sep = item.IndexOf(": ", StringComparison.Ordinal)

                    If sep < 1 Then
                        file.Errors.Add(NewError(lineNo, "STANZA", "E3", "Value bullet needs ""<value>: <note>"""))
                    Else
                        stanza.Values.Add(New OptionHelpValue With {.Value = item.Substring(0, sep), .Note = item.Substring(sep + 2).Trim(), .Line = lineNo})
                    End If
                ElseIf String.Equals(currentField, "References", StringComparison.Ordinal) Then
                    stanza.References.Add(item)
                    If Not UrlRegex.IsMatch(item) Then file.Errors.Add(NewError(lineNo, "STANZA", "E13", "Reference must be an http or https URL: '" & item & "'"))
                Else
                    file.Errors.Add(NewError(lineNo, "STANZA", "E3", "Bullet outside Values or References"))
                End If

                Continue For
            End If

            If currentField IsNot Nothing AndAlso Not String.Equals(currentField, "Values", StringComparison.Ordinal) AndAlso
                Not String.Equals(currentField, "References", StringComparison.Ordinal) Then

                If NoContinuationFields.Contains(currentField, StringComparer.Ordinal) Then
                    file.Errors.Add(NewError(lineNo, "STANZA", "E3", "Continuation is not allowed for '" & currentField & "'"))
                Else
                    stanza.FieldsByName(currentField) = (stanza.FieldsByName(currentField) & " " & trimmed).Trim()
                End If
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
        Dim isShared = SharedIds.Contains(file.Encoder, StringComparer.Ordinal)

        If Not h.ContainsKey("Schema") OrElse Not String.Equals(h("Schema"), "1", StringComparison.Ordinal) Then errors.Add(NewError(1, "FILE", "E1", "Schema must be 1"))

        If Not h.ContainsKey("Encoder") Then
            errors.Add(NewError(1, "FILE", "E1", "Encoder header is required"))
        ElseIf Not Regex.IsMatch(h("Encoder"), EncoderPattern) OrElse Not String.Equals(h("Encoder"), file.Encoder, StringComparison.Ordinal) Then
            errors.Add(NewError(1, "FILE", "E1", "Encoder '" & h("Encoder") & "' must match the file name '" & file.Encoder & "'"))
        End If

        If Not h.ContainsKey("Locale") Then
            errors.Add(NewError(1, "FILE", "E1", "Locale header is required"))
        ElseIf Not String.Equals(h("Locale"), file.Locale, StringComparison.Ordinal) Then
            errors.Add(NewError(1, "FILE", "E1", "Locale '" & h("Locale") & "' must match the file name locale '" & file.Locale & "'"))
        End If

        If Not h.ContainsKey("Title") Then errors.Add(NewError(1, "FILE", "E1", "Title header is required"))

        Dim anyReviewed = file.Stanzas.Any(Function(item) String.Equals(item.Status, "reviewed", StringComparison.Ordinal))

        If Not isShared Then
            For Each key In {"Source", "Allowed-Missing", "Minimum-Reviewed", "Reviewed-Complete"}
                If Not h.ContainsKey(key) Then errors.Add(NewError(1, "FILE", "E1", key & " header is required for an encoder file"))
            Next

            For Each key In {"Allowed-Missing", "Minimum-Reviewed"}
                If h.ContainsKey(key) AndAlso Not Regex.IsMatch(h(key), "^\d+$") Then errors.Add(NewError(1, "FILE", "E1", key & " must be a non-negative integer"))
            Next

            If h.ContainsKey("Reviewed-Complete") AndAlso Not String.Equals(h("Reviewed-Complete"), "true", StringComparison.Ordinal) AndAlso
                Not String.Equals(h("Reviewed-Complete"), "false", StringComparison.Ordinal) Then

                errors.Add(NewError(1, "FILE", "E1", "Reviewed-Complete must be true or false"))
            End If

            If anyReviewed Then
                Dim missing = {"Verified-Encoder-Version", "Verified-Encoder-Build", "Verified-Date", "Documentation"}.Where(Function(hk) Not h.ContainsKey(hk)).ToArray()
                If missing.Length > 0 Then errors.Add(NewError(1, "FILE", "E1", "Reviewed stanzas require headers: " & String.Join(", ", missing)))
            End If

            If h.ContainsKey("Verified-Date") AndAlso Not Regex.IsMatch(h("Verified-Date"), "^\d{4}-\d{2}-\d{2}$") Then errors.Add(NewError(1, "FILE", "E1", "Verified-Date must be an ISO date"))
            If h.ContainsKey("Documentation") AndAlso Not UrlRegex.IsMatch(h("Documentation")) Then errors.Add(NewError(1, "FILE", "E1", "Documentation must be an http or https URL"))

            If h.ContainsKey("Inherits") AndAlso (Not Regex.IsMatch(h("Inherits"), EncoderPattern) OrElse SharedIds.Contains(h("Inherits"), StringComparer.Ordinal)) Then
                errors.Add(NewError(1, "FILE", "E1", "Inherits must name an encoder file"))
            End If
        ElseIf h.ContainsKey("Inherits") Then
            errors.Add(NewError(1, "FILE", "E1", "Shared files cannot inherit"))
        End If

        Dim seen As New HashSet(Of String)(StringComparer.Ordinal)

        For Each st In file.Stanzas
            If Not seen.Add(st.Id) Then errors.Add(NewError(st.Line, "FILE", "E8", "Duplicate stanza id '" & st.Id & "'"))
            Dim hasUse = st.HasField("Use")

            If hasUse Then
                For Each k In st.FieldOrder
                    If Not String.Equals(k, "Label", StringComparison.Ordinal) AndAlso
                        Not String.Equals(k, "Use", StringComparison.Ordinal) AndAlso
                        Not String.Equals(k, "Status", StringComparison.Ordinal) Then

                        errors.Add(NewError(st.Line, "STANZA", "E3", "Field '" & k & "' is not allowed with Use"))
                    End If
                Next
            End If

            If Not st.HasField("Status") Then
                errors.Add(NewError(st.Line, "STANZA", "E3", "Status is required"))
            ElseIf Not String.Equals(st.Status, "draft", StringComparison.Ordinal) AndAlso Not String.Equals(st.Status, "reviewed", StringComparison.Ordinal) Then
                errors.Add(NewError(st.Line, "STANZA", "E3", "Status must be draft or reviewed, not '" & st.Status & "'"))
            End If

            If Not hasUse Then
                If Not st.HasField("Summary") OrElse st.GetField("Summary").Length = 0 Then
                    errors.Add(NewError(st.Line, "STANZA", "E2", "Summary is required"))
                ElseIf Not st.GetField("Summary").EndsWith(".") Then
                    errors.Add(NewError(st.Line, "STANZA", "E2", "Summary must end with a period"))
                End If

                If st.IsReviewed AndAlso Not st.HasField("When to change") Then errors.Add(NewError(st.Line, "STANZA", "E2", "When to change is required on a reviewed stanza"))
            End If

            For Each k In st.FieldOrder
                Dim limit As Integer

                If FieldLimits.TryGetValue(k, limit) AndAlso st.GetField(k).Length > limit Then
                    errors.Add(NewError(st.Line, "STANZA", "E2", k & " exceeds " & limit & " characters"))
                End If

                If InlineTextFields.Contains(k, StringComparer.Ordinal) Then
                    Dim m = TestInline(st.GetField(k))
                    If m IsNot Nothing Then errors.Add(NewError(st.FieldLines(k), "STANZA", "E13", k & ": " & m))
                End If
            Next

            For Each v In st.Values
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
            If parts(i).Length = 0 Then Continue For
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

        For Each st In file.Stanzas
            sb.Append("S ").Append(st.Id).Append(" ").Append(st.Line).Append(vbLf)

            For Each f In st.FieldOrder
                sb.Append("F ").Append(f).Append("=").Append(st.FieldsByName(f)).Append(vbLf)

                If String.Equals(f, "Values", StringComparison.Ordinal) Then
                    For Each v In st.Values
                        sb.Append("V ").Append(v.Value).Append("=").Append(v.Note).Append(vbLf)
                    Next
                End If

                If String.Equals(f, "References", StringComparison.Ordinal) Then
                    For Each r In st.References
                        sb.Append("R ").Append(r).Append(vbLf)
                    Next
                End If
            Next
        Next

        ' Line first, then the code as text ('E13' sorts between 'E1' and 'E3'), then level and
        ' message so that two errors on one line always land in the same order; both parsers share
        ' this order. Without the level key a stanza that opens on line 1 with an invalid id prints
        ' its STANZA error among the line 1 FILE errors in insertion order instead of after them.
        For Each e In file.Errors.OrderBy(Function(x) x.Line).ThenBy(Function(x) x.Code, StringComparer.Ordinal).
            ThenBy(Function(x) x.Level, StringComparer.Ordinal).ThenBy(Function(x) x.Message, StringComparer.Ordinal)
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
            If Not String.Equals(parsed.Locale, "en", StringComparison.Ordinal) Then Continue For

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

        ' staxrip is the universal base. It is appended only when the encoder itself is not staxrip,
        ' matching Get-OhChain's "$EncoderId -cne 'staxrip'" guard; without it, resolving "staxrip"
        ' itself (whose own while-loop pass above already added it once) would add it a second time.
        If Not String.Equals(encoderId, "staxrip", StringComparison.Ordinal) Then
            Dim staxrip As OptionHelpFile = Nothing
            If catalog.Files.TryGetValue("staxrip", staxrip) Then catalog.Chain.Add(staxrip)
        End If

        For Each f In catalog.Chain
            If f.HasFileErrors Then
                Log?.Invoke("OptionHelp: '" & f.Name & "' has file-level errors; help for '" & encoderId & "' is disabled")
                Return Nothing
            End If
        Next

        Return catalog
    End Function

    ''' <summary>Target-file lookup for a Use alias inside Resolve: mirrors Resolve-OhId's
    ''' "$targetFileId = (Split-OhId -Id $targetId).Namespace" (OptionHelp.psm1 line 500) -- the
    ''' target's file key is the identity's first segment, not a scan of every loaded file.</summary>
    Private Function FindByFileKey(id As String) As OptionHelpStanza
        If String.IsNullOrEmpty(id) Then Return Nothing
        Dim fileId = id.Split("."c)(0)
        Dim f As OptionHelpFile = Nothing
        If Not Files.TryGetValue(fileId, f) OrElse f.HasFileErrors Then Return Nothing
        Return f.FindStanza(id)
    End Function

    ''' <summary>Verbatim scan across every loaded file, used by Lookup for Related targets: mirrors
    ''' Add-OhLinkErrors's "foreach ($other in $Files.Values) { $t = Find-OhStanza -File $other -Id
    ''' $rel; if ($t) { break } }" (OptionHelp.psm1 line 760), so a glossary id like "concept.size" is
    ''' found in concepts.md even though the file's own key is "concepts", not "concept".</summary>
    Private Function FindInAnyFile(id As String) As OptionHelpStanza
        If String.IsNullOrEmpty(id) Then Return Nothing

        For Each f In Files.Values
            Dim st = f.FindStanza(id)
            If st IsNot Nothing Then Return st
        Next

        Return Nothing
    End Function

    ''' <summary>
    ''' An identity is namespace.local, split at the first dot. When the namespace equals this
    ''' catalog's own EncoderId (which is also the chain's root file), the identity resolves
    ''' namespace-relative: each file in the chain is probed for "&lt;that file's encoder&gt;.&lt;local&gt;",
    ''' so a variant inherits every base stanza without repeating base ids, and overrides one by
    ''' defining the same local part in its own namespace. Any other namespace (staxrip, shared,
    ''' concept, or a foreign encoder) is probed verbatim in each chain file. Mirrors Resolve-OhId in
    ''' Source/Tools/OptionHelp/OptionHelp.psm1 (HomeEncoder there is always this catalog's EncoderId).
    ''' </summary>
    Public Function Resolve(identity As String) As OptionHelpResolution
        Dim r As New OptionHelpResolution
        If String.IsNullOrEmpty(identity) OrElse identity = "none" Then Return r

        Dim dot = identity.IndexOf("."c)
        Dim namespacePart As String
        Dim localPart As String

        If dot < 1 Then
            namespacePart = ""
            localPart = identity
        Else
            namespacePart = identity.Substring(0, dot)
            localPart = identity.Substring(dot + 1)
        End If

        Dim ownNamespace = Not String.IsNullOrEmpty(EncoderId) AndAlso String.Equals(EncoderId, namespacePart, StringComparison.Ordinal)

        For Each f In Chain
            Dim probe = If(ownNamespace, f.Encoder & "." & localPart, identity)
            Dim st = f.FindStanza(probe)
            If st Is Nothing Then Continue For
            r.FileName = f.Name

            If Not st.IsReviewed Then
                r.Outcome = "draft"
                r.Stanza = st
                Return r
            End If

            If st.HasField("Use") Then
                Dim target = FindByFileKey(st.Use)

                If target Is Nothing OrElse Not target.IsReviewed OrElse target.HasField("Use") Then
                    r.Outcome = "draft"
                    r.Stanza = st
                    Return r
                End If

                r.Outcome = "alias"
                r.Stanza = target
                r.AliasStanza = st
                r.FileName = target.FileName
                Return r
            End If

            r.Outcome = "reviewed"
            r.Stanza = st
            Return r
        Next

        Return r
    End Function

    ''' <summary>A reviewed stanza by id from any loaded file, for Related links. Aliases are followed once.</summary>
    Public Function Lookup(id As String) As OptionHelpStanza
        Dim st = FindInAnyFile(id)
        If st Is Nothing OrElse Not st.IsReviewed Then Return Nothing

        If st.HasField("Use") Then
            Dim target = FindInAnyFile(st.Use)
            If target Is Nothing OrElse Not target.IsReviewed OrElse target.HasField("Use") Then Return Nothing
            Return target
        End If

        Return st
    End Function

    Public Function ValueNote(stanza As OptionHelpStanza, emittedValue As String) As String
        If stanza Is Nothing OrElse emittedValue Is Nothing Then Return Nothing

        For Each v In stanza.Values
            If String.Equals(v.Value, emittedValue, StringComparison.Ordinal) Then Return v.Note
        Next

        Return Nothing
    End Function

    Public Shared Function SearchText(stanza As OptionHelpStanza, identity As String) As String
        Dim parts As New List(Of String) From {identity, stanza.Id, stanza.Label, stanza.Summary, stanza.UsedWhen, stanza.WhenToChange, stanza.Example}
        parts.AddRange(stanza.Values.Select(Function(v) v.Note))
        parts.AddRange(stanza.Related)
        Return String.Join(" ", parts.Where(Function(t) Not String.IsNullOrEmpty(t)).Select(Function(t) OptionHelpParser.PlainText(t))).ToLowerInvariant()
    End Function
End Class
