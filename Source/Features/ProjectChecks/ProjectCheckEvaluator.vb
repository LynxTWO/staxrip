Imports System
Imports System.Collections.Generic

Public NotInheritable Class ProjectCheckEvaluator
    Private Sub New()
    End Sub

    Public Shared Function Evaluate(snapshot As ProjectCheckSnapshot) As ProjectCheckResult
        If snapshot Is Nothing Then
            Throw New ArgumentNullException(NameOf(snapshot))
        End If

        Dim checks = {
            EvaluateSourceTargetText(snapshot.SourceTargetText),
            EvaluateTargetPathCharacters(snapshot.TargetPathCharacters),
            EvaluateMuxerCoverConvention(snapshot.MuxerCoverConvention)
        }

        Return New ProjectCheckResult(checks)
    End Function

    Private Shared Function EvaluateSourceTargetText(state As SourceTargetTextState) As ProjectCheck
        Select Case state
            Case SourceTargetTextState.Distinct
                Return CreateCheck(
                    ProjectCheckCatalog.SourceTargetTextDistinctId,
                    ProjectCheckCategory.Project,
                    ProjectCheckOutcome.Fact,
                    ProjectCheckSeverity.Information,
                    ProjectCheckCatalog.SourceTargetTextDistinctFactMessageKey,
                    ProjectCheckCatalog.SourceTargetTextDistinctOrder)
            Case SourceTargetTextState.Identical
                Return CreateCheck(
                    ProjectCheckCatalog.SourceTargetTextDistinctId,
                    ProjectCheckCategory.Project,
                    ProjectCheckOutcome.Blocker,
                    ProjectCheckSeverity.Blocker,
                    ProjectCheckCatalog.SourceTargetTextDistinctBlockerMessageKey,
                    ProjectCheckCatalog.SourceTargetTextDistinctOrder)
            Case Else
                Return CreateCheck(
                    ProjectCheckCatalog.SourceTargetTextDistinctId,
                    ProjectCheckCategory.Project,
                    ProjectCheckOutcome.Unknown,
                    ProjectCheckSeverity.Unknown,
                    ProjectCheckCatalog.SourceTargetTextDistinctUnknownMessageKey,
                    ProjectCheckCatalog.SourceTargetTextDistinctOrder)
        End Select
    End Function

    Private Shared Function EvaluateTargetPathCharacters(state As TargetPathCharacterState) As ProjectCheck
        Select Case state
            Case TargetPathCharacterState.Valid
                Return CreateCheck(
                    ProjectCheckCatalog.TargetPathCharactersValidId,
                    ProjectCheckCategory.Target,
                    ProjectCheckOutcome.Fact,
                    ProjectCheckSeverity.Information,
                    ProjectCheckCatalog.TargetPathCharactersValidFactMessageKey,
                    ProjectCheckCatalog.TargetPathCharactersValidOrder)
            Case TargetPathCharacterState.Invalid
                Return CreateCheck(
                    ProjectCheckCatalog.TargetPathCharactersValidId,
                    ProjectCheckCategory.Target,
                    ProjectCheckOutcome.Warning,
                    ProjectCheckSeverity.Warning,
                    ProjectCheckCatalog.TargetPathCharactersValidWarningMessageKey,
                    ProjectCheckCatalog.TargetPathCharactersValidOrder)
            Case Else
                Return CreateCheck(
                    ProjectCheckCatalog.TargetPathCharactersValidId,
                    ProjectCheckCategory.Target,
                    ProjectCheckOutcome.Unknown,
                    ProjectCheckSeverity.Unknown,
                    ProjectCheckCatalog.TargetPathCharactersValidUnknownMessageKey,
                    ProjectCheckCatalog.TargetPathCharactersValidOrder)
        End Select
    End Function

    Private Shared Function EvaluateMuxerCoverConvention(state As MuxerCoverConventionState) As ProjectCheck
        Select Case state
            Case MuxerCoverConventionState.NotApplicable
                Return CreateCheck(
                    ProjectCheckCatalog.MuxerCoverConventionValidId,
                    ProjectCheckCategory.Muxer,
                    ProjectCheckOutcome.NotApplicable,
                    ProjectCheckSeverity.NotApplicable,
                    ProjectCheckCatalog.MuxerCoverConventionNotApplicableMessageKey,
                    ProjectCheckCatalog.MuxerCoverConventionValidOrder)
            Case MuxerCoverConventionState.Valid
                Return CreateCheck(
                    ProjectCheckCatalog.MuxerCoverConventionValidId,
                    ProjectCheckCategory.Muxer,
                    ProjectCheckOutcome.Fact,
                    ProjectCheckSeverity.Information,
                    ProjectCheckCatalog.MuxerCoverConventionFactMessageKey,
                    ProjectCheckCatalog.MuxerCoverConventionValidOrder)
            Case MuxerCoverConventionState.Invalid
                Return CreateCheck(
                    ProjectCheckCatalog.MuxerCoverConventionValidId,
                    ProjectCheckCategory.Muxer,
                    ProjectCheckOutcome.Blocker,
                    ProjectCheckSeverity.Blocker,
                    ProjectCheckCatalog.MuxerCoverConventionBlockerMessageKey,
                    ProjectCheckCatalog.MuxerCoverConventionValidOrder)
            Case MuxerCoverConventionState.Unknown
                Return CreateCheck(
                    ProjectCheckCatalog.MuxerCoverConventionValidId,
                    ProjectCheckCategory.Muxer,
                    ProjectCheckOutcome.Unknown,
                    ProjectCheckSeverity.Unknown,
                    ProjectCheckCatalog.MuxerCoverConventionUnknownMessageKey,
                    ProjectCheckCatalog.MuxerCoverConventionValidOrder)
            Case Else
                Return CreateCheck(
                    ProjectCheckCatalog.MuxerCoverConventionValidId,
                    ProjectCheckCategory.Muxer,
                    ProjectCheckOutcome.Unknown,
                    ProjectCheckSeverity.Unknown,
                    ProjectCheckCatalog.MuxerCoverConventionUnknownMessageKey,
                    ProjectCheckCatalog.MuxerCoverConventionValidOrder)
        End Select
    End Function

    Private Shared Function CreateCheck(
        id As String,
        category As ProjectCheckCategory,
        outcome As ProjectCheckOutcome,
        severity As ProjectCheckSeverity,
        messageKey As String,
        sortOrder As Integer) As ProjectCheck

        Return New ProjectCheck(id, category, outcome, severity, messageKey, sortOrder)
    End Function

End Class
