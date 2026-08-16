Imports System.Threading

Partial Public Class MainForm
    Private Const ProjectChecksMenuName As String = "ProjectChecksFixedMenu"
    Private Const ProjectChecksDetailsMenuName As String = "ProjectChecksFixedDetails"
    Private Const ProjectChecksRefreshMenuName As String = "ProjectChecksFixedRefresh"

    Private ProjectCheckCoordinatorValue As ProjectCheckCoordinator
    Private ProjectChecksSummaryValue As ProjectChecksSummaryControl
    Private ProjectCheckMenuReturnFocus As Control
    Private ProjectCheckSourceOpenDepth As Integer
    Private ProjectCheckUiThreadId As Integer
    Private ProjectCheckStartupNoFocusCommandSuppressed As Boolean
    Private ProjectCheckDetailsDialogValue As ProjectChecksDetailsForm
    Private ProjectCheckDetailsStateValue As ProjectCheckPresentationState

    Private Sub InitializeSourceProjectChecks()
        ProjectCheckUiThreadId = Thread.CurrentThread.ManagedThreadId
        ProjectCheckCoordinatorValue = New ProjectCheckCoordinator(
            AddressOf CreateProjectCheckSnapshot,
            AddressOf ProjectCheckEvaluator.Evaluate)

        ProjectChecksSummaryValue = New ProjectChecksSummaryControl With {
            .TabIndex = 45
        }
        tlpMain.SetColumnSpan(gbAssistant, 3)
        tlpMain.Controls.Add(ProjectChecksSummaryValue, 3, 4)

        AddHandler ProjectChecksSummaryValue.DetailsRequested,
            Sub(sender As Object, args As EventArgs)
                ShowProjectCheckDetails(TryCast(sender, Control))
            End Sub
        AddHandler ProjectChecksSummaryValue.RefreshRequested,
            Sub(sender As Object, args As EventArgs)
                RefreshProjectChecks()
            End Sub

        RenderCurrentProjectCheckPresentation()
    End Sub

    Private Function CreateProjectCheckSnapshot() As ProjectCheckSnapshot
        Dim currentProject = p
        If currentProject Is Nothing Then
            Throw New InvalidOperationException("No project is loaded.")
        End If

        Dim sourceTargetText = If(
            currentProject.SourceFile = currentProject.TargetFile,
            SourceTargetTextState.Identical,
            SourceTargetTextState.Distinct)
        Dim targetPathCharacters = If(
            Not String.IsNullOrEmpty(currentProject.TargetFile) AndAlso currentProject.TargetFile.IsValidPath(),
            TargetPathCharacterState.Valid,
            TargetPathCharacterState.Invalid)
        Dim muxerCoverConvention = ClassifyMuxerCoverConvention(currentProject.VideoEncoder?.Muxer)

        Return New ProjectCheckSnapshot(
            sourceTargetText,
            targetPathCharacters,
            muxerCoverConvention)
    End Function

    Private Shared Function ClassifyMuxerCoverConvention(muxer As Muxer) As MuxerCoverConventionState
        Dim mkvMuxer = TryCast(muxer, MkvMuxer)
        If mkvMuxer Is Nothing OrElse String.IsNullOrEmpty(mkvMuxer.CoverFile) Then
            Return MuxerCoverConventionState.NotApplicable
        End If

        Try
            Dim coverBase = mkvMuxer.CoverFile.Base()
            Dim coverExtension = mkvMuxer.CoverFile.Ext()
            Dim validBase = coverBase.EqualsAny("cover", "small_cover", "cover_land", "small_cover_land")
            Dim validExtension = coverExtension.EqualsAny("jpg", "png")

            Return If(
                validBase AndAlso validExtension,
                MuxerCoverConventionState.Valid,
                MuxerCoverConventionState.Invalid)
        Catch ex As ArgumentException
            Return MuxerCoverConventionState.Unknown
        Catch ex As NotSupportedException
            Return MuxerCoverConventionState.Unknown
        Catch ex As PathTooLongException
            Return MuxerCoverConventionState.Unknown
        End Try
    End Function

    Friend Sub BeginProjectCheckClearingMutation()
        Dim coordinator = ProjectCheckCoordinatorValue
        coordinator?.BeginClearingMutation()

        Try
            RenderCurrentProjectCheckPresentation()
        Catch
            coordinator?.EndClearingMutation()
            Throw
        End Try
    End Sub

    Friend Function EndProjectCheckClearingMutation() As Long
        If ProjectCheckCoordinatorValue Is Nothing Then
            Return Long.MinValue
        End If

        Dim completionGeneration = ProjectCheckCoordinatorValue.EndClearingMutation()
        RenderCurrentProjectCheckPresentation()
        Return completionGeneration
    End Function

    Friend Sub BeginProjectCheckInvalidatingMutation()
        Dim coordinator = ProjectCheckCoordinatorValue
        coordinator?.BeginInvalidatingMutation()

        Try
            RenderCurrentProjectCheckPresentation()
        Catch
            coordinator?.EndInvalidatingMutation()
            Throw
        End Try
    End Sub

    Friend Sub EndProjectCheckInvalidatingMutation()
        ProjectCheckCoordinatorValue?.EndInvalidatingMutation()
        RenderCurrentProjectCheckPresentation()
    End Sub

    Private ReadOnly Property ProjectCheckMutationDepth As Integer
        Get
            If ProjectCheckCoordinatorValue Is Nothing Then
                Return 0
            End If

            Return ProjectCheckCoordinatorValue.ActiveMutationCount
        End Get
    End Property

    Friend Sub InvalidateProjectChecks()
        ProjectCheckCoordinatorValue?.Invalidate()
        RenderCurrentProjectCheckPresentation()
    End Sub

    Private Sub EvaluateProjectChecks(expectedGeneration As Long)
        ProjectCheckCoordinatorValue?.EvaluateInitial(expectedGeneration)
        RenderCurrentProjectCheckPresentation()
    End Sub

    Friend Function RefreshProjectChecks() As ProjectCheckPresentationState
        If ProjectCheckCoordinatorValue Is Nothing Then
            Return ProjectCheckPresentationState.Hidden()
        End If

        Dim currentState = ProjectCheckCoordinatorValue.CurrentState
        Dim context = New ProjectCheckRefreshContext(
            currentState.Kind,
            Interlocked.CompareExchange(ProjectCheckSourceOpenDepth, 0, 0),
            ProjectCheckCoordinatorValue.ActiveMutationCount,
            IsProjectCheckUiThread(),
            g.IsJobProcessing,
            p IsNot Nothing AndAlso p.BatchMode,
            ProjectCheckStartupNoFocusCommandSuppressed)

        If Not ProjectCheckRefreshPolicy.ShouldEvaluate(context) Then
            RenderCurrentProjectCheckPresentation()
            Return currentState
        End If

        Dim refreshedState = ProjectCheckCoordinatorValue.Refresh()
        RenderCurrentProjectCheckPresentation()
        Return refreshedState
    End Function

    Friend ReadOnly Property CurrentProjectCheckPresentationState As ProjectCheckPresentationState
        Get
            If ProjectCheckCoordinatorValue Is Nothing Then
                Return ProjectCheckPresentationState.Hidden()
            End If

            Return ProjectCheckCoordinatorValue.CurrentState
        End Get
    End Property

    Private Function IsProjectCheckUiThread() As Boolean
        Return ProjectCheckUiThreadId <> 0 AndAlso
            Thread.CurrentThread.ManagedThreadId = ProjectCheckUiThreadId
    End Function

    Private Sub RenderCurrentProjectCheckPresentation()
        If ProjectCheckCoordinatorValue Is Nothing OrElse
            ProjectChecksSummaryValue Is Nothing OrElse
            IsDisposed OrElse
            Disposing Then

            Return
        End If

        If Not IsProjectCheckUiThread() Then
            If Not IsHandleCreated Then
                Return
            End If

            Try
                BeginInvoke(New MethodInvoker(AddressOf RenderCurrentProjectCheckPresentation))
            Catch ex As ObjectDisposedException
            Catch ex As InvalidOperationException
            End Try

            Return
        End If

        ' Re-read after a queued callback. A mutation may have changed the state.
        Dim currentState = ProjectCheckCoordinatorValue.CurrentState

        If ProjectCheckDetailsDialogValue IsNot Nothing AndAlso
            (currentState.Kind <> ProjectCheckPresentationKind.Available OrElse
             Not Object.ReferenceEquals(currentState, ProjectCheckDetailsStateValue)) Then

            ProjectCheckDetailsDialogValue.Close()
        End If

        Dim assistantColumnSpan = If(
            currentState.Kind = ProjectCheckPresentationKind.Hidden,
            4,
            3)

        tlpMain.SuspendLayout()
        Try
            ProjectChecksSummaryValue.Render(currentState)

            If tlpMain.GetColumnSpan(gbAssistant) <> assistantColumnSpan Then
                tlpMain.SetColumnSpan(gbAssistant, assistantColumnSpan)
            End If
        Finally
            tlpMain.ResumeLayout(True)
        End Try

        UpdateProjectCheckMenuState(currentState)
    End Sub

    Private Sub InstallProjectCheckMenu()
        For index = MenuStrip.Items.Count - 1 To 0 Step -1
            Dim item = MenuStrip.Items(index)
            If String.Equals(item.Name, ProjectChecksMenuName, StringComparison.Ordinal) Then
                MenuStrip.Items.RemoveAt(index)
                item.Dispose()
            End If
        Next

        Dim detailsItem = New ToolStripMenuItem With {
            .Name = ProjectChecksDetailsMenuName,
            .Text = "&View details...",
            .AccessibleName = "View project check details",
            .AccessibleDescription = "Opens the read-only source-project-check details dialog.",
            .AccessibleRole = AccessibleRole.MenuItem
        }
        Dim refreshItem = New ToolStripMenuItem With {
            .Name = ProjectChecksRefreshMenuName,
            .Text = "&Refresh project checks",
            .AccessibleName = "Refresh project checks",
            .AccessibleDescription = "Refreshes selected source-project checks without authorizing encoding.",
            .AccessibleRole = AccessibleRole.MenuItem
        }
        Dim menuItem = New ToolStripMenuItem With {
            .Name = ProjectChecksMenuName,
            .Text = "Source chec&ks",
            .AccessibleName = "Source checks",
            .AccessibleDescription = "Contains fixed source-project-check actions.",
            .AccessibleRole = AccessibleRole.MenuItem
        }

        AddHandler menuItem.DropDownOpening,
            Sub(sender As Object, args As EventArgs)
                ProjectCheckMenuReturnFocus = FindFocusedControl(Me)
                RenderCurrentProjectCheckPresentation()
            End Sub
        AddHandler detailsItem.Click,
            Sub(sender As Object, args As EventArgs)
                ShowProjectCheckDetails(ProjectCheckMenuReturnFocus)
            End Sub
        AddHandler refreshItem.Click,
            Sub(sender As Object, args As EventArgs)
                RefreshProjectChecks()
            End Sub

        menuItem.DropDownItems.Add(detailsItem)
        menuItem.DropDownItems.Add(refreshItem)
        MenuStrip.Items.Add(menuItem)
        RenderCurrentProjectCheckPresentation()
    End Sub

    Private Sub UpdateProjectCheckMenuState(state As ProjectCheckPresentationState)
        If state Is Nothing Then
            Return
        End If

        Dim menuItem = FindProjectCheckMenuItem(ProjectChecksMenuName)
        If menuItem Is Nothing Then
            Return
        End If

        For Each child As ToolStripItem In menuItem.DropDownItems
            If String.Equals(child.Name, ProjectChecksDetailsMenuName, StringComparison.Ordinal) Then
                child.Enabled = state.Kind = ProjectCheckPresentationKind.Available
            ElseIf String.Equals(child.Name, ProjectChecksRefreshMenuName, StringComparison.Ordinal) Then
                child.Enabled = state.Kind <> ProjectCheckPresentationKind.Hidden
            End If
        Next
    End Sub

    Private Function FindProjectCheckMenuItem(name As String) As ToolStripMenuItem
        For Each item As ToolStripItem In MenuStrip.Items
            If String.Equals(item.Name, name, StringComparison.Ordinal) Then
                Return TryCast(item, ToolStripMenuItem)
            End If
        Next

        Return Nothing
    End Function

    Private Sub ShowProjectCheckDetails(invokingControl As Control)
        Dim returnFocus = If(IsFocusRestoreCandidate(invokingControl), invokingControl, FindFocusedControl(Me))
        Dim currentState = CurrentProjectCheckPresentationState

        If currentState.Kind <> ProjectCheckPresentationKind.Available OrElse
            currentState.Result Is Nothing Then

            RenderCurrentProjectCheckPresentation()
            Return
        End If

        Try
            Using dialog As New ProjectChecksDetailsForm(currentState.Result)
                ProjectCheckDetailsDialogValue = dialog
                ProjectCheckDetailsStateValue = currentState

                ' Do not show a snapshot that was invalidated while the form was built.
                If Object.ReferenceEquals(CurrentProjectCheckPresentationState, currentState) Then
                    dialog.ShowDialog(Me)
                End If
            End Using
        Finally
            ProjectCheckDetailsDialogValue = Nothing
            ProjectCheckDetailsStateValue = Nothing

            If IsFocusRestoreCandidate(returnFocus) Then
                returnFocus.Focus()
            End If
        End Try
    End Sub

    Private Shared Function FindFocusedControl(root As Control) As Control
        If root Is Nothing OrElse root.IsDisposed Then
            Return Nothing
        End If

        Dim container = TryCast(root, ContainerControl)
        If container IsNot Nothing AndAlso container.ActiveControl IsNot Nothing Then
            Dim active = FindFocusedControl(container.ActiveControl)
            If active IsNot Nothing Then
                Return active
            End If
        End If

        For Each child As Control In root.Controls
            If child.ContainsFocus OrElse child.Focused Then
                Dim focused = FindFocusedControl(child)
                Return If(focused, child)
            End If
        Next

        Return If(root.Focused, root, Nothing)
    End Function

    Private Shared Function IsFocusRestoreCandidate(control As Control) As Boolean
        Return control IsNot Nothing AndAlso
            Not control.IsDisposed AndAlso
            control.CanFocus
    End Function
End Class
