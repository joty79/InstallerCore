#requires -version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [string[]]$ProfileName = @(),
    [switch]$All,
    [switch]$SkipMissingRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$profilesRoot = Join-Path -Path $repoRoot -ChildPath 'profiles'
$generatorPath = Join-Path -Path $PSScriptRoot -ChildPath 'New-ToolInstaller.ps1'

function Resolve-ExistingRoot {
    param([AllowEmptyString()][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    if (Test-Path -LiteralPath $Path -PathType Container) {
        return (Resolve-Path -LiteralPath $Path).Path
    }

    $alternate = ''
    if ($Path -match '^[Dd]:\\Users\\') {
        $alternate = 'C:' + $Path.Substring(2)
    }
    elseif ($Path -match '^[Cc]:\\Users\\') {
        $alternate = 'D:' + $Path.Substring(2)
    }

    if (-not [string]::IsNullOrWhiteSpace($alternate) -and (Test-Path -LiteralPath $alternate -PathType Container)) {
        return (Resolve-Path -LiteralPath $alternate).Path
    }

    return ''
}

if (-not $All -and @($ProfileName).Count -eq 0) {
    throw 'Choose profiles with -ProfileName or regenerate every profile with -All.'
}

if (-not (Test-Path -LiteralPath $generatorPath -PathType Leaf)) {
    throw "Generator not found: $generatorPath"
}

$profileFiles = @(Get-ChildItem -LiteralPath $profilesRoot -Filter '*.json' -File | Sort-Object Name)
$selectedProfiles = foreach ($profileFile in $profileFiles) {
    $profile = Get-Content -LiteralPath $profileFile.FullName -Raw | ConvertFrom-Json -Depth 50
    $toolName = [string]$profile.tool_name
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($profileFile.Name)

    if ($All -or $ProfileName -contains $toolName -or $ProfileName -contains $baseName) {
        [pscustomobject]@{
            ToolName = $toolName
            ProfilePath = $profileFile.FullName
            LegacyRoot = [string]$profile.legacy_root
        }
    }
}

if (@($selectedProfiles).Count -eq 0) {
    throw 'No matching profiles found.'
}

$results = foreach ($item in $selectedProfiles) {
    $targetRoot = Resolve-ExistingRoot -Path $item.LegacyRoot
    if ([string]::IsNullOrWhiteSpace($targetRoot)) {
        $message = "Downstream root not found for $($item.ToolName): $($item.LegacyRoot)"
        if ($SkipMissingRoot) {
            Write-Warning $message
            [pscustomobject]@{ ToolName = $item.ToolName; Status = 'Skipped'; OutputPath = ''; Message = $message }
            continue
        }
        throw $message
    }

    $outputPath = Join-Path -Path $targetRoot -ChildPath 'Install.ps1'
    if ($PSCmdlet.ShouldProcess($outputPath, "Regenerate installer for $($item.ToolName)")) {
        & $generatorPath -ProfilePath $item.ProfilePath -OutputPath $outputPath
    }

    [pscustomobject]@{ ToolName = $item.ToolName; Status = 'Generated'; OutputPath = $outputPath; Message = '' }
}

$results | Format-Table -AutoSize
