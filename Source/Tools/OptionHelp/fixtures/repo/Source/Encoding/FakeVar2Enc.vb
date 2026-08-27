Public Class FakeVar2EncParams
    Inherits CommandLineParams

    Public Overrides ReadOnly Property OptionHelpId As String
        Get
            Return "fakevar2"
        End Get
    End Property

    Property Sigma As New NumParam With {
        .Switch = "--sigma",
        .Text = "Sigma"}
End Class
