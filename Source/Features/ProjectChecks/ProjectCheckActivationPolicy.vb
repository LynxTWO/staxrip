Public Structure ProjectCheckActivationContext
    Private ReadOnly TransactionSucceededValue As Boolean
    Private ReadOnly RemainingSourceOpenDepthValue As Integer
    Private ReadOnly RemainingProjectCheckMutationDepthValue As Integer
    Private ReadOnly IsEncodingValue As Boolean
    Private ReadOnly EnteredOnUiThreadValue As Boolean
    Private ReadOnly JobProcessingAtEntryValue As Boolean
    Private ReadOnly JobProcessingAtCompletionValue As Boolean
    Private ReadOnly BatchModeAtEntryValue As Boolean
    Private ReadOnly BatchModeAtCompletionValue As Boolean
    Private ReadOnly StartupNoFocusCommandSuppressedValue As Boolean
    Private ReadOnly SameProjectAtCompletionValue As Boolean

    Public Sub New(
        transactionSucceeded As Boolean,
        remainingSourceOpenDepth As Integer,
        remainingProjectCheckMutationDepth As Integer,
        isEncoding As Boolean,
        enteredOnUiThread As Boolean,
        jobProcessingAtEntry As Boolean,
        jobProcessingAtCompletion As Boolean,
        batchModeAtEntry As Boolean,
        batchModeAtCompletion As Boolean,
        startupNoFocusCommandSuppressed As Boolean,
        sameProjectAtCompletion As Boolean)

        TransactionSucceededValue = transactionSucceeded
        RemainingSourceOpenDepthValue = remainingSourceOpenDepth
        RemainingProjectCheckMutationDepthValue = remainingProjectCheckMutationDepth
        IsEncodingValue = isEncoding
        EnteredOnUiThreadValue = enteredOnUiThread
        JobProcessingAtEntryValue = jobProcessingAtEntry
        JobProcessingAtCompletionValue = jobProcessingAtCompletion
        BatchModeAtEntryValue = batchModeAtEntry
        BatchModeAtCompletionValue = batchModeAtCompletion
        StartupNoFocusCommandSuppressedValue = startupNoFocusCommandSuppressed
        SameProjectAtCompletionValue = sameProjectAtCompletion
    End Sub

    Public ReadOnly Property TransactionSucceeded As Boolean
        Get
            Return TransactionSucceededValue
        End Get
    End Property

    Public ReadOnly Property RemainingSourceOpenDepth As Integer
        Get
            Return RemainingSourceOpenDepthValue
        End Get
    End Property

    Public ReadOnly Property RemainingProjectCheckMutationDepth As Integer
        Get
            Return RemainingProjectCheckMutationDepthValue
        End Get
    End Property

    Public ReadOnly Property IsEncoding As Boolean
        Get
            Return IsEncodingValue
        End Get
    End Property

    Public ReadOnly Property EnteredOnUiThread As Boolean
        Get
            Return EnteredOnUiThreadValue
        End Get
    End Property

    Public ReadOnly Property JobProcessingAtEntry As Boolean
        Get
            Return JobProcessingAtEntryValue
        End Get
    End Property

    Public ReadOnly Property JobProcessingAtCompletion As Boolean
        Get
            Return JobProcessingAtCompletionValue
        End Get
    End Property

    Public ReadOnly Property BatchModeAtEntry As Boolean
        Get
            Return BatchModeAtEntryValue
        End Get
    End Property

    Public ReadOnly Property BatchModeAtCompletion As Boolean
        Get
            Return BatchModeAtCompletionValue
        End Get
    End Property

    Public ReadOnly Property StartupNoFocusCommandSuppressed As Boolean
        Get
            Return StartupNoFocusCommandSuppressedValue
        End Get
    End Property

    Public ReadOnly Property SameProjectAtCompletion As Boolean
        Get
            Return SameProjectAtCompletionValue
        End Get
    End Property
End Structure

Public NotInheritable Class ProjectCheckActivationPolicy
    Private Sub New()
    End Sub

    Public Shared Function ShouldEvaluate(context As ProjectCheckActivationContext) As Boolean
        Return context.TransactionSucceeded AndAlso
            context.RemainingSourceOpenDepth = 0 AndAlso
            context.RemainingProjectCheckMutationDepth = 0 AndAlso
            Not context.IsEncoding AndAlso
            context.EnteredOnUiThread AndAlso
            Not context.JobProcessingAtEntry AndAlso
            Not context.JobProcessingAtCompletion AndAlso
            Not context.BatchModeAtEntry AndAlso
            Not context.BatchModeAtCompletion AndAlso
            Not context.StartupNoFocusCommandSuppressed AndAlso
            context.SameProjectAtCompletion
    End Function
End Class

Public Structure ProjectCheckRefreshContext
    Private ReadOnly PresentationKindValue As ProjectCheckPresentationKind
    Private ReadOnly SourceOpenDepthValue As Integer
    Private ReadOnly ProjectCheckMutationDepthValue As Integer
    Private ReadOnly IsUiThreadValue As Boolean
    Private ReadOnly IsJobProcessingValue As Boolean
    Private ReadOnly IsBatchModeValue As Boolean
    Private ReadOnly StartupNoFocusCommandSuppressedValue As Boolean

    Public Sub New(
        presentationKind As ProjectCheckPresentationKind,
        sourceOpenDepth As Integer,
        projectCheckMutationDepth As Integer,
        isUiThread As Boolean,
        isJobProcessing As Boolean,
        isBatchMode As Boolean,
        startupNoFocusCommandSuppressed As Boolean)

        PresentationKindValue = presentationKind
        SourceOpenDepthValue = sourceOpenDepth
        ProjectCheckMutationDepthValue = projectCheckMutationDepth
        IsUiThreadValue = isUiThread
        IsJobProcessingValue = isJobProcessing
        IsBatchModeValue = isBatchMode
        StartupNoFocusCommandSuppressedValue = startupNoFocusCommandSuppressed
    End Sub

    Public ReadOnly Property PresentationKind As ProjectCheckPresentationKind
        Get
            Return PresentationKindValue
        End Get
    End Property

    Public ReadOnly Property SourceOpenDepth As Integer
        Get
            Return SourceOpenDepthValue
        End Get
    End Property

    Public ReadOnly Property ProjectCheckMutationDepth As Integer
        Get
            Return ProjectCheckMutationDepthValue
        End Get
    End Property

    Public ReadOnly Property IsUiThread As Boolean
        Get
            Return IsUiThreadValue
        End Get
    End Property

    Public ReadOnly Property IsJobProcessing As Boolean
        Get
            Return IsJobProcessingValue
        End Get
    End Property

    Public ReadOnly Property IsBatchMode As Boolean
        Get
            Return IsBatchModeValue
        End Get
    End Property

    Public ReadOnly Property StartupNoFocusCommandSuppressed As Boolean
        Get
            Return StartupNoFocusCommandSuppressedValue
        End Get
    End Property
End Structure

Public NotInheritable Class ProjectCheckRefreshPolicy
    Private Sub New()
    End Sub

    Public Shared Function ShouldEvaluate(context As ProjectCheckRefreshContext) As Boolean
        Dim hasSuccessfulSourceCapability As Boolean

        Select Case context.PresentationKind
            Case ProjectCheckPresentationKind.Available,
                 ProjectCheckPresentationKind.RefreshRequired,
                 ProjectCheckPresentationKind.Unavailable

                hasSuccessfulSourceCapability = True
            Case ProjectCheckPresentationKind.Hidden
                hasSuccessfulSourceCapability = False
            Case Else
                Return False
        End Select

        Return hasSuccessfulSourceCapability AndAlso
            context.SourceOpenDepth = 0 AndAlso
            context.ProjectCheckMutationDepth = 0 AndAlso
            context.IsUiThread AndAlso
            Not context.IsJobProcessing AndAlso
            Not context.IsBatchMode AndAlso
            Not context.StartupNoFocusCommandSuppressed
    End Function
End Class
