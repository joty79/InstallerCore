# InstallerCore

Reusable framework για να φτιάχνουμε `Install.ps1` installers για context-menu tools χωρίς copy/paste λογική σε κάθε repo.

## Τι κάνει

- Κρατάει κοινό installer behavior σε ένα template: `templates/Install.Template.ps1`.
- Κρατάει tool-specific settings σε profile files: `profiles/*.json`.
- Παράγει τελικό installer για κάθε tool μέσω generator: `scripts/New-ToolInstaller.ps1`.

Με αυτό το μοντέλο:

- το flow (`Install/Update/Uninstall`) μένει σταθερό,
- οι διαφορές ανά tool μπαίνουν μόνο στο profile,
- τα λάθη από manual edits μειώνονται.

## Τι πληροφορίες χρειάζομαι από εσένα (mini brief)

Δεν χρειάζεται να γράφεις JSON. Στείλε μου μόνο αυτό:

```txt
REPO: D:\Users\joty79\scripts\<Tool>
ToolName:
GitHubRepo: joty79/<Tool>
GitHubRef: master
DeployFiles: (π.χ. .ps1, .vbs, .reg, assets\...)
MenuText:
Icon: (ή none)
OldKeysToCleanup: (αν υπάρχουν)
Notes: (π.χ. “same as previous tool”)
```

Αν κάτι δεν το ξέρεις, γράψε `same as current` και το συμπληρώνω εγώ.

## Generator χρήση

```powershell
pwsh -NoProfile -File .\scripts\New-ToolInstaller.ps1 `
  -ProfilePath .\profiles\WhoIsUsingThis.json `
  -OutputPath D:\Users\joty79\scripts\WhoIsUsingThis\Install.ps1
```
