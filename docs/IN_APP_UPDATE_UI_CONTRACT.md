# In-App Update UI Contract

## Purpose

`InstallerCore` provides the generated installer backend: install, update, uninstall, GitHub/local package resolution, logging, metadata, and relaunch flags.

It does not automatically provide the downstream app UI. Every app that exposes `Update app` inside its own script must implement this separate app-side contract.

## Non-Negotiable Rule

Updating an `InstallerCore` profile or regenerating `Install.ps1` is not a complete downstream update integration unless the app-side update UI contract is also checked.

Minimal code is good. Partial template parity is a bug.

## Canonical Reference

Use `WinAppManager` as the current canonical behavior reference for rich `WT + pwsh7` apps:

- `WinAppManager\Modules\ReviewUI.ps1`
- `WinAppManager\Modules\UiCommon.ps1`
- `WinAppManager\PROJECT_RULES.md`

The implementation may be adapted to the downstream host, but the behavior contract must remain intact unless a documented app-specific exception says otherwise.

## Required Behavior

Every downstream in-app updater should do these things:

- load app identity/version/repo from `app-metadata.json` when the app uses the metadata contract
- show version/update status in the app header or main status area
- expose an `Update app` entry inside the app UI, not only in `Install.ps1`
- resolve whether the app is running from the installed copy or from a repo working copy
- use the generated `Install.ps1` as the backend instead of duplicating installer logic
- use `UpdateGitHub` for installed-copy updates
- use `DownloadLatest -NoSelfRelaunch` or a repo-aware workspace update path for working-copy updates
- run the updater inside the current app session
- show visible update progress while the updater process is running
- show recent installer output from `logs\installer.log`
- show failure output and exit code when update fails
- on success, relaunch the updated app host
- close or exit the old app host after a successful relaunch

## Required Installer Flags

Embedded app updaters should use these generated installer flags where applicable:

| Scenario | Action | Required flags |
|----------|--------|----------------|
| Installed app copy | `UpdateGitHub` | `-Force -NoExplorerRestart` |
| Repo/working-copy app | `DownloadLatest` | `-Force -NoSelfRelaunch` |
| Local verification smoke | `Update` | `-PackageSource Local -Force -NoExplorerRestart` |

`-NoSelfRelaunch` means the generated installer updates files and returns control to the app. The app owns progress UI, app relaunch, and old-host shutdown.

## Adapter Families

### WT TUI Adapter

Use this for apps whose normal host is Windows Terminal with a resize-safe PowerShell TUI.

Expected behavior:

- synchronized/full-frame progress panel
- recent output section
- restart in a fresh `WT` tab/window when already inside WT
- fallback to plain `pwsh` if WT is unavailable

Canonical reference: `WinAppManager`.

### Plain pwsh Adapter

Use this for apps that cannot safely bootstrap through Windows Terminal.

Expected behavior:

- plain `pwsh` UI is acceptable
- no WT-only assumptions
- still shows progress, recent output, success/failure, relaunch, and old-host exit

Known use: `TakeOwnership`, because its RunAsTI launch chain is special.

### Host-Specific Adapter

Use this when the downstream app has a custom host flow.

Required before implementation:

- name the adapter family in the downstream `PROJECT_RULES.md`
- list what behavior is inherited from this contract
- list any explicit exceptions
- verify the exceptions are due to host constraints, not convenience

## Downstream Implementation Checklist

Before editing a downstream app:

- [ ] Read this contract.
- [ ] Read the downstream `PROJECT_RULES.md`.
- [ ] Identify the canonical reference or adapter family.
- [ ] List required behaviors that must be copied.
- [ ] List app-specific exceptions.
- [ ] Confirm `Install.ps1` is generated from `InstallerCore`.
- [ ] Confirm `app-metadata.json` is deployed when update status depends on it.

After editing:

- [ ] Parser validation passed for edited `.ps1` files.
- [ ] Generated installer was regenerated when profile/template changed.
- [ ] Local-source installer smoke completed where safe.
- [ ] Installed files match repo files after update smoke.
- [ ] Update UI has progress panel and recent output.
- [ ] Success path relaunches the app host.
- [ ] Old host exits after successful relaunch.
- [ ] Any unverified elevated/interactive path is called out explicitly.

## How To Ask For This In A Downstream App

Preferred short aliases:

```text
UPDATEUI
```

Use the default adapter from the downstream project rules, or `WinAppManager` as the canonical reference when no exception exists.

```text
UPDATEUI: WT
```

Use the `WinAppManager` / Windows Terminal TUI adapter.

```text
UPDATEUI: plain-pwsh
```

Use the plain PowerShell adapter. Do not add a Windows Terminal bootstrap.

```text
UPDATEUI: host-specific
```

Use a custom adapter, but first document the inherited behavior and explicit exceptions in the downstream `PROJECT_RULES.md`.

Long-form wording:

```text
Apply the InstallerCore update integration to this app using the In-App Update UI Contract. Use WinAppManager as the canonical behavior reference unless this app has a documented host-specific exception. Regenerate Install.ps1 from InstallerCore if needed, then implement and verify the app-side Update app UI: header status, progress panel, recent installer output, relaunch, and old-host exit.
```

For apps like `TakeOwnership`, add:

```text
This app must use the plain-pwsh adapter. Do not add a Windows Terminal bootstrap because the RunAsTI launch chain is special.
```
