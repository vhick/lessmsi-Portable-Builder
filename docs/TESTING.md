# Windows testing checklist

This builder is not Windows-verified until its GitHub Actions build and real launch tests have passed.

## Install

1. Download the GitHub Actions artifact, then extract the `lessmsiPortable-<version>.zip` inside it.
2. Put its `lessmsiPortable` folder directly under the same `PortableApps` directory containing `PortableApps.com`.
3. Launch `lessmsiPortable.exe`; PortableApps Menu > Apps > Refresh App Icons should show **lessmsi Portable**.

## Essential checks

- [ ] Root launcher starts the GUI without registration, installation or administrator privileges.
- [ ] Use an MSI you already trust; inspect its files and extract them to a test directory.
- [ ] Open another MSI, close, reopen; confirm Recent Files persist.
- [ ] Resize and reposition the window, close and relaunch; confirm the window state persists.
- [ ] `Data/Settings/lessmsi.settings.xml` exists; **no lessmsi `user.config` created in Windows AppData**.
- [ ] Edit > Preferences > Add shortcut does not register any Explorer shell command.
- [ ] Standard command line `App/LessMsi/lessmsi.exe x ...` still works.
- [ ] PortableApps.com Menu detects the package.
- [ ] Move the portable folder to another drive/path and reopen; settings remain.
- [ ] Upgrade by replacing `App`, `Other` and the root launcher only; **keep `Data`**.

## Limits

Windows can retain normal execution history, recent-file/Explorer records and system-managed caches independently of lessmsi. The builder does not delete any Windows folders or shared registry keys.

Stored Recent Files paths may become stale after moving drives. This is expected; only the saved list is portable, not the MSI files themselves.

Do not use the application's Explorer integration from an upstream/unmodified executable; that optional operation registers persistent system-wide shell commands. Our patched GUI blocks it and omits its registration helper.
