#requires -version 7.0
[CmdletBinding()]
param(
    [string]$TemplatePath = (Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'templates\Install.Template.ps1'),
    [Parameter(Mandatory)][string]$ProfilePath,
    [Parameter(Mandatory)][string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-NormalizedPath {
    param([Parameter(Mandatory)][string]$Path)
    [System.IO.Path]::GetFullPath($Path.Trim())
}

function Get-ProfileArray {
    param(
        [Parameter(Mandatory)]$Profile,
        [Parameter(Mandatory)][string]$Name
    )

    $prop = $Profile.PSObject.Properties[$Name]
    if ($null -eq $prop -or $null -eq $prop.Value) { return @() }
    return @($prop.Value)
}

function Test-AbsoluteFileSystemPathLiteral {
    param([AllowEmptyString()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    return ($Value -match '(?i)(^|["''\s=])([A-Z]:\\)')
}

function Assert-RelativeRepoPath {
    param(
        [AllowEmptyString()][string]$Value,
        [Parameter(Mandatory)][string]$Context
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { return }

    if ([System.IO.Path]::IsPathRooted($Value) -or (Test-AbsoluteFileSystemPathLiteral -Value $Value)) {
        throw "Profile $Context must be repo-relative. Move external runtime files into the workspace (prefer .assets) and reference them from there: $Value"
    }

    if ($Value -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "Profile $Context must stay inside the workspace. Parent-path traversal is not allowed: $Value"
    }
}

function Assert-RelativePathList {
    param(
        [Parameter(Mandatory)]$Profile,
        [Parameter(Mandatory)][string[]]$FieldNames
    )

    foreach ($fieldName in $FieldNames) {
        foreach ($entry in @(Get-ProfileArray -Profile $Profile -Name $fieldName)) {
            Assert-RelativeRepoPath -Value ([string]$entry) -Context $fieldName
        }
    }
}

function Assert-RelativeRowPathProperty {
    param(
        [Parameter(Mandatory)]$Profile,
        [Parameter(Mandatory)][string]$FieldName,
        [Parameter(Mandatory)][string]$PropertyName
    )

    foreach ($row in @(Get-ProfileArray -Profile $Profile -Name $FieldName)) {
        if ($null -eq $row) { continue }
        $prop = $row.PSObject.Properties[$PropertyName]
        if ($null -eq $prop) { continue }
        Assert-RelativeRepoPath -Value ([string]$prop.Value) -Context "$FieldName.$PropertyName"
    }
}

function Assert-NoAbsoluteRuntimeString {
    param(
        [Parameter(Mandatory)]$Profile,
        [Parameter(Mandatory)][string]$FieldName,
        [Parameter(Mandatory)][string]$PropertyName
    )

    foreach ($row in @(Get-ProfileArray -Profile $Profile -Name $FieldName)) {
        if ($null -eq $row) { continue }
        $prop = $row.PSObject.Properties[$PropertyName]
        if ($null -eq $prop) { continue }

        $value = [string]$prop.Value
        if ([string]::IsNullOrWhiteSpace($value)) { continue }

        if (Test-AbsoluteFileSystemPathLiteral -Value $value) {
            throw "Profile $FieldName.$PropertyName contains an absolute filesystem path. Move the dependency into the workspace (prefer .assets) and use a relative path or {InstallRoot}: $value"
        }
    }
}

$TemplatePath = Resolve-NormalizedPath -Path $TemplatePath
$ProfilePath = Resolve-NormalizedPath -Path $ProfilePath
$OutputPath = Resolve-NormalizedPath -Path $OutputPath

if (-not (Test-Path -LiteralPath $TemplatePath)) {
    throw "Template not found: $TemplatePath"
}
if (-not (Test-Path -LiteralPath $ProfilePath)) {
    throw "Profile not found: $ProfilePath"
}

$templateRaw = Get-Content -LiteralPath $TemplatePath -Raw
$profileRaw = (Get-Content -LiteralPath $ProfilePath -Raw).Trim()

if (-not $templateRaw.Contains('__EMBEDDED_PROFILE_JSON__')) {
    throw 'Template marker __EMBEDDED_PROFILE_JSON__ was not found.'
}

$profileObj = $profileRaw | ConvertFrom-Json -Depth 50
if (-not $profileObj.PSObject.Properties['tool_name']) {
    throw 'Profile must include tool_name.'
}
if (-not $profileObj.PSObject.Properties['required_package_entries']) {
    throw 'Profile must include required_package_entries.'
}
if ($profileObj.PSObject.Properties['app_metadata_file']) {
    Assert-RelativeRepoPath -Value ([string]$profileObj.app_metadata_file) -Context 'app_metadata_file'
}
Assert-RelativePathList -Profile $profileObj -FieldNames @(
    'required_package_entries',
    'deploy_entries',
    'preserve_existing_entries',
    'verify_core_files',
    'migration_copy_entries',
    'uninstall_preserve_files'
)
Assert-RelativeRowPathProperty -Profile $profileObj -FieldName 'wrapper_patches' -PropertyName 'file'
Assert-NoAbsoluteRuntimeString -Profile $profileObj -FieldName 'registry_values' -PropertyName 'value'
Assert-NoAbsoluteRuntimeString -Profile $profileObj -FieldName 'registry_verify' -PropertyName 'expected'
Assert-NoAbsoluteRuntimeString -Profile $profileObj -FieldName 'wrapper_patches' -PropertyName 'replacement'

$rendered = $templateRaw.Replace('__EMBEDDED_PROFILE_JSON__', $profileRaw)
$outputDir = Split-Path -Path $OutputPath -Parent
if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
}

Set-Content -LiteralPath $OutputPath -Value $rendered -Encoding UTF8

$tokens = $null
$parseErrors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($OutputPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) {
    $first = $parseErrors[0]
    throw "Generated installer has parse errors. First error: $($first.Message) at $($first.Extent.StartLineNumber):$($first.Extent.StartColumnNumber)"
}
Write-Host ("Generated installer for '{0}' -> {1}" -f [string]$profileObj.tool_name, $OutputPath) -ForegroundColor Green
