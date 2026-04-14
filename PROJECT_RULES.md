# PROJECT_RULES - InstallerCore

## Scope
- Repo: `D:\Users\joty79\scripts\InstallerCore`
- Purpose: shared installer template + profile-driven generation for multiple tool repos.

## Guardrails
- Keep `templates/Install.Template.ps1` generic and profile-driven.
- Do not hardcode tool-specific registry keys/paths in template logic.
- Tool-specific decisions belong in `profiles/*.json`.
- Generated installers must keep action flow parity: Install/Update/Uninstall/Open actions, metadata, registry write+verify, and uninstall entry.
- Generated installers must not depend on runtime files outside the tool workspace. Move imported icons, binaries, helper scripts, and sidecar files into the repo first, preferably under `.assets`, and reference only repo-local paths or `{InstallRoot}` in profiles.
- Once a tool repo is onboarded to `InstallerCore`, do not hand-write or maintain a bespoke repo-local `Install.ps1`. Regenerate `Install.ps1` from the template/profile pair and make template/profile fixes at the source.

## Decision Log

### Entry - 2026-02-26
- Date: 2026-02-26
- Problem: Rebuilding installer logic per repo was repetitive and error-prone.
- Root cause: No shared source-of-truth for installer behavior.
- Guardrail/rule: Introduce a dedicated InstallerCore repo with template + profile + generator workflow.
- Files affected: `templates/Install.Template.ps1`, `profiles/WhoIsUsingThis.json`, `scripts/New-ToolInstaller.ps1`.
- Validation/tests run: Generator output parse validation via `Parser::ParseFile` on generated installer.

### Entry - 2026-02-26 (TakeOwnership)
- Date: 2026-02-26
- Problem: New tool (`TakeOwnership`) needed installer parity without template forking.
- Root cause: Tool-specific registry/required files were not modeled yet in InstallerCore profiles.
- Guardrail/rule: Add one profile per tool and generate installers; keep template generic and move all tool specifics into profile JSON.
- Files affected: `profiles/TakeOwnership.json`.
- Validation/tests run: Installer generation completed via `scripts/New-ToolInstaller.ps1` and parser validation passed on generated `TakeOwnership\Install.ps1`.

### Entry - 2026-02-26 (HKCR cleanup permissions)
- Date: 2026-02-26
- Problem: Cleanup of HKCR context-menu keys can fail with Access Denied for non-elevated installs, causing noisy warnings.
- Root cause: HKCR merged-view keys may require elevated rights even when HKCU keys are the actual source.
- Guardrail/rule: Keep HKCR cleanup attempts, but suppress Access Denied warnings for HKCR-only cleanup failures to avoid false-negative installer outcomes.
- Files affected: `templates/Install.Template.ps1`.
- Validation/tests run: Parser validation passed for template; regenerated TakeOwnership installer validated by parser.

### Entry - 2026-02-26 (InstallerCore bootstrap script)
- Date: 2026-02-26
- Problem: InstallerCore lacked a single entry-point script for consistent local bootstrap/update workflows.
- Root cause: Repo setup relied on manual clone/pull commands.
- Guardrail/rule: Keep a root `install.ps1` that standardizes `Install`, `Update`, `Uninstall`, and `Open` actions against the GitHub repo/branch parameters.
- Files affected: `install.ps1`.
- Validation/tests run: `Parser::ParseFile` validation passed for `install.ps1`.

### Entry - 2026-02-26 (SystemCleanup profile onboarding)
- Date: 2026-02-26
- Problem: `dism` workspace needed to migrate into template-driven installer flow with explicit file ownership.
- Root cause: Context-menu tool files existed without an InstallerCore profile contract.
- Guardrail/rule: Add a dedicated `SystemCleanup` profile and keep Desktop background menu keys under `HKCU\Software\Classes\DesktopBackground\Shell\SystemCleanup` with HKCR cleanup fallback only.
- Files affected: `profiles/SystemCleanup.json`.
- Validation/tests run: Profile rendered into generated installer via `scripts/New-ToolInstaller.ps1`; generated script parser validation passed.

### Entry - 2026-03-01 (Restore branch list picker in template)
- Date: 2026-03-01
- Problem: Generated installers exposed only a plain `GitHub branch/ref` prompt, while branch list selection existed in working installers such as `Robocopy`.
- Root cause: `InstallerCore` template kept a simplified `ReadRefInteractive` implementation and dropped branch enumeration UX.
- Guardrail/rule: `templates/Install.Template.ps1` must offer branch list selection when GitHub branch enumeration succeeds, with manual ref input as fallback; this is template-level behavior, not per-tool custom logic.
- Files affected: `templates/Install.Template.ps1`, `PROJECT_RULES.md`.
- Validation/tests run: `Parser::ParseFile` on template after edit; static comparison against `Robocopy\Install.ps1` branch picker flow.

### Entry - 2026-03-02 (Clean Explorer restart flow in template)
- Date: 2026-03-02
- Problem: Installers used a naive `Stop-Process explorer` + `Start-Process explorer.exe` restart, which can create secondary zombie `explorer.exe` processes and lose the user's working folder window.
- Root cause: Template restart logic forced a new Explorer process instead of letting Windows auto-restore the shell and reopening a folder through `Shell.Application`.
- Guardrail/rule: `templates/Install.Template.ps1` must use the clean Explorer restart flow: stop Explorer, wait for shell auto-restart, never `Start-Process explorer.exe`, and reopen a safe folder path via `Shell.Application` COM when available.
- Files affected: `templates/Install.Template.ps1`, `PROJECT_RULES.md`.
- Validation/tests run: `Parser::ParseFile` on template after edit; static comparison against `SystemTools\RestartExplorer.ps1` restart flow.

### Entry - 2026-03-02 (GitHub ref autodetect in template)
- Date: 2026-03-02
- Problem: Generated installers still depended on a fixed `github_ref` even after branch-list UX was restored, so test branches like `latest` required manual/profile edits.
- Root cause: Template resolved GitHub source from `github_ref` only and had no branch autodetect fallback.
- Guardrail/rule: `templates/Install.Template.ps1` must autodetect GitHub ref when `-GitHubRef` is not explicitly provided, in this priority order: remote default branch, `master`, profile value, then `latest`; branch list UI must use the autodetected ref as its default.
- Files affected: `templates/Install.Template.ps1`, `PROJECT_RULES.md`.
- Validation/tests run: Generator output parse validation on regenerated `WhoIsUsingThis\Install.ps1`; static inspection for autodetect + branch-list flow.

### Entry - 2026-03-02 (Shared submenu profiles must emit valid host parents per branch)
- Date: 2026-03-02
- Problem: A generated tool profile broke the shared `System Tools` submenu after moving a verb under a nested child key.
- Root cause: The shared host submenu existed only on `Directory\Background\shell`; generated profile did not create valid `*\shell\SystemTools` and `Directory\shell\SystemTools` cascade parents for file/folder branches.
- Guardrail/rule: In `InstallerCore` profiles, when a tool is installed under a shared submenu on new branches, emit full valid parent keys for those branches (`MUIVerb`, `SubCommands`, `Icon`) before nested child verbs.
- Files affected: `profiles/WhoIsUsingThis.json`, `PROJECT_RULES.md`.
- Validation/tests run: Static profile review plus live registry query of installed `SystemTools` branches; regenerated installer expected to include valid file/folder parent writes.

### Entry - 2026-03-02 (Shared submenu children must be child-only)
- Date: 2026-03-02
- Problem: Multiple child-tool profiles (`WhoIsUsingThis`, `TakeOwnership`) repeated the same failure pattern by writing their own `SystemTools` parent keys, which broke the shared cascade when more than one tool participated.
- Root cause: Template/profile design blurred submenu ownership, so child tools tried to act as both host and child on `*\shell\SystemTools` and `Directory\shell\SystemTools`.
- Guardrail/rule: In `InstallerCore`, shared-submenu child tools must emit only child verb keys under existing host branches (`...\SystemTools\shell\<ToolVerb>`). Parent `SystemTools` keys are owned exclusively by the host repo (`SystemTools`) and must not be generated by child profiles.
- Files affected: `profiles/WhoIsUsingThis.json`, `profiles/TakeOwnership.json`, `PROJECT_RULES.md`.
- Validation/tests run: Static profile review after removing parent key writes; regenerated child installers expected to contain only nested child verb writes.

### Entry - 2026-03-02 (Remove InstallerCore bootstrap installer)
- Date: 2026-03-02
- Problem: Root `install.ps1` installed `InstallerCore` into `$HOME\scripts\InstallerCore`, which did not match the `%LOCALAPPDATA%` install pattern of generated installers and created a misleading uninstall flow.
- Root cause: The bootstrap script was a repo self-installer with different lifecycle semantics than generated tool installers, but it looked like part of the same installer system.
- Guardrail/rule: `InstallerCore` should not ship a root bootstrap `install.ps1`; keep this repo focused on template/profile/generator source-of-truth and avoid a separate self-installer UX.
- Files affected: `install.ps1`, `PROJECT_RULES.md`.
- Validation/tests run: Static review of root `install.ps1` install target and uninstall behavior; confirmed no registry writes were present.

### Entry - 2026-03-02 (Fail fast on empty-string registry writes)
- Date: 2026-03-02
- Problem: Generated installers still carried the same empty-string `reg.exe` write pattern that previously broke `SystemTools` host install semantics.
- Root cause: Template helper `RegAdd` converted empty strings to literal `""` and had no readback verification, so a sensitive registry write could silently diverge from the intended empty-string value.
- Guardrail/rule: In `InstallerCore`, empty-string registry writes must use the real empty value and immediately verify by readback for `REG_SZ`/`REG_EXPAND_SZ`; template helpers must fail loudly on mismatch instead of silently continuing.
- Files affected: `templates/Install.Template.ps1`, `PROJECT_RULES.md`.
- Validation/tests run: Template parser validation; regenerated `WhoIsUsingThis\Install.ps1` and `TakeOwnership\Install.ps1`; targeted scan confirmed the old literal `""` pattern was removed from template/generated installers.

### Entry - 2026-03-02 (SystemCleanup moved under desktop System Tools host)

- Date: 2026-03-02
- Problem: `SystemCleanup` needed current template behavior and integration under the shared `System Tools` submenu without changing its desktop-background interaction surface.
- Root cause: The profile still generated a standalone `DesktopBackground\Shell\SystemCleanup` verb and an old installer snapshot with pre-hardening helper behavior.
- Guardrail/rule: `SystemCleanup` is a child-only desktop-background tool under `HKCU\Software\Classes\DesktopBackground\Shell\SystemTools\shell\SystemCleanup`. Parent `DesktopBackground\Shell\SystemTools` is owned by the `SystemTools` repo, not by the child profile.
- Files affected: `profiles/SystemCleanup.json`, `PROJECT_RULES.md`.
- Validation/tests run: Regenerated `SystemCleanup\Install.ps1`; parser validation on generated installer; static review of child-only desktop-background registry paths.

### Entry - 2026-03-02 (Interactive installers must support Local and GitHub sources)
- Date: 2026-03-02
- Problem: Generated installers exposed only GitHub flow in the interactive `Install`/`Update` menu, even though CLI already supported `-PackageSource Local`.
- Root cause: Template `switch ($Action)` hard-overrode `PackageSource` to `GitHub` for `Install` and `Update`, so local testing existed only as a hidden CLI path.
- Guardrail/rule: In `InstallerCore`, interactive `Install` and `Update` must ask for package source (`Local` or `GitHub`) and default to `Local`. Keep `InstallGitHub` and `UpdateGitHub` as explicit GitHub-only actions for non-interactive use.
- Files affected: `templates/Install.Template.ps1`, `PROJECT_RULES.md`.
- Validation/tests run: Parser validation on template after edit; static review of action flow to confirm `PackageSource` is no longer hard-forced to `GitHub` for generic interactive install/update.

### Entry - 2026-03-03 (Interactive source chooser defaults to GitHub)
- Date: 2026-03-03
- Problem: Interactive installers needed GitHub as the first/default source choice instead of Local.
- Root cause: The initial source chooser fix defaulted to `Local`, which added the missing option but did not match the desired everyday workflow.
- Guardrail/rule: In `InstallerCore`, interactive `Install` and `Update` must present `GitHub` as option `[1]` and as the default selection. Keep `Local` available as option `[2]` and keep CLI `-PackageSource` overrides intact.
- Files affected: `templates/Install.Template.ps1`, `PROJECT_RULES.md`.
- Validation/tests run: Parser validation on template after edit; regenerated downstream installers for parser validation.

### Entry - 2026-03-03 (WhoIsUsingThis profile must include background branches)
- Date: 2026-03-03
- Problem: Regenerating `WhoIsUsingThis\Install.ps1` from `InstallerCore` silently removed background support, so local installer tests did not reproduce the manual `.reg` behavior.
- Root cause: The source-of-truth profile `profiles/WhoIsUsingThis.json` still defined only file and folder child verbs; the repo-local manual fix for `Directory\\Background` and `DesktopBackground` had never been propagated back into `InstallerCore`.
- Guardrail/rule: When a generated installer gains new registry branches, update the `InstallerCore` profile first, then regenerate the downstream installer. `WhoIsUsingThis` must include child-only entries for `Directory\\Background\\shell\\SystemTools\\shell\\WhoIsUsingThis` and `DesktopBackground\\Shell\\SystemTools\\shell\\WhoIsUsingThis`.
- Files affected: `profiles/WhoIsUsingThis.json`, `PROJECT_RULES.md`.
- Validation/tests run: Static profile review after edit; regenerated `WhoIsUsingThis\Install.ps1`; parser validation on generated installer.

### Entry - 2026-03-03 (TakeOwnership profile must include background branches)
- Date: 2026-03-03
- Problem: `TakeOwnership` still did not appear on folder background or desktop background, even with the manual `.reg` check.
- Root cause: The source-of-truth profile `profiles/TakeOwnership.json` only defined file and folder child verbs, and the manual `.reg` had the same gap.
- Guardrail/rule: `TakeOwnership` must include child-only entries for `Directory\\Background\\shell\\SystemTools\\shell\\TakeOwnership` and `DesktopBackground\\Shell\\SystemTools\\shell\\TakeOwnership`, using `%V` for the background target path and preserving `NoWorkingDirectory`.
- Files affected: `profiles/TakeOwnership.json`, `PROJECT_RULES.md`.
- Validation/tests run: Static profile review after edit; regenerated `TakeOwnership\\Install.ps1`; parser validation on generated installer.

### Entry - 2026-03-03 (Restore Download Latest local sync action)
- Date: 2026-03-03
- Problem: Generated installers no longer exposed the `DownloadLatest` local working-copy sync action, so downstream repos regenerated from `InstallerCore` lost the new menu item and relaunch flow.
- Root cause: The current template snapshot had drifted behind the intended action set and no longer contained the previously added `DownloadLatest` block.
- Guardrail/rule: `templates/Install.Template.ps1` must keep a `DownloadLatest` action that downloads GitHub content into `$PSScriptRoot`, skips install side effects, appears directly below `Uninstall` in the interactive menu, and relaunches the updated `Install.ps1`.
- Files affected: `templates/Install.Template.ps1`, `PROJECT_RULES.md`.
- Validation/tests run: Parser validation on template after restore; downstream regenerate required to pick up the restored action.

### Entry - 2026-03-03 (Branch picker is list-only)
- Date: 2026-03-03
- Problem: The interactive branch picker exposed an unnecessary manual ref path (`M`) even though the desired workflow is strict branch-list selection.
- Root cause: Template branch picker mixed two UX modes: enumerated branch selection and free-form ref entry.
- Guardrail/rule: In `InstallerCore`, interactive GitHub ref selection is list-only. If branch enumeration succeeds, allow only number selection or Enter for the default branch. If branch enumeration fails, fall back to the resolved default ref instead of prompting for arbitrary manual input.
- Files affected: `templates/Install.Template.ps1`, `PROJECT_RULES.md`.
- Validation/tests run: Parser validation on template after edit; downstream regenerate required to pick up the simplified branch picker.

### Entry - 2026-03-03 (SystemCleanup profile must include Directory Background branch)
- Date: 2026-03-03
- Problem: `SystemCleanup` local `.reg` and installer behavior had already expanded to `Directory\\Background\\shell\\SystemTools\\shell\\SystemCleanup`, but the `InstallerCore` source-of-truth profile still only modeled `DesktopBackground`.
- Root cause: The repo-local background support fix in `SystemCleanup` was never propagated back into `profiles/SystemCleanup.json`, so blind regenerate from `InstallerCore` would drop valid background support.
- Guardrail/rule: Keep `profiles/SystemCleanup.json` aligned with the current manual `.reg` contract. `SystemCleanup` must define both `Directory\\Background\\shell\\SystemTools\\shell\\SystemCleanup` and `DesktopBackground\\Shell\\SystemTools\\shell\\SystemCleanup` child-only branches in cleanup, write, and verify sections.
- Files affected: `profiles/SystemCleanup.json`, `PROJECT_RULES.md`.
- Validation/tests run: Static comparison against `SystemCleanup\\SystemCleanup.reg`; profile review after edit.

### Entry - 2026-03-09 (SystemTools host profile onboarding)
- Date: 2026-03-09
- Problem: `SystemTools` still lacked a template-generated installer, so host-menu deployment stayed split between repo-local scripts and manual path assumptions.
- Root cause: `InstallerCore` had profiles only for child tools; the shared host repo had no profile encoding its canonical parent keys, built-in child verbs, and launcher patch requirements.
- Guardrail/rule: Keep a dedicated `profiles/SystemTools.json` for the host repo. It must recreate the canonical `SystemToolsMenu.reg` structure on `*`, `Directory`, `Directory\\Background`, and `DesktopBackground`, verify empty-string `SubCommands`, and patch hardcoded VBS launcher script paths to `{InstallRoot}` after deploy.
- Files affected: `profiles/SystemTools.json`, `PROJECT_RULES.md`.
- Validation/tests run: Generated `D:\\Users\\joty79\\scripts\\SystemTools\\Install.ps1` via `scripts\\New-ToolInstaller.ps1`; PowerShell parser validation passed on generated installer.

### Entry - 2026-03-09 (Fail fast on external runtime asset paths)
- Date: 2026-03-09
- Problem: Tool repos can still hide runtime dependencies outside their own workspace, which makes generated installers non-portable on another PC when icons or helper files are missing.
- Root cause: `InstallerCore` documented self-contained installers, but the generator did not validate repo-external absolute paths in profile file lists, registry values, or wrapper replacements.
- Guardrail/rule: At installer-authoring time, import external runtime dependencies into the tool repo first, preferably under `.assets`. `scripts/New-ToolInstaller.ps1` must fail fast when profiles use absolute filesystem paths for runtime/deploy entries or installer-facing strings; deployed references must resolve through repo-relative paths and `{InstallRoot}`.
- Files affected: `scripts/New-ToolInstaller.ps1`, `README.md`, `PROJECT_RULES.md`.
- Validation/tests run: PowerShell parser validation on `scripts/New-ToolInstaller.ps1`; generator smoke test against existing `profiles/SystemTools.json`.

### Entry - 2026-03-09 (RunAsTI profile onboarding + registry-path validator fix)
- Date: 2026-03-09
- Problem: `RunAsTI` needed a real template-generated installer/profile, and the new absolute-path validator falsely rejected its embedded TI payload because the payload contains `\Registry\User\...` strings that are registry literals, not filesystem paths.
- Root cause: `RunAsTI` existed only as repo-local `.reg`/wrapper logic with machine-specific icon/script paths, and the validator heuristic treated any leading backslash path-like literal as a filesystem path.
- Guardrail/rule: Keep `profiles/RunAsTI.json` as the source-of-truth profile for `RunAsTI`, with repo-owned `.assets` icons and `{InstallRoot}` command/icon paths. In `scripts/New-ToolInstaller.ps1`, absolute-path validation must fail on drive-letter filesystem paths while allowing registry payload literals such as `\Registry\User\...`.
- Files affected: `profiles/RunAsTI.json`, `scripts/New-ToolInstaller.ps1`, `README.md`, `PROJECT_RULES.md`.
- Validation/tests run: Generated `RunAsTI` installer from `profiles/RunAsTI.json` via `scripts\New-ToolInstaller.ps1`; parser validation passed on `scripts/New-ToolInstaller.ps1`; static checks confirmed generated installer still contains interactive package-source chooser and branch picker.

### Entry - 2026-03-09 (No bespoke Install.ps1 after onboarding)
- Date: 2026-03-09
- Problem: An onboarded repo drifted into a hand-written `Install.ps1`, which dropped standard template behaviors such as interactive `Local/GitHub` source selection and the branch picker.
- Root cause: The repo received direct installer edits locally instead of treating `InstallerCore` template + profile as the only source of truth for installer behavior.
- Guardrail/rule: After a tool repo is onboarded to `InstallerCore`, do not maintain a bespoke repo-local `Install.ps1`. Fix behavior in `templates/Install.Template.ps1` or `profiles/<Tool>.json`, then regenerate the downstream installer.
- Files affected: `PROJECT_RULES.md`, `README.md`.
- Validation/tests run: Documentation/rule update only.

### Entry - 2026-03-09 (Firewall profile onboarding)
- Date: 2026-03-09
- Problem: `Firewall` needed a portable installer for VM use, but the repo had only a script and a manual `.reg` file pointing at machine-local script/icon paths.
- Root cause: No `InstallerCore` profile existed for `Firewall`, and the required icon still lived outside the workspace.
- Guardrail/rule: Keep `profiles/Firewall.json` as the source of truth for `Firewall`. Import the icon into the repo under `.assets`, deploy it with the installer, and patch the shipped `.reg` artifact to `{InstallRoot}` paths after install.
- Files affected: `profiles/Firewall.json`, `PROJECT_RULES.md`.
- Validation/tests run: Generated `D:\\Users\\joty79\\scripts\\Firewall\\Install.ps1` via `scripts\\New-ToolInstaller.ps1`; PowerShell parser validation passed on generated installer.

### Entry - 2026-03-12 (Downloader-only root install.ps1 for InstallerCore)
- Date: 2026-03-12
- Problem: `InstallerCore` still needed a convenient self-update entrypoint in the repo root, but the old bootstrap installer model was misleading because this repo is the template source-of-truth, not an app installed under `%LOCALAPPDATA%`.
- Root cause: The earlier rule removed `install.ps1` entirely to avoid install/uninstall semantics, which also removed a practical in-place refresh path for the repo itself.
- Guardrail/rule: `InstallerCore` may ship a root `install.ps1` only as a downloader-only self-refresh workflow. It must update the current repo directory in place, use GitHub branch autodetect/list selection like the template, and must not perform registry writes, uninstall registration, or separate install-directory deployment.
- Files affected: `install.ps1`, `README.md`, `PROJECT_RULES.md`, `CHANGELOG.md`
- Validation/tests run: PowerShell parser validation on `install.ps1`; static review of downloader-only action set and README usage guidance.

### Entry - 2026-03-12 (Downloader must refresh git state for clean checkouts)
- Date: 2026-03-12
- Problem: Running the downloader against an already clean local `InstallerCore` checkout still left tracked files falsely marked as modified, even when the file bytes matched `HEAD`.
- Root cause: Updating files outside git left the repo's working-tree/index state stale until a manual `git add -A`, despite no logical content change.
- Guardrail/rule: If the target directory starts as a clean git checkout, the root downloader must refresh git state after copying and must not leave staged changes behind.
- Files affected: `install.ps1`, `README.md`, `PROJECT_RULES.md`, `CHANGELOG.md`
- Validation/tests run: Local reproduction on a clean `InstallerCore` checkout; byte-level compare against `HEAD`; verified that `git add -A` cleared the false-dirty state before automating that refresh.

### Entry - 2026-03-12 (Downloader should not relaunch itself)
- Date: 2026-03-12
- Problem: After finishing a local self-refresh, the root downloader reopened itself automatically, which added unnecessary extra process noise for a repo-local update action.
- Root cause: The first downloader implementation reused the downstream installer `DownloadLatest` relaunch pattern even though `InstallerCore` is only refreshing its own working copy.
- Guardrail/rule: The root `InstallerCore` downloader should finish after a successful download and should not auto-relaunch `install.ps1`.
- Files affected: `install.ps1`, `README.md`, `PROJECT_RULES.md`, `CHANGELOG.md`
- Validation/tests run: PowerShell parser validation on `install.ps1`; static review of downloader flow after removing relaunch behavior.

### Entry - 2026-04-14 (WinAppManager profile onboarding)
- Date: 2026-04-14
- Problem: `WinAppManager` needed install/update/uninstall onboarding plus an in-app update entry, but it still had no `InstallerCore` profile contract to generate the downstream installer from a shared source of truth.
- Root cause: The app workflow matured before the installer layer was onboarded, so the repo risked growing a bespoke `Install.ps1` or app-side update logic that would drift from the shared template flow.
- Guardrail/rule: Keep `profiles/WinAppManager.json` as the source-of-truth installer profile for `WinAppManager`. The downstream repo `Install.ps1` must stay generated from `InstallerCore`, and the app's own `Update app` menu entry should launch that generated installer flow instead of duplicating installer behavior inside the app.
- Files affected: `profiles/WinAppManager.json`, `PROJECT_RULES.md`, `CHANGELOG.md`
- Validation/tests run: Installer generation planned via `scripts\New-ToolInstaller.ps1` to `WinAppManager\Install.ps1`; parser/runtime validation planned in the downstream repo.

### Entry - 2026-04-14 (WinAppManager as child-only SystemTools tool)
- Date: 2026-04-14
- Problem: `WinAppManager` also needed a real context-menu entry under the shared `System Tools` host, not just a standalone installer/update flow.
- Root cause: The first profile onboarding covered deployment only and omitted the shared-submenu child registry contract plus the hidden launcher needed for clean elevated startup from Explorer.
- Guardrail/rule: `profiles/WinAppManager.json` must stay child-only under the existing `SystemTools` host and may write only `...\SystemTools\shell\WinAppManager` branches for `Directory`, `Directory\Background`, and `DesktopBackground`. Use a repo-owned launcher file patched to `{InstallRoot}` for context-menu startup; do not let the child profile create or modify the parent `SystemTools` keys.
- Files affected: `profiles/WinAppManager.json`, `PROJECT_RULES.md`, `CHANGELOG.md`
- Validation/tests run: Regenerated downstream `WinAppManager\Install.ps1`; downstream non-admin install smoke with registry readback and patched-launcher verification.

### Entry - 2026-04-14 (Template must tolerate source==install repair paths)
- Date: 2026-04-14
- Problem: Downstream update/install flows could either crash on self-copy repair paths or silently leave stale code by nesting folders like `Modules\Modules` when deploying into an existing install root.
- Root cause: `Deploy()` only skipped same-path file copies, not same-path directory copies, and its directory branch used `Copy-Item <dir> -> <existing dir>` semantics that create nested folders instead of syncing the directory contents.
- Guardrail/rule: In `templates/Install.Template.ps1`, skip deploy entries entirely when normalized source and destination resolve to the same path, and when deploying directories copy the source children into the target directory instead of copying the parent folder as a new nested child.
- Files affected: `templates/Install.Template.ps1`, `PROJECT_RULES.md`, `CHANGELOG.md`
- Validation/tests run: Downstream parser validation and installed-copy local update smoke planned after template regeneration.

### Entry - 2026-04-15 (Embedded DownloadLatest must not spawn a second installer)
- Date: 2026-04-15
- Problem: A downstream app could run `DownloadLatest` from inside its own TUI, but the installer still spawned a separate relaunched installer window because the template only knew the standalone self-relaunch flow.
- Root cause: `RunDownloadLatest()` always called `Start-RelaunchUpdatedInstaller`, with no switch to distinguish standalone installer usage from embedded in-app updater usage.
- Guardrail/rule: The shared installer template must expose a `-NoSelfRelaunch` switch. Embedded TUI updaters use it so `DownloadLatest` can finish silently in the background and let the app decide when/how to relaunch the updated host.
- Files affected: `templates/Install.Template.ps1`, `PROJECT_RULES.md`, `CHANGELOG.md`
- Validation/tests run: Downstream regeneration and working-copy in-app update smoke planned.

### Entry - 2026-04-15 (DownloadLatest must preserve host family and log root)
- Date: 2026-04-15
- Problem: The same updater/relaunch confusion resurfaced in a downstream app because workspace `DownloadLatest` still behaved like a generic detached relaunch and kept writing logs to the default install path instead of the actual working-copy target.
- Root cause: `Start-RelaunchUpdatedInstaller()` always relaunched through the same generic path regardless of the current host, and `RunDownloadLatest()` did not temporarily switch `InstallPath` / `InstallerLogPath` to the working-copy target root.
- Guardrail/rule: In `InstallerCore`, `DownloadLatest` must preserve the current host family when it relaunches (`WT` session => fresh `WT` window, plain `pwsh` => plain `pwsh`) and must treat the working-copy target root as the active install/log root for the duration of the download so embedded app UIs can tail the correct log file.
- Files affected: `templates/Install.Template.ps1`, `PROJECT_RULES.md`, `CHANGELOG.md`
- Validation/tests run: Template parser validation planned after edit; downstream regeneration and workspace action probe planned in `WinAppManager`.

### Entry - 2026-04-15 (Profiles must own tool icons as runtime assets)
- Date: 2026-04-15
- Problem: A downstream context-menu tool still shipped with a generic `shell32.dll` icon even though a real tool-specific icon asset now existed in the repo.
- Root cause: The profile contract had not yet modeled the icon as a required/deployed runtime file plus explicit registry `Icon` verification, so the generated installer kept a placeholder fallback icon.
- Guardrail/rule: In `InstallerCore`, when a tool has a specific context-menu icon, the profile must own it as a repo-local runtime asset and wire it through `required_package_entries`, `deploy_entries`, `verify_core_files`, `registry_values`, and `registry_verify`. Do not leave generic `shell32.dll` fallback icons in a profile once a canonical repo-owned icon exists.
- Files affected: `profiles/WinAppManager.json`, `PROJECT_RULES.md`, `CHANGELOG.md`
- Validation/tests run: Regenerated `WinAppManager\Install.ps1`; static review confirmed `{InstallRoot}\assets\MsStore.ico` in embedded registry values and verify entries.

### Entry - 2026-04-15 (Shipped profiles are package content, not migration-only state)
- Date: 2026-04-15
- Problem: A downstream installed app showed only `_preferences.json` under `%LOCALAPPDATA%\<Tool>\profiles` even though the repo already shipped multiple profile JSONs.
- Root cause: The profile contract modeled `profiles` only under `migration_copy_entries`, which preserves existing runtime state but does not deploy the folder into fresh or repaired installs.
- Guardrail/rule: In `InstallerCore`, if a tool ships repo-owned profile JSONs for operator use, the `profiles` folder must be included in `required_package_entries` and `deploy_entries`. Keep runtime preference/state files such as `_preferences.json` compatible with migration, but do not rely on migration-only semantics for shipped profile content.
- Files affected: `profiles/WinAppManager.json`, `PROJECT_RULES.md`, `CHANGELOG.md`
- Validation/tests run: Regenerated `WinAppManager\Install.ps1`; downstream local update/readback confirmed the installed `profiles` folder receives the repo-owned JSON files.
