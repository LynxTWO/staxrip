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
