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

- [x] Versioned vault envelope/document.
- [x] AES-256-GCM through CryptoKit with fresh nonce.
- [x] Plaintext-at-rest and tamper fail-closed regression tests.
- [x] Atomic replacement + encrypted `.bak` recovery copy.
- [x] Empty + 5,000-record vault coverage.
- [x] `docs/VAULT_FORMAT.md`.

## Milestone 3 — Key management and unlock — COMPLETE FOR CORE

### 3A Device-local key path

- [x] `VaultKeyProvider` + `VaultSession`.
- [x] Lock clears cached key state and rejects non-256-bit key material.
- [x] macOS Keychain provider with `ThisDeviceOnly` + user presence and `LAContext`.
- [x] macOS CI coverage.
- [ ] Real-Mac Touch ID/system-password retrieval check (`docs/MANUAL_TEST_4A.md`).

### 3B Master-password recovery

- [x] Pin `jedisct1/swift-sodium` `0.11.0`.
- [x] Argon2id13 recovery envelope around the same random 256-bit vault key.
- [x] Store salt + KDF parameters, never master password.
- [x] Wrong password/tamper fail closed.
- [x] Reject weaker KDF parameters; no silent downgrade.
- [x] Real libsodium Argon2id + CryptoKit integration passes macOS CI.
- [x] Recovery backoff policy/state machine: 1s, 2s, 4s... capped at 30s and reset on success.
- [x] `docs/RECOVERY_FORMAT.md`.

## Milestone 4 — macOS SwiftUI application — IN PROGRESS

### 4A Secure app shell — AUTOMATED WORK COMPLETE

- [x] Create native `VaultMac.xcodeproj` for macOS 15+ and bundle id `com.stevewong.vaultmac`.
- [x] Enable App Sandbox with no unnecessary network/file entitlements.
- [x] Wire `VaultAppCore` to Keychain, Argon2id, AES-GCM and encrypted vault storage.
- [x] First-run Create Vault screen with master-password confirmation.
- [x] Locked screen with device-authentication unlock and master-password recovery sheet.
- [x] Unlocked shell with record count and explicit Lock.
- [x] Setup completion marker is written only after recovery, vault and Keychain steps succeed.
- [x] Add `setup.pending` transaction marker so interrupted setup can be cleaned safely.
- [x] Existing vault/recovery artifacts without a pending marker are never silently overwritten or deleted.
- [x] Package tests run with warnings-as-errors.
- [x] GitHub macOS 15 CI builds the real `VaultMac` app with signing disabled.
- [x] Add real-Mac checklist at `docs/MANUAL_TEST_4A.md`.
- [ ] Execute and record the real-Mac first-run, Touch ID/system-password, recovery and corruption checklist.

### Later Milestone 4 slices

- [ ] Credential list/search/detail UI.
- [ ] Add/edit/delete credential flows.
- [ ] Import picker + preview + conflict resolution.
- [ ] Password generator UI.
- [ ] Clipboard safe delayed clear.
- [ ] Auto-lock and workstation-lock handling.
- [ ] Local reused/weak password audit.

## Milestone 5 — AutoFill Credential Provider

- [ ] Credential Provider Extension + App Group.
- [ ] `ASCredentialIdentityStore` without passwords.
- [ ] Domain-safe credential matching and fail-closed behavior.

## Milestone 6 — Backup, restore and release hardening

- [ ] Encrypted backup/restore.
- [ ] Explicit plaintext interoperability export with warning + re-authentication.
- [ ] Privacy/security docs, App Store/export compliance, dependency/SBOM review.
- [ ] Manual security regression + threat-model review.

## Next execution batch

Run `docs/MANUAL_TEST_4A.md` on a real Mac. Once the interactive checklist passes, mark 4A complete and start the credential list/search/detail slice without changing the vault format.
