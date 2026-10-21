// Independent portable settings implementation for lessmsi GUI.
// Replace only LessMsi.Gui/Properties/Settings.Designer.cs at build time.
// The original user.config provider would store these values in Windows AppData.
// This implementation instead saves to <portable-root>/Data/Settings/lessmsi.settings.xml.
using System;
using System.Collections.Specialized;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Text;
using System.Xml;

namespace LessMsi.Gui.Properties
{
    internal sealed partial class Settings
    {
        private static readonly Settings instance = new Settings();
        public static Settings Default { get { return instance; } }

        public StringCollection RecentFiles { get; set; }
        public Size LastRecordedAppSize { get; set; }
        public Point LastRecordedAppLocation { get; set; }

        private static string SettingsPath
        {
            get
            {
                string folder = Path.GetFullPath(Path.Combine(
                    AppDomain.CurrentDomain.BaseDirectory, @"..\..\Data\Settings"));
                return Path.Combine(folder, "lessmsi.settings.xml");
            }
        }

        private Settings()
        {
            RecentFiles = new StringCollection();
            LastRecordedAppSize = new Size(0, 0);
            LastRecordedAppLocation = new Point(10, 10);
            Load();
        }

        private void Load()
        {
            string file = SettingsPath;
            // Recover an interrupted save on USB drives where atomic replacement
            // may not be supported (for example, FAT32).
            string backup = file + ".bak";
            if (!File.Exists(file) && File.Exists(backup)) File.Move(backup, file);
            if (!File.Exists(file)) return;

            // Settings XML is local user data: forbid DTDs and external resources.
            var readerSettings = new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null };
            var doc = new XmlDocument { XmlResolver = null };
            using (var reader = XmlReader.Create(file, readerSettings)) doc.Load(reader);
            XmlElement root = doc.DocumentElement;
            if (root == null || root.Name != "LessMsiPortableSettings")
                throw new InvalidDataException("Invalid lessmsi portable settings XML: " + file);

            var files = root.SelectNodes("RecentFiles/File");
            if (files != null)
            {
                foreach (XmlNode item in files)
                    if (item != null && !string.IsNullOrWhiteSpace(item.InnerText))
                        RecentFiles.Add(item.InnerText);
            }
            XmlNode window = root.SelectSingleNode("Window");
            if (window != null && window.Attributes != null)
            {
                var a = window.Attributes;
                int width, height, left, top;
                if (a["Width"] != null && a["Height"] != null &&
                    int.TryParse(a["Width"].Value, NumberStyles.Integer, CultureInfo.InvariantCulture, out width) &&
                    int.TryParse(a["Height"].Value, NumberStyles.Integer, CultureInfo.InvariantCulture, out height))
                    LastRecordedAppSize = new Size(width, height);
                if (a["Left"] != null && a["Top"] != null &&
                    int.TryParse(a["Left"].Value, NumberStyles.Integer, CultureInfo.InvariantCulture, out left) &&
                    int.TryParse(a["Top"].Value, NumberStyles.Integer, CultureInfo.InvariantCulture, out top))
                    LastRecordedAppLocation = new Point(left, top);
            }
        }

        public void Save()
        {
            string path = SettingsPath;
            string folder = Path.GetDirectoryName(path);
            Directory.CreateDirectory(folder);
            var doc = new XmlDocument { XmlResolver = null };
            var root = doc.CreateElement("LessMsiPortableSettings");
            root.SetAttribute("Version", "1");
            doc.AppendChild(root);
            var files = doc.CreateElement("RecentFiles");
            root.AppendChild(files);
            if (RecentFiles != null)
                foreach (string item in RecentFiles)
                {
                    var file = doc.CreateElement("File");
                    file.InnerText = item ?? string.Empty;
                    files.AppendChild(file);
                }
            var window = doc.CreateElement("Window");
            window.SetAttribute("Width", LastRecordedAppSize.Width.ToString(CultureInfo.InvariantCulture));
            window.SetAttribute("Height", LastRecordedAppSize.Height.ToString(CultureInfo.InvariantCulture));
            window.SetAttribute("Left", LastRecordedAppLocation.X.ToString(CultureInfo.InvariantCulture));
            window.SetAttribute("Top", LastRecordedAppLocation.Y.ToString(CultureInfo.InvariantCulture));
            root.AppendChild(window);

            string temporary = path + ".tmp";
            using (var writer = XmlWriter.Create(temporary, new XmlWriterSettings { Indent = true, Encoding = new UTF8Encoding(false) }))
                doc.Save(writer);
            // Plain same-directory renames also work on FAT32 removable drives.
            // Keep a backup until the new settings file is fully in place.
            string backup = path + ".bak";
            if (File.Exists(backup)) File.Delete(backup);
            if (File.Exists(path)) File.Move(path, backup);
            try
            {
                File.Move(temporary, path);
                if (File.Exists(backup)) File.Delete(backup);
            }
            catch
            {
                if (!File.Exists(path) && File.Exists(backup)) File.Move(backup, path);
                throw;
            }
        }
    }
}
