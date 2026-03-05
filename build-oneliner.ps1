[CmdletBinding()]
param()

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

Write-Host "Building $moduleName OneLiner Installer..." -ForegroundColor Cyan

$psm1Raw = [System.IO.File]::ReadAllText($psm1Path, [System.Text.Encoding]::UTF8)
$psd1Raw = [System.IO.File]::ReadAllText($psd1Path, [System.Text.Encoding]::Unicode)

function Minify-PS($Code) {
    $Code = $Code -replace '(?s)<#.*?#>', ''
    $Code = $Code -replace '(?m)^\s*#.*$', ''
    $Code = $Code -replace '(?m)^\s+', ''
    $Code = $Code -replace '(?m)^\s*\r?\n', ''
    $Code = $Code.Trim()
    return $Code
}

Write-Host "Minifying module files..."
$psm1Min = Minify-PS $psm1Raw
$psd1Min = Minify-PS $psd1Raw

function Compress-PS($String) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($String)
    $ms = New-Object System.IO.MemoryStream
    $cs = New-Object System.IO.Compression.DeflateStream($ms, [System.IO.Compression.CompressionLevel]::Optimal)
    $cs.Write($bytes, 0, $bytes.Length)
    $cs.Close()
    return [Convert]::ToBase64String($ms.ToArray())
}

Write-Host "Compressing module files..."
$psm1B64 = Compress-PS $psm1Min
$psd1B64 = Compress-PS $psd1Min

Write-Host "PSM1 Minified Length: $($psm1Min.Length) -> B64: $($psm1B64.Length)"
Write-Host "PSD1 Minified Length: $($psd1Min.Length) -> B64: $($psd1B64.Length)"

$outputPath = Join-Path $scriptDir "oneliner-install.md"
Write-Host "Generating one-liner markdown script..."

$minified = "`$m='VerifyPsh';`$d=if(`$PSVersionTable.PSVersion.Major -ge 6){Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules'}else{Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Modules'};`$p=Join-Path `$d `$m;if(Test-Path `$p){Remove-Item `$p -Recurse -Force};`$null=New-Item -Type Directory `$p -Force;`$D={param(`$b)`$m=New-Object IO.MemoryStream(,[Convert]::FromBase64String(`$b));(New-Object IO.StreamReader(New-Object IO.Compression.DeflateStream(`$m,[IO.Compression.CompressionMode]::Decompress))).ReadToEnd()};[IO.File]::WriteAllText((Join-Path `$p `"`$m.psm1`"),(&`$D '$psm1B64'),[Text.Encoding]::UTF8);[IO.File]::WriteAllText((Join-Path `$p `"`$m.psd1`"),(&`$D '$psd1B64'),[Text.Encoding]::UTF8);Import-Module `$m -Force"

$markdown = @"
# Copy and Paste Installer

Run the following extremely optimized one-liner in your terminal to install the `$moduleName module:

``````powershell
$minified
``````
"@
Set-Content -Path $outputPath -Value $markdown -Encoding UTF8
Write-Host "[OK] Build complete: $outputPath" -ForegroundColor Green
