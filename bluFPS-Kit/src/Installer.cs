using System;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

namespace BluFPS
{
    // bluFPS-Setup.exe: one file that carries the whole app inside it.
    // It unpacks to a temp folder, shows the setup window, then cleans up after itself.
    internal static class Installer
    {
        [STAThread]
        private static int Main()
        {
            string tmp = Path.Combine(Path.GetTempPath(), "bluFPS-setup-" + Guid.NewGuid().ToString("N").Substring(0, 8));
            try
            {
                Directory.CreateDirectory(tmp);
                Assembly asm = Assembly.GetExecutingAssembly();
                foreach (string name in asm.GetManifestResourceNames())
                {
                    using (Stream input = asm.GetManifestResourceStream(name))
                    using (FileStream output = File.Create(Path.Combine(tmp, name)))
                    {
                        input.CopyTo(output);
                    }
                }
                string error = PsHost.Run(Path.Combine(tmp, "Setup.ps1"), tmp);
                if (error != null)
                {
                    MessageBox.Show("Setup stopped unexpectedly:\r\n" + error, "bluFPS Setup", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return 1;
                }
                return 0;
            }
            catch (Exception ex)
            {
                MessageBox.Show("Setup could not start:\r\n" + ex.Message, "bluFPS Setup", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 1;
            }
            finally
            {
                try { Directory.Delete(tmp, true); } catch (Exception) { }
            }
        }
    }
}
