# D-053: replacing the `BinaryFormatter` clone helpers

`ObjectHelp.GetCopy(Of T)` and `Theme.ControlsThemeColors.Clone()` deep-copied objects by
round-tripping them through `BinaryFormatter` over a `MemoryStream`. `BinaryFormatter` is
removed from modern .NET, so both now call `DeepCopy.Clone`, a reflection-based copier written
to reproduce the formatter's semantics deliberately.

These are in-memory copies only. **No on-disk format changes**, which is why they went first;
the five on-disk `BinaryFormatter` formats are a separate and harder problem.

| Field | Value |
| --- | --- |
| Decision | D-053, ratified 2026-08-23 |
| Implementation | [`Source/General/DeepCopy.vb`](../../../Source/General/DeepCopy.vb) |
| Call sites switched | `ObjectHelp.GetCopy(Of T)` (90 callers), `ControlsThemeColors.Clone()` |
| Verified | 2026-08-24, Debug/x64 |

## What had to be reproduced

`BinaryFormatter` is not just "something that round-trips". Six of its behaviors are relied on
here, and a copier that drops one produces an object that *looks* copied and behaves wrongly —
no exception, no warning:

1. Every field is copied, including private and read-only ones, up the whole inheritance chain.
2. `<NonSerialized>` fields are skipped and left at their type default. 37 exist in the tree;
   copying them would duplicate handles, caches, or parent links.
3. Reference identity is preserved: an object referenced twice is copied once and referenced
   twice. A tree-walking copier duplicates it and silently destroys aliasing.
4. Cycles terminate.
5. No constructor runs — `FormatterServices.GetUninitializedObject`.
6. Serialization callbacks fire, in the formatter's order.

## How to verify

Both scripts **must** run under Windows PowerShell 5.1. `BinaryFormatter` — the reference
implementation being compared against — throws `PlatformNotSupportedException` under pwsh 7,
which is the very reason this work exists.

```powershell
# build first
MSBuild.exe Source\StaxRip.vbproj /p:Configuration=Debug /p:Platform=x64

powershell.exe -NoProfile -ExecutionPolicy Bypass -File Docs\Verification\D-053\clone-differential.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Docs\Verification\D-053\mutation-check.ps1
```

`clone-differential.ps1` clones the same graphs through `BinaryFormatter` and through the
shipping helpers and compares them structurally — **including aliasing**, since equal field
values with different aliasing is a failure a value-only comparison cannot see. It sets
`Folder.StartupValue` to a scratch directory before touching anything; pointing it at a real
installation pops StaxRip's modal settings dialog and hangs (P-016).

`mutation-check.ps1` breaks `DeepCopy.vb` three ways, rebuilds each time, and requires the
differential to fail on each. It restores the file in a `finally` block.

## Result, 2026-08-24

`clone-differential.ps1`: **54 checks, all green, 0 differences against `BinaryFormatter`.**

| Area | Covered |
| --- | --- |
| All six behaviors at once | private/read-only fields, `<NonSerialized>`, aliasing across fields, arrays and dictionaries, cycles, no constructor, callback order |
| Structures | nested structs, arrays of structs, `Dictionary`'s internal `Entry[]` |
| Real StaxRip graphs | `PrimitiveStore`, `Project`, `ApplicationSettings`, plus forced aliasing inside `Project` |
| Callback-bearing tree types | `CustomCultureInfo`, `Language`, `MkvMuxer` |
| Second clone site | `ControlsThemeColors.Clone()` |

`mutation-check.ps1`: **every mutation caught.**

| Behavior removed | Caught as |
| --- | --- |
| `<NonSerialized>` honored | 3 checks: `NonSerialized left at default`, `no constructor run`, `OnDeserializing invoked (base)` |
| Callbacks invoked | 4 checks, including `OnDeserialized ran AFTER fields` |
| Struct-safe population | the harness wedges outright and is killed at 180s — a copied `Dictionary` whose `next` chain loops never returns from its first lookup |

The third row is why `mutation-check.ps1` bounds each run: a copier broken this way hangs its
caller rather than reporting, so an unbounded harness would wait forever on its own success.

## Three things worth knowing before touching this

**Callback evidence has to live in `<NonSerialized>` fields.** `OnDeserializing` runs *before*
the fields are populated, so a serialized flag it sets is immediately overwritten and proves
nothing. This is not a quirk of the harness — it is exactly how real code uses the callback, to
rebuild transient state. The harness captures a field's value as each callback runs, which pins
down the order rather than merely that the callback ran.

**VB cannot fill in a boxed structure field by field.** Passing an `Object` variable that holds
a value type makes the compiler emit `RuntimeHelpers.GetObjectValue`, so every
`FieldInfo.SetValue` lands on a throwaway copy and the structure comes back at its type
default. This is silent and vicious: it turned a copied `Dictionary`'s internal `entries` array
into all-zero entries whose `next` chain pointed at itself, so the first lookup on the copy
never returned. `DeepCopy` populates through `FormatterServices.PopulateObjectMembers` and takes
the instance it returns. This bug was found by this harness, during this work.

**Comparing two clones is not the same as comparing a clone to the original.** Some objects are
process-global caches that `BinaryFormatter` hands out by reference too — the pattern arrays
behind `DateTimeFormatInfo` are the ones this tree hits — so two honest clones legitimately
share them. Rather than relaxing the rule, `GraphCompare.Diff` takes the original as a third
argument and accepts sharing only where the formatter shared with the original as well.
Anything the formatter copied must still be copied. `CultureInfo` also builds parts of itself
lazily on first read, so the harness warms it before taking either clone; otherwise the
comparison measures which clone was taken first rather than the copier.

## Deliberate departures from `BinaryFormatter`

- **Delegate fields become `Nothing`** rather than raising. A clone wants the data, not the
  event wiring.
- **Reflection objects (`Type`, `MemberInfo`, `Assembly`) are shared**, which is what the
  formatter's identity handling did anyway.
- **A non-serializable *class* still raises `SerializationException`**, keeping the old failure
  loud. The check stops at classes on purpose: framework collections hide non-serializable
  internal structs — `Dictionary`'s `Entry`, `Hashtable`'s `bucket` — that the formatter never
  met because those types serialize themselves through `ISerializable`.
- **A callback declared on a structure cannot mutate that structure**, for the VB boxing reason
  above. Every callback in this tree is declared on a class.
