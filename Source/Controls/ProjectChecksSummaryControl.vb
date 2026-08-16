Imports StaxRip.UI

Public NotInheritable Class ProjectChecksSummaryControl
    Inherits Panel

    Private ReadOnly LayoutPanelValue As TableLayoutPanel
    Private ReadOnly ActionsPanelValue As TableLayoutPanel
    Private PresentationVisibleValue As Boolean
    Private CurrentStateValue As ProjectCheckPresentationState

    Friend ReadOnly Property StatusLabel As LabelEx
    Friend ReadOnly Property DetailsButton As ButtonEx
    Friend ReadOnly Property RefreshButton As ButtonEx

    Friend ReadOnly Property PresentationVisible As Boolean
        Get
            Return PresentationVisibleValue
        End Get
    End Property

    Friend ReadOnly Property CurrentState As ProjectCheckPresentationState
        Get
            Return CurrentStateValue
        End Get
    End Property

    Public Event DetailsRequested As EventHandler
    Public Event RefreshRequested As EventHandler

    Public Sub New()
        Name = "ProjectChecksSummary"
        Dock = DockStyle.Fill
        Margin = New Padding(9, 0, 9, 9)
        Padding = New Padding(12)
        BorderStyle = BorderStyle.FixedSingle
        TabStop = False
        AccessibleName = "Project checks summary"
        AccessibleDescription = "Shows selected source-project checks and provides details and refresh actions."
        AccessibleRole = AccessibleRole.Grouping

        LayoutPanelValue = New TableLayoutPanel With {
            .Name = "ProjectChecksSummaryLayout",
            .Dock = DockStyle.Fill,
            .Margin = Padding.Empty,
            .Padding = Padding.Empty,
            .TabStop = False,
            .TabIndex = 0,
            .ColumnCount = 1,
            .RowCount = 2,
            .AccessibleName = "Project checks summary layout",
            .AccessibleDescription = "Arranges the project-check status and actions.",
            .AccessibleRole = AccessibleRole.Pane
        }
        LayoutPanelValue.ColumnStyles.Add(New ColumnStyle(SizeType.Percent, 100.0F))
        LayoutPanelValue.RowStyles.Add(New RowStyle(SizeType.Percent, 70.0F))
        LayoutPanelValue.RowStyles.Add(New RowStyle(SizeType.Percent, 30.0F))

        StatusLabel = New LabelEx With {
            .Name = "ProjectChecksStatus",
            .Dock = DockStyle.Fill,
            .Margin = Padding.Empty,
            .Padding = Padding.Empty,
            .TextAlign = ContentAlignment.MiddleLeft,
            .AutoSize = False,
            .AutoEllipsis = False,
            .UseMnemonic = False,
            .TabStop = False,
            .TabIndex = 0,
            .AccessibleName = "Project checks status",
            .AccessibleDescription = "States the overall result, counts, later checks, and non-authorization notice.",
            .AccessibleRole = AccessibleRole.StaticText
        }

        ActionsPanelValue = New TableLayoutPanel With {
            .Name = "ProjectChecksActions",
            .Dock = DockStyle.Fill,
            .Margin = Padding.Empty,
            .Padding = Padding.Empty,
            .TabStop = False,
            .TabIndex = 1,
            .ColumnCount = 2,
            .RowCount = 1,
            .AccessibleName = "Project checks actions",
            .AccessibleDescription = "Contains the Details and Refresh buttons.",
            .AccessibleRole = AccessibleRole.Grouping
        }
        ActionsPanelValue.ColumnStyles.Add(New ColumnStyle(SizeType.Percent, 55.0F))
        ActionsPanelValue.ColumnStyles.Add(New ColumnStyle(SizeType.Percent, 45.0F))
        ActionsPanelValue.RowStyles.Add(New RowStyle(SizeType.Percent, 100.0F))

        DetailsButton = New ButtonEx With {
            .Name = "ProjectChecksDetails",
            .Text = "&Details...",
            .Dock = DockStyle.Fill,
            .Margin = New Padding(0, 0, 6, 0),
            .AutoSize = False,
            .TabStop = True,
            .TabIndex = 0,
            .AccessibleName = "View project check details",
            .AccessibleDescription = "Opens the read-only source-project-check details dialog.",
            .AccessibleRole = AccessibleRole.PushButton
        }

        RefreshButton = New ButtonEx With {
            .Name = "ProjectChecksRefresh",
            .Text = "&Refresh",
            .Dock = DockStyle.Fill,
            .Margin = New Padding(6, 0, 0, 0),
            .AutoSize = False,
            .TabStop = True,
            .TabIndex = 1,
            .AccessibleName = "Refresh project checks",
            .AccessibleDescription = "Refreshes selected source-project checks without authorizing encoding.",
            .AccessibleRole = AccessibleRole.PushButton
        }

        AddHandler DetailsButton.Click,
            Sub(sender As Object, args As EventArgs)
                RaiseEvent DetailsRequested(DetailsButton, EventArgs.Empty)
            End Sub
        AddHandler RefreshButton.Click,
            Sub(sender As Object, args As EventArgs)
                RaiseEvent RefreshRequested(RefreshButton, EventArgs.Empty)
            End Sub

        ActionsPanelValue.Controls.Add(DetailsButton, 0, 0)
        ActionsPanelValue.Controls.Add(RefreshButton, 1, 0)
        LayoutPanelValue.Controls.Add(StatusLabel, 0, 0)
        LayoutPanelValue.Controls.Add(ActionsPanelValue, 0, 1)
        Controls.Add(LayoutPanelValue)

        Render(ProjectCheckPresentationState.Hidden())
        ApplyTheme(ThemeManager.CurrentTheme)
    End Sub

    Friend Sub Render(state As ProjectCheckPresentationState)
        If state Is Nothing Then
            Throw New ArgumentNullException(NameOf(state))
        End If

        CurrentStateValue = state
        PresentationVisibleValue = state.Kind <> ProjectCheckPresentationKind.Hidden
        MyBase.Visible = PresentationVisibleValue
        StatusLabel.Text = ProjectCheckPresentationText.SummaryFor(state)
        StatusLabel.AccessibleName = StatusLabel.Text
        DetailsButton.Enabled = state.Kind = ProjectCheckPresentationKind.Available
        RefreshButton.Enabled = state.Kind <> ProjectCheckPresentationKind.Hidden
    End Sub

    Friend Sub ApplyTheme(theme As Theme)
        If DesignHelp.IsDesignMode Then
            Return
        End If

        If SystemInformation.HighContrast Then
            BackColor = SystemColors.Control
            ForeColor = SystemColors.ControlText
            LayoutPanelValue.BackColor = SystemColors.Control
            LayoutPanelValue.ForeColor = SystemColors.ControlText
            ActionsPanelValue.BackColor = SystemColors.Control
            ActionsPanelValue.ForeColor = SystemColors.ControlText
            StatusLabel.BackColor = SystemColors.Control
            StatusLabel.ForeColor = SystemColors.ControlText

            For Each button In {DetailsButton, RefreshButton}
                button.BackColor = SystemColors.Control
                button.ForeColor = SystemColors.ControlText
                button.BackDisabledColor = SystemColors.Control
                button.ForeDisabledColor = SystemColors.GrayText
                button.FlatAppearance.BorderColor = SystemColors.ControlText
            Next
        Else
            BackColor = theme.General.Controls.Panel.BackColor
            ForeColor = theme.General.Controls.Panel.ForeColor
            LayoutPanelValue.BackColor = theme.General.Controls.TableLayoutPanel.BackColor
            LayoutPanelValue.ForeColor = theme.General.Controls.TableLayoutPanel.ForeColor
            ActionsPanelValue.BackColor = theme.General.Controls.TableLayoutPanel.BackColor
            ActionsPanelValue.ForeColor = theme.General.Controls.TableLayoutPanel.ForeColor
            StatusLabel.BackColor = theme.General.Controls.Label.BackColor
            StatusLabel.ForeColor = theme.General.Controls.Label.ForeColor
            DetailsButton.ApplyTheme(theme)
            RefreshButton.ApplyTheme(theme)
        End If
    End Sub

    Protected Overrides Sub OnSystemColorsChanged(e As EventArgs)
        MyBase.OnSystemColorsChanged(e)
        ApplyTheme(ThemeManager.CurrentTheme)
    End Sub
End Class
