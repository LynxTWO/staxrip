// Guard probe for the chunk-encode Script.Synchronize() race. Successor to
// chunk-sync-probe.cs, which established the defect. This one is a pass/fail gate that
// runs against any StaxRip build and works whether the guard caches expanded or
// unexpanded script text.
//
// It checks TWO invariants, because either one alone can be satisfied by a wrong fix.
//
//   GUARD A (no race): with the cache primed as a completed synchronization leaves it,
//     concurrent callers must NOT enter the guarded body, even when the script contains a
//     macro whose expansion changes between calls.
//
//   GUARD B (still fresh): when the script has genuinely changed, callers MUST enter the
//     body and rewrite it. Without this, a "fix" that short-circuits unconditionally
//     passes Guard A while leaving a stale script on disk.
//
// Body entry is detected without instrumenting the body. The first statement inside the
// guard writes the script file. This process holds that file open with FileShare.None, so
// a thread blocked on it has necessarily passed the guard. Nothing before the guard touches
// the file: the pre-guard work is string manipulation and a directory-existence test.
//
// The hold is deliberately SHORTER than the retry budget in Extensions.WriteFile
// (10 attempts, 150 ms apart, so about 1.5 s). Holding longer makes writers exhaust the
// budget and call g.ShowException, which raises a modal dialog from a worker thread and
// parks it forever. The predecessor probe held for 4 s and did exactly that.

using System;
using System.Collections;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Threading;

class GuardProbe
{
    const int HoldMs = 500;    // < 1500 ms retry budget, so no thread reaches ShowException
    const int SampleMs = 400;  // sample while the file is still held

    static Assembly asm;
    static Type tShortcut, tProject, tSettings, tGlobal, tVideoScript, tVideoFilter, tMacro;
    static int failures = 0;

    static object NewOf(Type t) { return Activator.CreateInstance(t, true); }

    static void SetStatic(string name, object val)
    {
        tShortcut.GetField(name, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static)
                 .SetValue(null, val);
    }

    static string Expand(string s)
    {
        var m = tMacro.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static)
                      .First(x => x.Name == "Expand" && x.GetParameters().Length == 1
                                  && x.GetParameters()[0].ParameterType == typeof(string));
        return (string)m.Invoke(null, new object[] { s });
    }

    static object MakeScript(string tempDir, string sourceFilterScript)
    {
        var vs = NewOf(tVideoScript);
        tVideoScript.GetProperty("Path").SetValue(vs, Path.Combine(tempDir, "test.avs"), null);
        var eng = tVideoScript.GetProperty("Engine");
        eng.SetValue(vs, Enum.ToObject(eng.PropertyType, 0), null); // 0 = AviSynth
        var filters = (IList)tVideoScript.GetProperty("Filters").GetValue(vs, null);
        filters.Clear();
        var ctor = tVideoFilter.GetConstructor(new[] { typeof(string), typeof(string), typeof(string), typeof(bool) });
        filters.Add(ctor.Invoke(new object[] { "Source", "Probe", sourceFilterScript, true }));
        return vs;
    }

    static string GetScriptText(object vs)
    {
        return (string)tVideoScript.GetMethod("GetScript", new Type[0]).Invoke(vs, null);
    }

    static void SetField(object vs, string name, object val)
    {
        tVideoScript.GetField(name, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)
                    .SetValue(vs, val);
    }

    static void CallSynchronize(object vs)
    {
        var m = tVideoScript.GetMethod("Synchronize", new[] { typeof(bool), typeof(bool), typeof(bool) });
        try { m.Invoke(vs, new object[] { false, true, false }); }
        catch (TargetInvocationException tie) { throw tie.InnerException; }
    }

    static void Main(string[] args)
    {
        string exePath = args[0];
        string tempDir = args[1];
        Directory.CreateDirectory(tempDir);

        asm = Assembly.LoadFrom(exePath);
        tShortcut = asm.GetType("StaxRip.ShortcutModule");
        tProject = asm.GetType("StaxRip.Project");
        tSettings = asm.GetType("StaxRip.ApplicationSettings");
        tGlobal = asm.GetType("StaxRip.GlobalClass");
        tVideoScript = asm.GetType("StaxRip.VideoScript");
        tVideoFilter = asm.GetType("StaxRip.VideoFilter");
        tMacro = asm.GetTypes().First(t => t.Name == "Macro");

        Console.WriteLine("Binary under test: " + asm.FullName);
        Console.WriteLine("Path: " + exePath);

        var proj = NewOf(tProject);
        SetStatic("p", proj);
        SetStatic("s", NewOf(tSettings));
        SetStatic("g", NewOf(tGlobal));
        tProject.GetField("SourceFile", BindingFlags.Public | BindingFlags.Instance)
                .SetValue(proj, Path.Combine(tempDir, "x.avs"));

        const string plain = "BlankClip()";
        const string volatileScript = "BlankClip() # %current_time%";

        Console.WriteLine();
        Console.WriteLine("=========== GUARD A: concurrent callers must not enter the body ===========");
        // Control: no volatile macro. Raw and expanded text are identical here, so this
        // passes under either cache contract. It proves the detector is not reporting an
        // unrelated failure.
        Check("A1 control, plain script, cache primed raw", tempDir, plain, "raw", 0);
        Check("A2 control, plain script, cache primed expanded", tempDir, plain, "expanded", 0);
        // The discriminator. A build that caches the expanded text cannot short-circuit
        // here, because the expansion has moved on since priming.
        Check("A3 TREATMENT, volatile macro, cache primed raw", tempDir, volatileScript, "raw", 0);

        Console.WriteLine();
        Console.WriteLine("=========== GUARD B: a changed script must still be rewritten ===========");
        // Guarantees the fix did not simply disable the guard.
        Check("B1 changed script, stale cache, plain", tempDir, plain, "stale", 8);
        Check("B2 changed script, stale cache, volatile macro", tempDir, volatileScript, "stale", 8);

        Console.WriteLine();
        Console.WriteLine("=========== INFORMATIONAL (not a gate) ===========");
        Console.WriteLine("  Priming with the expanded text does not match the raw-cache contract, so a");
        Console.WriteLine("  build using that contract is expected to enter the body here. This line is");
        Console.WriteLine("  recorded to keep the comparison with the predecessor probe legible.");
        Report("I1 volatile macro, cache primed expanded", Measure(tempDir, volatileScript, "expanded", 8));

        Console.WriteLine();
        if (failures == 0) Console.WriteLine("RESULT: PASS (all gated checks met their expectation)");
        else Console.WriteLine("RESULT: FAIL (" + failures + " gated check(s) did not meet expectation)");
        Environment.Exit(failures == 0 ? 0 : 1);
    }

    static void Check(string label, string tempDir, string sourceScript, string primeMode, int expectedInside)
    {
        int inside = Measure(tempDir, sourceScript, primeMode, 8);
        bool ok = inside == expectedInside;
        if (!ok) failures++;
        Console.WriteLine("  [" + (ok ? "PASS" : "FAIL") + "] " + label);
        Console.WriteLine("         expected " + expectedInside + " of 8 inside the body, observed " + inside);
    }

    static void Report(string label, int inside)
    {
        Console.WriteLine("  [INFO] " + label + ": " + inside + " of 8 inside the body");
    }

    // Returns how many of `threads` callers were simultaneously inside the guarded body.
    static int Measure(string tempDir, string sourceScript, string primeMode, int threads)
    {
        var vs = MakeScript(tempDir, sourceScript);
        string scriptPath = (string)tVideoScript.GetProperty("Path").GetValue(vs, null);
        string raw = GetScriptText(vs);

        SetField(vs, "Error", "");
        SetField(vs, "LastPath", scriptPath);
        if (primeMode == "raw") SetField(vs, "LastCode", raw);
        else if (primeMode == "expanded") SetField(vs, "LastCode", Expand(raw));
        else SetField(vs, "LastCode", "### a completely different script ###");

        // Let wall-clock move past the priming instant so a time macro expands differently.
        Thread.Sleep(1100);

        File.WriteAllText(scriptPath, "placeholder");
        var reached = new int[threads];
        var barrier = new ManualResetEventSlim(false);
        var ts = new Thread[threads];

        using (var hold = new FileStream(scriptPath, FileMode.Open, FileAccess.ReadWrite, FileShare.None))
        {
            for (int i = 0; i < threads; i++)
            {
                int idx = i;
                ts[i] = new Thread(() =>
                {
                    barrier.Wait();
                    Interlocked.Exchange(ref reached[idx], 1);
                    try { CallSynchronize(vs); }
                    catch (Exception) { /* classification is not needed; blocking is the signal */ }
                });
                ts[i].IsBackground = true;
                ts[i].Start();
            }
            barrier.Set();
            Thread.Sleep(SampleMs);

            int inside = 0;
            for (int i = 0; i < threads; i++) if (ts[i].IsAlive) inside++;

            // Release well inside the retry budget so no writer reaches g.ShowException.
            Thread.Sleep(Math.Max(0, HoldMs - SampleMs));
            hold.Dispose();
            for (int i = 0; i < threads; i++) ts[i].Join(5000);
            return inside;
        }
    }
}
