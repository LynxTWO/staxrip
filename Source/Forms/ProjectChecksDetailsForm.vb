Imports StaxRip.UI

Public NotInheritable Class ProjectChecksDetailsForm
    Inherits DialogBase

    Private ReadOnly LayoutPanelValue As TableLayoutPanel
    Private ReadOnly ActionsPanelValue As FlowLayoutPanel
    Friend ReadOnly Property NoticeLabel As LabelEx
    Friend ReadOnly Property ResultsGrid As DataGridViewEx
    Friend ReadOnly Property CloseControl As ButtonEx

    Public Sub New(result As ProjectCheckResult)
        If result Is Nothing Then
            Throw New ArgumentNullException(NameOf(result))
        End If

        RememberPosition = False
        Name = "ProjectChecksDetailsForm"
        Text = "Project check details"
        ClientSize = New Size(720, 420)
        MinimumSize = New Size(600, 340)
        AutoScaleDimensions = New SizeF(96.0F, 96.0F)
        AutoScaleMode = AutoScaleMode.Dpi
        FormBorderStyle = FormBorderStyle.Sizable
        HelpButton = False
        MinimizeBox = False
        MaximizeBox = False
        ShowInTaskbar = False
        AccessibleName = "Project check details dialog"
        AccessibleDescription = "Shows read-only source-project-check outcomes and does not authorize encoding."
        AccessibleRole = AccessibleRole.Dialog

        LayoutPanelValue = New TableLayoutPanel With {
            .Name = "ProjectChecksDetailsLayout",
            .Dock = DockStyle.Fill,
            .Margin = Padding.Empty,
            .Padding = New Padding(8),
            .TabStop = False,
            .ColumnCount = 1,
            .RowCount = 3,
            .AccessibleName = "Project check details layout",
            .AccessibleDescription = "Arranges the notice, result table, and Close button.",
            .AccessibleRole = AccessibleRole.Pane
        }
        LayoutPanelValue.ColumnStyles.Add(New ColumnStyle(SizeType.Percent, 100.0F))
        LayoutPanelValue.RowStyles.Add(New RowStyle(SizeType.Absolute, 54.0F))
        LayoutPanelValue.RowStyles.Add(New RowStyle(SizeType.Percent, 100.0F))
        LayoutPanelValue.RowStyles.Add(New RowStyle(SizeType.Absolute, 42.0F))

        NoticeLabel = New LabelEx With {
            .Name = "ProjectChecksNotice",
            .Text = ProjectCheckPresentationText.DetailsNotice,
            .Dock = DockStyle.Fill,
            .Margin = Padding.Empty,
            .TextAlign = ContentAlignment.MiddleLeft,
            .AutoSize = False,
            .UseMnemonic = False,
            .TabStop = False,
            .AccessibleName = ProjectCheckPresentationText.DetailsNotice,
            .AccessibleDescription = "Explains that these results do not authorize a job or encoding.",
            .AccessibleRole = AccessibleRole.StaticText
        }

        ResultsGrid = New DataGridViewEx With {
            .Name = "ProjectChecksGrid",
            .Dock = DockStyle.Fill,
            .Margin = New Padding(0, 0, 0, 6),
            .ReadOnly = True,
            .MultiSelect = False,
            .SelectionMode = DataGridViewSelectionMode.FullRowSelect,
            .AllowUserToAddRows = False,
            .AllowUserToDeleteRows = False,
            .AllowUserToOrderColumns = False,
            .AllowUserToResizeRows = False,
            .AllowUserToResizeColumns = False,
            .RowHeadersVisible = False,
            .ShowCellToolTips = False,
            .StandardTab = True,
            .ClipboardCopyMode = DataGridViewClipboardCopyMode.Disable,
            .EditMode = DataGridViewEditMode.EditProgrammatically,
            .AutoGenerateColumns = False,
            .AutoSizeRowsMode = DataGridViewAutoSizeRowsMode.AllCells,
            .ColumnHeadersHeightSizeMode = DataGridViewColumnHeadersHeightSizeMode.DisableResizing,
            .AccessibleName = "Project check outcomes",
            .AccessibleDescription = "Read-only rows with Status, Check, and Explanation columns.",
            .AccessibleRole = AccessibleRole.Table
        }
        ResultsGrid.DefaultCellStyle.WrapMode = DataGridViewTriState.True

        Dim statusColumn = New DataGridViewTextBoxColumn With {
            .Name = "StatusColumn",
            .HeaderText = "Status",
            .ReadOnly = True,
            .SortMode = DataGridViewColumnSortMode.NotSortable,
            .Width = 110,
            .Resizable = DataGridViewTriState.False
        }
        Dim checkColumn = New DataGridViewTextBoxColumn With {
            .Name = "CheckColumn",
            .HeaderText = "Check",
            .ReadOnly = True,
            .SortMode = DataGridViewColumnSortMode.NotSortable,
            .Width = 180,
            .Resizable = DataGridViewTriState.False
        }
        Dim explanationColumn = New DataGridViewTextBoxColumn With {
            .Name = "ExplanationColumn",
            .HeaderText = "Explanation",
            .ReadOnly = True,
            .SortMode = DataGridViewColumnSortMode.NotSortable,
            .AutoSizeMode = DataGridViewAutoSizeColumnMode.Fill,
            .Resizable = DataGridViewTriState.False
        }
        ResultsGrid.Columns.AddRange({statusColumn, checkColumn, explanationColumn})

        For Each check In result.Checks
            ResultsGrid.Rows.Add(
                ProjectCheckPresentationText.StatusFor(check.Outcome),
                ProjectCheckPresentationText.CheckNameFor(check.Id),
                ProjectCheckPresentationText.ExplanationFor(check.MessageKey))
        Next

        ActionsPanelValue = New FlowLayoutPanel With {
            .Name = "ProjectChecksDialogActions",
            .Dock = DockStyle.Fill,
            .FlowDirection = FlowDirection.RightToLeft,
            .WrapContents = False,
            .Margin = Padding.Empty,
            .Padding = Padding.Empty,
            .TabStop = False,
            .AccessibleName = "Project check dialog actions",
            .AccessibleDescription = "Contains the Close action.",
            .AccessibleRole = AccessibleRole.Grouping
        }

        CloseControl = New ButtonEx With {
            .Name = "ProjectChecksClose",
            .Text = "&Close",
            .DialogResult = DialogResult.Cancel,
            .AutoSize = False,
            .Size = New Size(96, 30),
            .Margin = New Padding(0, 6, 0, 0),
            .TabStop = True,
            .AccessibleName = "Close project check details",
            .AccessibleDescription = "Closes the source-project-check details dialog.",
            .AccessibleRole = AccessibleRole.PushButton
        }

        ActionsPanelValue.Controls.Add(CloseControl)
        LayoutPanelValue.Controls.Add(NoticeLabel, 0, 0)
        LayoutPanelValue.Controls.Add(ResultsGrid, 0, 1)
        LayoutPanelValue.Controls.Add(ActionsPanelValue, 0, 2)
        Controls.Add(LayoutPanelValue)
        CancelButton = CloseControl

        AddHandler ThemeManager.CurrentThemeChanged, AddressOf OnThemeChanged
        ApplyTheme(ThemeManager.CurrentTheme)
    End Sub

    Protected Overrides Sub Dispose(disposing As Boolean)
        RemoveHandler ThemeManager.CurrentThemeChanged, AddressOf OnThemeChanged
        MyBase.Dispose(disposing)
    End Sub

    Protected Overrides Sub OnShown(e As EventArgs)
        MyBase.OnShown(e)

        If ResultsGrid.Rows.Count > 0 Then
            ResultsGrid.ClearSelection()
            ResultsGrid.CurrentCell = ResultsGrid.Rows(0).Cells(0)
            ResultsGrid.Rows(0).Selected = True
            ResultsGrid.Focus()
        End If
    End Sub

    Protected Overrides Sub OnSystemColorsChanged(e As EventArgs)
        MyBase.OnSystemColorsChanged(e)
        ApplyTheme(ThemeManager.CurrentTheme)
    End Sub

    Private Sub OnThemeChanged(theme As Theme)
        ApplyTheme(theme)
    End Sub

    Private Sub ApplyTheme(theme As Theme)
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
            NoticeLabel.BackColor = SystemColors.Control
            NoticeLabel.ForeColor = SystemColors.ControlText
            ResultsGrid.BackgroundColor = SystemColors.Window
            ResultsGrid.GridColor = SystemColors.WindowText
            ResultsGrid.DefaultCellStyle.BackColor = SystemColors.Window
            ResultsGrid.DefaultCellStyle.ForeColor = SystemColors.WindowText
            ResultsGrid.DefaultCellStyle.SelectionBackColor = SystemColors.Highlight
            ResultsGrid.DefaultCellStyle.SelectionForeColor = SystemColors.HighlightText
            ResultsGrid.ColumnHeadersDefaultCellStyle.BackColor = SystemColors.Control
            ResultsGrid.ColumnHeadersDefaultCellStyle.ForeColor = SystemColors.ControlText
            CloseControl.BackColor = SystemColors.Control
            CloseControl.ForeColor = SystemColors.ControlText
            CloseControl.BackDisabledColor = SystemColors.Control
            CloseControl.ForeDisabledColor = SystemColors.GrayText
            CloseControl.FlatAppearance.BorderColor = SystemColors.ControlText
        Else
            BackColor = theme.General.BackColor
            ForeColor = theme.General.ForeColor
            LayoutPanelValue.BackColor = theme.General.Controls.TableLayoutPanel.BackColor
            LayoutPanelValue.ForeColor = theme.General.Controls.TableLayoutPanel.ForeColor
            ActionsPanelValue.BackColor = theme.General.Controls.FlowLayoutPanel.BackColor
            ActionsPanelValue.ForeColor = theme.General.Controls.FlowLayoutPanel.ForeColor
            NoticeLabel.BackColor = theme.General.Controls.Label.BackColor
            NoticeLabel.ForeColor = theme.General.Controls.Label.ForeColor
            ResultsGrid.ApplyTheme(theme)
            ResultsGrid.DefaultCellStyle.BackColor = theme.General.Controls.GridView.BackColor
            ResultsGrid.DefaultCellStyle.ForeColor = theme.General.Controls.GridView.ForeColor
            ResultsGrid.DefaultCellStyle.SelectionBackColor = theme.General.Controls.GridView.BackHighlightColor
            ResultsGrid.DefaultCellStyle.SelectionForeColor = theme.General.Controls.GridView.ForeHighlightColor
            ResultsGrid.ColumnHeadersDefaultCellStyle.BackColor = theme.General.Controls.GridView.BackColor
            ResultsGrid.ColumnHeadersDefaultCellStyle.ForeColor = theme.General.Controls.GridView.ForeColor
            CloseControl.ApplyTheme(theme)
        End If

        ResultsGrid.EnableHeadersVisualStyles = False
    End Sub
End Class
