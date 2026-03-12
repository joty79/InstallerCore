# Changelog

All notable changes to `InstallerCore` live here.

## [2026-03-12]

### Added

- Added a root `install.ps1` for `InstallerCore` as a downloader-only self-refresh workflow for the current repo directory.
- Documented that the root downloader updates the current working copy in place and does not perform `%LOCALAPPDATA%` installation, uninstall registration, or registry writes.

### Fixed

- Updated the root downloader to skip rewriting files that are already byte-identical, reducing false dirty git state after refreshing an already synced local repo checkout.
- Updated the root downloader to refresh git state automatically for already-clean repo checkouts, so unchanged files do not remain falsely marked as modified after download.
