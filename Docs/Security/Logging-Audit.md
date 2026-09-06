# Log Sharing Audit

This pass covers StaxRip's in-process log builder, raw and obfuscated export paths, archived logs, optional debug trace, AutoCrop console output, and the GitHub bug-report instructions at commit `198223ea`.

## Scope and method

- Scanned 184 tracked VB, C++, PowerShell, YAML, XML, project, solution, and configuration files under `Source` and `.github`. Ignored build output, restored packages, binaries, and private audit files were excluded.
- A known-positive search found `LogBuilder` in five files. A sink search found 177 `Log.Write*` or `Log.Save` occurrences in 23 files.
- A second bounded search found no Sentry, Application Insights, App Center, OpenTelemetry, Serilog, NLog, log4net, analytics, Crashlytics, or session-replay identifier in the 184 candidates.
- Inspected the central sink, path selection, raw export, obfuscated export, history copy and retention, debug trace, issue instructions, and representative producers for environment details, media paths and metadata, scripts, command lines, tool output, exceptions, and Dolby Vision JSON.
- Replayed the `ObfuscateLogFile` replacement rules with synthetic paths. The current source directory and base name were removed. An unrelated target path and synthetic processor name remained.

## Findings

| Finding | Area | Sink | Data | Finding class | Protected? | Smallest safe action |
|---|---|---|---|---|---|---|
| Bug instructions point directly to a raw log | `.github/ISSUE_TEMPLATE/01-bug_report.yml:55` | Public GitHub issue attachment | Paths, scripts, command lines, media metadata, tool output, and system details | conditional leak | no, documentation only | Direct users to `Save Obfuscated As` and require review before upload |
| Normal logs and history are raw | `Source/General/LogBuilder.vb:94-194`, `Source/General/GlobalClass.vb:1621-1634` | Local UTF-8 log and settings history | CPU, GPU, culture, paths, configuration, scripts, command lines, and external-tool output | conditional leak | yes for runtime redaction or retention changes | Keep runtime unchanged; improve sharing guidance first |
| Obfuscated export covers only the current source path and base name | `Source/General/GlobalClass.vb:1185-1202`, `Source/Forms/LogForm.vb:43-53` | User-selected UTF-8 export | Other paths, scripts, command lines, and system details can remain | conditional leak | yes for runtime redaction changes | Describe the limit and tell users to review the exported file |
| Optional debug trace can receive caller-supplied text | `Source/General/GlobalClass.vb:321-324`, `Source/Forms/MainForm.vb:1005-1016` | `Debug.log` under the startup directory | Depends on each `WriteDebugLog` caller | needs runtime confirmation | yes for runtime logging changes | Audit callers separately before changing the trace contract |
| AutoCrop prints full exceptions to stdout | `Source/Tools/AutoCrop/Main.vb:76-78` | Captured subprocess output | Exception type, message, and stack | needs runtime confirmation | yes, native/support process boundary | Use synthetic failures to establish actual path content before proposing redaction |

No telemetry, analytics, or crash-reporting SDK identifier was found in this bounded source scan. This does not prove that external tools never echo sensitive arguments or metadata into captured output.

## Fix selected

Update the GitHub bug-report form only. Tell reporters to open `Project > Log File`, use `Save Obfuscated As`, and review the result because unrelated paths, scripts, command lines, and system details may remain. Do not change runtime logging, redaction, retention, or export behavior in the same patch.

## Safe patterns for StaxRip

- Treat job logs as private until the user reviews them.
- Prefer `Save Obfuscated As` over sharing the raw working log.
- State that obfuscation covers the current source path, not every path or command.
- Keep tokens, credentials, signed URLs, and private script values out of command lines when a tool supports a safer input channel.
- Use synthetic paths and media names in issues, fixtures, screenshots, and failure packets.
- Keep raw logs local unless the user deliberately attaches them.
- Review external-tool output before assuming StaxRip can redact it safely.
- Keep debug traces and release or build logs free of secrets.

## High-risk domain note

StaxRip processes user-selected local media and scripts. The inspected code has no application authentication, billing, or regulated-data model. Media names, directory names, scripts, and command lines can still disclose personal or confidential information when a log is published.

## Unknowns and follow-up

### External-tool output privacy

- **Area or file:** `Source/General/Proc.vb`, captured output from bundled and user-selected tools
- **Concern:** External tools can echo paths, metadata, arguments, or environment-specific failures into the StaxRip log, but the exact payload varies by executable and workflow.
- **Why it matters:** A source-only redactor cannot safely promise complete privacy without knowing each tool's output contract.
- **Evidence found so far:** `Proc` writes command lines and captured output to the central log. The bounded scan covered StaxRip source but did not execute bundled tools or inspect every external output format.
- **Confidence:** unknown
- **Likely owner:** StaxRip maintainer and each external-tool owner
- **Next best check:** Run representative workflows with synthetic paths, then classify the output fields that survive `Save Obfuscated As`.
- **Risk level:** medium
- **Status:** open
- **Notes:** Do not use real user media or logs as fixtures.

## Coverage note

This pass maps the central StaxRip log, its local copies, its two manual export choices, its public issue handoff, and the optional debug and AutoCrop sinks. It does not claim semantic review of all 177 call sites, runtime activation of any encoder or tool, inspection of bundled binary internals, or coverage of content users paste manually into GitHub.
