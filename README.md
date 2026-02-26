# InstallerCore

`InstallerCore` είναι το shared framework για να παράγουμε consistent `Install.ps1` installers για Windows context-menu tools.

Αντί να ξαναγράφουμε installer logic σε κάθε repo, κρατάμε:
- ένα κοινό template,
- tool-specific profile metadata,
- και generator που συνθέτει το τελικό installer.

## 🔵 Γιατί υπάρχει

- Ίδιο flow σε όλα τα tools (`Install / Update / Uninstall`).
- Μικρότερο ρίσκο από copy/paste errors.
- Γρήγορο rollout νέου tool με προβλέψιμη δομή.
- Ευκολότερη συντήρηση όταν αλλάζει κοινή installer συμπεριφορά.

## 🔵 Architecture

- `templates/Install.Template.ps1`
  Generic installer engine (actions, deploy, registry write/verify, uninstall metadata, logs).

- `profiles/*.json`
  Tool contract: files to deploy, registry keys, labels, assets, GitHub source defaults.

- `scripts/New-ToolInstaller.ps1`
  Generator που κάνει embed το profile στο template και παράγει repo-specific `Install.ps1`.

## 🔵 Quick Start

```powershell
pwsh -NoProfile -File .\scripts\New-ToolInstaller.ps1 `
  -ProfilePath .\profiles\WhoIsUsingThis.json `
  -OutputPath D:\Users\joty79\scripts\WhoIsUsingThis\Install.ps1
```

## 🔵 Τι χρειάζεται να μου δίνεις (χωρίς JSON)

Για νέο tool, στείλε αυτό το mini brief:

```txt
REPO: D:\Users\joty79\scripts\<Tool>
ToolName:
GitHubRepo: joty79/<Tool>
GitHubRef: master
DeployFiles: (π.χ. .ps1, .vbs, .reg, assets\...)
MenuText:
Icon: (ή none)
OldKeysToCleanup: (αν υπάρχουν)
Notes: (π.χ. "same as previous tool")
```

Αν δεν ξέρεις κάτι, γράψε `same as current` και το συμπληρώνω εγώ.

## 🔵 Standard Output per Tool

Με βάση το brief, το workflow παράγει:
- profile JSON στο `InstallerCore\profiles\...`
- generated `Install.ps1` στο tool repo
- registry cleanup/write/verify rules
- deploy list + required file checks
- uninstall entry metadata

## 🔵 Current Direction

- Branch policy: `master` ως default/primary branch.
- One-branch default workflow για αυτά τα repos (εκτός αν ζητηθεί αλλιώς).
