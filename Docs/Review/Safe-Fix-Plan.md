# Safe Fix Plan

## Contributor build guide

- **Files:** `Docs/Contribution/README.md` and `Docs/README.md`.
- **Classification:** Documentation only.
- **Why this is safe now:** A clean detached worktree at commit `198223ea` completed the documented x64 restore, dependency staging, and build commands. No application or release behavior changes.
- **Behavior that must remain unchanged:** Project files, solution mappings, build scripts, dependency versions, runtime files, and release contents.
- **Checks:** Validate links and Markdown hygiene; repeat the documented restore and `Debug|x64` builds in the isolated worktree; confirm the upstream patch contains only the two documentation files.
- **Documentation:** Add the source-build procedure and activate its existing documentation-index link.
- **Rollback:** Revert the index line and remove `Docs/Contribution/README.md`.
- **Observability:** None. The change does not alter logging or runtime diagnostics.
- **Approval:** The user approved dependency retrieval, build verification, documentation, and an upstream pull request. Release scripts remain out of scope.

## Fork maintenance fallback

- Keep `agent/contributor-build-guide` available in `LynxTWO/staxrip` even if upstream pull request #1986 receives no response.
- Treat `upstream/master` as the integration baseline. Rebase or merge it into fork work before validating or proposing another change.
- Keep the calibrated verification files local while the upstream documentation proposal is under review. Do not mix them into pull request #1986.
- Re-run the documented restore and the smallest relevant x64 gate after upstream changes touch the solution, project files, package declarations, or build documentation.
- Do not change the unusual solution-level Release mapping until maintainer intent or equivalent release evidence establishes the contract.
- Propose follow-ups independently: native conversion-warning cleanup, build-output layout or ignore rules, AutoCrop tracked-binary policy, and an optional source-build CI check must each have their own evidence and pull request.
- Do not infer acceptance from inactivity. The fork may carry a verified improvement, but upstream publication remains a maintainer decision.

## Proposed FrameServer string-conversion repair

- **Files:** `Source/FrameServer/Common.cpp`.
- **Classification:** Behavior hardening at an approval-gated native boundary.
- **Why this is bounded:** The seven warnings and the failed Win32-call dependency are reproduced at commit `198223ea`. The change can remain inside one implementation file without altering exports or structures.
- **Behavior that must remain unchanged:** Valid ANSI and UTF-8 path conversions, valid error-text conversion, exported functions, and the FrameServer ABI.
- **Checks:** Run the isolated conversion probe, then rebuild FrameServer in Debug and Release x64. Confirm the exact warning delta.
- **Documentation:** Keep the evidence and limits in the local remediation records. No user documentation change is required.
- **Rollback:** Revert the one-file commit.
- **Observability:** Windows error strings lose unused NUL padding. No new logging is added.
- **Approval:** Approved by the user on 2026-08-10. Implemented as commit `d8dfc00f` in draft pull request #1987; maintainer review is pending.

## Proposed VapourSynth narrowing repair

- **Files:** `Source/FrameServer/VapourSynthServer.cpp`.
- **Classification:** Behavior hardening at an approval-gated ABI and frame-ownership boundary.
- **Why this is bounded:** The wider R79 source types, 32-bit StaxRip ABI, three warnings, and target conversion results are verified. The proposed edit does not change the ABI layout.
- **Behavior that must remain unchanged:** Representable metadata and strides, frame ownership on successful calls, existing COM declarations, and ordinary managed callers.
- **Checks:** Exercise accepted and rejected boundary values, inspect cleanup on the rejected stride branch, and rebuild FrameServer plus the main solution in Debug and Release x64.
- **Documentation:** Record the rejection policy in local evidence. Upstream release notes are unnecessary unless the maintainer requests them.
- **Rollback:** Revert the one-file commit.
- **Observability:** Add only fixed error text for rejected metadata. Do not include paths or script content.
- **Approval:** Approved by the user on 2026-08-10. Implemented as commit `74e15053` in draft pull request #1988; maintainer review is pending.

## Proposed FrameServer x64 intermediate-path repair

- **Files:** `Source/FrameServer/FrameServer.vcxproj` only.
- **Classification:** Behavior-preserving build-output configuration in an approval-gated native project.
- **Why this is bounded:** Only the two x64 property groups lack the `IntDir` value already used by Win32. Concrete path overrides passed both x64 configurations and moved compiler intermediates into the existing ignored tree.
- **Behavior that must remain unchanged:** Compiler and linker inputs, configuration isolation, parallel-build safety, `FrameServer.dll` contents apart from normal rebuild variance, and the final `Source/bin` output path.
- **Checks:** Evaluate `IntDir`, rebuild FrameServer Debug and Release x64, inspect C1041 and LNK1181 absence, verify unchanged `TargetPath`, and require a clean worktree outside ignored output.
- **Documentation:** Update the private verification record. The contributor guide does not need another output-path warning after the project fix.
- **Rollback:** Remove the two `IntDir` elements.
- **Observability:** None.
- **Approval:** Approved by the user on 2026-08-10. Implemented as commit `bf855df7` in draft pull request #1989; maintainer review is pending.

## AutoCrop tracked-binary policy hold

- **Files:** No source or tracked-binary edit is planned.
- **Classification:** Approval-gated build and release policy with an unresolved external owner decision.
- **Why this is bounded:** Git history establishes deliberate binary updates, but the repository does not expose their staging route. The existing contributor guide already warns that Release builds modify tracked files.
- **Behavior that must remain unchanged:** AutoCrop Release artifact production, source-to-binary updates, portable Apps staging, and packaged content.
- **Checks:** Ask for the artifact contract, then compare source, rebuilt, staged, and packaged identities before proposing a change.
- **Documentation:** Keep the warning in draft pull request #1986 and the evidence in private audit records.
- **Rollback:** Not applicable until a policy edit is approved.
- **Observability:** None.
- **Approval:** Deferred. Maintainer intent or equivalent release evidence is required before changing `OutputPath` or tracked artifacts.

## Proposed unused updater architecture-parameter cleanup

- **Files:** `Source/General/StaxRipUpdate.vb`, `Source/General/GlobalCommands.vb`, and `Source/Forms/MainForm.vb`.
- **Classification:** Behavior-preserving cleanup at an approval-gated update boundary.
- **Why this is bounded:** The parameter has no reads, the complete tracked call-site set contains two callers, and release selection is already unconditionally x64.
- **Behavior that must remain unchanged:** Update timing, force checks, supporter-release behavior, GitHub requests, x64 asset matching, version comparison, dismiss state, and dialogs.
- **Checks:** Confirm the signature and two call sites are the only diff, search for remaining callers, and build the main project in Debug and Release x64.
- **Documentation:** Retain the broader x86 retirement question in the private unknowns ledger; no user-facing documentation change is required.
- **Rollback:** Restore the optional parameter and the two second arguments.
- **Observability:** None.
- **Approval:** Approved by the user on 2026-08-10. Implemented as commit `29a8ab27` in draft pull request #1990. Project-configuration and runtime x86 removal remain separate.

## Bug-report log privacy guidance

- **Files:** `.github/ISSUE_TEMPLATE/01-bug_report.yml` only.
- **Classification:** Documentation-only privacy guidance.
- **Why this is safe now:** The UI route and narrow source-path obfuscation behavior are verified. The patch does not change log generation, retention, export, or redaction.
- **Behavior that must remain unchanged:** Runtime logging, `Save As`, `Save Obfuscated As`, log paths, history retention, issue-form fields, and required answers.
- **Checks:** Parse the file as YAML, run writing hygiene and `git diff --check`, and inspect the one-file upstream patch.
- **Documentation:** Replace the direct raw-log instruction with the safer UI export route and an explicit review warning.
- **Rollback:** Restore the prior description block.
- **Observability:** None.
- **Approval:** No protected runtime area was edited. The user's autonomous-work instruction covered this bounded documentation patch. Commit `62ba4d86` is in draft pull request #1991.
