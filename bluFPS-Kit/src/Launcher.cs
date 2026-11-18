using System;
using System.IO;
using System.Threading;
using System.Windows.Forms;

namespace BluFPS
{
    // This is bluFPS.exe - the program you pin to the taskbar.
    internal static class Launcher
    {
        [STAThread]
        private static int Main(string[] args)
        {
            bool first;
            using (Mutex single = new Mutex(true, "bluFPS.SingleInstance", out first))
            {
                if (!first) { return 0; }   // already running

                string dir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
                string script = Path.Combine(dir, "bluFPS.ps1");
                if (!File.Exists(script))
                {
                    MessageBox.Show("bluFPS.ps1 was not found next to bluFPS.exe.\r\nPlease reinstall bluFPS.",
                        "bluFPS", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return 1;
                }
                Environment.SetEnvironmentVariable("BLUFPS_ARGS", string.Join(" ", args));
                string error = PsHost.Run(script, dir);
                if (error != null)
                {
                    MessageBox.Show("bluFPS stopped unexpectedly:\r\n" + error, "bluFPS", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return 1;
                }
            }
            Environment.Exit(0);
            return 0;
        }
    }
}
