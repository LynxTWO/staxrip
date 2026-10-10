Imports System
Imports System.Collections.Generic
Imports System.Collections.ObjectModel

Public Enum SourceTargetTextState
    Distinct = 0
    Identical = 1
End Enum

Public Enum TargetPathCharacterState
    Valid = 0
    Invalid = 1
End Enum

Public Enum MuxerCoverConventionState
    NotApplicable = 0
    Valid = 1
    Invalid = 2
    Unknown = 3
End Enum

Public Enum ProjectCheckCategory
    Project = 0
    Target = 1
    Muxer = 2
End Enum

Public Enum ProjectCheckOutcome
    Fact = 0
    Warning = 1
    Blocker = 2
    Unknown = 3
    NotApplicable = 4
End Enum

Public Enum ProjectCheckSeverity
    NotApplicable = 0
    Information = 1
    Warning = 2
    Blocker = 3
    Unknown = 4
End Enum

Public Enum ProjectCheckOverallStatus
    BlockersFound = 0
    WarningsFound = 1
    ChecksIncomplete = 2
    SelectedChecksPassed = 3
End Enum

Public NotInheritable Class ProjectCheckSnapshot
    Private ReadOnly SourceTargetTextValue As SourceTargetTextState
    Private ReadOnly TargetPathCharactersValue As TargetPathCharacterState
    Private ReadOnly MuxerCoverConventionValue As MuxerCoverConventionState

    Public Sub New(
        sourceTargetText As SourceTargetTextState,
        targetPathCharacters As TargetPathCharacterState,
        muxerCoverConvention As MuxerCoverConventionState)

        SourceTargetTextValue = sourceTargetText
        TargetPathCharactersValue = targetPathCharacters
        MuxerCoverConventionValue = muxerCoverConvention
    End Sub

    Public ReadOnly Property SchemaVersion As Integer
        Get
            Return ProjectCheckCatalog.SchemaVersion
        End Get
    End Property

    Public ReadOnly Property SourceTargetText As SourceTargetTextState
        Get
            Return SourceTargetTextValue
        End Get
    End Property

    Public ReadOnly Property TargetPathCharacters As TargetPathCharacterState
        Get
            Return TargetPathCharactersValue
        End Get
    End Property

    Public ReadOnly Property MuxerCoverConvention As MuxerCoverConventionState
        Get
            Return MuxerCoverConventionValue
        End Get
    End Property
End Class

Public NotInheritable Class ProjectCheck
    Private ReadOnly IdValue As String
    Private ReadOnly CategoryValue As ProjectCheckCategory
    Private ReadOnly OutcomeValue As ProjectCheckOutcome
    Private ReadOnly SeverityValue As ProjectCheckSeverity
    Private ReadOnly MessageKeyValue As String
    Private ReadOnly SortOrderValue As Integer

    Friend Sub New(
        id As String,
        category As ProjectCheckCategory,
        outcome As ProjectCheckOutcome,
        severity As ProjectCheckSeverity,
        messageKey As String,
        sortOrder As Integer)

        If Not ProjectCheckCatalog.IsStableText(id) Then
            Throw New ArgumentException("The project-check id is invalid.", NameOf(id))
        End If

        If Not ProjectCheckCatalog.IsStableText(messageKey) Then
            Throw New ArgumentException("The project-check message key is invalid.", NameOf(messageKey))
        End If

        If sortOrder < 0 Then
            Throw New ArgumentOutOfRangeException(NameOf(sortOrder))
        End If

        If Not ProjectCheckCatalog.IsApprovedCheck(
            id,
            category,
            outcome,
            severity,
            messageKey,
            sortOrder) Then

            Throw New ArgumentException("The project-check row is not in the selected catalog.")
        End If

        IdValue = id
        CategoryValue = category
        OutcomeValue = outcome
        SeverityValue = severity
        MessageKeyValue = messageKey
        SortOrderValue = sortOrder
    End Sub

    Public ReadOnly Property Id As String
        Get
            Return IdValue
        End Get
    End Property

    Public ReadOnly Property Category As ProjectCheckCategory
        Get
            Return CategoryValue
        End Get
    End Property

    Public ReadOnly Property Outcome As ProjectCheckOutcome
        Get
            Return OutcomeValue
        End Get
    End Property

    Public ReadOnly Property Severity As ProjectCheckSeverity
        Get
            Return SeverityValue
        End Get
    End Property

    Public ReadOnly Property MessageKey As String
        Get
            Return MessageKeyValue
        End Get
    End Property

    Public ReadOnly Property SortOrder As Integer
        Get
            Return SortOrderValue
        End Get
    End Property
End Class

Public NotInheritable Class ProjectCheckResult
    Private ReadOnly OverallStatusValue As ProjectCheckOverallStatus
    Private ReadOnly ChecksValue As ReadOnlyCollection(Of ProjectCheck)

    Friend Sub New(checks As IEnumerable(Of ProjectCheck))
        If checks Is Nothing Then
            Throw New ArgumentNullException(NameOf(checks))
        End If

        Dim copiedChecks As New List(Of ProjectCheck)()

        For Each check In checks
            If check Is Nothing Then
                Throw New ArgumentException("A project-check result cannot contain an empty check.", NameOf(checks))
            End If

            copiedChecks.Add(check)
        Next

        If copiedChecks.Count <> ProjectCheckCatalog.CheckCount Then
            Throw New ArgumentException("A project-check result must contain the selected catalog.", NameOf(checks))
        End If

        If copiedChecks(0).Id <> ProjectCheckCatalog.SourceTargetTextDistinctId OrElse
            copiedChecks(1).Id <> ProjectCheckCatalog.TargetPathCharactersValidId OrElse
            copiedChecks(2).Id <> ProjectCheckCatalog.MuxerCoverConventionValidId Then

            Throw New ArgumentException("A project-check result must contain the ordered selected catalog.", NameOf(checks))
        End If

        OverallStatusValue = GetOverallStatus(copiedChecks)
        ChecksValue = copiedChecks.AsReadOnly()
    End Sub

    Private Shared Function GetOverallStatus(checks As IEnumerable(Of ProjectCheck)) As ProjectCheckOverallStatus
        Dim hasBlocker As Boolean
        Dim hasWarning As Boolean
        Dim hasUnknown As Boolean

        For Each check In checks
            Select Case check.Outcome
                Case ProjectCheckOutcome.Blocker
                    hasBlocker = True
                Case ProjectCheckOutcome.Warning
                    hasWarning = True
                Case ProjectCheckOutcome.Unknown
                    hasUnknown = True
                Case ProjectCheckOutcome.Fact, ProjectCheckOutcome.NotApplicable
                Case Else
                    Throw New ArgumentException("A project-check result contains an invalid outcome.", NameOf(checks))
            End Select
        Next

        If hasBlocker Then
            Return ProjectCheckOverallStatus.BlockersFound
        End If

        If hasWarning Then
            Return ProjectCheckOverallStatus.WarningsFound
        End If

        If hasUnknown Then
            Return ProjectCheckOverallStatus.ChecksIncomplete
        End If

        ' This bounded success state does not authorize Add Job or encoding.
        Return ProjectCheckOverallStatus.SelectedChecksPassed
    End Function

    Public ReadOnly Property SchemaVersion As Integer
        Get
            Return ProjectCheckCatalog.SchemaVersion
        End Get
    End Property

    Public ReadOnly Property OverallStatus As ProjectCheckOverallStatus
        Get
            Return OverallStatusValue
        End Get
    End Property

    Public ReadOnly Property Checks As ReadOnlyCollection(Of ProjectCheck)
        Get
            Return ChecksValue
        End Get
    End Property
End Class
