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
