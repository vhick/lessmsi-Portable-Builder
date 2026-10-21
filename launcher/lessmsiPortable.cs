// Standalone Windows .NET Framework 4.8 launcher.
// Runs GUI from App/LessMsi, with its portable settings implemented at source level.
// Intentionally never modifies APPDATA, the registry, or other applications' files.
using System;
using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Windows.Forms;

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        try
        {
            string root = AppDomain.CurrentDomain.BaseDirectory;
            string appDir = Path.Combine(root, "App", "LessMsi");
            string exe = Path.Combine(appDir, "lessmsi-gui.exe");
            if (!File.Exists(exe))
            {
                MessageBox.Show("Missing lessmsi-gui.exe at:\n" + exe,
                    "lessmsi Portable", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 2;
            }
            Directory.CreateDirectory(Path.Combine(root, "Data", "Settings"));

            // Prevent two concurrent launches of the same portable copy from racing
            // to save their RecentFiles list. Separate locations have separate locks.
            string identity;
            using (var sha = SHA256.Create())
            {
                byte[] hash = sha.ComputeHash(Encoding.UTF8.GetBytes(Path.GetFullPath(root).ToUpperInvariant()));
                identity = BitConverter.ToString(hash, 0, 12).Replace("-", "");
            }
            bool newlyCreated;
            using (var mutex = new System.Threading.Mutex(true, "Local\\LessMsiPortable_" + identity, out newlyCreated))
            {
                if (!newlyCreated)
                {
                    MessageBox.Show("This lessmsi Portable folder is already running.",
                        "lessmsi Portable", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return 0;
                }
                try
                {
                    var start = new ProcessStartInfo(exe) {
                        UseShellExecute = false,
                        WorkingDirectory = appDir
                    };
                    // GUI accepts an optional MSI file path as its first argument.
                    if (args.Length != 0)
                        start.Arguments = "\"" + args[0].Replace("\"", "\\\"") + "\"";
                    using (var child = Process.Start(start))
                    {
                        if (child == null) throw new InvalidOperationException("lessmsi GUI did not start.");
                        child.WaitForExit();
                        return child.ExitCode;
                    }
                }
                finally { mutex.ReleaseMutex(); }
            }
        }
        catch (Exception e)
        {
            MessageBox.Show(e.ToString(), "lessmsi Portable failed to start",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}
