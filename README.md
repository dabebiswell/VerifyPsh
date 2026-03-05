# Verify.psh

Verify.psh provides a simple utility for generating standalone, interactive PowerShell scripts to verify file integrity using cryptographic hashes. It's intended to be shipped alongside files whose integrity you care about (e.g., binaries, backups, archives).

## Features

- **Right-Click Friendly**: The generated scripts display interactive pass/fail output and wait for the user to press Enter before exiting. They are built to safely execute via the "Run with PowerShell" context menu.
- **Pipeline Ready**: Generated scripts return standard exit codes (`0` for Success, `1` for Failure/Missing) and can be run non-interactively using the `-NoPause` switch.
- **Parametric Targeting**: The output scripts default to checking the file they were generated for, but can accept alternate file paths via the `-TargetFile` parameter.
- **Flexible Hashing**: Choose between `SHA256` (default), `SHA384`, `SHA512`, or `MD5` when generating the verification script.
- **Visual Feedback**: Both the generator and verification scripts include an animated Braille loading spinner during hash calculations, providing clear progress indication for large files.

## Installation

You can install `VerifyPsh` directly into your `CurrentUser` module scope using the compiled installer script.

1. Download or execute the `Install-VerifyPsh.ps1` script on your machine.
2. The `New-VerifyScript` command is instantly available in your session.

### Building the Installer
If you modify `VerifyPsh.psm1` or `VerifyPsh.psd1`, you must compile a new installer:

```powershell
# Standard Installer (Generates Install-VerifyPsh.ps1)
.\build.ps1

# Ultra-Minimal One-Liner (Generates oneliner-install.md)
.\build.ps1 -OneLiner
```

This will encode your changes and regenerate the deployment files.

## Usage

### Generating a Verification Script

Use `New-VerifyScript` (now globally available) to generate a validation script for a target file.

```powershell
# Basic usage (defaults to SHA256)
New-VerifyScript .\my-archive.zip

# Specify a different algorithm
New-VerifyScript .\my-archive.zip -Algorithm SHA512
```

This will automatically calculate the hash of `my-archive.zip` and generate `Verify-my-archive.ps1` in the same directory.

### Running a Verification Script

Distribute both your file (`my-archive.zip`) and its generated validation script (`Verify-my-archive.ps1`) to your end user.

The user can natively execute it in three ways:

1. **Interactively (Right-Click -> Run with PowerShell)**
   Normally, running the script natively from the right-click menu will calculate the checksum, report the result, and pause:
   ```powershell
   .\Verify-my-archive.ps1
   ```
   
2. **Automated / Headless Environment**
   If you're deploying in a CI/CD pipeline or automated process, you can skip the "Press Enter to exit" prompt:
   ```powershell
   .\Verify-my-archive.ps1 -NoPause
   ```

3. **Verify a File in a Different Location**
   By default, the script looks for the file in the exact same directory. Users can override the path:
   ```powershell
   .\Verify-my-archive.ps1 -TargetFile "C:\Downloads\my-archive-copy.zip"
   ```