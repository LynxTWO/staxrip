<#
D-053 differential harness: proves StaxRip's deep-clone helpers reproduce BinaryFormatter's
semantics exactly, so the BinaryFormatter round-trip can be removed from Source/.

MUST run under Windows PowerShell 5.1 (.NET Framework 4.8):

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File Docs\Verification\D-053\clone-differential.ps1

BinaryFormatter -- the reference implementation this compares against -- is removed from
modern .NET and throws PlatformNotSupportedException under pwsh 7. That removal is the
reason D-053 exists, and it means reference and candidate can only be compared on Framework.

The candidate is the shipping code: StaxRip.ObjectHelp.GetCopy(Of T) and
StaxRip.Theme.ControlsThemeColors.Clone(), loaded out of the built assembly. The reference
is a BinaryFormatter round-trip performed here in the harness. Zero differences is the bar.

A differential reporting zero proves nothing until the comparator has been shown able to
report non-zero, so the run also feeds the comparator deliberately broken copies and
requires it to catch each one.
#>
[CmdletBinding()]
param(
    [string] $Exe,
    [string] $Scratch
)

$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSEdition -eq 'Core') {
    Write-Host 'FAIL: this harness requires Windows PowerShell 5.1; BinaryFormatter is unavailable on .NET Core/5+.' -ForegroundColor Red
    exit 2
}

if (-not $Exe) { $Exe = Join-Path $PSScriptRoot '..\..\..\Source\bin\StaxRip.exe' }
$Exe = [IO.Path]::GetFullPath($Exe)
if (-not (Test-Path $Exe)) {
    Write-Host "FAIL: built assembly not found at $Exe -- build Source\StaxRip.vbproj first." -ForegroundColor Red
    exit 2
}
$dir = Split-Path $Exe

# P-016: StaxRip resolves its asset tree from the HOST process's directory, so Folder.Startup
# must be redirected to an empty scratch directory before anything touches it. Pointing it at
# a real installation pops the modal settings dialog and hangs the run.
if (-not $Scratch) { $Scratch = Join-Path $env:TEMP 'd053-fakestartup' }
if (-not (Test-Path $Scratch)) { New-Item -ItemType Directory -Path $Scratch | Out-Null }
if (-not $Scratch.EndsWith('\')) { $Scratch += '\' }

[System.AppDomain]::CurrentDomain.add_AssemblyResolve({
    param($s, $e)
    $n = ($e.Name -split ',')[0]
    $p = Join-Path $dir "$n.dll"
    if (Test-Path $p) { [Reflection.Assembly]::LoadFrom($p) } else { $null }
})

$asm = [Reflection.Assembly]::LoadFrom($Exe)
$bindStatic = [Reflection.BindingFlags]'Public,NonPublic,Static'
$asm.GetType('StaxRip.Folder').GetField('StartupValue', $bindStatic).SetValue($null, $Scratch)

Add-Type -ReferencedAssemblies 'System.Runtime.Serialization' -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Formatters.Binary;

public sealed class RefEq : IEqualityComparer<object> {
    public static readonly RefEq I = new RefEq();
    public new bool Equals(object a, object b) { return ReferenceEquals(a, b); }
    public int GetHashCode(object o) { return System.Runtime.CompilerServices.RuntimeHelpers.GetHashCode(o); }
}

// The reference implementation. This is what Source/ used to do, kept here so the harness
// still has something to compare against once Source/ no longer does it.
public static class Reference {
    public static object Clone(object o) {
        using (var ms = new MemoryStream()) {
            var bf = new BinaryFormatter();
            bf.Serialize(ms, o);
            ms.Position = 0;
            return bf.Deserialize(ms);
        }
    }
}

// A graph carrying every behavior D-053 names, all at once.
[Serializable] public class Leaf { public int N; }

// Structures are their own hazard. A copier that fills one in through a boxed reference
// silently produces the type default, and nothing raises: the damage surfaces later as a
// Dictionary whose internal entries are all zero, whose bucket chain points into them, and
// whose first lookup never returns. These cover the shape directly and by proxy.
[Serializable] public struct Inner { public int X; public string K; }
[Serializable] public struct Outer { public Inner Nested; public int[] Values; }

[Serializable] public class StructHolder {
    public Inner One;
    public Outer Deep;
    public Inner[] Many;
    public Dictionary<string, int> Counts;      // internal Entry[] is an array of structures
    public int Plain;
    public static StructHolder Build() {
        var h = new StructHolder { Plain = 99 };
        h.One = new Inner { X = 1, K = "one" };
        h.Deep = new Outer { Nested = new Inner { X = 2, K = "two" }, Values = new[] { 5, 6 } };
        h.Many = new Inner[] { new Inner { X = 10, K = "ten" }, new Inner { X = 20, K = "twenty" } };
        h.Counts = new Dictionary<string, int>();
        for (int i = 0; i < 12; i++) h.Counts["k" + i] = i;   // enough to force bucket chains
        return h;
    }
}

[Serializable] public class NodeBase {
    private string _privateOnBase;                      // private, declared on a base class
    public readonly string ReadOnlyField;               // read-only
    public string BaseTag;                              // ordinary serialized field

    // Callback evidence must live in [NonSerialized] fields. A serialized flag set by
    // OnDeserializing is immediately clobbered when the fields are populated, so it proves
    // nothing -- which is exactly how real code uses these callbacks: to rebuild transient
    // state. Capturing BaseTag as each callback runs pins down the ORDER: null before the
    // fields land, "tag" after.
    [NonSerialized] public bool BaseDeserializingRan;
    [NonSerialized] public string BaseTagAtDeserializing;
    [NonSerialized] public bool BaseDeserializedRan;
    [NonSerialized] public string BaseTagAtDeserialized;

    public NodeBase(string p, string r) { _privateOnBase = p; ReadOnlyField = r; }
    public string PrivateOnBase { get { return _privateOnBase; } }
    [OnDeserializing] void BeforeLoad(StreamingContext c) { BaseDeserializingRan = true; BaseTagAtDeserializing = BaseTag; }
    [OnDeserialized] void AfterLoad(StreamingContext c) { BaseDeserializedRan = true; BaseTagAtDeserialized = BaseTag; }
}

[Serializable] public class Node : NodeBase, IDeserializationCallback {
    public Leaf A;                              // aliased with B
    public Leaf B;
    public Node Self;                           // cycle
    public Leaf[] Leaves;                       // array whose elements alias A
    public string Name;
    public int[] Numbers;
    public Dictionary<string, Leaf> Map;        // a type with its own deserialization callback
    [NonSerialized] public string Transient;    // must NOT be copied
    [NonSerialized] public bool DerivedDeserializedRan;
    [NonSerialized] public bool CtorRan;
    [NonSerialized] public bool InterfaceCallbackRan;
    [NonSerialized] public bool SelfWiredAtInterfaceCallback;
    public Node(string p, string r) : base(p, r) { CtorRan = true; }
    [OnDeserialized] void AfterLoad2(StreamingContext c) { DerivedDeserializedRan = true; }
    // IDeserializationCallback fires only once the WHOLE graph is built, which is why it
    // can see Self already wired up.
    public void OnDeserialization(object sender) {
        InterfaceCallbackRan = true;
        SelfWiredAtInterfaceCallback = ReferenceEquals(Self, this);
    }

    // Built here rather than in PowerShell: PowerShell wraps its own object construction in
    // PSObject, and MethodInfo.Invoke does not unwrap array elements, so the reflection call
    // into ObjectHelp.GetCopy would receive a PSObject instead of a Node.
    public static Node Build(string name) {
        var leaf = new Leaf { N = 7 };
        var n = new Node("private-value", "readonly-value");
        n.A = leaf;
        n.B = leaf;                                     // aliased with A
        n.Self = n;                                     // cycle
        n.Leaves = new Leaf[] { leaf, leaf };           // array elements alias A too
        n.Name = name;
        n.BaseTag = "tag";
        n.Numbers = new int[] { 1, 2, 3 };
        n.Map = new Dictionary<string, Leaf>();
        n.Map["shared"] = leaf;                         // dictionary value aliases A too
        n.Transient = "must not survive";
        return n;
    }
}

// Correct field values, but no identity map: aliasing is destroyed and cycles would recurse
// forever, so it is depth-capped to stay runnable. Exists solely to prove the comparator
// can report non-zero.
public static class NaiveCopier {
    public static object Copy(object o, int depth) {
        if (o == null || depth > 6) return null;
        Type t = o.GetType();
        if (t.IsPrimitive || t.IsEnum || t == typeof(string)) return o;
        if (t.IsArray) {
            var s = (Array)o; var d = Array.CreateInstance(t.GetElementType(), s.Length);
            for (int i = 0; i < s.Length; i++) d.SetValue(Copy(s.GetValue(i), depth + 1), i);
            return d;
        }
        object c = FormatterServices.GetUninitializedObject(t);
        for (Type cur = t; cur != null; cur = cur.BaseType)
            foreach (var f in cur.GetFields(BindingFlags.Instance | BindingFlags.Public
                                          | BindingFlags.NonPublic | BindingFlags.DeclaredOnly)) {
                if (f.IsNotSerialized) continue;
                f.SetValue(c, Copy(f.GetValue(o), depth + 1));
            }
        return c;
    }
}

// Structural comparison that also checks ALIASING, the half a value-only comparison misses:
// if two fields in the original point at one object they must point at one object in the
// copy, and it must not be the original's.
public static class GraphCompare {
    // Strict form: any object the two graphs have in common is reported.
    public static List<string> Diff(object a, object b) { return Diff(a, b, null); }

    // Calibrated form, for comparing two independent clones of the same original. Some objects
    // are process-global caches that BinaryFormatter hands out by reference as well -- the
    // pattern arrays behind DateTimeFormatInfo are the ones this tree hits -- so two honest
    // clones legitimately share them. Rather than relaxing the rule and losing its teeth, pass
    // the original: sharing is accepted only where BinaryFormatter shared with the original
    // too, and anything the formatter copied must still be copied here.
    public static List<string> Diff(object a, object b, object original) {
        var issues = new List<string>();
        var seen = new Dictionary<object, object>(RefEq.I);
        HashSet<object> sharedByReference = null;
        if (original != null) {
            sharedByReference = new HashSet<object>(RefEq.I);
            Collect(original, sharedByReference, 0);
        }
        Walk(a, b, "root", seen, issues, 0, sharedByReference);
        return issues;
    }

    static bool Atomic(Type t) {
        return t.IsPrimitive || t.IsEnum || t == typeof(string) || t == typeof(decimal)
            || t == typeof(DateTime) || t == typeof(TimeSpan) || t == typeof(Guid);
    }

    // Every reference-typed object reachable from the original, by identity.
    static void Collect(object o, HashSet<object> into, int depth) {
        if (o == null || depth > 40) return;
        Type t = o.GetType();
        if (Atomic(t)) return;
        if (!t.IsValueType && !into.Add(o)) return;
        if (t.IsArray) {
            var arr = (Array)o;
            for (int i = 0; i < arr.Length; i++) Collect(arr.GetValue(i), into, depth + 1);
            return;
        }
        if (typeof(Delegate).IsAssignableFrom(t)) return;
        for (Type cur = t; cur != null; cur = cur.BaseType) {
            foreach (var f in cur.GetFields(BindingFlags.Instance | BindingFlags.Public
                                          | BindingFlags.NonPublic | BindingFlags.DeclaredOnly)) {
                if (f.IsNotSerialized) continue;
                Collect(f.GetValue(o), into, depth + 1);
            }
        }
    }

    static void Walk(object a, object b, string path, Dictionary<object, object> seen, List<string> issues, int depth, HashSet<object> sharedByReference) {
        if (issues.Count > 40 || depth > 40) return;
        if (a == null && b == null) return;
        if (a == null || b == null) { issues.Add(path + ": null mismatch"); return; }
        Type t = a.GetType();
        if (t != b.GetType()) { issues.Add(path + ": type " + t.Name + " vs " + b.GetType().Name); return; }
        if (Atomic(t)) {
            if (!a.Equals(b)) issues.Add(path + ": value " + a + " vs " + b);
            return;
        }
        if (!t.IsValueType) {
            if (ReferenceEquals(a, b)) {
                if (sharedByReference == null)
                    issues.Add(path + ": SHARED reference with original (not copied)");
                else if (!sharedByReference.Contains(a))
                    issues.Add(path + ": SHARED between the two clones, but BinaryFormatter copied it");
                return;
            }
            object prior;
            if (seen.TryGetValue(a, out prior)) {
                if (!ReferenceEquals(prior, b)) issues.Add(path + ": ALIASING LOST (original shares, copy does not)");
                return;
            }
            seen[a] = b;
        }
        if (t.IsArray) {
            var x = (Array)a; var y = (Array)b;
            if (x.Length != y.Length) { issues.Add(path + ": array length " + x.Length + " vs " + y.Length); return; }
            for (int i = 0; i < x.Length; i++) Walk(x.GetValue(i), y.GetValue(i), path + "[" + i + "]", seen, issues, depth + 1, sharedByReference);
            return;
        }
        if (typeof(Delegate).IsAssignableFrom(t)) return;
        for (Type cur = t; cur != null; cur = cur.BaseType) {
            foreach (var f in cur.GetFields(BindingFlags.Instance | BindingFlags.Public
                                          | BindingFlags.NonPublic | BindingFlags.DeclaredOnly)) {
                if (f.IsNotSerialized) continue;
                Walk(f.GetValue(a), f.GetValue(b), path + "." + f.Name, seen, issues, depth + 1, sharedByReference);
            }
        }
    }
}
'@

$script:Failures = New-Object 'System.Collections.Generic.List[string]'

function Assert-True($label, $condition, $detail) {
    if ($condition) {
        Write-Host ("  PASS  {0}" -f $label)
    } else {
        Write-Host ("  FAIL  {0}  {1}" -f $label, $detail) -ForegroundColor Red
        $script:Failures.Add($label)
    }
}

function Assert-NoDiff($label, $issues) {
    if ($issues.Count -eq 0) {
        Write-Host ("  PASS  {0}: 0 difference(s)" -f $label)
    } else {
        Write-Host ("  FAIL  {0}: {1} difference(s)" -f $label, $issues.Count) -ForegroundColor Red
        $issues | Select-Object -First 8 | ForEach-Object { Write-Host "          $_" -ForegroundColor Red }
        $script:Failures.Add($label)
    }
}

# --- the candidate under test: the shipping clone helpers -------------------------------
$getCopy = $asm.GetType('StaxRip.ObjectHelp').GetMethod('GetCopy', $bindStatic)
if (-not $getCopy) { throw 'StaxRip.ObjectHelp.GetCopy not found in the built assembly.' }

# PowerShell hands function return values back wrapped in PSObject, and MethodInfo.Invoke
# does not unwrap array elements the way direct method binding does. Strip the wrapper so
# the reflection call sees the real instance.
function Unwrap($o) {
    if ($o -is [System.Management.Automation.PSObject]) { return $o.BaseObject }
    return $o
}

function Invoke-Candidate($obj) {
    $real = Unwrap $obj
    return $getCopy.MakeGenericMethod($real.GetType()).Invoke($null, @($real))
}

Write-Host ''
Write-Host '=== candidate identity ==='
Write-Host ("  assembly : {0}" -f $Exe)
Write-Host ("  built    : {0}" -f (Get-Item $Exe).LastWriteTime)
Write-Host ("  ObjectHelp declares : {0}" -f (
    ($asm.GetType('StaxRip.ObjectHelp').GetMethods($bindStatic) | ForEach-Object { $_.Name }) -join ', '))

# --- 1. the purpose-built graph, every behavior at once ---------------------------------
Write-Host ''
Write-Host '=== behaviors on a graph carrying all six at once ==='

$orig = [Node]::Build('root')
$copy = Invoke-Candidate $orig

Assert-True 'distinct object'                    (-not [object]::ReferenceEquals($orig, $copy)) ''
Assert-True 'public field values copied'         ($copy.Name -eq 'root' -and $copy.A.N -eq 7 -and $copy.Numbers[2] -eq 3) "Name=$($copy.Name)"
Assert-True 'private field on base copied'       ($copy.PrivateOnBase -eq 'private-value') "got '$($copy.PrivateOnBase)'"
Assert-True 'read-only field copied'             ($copy.ReadOnlyField -eq 'readonly-value') "got '$($copy.ReadOnlyField)'"
Assert-True 'NonSerialized left at default'      ($null -eq $copy.Transient) "got '$($copy.Transient)'"
Assert-True 'aliasing preserved (A is B)'        ([object]::ReferenceEquals($copy.A, $copy.B)) ''
Assert-True 'aliased target is the COPY'         (-not [object]::ReferenceEquals($copy.A, $orig.A)) ''
Assert-True 'aliasing spans arrays'              ([object]::ReferenceEquals($copy.Leaves[0], $copy.A) -and [object]::ReferenceEquals($copy.Leaves[1], $copy.A)) ''
Assert-True 'aliasing spans dictionaries'        ([object]::ReferenceEquals($copy.Map['shared'], $copy.A)) ''
Assert-True 'cycle points at the copy'           ([object]::ReferenceEquals($copy.Self, $copy)) ''
Assert-True 'no constructor run'                 (-not $copy.CtorRan) 'constructor executed on the clone'
Assert-True 'OnDeserializing invoked (base)'     ($copy.BaseDeserializingRan) ''
Assert-True 'OnDeserializing ran BEFORE fields'  ($null -eq $copy.BaseTagAtDeserializing) "saw BaseTag='$($copy.BaseTagAtDeserializing)'"
Assert-True 'OnDeserialized invoked (base)'      ($copy.BaseDeserializedRan) ''
Assert-True 'OnDeserialized ran AFTER fields'    ($copy.BaseTagAtDeserialized -eq 'tag') "saw BaseTag='$($copy.BaseTagAtDeserialized)'"
Assert-True 'OnDeserialized invoked (derived)'   ($copy.DerivedDeserializedRan) ''
Assert-True 'IDeserializationCallback invoked'   ($copy.InterfaceCallbackRan) ''
Assert-True 'IDeserializationCallback sees a fully wired graph' ($copy.SelfWiredAtInterfaceCallback) ''

# --- 1b. structures, which a boxed-reference copier silently zeroes ---------------------
Write-Host ''
Write-Host '=== structures ==='
$structOrig = [StructHolder]::Build()
$structCopy = Invoke-Candidate $structOrig

# Plain field reads first. These cannot hang however broken the copy is, so a wrecked
# Dictionary is reported here rather than wedging the run on the lookup below.
Assert-True 'reference field still copied'       ($structCopy.Plain -eq 99) "got $($structCopy.Plain)"
Assert-True 'structure field copied'             ($structCopy.One.X -eq 1 -and $structCopy.One.K -eq 'one') "X=$($structCopy.One.X) K=$($structCopy.One.K)"
Assert-True 'structure nested in structure'      ($structCopy.Deep.Nested.X -eq 2 -and $structCopy.Deep.Nested.K -eq 'two') "X=$($structCopy.Deep.Nested.X)"
Assert-True 'array inside a structure'           ($structCopy.Deep.Values.Length -eq 2 -and $structCopy.Deep.Values[1] -eq 6) ''
Assert-True 'array OF structures'                ($structCopy.Many[0].X -eq 10 -and $structCopy.Many[1].K -eq 'twenty') "[0].X=$($structCopy.Many[0].X)"

$countsField = [StructHolder].GetField('Counts')
$counts = $countsField.GetValue($structCopy)
$entries = $counts.GetType().GetField('entries', [Reflection.BindingFlags]'NonPublic,Instance').GetValue($counts)
$entryKey = $entries.GetType().GetElementType().GetField('key', [Reflection.BindingFlags]'Public,NonPublic,Instance')
$populated = @($entries | Where-Object { $null -ne $entryKey.GetValue($_) }).Count
Assert-True 'Dictionary internal entries survived' ($populated -eq 12) "$populated of 12 entries carry a key"

if ($populated -eq 12) {
    Assert-True 'lookup into the copied Dictionary works' `
        ($counts.ContainsKey('k7') -and $counts['k7'] -eq 7) "ContainsKey=$($counts.ContainsKey('k7'))"
} else {
    Write-Host '  SKIP  lookup into the copied Dictionary -- its entries are wrecked and the probe would not terminate' -ForegroundColor Yellow
}

Assert-NoDiff 'StructHolder: candidate vs BinaryFormatter' ([GraphCompare]::Diff([Reference]::Clone($structOrig), $structCopy, $structOrig))

# --- 2. comparator falsification: it must be able to report non-zero --------------------
Write-Host ''
Write-Host '=== comparator falsification (each must report a difference) ==='

$selfIssues = [GraphCompare]::Diff($orig, $orig)
Assert-True 'same object twice -> SHARED reference' `
    ($selfIssues.Count -gt 0 -and ($selfIssues -join '|') -match 'SHARED') `
    ("got {0} issue(s): {1}" -f $selfIssues.Count, ($selfIssues | Select-Object -First 1))

$naive = [NaiveCopier]::Copy($orig, 0)
$naiveIssues = [GraphCompare]::Diff($orig, $naive)
Assert-True 'aliasing-losing copier -> ALIASING LOST' `
    ($naiveIssues.Count -gt 0 -and ($naiveIssues -join '|') -match 'ALIASING LOST') `
    ("got {0} issue(s): {1}" -f $naiveIssues.Count, ($naiveIssues | Select-Object -First 1))

$mutated = [Node]::Build('not-root')
$mutatedIssues = [GraphCompare]::Diff($orig, (Invoke-Candidate $mutated))
Assert-True 'differing field value -> reported' `
    (($mutatedIssues -join '|') -match 'root vs not-root') `
    ("got {0} issue(s): {1}" -f $mutatedIssues.Count, ($mutatedIssues | Select-Object -First 1))

# The calibrated mode is a weaker rule, so it needs its own falsification: handed the same
# clone twice it must still object, because that object is not one the formatter shared.
$reference = [Reference]::Clone($orig)
$calibratedSelf = [GraphCompare]::Diff($reference, $reference, $orig)
Assert-True 'calibrated mode still catches an uncopied object' `
    ($calibratedSelf.Count -gt 0 -and ($calibratedSelf -join '|') -match 'BinaryFormatter copied it') `
    ("got {0} issue(s): {1}" -f $calibratedSelf.Count, ($calibratedSelf | Select-Object -First 1))

# --- 3. differential against BinaryFormatter over the purpose-built graph ---------------
Write-Host ''
Write-Host '=== differential vs BinaryFormatter ==='
Assert-NoDiff 'Node (all six behaviors)' ([GraphCompare]::Diff($reference, $copy, $orig))

# --- 4. differential over the real StaxRip graphs the call sites use --------------------
Write-Host ''
Write-Host '=== differential over real StaxRip graphs ==='
foreach ($tn in @('StaxRip.PrimitiveStore', 'StaxRip.Project', 'StaxRip.ApplicationSettings')) {
    $t = $asm.GetType($tn)
    if (-not $t) {
        Write-Host ("  FAIL  {0}: type not found" -f $tn) -ForegroundColor Red
        $script:Failures.Add($tn)
        continue
    }
    $o = [Activator]::CreateInstance($t)
    $refClone = [Reference]::Clone($o)
    $candClone = Invoke-Candidate $o
    Assert-True ("{0}: candidate is a distinct object" -f $tn) (-not [object]::ReferenceEquals($o, $candClone)) ''
    Assert-True ("{0}: candidate has the right type" -f $tn) ($candClone.GetType().FullName -eq $t.FullName) $candClone.GetType().FullName
    Assert-NoDiff ("{0}: candidate vs BinaryFormatter" -f $tn) ([GraphCompare]::Diff($refClone, $candClone, $o))
}

# Aliasing inside a real graph, not just the synthetic one: point two Project fields of the
# same type at one object and require the copy to keep them pointing at one object.
Write-Host ''
Write-Host '=== aliasing inside a real StaxRip graph ==='
$bindInst = [Reflection.BindingFlags]'Public,NonPublic,Instance'
$projT = $asm.GetType('StaxRip.Project')
$proj = [Activator]::CreateInstance($projT)
$pairs = $projT.GetFields($bindInst) |
    Where-Object { -not $_.IsNotSerialized -and -not $_.FieldType.IsValueType -and $_.FieldType -ne [string] -and $_.FieldType.IsSerializable -and -not $_.FieldType.IsArray -and $_.FieldType.GetConstructor([Type]::EmptyTypes) } |
    Group-Object { $_.FieldType.FullName } |
    Where-Object { $_.Count -ge 2 } |
    Select-Object -First 1
if ($pairs) {
    $twoFields = @($pairs.Group | Select-Object -First 2)
    $shared = [Activator]::CreateInstance($twoFields[0].FieldType)
    $twoFields[0].SetValue($proj, $shared)
    $twoFields[1].SetValue($proj, $shared)
    $pc = Invoke-Candidate $proj
    $a = $twoFields[0].GetValue($pc)
    $b = $twoFields[1].GetValue($pc)
    Assert-True ("Project: aliasing preserved across {0}/{1} ({2})" -f $twoFields[0].Name, $twoFields[1].Name, $twoFields[0].FieldType.Name) `
        ([object]::ReferenceEquals($a, $b) -and -not [object]::ReferenceEquals($a, $shared)) ''
    Assert-NoDiff 'Project (aliased): candidate vs BinaryFormatter' ([GraphCompare]::Diff([Reference]::Clone($proj), $pc, $proj))
} else {
    Write-Host '  SKIP  no two same-typed serializable Project fields to alias'
}

# --- 4b. the two tree types that actually carry serialization callbacks -----------------
# CustomCultureInfo rebuilds CultureInfo's private internals in IDeserializationCallback, and
# Muxer normalises a field in OnDeserialized. If the copier skipped callbacks these are what
# would come back subtly wrong, so they are checked against BinaryFormatter by name.
Write-Host ''
Write-Host '=== StaxRip types with serialization callbacks ==='

# CultureInfo builds compareInfo/textInfo/dateTimeInfo lazily, on first read. Whichever clone
# is taken first therefore warms the original and the second one sees different state, so an
# unwarmed comparison measures the order the clones were taken in rather than the copier.
# Touching them up front fixes the source state before either clone exists.
function Warm-Culture($culture) {
    if (-not $culture) { return }
    $null = $culture.Name
    $null = $culture.DisplayName
    $null = $culture.EnglishName
    $null = $culture.NativeName
    $null = $culture.CompareInfo.Name
    $null = $culture.TextInfo.ToUpper('a')
    $null = $culture.DateTimeFormat.ShortDatePattern
    $null = $culture.NumberFormat.NumberDecimalSeparator
}

$cciT = $asm.GetType('StaxRip.CustomCultureInfo')
if (-not $cciT) {
    Write-Host '  FAIL  CustomCultureInfo type not found' -ForegroundColor Red
    $script:Failures.Add('CustomCultureInfo type')
} else {
    $cci = [Activator]::CreateInstance($cciT, @('cmn-Hans-CN', 'cmn-Hans-CN', 'Chinese (Mandarin, Simplified, China)', 'zh', 'cmn'))
    Warm-Culture $cci
    $cciRef = [Reference]::Clone($cci)
    $cciCopy = Invoke-Candidate $cci
    Assert-True 'CustomCultureInfo: distinct object' (-not [object]::ReferenceEquals($cci, $cciCopy)) ''
    Assert-True 'CustomCultureInfo: IDeserializationCallback rebuilt Name' `
        ($cciCopy.Name -eq $cci.Name) "original='$($cci.Name)' copy='$($cciCopy.Name)'"
    Assert-True 'CustomCultureInfo: patched DisplayName survived' `
        ($cciCopy.DisplayName -eq $cci.DisplayName) "original='$($cci.DisplayName)' copy='$($cciCopy.DisplayName)'"
    Assert-NoDiff 'CustomCultureInfo: candidate vs BinaryFormatter' ([GraphCompare]::Diff($cciRef, $cciCopy, $cci))

    $langT = $asm.GetType('StaxRip.Language')
    $lang = [Activator]::CreateInstance($langT, @($cci, $false, $false))
    Warm-Culture $lang.CultureInfo
    $langRef = [Reference]::Clone($lang)
    $langCopy = Invoke-Candidate $lang
    Assert-True 'Language: culture survived the copy' ($langCopy.CultureInfo.Name -eq $cci.Name) "got '$($langCopy.CultureInfo.Name)'"
    Assert-NoDiff 'Language: candidate vs BinaryFormatter' ([GraphCompare]::Diff($langRef, $langCopy, $lang))
}

$muxT = $asm.GetType('StaxRip.MkvMuxer')
if (-not $muxT) {
    Write-Host '  FAIL  MkvMuxer type not found' -ForegroundColor Red
    $script:Failures.Add('MkvMuxer type')
} else {
    $mux = [Activator]::CreateInstance($muxT)
    $null = $muxT.GetProperty('Tags').GetValue($mux)          # populate the BindingList
    $muxT.GetProperty('TagFile').SetValue($mux, $null)        # the field OnDeserialized normalises
    Warm-Culture $mux.VideoTrackLanguage.CultureInfo
    $muxRef = [Reference]::Clone($mux)
    $muxCopy = Invoke-Candidate $mux
    Assert-True 'MkvMuxer: distinct object' (-not [object]::ReferenceEquals($mux, $muxCopy)) ''
    Assert-True 'MkvMuxer: OnDeserialized normalised TagFile' `
        ($null -ne $muxCopy.TagFile) "TagFile is still null on the copy"
    Assert-NoDiff 'MkvMuxer: candidate vs BinaryFormatter' ([GraphCompare]::Diff($muxRef, $muxCopy, $mux))
}

# --- 5. ControlsThemeColors.Clone(), the second in-memory clone site --------------------
Write-Host ''
Write-Host '=== ControlsThemeColors.Clone() ==='
$ctcT = $asm.GetType('StaxRip.Theme+ControlsThemeColors')
if (-not $ctcT) {
    Write-Host '  FAIL  ControlsThemeColors type not found' -ForegroundColor Red
    $script:Failures.Add('ControlsThemeColors type')
} else {
    $ctc = [Activator]::CreateInstance($ctcT)
    # Touch the lazy properties so the graph is populated rather than all-null.
    foreach ($p in $ctcT.GetProperties()) {
        if ($p.CanRead -and $p.GetIndexParameters().Count -eq 0) { $null = $p.GetValue($ctc) }
    }
    $ctcRef = [Reference]::Clone($ctc)
    $ctcCand = $ctcT.GetMethod('Clone').Invoke($ctc, @())
    Assert-True 'ControlsThemeColors: distinct object' (-not [object]::ReferenceEquals($ctc, $ctcCand)) ''
    Assert-True 'ControlsThemeColors: right type' ($ctcCand.GetType().FullName -eq $ctcT.FullName) $ctcCand.GetType().FullName
    Assert-NoDiff 'ControlsThemeColors: candidate vs BinaryFormatter' ([GraphCompare]::Diff($ctcRef, $ctcCand, $ctc))
}

Write-Host ''
if ($script:Failures.Count -eq 0) {
    Write-Host 'RESULT: PASS -- every check green.' -ForegroundColor Green
    exit 0
} else {
    Write-Host ("RESULT: FAIL -- {0} check(s) failed:" -f $script:Failures.Count) -ForegroundColor Red
    $script:Failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
