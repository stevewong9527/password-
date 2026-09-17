# Password Manager — TODO

Date: 2026-09-17
Source of truth: `SPEC.md`
Active branch: `feature/mvp-core`

## Working rules

- Use TDD for production behavior: failing test -> minimal implementation -> green -> refactor.
- Never add real password exports, vaults, secrets or signing material to Git.
- Keep security-sensitive changes small enough to review independently.
- Prefer Apple system frameworks and audited libraries over custom cryptography.
- Batch GitHub writes so one logical change creates one CI cycle.
- Update this file after each completed implementation/review cycle.

## Milestone 0 — Repository bootstrap — COMPLETE

- [x] README, hardened `.gitignore`, Swift package, macOS 15 CI.
- [x] Feature work runs through PR checks; `push` CI runs on `main` only.

## Milestone 1 — VaultCore import foundation — COMPLETE

- [x] Credential model, host normalization, CSV parser.
- [x] Google-compatible import.
- [x] Apple documented header compatibility (`Title,URL,Username,Password,Notes,OTPAuth`).
- [x] Conservative duplicate/conflict classification.
- [x] Portable + macOS CI coverage.
- [ ] Store/use `OTPAuth` when TOTP support is implemented.

## Milestone 2 — Encrypted vault storage — COMPLETE

- [x] Versioned `VaultEnvelope` and `VaultDocument`.
- [x] AES-256-GCM through CryptoKit with fresh nonce.
- [x] Plaintext-at-rest regression test and tamper fail-closed test.
- [x] Atomic replacement + recoverable encrypted `.bak`.
- [x] Unsupported envelope/document versions rejected.
- [x] Empty and 5,000-record vault tests.
- [x] `docs/VAULT_FORMAT.md`.

## Milestone 3 — Key management and unlock — IN PROGRESS

### 3A Device-local key path — COMPLETE EXCEPT APP MANUAL TEST

- [x] `VaultKeyProvider` and `VaultSession`.
- [x] Locked session cannot release usable vault key material.
- [x] Explicit lock clears cached session key state.
- [x] Reject non-256-bit key material.
- [x] macOS Keychain provider with `ThisDeviceOnly` + user presence.
- [x] `LAContext` interaction path.
- [x] macOS CI compiles/tests platform code.
- [ ] Manual Touch ID / system-password retrieval test once app target exists.

### 3B Master-password recovery — CODE COMPLETE, CI PENDING

- [x] Pin reviewed Argon2id implementation: `jedisct1/swift-sodium` `0.11.0`.
- [x] Define versioned recovery-key wrapping envelope.
- [x] Wrong master password cannot unwrap vault key.
- [x] Modified recovery envelope fails closed.
- [x] Store KDF salt + parameters; never store master password.
- [x] Reject KDF parameters below production policy; no silent downgrade.
- [x] Wrap the same random 256-bit vault key rather than encrypting vault records with the master password.
- [x] Document format/policy in `docs/RECOVERY_FORMAT.md`.
- [x] Local fake-KDF recovery tests pass with warnings as errors.
- [ ] macOS CI verifies real libsodium Argon2id + CryptoKit integration.
- [ ] Add UI/session backoff for repeated recovery attempts.

## Milestone 4 — macOS SwiftUI application

- [ ] Create Xcode macOS app target with App Sandbox.
- [ ] First-run vault creation/unlock flow.
- [ ] Credential list/search/detail UI.
- [ ] Add/edit/delete credential flows.
- [ ] Import picker + preview + conflict-resolution UI.
- [ ] Password generator UI.
- [ ] Clipboard copy with safe delayed clear.
- [ ] Auto-lock and workstation-lock handling.
- [ ] Local reused/weak password audit.

## Milestone 5 — AutoFill Credential Provider

- [ ] Add Credential Provider Extension target.
- [ ] App Group encrypted vault sharing.
- [ ] `ASCredentialIdentityStore` without passwords.
- [ ] Domain-safe credential selection and fail-closed matching.

## Milestone 6 — Backup, restore and release hardening

- [ ] Encrypted backup/restore.
- [ ] Explicit plaintext interoperability export with warning + re-authentication.
- [ ] Privacy/security docs, App Store/export compliance, dependency/SBOM review.
- [ ] Manual security regression + threat-model review before public beta.

## Next execution batch

Wait for macOS CI on Milestone 3B. If green, add recovery-attempt backoff as a small independent policy component, then start the macOS SwiftUI app shell and real first-run/unlock flow.
