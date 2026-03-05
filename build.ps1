[CmdletBinding()]
param (
    [switch]$OneLiner
)

$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptDir)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if ([string]::IsNullOrEmpty($scriptDir)) {
    $scriptDir = $PWD.Path
}

$moduleName = "VerifyPsh"
$psm1Path = Join-Path $scriptDir "$moduleName.psm1"
$psd1Path = Join-Path $scriptDir "$moduleName.psd1"

Write-Host "Building $moduleName Installer..." -ForegroundColor Cyan

# 1. Read files and convert to base64
Write-Host "Encoding module files..."
$psm1Bytes = [System.IO.File]::ReadAllBytes($psm1Path)
$psm1Base64 = [Convert]::ToBase64String($psm1Bytes)

$psd1Bytes = [System.IO.File]::ReadAllBytes($psd1Path)
$psd1Base64 = [Convert]::ToBase64String($psd1Bytes)

if ($OneLiner) {
    $outputPath = Join-Path $scriptDir "oneliner-install.md"
    Write-Host "Generating one-liner markdown script..."

    $minified = "`$m='$moduleName';`$d=if(`$PSVersionTable.PSVersion.Major -ge 6){Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules'}else{Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Modules'};`$p=Join-Path `$d `$m;if(Test-Path `$p){Remove-Item `$p -Recurse -Force};`$null=New-Item -Type Directory `$p -Force;[IO.File]::WriteAllBytes((Join-Path `$p `"`$m.psm1`"),[Convert]::FromBase64String('$psm1Base64'));[IO.File]::WriteAllBytes((Join-Path `$p `"`$m.psd1`"),[Convert]::FromBase64String('$psd1Base64'));Import-Module `$m -Force"

    $markdown = @"
# Copy and Paste Installer

Run the following one-liner in your terminal to install the `$moduleName module:

``````powershell
$minified
``````
"@
    Set-Content -Path $outputPath -Value $markdown -Encoding UTF8
    Write-Host "[OK] Build complete: $outputPath" -ForegroundColor Green
} else {
    $outputPath = Join-Path $scriptDir "Install-$moduleName.ps1"
    Write-Host "Generating installer script..."

    $installerTemplate = @"
<#
.SYNOPSIS
    Installs the `$moduleName PowerShell module.
.DESCRIPTION
    This script installs the `$moduleName module to the CurrentUser scope,
    making the New-VerifyScript cmdlet globally available.
    It automatically targets the correct path based on whether it is run from Windows PowerShell 5.1 or PowerShell Core.
#>

`$ErrorActionPreference = "Stop"

`$moduleName = "$moduleName"
Write-Host "=== Installing `$moduleName ===" -ForegroundColor Cyan

# Determine correct module path for CurrentUser scope
`$psVersion = `$PSVersionTable.PSVersion.Major
`$targetBaseDir = ""

if (`$psVersion -ge 6) {
    # PowerShell Core (7+)
    `$targetBaseDir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell\Modules"
} else {
    # Windows PowerShell 5.1
    `$targetBaseDir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell\Modules"
}

# Ensure directory exists
if (-not (Test-Path `$targetBaseDir)) {
    New-Item -ItemType Directory -Path `$targetBaseDir -Force | Out-Null
}

`$moduleDir = Join-Path `$targetBaseDir `$moduleName

if (Test-Path `$moduleDir) {
    Write-Host "Removing existing installation..." -ForegroundColor Yellow
    Remove-Item -Path `$moduleDir -Recurse -Force
}

Write-Host "Creating module directory..."
New-Item -ItemType Directory -Path `$moduleDir -Force | Out-Null

# Base64 Payloads
`$psm1Base64 = "$psm1Base64"
`$psd1Base64 = "$psd1Base64"

# Decode and write files
Write-Host "Extracting module files..."
`$psm1Bytes = [Convert]::FromBase64String(`$psm1Base64)
`$psd1Bytes = [Convert]::FromBase64String(`$psd1Base64)

`$psm1Dest = Join-Path `$moduleDir "`$moduleName.psm1"
`$psd1Dest = Join-Path `$moduleDir "`$moduleName.psd1"

[System.IO.File]::WriteAllBytes(`$psm1Dest, `$psm1Bytes)
[System.IO.File]::WriteAllBytes(`$psd1Dest, `$psd1Bytes)

# Import module immediately
Write-Host "Importing module..."
Import-Module `$moduleName -Force

Write-Host "[OK] `$moduleName successfully installed and imported." -ForegroundColor Green
Write-Host "You can now use New-VerifyScript." -ForegroundColor Green
"@

    # 3. Write installer to disk
    Set-Content -Path $outputPath -Value $installerTemplate -Encoding UTF8

    Write-Host "[OK] Build complete: $outputPath" -ForegroundColor Green
}
