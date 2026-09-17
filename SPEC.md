# Password Manager for macOS — Product & Security Specification

Status: Draft v0.1
Date: 2026-09-17
Target: Downloadable consumer macOS product

## 1. Product goal

Build a Mac-first password manager that lets users import passwords exported from Apple Passwords and Google Password Manager, store them in a local encrypted vault, generate strong passwords, search/manage credentials, and use the vault as a macOS AutoFill credential provider.

The first public release must be useful without creating an online account. Cloud sync, family sharing, passkeys, and team features are later phases.

## 2. v1 scope

### In scope

- Native macOS app using Swift and SwiftUI.
- Local encrypted vault.
- Touch ID / system user-presence unlock where available.
- Optional master-password recovery path.
- Import CSV exported from Apple Passwords.
- Import CSV compatible with Google Password Manager (`url`, `username`, `password`; additional columns tolerated).
- Import preview before committing changes.
- Conservative duplicate and conflict detection.
- Password generator using cryptographically secure randomness.
- Search, view, add, edit, delete and copy credentials.
- Auto-lock after inactivity / workstation lock.
- macOS AutoFill Credential Provider Extension.
- Local security audit: weak and reused passwords.
- Encrypted local backup/export format.

### Explicitly out of scope for v1

- Cloud sync.
- Android or Windows clients.
- Browser-specific extensions unless system AutoFill proves insufficient.
- Family/team sharing.
- Emergency access.
- Importing Apple/Google passkeys from CSV.
- Breach lookup over the network.
- AI-generated passwords or sending credentials to an AI service.

## 3. Platform and distribution

- Primary target: native macOS.
- UI: SwiftUI.
- AutoFill: AuthenticationServices Credential Provider Extension.
- Distribution target: Mac App Store first; direct notarized distribution may follow.
- App Sandbox must remain enabled for App Store builds.
- App and AutoFill extension share only the minimum required data using an App Group container.

## 4. Security principles

1. A credential password must never be stored unencrypted on persistent storage by this app.
2. Real credentials, exported CSV files, vault files, recovery secrets and signing secrets must never be committed to Git.
3. No password, vault key, recovery key or plaintext vault record may be written to application logs, analytics, crash metadata or telemetry.
4. Cryptographic primitives must come from established system/audited libraries. Do not implement encryption primitives manually.
5. Network access is not required for core v1 functionality.
6. AutoFill must use the service identifier/domain supplied by the OS and must not silently fill a credential into an unrelated domain.
7. Imported plaintext CSV is treated as highly sensitive transient input.
8. Security-sensitive operations require tests and explicit error states; silent fallback to insecure behavior is forbidden.

## 5. Threat model

### Protect against

- Theft or copying of the Mac while the vault is locked.
- Another local user reading the vault file without successful authentication.
- Accidental exposure of plaintext CSV through our own temp files or logs.
- Accidental Git commits of credentials/vault data.
- Wrong-site AutoFill caused by overly broad domain matching.
- Tampering/corruption of the encrypted vault file.

### Not fully protect against

- Malware/keyloggers running with the user's privileges while the vault is unlocked.
- A fully compromised/rooted operating system.
- Screen capture or shoulder surfing after the user reveals a secret.
- A malicious website after the user intentionally copies a credential into it.

These limitations must be reflected in user-facing security documentation and must not be marketed as protection against a compromised endpoint.

## 6. Vault architecture

### 6.1 Vault plaintext model

The logical plaintext vault is a versioned Codable document containing records such as:

```swift
struct CredentialRecord: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var serviceURL: String
    var normalizedHost: String
    var username: String
    var password: String
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
}
```

The exact schema may evolve, but migrations must be versioned and tested.

### 6.2 Storage strategy

For v1, encrypt the entire serialized vault document as a single authenticated ciphertext instead of introducing SQLCipher or a custom encrypted database.

Rationale:

- Keeps all record metadata encrypted at rest.
- Minimizes third-party dependencies and attack surface.
- A vault containing thousands of credentials remains small enough for atomic full-file rewrites.
- Simplifies integrity verification and backup.

The storage layer must:

- Serialize a versioned document.
- Encrypt using an authenticated encryption mode (AES-256-GCM through CryptoKit is the preferred v1 choice).
- Use a fresh nonce as required by the chosen API for every write.
- Write to a temporary sibling file and atomically replace the previous vault only after encryption succeeds.
- Keep a recoverable previous encrypted copy during an update so a failed write does not destroy the vault.
- Reject authentication-tag failures as corruption/tampering; never return partial plaintext.

### 6.3 Vault key

- Generate a random 256-bit vault key using a cryptographically secure RNG.
- The vault key is independent of the user's password.
- The raw vault key is never written to ordinary files or logs.

### 6.4 Device unlock

The vault key is wrapped/protected by a device-bound key stored through macOS Keychain, with user-presence/biometric policy where supported. Touch ID is an unlock mechanism, not the source of encryption entropy.

### 6.5 Master password / recovery

If master-password recovery is enabled:

- Derive a key using Argon2id through a pinned, reviewed implementation such as libsodium rather than a custom implementation.
- Store the KDF salt and parameters with the encrypted vault metadata.
- Use the derived key to wrap the random vault key; do not use the master password directly to encrypt every record.
- Rate limiting/backoff is required in the UI even though offline guessing cannot be fully prevented after ciphertext theft.

A build must not silently downgrade to a weaker KDF because the preferred dependency is unavailable.

## 7. Import architecture

### 7.1 Input

Use the macOS file picker. Read the chosen CSV directly; do not create a persistent plaintext copy.

Apple officially warns that exported password CSV files are unencrypted. After a successful import, show a clear reminder to delete the exported source file.

### 7.2 Parsing

The importer must:

- Correctly parse quoted commas, quotes and multiline CSV fields.
- Require a URL/site field, username field and password field after header normalization.
- Treat extra columns as optional metadata.
- Never include plaintext field values in parsing error logs.
- Produce per-row validation results so malformed rows do not silently disappear.

Google-compatible minimum headers are `url`, `username`, and `password`.

### 7.3 Normalization

Normalize conservatively:

- Parse URL with Foundation URL facilities.
- Lowercase host names.
- Remove a leading `www.` only.
- Remove URL path/query/fragment from the host match key.
- Do not invent an eTLD+1/public-suffix algorithm in v1.

A wrong automatic merge is more dangerous than leaving two possible duplicates for the user to resolve.

### 7.4 Duplicate/conflict policy

Exact duplicate key for v1:

`normalizedHost + case-insensitive normalized username`

For two records with the same key:

- Same password: classify as duplicate; default action is keep one.
- Different password: classify as conflict; require user choice (keep existing, keep imported, keep both, skip).
- Never overwrite a different password automatically.

Possible related hosts (for example `accounts.example.com` vs `example.com`) may be shown as possible duplicates later but must not be auto-merged without a public-suffix/affiliation strategy.

## 8. Password generator

- Use a cryptographically secure RNG.
- Default length: 20 characters.
- User-selectable length and character classes.
- Support site constraints when the OS provides password rules.
- Never use an LLM or deterministic PRNG for password generation.
- Do not persist generated passwords unless the user saves/uses them.

## 9. Clipboard behavior

- Copy on explicit user action only.
- Default clear interval: 60 seconds, configurable.
- Clear only if the pasteboard content/change state still corresponds to the secret written by this app; do not erase unrelated clipboard data written by another app afterward.
- Do not place secrets on a clipboard merely to implement AutoFill.

## 10. AutoFill architecture

Use Apple's AuthenticationServices Credential Provider Extension.

- Host app and extension include the AutoFill Credential Provider entitlement.
- Populate `ASCredentialIdentityStore` with only identity information needed for suggestions; passwords remain in the encrypted vault.
- Keep identity-store entries synchronized when the vault changes.
- Extension receives the requested service identifier and returns only appropriate credentials.
- If the vault requires authentication, request the minimum interaction needed to unlock and fulfill the request.
- AutoFill failure must fail closed rather than expose a broader credential list to an unrelated service.

Password-save, password-generation, OTP and passkey APIs may be added behind OS-availability checks in later milestones without changing the vault format prematurely.

## 11. Auto-lock

Default behavior:

- Lock after 5 minutes of inactivity.
- Lock when the user explicitly locks the app.
- Lock when the system session/workstation locks where macOS notifications permit reliable detection.
- Clear decrypted in-memory vault state when locking.

The UI may allow a user to choose a different inactivity timeout, but disabling auto-lock entirely should require an explicit warning.

## 12. Local security audit

v1 audit is offline only:

- Reused passwords: compare a cryptographic digest/equality result in memory while unlocked; do not persist a password-to-sites index in plaintext.
- Weak passwords: deterministic local rules and length/character checks; the UI must describe findings instead of presenting an unexplained absolute security score.
- Network breach lookup is deferred.

## 13. Backup and restore

- Backup format is encrypted and versioned.
- Never export an unencrypted backup under a generic "Backup" action.
- If a user explicitly requests plaintext interoperability export, label it clearly as plaintext and require authentication immediately beforehand.
- Restore validates format version and authenticated ciphertext before replacing the current vault.

## 14. Logging and telemetry

Allowed examples:

- app launch/version
- generic operation success/failure category
- number of imported rows only if analytics is explicitly enabled and no source identifiers are included

Forbidden:

- username
- URL containing user/private path/query data
- password
- notes
- vault key
- master/recovery secret
- plaintext CSV row
- decrypted record

v1 should default to no remote analytics.

## 15. Repository rules

The repository is currently public. Therefore:

- `.gitignore` must include common exported-password CSV names/patterns, local vault files, recovery material, environment/secrets files and Xcode user data.
- Tests use synthetic credentials only, for example `alice@example.test` and obviously fake passwords.
- No production signing certificates, provisioning profiles, secrets or real exported files are stored in the repository.
- Any sample vault must contain generated non-sensitive data.

## 16. Module boundaries

```text
PasswordManager/
  App/                         SwiftUI application shell
  CredentialProvider/          AuthenticationServices extension
  Packages/VaultCore/          models, normalization, import, conflict rules
  Packages/VaultCrypto/        vault encryption/key wrapping/storage
  Packages/VaultPlatform/      Keychain, LocalAuthentication, App Group integration
  Tests/                       integration/security regression tests
```

`VaultCore` must remain testable without UI and should avoid platform-only dependencies where practical.

## 17. MVP acceptance criteria

A v1 release candidate is not acceptable until all of the following are true:

1. Import valid Google-compatible CSV including quoted commas/newlines.
2. Import Apple-exported CSV through tested header mapping based on captured synthetic fixtures.
3. Show malformed-row errors without logging credential content.
4. Detect exact duplicates and password conflicts conservatively.
5. Create a vault and verify the persisted file does not contain plaintext test credentials.
6. Fail vault opening after ciphertext/tag tampering.
7. Unlock with approved local authentication flow.
8. Generate passwords using secure randomness.
9. AutoFill a matching credential through the Credential Provider Extension.
10. Do not AutoFill the same credential for a deliberately unrelated domain.
11. Auto-lock removes usable decrypted state.
12. Clipboard clearing does not erase newer unrelated clipboard data.
13. No real-secret fixtures or credentials exist in Git history created by this project.
14. Release build passes unit/integration tests and manual App Sandbox/AutoFill checks on macOS.

## 18. Initial implementation slice

The first implementation slice intentionally excludes encryption/UI and establishes the deterministic, portable core:

- `CredentialRecord` domain model.
- URL/host normalization.
- standards-compliant CSV tokenizer/parser sufficient for quoted commas, escaped quotes and multiline fields.
- Google-compatible importer.
- configurable Apple header mapping.
- duplicate/conflict classifier.
- synthetic test fixtures.

Once this core is green and reviewed, implement encrypted storage and key management as the next security-critical slice.

## 19. Official references

- Apple AuthenticationServices credential provider: https://developer.apple.com/documentation/authenticationservices/ascredentialproviderviewcontroller
- Apple AutoFill Credential Provider entitlement: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.authentication-services.autofill-credential-provider
- Apple Credential Identity Store: https://developer.apple.com/documentation/authenticationservices/ascredentialidentitystore
- Apple password CSV export warning: https://support.apple.com/guide/passwords/export-passwords-mchl35b12625/mac
- Google password CSV minimum headers: https://support.google.com/accounts/answer/10500247
