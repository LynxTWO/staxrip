Imports System.IO

''' <summary>
''' Standalone harness for the updater's integrity checks. Runs without a network, a
''' browser, or a dialog, and exits with the number of failed cases.
''' </summary>
Module Program
    Private Failures As Integer
    Private Count As Integer

    Function Main(args As String()) As Integer
        Check("https is accepted", DownloadIntegrity.IsHttps("https://example.test/files/tool.7z"))
        Check("http is refused", Not DownloadIntegrity.IsHttps("http://example.test/files/tool.7z"))
        Check("ftp is refused", Not DownloadIntegrity.IsHttps("ftp://example.test/tool.7z"))
        Check("relative text is refused", Not DownloadIntegrity.IsHttps("files/tool.7z"))
        Check("empty is refused", Not DownloadIntegrity.IsHttps(""))

        Const page = "https://vendor.test/downloads/index.html"
        CheckEqual("root-relative link resolves against the host", "https://vendor.test/files/tool-1.2.7z",
            DownloadIntegrity.ResolveLink("/files/tool-1.2.7z", page))
        CheckEqual("relative link resolves against the page directory", "https://vendor.test/downloads/tool-1.2.7z",
            DownloadIntegrity.ResolveLink("tool-1.2.7z", page))
        CheckEqual("protocol-relative link keeps the page scheme", "https://cdn.test/tool-1.2.7z",
            DownloadIntegrity.ResolveLink("//cdn.test/tool-1.2.7z", page))
        CheckEqual("absolute link is returned unchanged", "https://mirror.test/x/tool-1.2.zip",
            DownloadIntegrity.ResolveLink("https://mirror.test/x/tool-1.2.zip", page))
        CheckEqual("plain-http absolute link stays plain http so the scheme check can refuse it", "http://vendor.test/tool.7z",
            DownloadIntegrity.ResolveLink("http://vendor.test/tool.7z", page))

        Check("same host, different case, matches", DownloadIntegrity.IsSameHost("https://VENDOR.test/files/a.7z", page))
        Check("same host with a port matches", DownloadIntegrity.IsSameHost("https://vendor.test:8443/files/a.7z", page))
        Check("a different host does not match", Not DownloadIntegrity.IsSameHost("https://cdn.test/files/a.7z", page))
        Check("a relative link has no host and does not match", Not DownloadIntegrity.IsSameHost("files/a.7z", page))
        Check("an empty page has no host and does not match", Not DownloadIntegrity.IsSameHost("https://vendor.test/a", ""))

        Dim text = DownloadIntegrity.DescribeCrossHost("https://cdn.test/files/a.7z", page)
        Check("the cross-host text names both hosts and the link",
            text.Contains("vendor.test") AndAlso text.Contains("cdn.test") AndAlso text.Contains("https://cdn.test/files/a.7z"))

        Dim temp = Path.GetTempFileName()
        Try
            File.WriteAllBytes(temp, System.Text.Encoding.ASCII.GetBytes("abc"))
            CheckEqual("sha-256 of a known file", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
                DownloadIntegrity.ComputeSha256(temp))
        Finally
            File.Delete(temp)
        End Try

        Console.WriteLine($"ToolUpdateTests: {Count - Failures} of {Count} cases passed")
        Return Failures
    End Function

    Private Sub Check(name As String, condition As Boolean)
        Count += 1
        If Not condition Then
            Failures += 1
            Console.Error.WriteLine("FAIL " + name)
        End If
    End Sub

    Private Sub CheckEqual(name As String, expected As String, actual As String)
        Count += 1
        If expected <> actual Then
            Failures += 1
            Console.Error.WriteLine("FAIL " + name)
            Console.Error.WriteLine("  expected: " + expected)
            Console.Error.WriteLine("  actual:   " + actual)
        End If
    End Sub
End Module
