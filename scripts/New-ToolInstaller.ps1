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
