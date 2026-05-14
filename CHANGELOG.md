# Changelog

## 2026-05-14

- Removed desktop-background `SystemTools > Windows` entries from the `TakeOwnership` and `WhoIsUsingThis` profiles, removed nested `FirewallRules` from the `SystemTools` host profile, and restored repo-owned `Explorer` / `Windows` category icons.
- Added desktop-background `Power Options` / Safe Mode registry values to the `SystemTools` profile so generated installs and repairs create the SafeMode menu directly under `System Tools`.
- Switched the internal `SystemTools` SafeMode submenu key from `PowerMenu` to `SafeModeOptions` and added cleanup for the earlier key because Explorer did not render `PowerMenu` even when registry readback was correct.
- Moved the `SystemTools` SafeMode submenu under desktop `SystemTools\shell\Windows\shell\SafeModeOptions` after Explorer also refused to display a direct `SafeModeOptions` child despite correct registry readback.
- Flattened the desktop SafeMode/power actions directly under `SystemTools\shell\Windows\shell\z10_BootSafe` through `z15_LogOff` after Explorer hid the nested cascade inside `Windows`.
- Adjusted `SystemTools` single-file menu behavior so wildcard file targets create `Windows` and `z_ToolManager` only, with no `Explorer` shell-action category on files.
- Restored `Firewall` to its top-level `.exe` shell verb and kept cleanup for the temporary nested `SystemTools\shell\Windows\shell\FirewallManager` path.
- Corrected the shared `SystemTools` menu profile so `Explorer` remains the shell-action category, `AppsWindows` becomes `Windows`, ownership/lock tools move under `Windows`, and `Tool Manager / Updates` registers as `z_ToolManager` with a separator before it.
- Updated `WinAppManager`, `SystemCleanup`, and `Firewall` profiles to target the new `Windows` category while cleaning old `AppsWindows` child paths.
- Renamed the shared `SystemTools` utility category from `Explorer` to `Windows Utilities` in the host and child profiles.
- Moved `Tool Manager / Updates` out of the category folder and registered it as a direct child of the shared `System Tools` parent.
- Updated `TakeOwnership` and `WhoIsUsingThis` profiles to target `WindowsUtilities` while cleaning old `Explorer` child paths.
- Fixed generated installers so `wrapper_patches: null` is treated as an empty patch list instead of crashing under `Set-StrictMode`.

## 2026-05-13

- Updated `profiles\SystemTools.json` so host installs preserve the shared `SystemTools` parent registry trees and clean only old host-owned child keys.
- Added `.assets\systemtools-family.json` to the `SystemTools` profile package/verification list for the config-driven family manager.

## 2026-05-12

- Added `SystemToolsManager.ps1` and its launcher to the `SystemTools` profile, with `Tool Manager / Updates` registered under the `Explorer` submenu.
- Updated `SystemTools`, `TakeOwnership`, `WhoIsUsingThis`, `WinAppManager`, `SystemCleanup`, and `Firewall` profiles for the shared `System Tools` category menu layout.
- Moved child tool registry paths under `Explorer` or `AppsWindows` category folders while keeping old flat child paths in cleanup lists for migration.

## 2026-05-11

- Added `scripts\Update-DownstreamInstallers.ps1` to regenerate one or all downstream generated installers from their InstallerCore profiles.
- Updated the `ContextLens` profile to deploy the downstream app-side `ContextLens.ps1` UI.
- Added the `ContextLens` profile for the combined OCR and clipboard image context menu workspace.

All notable changes to `InstallerCore` live here.

## [2026-05-11]

### Fixed

- Updated the generated installer template to write/read registry values through `Microsoft.Win32.RegistryKey`, preserving Unicode menu labels and raw `REG_EXPAND_SZ` strings during verification.

## [2026-05-10]

### Changed

- Tightened `docs\IN_APP_UPDATE_UI_CONTRACT.md` so downstream app-side update UIs must reject stale cached `UpToDate` results when a fresh remote check fails.
- Added private-repo git-backed metadata fallback to the in-app update UI contract, matching the current `WinAppManager` canonical behavior.
- Updated `scripts\Sync-InstallerCore.ps1` to verify the new stale-cache and git-fallback contract markers.
- Updated the generated installer template so explicit GitHub package updates try a git clone fallback when archive/API download fails, and no longer report success by falling back to the already-installed local folder.
- Added git-backed branch/default detection so private repositories reachable through git credentials do not produce a false warning before `UpdateGitHub`.

## [2026-05-09]

### Added

- Added `scripts\Sync-InstallerCore.ps1` so other PCs can fast-forward `InstallerCore` from `origin/master` and verify the update UI contract/template in one command.

### Changed

- Updated `docs\IN_APP_UPDATE_UI_CONTRACT.md` with the current commit-aware update status requirements: installed copies compare `install-meta.json` `github_commit` to the remote branch commit, same-version commit mismatch is update-available, stale cached `UpToDate` results must be invalidated, and git working-copy updates must use git semantics instead of archive overlay.
- Updated the README with the preferred cross-PC update command for normal git checkouts.

## [2026-04-24]

### Added

- Added `docs\IN_APP_UPDATE_UI_CONTRACT.md` to define the downstream app-side `Update app` behavior that generated installers do not provide automatically.
- Added the `UPDATEUI` shorthand convention for asking Codex to apply the in-app update UI contract without pasting the full prompt.
- Updated `profiles/SystemTools.json` to package and register the new `Clear Icon Cache` context-menu tool with its dedicated icon and elevated launcher.

### Changed

- Updated `profiles/TakeOwnership.json` to deploy and verify `app-metadata.json`, allowing the downstream tool to use the current app metadata/update-status contract while staying generated from `InstallerCore`.
- Updated `profiles/WhoIsUsingThis.json` to deploy and verify `app-metadata.json`, allowing the downstream scanner to use the current in-app update status contract after regeneration.
- Documented that downstream apps must implement update status, progress output, relaunch, and old-host exit through an app-specific adapter after `Install.ps1` regeneration.

## [2026-04-22]

### Changed

- Generated installers now record resolved GitHub/local git commit metadata in `state\install-meta.json`, including `github_commit`, `source_git_branch`, and `source_dirty`, so downstream in-app update UIs can detect same-version hotfixes.

### Fixed

- Updated generated installer confirmations to treat `$null` `Read-Host` responses as cancellation, preventing non-interactive hosts from crashing on `.Trim()`.
- Changed generated `-NoExplorerRestart` handling to log the intentional skip as informational instead of warning/failure state, so scripted `Install`/`Update` verification can return exit code `0`.


## [2026-04-16]

### Changed

- Added profile-level `app_metadata_file` support so generated installers can read the real shipped app version from a repo-owned metadata JSON instead of relying on a stale template constant.
- Updated `scripts/New-ToolInstaller.ps1` to validate `app_metadata_file` as a repo-relative path, keeping the new version contract portable across machines.
- Updated `profiles/WinAppManager.json` to deploy and verify `app-metadata.json`, then regenerated the downstream `WinAppManager\Install.ps1` so install metadata and uninstall `DisplayVersion` follow the app's actual version.
- Updated `profiles/SystemCleanup.json` to match the modern PowerShell launcher contract: deploy/verify `app-metadata.json`, `SystemCleanup.ps1`, `FullCleanup.cmd`, and `ManageUpdates.ps1`, and register `SystemCleanup.ps1` as the primary context-menu entrypoint.
- Updated `profiles/SystemCleanup.json` again to use a shipped `Launch-SystemCleanup.vbs` hidden launcher, so Explorer context-menu launches hand off directly to `WT/pwsh` without flashing an intermediate PowerShell window.

## [2026-04-15]

### Changed

- Updated the shared `DownloadLatest` relaunch flow so generated installers now preserve the current host family: `WT` sessions relaunch in a fresh `WT` window, while plain `pwsh` sessions relaunch in plain `pwsh`.
- Updated `RunDownloadLatest()` to treat the working-copy target root as the active log/install root during the download, so embedded in-app updater panels tail the correct `logs\installer.log` for workspace updates.
- Updated `profiles/WinAppManager.json` so the child `System Tools` verb now deploys and verifies the repo-owned `assets\MsStore.ico` icon instead of using the generic `shell32.dll` fallback.
- Updated `profiles/WinAppManager.json` so the shipped `profiles` folder is treated as real package content (`required` + `deploy`) instead of migration-only state, allowing installed copies to receive the repo-owned profile JSONs by default.

## [2026-04-14]

### Added

- Added `profiles/WinAppManager.json` so `WinAppManager` can use the shared `InstallerCore` install/update/uninstall flow instead of maintaining a bespoke repo-local installer.
- Extended the `WinAppManager` profile with child-only `System Tools` registry integration and a patched `Launch-WinAppManager.vbs` launcher for elevated context-menu startup.

### Changed

- Updated the shared install template to skip same-path self-copy deploy entries and to copy directory contents into existing targets instead of nesting sibling folders like `Modules\Modules` during update/install runs.
- Added `-NoSelfRelaunch` to the shared installer template so embedded app updaters can run `DownloadLatest` inside the current TUI without spawning a second installer window.

## [2026-03-12]

### Added

- Added a root `install.ps1` for `InstallerCore` as a downloader-only self-refresh workflow for the current repo directory.
- Documented that the root downloader updates the current working copy in place and does not perform `%LOCALAPPDATA%` installation, uninstall registration, or registry writes.

### Fixed

- Updated the root downloader to skip rewriting files that are already byte-identical, reducing false dirty git state after refreshing an already synced local repo checkout.
- Updated the root downloader to refresh git state automatically for already-clean repo checkouts, so unchanged files do not remain falsely marked as modified after download.
- Updated the root downloader to finish in place after download instead of relaunching itself automatically.
