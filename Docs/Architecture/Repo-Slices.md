# Repository Slices and Gates

Use the smallest gate that reaches the behavior changed. Escalate when an edit crosses
an interface, shipping, persistence, or destructive boundary.

| Changed slice | Primary risk | Minimum gate | Escalation |
| --- | --- | --- | --- |
| Markdown and issue forms | inaccurate guidance or invalid YAML | targeted parse/link review plus `git diff --check` | build only when commands or generated docs depend on source |
| Main VB.NET source | project, UI, serialization, command behavior | Debug x64 solution build | Release build and GUI fixture for startup/source paths |
| `Package.vb` or tool updater | wrong executable/asset selection | Debug/Release x64 plus focused reflection/contract probe | portable tree and update sandbox |
| FrameServer C++ | ABI, lifetime, pointer, frame ownership | Debug/Release FrameServer and solution builds | controlled faults, real runtime matrix, soak |
| AutoCrop | crop output and tracked artifact drift | direct Debug/Release x64 AutoCrop builds | packaged host/runtime cases and artifact policy review |
| Solution/project configurations | build graph and output paths | parse/evaluate configurations and all affected x64 builds | portable/runtime gate when architecture changes |
| Settings, projects, jobs | compatibility, concurrency, data loss | focused serialization/state fixture | cross-process/fault-injection harness |
| GUI source opening/filter generation | modal state, tool invocation, script correctness | isolated settings plus one synthetic source | four-media GUI and both frame-server backends |
| Build scripts | local environment and tracked outputs | source-policy scan plus isolated build | prepared portable copy contract |
| Release scripts/exclusions | destructive target or incomplete archive | scratch-only copy/filter/archive simulation | maintainer-controlled publication rehearsal |
| Logging/issue templates | privacy leakage | synthetic log/redaction review | external-tool output corpus |

## Confidence ladder

1. **L0 - static:** diff scope, whitespace, parsing, search, project graph.
2. **L1 - affected compile:** direct project or solution Debug x64.
3. **L2 - semantic boundary:** focused probe, controlled failure, real runtime, GUI fixture.
4. **L3 - release-equivalent:** prepared portable tree, soak, package closure, maintainer approval.

Do not infer an L3 claim from an L1 pass. Conversely, do not force the 17-minute,
approximately 11 GiB full-archive gate onto a documentation-only change.

