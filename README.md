<p align="center">
  <img src="https://img.shields.io/badge/Platform-Windows_10%2F11-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/PowerShell-7%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white" alt="PowerShell">
  <img src="https://img.shields.io/badge/Type-Template_Engine-8B5CF6?style=for-the-badge&logo=blueprint&logoColor=white" alt="Template Engine">
  <img src="https://img.shields.io/badge/Dependencies-Zero-2ea44f?style=for-the-badge" alt="Dependencies">
</p>

<h1 align="center">⚙️ InstallerCore</h1>

<p align="center">
  <b>Profile-driven installer generator for Windows context menu tools — one template, many tools</b><br>
  <sub>JSON profile · PowerShell template · Code generation · GitHub integration — build production-ready installers in seconds</sub>
</p>

---

## ✨ What's Inside

| # | Component | Description |
|:-:|-----------|-------------|
| ⬇️ | **[Repo Downloader](#-repo-downloader)** | Root `install.ps1` that refreshes the current `InstallerCore` working copy in place |
| 📄 | **[Template Engine](#-template-engine)** | 750-line PowerShell template with embedded profile marker for code generation |
| 📋 | **[Profile System](#-profile-system)** | JSON profiles that define every tool-specific setting — registry, files, GitHub |
| 🔧 | **[Generator Script](#-generator-script)** | One-command script that merges template + profile into a production installer |

---

## ⬇️ Repo Downloader

> `InstallerCore` itself is special: its root `install.ps1` is not a generated installer and does not install into `%LOCALAPPDATA%`. It is a downloader-only refresh flow for the current repo directory.

### What it does

- Downloads the selected GitHub branch of `joty79/InstallerCore`
- Extracts it to a temp folder
- Verifies the extracted repo shape (`README.md`, `PROJECT_RULES.md`, template, generator)
- Copies the latest files into the directory where `install.ps1` is currently running
- If the target directory starts as a clean git checkout, refreshes git state after the copy so unchanged files do not stay falsely marked as modified

### What it does not do

- no registry writes
- no uninstall entry
- no `%LOCALAPPDATA%` deployment
- no separate install directory
- no automatic relaunch after download

### Usage

```powershell
# Interactive menu
pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1

# Directly refresh the current InstallerCore repo folder
pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Action DownloadLatest

# Refresh from a specific branch
pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Action DownloadLatest -GitHubRef master
```

The target path defaults to `$PSScriptRoot`, so running the script from `D:\Users\joty79\scripts\InstallerCore` refreshes that working copy in place.

---

## 📄 Template Engine

> A single, generic PowerShell template that generates complete install/update/uninstall flows for any context menu tool — driven entirely by an embedded JSON profile.

### The Problem

- Every context menu tool (`WhoIsUsingThis`, `TakeOwnership`, `SystemCleanup`) needs its own `Install.ps1`
- Each installer must handle: **registry writes**, **file deployment**, **GitHub downloads**, **Explorer restart**, **legacy cleanup**, **uninstall entries** — all identically
- Maintaining separate installers per tool leads to **drift** — one gets a fix, others don't
- Testing installer changes requires touching every downstream repo

### The Solution

A single `Install.Template.ps1` with a placeholder marker (`__EMBEDDED_PROFILE_JSON__`) that gets replaced with a tool-specific JSON profile at generation time:

```
┌─────────────────────────────────────────────────────────────┐
│              INSTALLERCORE ARCHITECTURE                      │
│                                                             │
│  profiles/                 templates/                       │
│  ├── WhoIsUsingThis.json   └── Install.Template.ps1         │
│  ├── TakeOwnership.json         │                           │
│  └── SystemCleanup.json         │  __EMBEDDED_PROFILE_JSON__ │
│         │                       │         ▲                  │
│         │    ┌──────────────┐    │         │                  │
│         └──▶ │ New-Tool     │────┘         │                  │
│              │ Installer.ps1│──────────────┘                  │
│              └──────┬───────┘                                │
│                     │                                        │
│                     ▼                                        │
│              WhoIsUsingThis/Install.ps1  (generated)         │
│              TakeOwnership/Install.ps1   (generated)         │
│              SystemCleanup/Install.ps1   (generated)         │
└─────────────────────────────────────────────────────────────┘
```

Every generated installer is a **self-contained, standalone PowerShell script** — no external dependencies, no module imports, no InstallerCore runtime needed.

### Built-in Actions

The template provides these actions out-of-the-box for every generated installer:

| Action | Mode | Description |
|--------|------|-------------|
| `Install` | Interactive | Source chooser (GitHub/Local) → branch picker → deploy → registry → verify |
| `Update` | Interactive | Same as Install, preserves existing data |
| `Uninstall` | Interactive/CLI | Registry cleanup → file removal → Explorer restart |
| `InstallGitHub` | CLI-only | Direct GitHub install (no prompts when used with `-Force`) |
| `UpdateGitHub` | CLI-only | Direct GitHub update |
| `DownloadLatest` | Interactive | Downloads latest files to `$PSScriptRoot` and relaunches |
| `OpenInstallDirectory` | Utility | Opens the install folder in Explorer |
| `OpenInstallLogs` | Utility | Opens the installer log file |

### Template Features

```
┌─────────────────────────────────────────────────────────────┐
│              GENERATED INSTALLER CAPABILITIES                │
│                                                             │
│  📦 Package Resolution                                      │
│     ├─ Local source (files alongside Install.ps1)           │
│     ├─ GitHub codeload (anonymous download)                 │
│     ├─ GitHub API fallback (authenticated via gh auth)      │
│     └─ Local fallback when GitHub is unreachable            │
│                                                             │
│  🔀 Branch Management                                       │
│     ├─ Auto-detect default branch from remote               │
│     ├─ Interactive branch list picker                       │
│     └─ Fallback: master → profile ref → latest             │
│                                                             │
│  🗝️ Registry Management                                     │
│     ├─ Cleanup legacy keys before writing new ones          │
│     ├─ Empty-string write + readback verification           │
│     ├─ Post-install registry verify against expected values │
│     └─ HKCR Access Denied suppression for non-elevated      │
│                                                             │
│  📂 Deployment                                               │
│     ├─ File copy with preserve-existing support             │
│     ├─ Core file verification after deploy                  │
│     ├─ Wrapper script patching ({InstallRoot} replacement)  │
│     └─ Install metadata saved to state/install-meta.json    │
│                                                             │
│  🔄 Explorer Restart                                         │
│     ├─ Clean stop (no zombie processes)                     │
│     ├─ Wait for shell auto-restart                          │
│     └─ Reopen folder via Shell.Application COM               │
│                                                             │
│  📋 Programs & Features                                      │
│     └─ Uninstall entry with DisplayName, Publisher, Version │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 Profile System

> A JSON file that defines everything about a tool's installer — name, files, registry keys, GitHub repo, legacy cleanup — without touching the template.

### Profile Structure

Every profile JSON has these sections:

| Section | Purpose | Example |
|---------|---------|---------|
| `tool_name` | Internal identifier | `"WhoIsUsingThis"` |
| `installer_title` | Display name in menu header | `"WhoIsUsingThis Installer"` |
| `install_folder_name` | Target folder under `%LOCALAPPDATA%` | `"WhoIsUsingThisContext"` |
| `github_repo` | GitHub `owner/repo` for downloads | `"joty79/WhoIsUsingThis"` |
| `app_metadata_file` | Repo-relative JSON metadata file that carries the real shipped app version | `"app-metadata.json"` |
| `github_ref` | Default branch (auto-detected if empty) | `""` |
| `required_package_entries` | Repo-relative runtime files that must exist in the source package | `["Install.ps1", ".assets\\icons\\tool.ico"]` |
| `deploy_entries` | Repo-relative files to copy to install directory | Same as above, plus assets |
| `registry_cleanup_keys` | Legacy keys to delete before install | `["HKCU\\...\\OldKeyName"]` |
| `registry_values` | Keys/values to write during install | `[{key, name, type, value}]` |
| `registry_verify` | Expected values to verify after install | `[{key, name, expected}]` |
| `wrapper_patches` | Regex patches for launcher scripts | `[{file, regex, replacement}]` |
| `uninstall_preserve_files` | Files to keep after uninstall | `["Install.ps1"]` |

### Profile Example (abridged)

```json
{
  "tool_name": "TakeOwnership",
  "installer_title": "TakeOwnership Installer",
  "install_folder_name": "TakeOwnershipContext",
  "github_repo": "joty79/TakeOwnership",
  "github_ref": "",
  "required_package_entries": [
    "Install.ps1",
    "Manage_Ownership.ps1",
    "SilentOwnership.vbs",
    ".assets\\RunAsTI\\RunAsTI.ps1"
  ],
  "registry_cleanup_keys": [
    "HKCU\\Software\\Classes\\*\\shell\\Z_ManageOwnership",
    "HKCU\\Software\\Classes\\*\\shell\\SystemTools\\shell\\TakeOwnership"
  ],
  "registry_values": [
    {
      "key": "HKCU\\Software\\Classes\\*\\shell\\SystemTools\\shell\\TakeOwnership",
      "name": "MUIVerb",
      "type": "REG_SZ",
      "value": "Manage Ownership 🛡️"
    }
  ]
}
```

### Workspace Asset Rule

Generated installers must stay portable across PCs. If a tool depends on any runtime file that currently lives outside the workspace, move that file into the repo before generating the installer, preferably under `.assets`.

Examples:
- icons such as `.ico`
- helper binaries such as `.exe` / `.dll`
- helper scripts copied from another repo
- launcher templates or sidecar files needed at runtime

Rules:
- `required_package_entries`, `deploy_entries`, and `wrapper_patches.file` must be repo-relative paths
- `app_metadata_file`, when present, must also be repo-relative and should normally point at the repo-owned version metadata JSON
- runtime registry commands, icon paths, and wrapper replacements must not contain absolute filesystem paths like `D:\...`
- use repo-local files and reference deployed paths through `{InstallRoot}`
- prefer `.assets\...` for imported runtime dependencies so ownership is obvious

If a profile supplies `app_metadata_file`, the shared template reads the version from that deployed file and uses it as the generated installer's effective version for install metadata / uninstall `DisplayVersion`. This keeps the installer aligned with the actual app version instead of a stale template constant.

### Shared Submenu Rules

Tools that live under the shared **System Tools** context menu follow strict ownership rules:

```
┌──────────────────────────────────────────────────────────────┐
│  SHARED SUBMENU OWNERSHIP                                     │
│                                                               │
│  SystemTools repo (host):                                     │
│    ✅ Creates parent keys: *\shell\SystemTools                 │
│    ✅ Sets MUIVerb, SubCommands, Icon on parent                │
│                                                               │
│  Child profiles (TakeOwnership, WhoIsUsingThis, etc.):        │
│    ✅ Creates only: ...\SystemTools\shell\<ToolVerb>            │
│    ✅ Targeted cleanup of own legacy keys                      │
│    ❌ NEVER creates or modifies parent SystemTools keys         │
│    ❌ NEVER writes empty SubCommands on shared parents          │
└──────────────────────────────────────────────────────────────┘
```

---

## 🔧 Generator Script

> Run one command, get a production-ready, self-contained installer with embedded profile and full parser validation.

### Usage

```powershell
# Generate installer for TakeOwnership
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\New-ToolInstaller.ps1 `
  -ProfilePath .\profiles\TakeOwnership.json `
  -OutputPath D:\Users\joty79\scripts\TakeOwnership\Install.ps1

# Generate installer for WhoIsUsingThis
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\New-ToolInstaller.ps1 `
  -ProfilePath .\profiles\WhoIsUsingThis.json `
  -OutputPath D:\Users\joty79\scripts\WhoIsUsingThis\Install.ps1

# Generate installer for SystemCleanup
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\New-ToolInstaller.ps1 `
  -ProfilePath .\profiles\SystemCleanup.json `
  -OutputPath D:\Users\joty79\scripts\SystemCleanup\Install.ps1
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-TemplatePath` | `string` | `templates\Install.Template.ps1` | Path to the template file |
| `-ProfilePath` | `string` | *(required)* | Path to the tool-specific JSON profile |
| `-OutputPath` | `string` | *(required)* | Where to write the generated `Install.ps1` |

### What Happens During Generation

```
┌───────────────────────────────────────────────────────┐
│  New-ToolInstaller.ps1                                 │
│                                                        │
│  1. Read template     → Install.Template.ps1           │
│  2. Read profile      → TakeOwnership.json             │
│  3. Validate profile  → tool_name, required_entries    │
│  4. Replace marker    → __EMBEDDED_PROFILE_JSON__      │
│  5. Write output      → TakeOwnership/Install.ps1      │
│  6. Parse validate    → Parser::ParseFile (PS7 AST)    │
│     └─ If errors → throw with line number + message    │
└───────────────────────────────────────────────────────┘
```

The generator **fails fast** on parse errors — you'll never ship a broken installer.

---

## 📦 Adding a New Tool

### Step-by-step

1. **Create a profile** — copy an existing profile from `profiles/` and modify the tool-specific values
2. **Define registry keys** — add `registry_cleanup_keys`, `registry_values`, and `registry_verify` for your context menu entries
3. **Internalize runtime files** — if the tool currently depends on files outside the workspace, copy them into the repo first, preferably under `.assets`
4. **List required files** — add every runtime file to `required_package_entries` and `deploy_entries`
5. **Generate** — run `New-ToolInstaller.ps1` with your new profile
6. **Use the generated installer as source-of-truth** — do not hand-write a bespoke repo-local `Install.ps1` once the repo is onboarded
7. **Test** — run the generated `Install.ps1` with `-Action Install -PackageSource Local`

### Checklist for new profiles

- [ ] `tool_name` is unique across all profiles
- [ ] `github_repo` matches the actual GitHub repository
- [ ] No runtime dependency is left outside the workspace; imported files live in `.assets` or another repo-local folder
- [ ] `required_package_entries` lists every file the tool needs at runtime
- [ ] `required_package_entries` / `deploy_entries` use only repo-relative paths
- [ ] `Install.ps1` is generated from `InstallerCore`; no bespoke installer logic is being maintained in the downstream repo
- [ ] `registry_cleanup_keys` includes all legacy key paths (HKCU + HKCR)
- [ ] `registry_values` uses `{InstallRoot}` placeholder for deployed file paths and contains no hardcoded `D:\...` paths
- [ ] `registry_verify` covers at least the command keys
- [ ] If child of System Tools: only child verb keys, no parent keys

---

## 📁 Project Structure

```
InstallerCore/
├── install.ps1                     # Downloader-only self-refresh entrypoint for this repo
├── templates/
│   └── Install.Template.ps1       # 750-line generic installer template
├── profiles/
│   ├── WhoIsUsingThis.json        # Lock scanner tool profile
│   ├── TakeOwnership.json         # Ownership manager tool profile
│   ├── Firewall.json              # Firewall context-menu tool profile
│   ├── RunAsTI.json               # TrustedInstaller context-menu profile
│   ├── SystemCleanup.json         # System cleanup tool profile
│   └── SystemTools.json           # Shared System Tools host profile
├── scripts/
│   └── New-ToolInstaller.ps1      # Profile→template merger + validator
├── PROJECT_RULES.md               # Decision log and project guardrails
├── CHANGELOG.md                   # Notable repo-level changes
└── README.md                      # You are here
```

---

## 🧠 Technical Notes

<details>
<summary><b>Why embed the profile JSON inside the generated script?</b></summary>

Each generated `Install.ps1` must be **completely self-contained** — users clone a tool repo and run the installer directly without needing InstallerCore. Embedding the profile as a heredoc string (`@' ... '@`) means the installer carries all its configuration internally. No external file dependencies, no module imports, no runtime resolution.

`New-ToolInstaller.ps1` enforces this during generation. If a profile contains repo-external absolute paths, generation fails fast and tells you to move those files into the workspace first.

</details>

<details>
<summary><b>Why reg.exe instead of PowerShell registry cmdlets?</b></summary>

PowerShell registry cmdlets (`New-Item`, `Set-ItemProperty`) have issues with **empty-string `REG_SZ` values** and **HKCR merged-view paths**. `reg.exe` handles these edge cases reliably and consistently. The template includes a `RegAdd` helper that writes via `reg.exe` and immediately reads back to verify — failing loudly on mismatches instead of silently continuing.

</details>

<details>
<summary><b>How does the branch auto-detect work?</b></summary>

When no explicit `-GitHubRef` is provided, the template resolves a branch in this priority order: **remote default branch** (via `gh api` or GitHub API), **`master`**, **profile `github_ref` value**, then **`latest`**. It checks each candidate against the actual branch list from the remote. In interactive mode, the branch list is presented as a numbered picker (list-only, no freeform input).

</details>

<details>
<summary><b>Why do child tools never create shared parent keys?</b></summary>

The shared `System Tools` submenu is a cascade menu registered by its own host repo. If multiple child tools each create their own version of the parent `SystemTools` key, they can **overwrite each other's settings** (especially `SubCommands` vs nested `shell\` children). The strict rule: child profiles write only `...\SystemTools\shell\<ToolVerb>` and never touch the parent. This prevents inter-tool conflicts and makes install/uninstall order-independent.

</details>

<details>
<summary><b>How does the Explorer restart avoid zombie processes?</b></summary>

The template uses a clean restart flow: stop Explorer, then **wait for Windows to auto-restart the shell** (via `Winlogon`). It never calls `Start-Process explorer.exe`, which would create a secondary zombie instance. After the shell auto-restarts, it reopens a folder window via `Shell.Application` COM. This matches the behavior of the dedicated `RestartExplorer.ps1` tool.

</details>

---

<p align="center">
  <sub>One template · Many tools · Zero drift · Profile-driven installer generation for Windows context menu tools</sub>
</p>
