Imports System

Public NotInheritable Class ProjectCheckCatalog
    Public Const SchemaVersion As Integer = 1
    Public Const CheckCount As Integer = 3
    Public Const MaxStableTextLength As Integer = 64

    Public Const SourceTargetTextDistinctId As String = "project.source-target-text-distinct"
    Public Const TargetPathCharactersValidId As String = "target.path-characters-valid"
    Public Const MuxerCoverConventionValidId As String = "muxer.cover-convention-valid"

    Public Const SourceTargetTextDistinctOrder As Integer = 100
    Public Const TargetPathCharactersValidOrder As Integer = 200
    Public Const MuxerCoverConventionValidOrder As Integer = 300

    Public Const SourceTargetTextDistinctFactMessageKey As String = "project.source-target-text-distinct.fact"
    Public Const SourceTargetTextDistinctBlockerMessageKey As String = "project.source-target-text-distinct.blocker"
    Public Const SourceTargetTextDistinctUnknownMessageKey As String = "project.source-target-text-distinct.unknown"

    Public Const TargetPathCharactersValidFactMessageKey As String = "target.path-characters-valid.fact"
    Public Const TargetPathCharactersValidWarningMessageKey As String = "target.path-characters-valid.warning"
    Public Const TargetPathCharactersValidUnknownMessageKey As String = "target.path-characters-valid.unknown"

    Public Const MuxerCoverConventionNotApplicableMessageKey As String = "muxer.cover-convention-valid.not-applicable"
    Public Const MuxerCoverConventionFactMessageKey As String = "muxer.cover-convention-valid.fact"
    Public Const MuxerCoverConventionBlockerMessageKey As String = "muxer.cover-convention-valid.blocker"
    Public Const MuxerCoverConventionUnknownMessageKey As String = "muxer.cover-convention-valid.unknown"

    Private Sub New()
    End Sub

    Friend Shared Function IsStableText(value As String) As Boolean
        If String.IsNullOrEmpty(value) OrElse value.Length > MaxStableTextLength Then
            Return False
        End If

        For Each character In value
            Dim isLowercaseAscii = character >= "a"c AndAlso character <= "z"c
            Dim isDigit = character >= "0"c AndAlso character <= "9"c

            If Not isLowercaseAscii AndAlso Not isDigit AndAlso character <> "."c AndAlso character <> "-"c Then
                Return False
            End If
        Next

        Return True
    End Function

    Friend Shared Function IsApprovedCheck(
        id As String,
        category As ProjectCheckCategory,
        outcome As ProjectCheckOutcome,
        severity As ProjectCheckSeverity,
        messageKey As String,
        sortOrder As Integer) As Boolean

        Select Case id
            Case SourceTargetTextDistinctId
                If category <> ProjectCheckCategory.Project OrElse sortOrder <> SourceTargetTextDistinctOrder Then
                    Return False
                End If

                Select Case outcome
                    Case ProjectCheckOutcome.Fact
                        Return severity = ProjectCheckSeverity.Information AndAlso
                            messageKey = SourceTargetTextDistinctFactMessageKey
                    Case ProjectCheckOutcome.Blocker
                        Return severity = ProjectCheckSeverity.Blocker AndAlso
                            messageKey = SourceTargetTextDistinctBlockerMessageKey
                    Case ProjectCheckOutcome.Unknown
                        Return severity = ProjectCheckSeverity.Unknown AndAlso
                            messageKey = SourceTargetTextDistinctUnknownMessageKey
                    Case Else
                        Return False
                End Select
            Case TargetPathCharactersValidId
                If category <> ProjectCheckCategory.Target OrElse sortOrder <> TargetPathCharactersValidOrder Then
                    Return False
                End If

                Select Case outcome
                    Case ProjectCheckOutcome.Fact
                        Return severity = ProjectCheckSeverity.Information AndAlso
                            messageKey = TargetPathCharactersValidFactMessageKey
                    Case ProjectCheckOutcome.Warning
                        Return severity = ProjectCheckSeverity.Warning AndAlso
                            messageKey = TargetPathCharactersValidWarningMessageKey
                    Case ProjectCheckOutcome.Unknown
                        Return severity = ProjectCheckSeverity.Unknown AndAlso
                            messageKey = TargetPathCharactersValidUnknownMessageKey
                    Case Else
                        Return False
                End Select
            Case MuxerCoverConventionValidId
                If category <> ProjectCheckCategory.Muxer OrElse sortOrder <> MuxerCoverConventionValidOrder Then
                    Return False
                End If

                Select Case outcome
                    Case ProjectCheckOutcome.NotApplicable
                        Return severity = ProjectCheckSeverity.NotApplicable AndAlso
                            messageKey = MuxerCoverConventionNotApplicableMessageKey
                    Case ProjectCheckOutcome.Fact
                        Return severity = ProjectCheckSeverity.Information AndAlso
                            messageKey = MuxerCoverConventionFactMessageKey
                    Case ProjectCheckOutcome.Blocker
                        Return severity = ProjectCheckSeverity.Blocker AndAlso
                            messageKey = MuxerCoverConventionBlockerMessageKey
                    Case ProjectCheckOutcome.Unknown
                        Return severity = ProjectCheckSeverity.Unknown AndAlso
                            messageKey = MuxerCoverConventionUnknownMessageKey
                    Case Else
                        Return False
                End Select
            Case Else
                Return False
        End Select
    End Function
End Class
