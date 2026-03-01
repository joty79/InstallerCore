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
