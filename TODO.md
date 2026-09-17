# Password Manager — TODO

Date: 2026-09-17
Source of truth: `SPEC.md`
Active branch: `feature/mvp-core`

## Working rules

- Use TDD for production behavior: failing test -> minimal implementation -> green -> refactor.
- Never add real password exports, vaults, secrets or signing material to Git.
- Keep security-sensitive changes small enough to review independently.
- Prefer Apple system frameworks and audited libraries over custom cryptography.
- Update this file after each completed implementation/review cycle.

---

## Milestone 0 — Repository bootstrap

- [x] Add `README.md` with product scope, build/test commands and security warning.
- [x] Add hardened `.gitignore` for Xcode state, password CSV exports, vault/recovery files and secrets.
- [x] Add root Swift Package for portable `VaultCore` development/testing.
- [ ] Add GitHub Actions CI after the first core branch is merged.

Acceptance:

- [x] `swift test` runs from repository root.
- [x] Repository fixtures contain synthetic data only.

---

## Milestone 1 — VaultCore import foundation

### 1.1 Credential model

- [x] Test `CredentialRecord` Codable round trip.
- [x] Implement UUID, title, service URL, normalized host, username, password, notes and timestamps.

### 1.2 Host normalization

- [x] Test lowercase host normalization.
- [x] Test leading `www.` removal.
- [x] Test path/query/fragment removal from the match key.
- [x] Test bare-host input.
- [x] Test malformed/missing-host rejection.
- [x] Implement conservative `HostNormalizer` without an invented eTLD+1 algorithm.

### 1.3 CSV parser

- [x] Test simple rows.
- [x] Test quoted commas.
- [x] Test escaped double quotes.
- [x] Test LF and CRLF.
- [x] Test multiline quoted fields.
- [x] Test unterminated quoted fields.
- [x] Fix review-discovered Swift grapheme/CRLF bug by parsing Unicode scalars.
- [x] Implement parser without logging field contents.

### 1.4 Google-compatible importer

- [x] Test required `url`, `username`, `password` headers.
- [x] Test additional columns.
- [x] Test case/whitespace-normalized headers.
- [x] Test UTF-8 BOM on first header.
- [x] Test malformed row reporting.
- [x] Test empty password reporting.
- [x] Verify row-level issue objects do not contain the input value.
- [x] Implement preview import without mutating a vault.

### 1.5 Apple Passwords CSV mapping

Apple's current documented password CSV fields are:

`Title,URL,Username,Password,Notes,OTPAuth`

- [x] Add a synthetic fixture/test using the documented Apple headers.
- [x] Import Title, URL, Username, Password and Notes through the shared importer.
- [x] Tolerate the `OTPAuth` column without failing import.
- [ ] Store/use `OTPAuth` when the TOTP milestone is implemented; it is intentionally ignored for now.

### 1.6 Duplicate/conflict classifier

- [x] Same normalized host + normalized username + same password => `duplicate`.
- [x] Same normalized host + normalized username + different password => `conflict`.
- [x] Different host or username => `distinct`.
- [x] Username comparison trims whitespace and is case-insensitive as specified.
- [x] Never auto-merge related-but-different hosts.

### Milestone 1 review status

- [x] Full portable-core test suite passes locally.
- [x] Tests compile with Swift warnings treated as errors.
- [x] Review covered conservative matching, plaintext error leakage and CSV edge cases.
- [x] Review fixes applied: CRLF parsing, BOM handling, extra/missing-field validation, unnecessary force unwrap removed.
- [ ] Add CI and run the same suite on macOS before merging the first production app target.

---

## Milestone 2 — Encrypted vault storage — NEXT

- [ ] Define versioned `VaultDocument` envelope.
- [ ] RED: persisted vault must not contain a known plaintext test value.
- [ ] RED: modified ciphertext/tag must fail to open.
- [ ] RED: repeated saves of unchanged plaintext produce different ciphertext/nonces.
- [ ] Implement random 256-bit vault key.
- [ ] Implement AES-256-GCM using CryptoKit.
- [ ] Implement atomic encrypted file replacement.
- [ ] Keep a recoverable previous encrypted copy during replacement.
- [ ] Test empty, normal, large synthetic and corrupted vaults.
- [ ] Document on-disk envelope/version migration rules.

Acceptance:

- No plaintext credential metadata is visible in the persisted vault.
- Authentication/tag failure is fail-closed.
- No custom cryptographic primitive is implemented.

---

## Milestone 3 — Key management and unlock

- [ ] Define `VaultKeyProvider` interface.
- [ ] Implement Keychain-backed device protection.
- [ ] Add LocalAuthentication / Touch ID user-presence gate where supported.
- [ ] RED: locked provider cannot release usable vault key material.
- [ ] RED: explicit lock clears cached decrypted key/state.
- [ ] Implement master-password recovery using Argon2id from a pinned reviewed implementation.
- [ ] Store KDF salt/parameters, never the master password.
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
- [ ] Handle a locked vault with only the minimum required authentication interaction.
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

## Completed first execution batch

- [x] M0 repository bootstrap.
- [x] M1.1 credential model.
- [x] M1.2 host normalization.
- [x] M1.3 CSV parser.
- [x] M1.4 Google-compatible import.
- [x] M1.5 Apple documented header compatibility for password fields.
- [x] M1.6 duplicate/conflict classification.
- [x] Run tests.
- [x] Review code against `SPEC.md`.
- [x] Apply review fixes.
- [x] Re-run tests with warnings as errors.

## Next execution batch

Start Milestone 2 with tests first: versioned vault envelope, AES-GCM ciphertext integrity, nonce uniqueness and atomic encrypted persistence.
