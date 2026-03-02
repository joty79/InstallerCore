# PROJECT_RULES - InstallerCore

## Scope
- Repo: `D:\Users\joty79\scripts\InstallerCore`
- Purpose: shared installer template + profile-driven generation for multiple tool repos.

## Guardrails
- Keep `templates/Install.Template.ps1` generic and profile-driven.
- Do not hardcode tool-specific registry keys/paths in template logic.
- Tool-specific decisions belong in `profiles/*.json`.
- Generated installers must keep action flow parity: Install/Update/Uninstall/Open actions, metadata, registry write+verify, and uninstall entry.

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
