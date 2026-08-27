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

        ' Task 2 enables this block
        'Dim chainDir = Path.Combine(root, "chain")
        'Dim files As New Dictionary(Of String, Byte())(StringComparer.Ordinal)

        'For Each f In Directory.GetFiles(chainDir, "*.md")
        '    files(Path.GetFileName(f)) = File.ReadAllBytes(f)
        'Next

        'For Each line In File.ReadAllLines(Path.Combine(chainDir, "cases.txt"))
        '    If line.Trim() = "" Then Continue For
        '    count += 1
        '    Dim parts = line.Split({" => "}, StringSplitOptions.None)
        '    Dim lhs = parts(0).Split(" "c)
        '    Dim catalog = OptionHelpCatalog.FromFiles(files, lhs(0))
        '    Dim actual = "none"

        '    If catalog IsNot Nothing Then
        '        Dim r = catalog.Resolve(lhs(1))
        '        If r.Outcome <> "none" Then actual = r.Outcome & ":" & r.FileName
        '    End If

        '    If actual <> parts(1) Then
        '        failures += 1
        '        Console.Error.WriteLine("FAIL chain '" & line & "' actual '" & actual & "'")
        '    End If
        'Next

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
