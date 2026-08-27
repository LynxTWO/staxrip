
Imports StaxRip.UI

Public Class HelpForm
    Inherits FormBase

#Region " Designer "
    <System.Diagnostics.DebuggerNonUserCode()>
    Protected Overloads Overrides Sub Dispose(disposing As Boolean)
        If disposing AndAlso components IsNot Nothing Then
            components.Dispose()
        End If
        MyBase.Dispose(disposing)
    End Sub

    Private ReadOnly components As System.ComponentModel.IContainer

    Friend WithEvents Browser As System.Windows.Forms.WebBrowser
    <System.Diagnostics.DebuggerStepThrough()>
    Private Sub InitializeComponent()
        Me.Browser = New System.Windows.Forms.WebBrowser()
        Me.SuspendLayout()
        '
        'Browser
        '
        Me.Browser.Dock = System.Windows.Forms.DockStyle.Fill
        Me.Browser.Location = New System.Drawing.Point(0, 0)
        Me.Browser.Name = "Browser"
        Me.Browser.Size = New System.Drawing.Size(1218, 791)
        Me.Browser.TabIndex = 0
        '
        'HelpForm
        '
        Me.AutoScaleDimensions = New System.Drawing.SizeF(288.0!, 288.0!)
        Me.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Dpi
        Me.ClientSize = New System.Drawing.Size(1218, 791)
        Me.Controls.Add(Me.Browser)
        Me.KeyPreview = True
        Me.Margin = New System.Windows.Forms.Padding(6, 6, 6, 6)
        Me.Name = $"{g.DefaultCommands.GetApplicationDetails()} - HelpForm"
        Me.StartPosition = System.Windows.Forms.FormStartPosition.CenterScreen
        Me.ResumeLayout(False)

    End Sub
#End Region

    Sub New()
        InitializeComponent()
        RestoreClientSize(50, 35)
        Icon = g.Icon
    End Sub

    Private DocumentValue As HelpDocument
    Private DocumentPath As String
    Property RouteAction As Action(Of OptionHelpRoute)

    Property Doc() As HelpDocument
        Get
            If DocumentValue Is Nothing Then
                Dim path = IO.Path.Combine(Folder.Temp, Guid.NewGuid.ToString + ".htm")
                DocumentPath = path
                DocumentValue = New HelpDocument(path)
            End If

            Return DocumentValue
        End Get
        Set(Value As HelpDocument)
            DocumentValue = Value
        End Set
    End Property

    Overloads Shared Sub ShowDialog(heading As String, tips As StringPairList)
        ShowDialog(heading, tips, Nothing)
    End Sub

    Overloads Shared Sub ShowDialog(heading As String, tips As StringPairList, summary As String)
        Dim form As New HelpForm()
        form.Doc.WriteStart(heading)

        If summary IsNot Nothing Then
            form.Doc.WriteParagraph(summary)
        End If

        form.Doc.WriteTips(tips)
        form.Show()
    End Sub

    Protected Overrides Sub OnFormClosed(e As FormClosedEventArgs)
        If DocumentPath <> "" AndAlso File.Exists(DocumentPath) Then
            Try
                FileHelp.Delete(DocumentPath)
            Catch
            End Try
        End If

        Dispose()
    End Sub

    Sub Browser_DocumentCompleted(sender As Object, e As WebBrowserDocumentCompletedEventArgs) Handles Browser.DocumentCompleted
        WebBrowserHelp.ResetTextSize(Browser)
    End Sub

    Sub Browser_Navigated(sender As Object, e As WebBrowserNavigatedEventArgs) Handles Browser.Navigated
        If Browser.DocumentTitle <> "" Then
            Text = Browser.DocumentTitle
        ElseIf File.Exists(e.Url.LocalPath) Then
            Text = e.Url.LocalPath.Base
        End If
    End Sub

    Shadows Sub Show()
        MyBase.Show()

        DocumentValue?.WriteDocument(Browser)
    End Sub

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
End Class
