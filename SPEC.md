# Password Manager for macOS — Product & Security Specification

Status: Draft v0.2
Date: 2026-09-17
Target: Downloadable consumer macOS product

## 1. Product goal

Build a Mac-first password manager that can import credentials exported from Apple Passwords and Google Password Manager, keep them in a local encrypted vault, generate strong passwords, search/manage credentials, and provide credentials through macOS AutoFill.

The first public release must remain useful without an online account. Cloud sync, family sharing, passkeys and team features are later phases.

## 2. v1 scope

### In scope

- Native macOS 15+ app using Swift and SwiftUI.
- Local encrypted vault.
- Touch ID / system user-presence unlock where available.
- Optional master-password recovery path.
- Apple Passwords CSV import.
- Google-compatible password CSV import.
- Import preview and row-level validation.
- Conservative duplicate/conflict detection.
- Cryptographically secure password generator.
- Search, view, add, edit, delete and copy credentials.
- Auto-lock.
- macOS AuthenticationServices Credential Provider Extension.
- Local weak/reused-password audit.
- Encrypted local backup/restore.

### Explicitly out of scope for v1

- Cloud sync.
- Windows or Android clients.
- Family/team sharing.
- Emergency access.
- Passkey migration/import.
- Network breach lookup.
- AI-generated passwords or sending credentials to an AI service.
- Full TOTP support; Apple `OTPAuth` is tolerated during import but ignored until a later milestone.

## 3. Security principles

1. Credential passwords must never be stored unencrypted on persistent storage by this app.
2. Real credentials, password-export CSVs, vault files, recovery secrets and signing secrets must never enter Git.
3. Passwords, vault keys, recovery secrets and plaintext vault records must never be written to logs, analytics or crash metadata.
4. Use established system/audited crypto libraries; never implement crypto primitives manually.
5. Network access is not required for core v1 operation.
6. AutoFill must fail closed and must not silently provide a credential to an unrelated service/domain.
7. Imported CSV is highly sensitive transient plaintext.
8. Security-sensitive behavior requires explicit tests; insecure fallback behavior is forbidden.

## 4. Threat model

### Protect against

- Theft/copying of the Mac while the vault is locked.
- Another local user reading the vault file without successful authentication.
- Accidental plaintext CSV copies created by this app.
- Accidental Git commits of exports/vaults/secrets.
- Wrong-site AutoFill from over-broad matching.
- Encrypted-vault tampering/corruption.

### Not fully protect against

- Malware/keyloggers running as the user while the vault is unlocked.
- A fully compromised/rooted OS.
- Screen capture or shoulder surfing after the user reveals a secret.
- A malicious destination after a user intentionally copies/pastes a secret there.

Marketing/security documentation must not imply protection from a compromised endpoint.

## 5. Core credential model

```swift
struct CredentialRecord: Codable, Identifiable, Equatable, Sendable {
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

The stored vault document must be versioned so schema migrations are explicit and tested.

## 6. Import format

### Google-compatible CSV

Required canonical fields:

`url,username,password`

Additional fields such as `name/title` and `note/notes` may be consumed when present.

### Apple Passwords CSV

Apple's current developer documentation describes these fields:

`Title,URL,Username,Password,Notes,OTPAuth`

For v1 password import:

- `Title` -> title
- `URL` -> service URL
- `Username` -> username
- `Password` -> password
- `Notes` -> notes
- `OTPAuth` -> accepted/tolerated but intentionally ignored until TOTP support exists

Importer headers are normalized for case/edge whitespace and a UTF-8 BOM on the first header is tolerated.

## 7. CSV parsing requirements

The parser must correctly handle:

- commas
- quoted commas
- escaped double quotes
- LF and CRLF line endings
- multiline quoted fields
- UTF-8 text
- unterminated quoted-field errors

The implementation must not include plaintext field values in error descriptions.

Row-level validation errors contain only the row number and an error category.

## 8. URL/host normalization

Normalize conservatively:

- trim surrounding whitespace
- allow a bare host by treating it as an HTTPS-style URL for parsing
- lowercase the parsed host
- remove a leading `www.` only
- remove a trailing dot
- discard path/query/fragment from the match key

Do **not** invent an eTLD+1/public-suffix algorithm.

A wrong automatic merge is more dangerous than leaving two records for the user to resolve.

## 9. Duplicate/conflict policy

Exact key for v1 import comparison:

`normalizedHost + trimmed case-insensitive username`

Classification:

- same key + same password -> `duplicate`
- same key + different password -> `conflict`
- different key -> `distinct`

A conflict must never overwrite automatically. UI choices later: keep existing, keep imported, keep both, skip.

Related-but-different hosts such as `accounts.example.com` and `example.com` remain distinct until a reviewed affiliation/public-suffix strategy is added.

## 10. Vault storage architecture

For v1, serialize the complete logical vault and encrypt it as one authenticated ciphertext rather than introducing SQLCipher or a custom encrypted database.

Rationale:

- encrypts metadata as well as passwords at rest
- reduces dependency/attack surface
- remains practical for thousands of credentials
- simplifies integrity verification and backup

Storage requirements:

- versioned envelope
- AES-256-GCM through CryptoKit preferred for the macOS target
- random 256-bit vault key
- fresh nonce for each encryption
- atomic file replacement
- retain a recoverable previous encrypted copy while replacing
- authentication/tag failure must fail closed
- never return partially decrypted content

## 11. Key management

### Device unlock

Protect/wrap the random vault key using macOS Keychain-backed material with LocalAuthentication/user-presence policy where appropriate. Touch ID is an unlock factor, not encryption entropy.

### Master-password recovery

If enabled:

- derive a wrapping key with Argon2id from a pinned reviewed implementation such as libsodium
- store KDF salt and parameters, never the master password
- use the derived key to wrap the random vault key
- never use the master password directly as the vault encryption key
- do not silently downgrade to a weaker KDF

## 12. AutoFill architecture

Use Apple's AuthenticationServices Credential Provider Extension.

- Add the AutoFill Credential Provider entitlement to host app and extension.
- Use `ASCredentialIdentityStore` for identity metadata only; passwords remain in the encrypted vault.
- Keep identity entries synchronized with vault changes.
- Use OS-provided service identifiers to choose matching credentials.
- A locked vault may request the minimum user interaction needed to unlock.
- Never expose a broad credential list to an unrelated service after matching failure.

Password-save, password-generation, OTP and passkey APIs can be added behind OS-availability checks in later milestones.

## 13. Password generator

- cryptographically secure RNG only
- default length: 20
- configurable length/character classes
- support site-provided password rules when available
- never use an LLM or deterministic PRNG
- do not persist a generated value until the user explicitly saves/uses it

## 14. Clipboard and auto-lock

Clipboard:

- explicit user action only
- default clear delay: 60 seconds
- clear only if the clipboard still contains the value/change state written by this app
- never erase newer clipboard content written by another app

Auto-lock default:

- after 5 minutes inactivity
- on explicit lock
- on workstation/session lock when reliable system notification exists
- discard usable decrypted in-memory vault state on lock

## 15. Local security audit

v1 is offline only:

- detect reused passwords while unlocked
- detect basic weak-password conditions locally
- do not persist a plaintext password-to-sites index
- do not present an unexplained absolute security score
- network breach checking is deferred

## 16. Backup and restore

- backup is encrypted and versioned
- restore validates version and authenticated ciphertext before replacement
- a plaintext interoperability export must be explicitly labelled plaintext and require immediate re-authentication
- a generic "Backup" action must never create plaintext

## 17. Logging and telemetry

Forbidden in logs/telemetry:

- username
- password
- notes
- plaintext CSV row
- decrypted record
- vault key
- recovery/master secret
- private URL path/query data

v1 defaults to no remote analytics.

## 18. Repository rules

The repository is public.

- `*.csv`, vault/recovery artifacts, `.env*`, signing material and Xcode user data are ignored.
- tests use synthetic values only
- no production certificate/provisioning material is committed
- no real exported credential file is used as a fixture

## 19. Current module layout

The first portable core is intentionally a root Swift Package:

```text
Package.swift
Sources/
  VaultCore/
    CredentialRecord.swift
    HostNormalizer.swift
    CSVParser.swift
    PasswordCSVImporter.swift
    ImportConflictClassifier.swift
Tests/
  VaultCoreTests/
```

Later macOS milestones add the application, crypto/platform code and Credential Provider target while keeping `VaultCore` independently testable.

## 20. MVP acceptance criteria

A v1 release candidate is not acceptable until all are true:

1. Google-compatible CSV import handles quoted commas/newlines.
2. Apple documented CSV headers import password fields correctly.
3. Malformed rows are surfaced without echoing credential values in errors.
4. Exact duplicates/conflicts are classified conservatively.
5. Persisted vault contains no plaintext test credential/metadata.
6. Ciphertext/tag tampering fails to open.
7. Device authentication unlock path works.
8. Password generation uses secure randomness.
9. Matching credential fills through the Credential Provider Extension.
10. Deliberately unrelated domain cannot receive the credential.
11. Auto-lock removes usable decrypted state.
12. Clipboard clearing does not erase newer unrelated clipboard data.
13. Git history created by this project contains no real secrets/exports.
14. Release build passes automated tests and manual macOS sandbox/AutoFill checks.

## 21. Implementation status

### Completed first slice

- repository bootstrap
- `CredentialRecord`
- host normalization
- CSV parser
- Google-compatible importer
- Apple documented-header password compatibility
- duplicate/conflict classifier
- regression coverage for CRLF, multiline fields, BOM, malformed rows and non-echoing errors

### Next slice

Implement encrypted vault persistence with tests first:

- versioned envelope
- AES-GCM encryption/integrity
- nonce uniqueness
- atomic replacement
- corruption/tamper failure behavior

## 22. Official references

- Apple credential provider: https://developer.apple.com/documentation/authenticationservices/ascredentialproviderviewcontroller
- Apple AutoFill entitlement: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.authentication-services.autofill-credential-provider
- Apple Credential Identity Store: https://developer.apple.com/documentation/authenticationservices/ascredentialidentitystore
- Apple password export warning: https://support.apple.com/guide/passwords/export-passwords-mchl35b12625/mac
- Apple/Safari exported password data fields: https://developer.apple.com/documentation/safariservices/importing-data-exported-from-safari
- Google CSV minimum headers: https://support.google.com/accounts/answer/10500247
