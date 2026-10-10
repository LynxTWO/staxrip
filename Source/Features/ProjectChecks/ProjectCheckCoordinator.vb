Imports System

Public Enum ProjectCheckPresentationKind
    Hidden = 0
    Available = 1
    RefreshRequired = 2
    Unavailable = 3
End Enum

Public NotInheritable Class ProjectCheckPresentationState
    Private Shared ReadOnly HiddenValue As New ProjectCheckPresentationState(
        ProjectCheckPresentationKind.Hidden,
        Nothing)
    Private Shared ReadOnly RefreshRequiredValue As New ProjectCheckPresentationState(
        ProjectCheckPresentationKind.RefreshRequired,
        Nothing)
    Private Shared ReadOnly UnavailableValue As New ProjectCheckPresentationState(
        ProjectCheckPresentationKind.Unavailable,
        Nothing)

    Private ReadOnly KindValue As ProjectCheckPresentationKind
    Private ReadOnly ResultValue As ProjectCheckResult

    Private Sub New(kind As ProjectCheckPresentationKind, result As ProjectCheckResult)
        Select Case kind
            Case ProjectCheckPresentationKind.Available
                If result Is Nothing Then
                    Throw New ArgumentNullException(NameOf(result))
                End If
            Case ProjectCheckPresentationKind.Hidden,
                 ProjectCheckPresentationKind.RefreshRequired,
                 ProjectCheckPresentationKind.Unavailable

                If result IsNot Nothing Then
                    Throw New ArgumentException("Only an available presentation can contain a result.", NameOf(result))
                End If
            Case Else
                Throw New ArgumentOutOfRangeException(NameOf(kind))
        End Select

        KindValue = kind
        ResultValue = result
    End Sub

    Public ReadOnly Property Kind As ProjectCheckPresentationKind
        Get
            Return KindValue
        End Get
    End Property

    Public ReadOnly Property Result As ProjectCheckResult
        Get
            Return ResultValue
        End Get
    End Property

    Public Shared Function Hidden() As ProjectCheckPresentationState
        Return HiddenValue
    End Function

    Public Shared Function Available(result As ProjectCheckResult) As ProjectCheckPresentationState
        Return New ProjectCheckPresentationState(ProjectCheckPresentationKind.Available, result)
    End Function

    Public Shared Function RefreshRequired() As ProjectCheckPresentationState
        Return RefreshRequiredValue
    End Function

    Public Shared Function Unavailable() As ProjectCheckPresentationState
        Return UnavailableValue
    End Function
End Class

Public NotInheritable Class ProjectCheckCoordinator
    Private ReadOnly SyncRoot As New Object()
    Private ReadOnly SnapshotFactory As Func(Of ProjectCheckSnapshot)
    Private ReadOnly SnapshotEvaluator As Func(Of ProjectCheckSnapshot, ProjectCheckResult)
    Private Generation As Long
    ' Only the outermost successful clearing scope can mint this one-shot token.
    Private PendingInitialGeneration As Long = Long.MinValue
    Private ActiveClearingMutationCount As Integer
    Private ActiveInvalidatingMutationCount As Integer
    Private StateValue As ProjectCheckPresentationState = ProjectCheckPresentationState.Hidden()

    Public Sub New(
        snapshotFactory As Func(Of ProjectCheckSnapshot),
        snapshotEvaluator As Func(Of ProjectCheckSnapshot, ProjectCheckResult))

        If snapshotFactory Is Nothing Then
            Throw New ArgumentNullException(NameOf(snapshotFactory))
        End If

        If snapshotEvaluator Is Nothing Then
            Throw New ArgumentNullException(NameOf(snapshotEvaluator))
        End If

        Me.SnapshotFactory = snapshotFactory
        Me.SnapshotEvaluator = snapshotEvaluator
    End Sub

    Public ReadOnly Property CurrentState As ProjectCheckPresentationState
        Get
            SyncLock SyncRoot
                Return StateValue
            End SyncLock
        End Get
    End Property

    Friend ReadOnly Property ActiveMutationCount As Integer
        Get
            SyncLock SyncRoot
                Return GetActiveMutationCount()
            End SyncLock
        End Get
    End Property

    Public Function Clear() As ProjectCheckPresentationState
        SyncLock SyncRoot
            Generation += 1
            PendingInitialGeneration = Long.MinValue
            StateValue = ProjectCheckPresentationState.Hidden()
            Return StateValue
        End SyncLock
    End Function

    Public Function Invalidate() As ProjectCheckPresentationState
        SyncLock SyncRoot
            Generation += 1
            PendingInitialGeneration = Long.MinValue
            StateValue = GetInvalidatedState(StateValue)
            Return StateValue
        End SyncLock
    End Function

    Friend Function BeginClearingMutation() As ProjectCheckPresentationState
        SyncLock SyncRoot
            Generation += 1
            PendingInitialGeneration = Long.MinValue
            ActiveClearingMutationCount += 1
            StateValue = ProjectCheckPresentationState.Hidden()
            Return StateValue
        End SyncLock
    End Function

    Friend Function EndClearingMutation() As Long
        SyncLock SyncRoot
            If ActiveClearingMutationCount <= 0 Then
                Throw New InvalidOperationException("A clearing project-check mutation scope is not active.")
            End If

            Generation += 1
            StateValue = ProjectCheckPresentationState.Hidden()
            ActiveClearingMutationCount -= 1

            If GetActiveMutationCount() = 0 Then
                PendingInitialGeneration = Generation
                Return PendingInitialGeneration
            End If

            PendingInitialGeneration = Long.MinValue
            Return Long.MinValue
        End SyncLock
    End Function

    Friend Function BeginInvalidatingMutation() As ProjectCheckPresentationState
        SyncLock SyncRoot
            Generation += 1
            PendingInitialGeneration = Long.MinValue
            ActiveInvalidatingMutationCount += 1
            StateValue = GetInvalidatedState(StateValue)
            Return StateValue
        End SyncLock
    End Function

    Friend Function EndInvalidatingMutation() As ProjectCheckPresentationState
        SyncLock SyncRoot
            If ActiveInvalidatingMutationCount <= 0 Then
                Throw New InvalidOperationException("An invalidating project-check mutation scope is not active.")
            End If

            Generation += 1
            PendingInitialGeneration = Long.MinValue
            StateValue = GetInvalidatedState(StateValue)
            ActiveInvalidatingMutationCount -= 1
            Return StateValue
        End SyncLock
    End Function

    Friend Function EvaluateInitial(expectedGeneration As Long) As ProjectCheckPresentationState
        Dim observedGeneration As Long

        SyncLock SyncRoot
            If GetActiveMutationCount() <> 0 OrElse
                expectedGeneration = Long.MinValue OrElse
                Generation <> expectedGeneration OrElse
                PendingInitialGeneration <> expectedGeneration OrElse
                StateValue.Kind <> ProjectCheckPresentationKind.Hidden Then

                Return StateValue
            End If

            observedGeneration = Generation
            PendingInitialGeneration = Long.MinValue
        End SyncLock

        Return EvaluateAndPublish(observedGeneration)
    End Function

    Friend Function Refresh() As ProjectCheckPresentationState
        Dim observedGeneration As Long

        SyncLock SyncRoot
            If GetActiveMutationCount() <> 0 OrElse Not CanRefresh(StateValue.Kind) Then
                Return StateValue
            End If

            observedGeneration = Generation
        End SyncLock

        Return EvaluateAndPublish(observedGeneration)
    End Function

    Private Function EvaluateAndPublish(observedGeneration As Long) As ProjectCheckPresentationState
        ' User/project mapping runs outside the lock. The generation check below
        ' rejects the result if any mutation crosses this evaluation window.
        Dim nextState = TryCreateEvaluationState()

        SyncLock SyncRoot
            If observedGeneration = Generation AndAlso GetActiveMutationCount() = 0 Then
                StateValue = nextState
            End If

            Return StateValue
        End SyncLock
    End Function

    Private Shared Function CanRefresh(kind As ProjectCheckPresentationKind) As Boolean
        Return kind = ProjectCheckPresentationKind.Available OrElse
            kind = ProjectCheckPresentationKind.RefreshRequired OrElse
            kind = ProjectCheckPresentationKind.Unavailable
    End Function

    Private Function GetActiveMutationCount() As Integer
        Return ActiveClearingMutationCount + ActiveInvalidatingMutationCount
    End Function

    Private Shared Function GetInvalidatedState(
        state As ProjectCheckPresentationState) As ProjectCheckPresentationState

        Select Case state.Kind
            Case ProjectCheckPresentationKind.Available,
                 ProjectCheckPresentationKind.Unavailable

                Return ProjectCheckPresentationState.RefreshRequired()
            Case ProjectCheckPresentationKind.Hidden,
                 ProjectCheckPresentationKind.RefreshRequired

                Return state
            Case Else
                Return ProjectCheckPresentationState.Hidden()
        End Select
    End Function

    Private Function TryCreateEvaluationState() As ProjectCheckPresentationState
        Try
            Dim snapshot = SnapshotFactory()
            If snapshot Is Nothing Then
                Throw New InvalidOperationException("The snapshot factory returned no snapshot.")
            End If

            Dim result = SnapshotEvaluator(snapshot)
            If result Is Nothing Then
                Throw New InvalidOperationException("The snapshot evaluator returned no result.")
            End If

            Return ProjectCheckPresentationState.Available(result)
        Catch ex As Exception
            Return ProjectCheckPresentationState.Unavailable()
        End Try
    End Function
End Class
