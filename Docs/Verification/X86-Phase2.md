# X64 Runtime Cleanup Phase 2

Phase 2 is commit `ed32aae0` on branch `agent/remove-x86-runtime-branches` in draft
pull request #1994. It is stacked on Phase 1 commit `e10d99cf` / draft pull request
#1992 and must not be merged independently while x86 project configurations remain
available.

## Change boundary

The commit changes exactly four files:

- `Source/Forms/MainForm.vb` removes the unreachable `(32 bit)` title suffix.
- `Source/General/GlobalClass.vb` removes the 32-bit process requirement branch and
  stops recognizing the retired `bin-x86` development output.
- `Source/General/Package.vb` stops selecting alternate internal filenames by process
  bitness and removes eight unused `Filename32` initializers.
- `Source/General/ToolUpdate.vb` always excludes x86 update assets.

The public `Package.Filename32` property is preserved for binary/source compatibility
and marked obsolete with the message `StaxRip supports x64 only. Use Filename instead.`
Its storage and accessors remain functional; internal runtime selection uses only
`Filename`.

## Checks

- Debug x64 solution build: pass, zero warnings/errors.
- Release x64 solution build: pass. On the isolated Phase 2 branch, only the ten known
  upstream FrameServer conversion warnings remain.
- Integrated Debug and Release x64 builds with the warning/lifetime fixes: pass, zero
  warnings/errors.
- IL inspection: `Filename32` accessors remain; `Filename` contains no
  `Environment.Is64BitProcess` branch.
- Managed compatibility probe: the obsolete attribute is present, legacy storage
  remains readable/writable, and x86 tool assets are rejected.
- Portable GUI, runtime, soak, and packaging gates: pass on the integrated candidate;
  see `Portable-X64-Validation.md`.

## Dependency on Phase 1

Phase 1 removes the five x86/Win32 solution and project configurations and corrects
direct-project defaults. Phase 2 makes runtime behavior consistently x64-only. If
Phase 2 landed first, an existing x86 configuration could still build while selecting
x64 package/runtime behavior, so the review and merge order is Phase 1 then Phase 2.

## Remaining compatibility boundary

An external extension can still compile against `Filename32`; it receives an obsolete
warning and retains its stored value. No internal tracked call site reads it. Removing
the public property entirely would be a separate breaking API decision and is not part
of this phase.
