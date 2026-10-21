import pathlib
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]


class BuilderTests(unittest.TestCase):
    def test_workflow_manual_only(self):
        content = (ROOT / '.github/workflows/build-lessmsi-portable.yml').read_text(encoding='utf-8')
        self.assertIn('workflow_dispatch:', content)
        self.assertIn('runs-on: windows-latest', content)
        self.assertIn('upload-artifact@v6', content)
        self.assertIn('actions/checkout@v5', content)
        self.assertIn('retention-days: 1', content)

    def test_launcher_runs_only_GUI(self):
        text = (ROOT/'launcher/lessmsiPortable.cs').read_text(encoding='utf-8')
        self.assertIn('App", "LessMsi', text)
        self.assertIn('lessmsi-gui.exe', text)
        self.assertNotIn('Environment.SetEnvironmentVariable', text)
        self.assertNotIn('Registry.', text)

    def test_source_level_settings_patch(self):
        text = (ROOT/'patches/Settings.Designer.cs').read_text(encoding='utf-8')
        for value in ('RecentFiles', 'LastRecordedAppSize', 'LastRecordedAppLocation',
                      'Data\\Settings', 'lessmsi.settings.xml', 'File.Move'):
            self.assertIn(value, text)
        self.assertNotIn('ApplicationSettingsBase', text)
        self.assertNotIn('user.config', text.replace('// The original user.config provider would store these values in Windows AppData.', ''))

    def test_source_patch_blocks_explorer_integration(self):
        text = (ROOT/'scripts/patch_source.py').read_text(encoding='utf-8')
        self.assertIn('cmdAddRemoveShortcut_Click', text)
        self.assertIn('integration is disabled', text)
        self.assertIn('refusing an unsafe build', text)

    def test_official_release_and_digest_pin(self):
        text = (ROOT/'scripts/build.ps1').read_text(encoding='utf-8')
        self.assertIn('https://api.github.com/repos/activescott/lessmsi/releases/latest', text)
        self.assertIn('5b4e187e74b184ad3a63ccf06c3d17dae2b8c4b6c298a996dbd51a9f6db29d21', text)
        self.assertIn('lessmsi-gui.exe', text)
        self.assertIn('lessmsi.exe', text)
        self.assertIn('Remove-Item -LiteralPath $helper -Force', text)
        self.assertIn("lessmsi.core.dll", text)

    def test_appinfo_layout(self):
        text = (ROOT/'scripts/build.ps1').read_text(encoding='utf-8')
        self.assertIn('App/AppInfo', text)
        self.assertIn('Data/Settings', text)
        self.assertIn('Other/Source', text)
        for item in ('Start=lessmsiPortable.exe','Category=Utilities','AppID=lessmsiPortable'):
            self.assertIn(item, text)

    def test_upstream_build_patch_is_failsafe(self):
        text = (ROOT/'scripts/patch_source.py').read_text(encoding='utf-8')
        self.assertIn('ApplicationSettingsBase', text)
        self.assertIn('Settings source changed', text)
        self.assertIn('Explorer integration handler changed', text)
        self.assertIn('CommonAssemblyInfo.cs', text)
        self.assertIn('AssemblyVersion', text)

    def test_upstream_native_dependency_is_explicitly_restored_and_included(self):
        build = (ROOT / 'scripts/build.ps1').read_text(encoding='utf-8')
        verify = (ROOT / 'scripts/verify.ps1').read_text(encoding='utf-8')
        self.assertIn('-PackagesDirectory $packagesDir', build)
        self.assertIn("$solutionProperty = '/p:SolutionDir=' + $solutionDir", build)
        self.assertIn('libmspack4n.0.9.10/build/x86/mspack.dll', build)
        self.assertIn('libmspack4n.0.9.10/lib/net40/libmspackn.dll', build)
        self.assertIn('$rebuiltNativeCab', build)
        self.assertIn("Join-Path $app 'mspack.dll'", build)
        self.assertIn("Join-Path $app 'libmspackn.dll'", build)
        self.assertIn('App/LessMsi/mspack.dll', verify)
        self.assertIn('App/LessMsi/libmspackn.dll', verify)

    def test_builder_version_is_updated(self):
        build = (ROOT / 'scripts/build.ps1').read_text(encoding='utf-8')
        readme = (ROOT / 'README.md').read_text(encoding='utf-8')
        self.assertIn('builder=1.1', build)
        self.assertIn('Builder v1.1', readme)

    def test_no_automatic_registry_or_msi_installation(self):
        build = (ROOT/'scripts/build.ps1').read_text(encoding='utf-8')
        self.assertNotIn('msiexec /i', build.lower())
        self.assertNotIn('reg add ', build.lower())
        self.assertNotIn('Remove-Item $env:APPDATA', build)

    def test_launcher_compilation_icon(self):
        build = (ROOT/'scripts/build.ps1').read_text(encoding='utf-8')
        self.assertIn('/win32icon:$icon', build)
        self.assertIn('Resources/LessmsiIcon.ico', build)
        self.assertIn('appicon.ico', build)

    def test_no_missing_source_artifacts(self):
        self.assertTrue((ROOT/'README.md').exists())
        self.assertTrue((ROOT/'docs/TESTING.md').exists())
        self.assertTrue((ROOT/'scripts/verify.ps1').exists())


if __name__ == '__main__':
    unittest.main()
