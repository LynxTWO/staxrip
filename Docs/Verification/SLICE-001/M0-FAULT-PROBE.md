# SLICE-001 M0 Coordinator Fault Probe

Date: 2026-08-15. Repository base: `c26e0fa6`. Status: Pass for design evidence only.

## Selected seam

Use one instance-scoped coordinator with two constructor dependencies:

- `Func(Of ReadinessSnapshot)` for snapshot mapping.
- `Func(Of ReadinessSnapshot, ReadinessResult)` for pure evaluation.

One `TryEvaluate` boundary calls both in order. It converts an unexpected exception from either dependency to the same typed `Unavailable` presentation. The type contains no exception or arbitrary string field. Publication, invalidation, refresh wiring, and rendering stay outside this catch.

The ignored pre-decision probe uses the historical `ReadinessSnapshot` and `ReadinessResult` names. Confirmed D-037 requires production names under the Source project checks feature, such as `ProjectCheckSnapshot` and `ProjectCheckResult`. The delegate call order and failure-boundary evidence are unchanged by that rename.

Constructor-injected `Func` and `Action` dependencies already exist at `Source/UI/Menu.vb:171-185` and `Source/Forms/ProfilesForm.vb:292-311`. This is a code-shape precedent, not production activation evidence.

## Ignored probe

The inspected disposable VB.NET Framework 4.8 x64 probe lives under:

```text
Source/obj/ReadinessTests/M0Probe/
```

`.gitignore:12` excludes the whole `Source/obj` tree. `git status --short` did not list the probe.

Inspected source hashes:

```text
29621D9E2BC3D60FA64D5F84B69619E2E7304151D7E0D79136C9562D449F5A80 Program.vb
705132A6C21EE7CDC886030AB94BAFA20130FD7A447F5022E74CBAA7015C42BF M0Probe.vbproj
```

Command:

```text
"C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe" Source\obj\ReadinessTests\M0Probe\M0Probe.vbproj /nologo /v:minimal /t:Build /p:Configuration=Debug /p:Platform=x64 /p:RestorePackages=false
Source\obj\ReadinessTests\M0Probe\bin\Debug\M0Probe.exe
```

Bounded output:

```text
M0Probe -> Source\obj\ReadinessTests\M0Probe\bin\Debug\M0Probe.exe
PASS mapper=1 evaluator-after-mapper=0 evaluator-fault=1 project-unchanged=true
```

## Branch evidence

| Forced branch | Mapper count | Evaluator count | Presentation | Synthetic project fingerprint |
|---|---:|---:|---|---|
| Mapper throws | 1 | 0 | `Unavailable`, no result | Unchanged |
| Evaluator throws | 1 | 1 | `Unavailable`, no result | Unchanged |

The probe also reflects over the presentation properties and rejects `Exception` or `String` fields. It contains no StaxRip project reference, package, log call, environment trigger, global flag, user switch, network action, filesystem probe, or solution mapping.

## Limits and later evidence

- **verified:** The dependency shape can force mapper and evaluator faults independently.
- **verified:** The probe builds and passes as an ignored x64 .NET Framework 4.8 executable.
- **historical boundary:** The production coordinator did not exist at this M0 probe.
- **current evidence:** `M2-INTEGRATION.md` records source-linked and product-assembly activation of both production dependency branches, payload-free `Unavailable`, and 175 unchanged shallow project fields.
- **remaining unknown:** Loaded-project GUI publication and rendering outcomes remain L4 evidence. No permanent production fault switch is allowed.
