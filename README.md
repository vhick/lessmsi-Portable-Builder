# lessmsi True Portable Builder v1.1

**Upstream:** https://github.com/activescott/lessmsi  
**Initial stable release:** v2.12.9 (2026-04-02)  
**Output:** manually built ready-to-use `lessmsiPortable-<version>.zip` with a single `lessmsiPortable/` parent folder.  
**Format:** ZIP, not `.paf.exe`.

## What the builder does

1. Finds the selected stable release and downloads its official ZIP.
2. Verifies SHA-256 using the upstream release digest if GitHub provides one, otherwise a pinned checksum for v2.12.9. For future unpinned versions, it warns if no trusted hash is published.
3. Checks out the **same release tag** from the official lessmsi repository.
4. Replaces **only the GUI settings implementation**, so Recent Files and window preferences live in `Data/Settings/lessmsi.settings.xml` instead of Windows `user.config`.
5. Rebuilds the GUI and Core library with matching release assembly versions, and disables the permanent Windows Explorer context-menu registration at source level and omits its helper binary.
6. Restores the x86 CAB extraction dependency to a fixed NuGet folder, passes the actual solution directory to MSBuild, then builds the patched GUI. The official release supplies the CLI and other packaged dependencies.
7. Compiles `lessmsiPortable.exe` with the upstream application's *actual icon*, and writes `App/AppInfo/appinfo.ini` plus PNG menu icons.
8. Packages the complete portable folder into an additional ZIP, ready to extract into your PortableApps directory.

## Build using GitHub Desktop and Actions

1. Create a new empty public or private GitHub repository called `lessmsi-Portable-Builder`.
2. Extract **this builder kit ZIP**. Use GitHub Desktop to copy **all the files** into the new repository, including the hidden `.github` folder.
3. Commit the files and push them to GitHub.
4. In your GitHub repository, open **Actions** > **Build lessmsi Portable (Manual)** > **Run workflow**.
5. Keep `release_tag` = `latest` or manually enter a stable tag such as `v2.12.9`.
6. After the job gets a green check, download the ZIP artifact.
7. Extract the `lessmsiPortable-<version>.zip` inside the artifact. Move the `lessmsiPortable` folder into `D:\PortableApps\` or whichever location contains the `PortableApps.com` directory.
8. In the PortableApps menu, click **Apps > Refresh App Icons**.

The root launcher is `lessmsiPortable.exe`. Use it to launch the graphical user interface, and use `App/LessMsi/lessmsi.exe` directly for command-line MSI extraction. No admin setup is needed for either.

## Portable layout

```text
lessmsiPortable/
  lessmsiPortable.exe
  App/
    AppInfo/
      appinfo.ini
      appicon.ico
      appicon_16.png, appicon_32.png, appicon_75.png,
      appicon_128.png, appicon_256.png
    LessMsi/
      lessmsi-gui.exe       (patched GUI)
      lessmsi.exe           (official CLI)
      lessmsi.core.dll      (matching rebuilt Core library)
      mspack.dll            (verified x86 native CAB extractor)
      libmspackn.dll        (CAB extraction .NET wrapper)
      (official dependencies and languages)
  Data/
    Settings/
      lessmsi.settings.xml (created on GUI exit)
  Other/
    Source/
      BUILDER-README.md
      UPSTREAM-LICENSE.txt
      Settings.Designer.cs
      lessmsiPortable.cs
      BUILD-INFO.txt
```

## Upgrade safely

Only overwrite `lessmsiPortable.exe`, `App/`, and `Other/` using files from the new version. **Never replace or delete `Data/`.** Exit lessmsi before upgrading. The builder does not auto-update itself or run by a schedule.

## Important restrictions

- The **Explorer right-click menu registration** is intentionally disabled. Using it would create permanent Windows registry changes.
- MSI viewing and extraction still work. Lessmsi extracts MSI contents; it does **not** make an arbitrary extracted program portable.
- No Windows cleanup is performed; unrelated `AppData`, registry and `IsolatedStorage` content is untouched.
- The root launcher depends on .NET Framework 4.8, just as the upstream application does.
- Source-level patches may need updating if upstream changes how preferences are stored; the build deliberately fails safely rather than silently switching to a nonportable version.
- Windows app execution traces and normal system caches are outside this app's control.

## Fix in v1.1

The v1.0 Windows GitHub run compiled the source successfully but stopped at the upstream post-build `xcopy` of `mspack.dll` (MSB3073, code 4). That `.csproj` uses `$(SolutionDir)` without a fixed value when MSBuild is invoked directly on the project. v1.1 explicitly restores packages to `src/packages`, specifies the solution directory in the MSBuild command, verifies the x86 native dependency before/after compilation, and includes `mspack.dll` and `libmspackn.dll` in the final package. The MSI extraction engine is not disabled or stubbed.

## Verification status

The builder files receive local structural tests. A Windows build, GUI behavior, and exact host-remnant behavior require running the GitHub workflow and checking on a Windows machine. See `docs/TESTING.md`.

## License and credit

Lessmsi is developed by Scott Willeke and contributors under the MIT license. The portable modification is an independent community package; it is not an official PortableApps.com release. Respect upstream license notices and the upstream source repository.
