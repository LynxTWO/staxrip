# SLICE-001 M1 Pure Model and Harness

Date: 2026-08-15. Repository base: `c26e0fa6`. Status: Pass.

## Change boundary

M1 originally added four pure production files under `Source/Features/ProjectChecks/`, one package-free standalone test project under `Source/Tests/ProjectChecks/`, and four normal compile entries in `Source/StaxRip.vbproj`. M2 and M3 later extended the same source-linked harness with the pure coordinator and presentation-text files. Current aggregate evidence is recorded below; milestone-specific integration evidence is in `M2-INTEGRATION.md` and `M3-PRESENTATION.md`.

During M1, no form, adapter, source-opening path, project writer, solution mapping, package, CI file, build script, release script, x86 configuration, or runtime dependency changed.

## Pure contract

- **verified:** `ProjectCheckSnapshot` contains one schema version and the three bounded catalog enums. It contains no path, mutable project, arbitrary string, script, command, exception, log, or external output.
- **verified:** The evaluator always returns the three stable ids in sort order 100, 200, and 300.
- **verified:** Invalid enum values become Unknown checks. They do not become pass results or expose input text.
- **verified:** Each constructed check must match one complete allowlisted catalog tuple. A result must contain the three exact rows once in fixed order, and derives overall status from those rows.
- **verified:** Overall precedence is Blockers, Warnings, Incomplete, then Selected checks passed.
- **verified:** The selected-check success status exists only in the typed result. It does not authorize Add Job or encoding.
- **verified:** The activation policy accepts only successful depth-zero interactive UI-thread input with every encoding, job, batch, startup-suppression, and project-identity condition satisfied.
- **verified:** The refresh policy accepts only non-hidden capable states with zero source and mutation depth, UI-thread entry, and no job, batch, or startup suppressor.
- **verified:** The coordinator uses separate mutation counters, generation publication checks, and a single pending initial-evaluation capability. Mapper and evaluator failures converge to payload-free `Unavailable`.
- **verified:** The pure presentation renderer maps only allowlisted enums, ids, and message keys and always includes the exact later-check and non-authorization caveat in a visible summary.

## Standalone harness

The current harness links six pure production files: model, catalog, evaluator, activation and refresh policies, coordinator, and presentation text. XML inspection found zero project references, package references, and hint paths. `Source/StaxRip.sln` contains no harness entry. Output and intermediate paths remain below ignored `Source/obj/ProjectCheckTests/`.

Commands:

```text
MSBuild.exe Source\Tests\ProjectChecks\ProjectCheckEvaluatorTests.vbproj /nologo /v:minimal /t:Rebuild /p:Configuration=Debug /p:Platform=x64 /p:RestorePackages=false
Source\obj\ProjectCheckTests\bin\x64\Debug\ProjectCheckEvaluatorTests.exe
MSBuild.exe Source\Tests\ProjectChecks\ProjectCheckEvaluatorTests.vbproj /nologo /v:minimal /t:Rebuild /p:Configuration=Release /p:Platform=x64 /p:RestorePackages=false
Source\obj\ProjectCheckTests\bin\x64\Release\ProjectCheckEvaluatorTests.exe
```

Bounded output for both Debug x64 and Release x64:

```text
PASS ProjectCheckEvaluatorTests assertions=12199 activation_vectors=8192 refresh_vectors=1280
```

The 8,192 activation vectors cover all 512 Boolean combinations at source and mutation depths -1, 0, 1, and 2. Exactly one vector is accepted. The 1,280 refresh vectors cover five presentation kinds, all 16 Boolean combinations, and the same four values for both depths. Exactly three vectors are accepted, one for each permitted non-hidden presentation kind.

## Application compile check

Command:

```text
MSBuild.exe Source\StaxRip.vbproj /nologo /v:minimal /t:Build /p:Configuration=Debug /p:Platform=x64 /p:RestorePackages=false
```

Bounded output:

```text
StaxRip -> Source\bin\StaxRip.exe
```

This section retains the original M1 direct Debug x64 compile evidence. Current integration and product-assembly evidence is in `M2-INTEGRATION.md`. It still does not verify a real source-opening outcome, operating-system UI behavior, packaging, or release.

## Static checks

- **verified:** The pure production files contain no `System.IO`, file, directory, process, HTTP, socket, clipboard, or Windows Forms reference.
- **verified:** The M1 production and harness files contain no `Readiness` or `Ready` name.
- **verified:** `git diff --check` passes for the M1 files.
- **verified:** All M1 source and test output is under the approved source or ignored output roots.

An independent audit found that the first constructor shape admitted arbitrary stable-looking rows and duplicate result rows. M1 then added complete tuple allowlisting, exact ordered-catalog enforcement, derived precedence, and seven adversarial vectors. A Release x64 reflection recheck rejected arbitrary stable rows, undefined enums, duplicate rows, and reversed rows with `ArgumentException`. Reflection also confirmed that callers cannot supply overall status. No residual M1 finding remained in scope.

## Remaining boundary

M2 deterministic mapping, coordinator, lifecycle, invalidation, explicit refresh, production-source, product-assembly, and x64 build evidence passes. M3 production-control presentation evidence passes. M4 still owns real workflow compatibility, loaded GUI accessibility, performance, full-application handles, and the human walkthrough.
