# Check-OptionHelp

Validates `Docs/OptionHelp/*.md` against the grammar in `Docs/Planning/OPTION-HELP.md` and against the parameters declared in `Source/Encoding/*.vb`.

## Usage

```powershell
pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1              # report, exit 1 on any error
pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -SelfTest    # fixture suite
pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -Encoder svt-av1
pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -Json > report.json
pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -AdvanceRatchet
pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -CompareFacts facts.json
pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -Dump Docs/OptionHelp/svt-av1.md
```

`-Encoder <id>` keeps the source-level checks, the counters, and E5 to that encoder, and applies the stanza rules (parse errors, E6, the E12 file pairing) to its files, to those of every encoder in its inheritance chain, and to the shared files its text can display through; repository-wide checks (W1, resource entries without a file or `LogicalName`) run only in the unscoped mode. `-Json` writes only JSON to stdout; diagnostics go to stderr. `-AdvanceRatchet` runs only after a clean validation, lowers `Allowed-Missing` and raises `Minimum-Reviewed` to the current counts, never the other way, and never touches `Reviewed-Complete`. `-CompareFacts` takes the file written by the StaxRip command `-ExportOptionHelpFacts:<path>` and reports every difference between the application's view of the parameters and this script's extraction as E11.

## Rules

| Code | Level | Meaning |
| --- | --- | --- |
| E1 | file | Grammar or header violation, unknown Schema, name and header disagree, bad inheritance |
| E2 | stanza | Summary missing, overlong, or not ending with a period; When to change missing on a reviewed stanza; limits |
| E3 | stanza | Unknown, duplicate, or out-of-order field; Status missing or invalid; text or bullet in the wrong place |
| E4 | stanza | A value note names a value that none of the controls resolving to the stanza emits, judged over the union of their emitted values and reported once per stanza and value; or `Values` on a stanza no option parameter resolves to |
| E5 | stanza | Orphan stanza |
| E6 | stanza | Related or Use target missing, or Use target not reviewed; applies to the shared files too |
| E7 | file | A counter crossed its bound |
| E8 | file | Duplicate stanza id |
| E9 | source | OptionHelpId override missing or wrong |
| E10 | source | Parameter without identity |
| E11 | source | Parameter construction the extractor does not recognize, literal `Options` and `Values` arrays of different lengths, or a difference from the application export |
| E12 | project | Help file and EmbeddedResource entries do not pair up; an entry naming a file lacks `<LogicalName>StaxRip.OptionHelp.<file></LogicalName>` or declares a different one; Source path outside the repository or with different case |
| E13 | stanza | Bad URL scheme, malformed link, unmatched backtick, C0 control character other than tab |
| W1 | source | Encoder file with no help file |
| W2 | stanza | Label matches neither the caption nor the first line of the caption of any control that resolves to the stanza; the dialog wraps a long caption at a line break, which is how the four Custom boxes share one stanza |
| W3 | source | Excluded parameters |
| W4 | source | Own-namespace identity that resolves in the `staxrip` file because its local part collides with a StaxRip-owned key; the message names the file it resolved in |

## Known blind spots

The extractor reads text. It understands `New OptionParam|NumParam|BoolParam|StringParam ... With { ... }` declared as properties or inline inside `Add(...)`, with full-line comments removed. Anything else that constructs a parameter is E11, not silently invisible. Parameters that are declared but never added to `Items` count toward totals unless excluded with `OptionHelpKey = "none"`. Run `-CompareFacts` against a fresh application export before a close-out to reconcile.
