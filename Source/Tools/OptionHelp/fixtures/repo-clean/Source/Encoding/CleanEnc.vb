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
