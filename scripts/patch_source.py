"""Patch the exact upstream release checkout, failing safely if its layout changes."""
import pathlib
import re
import shutil
import sys

source = pathlib.Path(sys.argv[1])
version = sys.argv[2]
if not re.fullmatch(r'\d+\.\d+\.\d+', version):
    raise SystemExit('Invalid stable release version for assembly patch.')
settings = source / 'src/LessMsi.Gui/Properties/Settings.Designer.cs'
prefs = source / 'src/LessMsi.Gui/PreferencesForm.cs'
kit = pathlib.Path(__file__).resolve().parents[1]
if not settings.is_file() or not prefs.is_file():
    raise SystemExit('The lessmsi GUI source layout changed; refusing to package an unpatched GUI.')
original = settings.read_text(encoding='utf-8-sig')
for token in ['ApplicationSettingsBase', 'RecentFiles', 'LastRecordedAppSize', 'LastRecordedAppLocation']:
    if token not in original:
        raise SystemExit(f'Settings source changed: missing {token}. Review the upstream update.')
shutil.copyfile(kit / 'patches/Settings.Designer.cs', settings)

text = prefs.read_text(encoding='utf-8-sig')
signature = 'private void cmdAddRemoveShortcut_Click(object sender, EventArgs e)'
start = text.find(signature)
if start < 0 or text.count(signature) != 1:
    raise SystemExit('Explorer integration handler changed; refusing an unsafe build.')
brace = text.find('{', start + len(signature))
if brace < 0:
    raise SystemExit('Explorer integration handler has no body.')
# Make registry-registration button explicitly refuse, even if the helper binary were restored.
text = text[:brace+1] + '''
            MessageBox.Show(this,
                "Windows Explorer integration is disabled in this true-portable build because " +
                "it registers persistent system-wide file commands.",
                "lessmsi Portable", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
''' + text[brace+1:]
prefs.write_text(text, encoding='utf-8-sig')
print('Patched source settings to Data/Settings and disabled Explorer registration.')

# The upstream build script normally generates this version at release time.
# Match that release version when rebuilding the GUI and Core assembly so the
# official CLI, GUI and dependent DLL all agree on their assembly identities.
assembly = source / 'src/CommonAssemblyInfo.cs'
asm = assembly.read_text(encoding='utf-8-sig')
asm, count = re.subn(r'\[assembly:\s*AssemblyVersion\("[^"]+"\)\]',
                     '[assembly: AssemblyVersion("' + version + '.0")]', asm)
if count != 1:
    raise SystemExit('CommonAssemblyInfo version declaration changed; cannot ensure binary compatibility.')
assembly.write_text(asm, encoding='utf-8-sig')
print('Aligned rebuilt GUI/Core assembly version to ' + version + '.0')
