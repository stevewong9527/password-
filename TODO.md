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

---

## Milestone 0 — Repository bootstrap

- [x] Add `README.md` with product scope, build/test commands and security warning.
- [x] Add hardened `.gitignore` for Xcode state, password CSV exports, vault/recovery files and secrets.
- [x] Add root Swift Package for portable `VaultCore` development/testing.
- [x] Add macOS 15 GitHub Actions CI with Swift warnings treated as errors.
- [x] Avoid duplicate feature-branch CI: feature work runs through PR checks; `push` runs on `main` only.

Acceptance:

- [x] `swift test` runs from repository root.
- [x] Repository fixtures contain synthetic data only.

---

## Milestone 1 — VaultCore import foundation — COMPLETE

### 1.1 Credential model

- [x] Test `CredentialRecord` Codable round trip.
- [x] Implement UUID, title, service URL, normalized host, username, password, notes and timestamps.

### 1.2 Host normalization

- [x] Lowercase host and remove leading `www.` only.
- [x] Remove path/query/fragment from match key.
- [x] Accept bare hosts and reject malformed/missing hosts.
- [x] Do not invent an eTLD+1 algorithm.

### 1.3 CSV parser

- [x] Simple rows, quoted commas, escaped quotes, LF/CRLF and multiline fields.
- [x] Unterminated quoted field error.
- [x] Fix Swift grapheme/CRLF bug by parsing Unicode scalars.
- [x] Never log field contents from parser errors.

### 1.4 Google-compatible importer

- [x] Required `url`, `username`, `password` headers.
- [x] Extra columns and normalized header case/whitespace.
- [x] UTF-8 BOM handling.
- [x] Row-level malformed/empty-password reporting without secret content.
- [x] Preview import without mutating a vault.

### 1.5 Apple Passwords CSV mapping

Current documented fields: `Title,URL,Username,Password,Notes,OTPAuth`.

- [x] Synthetic fixture/test using documented Apple headers.
- [x] Import Title, URL, Username, Password and Notes.
- [x] Tolerate `OTPAuth` without failing import.
- [ ] Store/use `OTPAuth` when TOTP support is implemented.

### 1.6 Duplicate/conflict classifier

- [x] Same normalized host + normalized username + same password => duplicate.
- [x] Same key + different password => conflict.
- [x] Different host or username => distinct.
- [x] Username comparison trims whitespace and is case-insensitive.
- [x] Never auto-merge related-but-different hosts.

Review:

- [x] Portable tests pass.
- [x] macOS CI passes with warnings as errors.
- [x] Review covered matching, plaintext leakage and CSV edge cases.

---

## Milestone 2 — Encrypted vault storage — COMPLETE

- [x] Versioned `VaultEnvelope` and versioned plaintext `VaultDocument`.
- [x] Persisted vault test confirms known plaintext password is absent.
- [x] Modified authentication tag fails closed.
- [x] Repeated encryption of unchanged plaintext uses different nonce/ciphertext.
- [x] Random 256-bit vault key generation.
- [x] AES-256-GCM through CryptoKit; no custom cryptographic primitive.
- [x] Atomic encrypted file replacement.
- [x] Recoverable previous encrypted `.bak` copy.
- [x] Failed replacement preserves the previous vault.
- [x] Unsupported envelope/document versions are rejected.
- [x] Empty vault round-trip.
- [x] 5,000-record synthetic vault round-trip.
- [x] Document v1 on-disk envelope and migration rule in `docs/VAULT_FORMAT.md`.
- [x] macOS 15 CI verifies CryptoKit path.

Acceptance:

- [x] No plaintext credential metadata is intentionally persisted outside ciphertext.
- [x] Authentication/tag failure is fail-closed.
- [x] No custom cryptographic primitive is implemented.

---

## Milestone 3 — Key management and unlock — IN PROGRESS

### 3A Device-local key path

- [x] Define `VaultKeyProvider` interface.
- [x] Add `VaultSession` locked/unlocked state.
- [x] RED/green: locked session cannot release usable vault key material.
- [x] RED/green: explicit lock clears cached session key state.
- [x] Reject non-256-bit key material before caching/installation.
- [x] Implement macOS Keychain vault-key provider.
- [x] Protect Keychain item with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` + user presence.
- [x] Use `LAContext` for Keychain authentication interaction.
- [x] macOS CI compiles and tests the platform-specific implementation.
- [ ] Manual Touch ID / system-password retrieval test once the macOS app target exists.

### 3B Master-password recovery

- [ ] Select and pin a reviewed Argon2id implementation.
- [ ] Define versioned recovery-key wrapping envelope.
- [ ] RED: wrong master password cannot unwrap the vault key.
- [ ] RED: modified recovery envelope fails closed.
- [ ] Store KDF salt and parameters, never the master password.
- [ ] Prevent silent KDF downgrade.
- [ ] Add UI backoff for repeated recovery attempts.

---

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

---

## Milestone 5 — AutoFill Credential Provider

- [ ] Add Credential Provider Extension target.
- [ ] Add AutoFill Credential Provider entitlement to app and extension.
- [ ] Configure App Group shared encrypted vault access.
- [ ] Populate/update `ASCredentialIdentityStore` without passwords.
- [ ] Return matching credentials for OS service identifiers.
- [ ] RED/manual test: unrelated domain cannot receive a credential.
- [ ] Handle a locked vault with only the minimum authentication interaction.
- [ ] Add extension-enable onboarding with supported AuthenticationServices APIs.

---

## Milestone 6 — Backup, restore and release hardening

- [ ] Encrypted backup export.
- [ ] Authenticated restore with version validation.
- [ ] Explicit plaintext interoperability export with warning + re-authentication.
- [ ] Privacy policy/security model documentation.
- [ ] App Store sandbox/signing/notarization/export-compliance checklist.
- [ ] Dependency/SBOM review.
- [ ] Manual security regression checklist.
- [ ] Threat-model review before public beta.

---

## Next execution batch

Milestone 3B: design and test master-password recovery around the same random vault key. Keep recovery independent from the Keychain path so either path unwraps/releases the same 256-bit vault key without changing the encrypted vault format.
