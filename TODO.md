# Password Manager — TODO

Date: 2026-09-17
Source of truth: `SPEC.md`

## Working rules

- [ ] Use TDD for production behavior: failing test -> minimal implementation -> green -> refactor.
- [ ] Never add real password exports, vaults, secrets or signing material to Git.
- [ ] Keep security-sensitive changes small enough to review independently.
- [ ] Prefer Apple system frameworks and audited libraries over custom cryptography.
- [ ] Update this file after each completed implementation/review cycle.

---

## Milestone 0 — Repository bootstrap

- [ ] Add `README.md` with product scope, local build/test commands and security warning.
- [ ] Add hardened `.gitignore` for Xcode user state, exported-password CSV, vault files, environment/secrets files and recovery artifacts.
- [ ] Add root Swift Package for portable `VaultCore` development/testing.
- [ ] Add CI later after first package tests are stable.

Acceptance:

- `swift test` runs from repository root.
- Repository contains no real secrets or private fixtures.

---

## Milestone 1 — VaultCore import foundation

### 1.1 Credential model

- [ ] Test `CredentialRecord` initialization/equality/Codable round trip.
- [ ] Implement `CredentialRecord` with UUID, title, service URL, normalized host, username, password, notes and timestamps.

### 1.2 Host normalization

- [ ] Test lowercasing host.
- [ ] Test leading `www.` removal.
- [ ] Test path/query/fragment removal from match key.
- [ ] Test malformed/missing-host URL rejection.
- [ ] Implement conservative `HostNormalizer`.

### 1.3 CSV parser

- [ ] Test simple rows.
- [ ] Test quoted comma.
- [ ] Test escaped double quote.
- [ ] Test CRLF/LF.
- [ ] Test multiline quoted field.
- [ ] Test malformed unterminated quote returns an error without secret content.
- [ ] Implement a small RFC-4180-style parser for importer input.

### 1.4 Google-compatible importer

- [ ] Test required header mapping for `url`, `username`, `password`.
- [ ] Test extra columns are tolerated.
- [ ] Test case/whitespace normalization for headers.
- [ ] Test malformed rows produce row-level validation errors.
- [ ] Implement `PasswordCSVImporter` returning preview rows, not directly mutating a vault.

### 1.5 Apple importer mapping

- [ ] Capture synthetic header fixtures representing current Apple Passwords export.
- [ ] Map Apple title/site/user/password/notes aliases through the same importer pipeline.
- [ ] Keep mapping explicit and unit tested; do not guess silently when a required field is missing.

### 1.6 Duplicate/conflict classifier

- [ ] Same normalized host + normalized username + same password => duplicate.
- [ ] Same normalized host + normalized username + different password => conflict.
- [ ] Different host or username => distinct.
- [ ] Username comparison is case-insensitive after trimming for duplicate classification.
- [ ] Implement `ImportConflictClassifier` with `duplicate`, `conflict`, `distinct` outcomes.

Acceptance:

- All synthetic import/core unit tests pass on `swift test`.
- Review confirms no secret values appear in error descriptions.

---

## Milestone 2 — Encrypted vault storage

- [ ] Define versioned `VaultDocument` envelope.
- [ ] RED: persisted vault must not contain known plaintext test password.
- [ ] RED: modified ciphertext/tag must fail to open.
- [ ] RED: repeated saves produce different ciphertext for unchanged plaintext.
- [ ] Implement random 256-bit vault key.
- [ ] Implement AES-256-GCM encryption using CryptoKit.
- [ ] Implement atomic encrypted file replacement with recoverable previous encrypted copy.
- [ ] Test empty vault, normal vault, large synthetic vault and corrupted vault.
- [ ] Document on-disk envelope fields and migration/version rules.

Acceptance:

- No plaintext credential metadata is visible in the vault file.
- Authentication failure is fail-closed.

---

## Milestone 3 — Key management and unlock

- [ ] Define `VaultKeyProvider` interface.
- [ ] Implement Keychain-backed device key storage.
- [ ] Add LocalAuthentication user-presence/Touch ID gate where supported.
- [ ] RED: locked provider cannot release the vault key.
- [ ] RED: explicit lock clears cached decrypted key/state.
- [ ] Add master-password recovery design implementation using Argon2id from a pinned reviewed library.
- [ ] Store KDF salt/parameters, never the master password.
- [ ] Add exponential UI backoff for repeated recovery attempts.

Acceptance:

- Device unlock and recovery paths unwrap the same random vault key.
- No silent KDF downgrade exists.

---

## Milestone 4 — macOS SwiftUI application

- [ ] Create Xcode macOS app target with App Sandbox.
- [ ] First-run vault creation/unlock flow.
- [ ] Credential list/search/detail UI.
- [ ] Add/edit/delete credential flows.
- [ ] Import picker + preview + conflict-resolution UI.
- [ ] Password generator UI.
- [ ] Clipboard copy with safe delayed clear.
- [ ] Auto-lock timer and workstation-lock handling.
- [ ] Local reused/weak password audit.

Acceptance:

- A user can install, create/unlock a vault, import a synthetic CSV, resolve conflicts and manage credentials without network access.

---

## Milestone 5 — AutoFill Credential Provider

- [ ] Add Credential Provider Extension target.
- [ ] Add AutoFill Credential Provider entitlement to app and extension.
- [ ] Configure App Group shared encrypted vault access.
- [ ] Populate/update `ASCredentialIdentityStore` without passwords.
- [ ] Return matching credentials for OS service identifiers.
- [ ] RED/manual test: unrelated domain cannot receive a credential.
- [ ] Handle locked vault by requesting only the required user interaction.
- [ ] Add extension-enable onboarding using supported AuthenticationServices settings flow when available.

Acceptance:

- Matching credential appears in macOS AutoFill and fills successfully.
- Deliberately unrelated sites do not receive the credential.

---

## Milestone 6 — Backup, restore and release hardening

- [ ] Encrypted backup export.
- [ ] Authenticated restore with version validation.
- [ ] Explicit plaintext interoperability export with strong warnings and re-authentication.
- [ ] Privacy policy/security model documentation.
- [ ] App Store sandbox/signing/notarization/export-compliance checklist.
- [ ] Dependency/SBOM review.
- [ ] Manual security regression checklist.
- [ ] Threat-model review before public beta.

Acceptance:

- Release candidate passes automated tests and manual macOS AutoFill/sandbox checks.
- No test or build artifact contains real credentials.

---

## First execution batch

This is the batch to implement now:

- [ ] M0: `README.md`, `.gitignore`, Swift package skeleton.
- [ ] M1.1: `CredentialRecord` tests + implementation.
- [ ] M1.2: `HostNormalizer` tests + implementation.
- [ ] M1.3: CSV parser tests + implementation.
- [ ] M1.4: Google-compatible importer tests + implementation.
- [ ] M1.6: duplicate/conflict tests + implementation.
- [ ] Run full `swift test`.
- [ ] Review code against `SPEC.md` for over-broad matching, plaintext logging and parser edge cases.
- [ ] Fix review findings.
- [ ] Re-run full test suite and update completed checkboxes.
