Imports System
Imports System.Globalization

Public NotInheritable Class ProjectCheckPresentationText
    Public Const LaterChecksCaveat As String =
        "Add Job and encode-time checks still run later. This result does not authorize encoding."

    Public Const DetailsNotice As String =
        "These results do not authorize encoding. Add Job and encode-time checks still run later."

    Private Sub New()
    End Sub

    Public Shared Function SummaryFor(state As ProjectCheckPresentationState) As String
        If state Is Nothing Then
            Throw New ArgumentNullException(NameOf(state))
        End If

        Select Case state.Kind
            Case ProjectCheckPresentationKind.Hidden
                Return String.Empty
            Case ProjectCheckPresentationKind.Unavailable
                Return "Project checks unavailable. " + LaterChecksCaveat
            Case ProjectCheckPresentationKind.RefreshRequired
                Return "Project checks require refresh. " + LaterChecksCaveat
            Case ProjectCheckPresentationKind.Available
                Return AvailableSummaryFor(state.Result)
            Case Else
                Throw New ArgumentOutOfRangeException(NameOf(state))
        End Select
    End Function

    Private Shared Function AvailableSummaryFor(result As ProjectCheckResult) As String
        If result Is Nothing Then
            Throw New ArgumentNullException(NameOf(result))
        End If

        Dim factCount As Integer
        Dim warningCount As Integer
        Dim blockerCount As Integer
        Dim unknownCount As Integer
        Dim notApplicableCount As Integer

        For Each check In result.Checks
            Select Case check.Outcome
                Case ProjectCheckOutcome.Fact
                    factCount += 1
                Case ProjectCheckOutcome.Warning
                    warningCount += 1
                Case ProjectCheckOutcome.Blocker
                    blockerCount += 1
                Case ProjectCheckOutcome.Unknown
                    unknownCount += 1
                Case ProjectCheckOutcome.NotApplicable
                    notApplicableCount += 1
                Case Else
                    Throw New ArgumentOutOfRangeException(NameOf(result))
            End Select
        Next

        Return OverallStatusFor(result.OverallStatus) + ". " +
            "Fact " + factCount.ToString(CultureInfo.InvariantCulture) + "; " +
            "Warning " + warningCount.ToString(CultureInfo.InvariantCulture) + "; " +
            "Blocker " + blockerCount.ToString(CultureInfo.InvariantCulture) + "; " +
            "Unknown " + unknownCount.ToString(CultureInfo.InvariantCulture) + "; " +
            "N/A " + notApplicableCount.ToString(CultureInfo.InvariantCulture) + ". " +
            LaterChecksCaveat
    End Function

    Public Shared Function StatusFor(outcome As ProjectCheckOutcome) As String
        Select Case outcome
            Case ProjectCheckOutcome.Fact
                Return "Fact"
            Case ProjectCheckOutcome.Warning
                Return "Warning"
            Case ProjectCheckOutcome.Blocker
                Return "Blocker"
            Case ProjectCheckOutcome.Unknown
                Return "Unknown"
            Case ProjectCheckOutcome.NotApplicable
                Return "Not applicable"
            Case Else
                Throw New ArgumentOutOfRangeException(NameOf(outcome))
        End Select
    End Function

    Public Shared Function CheckNameFor(id As String) As String
        Select Case id
            Case ProjectCheckCatalog.SourceTargetTextDistinctId
                Return "Source and target path text"
            Case ProjectCheckCatalog.TargetPathCharactersValidId
                Return "Target path characters"
            Case ProjectCheckCatalog.MuxerCoverConventionValidId
                Return "Matroska cover convention"
            Case Else
                Throw New ArgumentException("The project-check id is not presentable.", NameOf(id))
        End Select
    End Function

    Public Shared Function ExplanationFor(messageKey As String) As String
        Select Case messageKey
            Case ProjectCheckCatalog.SourceTargetTextDistinctFactMessageKey
                Return "Source and target use different path text."
            Case ProjectCheckCatalog.SourceTargetTextDistinctBlockerMessageKey
                Return "Source and target path text is identical. Change the target file path."
            Case ProjectCheckCatalog.SourceTargetTextDistinctUnknownMessageKey
                Return "The source-target comparison is unavailable."
            Case ProjectCheckCatalog.TargetPathCharactersValidFactMessageKey
                Return "The target path text contains no invalid path characters."
            Case ProjectCheckCatalog.TargetPathCharactersValidWarningMessageKey
                Return "The target path is empty or contains invalid path characters. Change the target file path."
            Case ProjectCheckCatalog.TargetPathCharactersValidUnknownMessageKey
                Return "The target path-character check is unavailable."
            Case ProjectCheckCatalog.MuxerCoverConventionNotApplicableMessageKey
                Return "No Matroska cover naming check applies."
            Case ProjectCheckCatalog.MuxerCoverConventionFactMessageKey
                Return "The Matroska cover name and extension follow the accepted convention."
            Case ProjectCheckCatalog.MuxerCoverConventionBlockerMessageKey
                Return "The Matroska cover must use cover, small_cover, cover_land, or small_cover_land with JPG or PNG."
            Case ProjectCheckCatalog.MuxerCoverConventionUnknownMessageKey
                Return "The Matroska cover name could not be classified."
            Case Else
                Throw New ArgumentException("The project-check message key is not presentable.", NameOf(messageKey))
        End Select
    End Function

    Private Shared Function OverallStatusFor(status As ProjectCheckOverallStatus) As String
        Select Case status
            Case ProjectCheckOverallStatus.BlockersFound
                Return "Blockers found"
            Case ProjectCheckOverallStatus.WarningsFound
                Return "Warnings found"
            Case ProjectCheckOverallStatus.ChecksIncomplete
                Return "Checks incomplete"
            Case ProjectCheckOverallStatus.SelectedChecksPassed
                Return "Selected checks passed"
            Case Else
                Throw New ArgumentOutOfRangeException(NameOf(status))
        End Select
    End Function
End Class
