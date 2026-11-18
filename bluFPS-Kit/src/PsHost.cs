using System;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading;

namespace BluFPS
{
    // Runs a PowerShell script INSIDE this program (no powershell.exe window or taskbar icon),
    // so the window belongs to bluFPS.exe and shows bluFPS's own icon.
    internal static class PsHost
    {
        private static string scriptPath;
        private static string failure;

        // Returns null when the script finished normally, otherwise an error message.
        public static string Run(string script, string homeDir)
        {
            scriptPath = script;
            failure = null;
            Environment.SetEnvironmentVariable("BLUFPS_HOME", homeDir);
            Thread worker = new Thread(new ThreadStart(Worker));
            worker.SetApartmentState(ApartmentState.STA);
            worker.Start();
            worker.Join();
            return failure;
        }

        private static void Worker()
        {
            try
            {
                InitialSessionState iss = InitialSessionState.CreateDefault();
                using (Runspace rs = RunspaceFactory.CreateRunspace(iss))
                {
                    rs.ApartmentState = ApartmentState.STA;
                    rs.ThreadOptions = PSThreadOptions.UseCurrentThread;
                    rs.Open();
                    using (PowerShell ps = PowerShell.Create())
                    {
                        ps.Runspace = rs;
                        ps.AddScript("try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force } catch { }");
                        ps.Invoke();
                        ps.Commands.Clear();
                        ps.AddScript(File.ReadAllText(scriptPath));
                        ps.Invoke();
                    }
                }
            }
            catch (Exception ex)
            {
                failure = ex.Message;
            }
        }
    }
}
