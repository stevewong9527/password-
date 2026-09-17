# Password Manager for macOS

Early development repository for a Mac-first, local-first password manager.

The product goal and security architecture are defined in [`SPEC.md`](SPEC.md). The active implementation checklist is in [`TODO.md`](TODO.md).

## Current status

The repository now contains the automated Milestone 4A secure app shell:

- native macOS 15+ SwiftUI `VaultMac` app target with App Sandbox
- Apple/Google-compatible password CSV parsing/import foundation
- conservative host normalization and duplicate/conflict classification
- versioned whole-vault encryption using AES-256-GCM through CryptoKit
- random 256-bit vault key
- macOS Keychain device unlock protected by user presence
- master-password recovery using Argon2id13 from pinned `swift-sodium` 0.11.0
- first-run setup transaction with `setup.json` written last
- `setup.pending` crash-recovery marker that prevents accidental overwrite of existing vault artifacts
- explicit lock and in-memory recovery-attempt backoff
- macOS 15 CI that runs package tests and builds the real `VaultMac.app`

Automated 4A work is complete, but the real-Mac interactive checklist in [`docs/MANUAL_TEST_4A.md`](docs/MANUAL_TEST_4A.md) is still required before Milestone 4A is declared complete. Credential browsing/editing, import UI, password generator UI, AutoFill, backup/restore and release hardening are later milestones.

**Do not use this repository with real credentials yet.** It is still pre-release security software.

## Security warning

This repository is public. Never commit:

- a real Apple/Google password export
- real usernames/passwords or recovery material
- vault files
- signing certificates/provisioning profiles
- environment files containing secrets

Tests use synthetic credentials only. `*.csv` and vault/recovery patterns are ignored by default to reduce accidental secret commits.

## Development

Requirements:

- Swift 6.0+
- macOS 15+ / Xcode for the native app target

Run package tests from the repository root:

```bash
swift test -Xswiftc -warnings-as-errors
```

Build the native app without signing:

```bash
xcodebuild \
  -project VaultMac.xcodeproj \
  -scheme VaultMac \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Development order

1. `VaultCore` import/normalization/conflict logic — implemented
2. encrypted vault storage — implemented
3. key management and unlock — core implemented
4. SwiftUI application — 4A automated shell implemented; manual real-Mac gate pending
5. credential management/import/password-generator UI — next application slices
6. AutoFill Credential Provider Extension
7. backup/restore and release hardening
