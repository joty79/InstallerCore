[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,
    [string]$Remote = 'origin',
    [string]$Branch = 'master',
    [switch]$Pull,
    [switch]$VerifyOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param(
        [Parameter(Mandatory)]
        [string]$Root,
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    & git -C $Root @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed in $Root"
    }
}

function Assert-FileContains {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Pattern,
        [Parameter(Mandatory)]
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing $Label file: $Path"
    }

    $content = Get-Content -Raw -LiteralPath $Path
    if ($content -notmatch $Pattern) {
        throw "$Label missing required marker: $Pattern"
    }
}

function Assert-CleanWorktree {
    param([Parameter(Mandatory)][string]$Root)

    $status = & git -C $Root status --porcelain
    if ($LASTEXITCODE -ne 0) {
        throw "git status failed in $Root"
    }
    if ($status) {
        throw "Worktree has local changes: $Root"
    }
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot '.git'))) {
    throw "Not a git repo: $RepoRoot"
}

if ($Pull) {
    Assert-CleanWorktree -Root $RepoRoot
    Invoke-Git -Root $RepoRoot -Arguments @('fetch', $Remote, '--prune')
    Invoke-Git -Root $RepoRoot -Arguments @('pull', '--ff-only', $Remote, $Branch)
}
else {
    Invoke-Git -Root $RepoRoot -Arguments @('fetch', $Remote, '--prune')
}

$localHead = (& git -C $RepoRoot rev-parse HEAD).Trim()
$remoteHead = (& git -C $RepoRoot rev-parse "$Remote/$Branch").Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Could not resolve $Remote/$Branch"
}

if ($localHead -ne $remoteHead) {
    $message = "InstallerCore is not at $Remote/$Branch. Local=$localHead Remote=$remoteHead"
    if ($VerifyOnly) {
        throw $message
    }
    Write-Host $message -ForegroundColor Yellow
}

Assert-FileContains -Path (Join-Path $RepoRoot 'docs\IN_APP_UPDATE_UI_CONTRACT.md') -Pattern 'commit-aware update status|github_commit|same-version commit mismatch' -Label 'in-app update UI contract'
Assert-FileContains -Path (Join-Path $RepoRoot 'README.md') -Pattern 'IN_APP_UPDATE_UI_CONTRACT\.md' -Label 'README'
Assert-FileContains -Path (Join-Path $RepoRoot 'PROJECT_RULES.md') -Pattern 'app-side update UI' -Label 'project rules'

$tokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $RepoRoot 'templates\Install.Template.ps1'), [ref]$tokens, [ref]$parseErrors) | Out-Null
if ($parseErrors) {
    throw "Template parser validation failed: $($parseErrors[0].Message)"
}

Write-Host 'InstallerCore sync/verification OK'
