# Writing option help

Every option in an encoder dialog gets one stanza in the encoder's file here. The text shows as a tooltip, in the description strip above the command line, and in the details window (F1 or right-click). The grammar and the rules are defined in `Docs/Planning/OPTION-HELP.md`; this page is the short version for authors.

## The stanza

```markdown
## svt-av1.preset
Label: Preset
Summary: One or two sentences. What it changes in the encode, ending with a period.
Used when: Only if the option is ignored in some mode; say which mode uses it.
When to change: The situation, the tradeoff, and a practical first action.
Encoder default: 8
Example: A concrete thing to try, with enough context to reproduce it.
Values:
- 6: A note for a value worth explaining. Not every value needs one.
Related: svt-av1.crf, concept.compression-efficiency
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md
Status: draft
```

Field order is fixed. `Summary` and `Status` are required; `When to change` is required once the stanza is `reviewed`. Limits: Label 60, Summary 200, Used when 200, When to change 400, Encoder default 40, Example 300, value notes 120 characters. Inline markup is backticks for a literal switch or value and `[text](https://...)` for a link; nothing else.

## Stanza ids

The heading is the option's stable id, `<encoder>.<switch without dashes>` for ordinary options (`svt-av1.preset` for `--preset`). Controls that share a switch or have no switch carry an explicit `OptionHelpKey` in the VB declaration; `Check-OptionHelp.ps1` prints the id of every option it cannot find text for, so you never have to derive one by hand.

## Variants and inheritance

A variant encoder's file names its base with `Inherits: <base>` and holds only what differs. An option is looked up namespace-relative along the chain: the variant's own file first, then the base's, then `staxrip.md`, each probed for `<that file's encoder>.<local part>`. So `<variant>.preset` finds `svt-av1.preset` in the base file without the variant repeating it, and the variant overrides an option by writing `## <variant>.preset` in its own file. That stanza wins even as a `draft`, which is how a variant author hides base text that is wrong for the variant until the replacement is reviewed; a variant file never repeats a base id. Ids in another namespace (`staxrip.*`, `concept.*`, `shared.*`) are looked up verbatim in each chain file.

A stanza in an encoder file must match an option of that encoder or of an encoder that inherits from it, so a base file may carry text for a switch only a variant declares. Run the unscoped check after editing a variant file: the base's orphan rule and counters depend on the variant's declarations, and a scoped run reports the counters of the named encoder alone (it does apply the stanza rules to every file in the chain and to the shared files).

## Writing rules

1. The first sentence names the observable effect on picture quality, file size, encoding speed, decoding compatibility, resource use, or workflow.
2. `When to change` names the situation, the tradeoff, and a practical first action.
3. Current value, StaxRip default, and valid range come from the application; put them in prose only when they are stable and version-verified.
4. Use a number when it helps the decision. Never add a number to satisfy the template.
5. State exact ranges plainly. Label performance, time, size, and quality outcomes as measured examples and include enough test context to reproduce them.
6. Define an unfamiliar term inline or link it to a reviewed glossary entry through `Related`.
7. Say "leave it at the default" when that is the honest advice. Avoid "best", "sweet spot", and universal claims unless the evidence supports them.
8. Explain interactions and inactive modes. Use `Used when` to tell the user when an option is ignored.
9. Use original wording and link the evidence. x264 and x265 documentation is GPL and StaxRip is MIT.
10. A stanza becomes `reviewed` only after a human readability review in the real interface and technical verification against the bundled encoder version named in the file header.

## Drafting workflow

Anyone, and any tool, may draft. The maintainer's standing preference: draft the prose with whichever model or writer produces the warmest, clearest friend-to-friend English, at the drafter's judgment. The gate is rule 10, not the tool. On a feature branch, `reviewed` means the technical verification is done and the maintainer's readability review on the real dialog happens before merge; on `master` it means both have happened.

Sources for SVT-AV1: the bundled `Apps\Encoders\SvtAv1EncApp\SvtAv1EncApp.exe --help` and `--version` output, the SVT-AV1 `Docs/Parameters.md` at the tag matching the bundled build, and Patman's release notes for PMod-specific behavior. Where the bundled build and upstream disagree, the bundled build wins and the stanza says so.

## Checking your work

```powershell
pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1
```

The report lists every option without text (`MISSING`), every rule violation with a file and line, and whether each encoder is within its counters. Adding a parameter in VB fails the check until at least a `draft` stanza exists. When a batch of stanzas is done, run with `-AdvanceRatchet` so the counters follow; when every option of an encoder is reviewed, set `Reviewed-Complete: true` by hand.

## Files

| File | Holds |
| --- | --- |
| `<encoder>.md` | Every option of that encoder |
| `<variant>.md` with `Inherits: <base>` | Only the variant's additions and overrides; a `draft` here hides the base text |
| `staxrip.md` | The controls StaxRip adds to every dialog: Decoder, Pipe, Custom, target file name, Chunks, Comp. Check, Aimed Quality |
| `concepts.md` | Glossary entries such as `concept.psnr`, reached only through `Related` |
| `shared.md` | Reusable option prose, reached only through `Use:`; created when a second encoder needs it |
