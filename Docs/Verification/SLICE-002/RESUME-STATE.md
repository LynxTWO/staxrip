# SLICE-002 Resume State

Date: 2026-08-16. Base: `940eaba1`. Written by an anti-dark-code pass `00` preflight.

The previous session stopped abruptly when its model provider hit a usage limit. It stopped
in the middle of a negative mutation challenge against `eng/Restore.ps1`. This note records
the exact observed state so the next session does not misread it. No gate was executed to
produce this note. Every line below comes from reading the working tree.

## Interrupted state

### 1. The NuGet restore tree is incomplete on purpose

`CrossPlatform/artifacts/nuget/microsoft.netcore.app.host.linux-x64/10.0.11/` is absent.
The directory was moved intact to
`CrossPlatform/artifacts/quarantine-nuget-mutation-20260816-v3/microsoft.netcore.app.host.linux-x64/10.0.11/`.

The quarantined copy holds the **mutated** nuspec from the challenge, not clean bytes.
Moving it back would reintroduce tampered content. Recovery requires a restore from the
approved signed source, which is a network action and needs explicit approval.

Confidence: verified. The parent `nuget/` directory lists three packages and the `10.0.11`
leaf is missing; the quarantine leaf contains the full package including `.signature.p7s`
and the nuspec.

### 2. `failures/port-restore.txt` is an intended negative result

The packet records `exit=1` with
`Package Microsoft.NETCore.App.Host.linux-x64/10.0.11 archive and extracted lengths differ.`
at head `940eaba1`. That is the mutation challenge succeeding. It is not a regression and
not a source defect. Clear it only after a clean restore passes.

Confidence: verified. Packet contents read directly.

### 3. No stuck locks

`CrossPlatform/artifacts/evidence/.evidence-writer.lock` is absent.
`CrossPlatform/artifacts/tmp/.port-verify-running` is absent.
The interrupted session released both. No lease recovery is needed.

Confidence: verified.

### 4. The final evidence audit has never produced its pair

`CrossPlatform/artifacts/evidence/` holds 15 records. Neither `evidence-audit.json` nor
`evidence-audit.json.sha256` exists. The `port-evidence` correspondence audit has not
passed for this checkpoint. This is the gate that stands between the current state and
closing the independent NO-GO recorded in `README.md`.

Confidence: verified by directory listing.

## Remaining work, in order

1. Recover the quarantined package by clean restore from the approved signed source.
   Requires approval for a network restore.
2. Rerun the committed-source gates through `eng/`.
3. Produce and pass the `port-evidence` correspondence audit.
4. Obtain the independent re-review that the NO-GO requires.
5. Resolve or keep P-007 blocked. The independent Ubuntu peer answers ping but refuses SSH,
   so WSL is still not second-host evidence.

## Scope reminder

Nothing here changes `Source/`, the WinForms application, or the protected build and release
scripts. The acceptance table in `README.md` holds target values, not committed-source
results. No row is a final claim until steps 2 and 3 pass.
