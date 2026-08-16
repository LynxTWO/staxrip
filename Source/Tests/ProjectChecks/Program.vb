Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Reflection
Imports System.Text
Imports System.Threading

Friend Module ProjectCheckEvaluatorTestsProgram
    Private AssertionCount As Integer
    Private ActivationVectorCount As Integer
    Private RefreshVectorCount As Integer
    Private CurrentTest As String = "startup"

    Public Sub Main()
        Try
            RunTest("catalog", AddressOf TestCatalog)
            RunTest("evaluator-matrix", AddressOf TestEvaluatorMatrix)
            RunTest("precedence", AddressOf TestOverallPrecedence)
            RunTest("immutability", AddressOf TestImmutabilityAndDeterminism)
            RunTest("culture-privacy", AddressOf TestCultureAndPrivacy)
            RunTest("activation-policy", AddressOf TestActivationPolicyExhaustive)
            RunTest("refresh-policy", AddressOf TestRefreshPolicyExhaustive)
            RunTest("model-boundaries", AddressOf TestModelBoundaries)
            RunTest("coordinator", AddressOf TestCoordinator)
            RunTest("presentation-text", AddressOf TestPresentationText)

            Console.WriteLine(
                "PASS ProjectCheckEvaluatorTests assertions=" & AssertionCount.ToString(CultureInfo.InvariantCulture) &
                " activation_vectors=" & ActivationVectorCount.ToString(CultureInfo.InvariantCulture) &
                " refresh_vectors=" & RefreshVectorCount.ToString(CultureInfo.InvariantCulture))
            Environment.ExitCode = 0
        Catch ex As TestFailureException
            Console.WriteLine("FAIL ProjectCheckEvaluatorTests test=" & SafeToken(CurrentTest) & " detail=" & SafeToken(ex.Message))
            Environment.ExitCode = 1
        Catch ex As Exception
            Console.WriteLine("FAIL ProjectCheckEvaluatorTests test=" & SafeToken(CurrentTest) & " detail=unexpected-" & SafeToken(ex.GetType().Name))
            Environment.ExitCode = 1
        End Try
    End Sub

    Private Sub RunTest(name As String, test As Action)
        CurrentTest = name
        test()
    End Sub

    Private Sub TestCatalog()
        AssertEqual(1, ProjectCheckCatalog.SchemaVersion, "schema-version")
        AssertEqual(3, ProjectCheckCatalog.CheckCount, "catalog-count")
        AssertEqual(64, ProjectCheckCatalog.MaxStableTextLength, "stable-text-bound")

        Dim result = ProjectCheckEvaluator.Evaluate(
            New ProjectCheckSnapshot(
                SourceTargetTextState.Distinct,
                TargetPathCharacterState.Valid,
                MuxerCoverConventionState.NotApplicable))

        Dim expectedIds = {
            "project.source-target-text-distinct",
            "target.path-characters-valid",
            "muxer.cover-convention-valid"
        }
        Dim expectedOrders = {100, 200, 300}
        Dim uniqueIds As New HashSet(Of String)(StringComparer.Ordinal)

        AssertEqual(ProjectCheckCatalog.SchemaVersion, result.SchemaVersion, "result-schema-version")
        AssertEqual(ProjectCheckCatalog.CheckCount, result.Checks.Count, "result-check-count")

        For index = 0 To result.Checks.Count - 1
            Dim check = result.Checks(index)
            AssertEqual(expectedIds(index), check.Id, "stable-id-" & index)
            AssertEqual(expectedOrders(index), check.SortOrder, "stable-order-" & index)
            AssertTrue(uniqueIds.Add(check.Id), "unique-id-" & index)
            AssertTrue(ProjectCheckCatalog.IsStableText(check.Id), "bounded-id-" & index)
            AssertTrue(ProjectCheckCatalog.IsStableText(check.MessageKey), "bounded-message-key-" & index)
        Next

        AssertEqual(ProjectCheckCatalog.SourceTargetTextDistinctId, result.Checks(0).Id, "source-id-constant")
        AssertEqual(ProjectCheckCatalog.TargetPathCharactersValidId, result.Checks(1).Id, "target-id-constant")
        AssertEqual(ProjectCheckCatalog.MuxerCoverConventionValidId, result.Checks(2).Id, "cover-id-constant")
        AssertEqual(ProjectCheckOverallStatus.SelectedChecksPassed, result.OverallStatus, "catalog-pass-status")
    End Sub

    Private Sub TestEvaluatorMatrix()
        Dim sourceStates As SourceTargetTextState() = {
            SourceTargetTextState.Distinct,
            SourceTargetTextState.Identical,
            CType(Integer.MinValue, SourceTargetTextState),
            CType(Integer.MaxValue, SourceTargetTextState)
        }
        Dim targetStates As TargetPathCharacterState() = {
            TargetPathCharacterState.Valid,
            TargetPathCharacterState.Invalid,
            CType(Integer.MinValue, TargetPathCharacterState),
            CType(Integer.MaxValue, TargetPathCharacterState)
        }
        Dim coverStates As MuxerCoverConventionState() = {
            MuxerCoverConventionState.NotApplicable,
            MuxerCoverConventionState.Valid,
            MuxerCoverConventionState.Invalid,
            MuxerCoverConventionState.Unknown,
            CType(Integer.MinValue, MuxerCoverConventionState),
            CType(Integer.MaxValue, MuxerCoverConventionState)
        }

        For Each sourceState In sourceStates
            For Each targetState In targetStates
                For Each coverState In coverStates
                    Dim snapshot = New ProjectCheckSnapshot(sourceState, targetState, coverState)
                    Dim result = ProjectCheckEvaluator.Evaluate(snapshot)

                    AssertEqual(ProjectCheckCatalog.SchemaVersion, snapshot.SchemaVersion, "matrix-snapshot-schema")
                    AssertEqual(ProjectCheckCatalog.CheckCount, result.Checks.Count, "matrix-check-count")
                    AssertSourceCheck(sourceState, result.Checks(0))
                    AssertTargetCheck(targetState, result.Checks(1))
                    AssertCoverCheck(coverState, result.Checks(2))

                    Dim expectedOverall = ExpectedOverallStatus(
                        ExpectedSourceOutcome(sourceState),
                        ExpectedTargetOutcome(targetState),
                        ExpectedCoverOutcome(coverState))
                    AssertEqual(expectedOverall, result.OverallStatus, "matrix-overall")
                Next
            Next
        Next
    End Sub

    Private Sub TestOverallPrecedence()
        AssertOverall(
            ProjectCheckOverallStatus.BlockersFound,
            SourceTargetTextState.Identical,
            TargetPathCharacterState.Invalid,
            MuxerCoverConventionState.Unknown,
            "blocker-over-warning-unknown")
        AssertOverall(
            ProjectCheckOverallStatus.BlockersFound,
            SourceTargetTextState.Distinct,
            TargetPathCharacterState.Invalid,
            MuxerCoverConventionState.Invalid,
            "cover-blocker-over-warning")
        AssertOverall(
            ProjectCheckOverallStatus.WarningsFound,
            SourceTargetTextState.Distinct,
            TargetPathCharacterState.Invalid,
            MuxerCoverConventionState.Unknown,
            "warning-over-unknown")
        AssertOverall(
            ProjectCheckOverallStatus.ChecksIncomplete,
            CType(-1, SourceTargetTextState),
            TargetPathCharacterState.Valid,
            MuxerCoverConventionState.NotApplicable,
            "unknown-over-pass")
        AssertOverall(
            ProjectCheckOverallStatus.SelectedChecksPassed,
            SourceTargetTextState.Distinct,
            TargetPathCharacterState.Valid,
            MuxerCoverConventionState.NotApplicable,
            "not-applicable-does-not-raise")
        AssertOverall(
            ProjectCheckOverallStatus.SelectedChecksPassed,
            SourceTargetTextState.Distinct,
            TargetPathCharacterState.Valid,
            MuxerCoverConventionState.Valid,
            "all-applicable-facts-pass")
    End Sub

    Private Sub TestImmutabilityAndDeterminism()
        AssertReadOnlyProperties(GetType(ProjectCheckSnapshot), "snapshot")
        AssertReadOnlyProperties(GetType(ProjectCheck), "check")
        AssertReadOnlyProperties(GetType(ProjectCheckResult), "result")
        AssertReadOnlyProperties(GetType(ProjectCheckActivationContext), "activation-context")
        AssertReadOnlyProperties(GetType(ProjectCheckRefreshContext), "refresh-context")

        Dim snapshot = New ProjectCheckSnapshot(
            SourceTargetTextState.Identical,
            TargetPathCharacterState.Invalid,
            MuxerCoverConventionState.Unknown)
        Dim sourceBefore = snapshot.SourceTargetText
        Dim targetBefore = snapshot.TargetPathCharacters
        Dim coverBefore = snapshot.MuxerCoverConvention
        Dim result = ProjectCheckEvaluator.Evaluate(snapshot)

        AssertEqual(sourceBefore, snapshot.SourceTargetText, "snapshot-source-unchanged")
        AssertEqual(targetBefore, snapshot.TargetPathCharacters, "snapshot-target-unchanged")
        AssertEqual(coverBefore, snapshot.MuxerCoverConvention, "snapshot-cover-unchanged")

        Dim checksList = DirectCast(result.Checks, IList(Of ProjectCheck))
        AssertThrows(Of NotSupportedException)(Sub() checksList.Add(result.Checks(0)), "read-only-check-list")

        Dim constructorInput = {result.Checks(0), result.Checks(1), result.Checks(2)}
        Dim copiedResult = New ProjectCheckResult(constructorInput)
        constructorInput(0) = Nothing
        AssertTrue(copiedResult.Checks(0) IsNot Nothing, "result-defensive-copy")

        Dim expectedSignature = ResultSignature(result)

        For repeat = 1 To 100
            Dim repeatedResult = ProjectCheckEvaluator.Evaluate(snapshot)
            AssertEqual(expectedSignature, ResultSignature(repeatedResult), "repeat-signature-" & repeat)
            AssertTrue(Not Object.ReferenceEquals(result, repeatedResult), "repeat-result-instance-" & repeat)
        Next

        Dim reorderedCopy As New List(Of ProjectCheck)(result.Checks)
        reorderedCopy.Reverse()
        AssertEqual(ProjectCheckCatalog.SourceTargetTextDistinctOrder, result.Checks(0).SortOrder, "render-copy-does-not-reorder-result")
        AssertEqual(ProjectCheckCatalog.MuxerCoverConventionValidOrder, reorderedCopy(0).SortOrder, "render-copy-reordered")
    End Sub

    Private Sub TestCultureAndPrivacy()
        Dim snapshot = New ProjectCheckSnapshot(
            SourceTargetTextState.Distinct,
            TargetPathCharacterState.Valid,
            MuxerCoverConventionState.Valid)
        Dim expectedSignature = ResultSignature(ProjectCheckEvaluator.Evaluate(snapshot))
        Dim originalCulture = Thread.CurrentThread.CurrentCulture
        Dim originalUiCulture = Thread.CurrentThread.CurrentUICulture
        Dim cultures = {"en-US", "tr-TR", "de-DE"}

        Try
            For Each cultureName In cultures
                Dim culture = CultureInfo.GetCultureInfo(cultureName)
                Thread.CurrentThread.CurrentCulture = culture
                Thread.CurrentThread.CurrentUICulture = culture
                AssertEqual(expectedSignature, ResultSignature(ProjectCheckEvaluator.Evaluate(snapshot)), "culture-" & cultureName)
            Next
        Finally
            Thread.CurrentThread.CurrentCulture = originalCulture
            Thread.CurrentThread.CurrentUICulture = originalUiCulture
        End Try

        For Each propertyInfo In GetType(ProjectCheckSnapshot).GetProperties(BindingFlags.Instance Or BindingFlags.Public)
            AssertTrue(propertyInfo.PropertyType IsNot GetType(String), "snapshot-has-no-string-" & propertyInfo.Name)
        Next

        AssertTrue(GetType(ProjectCheck).GetProperty("Arguments") Is Nothing, "no-arguments-property")
        AssertTrue(GetType(ProjectCheck).GetProperty("MessageArguments") Is Nothing, "no-message-arguments-property")
        AssertTrue(GetType(ProjectCheckSnapshot).Assembly.GetType("StaxRip.Project", False) Is Nothing, "no-legacy-project-type")

        Dim stableResultText = CollectStableResultText()
        Dim sentinels = {
            "C:\private\source.mkv",
            "private-media-title",
            "private-script()",
            "--private-command",
            "private-setting",
            "private-external-output",
            "private-exception-text"
        }

        For index = 0 To sentinels.Length - 1
            AssertTrue(stableResultText.IndexOf(sentinels(index), StringComparison.Ordinal) < 0, "privacy-sentinel-" & index)
        Next
    End Sub

    Private Sub TestActivationPolicyExhaustive()
        Dim sourceDepths = {-1, 0, 1, 2}
        Dim mutationDepths = {-1, 0, 1, 2}
        Const AcceptedMask As Integer = 261
        Dim acceptedCount As Integer

        For Each sourceDepth In sourceDepths
            For Each mutationDepth In mutationDepths
                For mask = 0 To 511
                    Dim context = New ProjectCheckActivationContext(
                        IsBitSet(mask, 0),
                        sourceDepth,
                        mutationDepth,
                        IsBitSet(mask, 1),
                        IsBitSet(mask, 2),
                        IsBitSet(mask, 3),
                        IsBitSet(mask, 4),
                        IsBitSet(mask, 5),
                        IsBitSet(mask, 6),
                        IsBitSet(mask, 7),
                        IsBitSet(mask, 8))
                    Dim expected = sourceDepth = 0 AndAlso mutationDepth = 0 AndAlso mask = AcceptedMask
                    Dim actual = ProjectCheckActivationPolicy.ShouldEvaluate(context)

                    ActivationVectorCount += 1
                    AssertEqual(
                        expected,
                        actual,
                        "activation-source-depth-" & sourceDepth & "-mutation-depth-" & mutationDepth & "-mask-" & mask)

                    If actual Then
                        acceptedCount += 1
                    End If
                Next
            Next
        Next

        AssertEqual(8192, ActivationVectorCount, "activation-vector-count")
        AssertEqual(1, acceptedCount, "activation-accepted-count")
    End Sub

    Private Sub TestRefreshPolicyExhaustive()
        Dim kinds As ProjectCheckPresentationKind() = {
            ProjectCheckPresentationKind.Hidden,
            ProjectCheckPresentationKind.Available,
            ProjectCheckPresentationKind.RefreshRequired,
            ProjectCheckPresentationKind.Unavailable,
            CType(-1, ProjectCheckPresentationKind)
        }
        Dim depths = {-1, 0, 1, 2}
        Const AcceptedMask As Integer = 1
        Dim acceptedCount As Integer

        For Each kind In kinds
            For Each sourceDepth In depths
                For Each mutationDepth In depths
                    For mask = 0 To 15
                        Dim context = New ProjectCheckRefreshContext(
                            kind,
                            sourceDepth,
                            mutationDepth,
                            IsBitSet(mask, 0),
                            IsBitSet(mask, 1),
                            IsBitSet(mask, 2),
                            IsBitSet(mask, 3))
                        Dim permittedKind = kind = ProjectCheckPresentationKind.Available OrElse
                            kind = ProjectCheckPresentationKind.RefreshRequired OrElse
                            kind = ProjectCheckPresentationKind.Unavailable
                        Dim expected = permittedKind AndAlso
                            sourceDepth = 0 AndAlso
                            mutationDepth = 0 AndAlso
                            mask = AcceptedMask
                        Dim actual = ProjectCheckRefreshPolicy.ShouldEvaluate(context)

                        RefreshVectorCount += 1
                        AssertEqual(
                            expected,
                            actual,
                            "refresh-kind-" & CInt(kind) & "-source-depth-" & sourceDepth &
                                "-mutation-depth-" & mutationDepth & "-mask-" & mask)

                        If actual Then
                            acceptedCount += 1
                        End If
                    Next
                Next
            Next
        Next

        AssertEqual(1280, RefreshVectorCount, "refresh-vector-count")
        AssertEqual(3, acceptedCount, "refresh-accepted-count")
    End Sub

    Private Sub TestModelBoundaries()
        AssertThrows(Of ArgumentNullException)(
            Sub()
                Dim ignored = ProjectCheckEvaluator.Evaluate(Nothing)
            End Sub,
            "null-snapshot")

        Dim validResult = ProjectCheckEvaluator.Evaluate(
            New ProjectCheckSnapshot(
                SourceTargetTextState.Distinct,
                TargetPathCharacterState.Valid,
                MuxerCoverConventionState.NotApplicable))

        AssertThrows(Of ArgumentNullException)(
            Sub()
                Dim ignored = New ProjectCheckResult(Nothing)
            End Sub,
            "null-check-collection")
        AssertThrows(Of ArgumentException)(
            Sub()
                Dim ignored = New ProjectCheckResult({validResult.Checks(0), validResult.Checks(1)})
            End Sub,
            "short-check-collection")
        AssertThrows(Of ArgumentException)(
            Sub()
                Dim ignored = New ProjectCheckResult({validResult.Checks(0), Nothing, validResult.Checks(2)})
            End Sub,
            "empty-check-entry")
        AssertThrows(Of ArgumentException)(
            Sub()
                Dim ignored = New ProjectCheck(
                    New String("a"c, ProjectCheckCatalog.MaxStableTextLength + 1),
                    ProjectCheckCategory.Project,
                    ProjectCheckOutcome.Fact,
                    ProjectCheckSeverity.Information,
                    "project.valid.fact",
                    1)
            End Sub,
            "oversized-id")
        AssertThrows(Of ArgumentException)(
            Sub()
                Dim ignored = New ProjectCheck(
                    "Project.invalid-uppercase",
                    ProjectCheckCategory.Project,
                    ProjectCheckOutcome.Fact,
                    ProjectCheckSeverity.Information,
                    "project.valid.fact",
                    1)
            End Sub,
            "invalid-id-character")
        AssertThrows(Of ArgumentException)(
            Sub()
                Dim ignored = New ProjectCheck(
                    "project.valid",
                    ProjectCheckCategory.Project,
                    ProjectCheckOutcome.Fact,
                    ProjectCheckSeverity.Information,
                    New String("m"c, ProjectCheckCatalog.MaxStableTextLength + 1),
                    1)
            End Sub,
            "oversized-message-key")
        AssertThrows(Of ArgumentOutOfRangeException)(
            Sub()
                Dim ignored = New ProjectCheck(
                    "project.valid",
                    ProjectCheckCategory.Project,
                    ProjectCheckOutcome.Fact,
                    ProjectCheckSeverity.Information,
                    "project.valid.fact",
                    -1)
            End Sub,
            "negative-sort-order")

        AssertThrows(Of ArgumentException)(
            Sub()
                Dim ignored = New ProjectCheck(
                    "project.private-media-title",
                    ProjectCheckCategory.Project,
                    ProjectCheckOutcome.Fact,
                    ProjectCheckSeverity.Information,
                    "project.private-media-title.fact",
                    1)
            End Sub,
            "unapproved-stable-row")
        AssertThrows(Of ArgumentException)(
            Sub()
                Dim ignored = New ProjectCheck(
                    ProjectCheckCatalog.SourceTargetTextDistinctId,
                    CType(99, ProjectCheckCategory),
                    ProjectCheckOutcome.Fact,
                    ProjectCheckSeverity.Information,
                    ProjectCheckCatalog.SourceTargetTextDistinctFactMessageKey,
                    ProjectCheckCatalog.SourceTargetTextDistinctOrder)
            End Sub,
            "undefined-category")
        AssertThrows(Of ArgumentException)(
            Sub()
                Dim ignored = New ProjectCheck(
                    ProjectCheckCatalog.SourceTargetTextDistinctId,
                    ProjectCheckCategory.Project,
                    CType(99, ProjectCheckOutcome),
                    ProjectCheckSeverity.Information,
                    ProjectCheckCatalog.SourceTargetTextDistinctFactMessageKey,
                    ProjectCheckCatalog.SourceTargetTextDistinctOrder)
            End Sub,
            "undefined-outcome")
        AssertThrows(Of ArgumentException)(
            Sub()
                Dim ignored = New ProjectCheck(
                    ProjectCheckCatalog.SourceTargetTextDistinctId,
                    ProjectCheckCategory.Project,
                    ProjectCheckOutcome.Fact,
                    CType(99, ProjectCheckSeverity),
                    ProjectCheckCatalog.SourceTargetTextDistinctFactMessageKey,
                    ProjectCheckCatalog.SourceTargetTextDistinctOrder)
            End Sub,
            "undefined-severity")
        AssertThrows(Of ArgumentException)(
            Sub()
                Dim ignored = New ProjectCheck(
                    ProjectCheckCatalog.SourceTargetTextDistinctId,
                    ProjectCheckCategory.Project,
                    ProjectCheckOutcome.Fact,
                    ProjectCheckSeverity.Information,
                    ProjectCheckCatalog.TargetPathCharactersValidFactMessageKey,
                    ProjectCheckCatalog.SourceTargetTextDistinctOrder)
            End Sub,
            "mismatched-message-key")
        AssertThrows(Of ArgumentException)(
            Sub()
                Dim ignored = New ProjectCheckResult(
                    {validResult.Checks(0), validResult.Checks(0), validResult.Checks(0)})
            End Sub,
            "duplicate-result-rows")
        AssertThrows(Of ArgumentException)(
            Sub()
                Dim ignored = New ProjectCheckResult(
                    {validResult.Checks(2), validResult.Checks(1), validResult.Checks(0)})
            End Sub,
            "reordered-result-rows")
    End Sub

    Private Sub TestCoordinator()
        Dim mapperCount As Integer
        Dim evaluatorCount As Integer
        Dim syntheticProjectFingerprint = 7301
        Dim snapshot = New ProjectCheckSnapshot(
            SourceTargetTextState.Distinct,
            TargetPathCharacterState.Valid,
            MuxerCoverConventionState.NotApplicable)
        Dim expectedResult = ProjectCheckEvaluator.Evaluate(snapshot)
        Dim coordinator = New ProjectCheckCoordinator(
            Function()
                mapperCount += 1
                Return snapshot
            End Function,
            Function(value)
                evaluatorCount += 1
                Return ProjectCheckEvaluator.Evaluate(value)
            End Function)

        AssertEqual(ProjectCheckPresentationKind.Hidden, coordinator.CurrentState.Kind, "coordinator-initial-hidden")
        AssertTrue(coordinator.CurrentState.Result Is Nothing, "coordinator-initial-no-result")
        AssertEqual(ProjectCheckPresentationKind.Hidden, coordinator.EvaluateInitial(0).Kind, "coordinator-fresh-initial-rejected")
        AssertEqual(0, mapperCount, "coordinator-fresh-initial-skips-mapper")
        AssertEqual(0, evaluatorCount, "coordinator-fresh-initial-skips-evaluator")

        Dim initialGeneration = CreateInitialToken(coordinator)
        Dim available = coordinator.EvaluateInitial(initialGeneration)
        AssertEqual(ProjectCheckPresentationKind.Available, available.Kind, "coordinator-available")
        AssertEqual(ResultSignature(expectedResult), ResultSignature(available.Result), "coordinator-result")
        AssertEqual(1, mapperCount, "coordinator-mapper-count")
        AssertEqual(1, evaluatorCount, "coordinator-evaluator-count")
        AssertEqual(7301, syntheticProjectFingerprint, "coordinator-project-unchanged")

        Dim refreshRequired = coordinator.Invalidate()
        AssertEqual(ProjectCheckPresentationKind.RefreshRequired, refreshRequired.Kind, "coordinator-refresh-required")
        AssertTrue(refreshRequired.Result Is Nothing, "coordinator-invalidated-no-stale-result")

        available = coordinator.Refresh()
        AssertEqual(ProjectCheckPresentationKind.Available, available.Kind, "coordinator-refresh-available")
        AssertEqual(2, mapperCount, "coordinator-refresh-mapper-count")
        AssertEqual(2, evaluatorCount, "coordinator-refresh-evaluator-count")

        Dim mutationState = coordinator.BeginInvalidatingMutation()
        AssertEqual(ProjectCheckPresentationKind.RefreshRequired, mutationState.Kind, "coordinator-mutation-begin-refresh-required")
        AssertEqual(1, coordinator.ActiveMutationCount, "coordinator-mutation-depth-one")
        AssertEqual(
            ProjectCheckPresentationKind.RefreshRequired,
            coordinator.Refresh().Kind,
            "coordinator-active-mutation-rejects-evaluation")
        AssertEqual(2, mapperCount, "coordinator-active-mutation-skips-mapper")
        AssertEqual(2, evaluatorCount, "coordinator-active-mutation-skips-evaluator")

        coordinator.BeginInvalidatingMutation()
        AssertEqual(2, coordinator.ActiveMutationCount, "coordinator-nested-mutation-depth-two")
        coordinator.EndInvalidatingMutation()
        AssertEqual(1, coordinator.ActiveMutationCount, "coordinator-nested-mutation-depth-one")
        coordinator.EndInvalidatingMutation()
        AssertEqual(0, coordinator.ActiveMutationCount, "coordinator-mutation-depth-zero")
        AssertEqual(ProjectCheckPresentationKind.RefreshRequired, coordinator.CurrentState.Kind, "coordinator-post-mutation-refresh-required")

        available = coordinator.Refresh()
        AssertEqual(ProjectCheckPresentationKind.Available, available.Kind, "coordinator-post-mutation-available")
        AssertEqual(3, mapperCount, "coordinator-post-mutation-mapper-count")
        AssertEqual(3, evaluatorCount, "coordinator-post-mutation-evaluator-count")
        AssertThrows(Of InvalidOperationException)(
            Sub()
                coordinator.EndInvalidatingMutation()
            End Sub,
            "coordinator-unbalanced-mutation-end")
        coordinator.BeginInvalidatingMutation()
        AssertThrows(Of InvalidOperationException)(
            Sub()
                coordinator.EndClearingMutation()
            End Sub,
            "coordinator-mismatched-mutation-end")
        AssertEqual(1, coordinator.ActiveMutationCount, "coordinator-mismatched-end-keeps-scope-active")
        coordinator.EndInvalidatingMutation()
        AssertEqual(0, coordinator.ActiveMutationCount, "coordinator-mismatched-end-recovery")

        Dim hidden = coordinator.Clear()
        AssertEqual(ProjectCheckPresentationKind.Hidden, hidden.Kind, "coordinator-clear-hidden")
        AssertTrue(hidden.Result Is Nothing, "coordinator-clear-no-result")
        AssertEqual(ProjectCheckPresentationKind.Hidden, coordinator.Refresh().Kind, "coordinator-hidden-refresh-rejected")
        AssertEqual(ProjectCheckPresentationKind.Hidden, coordinator.EvaluateInitial(0).Kind, "coordinator-stale-initial-token-rejected")
        AssertEqual(3, mapperCount, "coordinator-rejected-evaluation-skips-mapper")
        AssertEqual(3, evaluatorCount, "coordinator-rejected-evaluation-skips-evaluator")

        Dim initialTokenCoordinator = New ProjectCheckCoordinator(
            Function() snapshot,
            AddressOf ProjectCheckEvaluator.Evaluate)
        initialTokenCoordinator.BeginClearingMutation()
        Dim firstCompletionToken = initialTokenCoordinator.EndClearingMutation()
        initialTokenCoordinator.BeginClearingMutation()
        Dim currentCompletionToken = initialTokenCoordinator.EndClearingMutation()
        AssertEqual(
            ProjectCheckPresentationKind.Hidden,
            initialTokenCoordinator.EvaluateInitial(firstCompletionToken).Kind,
            "coordinator-superseded-completion-token-rejected")
        AssertEqual(
            ProjectCheckPresentationKind.Available,
            initialTokenCoordinator.EvaluateInitial(currentCompletionToken).Kind,
            "coordinator-current-completion-token-accepted")

        Dim revokedTokenMapperCount As Integer
        Dim revokedTokenCoordinator = New ProjectCheckCoordinator(
            Function()
                revokedTokenMapperCount += 1
                Return snapshot
            End Function,
            AddressOf ProjectCheckEvaluator.Evaluate)
        Dim revokedToken = CreateInitialToken(revokedTokenCoordinator)
        revokedTokenCoordinator.BeginInvalidatingMutation()
        revokedTokenCoordinator.EndInvalidatingMutation()
        AssertEqual(
            ProjectCheckPresentationKind.Hidden,
            revokedTokenCoordinator.EvaluateInitial(revokedToken).Kind,
            "coordinator-invalidating-mutation-revokes-initial-token")
        AssertEqual(0, revokedTokenMapperCount, "coordinator-revoked-token-skips-mapper")

        Dim mapperFaultCount As Integer
        Dim mapperFaultCoordinator = New ProjectCheckCoordinator(
            Function()
                mapperFaultCount += 1
                Throw New InvalidOperationException("private-mapper-exception")
            End Function,
            Function(value)
                Throw New InvalidOperationException("evaluator-must-not-run")
            End Function)
        Dim unavailable = mapperFaultCoordinator.EvaluateInitial(CreateInitialToken(mapperFaultCoordinator))
        AssertEqual(ProjectCheckPresentationKind.Unavailable, unavailable.Kind, "coordinator-mapper-unavailable")
        AssertTrue(unavailable.Result Is Nothing, "coordinator-mapper-no-result")
        AssertEqual(1, mapperFaultCount, "coordinator-mapper-fault-count")

        Dim evaluatorFaultCount As Integer
        Dim evaluatorFaultCoordinator = New ProjectCheckCoordinator(
            Function()
                Return snapshot
            End Function,
            Function(value)
                evaluatorFaultCount += 1
                Throw New InvalidOperationException("private-evaluator-exception")
            End Function)
        unavailable = evaluatorFaultCoordinator.EvaluateInitial(CreateInitialToken(evaluatorFaultCoordinator))
        AssertEqual(ProjectCheckPresentationKind.Unavailable, unavailable.Kind, "coordinator-evaluator-unavailable")
        AssertTrue(unavailable.Result Is Nothing, "coordinator-evaluator-no-result")
        AssertEqual(1, evaluatorFaultCount, "coordinator-evaluator-fault-count")
        AssertEqual(
            ProjectCheckPresentationKind.RefreshRequired,
            evaluatorFaultCoordinator.Invalidate().Kind,
            "coordinator-unavailable-invalidation")

        Dim nullSnapshotCoordinator = New ProjectCheckCoordinator(
            Function() DirectCast(Nothing, ProjectCheckSnapshot),
            AddressOf ProjectCheckEvaluator.Evaluate)
        AssertEqual(
            ProjectCheckPresentationKind.Unavailable,
            nullSnapshotCoordinator.EvaluateInitial(CreateInitialToken(nullSnapshotCoordinator)).Kind,
            "coordinator-null-snapshot")

        Dim nullResultCoordinator = New ProjectCheckCoordinator(
            Function() snapshot,
            Function(value) DirectCast(Nothing, ProjectCheckResult))
        AssertEqual(
            ProjectCheckPresentationKind.Unavailable,
            nullResultCoordinator.EvaluateInitial(CreateInitialToken(nullResultCoordinator)).Kind,
            "coordinator-null-result")

        Dim invalidateDuringEvaluation As Boolean
        Dim generationCoordinator As ProjectCheckCoordinator = Nothing
        generationCoordinator = New ProjectCheckCoordinator(
            Function() snapshot,
            Function(value)
                If invalidateDuringEvaluation Then
                    generationCoordinator.Invalidate()
                End If

                Return ProjectCheckEvaluator.Evaluate(value)
            End Function)
        AssertEqual(
            ProjectCheckPresentationKind.Available,
            generationCoordinator.EvaluateInitial(CreateInitialToken(generationCoordinator)).Kind,
            "coordinator-generation-initial")
        invalidateDuringEvaluation = True
        AssertEqual(
            ProjectCheckPresentationKind.RefreshRequired,
            generationCoordinator.Refresh().Kind,
            "coordinator-generation-discards-stale-publication")

        Dim mutationDuringEvaluation As Boolean
        Dim mutationGenerationCoordinator As ProjectCheckCoordinator = Nothing
        mutationGenerationCoordinator = New ProjectCheckCoordinator(
            Function() snapshot,
            Function(value)
                If mutationDuringEvaluation Then
                    mutationGenerationCoordinator.BeginInvalidatingMutation()
                End If

                Return ProjectCheckEvaluator.Evaluate(value)
            End Function)
        AssertEqual(
            ProjectCheckPresentationKind.Available,
            mutationGenerationCoordinator.EvaluateInitial(CreateInitialToken(mutationGenerationCoordinator)).Kind,
            "coordinator-mutation-generation-initial")
        mutationDuringEvaluation = True
        AssertEqual(
            ProjectCheckPresentationKind.RefreshRequired,
            mutationGenerationCoordinator.Refresh().Kind,
            "coordinator-mutation-start-discards-inflight-publication")
        AssertEqual(1, mutationGenerationCoordinator.ActiveMutationCount, "coordinator-inflight-mutation-active")
        mutationGenerationCoordinator.EndInvalidatingMutation()
        AssertEqual(0, mutationGenerationCoordinator.ActiveMutationCount, "coordinator-inflight-mutation-balanced")

        Dim completeCycleDuringRefresh As Boolean
        Dim completeCycleCoordinator As ProjectCheckCoordinator = Nothing
        completeCycleCoordinator = New ProjectCheckCoordinator(
            Function() snapshot,
            Function(value)
                If completeCycleDuringRefresh Then
                    completeCycleCoordinator.BeginInvalidatingMutation()
                    completeCycleCoordinator.EndInvalidatingMutation()
                End If

                Return ProjectCheckEvaluator.Evaluate(value)
            End Function)
        AssertEqual(
            ProjectCheckPresentationKind.Available,
            completeCycleCoordinator.EvaluateInitial(CreateInitialToken(completeCycleCoordinator)).Kind,
            "coordinator-complete-cycle-initial")
        completeCycleDuringRefresh = True
        AssertEqual(
            ProjectCheckPresentationKind.RefreshRequired,
            completeCycleCoordinator.Refresh().Kind,
            "coordinator-complete-cycle-discards-inflight-refresh")
        AssertEqual(0, completeCycleCoordinator.ActiveMutationCount, "coordinator-complete-cycle-balanced")

        AssertThrows(Of ArgumentNullException)(
            Sub()
                Dim ignored = New ProjectCheckCoordinator(Nothing, AddressOf ProjectCheckEvaluator.Evaluate)
            End Sub,
            "coordinator-null-mapper")
        AssertThrows(Of ArgumentNullException)(
            Sub()
                Dim ignored = New ProjectCheckCoordinator(Function() snapshot, Nothing)
            End Sub,
            "coordinator-null-evaluator")

        AssertReadOnlyProperties(GetType(ProjectCheckPresentationState), "presentation-state")
        For Each propertyInfo In GetType(ProjectCheckPresentationState).GetProperties(BindingFlags.Instance Or BindingFlags.Public)
            AssertTrue(propertyInfo.PropertyType IsNot GetType(String), "presentation-has-no-string-" & propertyInfo.Name)
            AssertTrue(Not GetType(Exception).IsAssignableFrom(propertyInfo.PropertyType), "presentation-has-no-exception-" & propertyInfo.Name)
        Next

        AssertTrue(
            CollectPresentationText(mapperFaultCoordinator.CurrentState).
                IndexOf("private-mapper-exception", StringComparison.Ordinal) < 0,
            "coordinator-mapper-exception-private")
        AssertTrue(
            CollectPresentationText(evaluatorFaultCoordinator.CurrentState).
                IndexOf("private-evaluator-exception", StringComparison.Ordinal) < 0,
            "coordinator-evaluator-exception-private")
    End Sub

    Private Function CreateInitialToken(coordinator As ProjectCheckCoordinator) As Long
        coordinator.BeginClearingMutation()
        Return coordinator.EndClearingMutation()
    End Function

    Private Sub TestPresentationText()
        AssertEqual(
            "Add Job and encode-time checks still run later. This result does not authorize encoding.",
            ProjectCheckPresentationText.LaterChecksCaveat,
            "presentation-caveat")
        AssertEqual(
            "These results do not authorize encoding. Add Job and encode-time checks still run later.",
            ProjectCheckPresentationText.DetailsNotice,
            "presentation-details-notice")
        AssertEqual(String.Empty, ProjectCheckPresentationText.SummaryFor(ProjectCheckPresentationState.Hidden()), "presentation-hidden")
        AssertEqual(
            "Project checks unavailable. " + ProjectCheckPresentationText.LaterChecksCaveat,
            ProjectCheckPresentationText.SummaryFor(ProjectCheckPresentationState.Unavailable()),
            "presentation-unavailable")
        AssertEqual(
            "Project checks require refresh. " + ProjectCheckPresentationText.LaterChecksCaveat,
            ProjectCheckPresentationText.SummaryFor(ProjectCheckPresentationState.RefreshRequired()),
            "presentation-refresh-required")

        Dim presentations = New Dictionary(Of ProjectCheckSnapshot, String) From {
            {
                New ProjectCheckSnapshot(
                    SourceTargetTextState.Distinct,
                    TargetPathCharacterState.Valid,
                    MuxerCoverConventionState.NotApplicable),
                "Selected checks passed. Fact 2; Warning 0; Blocker 0; Unknown 0; N/A 1. " + ProjectCheckPresentationText.LaterChecksCaveat
            },
            {
                New ProjectCheckSnapshot(
                    SourceTargetTextState.Identical,
                    TargetPathCharacterState.Invalid,
                    MuxerCoverConventionState.Unknown),
                "Blockers found. Fact 0; Warning 1; Blocker 1; Unknown 1; N/A 0. " + ProjectCheckPresentationText.LaterChecksCaveat
            },
            {
                New ProjectCheckSnapshot(
                    SourceTargetTextState.Distinct,
                    TargetPathCharacterState.Invalid,
                    MuxerCoverConventionState.Valid),
                "Warnings found. Fact 2; Warning 1; Blocker 0; Unknown 0; N/A 0. " + ProjectCheckPresentationText.LaterChecksCaveat
            },
            {
                New ProjectCheckSnapshot(
                    CType(-1, SourceTargetTextState),
                    TargetPathCharacterState.Valid,
                    MuxerCoverConventionState.NotApplicable),
                "Checks incomplete. Fact 1; Warning 0; Blocker 0; Unknown 1; N/A 1. " + ProjectCheckPresentationText.LaterChecksCaveat
            }
        }

        For Each pair In presentations
            Dim result = ProjectCheckEvaluator.Evaluate(pair.Key)
            Dim state = ProjectCheckPresentationState.Available(result)
            AssertEqual(pair.Value, ProjectCheckPresentationText.SummaryFor(state), "presentation-summary-" & CInt(result.OverallStatus))

            For Each check In result.Checks
                AssertTrue(Not String.IsNullOrWhiteSpace(ProjectCheckPresentationText.StatusFor(check.Outcome)), "presentation-status")
                AssertTrue(Not String.IsNullOrWhiteSpace(ProjectCheckPresentationText.CheckNameFor(check.Id)), "presentation-check-name")
                AssertTrue(Not String.IsNullOrWhiteSpace(ProjectCheckPresentationText.ExplanationFor(check.MessageKey)), "presentation-explanation")
            Next
        Next

        Dim allSnapshots = {
            New ProjectCheckSnapshot(SourceTargetTextState.Distinct, TargetPathCharacterState.Valid, MuxerCoverConventionState.NotApplicable),
            New ProjectCheckSnapshot(SourceTargetTextState.Identical, TargetPathCharacterState.Invalid, MuxerCoverConventionState.Valid),
            New ProjectCheckSnapshot(CType(-1, SourceTargetTextState), CType(-1, TargetPathCharacterState), MuxerCoverConventionState.Invalid),
            New ProjectCheckSnapshot(SourceTargetTextState.Distinct, TargetPathCharacterState.Valid, MuxerCoverConventionState.Unknown)
        }
        Dim presentedMessageKeys As New HashSet(Of String)(StringComparer.Ordinal)

        For Each snapshot In allSnapshots
            For Each check In ProjectCheckEvaluator.Evaluate(snapshot).Checks
                presentedMessageKeys.Add(check.MessageKey)
                ProjectCheckPresentationText.ExplanationFor(check.MessageKey)
            Next
        Next

        AssertEqual(10, presentedMessageKeys.Count, "presentation-all-message-keys")
        AssertThrows(Of ArgumentNullException)(
            Sub() ProjectCheckPresentationText.SummaryFor(Nothing),
            "presentation-null-state")
        AssertThrows(Of ArgumentOutOfRangeException)(
            Sub() ProjectCheckPresentationText.StatusFor(CType(-1, ProjectCheckOutcome)),
            "presentation-invalid-outcome")
        AssertThrows(Of ArgumentException)(
            Sub() ProjectCheckPresentationText.CheckNameFor("project.private"),
            "presentation-unapproved-id")
        AssertThrows(Of ArgumentException)(
            Sub() ProjectCheckPresentationText.ExplanationFor("project.private.message"),
            "presentation-unapproved-message")
    End Sub

    Private Sub AssertSourceCheck(state As SourceTargetTextState, check As ProjectCheck)
        AssertEqual(ProjectCheckCatalog.SourceTargetTextDistinctId, check.Id, "source-id")
        AssertEqual(ProjectCheckCategory.Project, check.Category, "source-category")
        AssertEqual(ProjectCheckCatalog.SourceTargetTextDistinctOrder, check.SortOrder, "source-order")
        AssertEqual(ExpectedSourceOutcome(state), check.Outcome, "source-outcome")
        AssertEqual(ExpectedSourceSeverity(state), check.Severity, "source-severity")
        AssertEqual(ExpectedSourceMessageKey(state), check.MessageKey, "source-message-key")
        AssertTrue(ProjectCheckCatalog.IsStableText(check.MessageKey), "source-message-key-bound")
    End Sub

    Private Sub AssertTargetCheck(state As TargetPathCharacterState, check As ProjectCheck)
        AssertEqual(ProjectCheckCatalog.TargetPathCharactersValidId, check.Id, "target-id")
        AssertEqual(ProjectCheckCategory.Target, check.Category, "target-category")
        AssertEqual(ProjectCheckCatalog.TargetPathCharactersValidOrder, check.SortOrder, "target-order")
        AssertEqual(ExpectedTargetOutcome(state), check.Outcome, "target-outcome")
        AssertEqual(ExpectedTargetSeverity(state), check.Severity, "target-severity")
        AssertEqual(ExpectedTargetMessageKey(state), check.MessageKey, "target-message-key")
        AssertTrue(ProjectCheckCatalog.IsStableText(check.MessageKey), "target-message-key-bound")
    End Sub

    Private Sub AssertCoverCheck(state As MuxerCoverConventionState, check As ProjectCheck)
        AssertEqual(ProjectCheckCatalog.MuxerCoverConventionValidId, check.Id, "cover-id")
        AssertEqual(ProjectCheckCategory.Muxer, check.Category, "cover-category")
        AssertEqual(ProjectCheckCatalog.MuxerCoverConventionValidOrder, check.SortOrder, "cover-order")
        AssertEqual(ExpectedCoverOutcome(state), check.Outcome, "cover-outcome")
        AssertEqual(ExpectedCoverSeverity(state), check.Severity, "cover-severity")
        AssertEqual(ExpectedCoverMessageKey(state), check.MessageKey, "cover-message-key")
        AssertTrue(ProjectCheckCatalog.IsStableText(check.MessageKey), "cover-message-key-bound")
    End Sub

    Private Function ExpectedSourceOutcome(state As SourceTargetTextState) As ProjectCheckOutcome
        Select Case state
            Case SourceTargetTextState.Distinct
                Return ProjectCheckOutcome.Fact
            Case SourceTargetTextState.Identical
                Return ProjectCheckOutcome.Blocker
            Case Else
                Return ProjectCheckOutcome.Unknown
        End Select
    End Function

    Private Function ExpectedSourceSeverity(state As SourceTargetTextState) As ProjectCheckSeverity
        Select Case state
            Case SourceTargetTextState.Distinct
                Return ProjectCheckSeverity.Information
            Case SourceTargetTextState.Identical
                Return ProjectCheckSeverity.Blocker
            Case Else
                Return ProjectCheckSeverity.Unknown
        End Select
    End Function

    Private Function ExpectedSourceMessageKey(state As SourceTargetTextState) As String
        Select Case state
            Case SourceTargetTextState.Distinct
                Return ProjectCheckCatalog.SourceTargetTextDistinctFactMessageKey
            Case SourceTargetTextState.Identical
                Return ProjectCheckCatalog.SourceTargetTextDistinctBlockerMessageKey
            Case Else
                Return ProjectCheckCatalog.SourceTargetTextDistinctUnknownMessageKey
        End Select
    End Function

    Private Function ExpectedTargetOutcome(state As TargetPathCharacterState) As ProjectCheckOutcome
        Select Case state
            Case TargetPathCharacterState.Valid
                Return ProjectCheckOutcome.Fact
            Case TargetPathCharacterState.Invalid
                Return ProjectCheckOutcome.Warning
            Case Else
                Return ProjectCheckOutcome.Unknown
        End Select
    End Function

    Private Function ExpectedTargetSeverity(state As TargetPathCharacterState) As ProjectCheckSeverity
        Select Case state
            Case TargetPathCharacterState.Valid
                Return ProjectCheckSeverity.Information
            Case TargetPathCharacterState.Invalid
                Return ProjectCheckSeverity.Warning
            Case Else
                Return ProjectCheckSeverity.Unknown
        End Select
    End Function

    Private Function ExpectedTargetMessageKey(state As TargetPathCharacterState) As String
        Select Case state
            Case TargetPathCharacterState.Valid
                Return ProjectCheckCatalog.TargetPathCharactersValidFactMessageKey
            Case TargetPathCharacterState.Invalid
                Return ProjectCheckCatalog.TargetPathCharactersValidWarningMessageKey
            Case Else
                Return ProjectCheckCatalog.TargetPathCharactersValidUnknownMessageKey
        End Select
    End Function

    Private Function ExpectedCoverOutcome(state As MuxerCoverConventionState) As ProjectCheckOutcome
        Select Case state
            Case MuxerCoverConventionState.NotApplicable
                Return ProjectCheckOutcome.NotApplicable
            Case MuxerCoverConventionState.Valid
                Return ProjectCheckOutcome.Fact
            Case MuxerCoverConventionState.Invalid
                Return ProjectCheckOutcome.Blocker
            Case Else
                Return ProjectCheckOutcome.Unknown
        End Select
    End Function

    Private Function ExpectedCoverSeverity(state As MuxerCoverConventionState) As ProjectCheckSeverity
        Select Case state
            Case MuxerCoverConventionState.NotApplicable
                Return ProjectCheckSeverity.NotApplicable
            Case MuxerCoverConventionState.Valid
                Return ProjectCheckSeverity.Information
            Case MuxerCoverConventionState.Invalid
                Return ProjectCheckSeverity.Blocker
            Case Else
                Return ProjectCheckSeverity.Unknown
        End Select
    End Function

    Private Function ExpectedCoverMessageKey(state As MuxerCoverConventionState) As String
        Select Case state
            Case MuxerCoverConventionState.NotApplicable
                Return ProjectCheckCatalog.MuxerCoverConventionNotApplicableMessageKey
            Case MuxerCoverConventionState.Valid
                Return ProjectCheckCatalog.MuxerCoverConventionFactMessageKey
            Case MuxerCoverConventionState.Invalid
                Return ProjectCheckCatalog.MuxerCoverConventionBlockerMessageKey
            Case Else
                Return ProjectCheckCatalog.MuxerCoverConventionUnknownMessageKey
        End Select
    End Function

    Private Function ExpectedOverallStatus(
        sourceOutcome As ProjectCheckOutcome,
        targetOutcome As ProjectCheckOutcome,
        coverOutcome As ProjectCheckOutcome) As ProjectCheckOverallStatus

        Dim outcomes = {sourceOutcome, targetOutcome, coverOutcome}

        If Array.IndexOf(outcomes, ProjectCheckOutcome.Blocker) >= 0 Then
            Return ProjectCheckOverallStatus.BlockersFound
        End If

        If Array.IndexOf(outcomes, ProjectCheckOutcome.Warning) >= 0 Then
            Return ProjectCheckOverallStatus.WarningsFound
        End If

        If Array.IndexOf(outcomes, ProjectCheckOutcome.Unknown) >= 0 Then
            Return ProjectCheckOverallStatus.ChecksIncomplete
        End If

        Return ProjectCheckOverallStatus.SelectedChecksPassed
    End Function

    Private Sub AssertOverall(
        expected As ProjectCheckOverallStatus,
        sourceState As SourceTargetTextState,
        targetState As TargetPathCharacterState,
        coverState As MuxerCoverConventionState,
        label As String)

        Dim actual = ProjectCheckEvaluator.Evaluate(
            New ProjectCheckSnapshot(sourceState, targetState, coverState)).OverallStatus
        AssertEqual(expected, actual, label)
    End Sub

    Private Sub AssertReadOnlyProperties(type As Type, label As String)
        For Each propertyInfo In type.GetProperties(BindingFlags.Instance Or BindingFlags.Public)
            AssertTrue(Not propertyInfo.CanWrite, label & "-property-" & propertyInfo.Name)
        Next
    End Sub

    Private Function CollectStableResultText() As String
        Dim snapshots = {
            New ProjectCheckSnapshot(SourceTargetTextState.Distinct, TargetPathCharacterState.Valid, MuxerCoverConventionState.NotApplicable),
            New ProjectCheckSnapshot(SourceTargetTextState.Identical, TargetPathCharacterState.Invalid, MuxerCoverConventionState.Invalid),
            New ProjectCheckSnapshot(CType(-1, SourceTargetTextState), CType(-1, TargetPathCharacterState), MuxerCoverConventionState.Unknown)
        }
        Dim builder As New StringBuilder()

        For Each snapshot In snapshots
            For Each check In ProjectCheckEvaluator.Evaluate(snapshot).Checks
                builder.Append(check.Id)
                builder.Append("|")
                builder.Append(check.MessageKey)
                builder.Append("|")
            Next
        Next

        Return builder.ToString()
    End Function

    Private Function ResultSignature(result As ProjectCheckResult) As String
        Dim builder As New StringBuilder()
        builder.Append(result.SchemaVersion.ToString(CultureInfo.InvariantCulture))
        builder.Append("|")
        builder.Append(CInt(result.OverallStatus).ToString(CultureInfo.InvariantCulture))

        For Each check In result.Checks
            builder.Append("|")
            builder.Append(check.Id)
            builder.Append(":")
            builder.Append(CInt(check.Category).ToString(CultureInfo.InvariantCulture))
            builder.Append(":")
            builder.Append(CInt(check.Outcome).ToString(CultureInfo.InvariantCulture))
            builder.Append(":")
            builder.Append(CInt(check.Severity).ToString(CultureInfo.InvariantCulture))
            builder.Append(":")
            builder.Append(check.MessageKey)
            builder.Append(":")
            builder.Append(check.SortOrder.ToString(CultureInfo.InvariantCulture))
        Next

        Return builder.ToString()
    End Function

    Private Function CollectPresentationText(state As ProjectCheckPresentationState) As String
        Dim builder As New StringBuilder()
        builder.Append(state.Kind.ToString())

        If state.Result IsNot Nothing Then
            builder.Append("|")
            builder.Append(ResultSignature(state.Result))
        End If

        Return builder.ToString()
    End Function

    Private Function IsBitSet(mask As Integer, bitIndex As Integer) As Boolean
        Return (mask And (1 << bitIndex)) <> 0
    End Function

    Private Sub AssertTrue(condition As Boolean, label As String)
        AssertionCount += 1

        If Not condition Then
            Throw New TestFailureException(label)
        End If
    End Sub

    Private Sub AssertEqual(Of T)(expected As T, actual As T, label As String)
        AssertionCount += 1

        If Not EqualityComparer(Of T).Default.Equals(expected, actual) Then
            Throw New TestFailureException(
                label & "-expected-" & FormatValue(expected) & "-actual-" & FormatValue(actual))
        End If
    End Sub

    Private Sub AssertThrows(Of TException As Exception)(action As Action, label As String)
        AssertionCount += 1

        Try
            action()
        Catch ex As TException
            Return
        Catch ex As Exception
            Throw New TestFailureException(label & "-wrong-exception-" & ex.GetType().Name)
        End Try

        Throw New TestFailureException(label & "-no-exception")
    End Sub

    Private Function FormatValue(value As Object) As String
        If value Is Nothing Then
            Return "null"
        End If

        Return SafeToken(Convert.ToString(value, CultureInfo.InvariantCulture))
    End Function

    Private Function SafeToken(value As String) As String
        If value Is Nothing Then
            Return "null"
        End If

        Dim token = value.Replace(Convert.ToChar(13), "-"c).
            Replace(Convert.ToChar(10), "-"c).
            Replace(Convert.ToChar(9), "-"c).
            Replace(" "c, "-"c)

        If token.Length > 120 Then
            token = token.Substring(0, 120)
        End If

        Return token
    End Function

    Private NotInheritable Class TestFailureException
        Inherits Exception

        Public Sub New(message As String)
            MyBase.New(message)
        End Sub
    End Class
End Module
