Public Class CycEncParams
    Inherits CommandLineParams

    Public Overrides ReadOnly Property OptionHelpId As String
        Get
            Return "cyc"
        End Get
    End Property

    Property Alpha As New NumParam With {
        .Switch = "--alpha",
        .Text = "Alpha"}
End Class
