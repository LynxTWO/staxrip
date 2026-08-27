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

`-Encoder <id>` checks that file alone; repository-wide checks (W1, resource entries without a file) run only in the unscoped mode. `-Json` writes only JSON to stdout; diagnostics go to stderr. `-AdvanceRatchet` runs only after a clean validation, lowers `Allowed-Missing` and raises `Minimum-Reviewed` to the current counts, never the other way, and never touches `Reviewed-Complete`. `-CompareFacts` takes the file written by the StaxRip command `-ExportOptionHelpFacts:<path>` and reports every difference between the application's view of the parameters and this script's extraction as E11.

## Rules

| Code | Level | Meaning |
| --- | --- | --- |
| E1 | file | Grammar or header violation, unknown Schema, name and header disagree, bad inheritance |
| E2 | stanza | Summary missing, overlong, or not ending with a period; When to change missing on a reviewed stanza; limits |
| E3 | stanza | Unknown, duplicate, or out-of-order field; Status missing or invalid; text or bullet in the wrong place |
| E4 | stanza | A value note names a value the option does not emit |
| E5 | stanza | Orphan stanza |
| E6 | stanza | Related or Use target missing, or Use target not reviewed |
| E7 | file | A counter crossed its bound |
| E8 | file | Duplicate stanza id |
| E9 | source | OptionHelpId override missing or wrong |
| E10 | source | Parameter without identity |
| E11 | source | Parameter construction the extractor does not recognize, or a difference from the application export |
| E12 | project | Help file and EmbeddedResource entries do not pair up; an entry naming a file lacks `<LogicalName>StaxRip.OptionHelp.<file></LogicalName>`; Source path outside the repository or with different case |
| E13 | stanza | Bad URL scheme, malformed link, unmatched backtick |
| W1 | source | Encoder file with no help file |
| W2 | stanza | Label differs from the VB caption (planned; implemented with the SVT-AV1 content plan) |
| W3 | source | Excluded parameters |

## Known blind spots

The extractor reads text. It understands `New OptionParam|NumParam|BoolParam|StringParam ... With { ... }` declared as properties or inline inside `Add(...)`, with full-line comments removed. Anything else that constructs a parameter is E11, not silently invisible. Parameters that are declared but never added to `Items` count toward totals unless excluded with `OptionHelpKey = "none"`. Run `-CompareFacts` against a fresh application export before a close-out to reconcile.
