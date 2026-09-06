using System;
using System.Diagnostics;
using System.IO;
using System.Text;

public static class SpaFakeCodex
{
    static string ArgValue(string[] args, string flag)
    {
        for (int i = 0; i < args.Length - 1; i++)
        {
            if (string.Equals(args[i], flag, StringComparison.OrdinalIgnoreCase)) return args[i + 1];
        }
        return null;
    }

    static bool Has(string[] args, string flag)
    {
        foreach (string arg in args)
        {
            if (string.Equals(arg, flag, StringComparison.OrdinalIgnoreCase)) return true;
        }
        return false;
    }

    static string Env(string name)
    {
        return Environment.GetEnvironmentVariable(name);
    }

    static void WriteText(string path, string text)
    {
        if (!string.IsNullOrWhiteSpace(path)) File.WriteAllText(path, text, new UTF8Encoding(false));
    }

    static string Quote(string value)
    {
        if (string.IsNullOrEmpty(value) || value.IndexOfAny(new[] { ' ', '"' }) < 0) return value;
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }

    static int RunGit(string repo, params string[] rest)
    {
        string arguments = string.Empty;
        foreach (string part in rest)
        {
            if (arguments.Length > 0) arguments += " ";
            arguments += Quote(part);
        }
        ProcessStartInfo psi = new ProcessStartInfo("git", arguments)
        {
            WorkingDirectory = repo,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };
        using (Process process = Process.Start(psi))
        {
            process.WaitForExit();
            return process.ExitCode;
        }
    }

    public static int Main(string[] args)
    {
        bool isDebug = Has(args, "--add-dir");
        string lastMessagePath = ArgValue(args, "--output-last-message");
        bool sawLastMessage = lastMessagePath != null;

        if (!isDebug && !sawLastMessage)
        {
            Console.WriteLine("MODEL_CHECK_OK");
            Console.WriteLine("model: " + (ArgValue(args, "--model") ?? "deepseek-v4-flash"));
            Console.WriteLine("provider: deepseek");
            Console.WriteLine("reasoning effort: high");
            Console.WriteLine("approval: never");
            Console.WriteLine("sandbox: " + (ArgValue(args, "--sandbox") ?? "workspace-write"));
            return 0;
        }

        if (isDebug)
        {
            string addDir = ArgValue(args, "--add-dir");
            string addDirCapture = Env("SPA_AD_ADD_DIR_CAPTURE");
            if (!string.IsNullOrWhiteSpace(addDirCapture) && !string.IsNullOrWhiteSpace(addDir))
            {
                WriteText(addDirCapture, addDir);
            }

            int cycle = 0;
            string countFile = Env("SPA_AD_COUNT_FILE");
            if (!string.IsNullOrWhiteSpace(countFile))
            {
                if (File.Exists(countFile))
                {
                    int.TryParse(File.ReadAllText(countFile).Trim(), out cycle);
                }
                cycle += 1;
                WriteText(countFile, cycle.ToString());
            }

            string gateNext = Environment.GetEnvironmentVariable("SPA_AD_GATE_" + cycle);
            string gateFile = Env("SPA_AD_GATE_FILE");
            if (!string.IsNullOrWhiteSpace(gateNext) && !string.IsNullOrWhiteSpace(gateFile))
            {
                WriteText(gateFile, gateNext);
            }

            if (string.Equals(Env("SPA_AD_DEBUG_EXIT"), "fail", StringComparison.Ordinal))
            {
                Console.WriteLine("DEBUGGER_FAILED_SAFELY");
                Console.Error.WriteLine("DEBUGGER_FAILED_SAFELY");
                return 23;
            }

            string repo = Env("SPA_AD_REPAIR_REPO");
            if (!string.IsNullOrWhiteSpace(repo))
            {
                string leaf = cycle > 0 ? "auto-debug-repair-" + cycle + ".txt" : "auto-debug-repair.txt";
                WriteText(Path.Combine(repo, leaf), "repair cycle " + cycle);
                if (RunGit(repo, "add", "-A") != 0)
                {
                    Console.WriteLine("DEBUGGER_REPAIR_ADD_FAILED");
                    return 25;
                }
                if (RunGit(repo, "commit", "-q", "-m", "test auto-debug repair cycle " + cycle) != 0)
                {
                    Console.WriteLine("DEBUGGER_REPAIR_COMMIT_FAILED");
                    return 25;
                }
                string branch = Env("SPA_AD_BRANCH");
                if (!string.IsNullOrWhiteSpace(branch) && RunGit(repo, "push", "-q", "origin", branch) != 0)
                {
                    Console.WriteLine("DEBUGGER_REPAIR_PUSH_FAILED");
                    return 26;
                }
            }

            if (!string.IsNullOrWhiteSpace(lastMessagePath))
            {
                WriteText(lastMessagePath, "AUTO-DEBUG COMPLETE\r\nSPA AUTO-DEBUG V1");
            }
            Console.WriteLine("DEBUGGER_RAN_CYCLE_" + cycle);
            return 0;
        }

        string gate = string.Empty;
        string gateFilePath = Env("SPA_AD_GATE_FILE");
        if (!string.IsNullOrWhiteSpace(gateFilePath) && File.Exists(gateFilePath))
        {
            gate = File.ReadAllText(gateFilePath).Trim();
        }
        if (gate == "fail-A")
        {
            Console.WriteLine("ROUTE_FAILURE_SIGNATURE_ALPHA");
            Console.Error.WriteLine("ROUTE_FAILURE_SIGNATURE_ALPHA");
            return 7;
        }
        if (gate == "fail-B")
        {
            Console.WriteLine("ROUTE_FAILURE_SIGNATURE_BETA");
            Console.Error.WriteLine("ROUTE_FAILURE_SIGNATURE_BETA");
            return 7;
        }
        if (!string.IsNullOrWhiteSpace(lastMessagePath))
        {
            WriteText(lastMessagePath, "Task complete.\r\nIMPLEMENTED");
        }
        Console.WriteLine("TASK_RUN_OK");
        return 0;
    }
}
