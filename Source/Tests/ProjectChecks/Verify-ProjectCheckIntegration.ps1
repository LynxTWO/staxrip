param(
    [string] $RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\.."))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$script:AssertionCount = 0

function Assert-True {
    param(
        [Parameter(Mandatory)]
        [bool] $Condition,

        [Parameter(Mandatory)]
        [string] $Label
    )

    if (-not $Condition) {
        throw "Integration source check failed: $Label"
    }

    $script:AssertionCount += 1
}

function Get-SourceText {
    param([Parameter(Mandatory)][string] $RelativePath)

    $path = Join-Path $RepositoryRoot $RelativePath
    if (-not [IO.File]::Exists($path)) {
        throw "Integration source input is missing: $RelativePath"
    }

    return [IO.File]::ReadAllText($path)
}

function Get-TextSegment {
    param(
        [Parameter(Mandatory)][string] $Text,
        [Parameter(Mandatory)][string] $StartMarker,
        [Parameter(Mandatory)][string] $EndMarker
    )

    $start = $Text.IndexOf($StartMarker, [StringComparison]::Ordinal)
    if ($start -lt 0) {
        throw "Integration source marker is missing: $StartMarker"
    }

    $end = $Text.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal)
    if ($end -lt 0) {
        throw "Integration source marker is missing: $EndMarker"
    }

    return $Text.Substring($start, $end - $start)
}

$mainForm = Get-SourceText "Source/Forms/MainForm.vb"
$mainProjectChecks = Get-SourceText "Source/Forms/MainForm_SourceProjectChecks.vb"
$globalClass = Get-SourceText "Source/General/GlobalClass.vb"
$videoEncoder = Get-SourceText "Source/Encoding/VideoEncoder.vb"
$project = Get-SourceText "Source/General/Project.vb"
$coordinator = Get-SourceText "Source/Features/ProjectChecks/ProjectCheckCoordinator.vb"
$presentationText = Get-SourceText "Source/Features/ProjectChecks/ProjectCheckPresentationText.vb"
$summaryControl = Get-SourceText "Source/Controls/ProjectChecksSummaryControl.vb"
$detailsForm = Get-SourceText "Source/Forms/ProjectChecksDetailsForm.vb"
$formBase = Get-SourceText "Source/UI/Misc.vb"
$projectFile = Get-SourceText "Source/StaxRip.vbproj"
$solutionFile = Get-SourceText "Source/StaxRip.sln"

$stringOpenProject = Get-TextSegment `
    $mainForm `
    "Function OpenProject(path As String, saveCurrentFirst As Boolean) As Boolean" `
    "Function OpenProject(proj As Project"
$stringBegin = $stringOpenProject.IndexOf("BeginProjectCheckClearingMutation()", [StringComparison]::Ordinal)
$stringFirstAssignment = $stringOpenProject.IndexOf("p = SafeSerialization.Deserialize", [StringComparison]::Ordinal)
$stringFallbackAssignment = $stringOpenProject.IndexOf("p = New Project()", [StringComparison]::Ordinal)
Assert-True ($stringBegin -ge 0) "string project overload mutation scope"
Assert-True ($stringBegin -lt $stringFirstAssignment) "scope before deserialized project assignment"
Assert-True ($stringBegin -lt $stringFallbackAssignment) "scope before fallback project assignment"
Assert-True `
    ([regex]::IsMatch(
        $stringOpenProject,
        "Finally\s*\r?\n\s*EndProjectCheckClearingMutation\(\)\s*\r?\n\s*End Try")) `
    "string project scope balances in finally"

$objectOpenProject = Get-TextSegment `
    $mainForm `
    "Function OpenProject(proj As Project" `
    "Sub SetSlider()"
$objectBegin = $objectOpenProject.LastIndexOf("BeginProjectCheckClearingMutation()", [StringComparison]::Ordinal)
$objectAssignment = $objectOpenProject.IndexOf("p = If(proj IsNot Nothing", [StringComparison]::Ordinal)
Assert-True ($objectBegin -ge 0 -and $objectBegin -lt $objectAssignment) "scope before object project assignment"
Assert-True `
    ([regex]::IsMatch(
        $objectOpenProject,
        "Finally[\s\S]*If projectCheckMutationStarted Then\s*\r?\n\s*EndProjectCheckClearingMutation\(\)")) `
    "object project scope balances in finally"

$globalProjectAssignmentCount = [regex]::Matches($mainForm, "(?m)^\s*p\s*=").Count
Assert-True ($globalProjectAssignmentCount -eq 3) "three mapped global project assignments"

$sharedSourceSignature = "Sub OpenVideoSourceFiles(files As IEnumerable(Of String), demuxSource As Boolean, isEncoding As Boolean, Optional errorTimeout As Integer = 0)"
Assert-True `
    ([regex]::IsMatch(
        $mainForm,
        [regex]::Escape($sharedSourceSignature) + "\s*\r?\n\s*BeginProjectCheckClearingMutation\(\)\s*\r?\n\s*Interlocked\.Increment\(ProjectCheckSourceOpenDepth\)",
        [Text.RegularExpressions.RegexOptions]::CultureInvariant)) `
    "shared source overload begins with clearing mutation and depth reservation"
Assert-True `
    ($mainForm.Contains("OpenVideoSourceFiles(files, demux, False, errorTimeout)", [StringComparison]::Ordinal)) `
    "interactive wrapper retains false encoding flag"
Assert-True `
    ($globalClass.Contains("g.MainForm.OpenVideoSourceFiles(p.SourceFiles, True, True, s.ErrorMessageTimeout)", [StringComparison]::Ordinal)) `
    "job path retains true encoding flag"
Assert-True `
    ($mainForm.Contains("-NoFocus -LoadTemplate:", [StringComparison]::Ordinal)) `
    "extra-source child retains no-focus command"

$sourceTransaction = Get-TextSegment $mainForm $sharedSourceSignature "Sub ModifyFilters("
Assert-True `
    ([regex]::IsMatch(
        $sourceTransaction,
        "g\.RaiseAppEvent\(ApplicationEvent\.AfterProjectOrSourceLoaded\)\s*\r?\n\s*Log\.Save\(\)\s*\r?\n\s*transactionSucceeded = True")) `
    "success assigned only after final log save"
Assert-True `
    ([regex]::IsMatch(
        $sourceTransaction,
        "Finally[\s\S]*remainingSourceOpenDepth = Interlocked\.Decrement\(ProjectCheckSourceOpenDepth\)\s*\r?\n\s*sourceCompletionGeneration = EndProjectCheckClearingMutation\(\)\s*\r?\n\s*remainingProjectCheckMutationDepth = ProjectCheckMutationDepth[\s\S]*End Try\s*\r?\n\s*Dim activationContext[\s\S]*ProjectCheckActivationPolicy\.ShouldEvaluate\(activationContext\)[\s\S]*EvaluateProjectChecks\(sourceCompletionGeneration\)")) `
    "evaluation follows complete transaction finally"
$sourceBalance = $sourceTransaction.IndexOf("remainingSourceOpenDepth = Interlocked.Decrement(ProjectCheckSourceOpenDepth)", [StringComparison]::Ordinal)
$processFinished = $sourceTransaction.IndexOf("ProcController.Finished()", [StringComparison]::Ordinal)
Assert-True `
    ($sourceBalance -ge 0 -and $processFinished -gt $sourceBalance) `
    "source mutation balance precedes process cleanup"
Assert-True `
    ([regex]::IsMatch(
        $sourceTransaction,
        "Try\s*\r?\n\s*remainingSourceOpenDepth = Interlocked\.Decrement\(ProjectCheckSourceOpenDepth\)[\s\S]*Finally\s*\r?\n\s*If processingStarted AndAlso Not isEncoding Then\s*\r?\n\s*ProcController\.Finished\(\)")) `
    "source mutation balance cannot be skipped by process cleanup"
Assert-True `
    ($sourceTransaction.IndexOf("Interlocked.Increment(ProjectCheckSourceOpenDepth)", [StringComparison]::Ordinal) -lt
        $sourceTransaction.IndexOf("IsSaveCanceled()", [StringComparison]::Ordinal) -and
     $sourceTransaction.IndexOf("Interlocked.Increment(ProjectCheckSourceOpenDepth)", [StringComparison]::Ordinal) -lt
        $sourceTransaction.IndexOf("SafeSerialization.Serialize", [StringComparison]::Ordinal) -and
     $sourceTransaction.IndexOf("Interlocked.Increment(ProjectCheckSourceOpenDepth)", [StringComparison]::Ordinal) -lt
        $sourceTransaction.IndexOf("transactionSucceeded = True", [StringComparison]::Ordinal)) `
    "atomic source depth covers save recovery and processing"

$processCommandLine = Get-TextSegment $mainForm "Sub ProcessCommandLine(commandLine As String)" "Sub SetHideDialogsOption("
Assert-True `
    ($processCommandLine.Contains('String.Equals(arg.TrimQuotes(), "-NoFocus", StringComparison.OrdinalIgnoreCase)', [StringComparison]::Ordinal)) `
    "exact no-focus command scope"
Assert-True `
    ([regex]::IsMatch(
        $processCommandLine,
        "Finally\s*\r?\n\s*ProjectCheckStartupNoFocusCommandSuppressed = priorStartupNoFocusCommandSuppressed\s*\r?\n\s*End Try")) `
    "no-focus command scope restored in finally"

$indexMutationCount = [regex]::Matches(
    $mainForm,
    "BeginProjectCheckInvalidatingMutation\(\)\s*\r?\n\s*Try\s*\r?\n\s*p\.SourceFile = p\.LastOriginalSourceFile\s*\r?\n\s*Finally\s*\r?\n\s*EndProjectCheckInvalidatingMutation\(\)").Count
Assert-True ($indexMutationCount -eq 4) "four balanced indexing mutation scopes"
Assert-True `
    ([regex]::IsMatch(
        $mainForm,
        "If e\.PropertyName = NameOf\(Project\.TargetFile\) Then\s*\r?\n\s*InvalidateProjectChecks\(\)")) `
    "target property invalidation"
Assert-True `
    ([regex]::Matches(
        $videoEncoder,
        "BeginProjectCheckInvalidatingMutation\(\)").Count -eq 2 -and
     [regex]::Matches(
        $videoEncoder,
        "Finally\s*\r?\n\s*If isActiveEncoder Then g\.MainForm\.EndProjectCheckInvalidatingMutation\(\)").Count -eq 2) `
    "active muxer mutations balance in finally"
Assert-True `
    ([regex]::IsMatch(
        $globalClass,
        "Dim currentMuxer = p\.VideoEncoder\.Muxer\s*\r?\n\s*MainForm\.BeginProjectCheckInvalidatingMutation\(\)[\s\S]*Try\s*\r?\n\s*p\.VideoEncoder =[\s\S]*Finally\s*\r?\n\s*MainForm\.EndProjectCheckInvalidatingMutation\(\)")) `
    "active video encoder mutation balances in finally"
Assert-True `
    ([regex]::IsMatch(
        $project,
        "Dim projectCheckOwner = If\(Me Is p, g\.MainForm, Nothing\)\s*\r?\n\s*projectCheckOwner\?\.BeginProjectCheckInvalidatingMutation\(\)[\s\S]*TargetFileValue = value\s*\r?\n\s*NotifyPropertyChanged\(\)[\s\S]*Finally\s*\r?\n\s*projectCheckOwner\?\.EndProjectCheckInvalidatingMutation\(\)")) `
    "target assignment mutation balances in finally"

Assert-True ($mainProjectChecks.Contains("AddressOf CreateProjectCheckSnapshot", [StringComparison]::Ordinal)) "composition-root mapper delegate"
Assert-True ($mainProjectChecks.Contains("AddressOf ProjectCheckEvaluator.Evaluate", [StringComparison]::Ordinal)) "composition-root evaluator delegate"
Assert-True ($coordinator.Contains("Catch ex As Exception", [StringComparison]::Ordinal)) "bounded dependency failure conversion"
Assert-True ($coordinator.Contains("PendingInitialGeneration As Long = Long.MinValue", [StringComparison]::Ordinal)) "initial evaluation requires completion capability"
Assert-True ($coordinator.Contains("PendingInitialGeneration = Long.MinValue", [StringComparison]::Ordinal)) "mutations revoke initial capability"
Assert-True ($coordinator.Contains("Private ActiveClearingMutationCount As Integer", [StringComparison]::Ordinal)) "separate clearing mutation count"
Assert-True ($coordinator.Contains("Private ActiveInvalidatingMutationCount As Integer", [StringComparison]::Ordinal)) "separate invalidating mutation count"
Assert-True ($coordinator.Contains("observedGeneration = Generation AndAlso GetActiveMutationCount() = 0", [StringComparison]::Ordinal)) "publication requires current generation and no active mutation"
Assert-True ([regex]::Matches($coordinator, "scope is not active\.").Count -eq 2) "mismatched mutation ends fail closed"
Assert-True `
    ([regex]::IsMatch(
        $mainProjectChecks,
        "Friend Sub BeginProjectCheckClearingMutation\(\)[\s\S]*coordinator\?\.BeginClearingMutation\(\)[\s\S]*Catch\s*\r?\n\s*coordinator\?\.EndClearingMutation\(\)\s*\r?\n\s*Throw[\s\S]*End Sub\s*\r?\n\s*Friend Function EndProjectCheckClearingMutation")) `
    "clearing begin wrapper balances if rendering fails"
Assert-True `
    ([regex]::IsMatch(
        $mainProjectChecks,
        "Friend Sub BeginProjectCheckInvalidatingMutation\(\)[\s\S]*coordinator\?\.BeginInvalidatingMutation\(\)[\s\S]*Catch\s*\r?\n\s*coordinator\?\.EndInvalidatingMutation\(\)\s*\r?\n\s*Throw[\s\S]*End Sub\s*\r?\n\s*Friend Sub EndProjectCheckInvalidatingMutation")) `
    "invalidating begin wrapper balances if rendering fails"
Assert-True ($mainProjectChecks.Contains("ProjectCheckRefreshPolicy.ShouldEvaluate(context)", [StringComparison]::Ordinal)) "refresh uses pure activation policy"
Assert-True ($mainProjectChecks.Contains("ProjectCheckCoordinatorValue.Refresh()", [StringComparison]::Ordinal)) "refresh uses capability-enforcing coordinator route"
Assert-True (-not $mainProjectChecks.Contains("ProjectCheckCoordinatorValue.Evaluate()", [StringComparison]::Ordinal)) "no unguarded coordinator evaluation route"
Assert-True ($mainProjectChecks.Contains("BeginInvoke(New MethodInvoker(AddressOf RenderCurrentProjectCheckPresentation))", [StringComparison]::Ordinal)) "background rendering queues a state re-read"
Assert-True ($mainProjectChecks.Contains("Dim currentState = ProjectCheckCoordinatorValue.CurrentState", [StringComparison]::Ordinal)) "render path re-reads coordinator state"
Assert-True ($mainProjectChecks.Contains("Not Object.ReferenceEquals(currentState, ProjectCheckDetailsStateValue)", [StringComparison]::Ordinal)) "state replacement closes stale details"
Assert-True ($mainProjectChecks.Contains("ProjectCheckDetailsDialogValue.Close()", [StringComparison]::Ordinal)) "stale details close before summary render"
Assert-True ($mainProjectChecks.Contains("Object.ReferenceEquals(CurrentProjectCheckPresentationState, currentState)", [StringComparison]::Ordinal)) "details snapshot rechecked before modal display"

$installCallCount = [regex]::Matches($mainForm, "InstallProjectCheckMenu\(\)").Count
Assert-True ($installCallCount -eq 2) "fixed menu installed after initial and edited custom menus"
Assert-True ($mainProjectChecks.Contains('.Name = ProjectChecksMenuName', [StringComparison]::Ordinal)) "fixed menu has stable name"
Assert-True ($mainProjectChecks.Contains('.Text = "Source chec&ks"', [StringComparison]::Ordinal)) "fixed menu has approved mnemonic"
Assert-True ($mainProjectChecks.Contains('.Text = "&View details..."', [StringComparison]::Ordinal)) "details menu has approved text"
Assert-True ($mainProjectChecks.Contains('.Text = "&Refresh project checks"', [StringComparison]::Ordinal)) "refresh menu has approved text"
Assert-True (-not $mainProjectChecks.Contains("String.Equals(item.Text", [StringComparison]::Ordinal)) "fixed menu identity does not depend on user-visible text"
Assert-True ([regex]::Matches($mainProjectChecks, "New ToolStripMenuItem With").Count -eq 3) "fixed menu uses three standard menu items"
Assert-True ($mainForm.Contains("Me.tlpMain.SetColumnSpan(Me.gbAssistant, 3)", [StringComparison]::Ordinal)) "Assistant spans three columns"
Assert-True ($mainForm.Contains("New RowStyle(SizeType.Absolute, 531.0!)", [StringComparison]::Ordinal)) "bottom row is 177 logical pixels"
Assert-True ($mainProjectChecks.Contains("tlpMain.Controls.Add(ProjectChecksSummaryValue, 3, 4)", [StringComparison]::Ordinal)) "summary occupies the fourth bottom cell"
Assert-True ($mainProjectChecks.Contains("currentState.Kind = ProjectCheckPresentationKind.Hidden", [StringComparison]::Ordinal)) "hidden summary selects full-width Assistant layout"
Assert-True ($mainProjectChecks.Contains("tlpMain.GetColumnSpan(gbAssistant) <> assistantColumnSpan", [StringComparison]::Ordinal)) "Assistant span changes only when required"
Assert-True ($mainProjectChecks.Contains("tlpMain.SetColumnSpan(gbAssistant, assistantColumnSpan)", [StringComparison]::Ordinal)) "Assistant restores four hidden columns and three visible columns"

Assert-True ($presentationText.Contains('"Fact " + factCount', [StringComparison]::Ordinal)) "strict Fact count copy"
Assert-True ($presentationText.Contains('"Warning " + warningCount', [StringComparison]::Ordinal)) "strict Warning count copy"
Assert-True ($presentationText.Contains('"Blocker " + blockerCount', [StringComparison]::Ordinal)) "strict Blocker count copy"
Assert-True ($presentationText.Contains('"Unknown " + unknownCount', [StringComparison]::Ordinal)) "strict Unknown count copy"
Assert-True ($presentationText.Contains('"N/A " + notApplicableCount', [StringComparison]::Ordinal)) "strict not-applicable count copy"
Assert-True ($presentationText.Contains("This result does not authorize encoding.", [StringComparison]::Ordinal)) "summary has non-authorization caveat"
Assert-True ($summaryControl.Contains('.Text = "&Details..."', [StringComparison]::Ordinal)) "summary details mnemonic"
Assert-True ($summaryControl.Contains('.Text = "&Refresh"', [StringComparison]::Ordinal)) "summary refresh mnemonic"
Assert-True ($summaryControl.Contains("state.Kind = ProjectCheckPresentationKind.Available", [StringComparison]::Ordinal)) "details action requires available result"
Assert-True ($summaryControl.Contains("state.Kind <> ProjectCheckPresentationKind.Hidden", [StringComparison]::Ordinal)) "refresh action requires source capability"
Assert-True ($summaryControl.Contains("StatusLabel.AccessibleName = StatusLabel.Text", [StringComparison]::Ordinal)) "summary result text is the accessible name"
Assert-True ($detailsForm.Contains(".AccessibleName = ProjectCheckPresentationText.DetailsNotice", [StringComparison]::Ordinal)) "details notice text is the accessible name"
Assert-True ([regex]::Matches($summaryControl + $detailsForm + $mainProjectChecks, "AccessibleName\s*=").Count -ge 13) "project-check UI has explicit accessible names"
Assert-True ([regex]::Matches($summaryControl + $detailsForm + $mainProjectChecks, "AccessibleDescription\s*=").Count -ge 13) "project-check UI has explicit accessible descriptions"
Assert-True ([regex]::Matches($summaryControl + $detailsForm, "FlatAppearance\.BorderColor = SystemColors\.ControlText").Count -eq 2) "high contrast uses system button borders"
Assert-True ($detailsForm.Contains(".ReadOnly = True", [StringComparison]::Ordinal)) "details grid is read only"
Assert-True ($detailsForm.Contains(".ClipboardCopyMode = DataGridViewClipboardCopyMode.Disable", [StringComparison]::Ordinal)) "details grid does not export path-bearing payloads"
Assert-True ($detailsForm.Contains("RememberPosition = False", [StringComparison]::Ordinal)) "details dialog does not persist position"
Assert-True ([regex]::Matches($formBase, "RememberPosition").Count -eq 3) "position opt-out has one default and two guards"
Assert-True ($formBase.Contains("Protected Property RememberPosition As Boolean = True", [StringComparison]::Ordinal)) "existing dialogs preserve position behavior by default"

$projectCheckProductionText = $mainProjectChecks + $coordinator + $presentationText + $summaryControl + $detailsForm
Assert-True (-not [regex]::IsMatch($projectCheckProductionText, "(?i)\bready(?:ness)?\b")) "no forbidden ready naming"
Assert-True (-not [regex]::IsMatch($projectCheckProductionText, "(?m)\bLog\b|\bProcess\.|\bFile\.|\bDirectory\.")) "no project-check log process or filesystem boundary"

$productionCompileFiles = @(
    "Features\ProjectChecks\ProjectCheckModel.vb",
    "Features\ProjectChecks\ProjectCheckCatalog.vb",
    "Features\ProjectChecks\ProjectCheckEvaluator.vb",
    "Features\ProjectChecks\ProjectCheckActivationPolicy.vb",
    "Features\ProjectChecks\ProjectCheckCoordinator.vb",
    "Features\ProjectChecks\ProjectCheckPresentationText.vb",
    "Controls\ProjectChecksSummaryControl.vb",
    "Forms\ProjectChecksDetailsForm.vb",
    "Forms\MainForm_SourceProjectChecks.vb"
)
foreach ($compileFile in $productionCompileFiles) {
    $count = [regex]::Matches($projectFile, [regex]::Escape('Compile Include="' + $compileFile + '"')).Count
    Assert-True ($count -eq 1) "one production compile entry for $compileFile"
}

Assert-True (-not $solutionFile.Contains("ProjectCheckEvaluatorTests", [StringComparison]::Ordinal)) "no solution test mapping"

"PASS project-check-integration source_assertions=$script:AssertionCount project_assignments=3 indexing_mutation_scopes=4"
