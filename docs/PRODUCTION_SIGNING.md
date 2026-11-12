# MFSL Office production signing

The private files are deliberately **not stored in Git**. Keep at least two encrypted backups under company control. Losing the Android key means no future build can update installations signed by it.

## Generated identities

- Android application ID: `com.n_o_group.mfsl_office`
- Android PKCS#12 alias: `com.n_o_group.mfsl_office`
- Windows MSIX publisher subject: `CN=N.O Group`
- Windows certificate: reusable self-signed code-signing identity (valid through 2036)

Changing the Android application ID means Android treats MFSL Office as a new application. It will install separately from builds that used `com.n_o_group.mfsl`, as explicitly selected for this release.

## Download and back up

Download these out-of-band deliverables from the Arena workspace:

1. `signing-output/signing-keys.zip`
2. `signing-output/signing-password.txt`

Never commit either file, paste them into issues, or send them through ordinary messaging. The repository ignores all corresponding private-key formats.

## Configure GitHub Actions

Create these Actions repository secrets:

- `MFSL_SIGNING_PASSWORD`: exact contents of `signing-password.txt`
- `MFSL_ANDROID_KEYSTORE_BASE64`: base64 text of `mfsl-office-android.p12`
- `MFSL_WINDOWS_PFX_BASE64`: base64 text of `mfsl-office-windows.pfx`

Linux/macOS base64 command:

```sh
base64 -w 0 mfsl-office-android.p12
base64 -w 0 mfsl-office-windows.pfx
```

PowerShell base64 command:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('mfsl-office-android.p12'))
[Convert]::ToBase64String([IO.File]::ReadAllBytes('mfsl-office-windows.pfx'))
```

The build workflow automatically detects these secrets. Without them it warns and falls back to development signing; such a build must not be publicly released.

## Trust the no-cost Windows certificate

A self-signed certificate does not receive automatic public trust. Before installing the MSIX on each company computer:

1. Copy `mfsl-office-windows.cer` to the computer.
2. Double-click it and choose **Install Certificate**.
3. Select **Local Machine** (administrator approval may be requested).
4. Choose **Place all certificates in the following store**.
5. Select **Trusted People** and complete the wizard.
6. Install the MFSL Office MSIX.

Only install the public `.cer`; never place the private `.pfx` on staff computers. The portable ZIP remains available where certificate installation is not desired, though Windows SmartScreen may warn because the certificate is not publicly trusted.
