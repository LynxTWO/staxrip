
Imports System.Collections.Concurrent
Imports System.Threading
Imports System.Threading.Tasks
Imports StaxRip.VideoEncoderCommandLine
Imports StaxRip.UI

Public Class CommandLineForm
    Private Params As CommandLineParams
    Private SearchIndex As Integer
    Private Items As New List(Of Item)
    Private HighlightedControl As Control
    Private CommandLineHighlightingMenuItem As MenuItemEx
    Private CommandLineMouseUpSearchMenuItem As MenuItemEx
    Private GoToComboBoxCts As CancellationTokenSource
    Private OptionHelpTips As ToolTip
    Private Catalog As OptionHelpCatalog

    Property HTMLHelpFunc As Func(Of String)

    Event BeforeHelp()

    Sub New(params As CommandLineParams)
        InitializeComponent()
        SimpleUI.ScaleClientSize(50, 30)

        rtbCommandLine.ScrollBars = RichTextBoxScrollBars.None
        rtbCommandLine.ContextMenuStrip.Dispose()
        rtbCommandLine.ContextMenuStrip = cmsCommandLine

        Dim singleList As New List(Of String)

        For Each param In params.Items
            If param.GetKey = "" OrElse singleList.Contains(param.GetKey) Then
                'Throw New Exception("key found twice: " + param.GetKey)
            Else
                singleList.Add(param.GetKey)
            End If
        Next

        Me.Params = params
        Text = $"{params.Title} ({params.Items.Count} options) - {g.DefaultCommands.GetApplicationDetails()}"

        OptionHelpTips = New ToolTip(components) With {.AutoPopDelay = 20000, .InitialDelay = 700, .ReshowDelay = 300}
        OptionHelpCatalog.Log = AddressOf g.WriteDebugLog
        Catalog = OptionHelpCatalog.Get(params.OptionHelpId)

        lblDescription.Height = FontHeight * 3 + 6
        lblDescription.Text = "Point at an option, or move focus to it, to see what it does. Press F1 for details."

        InitUI()
        SelectLastPage()
        AddHandler params.ValueChanged, AddressOf ValueChanged
        params.RaiseValueChanged(Nothing)

        cbGoTo.Sorted = True
        cbGoTo.SendMessageCue("Search")
        cbGoTo.Select()

        cms.Form = Me

        cms.Add("Execute Command Line", Sub() params.Execute(), Keys.Control Or Keys.E, p.SourceFile <> "").SetImage(Symbol.fa_terminal)

        Dim a = Sub()
                    Clipboard.SetText(params.GetCommandLine(True, True))
                    MsgInfo("Command Line was copied.")
                End Sub

        cms.Add("Copy Command Line", a, Keys.Control Or Keys.Shift Or Keys.C).SetImage(Symbol.Copy)
        cms.Add("Show Command Line...", Sub() g.ShowCommandLinePreview("Command Line", params.GetCommandLinePreview, False), Keys.F4, Symbol.Code)
        cms.Add("Import Command Line...", Sub() If MsgQuestion("Import command line from clipboard?", Clipboard.GetText) = DialogResult.OK Then BasicVideoEncoder.ImportCommandLine(Clipboard.GetText, params), Keys.Control Or Keys.I).SetImage(Symbol.Download)

        cms.Add("-")

        a = Sub()
                CommandLineHighlightingMenuItem.Checked = Not CommandLineHighlightingMenuItem.Checked
                s.CommandLineHighlighting = CommandLineHighlightingMenuItem.Checked
                rtbCommandLine.Format(rtbCommandLine.Text.ToString)
            End Sub

        CommandLineHighlightingMenuItem = cms.Add("Command Line Highlighting", a, Keys.Control Or Keys.H)
        CommandLineHighlightingMenuItem.Checked = s.CommandLineHighlighting

        a = Sub()
                CommandLineMouseUpSearchMenuItem.Checked = Not CommandLineMouseUpSearchMenuItem.Checked
                s.CommandLinePreviewMouseUpSearch = CommandLineMouseUpSearchMenuItem.Checked
            End Sub

        CommandLineMouseUpSearchMenuItem = cms.Add("Preview Mouse-Up Search", a, Keys.Control Or Keys.P, "Clicking on an option in the preview navigates directly to the UI control.")
        CommandLineMouseUpSearchMenuItem.Checked = s.CommandLinePreviewMouseUpSearch

        cms.Add("-")

        Dim help = cms.Add("Help about this dialog", AddressOf ShowHelp)
        help.SetImage(Symbol.Help)
        help.ShortcutKeyDisplayString = "F1"

        cms.Add("Help about " + params.Package.Name, Sub() params.Package.ShowHelp(), Keys.Control Or Keys.F1).SetImage(Symbol.Help)

        cms.Add("-")

        ApplyTheme()

        AddHandler ThemeManager.CurrentThemeChanged, AddressOf OnThemeChanged
    End Sub

    Protected Overrides Sub Dispose(disposing As Boolean)
        RemoveHandler ThemeManager.CurrentThemeChanged, AddressOf OnThemeChanged
        components?.Dispose()
        MyBase.Dispose(disposing)
    End Sub

    Sub OnThemeChanged(theme As Theme)
        ApplyTheme(theme)
    End Sub

    Sub ApplyTheme()
        ApplyTheme(ThemeManager.CurrentTheme)
    End Sub

    Sub ApplyTheme(theme As Theme)
        If DesignHelp.IsDesignMode Then
            Exit Sub
        End If

        BackColor = theme.General.BackColor
    End Sub

    Sub SelectLastPage()
        SimpleUI.SelectLast(Params.Title + "page selection")
    End Sub

    Sub ValueChanged(item As CommandLineParam)
        rtbCommandLine.SetText(Params.GetCommandLine(False, False))
        rtbCommandLine.SelectionLength = 0
        rtbCommandLine.UpdateHeight()

        Task.Run(AddressOf UpdateSearchComboBox)
    End Sub

    Sub InitUI()
        Dim flowPanels As New List(Of Control)
        Dim currentFlow As SimpleUI.FlowPage = Nothing

        For x = 0 To Params.Items.Count - 1
            Dim param = Params.Items(x)
            Dim parent As FlowLayoutPanelEx = SimpleUI.GetFlowPage(param.Path)
            currentFlow = DirectCast(parent, SimpleUI.FlowPage)
            Dim helpControl As Control = Nothing
            Dim targets As New List(Of Control)

            If Not flowPanels.Contains(parent) Then
                flowPanels.Add(parent)
                parent.SuspendLayout()
            End If

            Dim help As String = Nothing

            If param.Switch <> "" Then
                help += param.Switch + BR
            End If

            If param.HelpSwitch <> "" Then
                help += param.HelpSwitch + BR
            End If

            If param.NoSwitch <> "" Then
                help += param.NoSwitch + BR
            End If

            Dim switches = param.Switches

            If Not switches.NothingOrEmpty Then
                help += switches.Join(BR) + BR
            End If

            help += BR

            If TypeOf param Is NumParam Then
                Dim nParam = DirectCast(param, NumParam)

                If nParam.Config(0) > Double.MinValue Then
                    help += "Minimum: " & nParam.Config(0) & BR
                End If

                If nParam.Config(1) < Double.MaxValue Then
                    help += "Maximum: " & nParam.Config(1) & BR
                End If
            End If

            help += BR

            If Not param.URLs.NothingOrEmpty Then
                help += String.Join(BR, param.URLs.Select(Function(val) "[" + val + " " + val + "]"))
            End If

            If param.Help <> "" Then
                help += param.Help
            End If

            If help <> "" Then
                If help.Contains(BR2 + BR) Then
                    help = help.Replace(BR2 + BR, BR2)
                End If

                If help.EndsWith(BR) Then
                    help = help.Trim
                End If
            End If

            Dim identity = param.OptionHelpIdentity(Params.OptionHelpId)
            Dim stanza As OptionHelpStanza = Nothing

            If Catalog IsNot Nothing Then
                Dim resolution = Catalog.Resolve(identity)

                If resolution.Outcome = "reviewed" OrElse resolution.Outcome = "alias" Then
                    stanza = resolution.Stanza
                End If
            End If

            Dim item As New Item With {.Page = currentFlow, .Param = param, .Stanza = stanza, .Identity = identity}

            If param.Label <> "" Then
                SimpleUI.AddLabel(parent, param.Label).MarginTop = FontHeight \ 2
            End If

            If TypeOf param Is LineParam Then
                Dim line = SimpleUI.AddLine(parent, "", 2, 2)
                DirectCast(param, LineParam).InitParam(line)
            ElseIf TypeOf param Is BoolParam Then
                Dim checkBox = SimpleUI.AddBool(parent)
                checkBox.Text = param.Text

                If stanza IsNot Nothing Then
                    checkBox.HelpAction = Sub() ShowOptionHelp(item)
                ElseIf param.HelpSwitch <> "" Then
                    Dim helpOptions = param.GetSwitches
                    checkBox.HelpAction = Sub() Params.ShowHelp(helpOptions)
                Else
                    checkBox.Help = help
                End If

                checkBox.MarginLeft = param.LeftMargin
                DirectCast(param, BoolParam).InitParam(checkBox)
                helpControl = checkBox
                targets.Add(checkBox)
            ElseIf TypeOf param Is NumParam Then
                Dim tempNumParam = DirectCast(param, NumParam)
                Dim nParam = DirectCast(param, NumParam)
                Dim numBlock = SimpleUI.AddNum(parent)

                If param.Text <> "" Then
                    numBlock.Label.Text = If(param.Text.EndsWithEx(":"), param.Text, param.Text + ":")
                End If

                If stanza IsNot Nothing Then
                    numBlock.Label.HelpAction = Sub() ShowOptionHelp(item)
                ElseIf param.HelpSwitch <> "" Then
                    Dim helpOptions = param.GetSwitches
                    numBlock.Label.HelpAction = Sub() Params.ShowHelp(helpOptions)
                Else
                    numBlock.Label.Help = help
                End If

                numBlock.NumEdit.Config = nParam.Config

                If nParam.HintText <> "" Then
                    SimpleUI.AddLabel(numBlock, nParam.HintText)
                End If

                AddHandler numBlock.Label.MouseDoubleClick, Sub() tempNumParam.Value = tempNumParam.DefaultValue
                DirectCast(param, NumParam).InitParam(numBlock.NumEdit)
                helpControl = numBlock.Label
                targets.Add(numBlock.Label)
                targets.Add(numBlock.NumEdit)
            ElseIf TypeOf param Is OptionParam Then
                Dim tempOptionParam = DirectCast(param, OptionParam)
                Dim oParam = DirectCast(param, OptionParam)
                Dim menuBlock = SimpleUI.AddMenu(Of Integer)(parent)
                menuBlock.Label.Text = If(param.Text.EndsWith(":"), param.Text, param.Text + ":")

                If stanza IsNot Nothing Then
                    menuBlock.Label.HelpAction = Sub() ShowOptionHelp(item)
                    menuBlock.Button.HelpAction = Sub() ShowOptionHelp(item)
                ElseIf param.HelpSwitch <> "" Then
                    Dim helpOptions = param.GetSwitches
                    menuBlock.Label.HelpAction = Sub() Params.ShowHelp(helpOptions)
                    menuBlock.Button.HelpAction = Sub() Params.ShowHelp(helpOptions)
                Else
                    menuBlock.Help = help
                End If

                If oParam.HintText <> "" Then
                    SimpleUI.AddLabel(menuBlock, oParam.HintText)
                End If

                helpControl = menuBlock.Label
                targets.Add(menuBlock.Label)
                targets.Add(menuBlock.Button)
                AddHandler menuBlock.Label.MouseDoubleClick, Sub() tempOptionParam.ValueChangedUser(tempOptionParam.DefaultValue)

                Dim max = oParam.Options.Select(Function(txt) txt.Length).Max

                If tempOptionParam.Expanded OrElse max > 24 Then
                    menuBlock.Button.Expand = True
                End If

                For x2 = 0 To oParam.Options.Length - 1
                    Dim menuItem = menuBlock.Button.Add(oParam.Options(x2), x2)

                    If stanza IsNot Nothing Then
                        Dim note = Catalog.ValueNote(stanza, oParam.GetEmittedValue(x2))

                        If note <> "" Then
                            menuItem.ToolTipText = OptionHelpParser.PlainText(note)
                        End If
                    End If
                Next

                oParam.InitParam(menuBlock.Button)
            ElseIf TypeOf param Is StringParam Then
                Dim tempItem = DirectCast(param, StringParam)
                Dim textBlock As SimpleUI.TextBlock

                If tempItem.BrowseFileFilter <> "" Then
                    Dim textButtonBlock = SimpleUI.AddTextButton(parent)
                    textButtonBlock.BrowseFile(tempItem.BrowseFileFilter)
                    textBlock = textButtonBlock
                ElseIf tempItem.Menu <> "" Then
                    Dim textMenuBlock = SimpleUI.AddTextMenu(parent)
                    textMenuBlock.AddMenu(tempItem.Menu)
                    textBlock = textMenuBlock
                Else
                    textBlock = SimpleUI.AddText(parent)
                End If

                textBlock.Label.Text = If(param.Text.EndsWith(":"), param.Text, param.Text + ":")

                If stanza IsNot Nothing Then
                    textBlock.Label.HelpAction = Sub() ShowOptionHelp(item)
                ElseIf param.HelpSwitch <> "" Then
                    Dim helpOptions = param.GetSwitches
                    textBlock.Label.HelpAction = Sub() Params.ShowHelp(helpOptions)
                Else
                    textBlock.Label.Help = help
                End If

                helpControl = textBlock.Label
                targets.Add(textBlock.Label)
                targets.Add(textBlock.Edit)
                AddHandler textBlock.Label.MouseDoubleClick, Sub() tempItem.Value = tempItem.DefaultValue
                textBlock.Edit.Expand = tempItem.Expand
                tempItem.InitParam(textBlock)
            End If

            If helpControl IsNot Nothing Then
                item.Control = helpControl
                item.Targets.AddRange(targets)
                Items.Add(item)

                If stanza IsNot Nothing Then
                    AttachOptionHelp(item)
                End If
            End If
        Next

        For Each panel In flowPanels
            panel.ResumeLayout()
        Next
    End Sub

    Private Sub AttachOptionHelp(item As Item)
        Dim caption = item.Param.Text.TrimEnd(":"c).Trim()
        Dim summary = OptionHelpParser.PlainText(item.Stanza.Summary)
        Dim tip = summary + BR + "Press F1 or right-click for details"
        Dim attached As New HashSet(Of Control)

        item.SearchText = OptionHelpCatalog.SearchText(item.Stanza, item.Identity)

        For Each target In item.Targets
            'NumEdit and TextEdit are user controls, their inner text box receives the mouse
            'and the focus, so every descendant has to be registered as well.
            For Each ctrl In {target}.Concat(target.GetAllControls())
                If Not attached.Add(ctrl) Then
                    Continue For
                End If

                OptionHelpTips.SetToolTip(ctrl, tip)
                AddHandler ctrl.MouseEnter, Sub() SetDescription(item)
                AddHandler ctrl.Enter, Sub() SetDescription(item)

                If Not TypeOf ctrl Is Label Then
                    ctrl.AccessibleName = caption
                    ctrl.AccessibleDescription = summary
                End If
            Next
        Next
    End Sub

    Private Function FindFocusedItem() As Item
        Return Items.FirstOrDefault(Function(i) i.Targets.Any(Function(t) t.ContainsFocus))
    End Function

    Private Function FindItemByIdentity(id As String) As Item
        Return Items.FirstOrDefault(Function(i) i.Identity = id)
    End Function

    Private Sub SetDescription(item As Item)
        If item.Stanza Is Nothing Then Exit Sub
        Dim caption = item.Param.Text.TrimEnd(":"c).Trim()
        Dim text = caption + ": " + OptionHelpParser.PlainText(item.Stanza.Summary)
        Dim whenToChange = item.Stanza.WhenToChange

        If whenToChange <> "" Then
            text += BR + "When to change: " + OptionHelpParser.PlainText(whenToChange)
        End If

        lblDescription.Text = text
    End Sub

    Private Sub ShowOptionHelp(item As Item)
        ' Task 7 replaces this stub with the details window.
        Params.ShowHelp(item.Param.GetSwitches)
    End Sub

    Public Class Item
        Property Page As SimpleUI.FlowPage
        Property Control As Control
        Property Param As CommandLineParam
        Property Targets As New List(Of Control)
        Property Stanza As OptionHelpStanza
        Property Identity As String
        Property SearchText As String
    End Class

    Protected Overrides Sub OnFormClosed(e As FormClosedEventArgs)
        SimpleUI.SaveLast(Params.Title + "page selection")
        RemoveHandler Params.ValueChanged, AddressOf ValueChanged
        MyBase.OnFormClosed(e)
    End Sub

    Sub CommandLineForm_HelpRequested(sender As Object, hlpevent As HelpEventArgs) Handles Me.HelpRequested
        If ModifierKeys = Keys.None Then
            Dim item = FindFocusedItem()

            If item IsNot Nothing AndAlso item.Stanza IsNot Nothing Then
                hlpevent.Handled = True
                ShowOptionHelp(item)
            Else
                ShowHelp()
            End If
        End If
    End Sub

    Sub ShowHelp()
        RaiseEvent BeforeHelp()

        Dim form As New HelpForm()
        form.Doc.WriteStart(Text)

        form.Doc.WriteH2("How to use the video encoder dialog")

        form.Doc.WriteParagraph("The context help is shown by right-clicking a label, dropdown or checkbox.")

        If cbGoTo.Visible Then
            form.Doc.WriteParagraph("The Search dropdown field at the dialog bottom left lists options and can be used to quickly find options, it searches command line switches, labels and dropdowns. Multiple matches can be cycled by pressing enter.")
        End If

        form.Doc.WriteParagraph("Numeric values and dropdown menu options can be reset to their default value by double clicking on the label.")
        form.Doc.WriteParagraph("The command line preview at the bottom of the dialog has a context menu that allows to quickly find and show options.")

        If HTMLHelpFunc IsNot Nothing Then
            form.Doc.Writer.WriteRaw(HTMLHelpFunc.Invoke)
        End If

        form.Doc.WriteTips(SimpleUI.ActivePage.TipProvider.GetTips)
        form.Show()
    End Sub

    Sub cbGoTo_KeyDown(sender As Object, e As KeyEventArgs) Handles cbGoTo.KeyDown
        If e.KeyData = Keys.Enter Then
            SearchIndex += 1
            cbGoTo_TextChanged(Nothing, Nothing)
        Else
            SearchIndex = 0
        End If

        If e.KeyData = Keys.Enter Then
            e.SuppressKeyPress = True
        End If
    End Sub

    Sub cbGoTo_TextChanged(sender As Object, e As EventArgs) Handles cbGoTo.TextChanged
        If HighlightedControl IsNot Nothing Then
            HighlightedControl.Font = FontManager.GetDefaultFont()
            HighlightedControl = Nothing
        End If

        Dim find = cbGoTo.Text.ToLowerInvariant()
        Dim findNoSpace = find.Replace(" ", "")
        Dim matchedItems As New HashSet(Of Item)

        If find.Length > 1 Then
            For Each item In Items
                If item.Param.Switch = cbGoTo.Text OrElse
                    item.Param.NoSwitch = cbGoTo.Text OrElse
                    item.Param.HelpSwitch = cbGoTo.Text Then

                    matchedItems.Add(item)
                End If

                If item.Param.Switches IsNot Nothing Then
                    For Each switch In item.Param.Switches
                        If switch = cbGoTo.Text Then
                            matchedItems.Add(item)
                        End If
                    Next
                End If
            Next

            For Each item In Items
                If item.Param.Switch.ToLowerEx.Contains(find) OrElse
                    item.Param.NoSwitch.ToLowerEx.Contains(find) OrElse
                    item.Param.HelpSwitch.ToLowerEx.Contains(find) OrElse
                    item.Param.Help.ToLowerEx.Contains(find) OrElse
                    item.Param.Text.ToLowerEx.Contains(find) Then

                    matchedItems.Add(item)
                End If

                If item.SearchText IsNot Nothing AndAlso item.SearchText.Contains(find) Then
                    matchedItems.Add(item)
                End If

                If item.Param.Switches IsNot Nothing Then
                    For Each switch In item.Param.Switches
                        If switch.ToLowerInvariant.Contains(find) Then
                            matchedItems.Add(item)
                        End If
                    Next
                End If

                If TypeOf item.Param Is OptionParam Then
                    Dim param = DirectCast(item.Param, OptionParam)

                    If param.Options IsNot Nothing Then
                        For Each value In param.Options
                            Dim valueNoSpace = value.Replace(" ", "")

                            If value.ToLowerInvariant.Contains(find) Then
                                matchedItems.Add(item)
                            End If

                            If valueNoSpace.ToLowerInvariant.Contains(findNoSpace) Then
                                matchedItems.Add(item)
                            End If

                            If value.ToLowerInvariant.Contains(findNoSpace) Then
                                matchedItems.Add(item)
                            End If

                            If valueNoSpace.ToLowerInvariant.Contains(find) Then
                                matchedItems.Add(item)
                            End If
                        Next
                    End If

                    If param.Values IsNot Nothing Then
                        For Each value In param.Values
                            Dim valueNoSpace = value.Replace(" ", "")

                            If value.ToLowerInvariant.Contains(find) Then
                                matchedItems.Add(item)
                            End If

                            If valueNoSpace.ToLowerInvariant.Contains(findNoSpace) Then
                                matchedItems.Add(item)
                            End If

                            If value.ToLowerInvariant.Contains(findNoSpace) Then
                                matchedItems.Add(item)
                            End If

                            If valueNoSpace.ToLowerInvariant.Contains(find) Then
                                matchedItems.Add(item)
                            End If
                        Next
                    End If
                End If
            Next

            Dim visibleItems = matchedItems.Where(Function(arg) arg.Param.Visible)

            If visibleItems.Count > 0 Then
                If SearchIndex >= visibleItems.Count Then
                    SearchIndex = 0
                End If

                Dim control = visibleItems(SearchIndex).Control
                SimpleUI.ShowPage(visibleItems(SearchIndex).Page)
                control.Font = FontManager.GetDefaultFont(0, FontStyle.Bold)
                HighlightedControl = control
                Exit Sub
            End If
        End If
    End Sub

    Private Sub UpdateSearchComboBox()
        If GoToComboBoxCts IsNot Nothing Then
            GoToComboBoxCts.Cancel()
            GoToComboBoxCts.Dispose()
        End If

        GoToComboBoxCts = New CancellationTokenSource()
        Dim token = GoToComboBoxCts.Token
        Dim queue = New ConcurrentQueue(Of String)

        Try
            Task.Run(Sub()
                         Dim source = Items.Where(Function(x) TypeOf x.Param IsNot NumParam AndAlso x.Param.Visible).Select(Function(x) x.Param)
                         Dim options = New ParallelOptions() With {.MaxDegreeOfParallelism = Environment.ProcessorCount \ 2, .CancellationToken = token}

                         Parallel.ForEach(source, options, Sub(item)
                                                               token.ThrowIfCancellationRequested()

                                                               If item.Switches IsNot Nothing Then
                                                                   For Each switch In item.Switches
                                                                       If Not queue.Contains(switch) Then
                                                                           token.ThrowIfCancellationRequested()
                                                                           queue.Enqueue(switch)
                                                                       End If
                                                                   Next
                                                               End If

                                                               If item.Switch <> "" AndAlso Not queue.Contains(item.Switch) Then
                                                                   token.ThrowIfCancellationRequested()
                                                                   queue.Enqueue(item.Switch)
                                                               End If

                                                               If item.NoSwitch <> "" AndAlso Not queue.Contains(item.NoSwitch) Then
                                                                   token.ThrowIfCancellationRequested()
                                                                   queue.Enqueue(item.NoSwitch)
                                                               End If

                                                               If item.HelpSwitch <> "" AndAlso Not queue.Contains(item.HelpSwitch) Then
                                                                   token.ThrowIfCancellationRequested()
                                                                   queue.Enqueue(item.HelpSwitch)
                                                               End If
                                                           End Sub)
                         Dim array = queue.OrderBy(Function(x) x).ToArray()

                         If array IsNot Nothing Then
                             cbGoTo.BeginUpdate()
                             cbGoTo.Items.Clear()
                             cbGoTo.Items.AddRange(array)
                             cbGoTo.EndUpdate()
                         End If
                     End Sub, token)
        Catch ex As Exception
        Finally
            cbGoTo.EndUpdate()
        End Try
    End Sub

    Sub CommandLineForm_FormClosed(sender As Object, e As FormClosedEventArgs) Handles Me.FormClosed
        g.MainForm.PopulateProfileMenu(DynamicMenuItemID.EncoderProfiles)
    End Sub

    Sub rtbCommandLine_MouseUp(sender As Object, e As MouseEventArgs) Handles rtbCommandLine.MouseUp
        If e.Button = MouseButtons.Left AndAlso s.CommandLinePreviewMouseUpSearch Then
            Dim find = FindOptionInPreview()

            If find <> "" Then
                cbGoTo.Text = find
            End If
        ElseIf e.Button = MouseButtons.Right Then
            cmsCommandLine.Items.Clear()

            Dim copyItem = cmsCommandLine.Add("Copy Selection", Sub() Clipboard.SetText(rtbCommandLine.SelectedText))
            copyItem.ShortcutKeyDisplayString = "Ctrl+C"
            copyItem.Visible = rtbCommandLine.SelectionLength > 0

            cmsCommandLine.Add("Copy Command Line", Sub() Clipboard.SetText(Params.GetCommandLine(True, True)))

            Dim find = FindOptionInPreview()

            If find <> "" Then
                Dim a = Sub()
                            cbGoTo.Text = find
                            cbGoTo.Focus()
                        End Sub

                cmsCommandLine.Add("Search " + find, a)
            End If

            cmsCommandLine.ApplyMarginFix()
            cmsCommandLine.Show(rtbCommandLine, e.Location)
        End If
    End Sub

    Function FindOptionInPreview() As String
        Dim find = rtbCommandLine.SelectedText

        If find.Length = 0 Then
            Dim pos = rtbCommandLine.SelectionStart
            Dim leftString = rtbCommandLine.Text.Substring(0, pos)
            Dim left = leftString.LastIndexOf(" ") + 1
            Dim right = rtbCommandLine.Text.Length
            Dim rightString = rtbCommandLine.Text.Substring(pos)
            Dim index = rightString.IndexOf(" ")

            If index > -1 Then
                right = pos + index
            End If

            If right - left > 0 Then
                find = rtbCommandLine.Text.Substring(left, right - left)
            End If
        End If

        If find.Length > 0 Then
            If find.Contains("=") Then
                find = find.Left("=")
            End If

            Return find
        End If
    End Function

    Sub rtbCommandLine_MouseDown(sender As Object, e As MouseEventArgs) Handles rtbCommandLine.MouseDown
        If e.Button = MouseButtons.Right AndAlso rtbCommandLine.SelectedText = "" Then
            rtbCommandLine.SelectionStart = rtbCommandLine.GetCharIndexFromPosition(e.Location)
        End If
    End Sub
End Class
