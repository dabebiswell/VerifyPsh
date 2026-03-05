[CmdletBinding()]
param (
    [Parameter(Position=0, ValueFromPipeline=$true)]
    [string]$TargetFile,

    [ValidateSet("SHA256", "SHA384", "SHA512", "MD5")]
    [string]$Algorithm = "SHA256",

    [switch]$Interactive
)

if ([string]::IsNullOrWhiteSpace($TargetFile) -or $Interactive) {
    Write-Host "=== New Verification Script Generator ===" -ForegroundColor Cyan
    
    if ([string]::IsNullOrWhiteSpace($TargetFile)) {
        $TargetFile = Read-Host "Enter the path to the target file to verify"
    }
    
    while (-not (Test-Path $TargetFile -PathType Leaf)) {
        if (-not [string]::IsNullOrWhiteSpace($TargetFile)) {
            Write-Host "File not found: $TargetFile" -ForegroundColor Red
        }
        $TargetFile = Read-Host "Enter a valid path to the target file"
    }
    
    Write-Host ""
    Write-Host "Select a hashing algorithm (Current: $Algorithm):"
    $algoOptions = @("SHA256", "SHA384", "SHA512", "MD5")
    for ($i = 0; $i -lt $algoOptions.Length; $i++) {
        Write-Host "  $($i + 1). $($algoOptions[$i])"
    }
    
    $algoChoice = Read-Host "Enter choice (1-4) or press Enter to keep [$Algorithm]"
    $choiceInt = 0
    if ([int]::TryParse($algoChoice, [ref]$choiceInt) -and $choiceInt -ge 1 -and $choiceInt -le 4) {
        $Algorithm = $algoOptions[$choiceInt - 1]
    }
    Write-Host ""
} elseif (-not (Test-Path $TargetFile -PathType Leaf)) {
    Write-Error "Target file not found: $TargetFile"
    exit 1
}

# Resolve path correctly
$resolvedPath = Resolve-Path $TargetFile
$fileInfo = Get-Item $resolvedPath

# Calculate Hash
Write-Verbose "Calculating $Algorithm hash for $($fileInfo.Name)..."
$hashObj = Get-FileHash -Path $fileInfo.FullName -Algorithm $Algorithm
$hashString = $hashObj.Hash

$scriptName = "Verify-$($fileInfo.BaseName).ps1"
$scriptPath = Join-Path (Split-Path $resolvedPath) $scriptName

Write-Verbose "Generating verification script at $scriptPath..."

# Build script content
# Using a Here-String but escaping necessary variables with backticks
$scriptContent = @"
<#
.SYNOPSIS
    Verifies the integrity of $($fileInfo.Name).
.DESCRIPTION
    Auto-generated verification script for $($fileInfo.Name).
    Expected Hash ($Algorithm): $hashString
#>
[CmdletBinding()]
param (
    [Parameter(Position=0)]
    [string]`$TargetFile,

    [switch]`$NoPause
)

if ([string]::IsNullOrWhiteSpace(`$TargetFile)) {
    `$scriptDir = `$PSScriptRoot
    if ([string]::IsNullOrEmpty(`$scriptDir)) {
        `$scriptDir = Split-Path -Parent `$MyInvocation.MyCommand.Path
    }
    if ([string]::IsNullOrEmpty(`$scriptDir)) {
        `$scriptDir = `$PWD.Path
    }
    `$TargetFile = Join-Path `$scriptDir `"$($fileInfo.Name)`"
}

`$expected_hash = `"$hashString`"
`$algorithm = `"$Algorithm`"

function Write-Pass { process { Write-Host `"  [OK] `$_`" -ForegroundColor Green } }
function Write-Fail { process { Write-Host `"  [X] `$_`" -ForegroundColor Red } }
function Write-Info { process { Write-Host `"  [i] `$_`" -ForegroundColor Cyan } }

Write-Host `"=== File Integrity Verification ===`" -ForegroundColor Cyan
Write-Host `"Target File: `$TargetFile`"
Write-Host `"Algorithm:   `$algorithm`"
Write-Host `"`"

`"Checking input file...`" | Write-Info
if (-not (Test-Path `$TargetFile)) {
    `"File not found at specified path.`" | Write-Fail
    if (-not `$NoPause) { Read-Host `"Press Enter to exit...`" }
    exit 1
}

`"Calculating hash, please wait...`" | Write-Info

`$measure = Measure-Command { 
    `$result = Get-FileHash -Path `$TargetFile -Algorithm `$algorithm
}

Write-Host `"Expected:    `$expected_hash`"
Write-Host `"Actual:      `$(`$result.Hash)`"
Write-Host `"`"

if (`$result.Hash -eq `$expected_hash) {
    `"MATCH. The file integrity has been verified.`" | Write-Pass
    Write-Host `"Verification took `$(`$measure.TotalSeconds.ToString('F2')) seconds.`" -ForegroundColor DarkGray
    if (-not `$NoPause) { Read-Host `"Press Enter to exit...`" }
    exit 0
} else {
    `"MISMATCH. The file does not match the expected hash!`" | Write-Fail
    Write-Host `"Verification took `$(`$measure.TotalSeconds.ToString('F2')) seconds.`" -ForegroundColor DarkGray
    if (-not `$NoPause) { Read-Host `"Press Enter to exit...`" }
    exit 1
}
"@

# Write content
Set-Content -Path $scriptPath -Value $scriptContent -Encoding UTF8

Write-Host "Created verifier script: $scriptPath" -ForegroundColor Green
