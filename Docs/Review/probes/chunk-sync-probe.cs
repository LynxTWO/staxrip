// Runtime probe for the chunk-encode Script.Synchronize() concurrency question.
// Drives the SHIPPING StaxRip v2.52.5 x64 binary by reflection. Builds nothing from source.
//
// Two experiments:
//   A. Is Macro.Expand deterministic across calls? (the guard compares its output to LastCode)
//   B. With the cache primed exactly as GlobalClass.vb:633 primes it, do N concurrent
//      callers enter the guarded body of VideoScript.Synchronize?
//
// Body entry is detected without instrumenting the body: the first statement inside the
// guard writes the script file, and a few statements later it calls g.MainForm.Indexing().
// g.MainForm is null in this process, so entering the body throws NullReferenceException.
// No exception => the guard short-circuited. That is the whole signal.

using System;
using System.Collections;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Threading;

class Probe
{
    static Assembly asm;
    static Type tShortcut, tProject, tSettings, tGlobal, tVideoScript, tVideoFilter, tMacro;

    static object NewOf(Type t) { return Activator.CreateInstance(t, true); }

    static void SetStatic(string name, object val)
    {
        var f = tShortcut.GetField(name, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static);
        f.SetValue(null, val);
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
        // Engine: 0 = AviSynth (ScriptEngine.AviSynth)
        var eng = tVideoScript.GetProperty("Engine");
        eng.SetValue(vs, Enum.ToObject(eng.PropertyType, 0), null);

        var filters = (IList)tVideoScript.GetProperty("Filters").GetValue(vs, null);
        filters.Clear();
        var ctor = tVideoFilter.GetConstructor(new[] { typeof(string), typeof(string), typeof(string), typeof(bool) });
        filters.Add(ctor.Invoke(new object[] { "Source", "Probe", sourceFilterScript, true }));
        return vs;
    }

    static string GetScriptText(object vs)
    {
        var m = tVideoScript.GetMethod("GetScript", new Type[0]);
        return (string)m.Invoke(vs, null);
    }

    static void SetField(object vs, string name, object val)
    {
        tVideoScript.GetField(name, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)
                    .SetValue(vs, val);
    }

    static object GetField(object vs, string name)
    {
        return tVideoScript.GetField(name, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)
                           .GetValue(vs);
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

        // --- globals ---
        var proj = NewOf(tProject);
        SetStatic("p", proj);
        SetStatic("s", NewOf(tSettings));
        SetStatic("g", NewOf(tGlobal));
        // SourceFile ending in .avs makes ModifyScript a pass-through (VideoScript.vb:319-323),
        // which keeps this probe off the AviSynth script-rewriting path.
        tProject.GetField("SourceFile", BindingFlags.Public | BindingFlags.Instance)
                .SetValue(proj, Path.Combine(tempDir, "x.avs"));

        Console.WriteLine("\n================ EXPERIMENT A: Macro.Expand determinism ================");
        foreach (var probe in new[] {
            new[] { "control (no volatile macro)", "BlankClip()" },
            new[] { "%current_time%",              "BlankClip() # %current_time%" },
            new[] { "%random:6%",                  "BlankClip() # %random:6%" },
        })
        {
            string label = probe[0], text = probe[1];
            string a = Expand(text);
            Thread.Sleep(1100); // cross a seconds boundary for the time macros
            string b = Expand(text);
            Console.WriteLine("  {0,-30} stable={1}", label, (a == b));
            Console.WriteLine("      call1: {0}", a);
            Console.WriteLine("      call2: {0}", b);
        }

        Console.WriteLine("\n================ EXPERIMENT B: concurrent entry into the guarded body ================");
        RunConcurrent("control (no volatile macro)", tempDir, "BlankClip()", 4);
        RunConcurrent("treatment (%current_time%)", tempDir, "BlankClip() # %current_time%", 4);

        Console.WriteLine("\n================ EXPERIMENT C: simultaneous presence inside the body ================");
        Console.WriteLine("  This process holds the script file open with FileShare.None for the whole run.");
        Console.WriteLine("  A thread can only fail on that file by executing the write statement, which is");
        Console.WriteLine("  INSIDE the guarded body. Every thread that fails was therefore inside the body");
        Console.WriteLine("  during the one window the lock was held -- i.e. all of them at the same time.");
        RunLockHeld("control (no volatile macro)", tempDir, "BlankClip()", 8);
        RunLockHeld("treatment (%current_time%)", tempDir, "BlankClip() # %current_time%", 8);
    }

    static void RunLockHeld(string label, string tempDir, string sourceScript, int threads)
    {
        var vs = MakeScript(tempDir, sourceScript);
        string scriptPath = (string)tVideoScript.GetProperty("Path").GetValue(vs, null);

        SetField(vs, "Error", "");
        SetField(vs, "LastCode", Expand(GetScriptText(vs)));
        SetField(vs, "LastPath", scriptPath);
        Thread.Sleep(1100);

        File.WriteAllText(scriptPath, "placeholder");
        var outcomes = new string[threads];
        var reachedCall = new int[threads];
        var barrier = new ManualResetEventSlim(false);
        var ts = new Thread[threads];

        var hold = new FileStream(scriptPath, FileMode.Open, FileAccess.ReadWrite, FileShare.None);
        for (int i = 0; i < threads; i++)
        {
            int idx = i;
            ts[i] = new Thread(() =>
            {
                barrier.Wait();
                Interlocked.Exchange(ref reachedCall[idx], 1);
                try { CallSynchronize(vs); outcomes[idx] = "no exception -> guard SHORT-CIRCUITED"; }
                catch (IOException) { outcomes[idx] = "IOException on the shared script file"; }
                catch (TypeInitializationException) { outcomes[idx] = "completed the write, then threw at the Package.VerifyOK check"; }
                catch (Exception ex) { outcomes[idx] = "other " + ex.GetType().Name; }
            });
            ts[i].IsBackground = true;
            ts[i].Start();
        }
        barrier.Set();

        // Snapshot while the lock is still held. The only thing in Synchronize that can
        // block on this file is the write statement, which is inside the guarded body.
        Thread.Sleep(4000);
        int blocked = 0, started = 0;
        for (int i = 0; i < threads; i++) { if (ts[i].IsAlive) blocked++; if (reachedCall[i] == 1) started++; }

        Console.WriteLine("\n  --- " + label + ", " + threads + " threads ---");
        Console.WriteLine("    while the lock was held: {0} of {1} threads had entered Synchronize,", started, threads);
        Console.WriteLine("                             {0} of {1} were blocked inside it", blocked, threads);
        Console.WriteLine("    => {0} threads were simultaneously inside the guarded body", blocked);

        hold.Dispose(); // release; blocked threads should now proceed
        for (int i = 0; i < threads; i++) ts[i].Join(15000);
        Console.WriteLine("    after releasing the lock:");
        for (int i = 0; i < threads; i++)
            Console.WriteLine("      thread {0}: {1}", i, outcomes[i] ?? "still running (did not finish within 15s)");
    }

    static void RunConcurrent(string label, string tempDir, string sourceScript, int threads)
    {
        var vs = MakeScript(tempDir, sourceScript);
        string scriptPath = (string)tVideoScript.GetProperty("Path").GetValue(vs, null);

        // Prime the cache exactly as the pre-synchronize at GlobalClass.vb:633 leaves it:
        // Error empty, LastCode = the expanded code, LastPath = Path.
        SetField(vs, "Error", "");
        SetField(vs, "LastCode", Expand(GetScriptText(vs)));
        SetField(vs, "LastPath", scriptPath);

        Thread.Sleep(1100); // ensure wall-clock has moved on since priming

        if (File.Exists(scriptPath)) File.Delete(scriptPath);

        var outcomes = new string[threads];
        var barrier = new ManualResetEventSlim(false);
        var ts = new Thread[threads];
        for (int i = 0; i < threads; i++)
        {
            int idx = i;
            ts[i] = new Thread(() =>
            {
                barrier.Wait();
                try { CallSynchronize(vs); outcomes[idx] = "no exception -> guard SHORT-CIRCUITED"; }
                catch (NullReferenceException) { outcomes[idx] = "ENTERED BODY (reached g.MainForm.Indexing())"; }
                catch (IOException ex) { outcomes[idx] = "ENTERED BODY (reached the file write; " + ex.GetType().Name + ")"; }
                catch (TypeInitializationException) { outcomes[idx] = "ENTERED BODY (past the write, threw at the Package.VerifyOK check)"; }
                catch (Exception ex) { outcomes[idx] = "unclassified " + ex.GetType().Name + ": " + ex.Message.Split('\n')[0]; }
            });
            ts[i].Start();
        }
        barrier.Set();
        foreach (var t in ts) t.Join();

        Console.WriteLine("\n  --- " + label + " ---");
        int entered = 0;
        for (int i = 0; i < threads; i++)
        {
            Console.WriteLine("    thread {0}: {1}", i, outcomes[i]);
            if (outcomes[i].Contains("ENTERED BODY")) entered++;
        }
        Console.WriteLine("    => {0} of {1} threads entered the guarded body", entered, threads);
        Console.WriteLine("    => script file written by the run: {0}", File.Exists(scriptPath));
    }
}
