#requires -version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Install', 'Update', 'Uninstall', 'Open')]
    [string]$Action = 'Install',
    [string]$InstallPath = (Join-Path $HOME 'scripts\InstallerCore'),
    [string]$GitHubRepo = 'joty79/InstallerCore',
    [string]$GitHubRef = 'master',
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-NormalizedPath {
    param([Parameter(Mandatory)][string]$Path)
    [System.IO.Path]::GetFullPath($Path.Trim())
}

function Test-CommandAvailable {
    param([Parameter(Mandatory)][string]$Name)
    return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Invoke-Git {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [string]$WorkDir
    )

    if ($WorkDir) {
        & git -C $WorkDir @Arguments
    } else {
        & git @Arguments
    }

    if ($LASTEXITCODE -ne 0) {
        throw "git command failed: git $($Arguments -join ' ')"
    }
}

function Ensure-Git {
    if (-not (Test-CommandAvailable -Name 'git')) {
        throw "git was not found in PATH. Install Git and rerun install.ps1."
    }
}

function Ensure-RepoExists {
    param([Parameter(Mandatory)][string]$Path)
    $gitPath = Join-Path $Path '.git'
    if (-not (Test-Path -LiteralPath $gitPath)) {
        throw "Git repository not found at: $Path"
    }
}

function Install-OrUpdateRepo {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$Ref
    )

    $gitPath = Join-Path $Path '.git'
    if (Test-Path -LiteralPath $gitPath) {
        Write-Host "InstallerCore already exists. Running update..." -ForegroundColor Yellow
        Update-Repo -Path $Path -Ref $Ref
        return
    }

    $parentDir = Split-Path -Path $Path -Parent
    if (-not (Test-Path -LiteralPath $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }

    $cloneUrl = "https://github.com/$Repo.git"
    Invoke-Git -Arguments @('clone', '--branch', $Ref, '--single-branch', $cloneUrl, $Path)
    Write-Host "Installed InstallerCore to: $Path" -ForegroundColor Green
}

function Update-Repo {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Ref
    )

    Ensure-RepoExists -Path $Path
    Invoke-Git -WorkDir $Path -Arguments @('fetch', 'origin', $Ref)
    Invoke-Git -WorkDir $Path -Arguments @('checkout', $Ref)
    Invoke-Git -WorkDir $Path -Arguments @('pull', '--ff-only', 'origin', $Ref)
    Write-Host "Updated InstallerCore at: $Path" -ForegroundColor Green
}

function Remove-Repo {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][bool]$SkipPrompt
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "Nothing to uninstall. Path not found: $Path" -ForegroundColor Yellow
        return
    }

    if (-not $SkipPrompt) {
        $confirmation = Read-Host "Type YES to remove '$Path'"
        if ($confirmation -ne 'YES') {
            Write-Host 'Uninstall cancelled.' -ForegroundColor Yellow
            return
        }
    }

    Remove-Item -LiteralPath $Path -Recurse -Force
    Write-Host "Removed InstallerCore from: $Path" -ForegroundColor Green
}

$InstallPath = Resolve-NormalizedPath -Path $InstallPath
Ensure-Git

switch ($Action) {
    'Install' {
        Install-OrUpdateRepo -Path $InstallPath -Repo $GitHubRepo -Ref $GitHubRef
    }
    'Update' {
        Update-Repo -Path $InstallPath -Ref $GitHubRef
    }
    'Uninstall' {
        Remove-Repo -Path $InstallPath -SkipPrompt:$Force.IsPresent
    }
    'Open' {
        Ensure-RepoExists -Path $InstallPath
        Start-Process explorer.exe $InstallPath
    }
    default {
        throw "Unknown action: $Action"
    }
}
