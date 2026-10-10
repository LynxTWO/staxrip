# SLICE-001 Evidence Index

Date: 2026-08-15. Status: M0 and M1 complete; M2 deterministic integration and x64 build evidence passes; M3 production-control evidence passes; M4 paired runtime evidence passes; remaining production accessibility, branch, and human evidence is open.

| Artifact | Purpose | Current state |
|---|---|---|
| `M0-PREFLIGHT.md` | Historical anti-dark-code preflight at `c26e0fa6` | Complete historical snapshot |
| `M0-SYSTEM-MAP.md` | Source-opening architecture and trust-boundary map | Complete M0 map; current implementation evidence is in M2 |
| `M0-AUTHORITY-STOP.md` | Why pure post-open state cannot authorize encoding | Stop resolved by D-037 |
| `M0-CATALOG.md` | Final three-check catalog and mutation-owner map | Approved and implemented |
| `M0-ACTIVATION-LIFECYCLE.md` | Caller, activation, clear-owner, and success-seam design | Complete M0 map; current implementation evidence is in M2 |
| `M0-FAULT-PROBE.md` | Disposable coordinator dependency-shape proof | Complete design evidence; product-assembly evidence is in M2 |
| `M0-UI-AND-VERIFICATION.md` | UI ownership, fixture, timing, and verification design | Design complete; runtime protocol passes in M0-RUNTIME-PLAN; OS presentation remains open |
| `M0-UI-PROBE.md` | Historical strict-copy, navigation, menu, position, and fixed-span model | Limited-font pass; final row height and Hidden-state span superseded by M3 |
| `M0-FIXTURE-MANIFEST.json` | Hash-bound ignored fixture identity and bounded facts | Complete for six fixture artifacts; executed template and runtime values are bound in M0-RUNTIME-PLAN |
| `M0-FIXTURE-RECIPE.ps1` | Complete deterministic fixture recipe | Pinned-toolchain replay pass for all six hashes; arbitrary generator builds are not claimed bit-identical |
| `M0-RUNTIME-PLAN.md` | Clean donor, isolation, timing, handle, and safety protocol | Reviewed v6 paired matrix passes four routes, stale-state, refresh p95, handles, and independent postflight; historical holds retained |
| `M0-PASS-REPORT.md` | M0 findings, D-037 stop, and continuation record | Complete with historical sections labeled |
| `M1-PURE-MODEL.md` | Pure model, policy, coordinator, presentation, and harness evidence | Pass |
| `M2-INTEGRATION.md` | Production mapper, lifecycle, mutation, fault, product-assembly, and x64 build evidence | Deterministic and build pass; paired workflow evidence is in M0-RUNTIME-PLAN |
| `M3-PRESENTATION.md` | Strict presentation contract and production-assembly UI evidence | Production-control probe pass; full GUI, UIA, and human evidence pending |

The pinned-toolchain fixture replay binds the current recipe at 7,484 bytes and SHA-256 `DF5FDCF6DADA54CC68AA4619382DFEDE7DD9B06B5E00B248D05A8791A413E051`. The current tracked manifest is 18,564 bytes and SHA-256 `277FA123F55EB7ED267A22F746205B1F5C51D98F702394A1E54A60FD4C03EC75`.

The accepted ignored runtime aggregate has schema `staxrip.project-check-runtime.paired.v1`, evidence id `paired-20260816T032305Z-4b9b5844b1f4`, and SHA-256 `CBB592D9EB4D215A070F73B349B6E2F51F24BFE2044ACB3CF19BA80A94159F62`. Exact metrics and boundaries are recorded in `M0-RUNTIME-PLAN.md`; raw trial artifacts remain ignored and unpublished.

## Current claim boundary

- D-037 is Confirmed. D-030 and D-034 are Superseded.
- `Selected checks passed` covers only the three selected checks. It does not authorize Add Job or encoding.
- Q-003 and U-004 are Closed by the reviewed v6 paired source-open, stale-state, refresh, timing, handle, and postflight result.
- U-011 remains Open for human value validation.
- Exact `Application.Run`, complete MainForm UI Automation, Narrator, physical keyboard, focus, actual high contrast, physical DPI, and remaining abort and recovery outcomes remain unverified.
- No successful real `ProcessJob` equivalence, packaging, release, or public binary is claimed.

`SLICE-001` is not `Done with evidence`.
