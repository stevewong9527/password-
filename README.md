# Password Manager for macOS

Early development repository for a Mac-first, local-first password manager.

The product goal and security architecture are defined in [`SPEC.md`](SPEC.md). The active implementation checklist is in [`TODO.md`](TODO.md).

## Current status

The repository currently contains the first portable `VaultCore` slice:

- credential model
- conservative host normalization
- CSV parsing with quoted commas, escaped quotes, CRLF/LF and multiline fields
- Google-compatible password CSV import
- Apple Passwords-compatible header handling (`Title,URL,Username,Password,Notes,OTPAuth`; OTPAuth is currently ignored)
- duplicate/conflict classification

Encryption, Keychain/Touch ID integration, SwiftUI UI and the macOS AutoFill extension are not implemented yet. Do **not** use this repository as a real password manager yet.

## Security warning

This repository is public. Never commit:

- a real Apple/Google password export
- real usernames/passwords or recovery material
- vault files
- signing certificates/provisioning profiles
- environment files containing secrets

Tests use synthetic credentials only. `*.csv` is ignored by default to reduce accidental password-export commits.

## Development

Requirements for the portable core:

- Swift 6.0+

Run tests from the repository root:

```bash
swift test
```

The production macOS app will target macOS 15+ and use SwiftUI, AuthenticationServices, CryptoKit, Keychain and LocalAuthentication according to `SPEC.md`.

## Development order

1. `VaultCore` import/normalization/conflict logic
2. encrypted vault storage
3. key management and unlock
4. SwiftUI application
5. AutoFill Credential Provider Extension
6. backup/restore and release hardening
