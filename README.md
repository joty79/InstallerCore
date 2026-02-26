# InstallerCore

Reusable installer framework for context-menu tools.

## Structure

- `templates/Install.Template.ps1`: Generic installer template.
- `profiles/*.json`: Tool profiles (files, registry, metadata, menu labels).
- `scripts/New-ToolInstaller.ps1`: Generates a tool-specific `Install.ps1` by embedding a profile into the template.

## Usage

```powershell
pwsh -NoProfile -File .\scripts\New-ToolInstaller.ps1 `
  -ProfilePath .\profiles\WhoIsUsingThis.json `
  -OutputPath D:\Users\joty79\scripts\WhoIsUsingThis\Install.ps1
```
