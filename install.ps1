#requires -version 7.0
[CmdletBinding()]
param(
    [ValidateSet('DownloadLatest', 'OpenCurrentDirectory')]
    [string]$Action = 'DownloadLatest',
    [string]$TargetPath = $PSScriptRoot,
    [string]$GitHubRepo = 'joty79/InstallerCore',
    [string]$GitHubRef = '',
    [string]$GitHubZipUrl = '',
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-NormalizedPath {
    param([Parameter(Mandatory)][string]$Path)
    [System.IO.Path]::GetFullPath($Path.Trim())
}

function EnsureDir {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function NormalizeGitHubRef {
    param([AllowEmptyString()][string]$Ref)
    if ($null -eq $Ref) { return '' }
    $candidate = $Ref.Trim()
    if ($candidate.StartsWith('refs/heads/', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $candidate.Substring('refs/heads/'.Length)
    }
    return $candidate
}

function Confirm {
    param([Parameter(Mandatory)][string]$Prompt)
    if ($Force) { return $true }
    return ((Read-Host "$Prompt [y/N]").Trim().ToLowerInvariant() -eq 'y')
}

function Get-GitHubApiHeaders {
    $headers = @{ 'User-Agent' = "$($script:ToolName)Downloader/$($script:DownloaderVersion)" }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
        $headers['Authorization'] = "Bearer $($env:GITHUB_TOKEN)"
    }
    return $headers
}

function Get-GitHubRemoteInfo {
    param([Parameter(Mandatory)][string]$Repo)

    $result = [ordered]@{
        DefaultBranch = ''
        Branches      = [System.Collections.Generic.List[string]]::new()
    }

    if ([string]::IsNullOrWhiteSpace($Repo)) { return [pscustomobject]$result }

    if (Get-Command gh.exe -ErrorAction SilentlyContinue) {
        try {
            $repoJson = (& gh.exe api "repos/$Repo" 2>$null | Out-String).Trim()
            if (-not [string]::IsNullOrWhiteSpace($repoJson)) {
                $repoInfo = $repoJson | ConvertFrom-Json
                $result.DefaultBranch = [string]$repoInfo.default_branch
            }

            $branchesJson = (& gh.exe api --paginate "repos/$Repo/branches?per_page=100" 2>$null | Out-String).Trim()
            if (-not [string]::IsNullOrWhiteSpace($branchesJson)) {
                foreach ($row in @($branchesJson | ConvertFrom-Json)) {
                    $name = NormalizeGitHubRef ([string]$row.name)
                    if (-not [string]::IsNullOrWhiteSpace($name) -and -not $result.Branches.Contains($name)) {
                        $result.Branches.Add($name)
                    }
                }
            }

            if ($result.DefaultBranch -or $result.Branches.Count -gt 0) {
                return [pscustomobject]$result
            }
        }
        catch {}
    }

    try {
        $headers = Get-GitHubApiHeaders
        $repoResp = Invoke-WebRequest -Uri ("https://api.github.com/repos/{0}" -f $Repo) -UseBasicParsing -Headers $headers
        $repoInfo = $repoResp.Content | ConvertFrom-Json
        $result.DefaultBranch = [string]$repoInfo.default_branch

        $branchesResp = Invoke-WebRequest -Uri ("https://api.github.com/repos/{0}/branches?per_page=100" -f $Repo) -UseBasicParsing -Headers $headers
        foreach ($row in @($branchesResp.Content | ConvertFrom-Json)) {
            $name = NormalizeGitHubRef ([string]$row.name)
            if (-not [string]::IsNullOrWhiteSpace($name) -and -not $result.Branches.Contains($name)) {
                $result.Branches.Add($name)
            }
        }
    }
    catch {}

    return [pscustomobject]$result
}

function ResolveGitHubRefAuto {
    if ($script:GitHubRefSpecified -and -not [string]::IsNullOrWhiteSpace($GitHubRef)) {
        return $GitHubRef
    }

    $info = Get-GitHubRemoteInfo -Repo $GitHubRepo
    $preferred = [System.Collections.Generic.List[string]]::new()
    foreach ($candidate in @($info.DefaultBranch, 'master', 'latest')) {
        $name = NormalizeGitHubRef $candidate
        if (-not [string]::IsNullOrWhiteSpace($name) -and -not $preferred.Contains($name)) {
            $preferred.Add($name)
        }
    }

    foreach ($candidate in $preferred) {
        if ($info.Branches.Contains($candidate)) {
            return $candidate
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($info.DefaultBranch)) {
        return (NormalizeGitHubRef $info.DefaultBranch)
    }

    return 'master'
}

function EnsureGitHubRefResolved {
    $resolved = ResolveGitHubRefAuto
    $script:GitHubRefSpecified = $true
    Set-Variable -Name GitHubRef -Scope Script -Value $resolved
}

function Get-GitHubBranchNames {
    param([Parameter(Mandatory)][string]$Repo)
    $info = Get-GitHubRemoteInfo -Repo $Repo
    return @($info.Branches | Select-Object -Unique)
}

function ReadRefInteractive {
    param([Parameter(Mandatory)][string]$DefaultRef)

    $normalizedDefault = if ([string]::IsNullOrWhiteSpace($DefaultRef)) { 'master' } else { $DefaultRef.Trim() }
    $branches = @(Get-GitHubBranchNames -Repo $GitHubRepo)

    if ($branches.Count -gt 0) {
        if ($branches -notcontains $normalizedDefault) {
            $branches = @($normalizedDefault) + @($branches)
        }
        else {
            $branches = @($normalizedDefault) + @($branches | Where-Object { $_ -ne $normalizedDefault })
        }
        $branches = @($branches | Select-Object -Unique)

        Write-Host ''
        Write-Host ("Available branches for {0}:" -f $GitHubRepo) -ForegroundColor Cyan
        for ($i = 0; $i -lt $branches.Count; $i++) {
            $n = $i + 1
            $name = $branches[$i]
            $suffix = if ($name -eq $normalizedDefault) { ' (default)' } else { '' }
            Write-Host ("[{0}] {1}{2}" -f $n, $name, $suffix) -ForegroundColor Gray
        }
        Write-Host '[Enter] Use default' -ForegroundColor Gray

        while ($true) {
            $choice = (Read-Host ("Select branch number (blank = {0})" -f $normalizedDefault)).Trim()
            if ([string]::IsNullOrWhiteSpace($choice)) { return $normalizedDefault }
            if ($choice -match '^\d+$') {
                $index = [int]$choice
                if ($index -ge 1 -and $index -le $branches.Count) {
                    return $branches[$index - 1]
                }
            }
            Write-Host 'Invalid selection. Choose a number or Enter.' -ForegroundColor Yellow
        }
    }

    Write-Host ("Could not read branch list. Using default ref: {0}" -f $normalizedDefault) -ForegroundColor Yellow
    return $normalizedDefault
}

function Test-InstallerCoreRoot {
    param([Parameter(Mandatory)][string]$Root)

    foreach ($relativePath in @(
        'README.md',
        'PROJECT_RULES.md',
        'templates\Install.Template.ps1',
        'scripts\New-ToolInstaller.ps1'
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $relativePath))) {
            return $false
        }
    }

    return $true
}

function ResolveGitHubSourceRoot {
    if ([string]::IsNullOrWhiteSpace($GitHubRepo)) {
        throw 'GitHubRepo is required.'
    }

    if ([string]::IsNullOrWhiteSpace($GitHubRef)) {
        EnsureGitHubRefResolved
    }

    $url = if ([string]::IsNullOrWhiteSpace($GitHubZipUrl)) {
        "https://codeload.github.com/$GitHubRepo/zip/refs/heads/$GitHubRef"
    }
    else {
        $GitHubZipUrl.Trim()
    }

    $tempRoot = Join-Path $env:TEMP ("InstallerCore_pkg_" + [guid]::NewGuid().ToString('N'))
    $zipPath = Join-Path $tempRoot 'pkg.zip'
    $extractRoot = Join-Path $tempRoot 'extract'
    EnsureDir $tempRoot
    EnsureDir $extractRoot
    $script:TempPackageRoots.Add($tempRoot) | Out-Null

    Write-Host ("Downloading package: {0}" -f $url) -ForegroundColor DarkGray
    $downloaded = $false
    try {
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -Headers (Get-GitHubApiHeaders)
        $downloaded = $true
    }
    catch {
        if (Get-Command gh.exe -ErrorAction SilentlyContinue) {
            try {
                Write-Host 'Invoke-WebRequest failed; trying authenticated GitHub API fallback via gh auth token...' -ForegroundColor Yellow
                $ghToken = (& gh.exe auth token 2>$null | Out-String).Trim()
                if (-not [string]::IsNullOrWhiteSpace($ghToken)) {
                    $headers = @{
                        'User-Agent'    = "$($script:ToolName)Downloader/$($script:DownloaderVersion)"
                        'Authorization' = "Bearer $ghToken"
                        'Accept'        = 'application/vnd.github+json'
                    }
                    $apiUrl = "https://api.github.com/repos/$GitHubRepo/zipball/$GitHubRef"
                    Invoke-WebRequest -Uri $apiUrl -OutFile $zipPath -UseBasicParsing -Headers $headers
                }
                if (Test-Path -LiteralPath $zipPath) {
                    $downloaded = $true
                }
            }
            catch {}
        }

        if (-not $downloaded) {
            throw
        }
    }

    Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force
    $candidates = @($extractRoot) + @(Get-ChildItem -LiteralPath $extractRoot -Directory -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    foreach ($candidate in $candidates) {
        if (Test-InstallerCoreRoot -Root $candidate) {
            return $candidate
        }
    }

    throw 'Downloaded package does not look like a valid InstallerCore repo root.'
}

function Deploy-RepoContent {
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$TargetRoot
    )

    EnsureDir $TargetRoot
    foreach ($item in @(Get-ChildItem -LiteralPath $SourceRoot -Force -ErrorAction Stop)) {
        if ($item.Name -eq '.git') { continue }
        Copy-Item -LiteralPath $item.FullName -Destination $TargetRoot -Recurse -Force
    }
}

function CleanupTempPackageRoots {
    foreach ($tempRoot in $script:TempPackageRoots) {
        try {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        catch {}
    }
    $script:TempPackageRoots.Clear()
}

function Start-RelaunchUpdatedInstaller {
    param([Parameter(Mandatory)][string]$TargetRoot)

    $updatedInstaller = Join-Path $TargetRoot 'install.ps1'
    if (-not (Test-Path -LiteralPath $updatedInstaller)) {
        throw "Updated downloader was not found after download: $updatedInstaller"
    }

    $pwshCmd = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    $pwshExe = if ($null -ne $pwshCmd) { $pwshCmd.Source } else { Join-Path $PSHOME 'pwsh.exe' }
    $launcherPath = Join-Path $env:TEMP ("InstallerCore_relaunch_{0}.cmd" -f [guid]::NewGuid().ToString('N'))
    $launcherContent = @(
        '@echo off',
        'setlocal',
        'timeout /t 2 /nobreak >nul',
        ('start "" "{0}" -ExecutionPolicy Bypass -File "{1}"' -f $pwshExe, $updatedInstaller),
        'del "%~f0"'
    )
    Set-Content -LiteralPath $launcherPath -Value $launcherContent -Encoding ASCII
    Start-Process -FilePath $launcherPath -WindowStyle Hidden | Out-Null
}

function RunDownloadLatest {
    $targetRoot = Resolve-NormalizedPath -Path $TargetPath
    EnsureGitHubRefResolved

    if (-not $script:HasCliArgs) {
        $GitHubRef = ReadRefInteractive -DefaultRef $GitHubRef
        Set-Variable -Name GitHubRef -Scope Script -Value $GitHubRef
    }

    Write-Host ("Using GitHub ref: {0}" -f $GitHubRef) -ForegroundColor DarkCyan
    if (-not (Confirm "Download latest InstallerCore into '$targetRoot' and relaunch the updated downloader?")) {
        Write-Host 'Cancelled.' -ForegroundColor Yellow
        return 0
    }

    try {
        $sourceRoot = ResolveGitHubSourceRoot
        Deploy-RepoContent -SourceRoot $sourceRoot -TargetRoot $targetRoot

        if (-not (Test-InstallerCoreRoot -Root $targetRoot)) {
            Write-Host 'Download completed with warnings: target directory is missing required InstallerCore files.' -ForegroundColor Yellow
            return 2
        }

        Start-RelaunchUpdatedInstaller -TargetRoot $targetRoot
        Write-Host 'Latest files downloaded successfully. Relaunching updated downloader...' -ForegroundColor Green
        return 0
    }
    finally {
        CleanupTempPackageRoots
    }
}

function Open-CurrentDirectory {
    $targetRoot = Resolve-NormalizedPath -Path $TargetPath
    if (-not (Test-Path -LiteralPath $targetRoot)) {
        Write-Host ("Directory not found: {0}" -f $targetRoot) -ForegroundColor Yellow
        return 1
    }

    Start-Process explorer.exe -ArgumentList $targetRoot
    return 0
}

function ShowMenu {
    while ($true) {
        try { Clear-Host } catch {}
        Write-Host '============================================================' -ForegroundColor Cyan
        Write-Host ('  {0}  v{1}' -f $script:InstallerTitle, $script:DownloaderVersion) -ForegroundColor Cyan
        Write-Host '============================================================' -ForegroundColor Cyan
        Write-Host ('Target: {0}' -f $TargetPath) -ForegroundColor DarkGray
        Write-Host ('Repo:   {0}' -f $GitHubRepo) -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '[1] Download Latest here' -ForegroundColor Green
        Write-Host '[2] Open current directory' -ForegroundColor Cyan
        Write-Host '[0] Exit' -ForegroundColor Gray

        $choice = (Read-Host 'Select option').Trim()
        switch ($choice) {
            '1' { return 'DownloadLatest' }
            '2' { return 'OpenCurrentDirectory' }
            '0' { return 'Exit' }
            default { Write-Host 'Invalid selection.' -ForegroundColor Yellow; Start-Sleep -Milliseconds 900 }
        }
    }
}

$script:ToolName = 'InstallerCore'
$script:InstallerTitle = 'InstallerCore Downloader'
$script:DownloaderVersion = '1.0.0'
$script:HasCliArgs = $MyInvocation.BoundParameters.Count -gt 0
$script:GitHubRefSpecified = $PSBoundParameters.ContainsKey('GitHubRef')
$script:TempPackageRoots = [System.Collections.Generic.List[string]]::new()

$TargetPath = Resolve-NormalizedPath -Path $TargetPath
$GitHubRef = NormalizeGitHubRef $GitHubRef

if (-not $script:HasCliArgs) {
    $menuAction = ShowMenu
    if ($menuAction -eq 'Exit') {
        exit 0
    }
    $Action = $menuAction
}

switch ($Action) {
    'DownloadLatest' { exit (RunDownloadLatest) }
    'OpenCurrentDirectory' { exit (Open-CurrentDirectory) }
    default { Write-Host "Unknown action: $Action" -ForegroundColor Red; exit 1 }
}
