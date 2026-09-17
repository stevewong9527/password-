# VaultMac Milestone 4A — macOS App Design

Date: 2026-09-17  
Branch: `feature/mvp-core`  
Status: Automated implementation complete; real-Mac manual gate pending

## Goal

Turn the tested `VaultCore` package into a real sandboxed macOS SwiftUI application that can create a new encrypted vault, protect its random 256-bit vault key through both macOS Keychain user-presence and master-password recovery, lock, and unlock again through either path.

Milestone 4A deliberately stops before credential list/edit/import UI. Its automated acceptance condition is a secure application shell whose first-run and unlock lifecycle builds and tests on macOS 15 CI. Full 4A completion additionally requires the real-Mac checklist in `docs/MANUAL_TEST_4A.md`.

## Product slice

The app presents three primary states:

1. **Welcome / Create Vault** — user enters and confirms a master password; the app creates an empty encrypted vault, recovery envelope, and Keychain-protected copy of the same random vault key.
2. **Locked** — normal state after relaunch; user can unlock through macOS user-presence authentication or the master-password recovery path.
3. **Unlocked Shell** — proves the vault can be authenticated/decrypted, shows record count, and provides explicit Lock. Credential browsing/editing remains out of scope.

## App identity

- Product name: `VaultMac`
- Bundle identifier: `com.stevewong.vaultmac`
- Platform: macOS 15+
- UI: SwiftUI
- Swift: Swift 6 with strict concurrency and warnings-as-errors
- App Sandbox: enabled; no unnecessary network or user-file entitlements in 4A

Storage and Keychain identifiers are centralized so a future bundle-id/product rename can be handled explicitly rather than silently orphaning user state.

## Architecture

`VaultCore` remains the cryptographic/domain layer. `VaultAppCore` owns the testable app lifecycle/coordinator state machine. The `VaultMac` target owns macOS-specific dependency wiring and SwiftUI presentation.

```text
VaultMac.app
    │
    ▼
AppModel / SwiftUI
    │
    ▼
VaultAppCoordinator  (VaultAppCore)
    │
    ├───────────────┬─────────────────┐
    ▼               ▼                 ▼
VaultSession   RecoveryService    VaultFileStore
    │               │                 │
    ▼               ▼                 ▼
Keychain       Argon2id + AES-GCM  Encrypted Vault
    │               │
    └───────┬───────┘
            ▼
      same random 256-bit
          Vault Key
```

### `VaultCore`

Security/domain responsibilities:

- `VaultSession`: short-lived in-memory key cache and explicit lock;
- `KeychainVaultKeyProvider`: user-presence protected device-local vault-key retrieval;
- `RecoveryService`: master-password recovery envelope create/unwrap;
- `SodiumArgon2IDKDF`: Argon2id13 KDF from pinned `swift-sodium` 0.11.0;
- `AESGCMVaultCipher`: authenticated encryption;
- `VaultFileStore`: versioned encrypted vault persistence.

UI-specific state does not belong in `VaultCore`.

### `VaultAppCore`

Responsibilities:

- first-run/completed/incomplete setup detection;
- transaction sequencing;
- fail-safe artifact-existence checks;
- locked/unlocked presentation state;
- recovery-attempt backoff;
- generic user-facing error categories;
- testable protocols around filesystem, Keychain install, recovery, and session access.

### `VaultMac`

Responsibilities:

- Application Support path selection;
- production adapters for Keychain, Argon2id, AES-GCM and vault storage;
- SwiftUI screens and app lifecycle;
- no duplicated cryptographic implementation.

## Persistence layout

All files live inside the sandboxed Application Support container:

```text
Application Support/VaultMac/
    vault.vault
    vault.vault.bak
    recovery.json
    setup.pending
    setup.json
```

### `vault.vault`

Existing versioned encrypted vault envelope. Credential metadata is contained inside authenticated ciphertext.

### `recovery.json`

Versioned `RecoveryEnvelope`: KDF identifier/parameters, salt, AES-GCM nonce/ciphertext/tag. It does not contain the master password or plaintext vault key.

### `setup.pending`

A non-secret transaction marker indicating that a first-run setup was started but not yet committed. It contains only version metadata.

This marker is security-significant for data preservation:

- if `setup.pending` exists, the app may treat recovery/vault/Keychain artifacts as belonging to an interrupted setup and clean them before retrying;
- if `setup.pending` is absent but `vault.vault` or `recovery.json` exists while `setup.json` is missing/corrupt, the app must **not** overwrite or delete those artifacts automatically;
- that state is reported as unavailable/incomplete and requires explicit recovery/repair work rather than a destructive new setup.

### `setup.json`

Non-secret completion metadata only. It is written last, after the required security artifacts have succeeded. It contains no usernames, passwords, credential metadata, vault key, master password, or password-derived material.

## First-run transaction

The setup operation is treated as a transaction.

Sequence:

1. validate non-empty matching master-password fields;
2. refuse setup if a completed setup already exists;
3. if an old `setup.pending` exists, clean only artifacts belonging to that interrupted setup;
4. if no pending marker exists but an existing vault or recovery envelope is present, refuse setup and preserve the artifacts;
5. write `setup.pending` atomically;
6. generate a random 32-byte vault key through the existing secure vault-key generator;
7. create a recovery envelope using `SodiumArgon2IDKDF` + `AESGCMVaultCipher`;
8. write `recovery.json` atomically;
9. write an empty encrypted `VaultDocument` through `VaultFileStore` using the random vault key;
10. install the same vault key into `KeychainVaultKeyProvider`;
11. write `setup.json` last;
12. clear `setup.pending`;
13. install the verified key into `VaultSession` and verify the encrypted vault can be opened;
14. transition to the unlocked shell, or remain locked if post-commit session bootstrap cannot complete.

A failure during an active pending transaction cleans incomplete artifacts and leaves setup incomplete. Existing artifacts that are not associated with a pending transaction are never silently overwritten or deleted.

## Unlock flows

### Device / Keychain path

1. Locked view requests unlock.
2. `VaultSession.unlock(reason:)` asks `KeychainVaultKeyProvider` for the vault key.
3. macOS performs user-presence authentication (Touch ID when available or OS-provided fallback).
4. `VaultSession` validates the key is exactly 32 bytes.
5. App loads/authenticates/decrypts `vault.vault` before transitioning to unlocked.
6. Any authentication/decryption error clears the active session and leaves the app locked.

UI copy does not promise Touch ID exclusively because macOS can use system-password fallback.

### Master-password recovery path

1. User chooses `Use Master Password`.
2. App enforces the in-memory recovery-attempt backoff.
3. App loads `recovery.json`.
4. `RecoveryService` validates envelope/KDF policy, derives the wrapping key with Argon2id13, and authenticates/decrypts the wrapped vault key.
5. Returned vault key must be exactly 32 bytes.
6. App verifies the recovered key by opening `vault.vault`.
7. On success, the key is installed into `VaultSession`, the backoff resets, and the app transitions to unlocked.
8. On failure, the session is locked and a generic recovery error is shown.

Recovery does not automatically replace or re-enrol the Keychain item.

## Locking

Explicit Lock calls `VaultSession.lock()`, which clears cached key bytes before dropping the cache. The unlocked record-count presentation state is discarded when the coordinator transitions to locked.

Sleep/workstation/inactivity auto-lock policies are later hardening slices.

## Error handling and logging

User-facing errors remain generic, for example:

- unable to create vault;
- unable to unlock;
- recovery password was not accepted;
- vault data is unavailable or damaged.

Never log or expose through diagnostics:

- master password;
- vault key;
- password-derived wrapping key;
- credential values;
- recovery ciphertext/salt/tag dumps;
- decrypted vault JSON.

Production UI does not expose cryptographic-oracle detail such as distinguishing wrong password from modified authentication tag.

## UI

### Create Vault

- `SecureField` Master Password
- `SecureField` Confirm Master Password
- Create Vault button
- reject empty/mismatched fields
- clear both fields after success

### Locked

- Unlock button for macOS user-presence path
- Use Master Password button/sheet
- retry-delay presentation for recovery backoff

### Unlocked Shell

- `Vault Unlocked`
- record count
- Lock button

No credential values are displayed in 4A.

## Automated testing and CI

Required regression coverage includes:

- clean install -> needs setup;
- completed setup -> locked;
- setup completion ordering is recovery -> vault -> Keychain -> setup marker;
- failed Keychain install does not produce completed setup;
- wrong recovery remains locked and increments backoff;
- successful recovery resets backoff and unlocks only after vault verification;
- explicit lock clears session/presentation state;
- existing vault/recovery artifacts with no pending marker cannot be overwritten/deleted by Create Vault;
- pending marker allows cleanup/retry of a genuinely interrupted setup.

GitHub macOS 15 CI must:

- resolve pinned `swift-sodium` 0.11.0;
- run `swift test -Xswiftc -warnings-as-errors`;
- build the real `VaultMac` app target through `xcodebuild` with signing disabled;
- never invoke interactive LocalAuthentication prompts.

## Real-Mac manual gate

Before 4A is marked fully complete, run and record `docs/MANUAL_TEST_4A.md`, including:

- first-run setup;
- relaunch into Locked state;
- system user-presence authentication;
- Touch ID where available and OS password fallback where offered;
- explicit lock;
- correct/incorrect master-password recovery;
- retry backoff;
- recovery/vault corruption fail-closed checks;
- missing `setup.json` with no pending marker must preserve existing vault/recovery artifacts.

## Security invariants

Non-negotiable for 4A:

- persisted vault key exists only wrapped/encrypted or inside macOS Keychain;
- master password is never persisted;
- both unlock paths produce the same random 256-bit vault key;
- recovery does not create a second credential vault;
- vault ciphertext is authenticated before plaintext is used;
- `setup.json` is the final completion marker;
- `setup.pending` is the only automatic-cleanup authorization for an interrupted first-run transaction;
- existing unmarked vault/recovery artifacts are preserved fail-safe;
- no secret is placed in Git fixtures, logs, crash messages, or UI diagnostics;
- no custom cryptographic primitive is introduced.

## Out of scope for 4A

- credential list/search/detail UI;
- add/edit/delete credentials;
- CSV import UI;
- password generator UI;
- AutoFill Credential Provider extension;
- TOTP/passkeys;
- cloud sync;
- master-password change;
- Keychain repair/re-enrollment;
- inactivity/workstation auto-lock hardening;
- distribution signing/notarization/App Store submission.

## Acceptance criteria

Automated 4A work is complete when:

1. sandboxed `VaultMac` app target builds successfully on macOS 15 CI;
2. first-run setup produces encrypted vault, recovery envelope, Keychain-protected key and completion marker in the intended order;
3. crash/interrupted setup is recoverable through `setup.pending` without enabling deletion of unrelated/existing vault artifacts;
4. subsequent launch starts locked;
5. Keychain and master-password paths can authenticate/decrypt the same vault;
6. wrong-password/tampered-data paths fail closed;
7. explicit Lock clears the active vault session;
8. package tests and real app build are green in CI.

Full Milestone 4A remains **IN PROGRESS** until the real-Mac checklist is executed and recorded successfully.
