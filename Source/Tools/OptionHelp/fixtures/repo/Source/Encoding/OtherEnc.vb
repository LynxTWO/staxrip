Public Class OtherEncParams
    Inherits CommandLineParams

    Property Alpha As New NumParam With {
        .Switch = "--alpha",
        .Text = "Alpha"}
End Class
