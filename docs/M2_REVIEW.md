# Milestone 2 Security Review

Date: 2026-09-17
Branch: `feature/m2-encrypted-vault`

## Reviewed scope

- `VaultDocument` schema versioning
- random 256-bit `VaultKey`
- AES-256-GCM seal/open through CryptoKit
- encrypted envelope version and algorithm checks
- nonce/ciphertext/tag persistence
- wrong-key and tamper failure behavior
- atomic/staged file replacement
- retained previous encrypted copy
- plaintext leakage checks

## Findings and fixes

1. **TDD discovery issue** — the first crypto tests were not initially registered in `Package.swift`, which made CI appear green without running them. The test target was registered and RED was re-verified as `no such module 'VaultCrypto'` before implementation.
2. **Swift Testing syntax issue** — two `#require` calls needed `try`; this was corrected without changing production code.
3. **Document schema compatibility gap** — authenticated plaintext could decode a `VaultDocument` carrying an unsupported schema version. A regression test was added first, then `VaultCipher.open` was changed to reject unknown `VaultDocument.version` values explicitly.

## Verification

Latest verified command:

```sh
swift test -Xswiftc -warnings-as-errors
```

Verified on GitHub Actions macOS 15 arm64, Apple Swift 6.1.2.

Result: 34 tests passed.

## Deferred intentionally

- Keychain key storage/wrapping
- LocalAuthentication / Touch ID
- master-password recovery / Argon2id
- App Group integration
- application UI

These belong to Milestone 3 or later and are not mixed into `VaultCrypto`.
