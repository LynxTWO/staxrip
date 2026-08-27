Imports StaxRip.VideoEncoderCommandLine

Public Class FakeEncParams
    Inherits CommandLineParams

    Public Overrides ReadOnly Property OptionHelpId As String
        Get
            Return "fake"
        End Get
    End Property

    Property Alpha As New NumParam With {
        .Switch = "--alpha",
        .Text = "Alpha",
        .Config = {0, 10, 1},
        .Init = 3}

    Property Beta As New OptionParam With {
        .Switch = "--beta",
        .Text = "Beta",
        .Options = {"0: Off (default)", "1: On"},
        .Values = {"0", "1"},
        .Init = 0}

    Property Beta2 As New OptionParam With {
        .Switch = "--beta",
        .Text = "Beta 2",
        .Options = {"0: Off", "2: Two"},
        .Values = {"0", "2"},
        .Init = 0}

    Property Gamma As New OptionParam With {
        .Switch = "--gamma",
        .Text = "Gamma",
        .IntegerValue = True,
        .Options = {"0: VQ", "1: PSNR (default)", "2: SSIM"},
        .Init = 1}

    Property Delta As New OptionParam With {
        .Switch = "--delta",
        .Text = "Delta",
        .Options = {"Ultra Fast", "Very Slow", "0: ""quoted"" text"},
        .Init = 0}

    Property Epsilon As New OptionParam With {
        .Switches = {"--pass", "--passes", "--stats"},
        .Text = "Passes",
        .Options = {"1-pass", "2-pass"},
        .Values = {"1", "2"}}

    Property Zeta As New NumParam With {
        .HelpSwitch = "--zeta",
        .Text = "Zeta",
        .ArgsFunc = Function() "--zeta 1"}

    Property Eta As New BoolParam With {
        .Switch = "--eta",
        .NoSwitch = "--no-eta",
        .Text = "Eta",
        .Init = True}

    Property Chunks As New NumParam With {
        .OptionHelpKey = "staxrip.chunks",
        .Text = "Chunks",
        .Config = {1, 128},
        .Init = 1}

    Property Hidden As New StringParam With {
        .OptionHelpKey = "none",
        .Switch = "--hidden",
        .Text = "Hidden"}

    Property NoKey As New StringParam With {
        .Text = "Custom"}

    Property CustomSecond As New StringParam With {
        .OptionHelpKey = "staxrip.custom",
        .Text = "Custom" + BR + "Second Pass"}

    'Property Commented As New NumParam With {
    '    .Switch = "--commented",
    '    .Text = "Commented"}

    Overrides ReadOnly Property Items As List(Of CommandLineParam)
        Get
            If ItemsValue Is Nothing Then
                ItemsValue = New List(Of CommandLineParam)
                Add("Basic", Alpha, Beta, Beta2, Gamma, Delta, Epsilon, Zeta, Eta,
                    New NumParam With {.Switch = "--inline", .Text = "Inline", .Config = {0, 5}},
                    New LineParam(),
                    Chunks, Hidden, NoKey, CustomSecond)
                Add("Weird", New WeirdParam With {.Switch = "--weird", .Text = "Weird"})
                Dim built As New NumParam
                Add("Other", built)
            End If
            Return ItemsValue
        End Get
    End Property
End Class
