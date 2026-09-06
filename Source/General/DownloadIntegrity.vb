
Imports System.Security.Cryptography

''' <summary>
''' Integrity checks for the package updater. Pure functions so a standalone harness can
''' exercise them without a browser, a network, or a dialog.
'''
''' Why: the updater turns a vendor web page into executable dependencies. Before these
''' checks it accepted any scheme, any host the page linked to, and any bytes that
''' extracted to the expected file name. Nothing here verifies a publisher signature,
''' because no package declares one; the digest exists so a person can compare it with
''' the publisher's checksum and so a support report carries it.
''' </summary>
Public Module DownloadIntegrity
    ''' <summary>True only for an absolute https URL. Plain http, other schemes, and relative text are false.</summary>
    Public Function IsHttps(url As String) As Boolean
        Dim parsed As Uri = Nothing

        If String.IsNullOrWhiteSpace(url) OrElse Not Uri.TryCreate(url, UriKind.Absolute, parsed) Then
            Return False
        End If

        Return parsed.Scheme = Uri.UriSchemeHttps
    End Function

    ''' <summary>
    ''' Resolve a link found on a download page. An absolute link is returned as is; a
    ''' relative or protocol-relative link is resolved against the page URL the way a
    ''' browser would, so "/files/x.7z", "x.7z", and "//cdn.example/x.7z" all resolve.
    ''' </summary>
    Public Function ResolveLink(href As String, pageUrl As String) As String
        Dim resolved As Uri = Nothing
        Dim page As Uri = Nothing

        If Uri.TryCreate(href, UriKind.Absolute, resolved) AndAlso resolved.Scheme.StartsWith("http") Then
            Return resolved.AbsoluteUri
        End If

        If Uri.TryCreate(pageUrl, UriKind.Absolute, page) AndAlso Uri.TryCreate(page, href, resolved) Then
            Return resolved.AbsoluteUri
        End If

        Return href
    End Function

    ''' <summary>Lower-case host of an absolute URL, or an empty string when it has none.</summary>
    Public Function HostOf(url As String) As String
        Dim parsed As Uri = Nothing

        If String.IsNullOrWhiteSpace(url) OrElse Not Uri.TryCreate(url, UriKind.Absolute, parsed) Then
            Return ""
        End If

        Return parsed.Host.ToLowerInvariant()
    End Function

    ''' <summary>True when both URLs name the same host. Ports and paths are ignored; an empty host never matches.</summary>
    Public Function IsSameHost(linkUrl As String, pageUrl As String) As Boolean
        Dim linkHost = HostOf(linkUrl)
        Return linkHost <> "" AndAlso linkHost = HostOf(pageUrl)
    End Function

    ''' <summary>Text for the confirmation shown when the file link leaves the download page's host.</summary>
    Public Function DescribeCrossHost(linkUrl As String, pageUrl As String) As String
        Dim nl2 = Environment.NewLine + Environment.NewLine
        Return "The download page is on " + HostOf(pageUrl) + " but the file link points to " +
            HostOf(linkUrl) + ":" + nl2 + linkUrl + nl2 +
            "Continue only if you expect this host to serve the file."
    End Function

    ''' <summary>Lower-case hex SHA-256 of a file's bytes.</summary>
    Public Function ComputeSha256(path As String) As String
        Using stream = IO.File.OpenRead(path)
            Using sha = SHA256.Create()
                Return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", "").ToLowerInvariant()
            End Using
        End Using
    End Function
End Module
