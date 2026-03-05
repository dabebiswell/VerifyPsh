# Verify.psh

Verify.psh provides a simple utility for generating standalone, interactive PowerShell scripts to verify file integrity using cryptographic hashes. It's intended to be shipped alongside files whose integrity you care about (e.g., binaries, backups, archives).

## Features

- **Double-Click Friendly**: The generated scripts display interactive pass/fail output and wait for the user to press Enter before exiting.
- **Pipeline Ready**: Generated scripts return standard exit codes (`0` for Success, `1` for Failure/Missing) and can be run non-interactively using the `-NoPause` switch.
- **Parametric Targeting**: The output scripts default to checking the file they were generated for, but can accept alternate file paths via the `-TargetFile` parameter.
- **Flexible Hashing**: Choose between `SHA256` (default), `SHA384`, `SHA512`, or `MD5` when generating the verification script.

## Usage

### Generating a Verification Script

Use `New-VerifyScript.ps1` to generate a validation script for a target file.

```powershell
# Basic usage (defaults to SHA256)
.\New-VerifyScript.ps1 .\my-archive.zip

# Specify a different algorithm
.\New-VerifyScript.ps1 .\my-archive.zip -Algorithm SHA512
```

This will automatically calculate the hash of `my-archive.zip` and generate `Verify-my-archive.ps1` in the same directory.

### Running a Verification Script

Distribute both your file (`my-archive.zip`) and its generated validation script (`Verify-my-archive.ps1`) to your end user.

The user can natively execute it in three ways:

1. **Interactively (Double-click / Terminal)**
   Normally, running the script natively will calculate the checksum, report the result, and pause:
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

## Security Considerations

*Note: Generating a verification script does not make the file tamper-proof.*

If a malicious actor alters a file in transit, they could also easily update the hash inside the companion `Verify-*.ps1` script so that it falsely validates the tampered file. 

To cryptographically ensure that the validation mechanism itself hasn't been tampered with, you should adopt one of the following strategies:
- **Authenticode Signing**: Sign the generated `.ps1` script using a Code Signing Certificate. If execution policies are enforced (`AllSigned` or `RemoteSigned`), Windows will refuse to run the generated script if any text inside the script has been modified.
- **Detached Signatures**: Generate a GPG/PGP signature for the target file and distribute a `.sig` file, having the user execute their own validation.
- **Trusted Endpoints**: Modify the generated scripts to dynamically retrieve known-good hashes from an HTTPS endpoint you explicitly control.
