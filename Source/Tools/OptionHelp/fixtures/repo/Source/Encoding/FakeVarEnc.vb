Public Class FakeVarEncParams
    Inherits CommandLineParams

    Public Overrides ReadOnly Property OptionHelpId As String
        Get
            Return "fakevar"
        End Get
    End Property

    Property Alpha As New NumParam With {
        .Switch = "--alpha",
        .Text = "Alpha"}

    Property Beta As New OptionParam With {
        .Switch = "--beta",
        .Text = "Beta",
        .Options = {"0: Off (default)", "1: On"},
        .Values = {"0", "1"}}

    Property Omega As New NumParam With {
        .Switch = "--omega",
        .Text = "Omega"}
End Class
