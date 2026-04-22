# Changelog

All notable changes to `InstallerCore` live here.

## [2026-04-22]

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
