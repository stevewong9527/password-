# VaultMac Milestone 4A — macOS App Design

Date: 2026-09-17
Branch: `feature/mvp-core`

## Goal

Turn the existing tested `VaultCore` package into a real sandboxed macOS SwiftUI application that can create a new encrypted vault, protect its random 256-bit vault key through both macOS Keychain user-presence and master-password recovery, lock, and unlock again through either path.

Milestone 4A deliberately stops before credential list/edit/import UI. Its acceptance condition is a working secure application shell whose first-run and unlock lifecycle is complete.

## Product slice

The app presents only three primary states in this milestone:

1. **Welcome / Create Vault**
   - shown when no vault metadata exists;
   - user enters and confirms a master password;
   - app generates a random 256-bit vault key;
   - app creates an empty encrypted vault;
   - app creates an Argon2id/AES-GCM recovery envelope for the same vault key;
   - app installs the same vault key in macOS Keychain using user-presence access control.

2. **Locked**
   - default state for an existing vault after launch;
   - primary action: unlock through the Keychain path, which allows Touch ID or the system authentication fallback selected by macOS;
   - secondary action: unlock with the master password and recovery envelope;
   - failed master-password recovery is governed by the existing exponential recovery backoff state.

3. **Unlocked Shell**
   - proves the vault can be decrypted using the active `VaultSession` key;
   - displays only basic vault status and record count;
   - provides an explicit Lock action;
   - credential browsing and editing are out of scope for 4A.

## App identity

- Product name: `VaultMac`
- Bundle identifier: `com.stevewong.vaultmac`
- Platform: macOS 15+
- UI: SwiftUI
- App Sandbox: enabled from the first app target

The bundle identifier is provisional and can be changed before external distribution, but all 4A storage identifiers must be centralized so a later rename does not silently orphan vault or Keychain state.

## Architecture

`VaultCore` remains the security/domain layer. The macOS app target owns lifecycle, persistence locations, and UI state, but must not reimplement cryptography.

```text
VaultMac.app
    │
    ▼
AppCoordinator / AppModel
    │
    ├── first-run detection
    ├── create-vault transaction
    ├── locked/unlocked presentation state
    └── recovery attempt backoff
    │
    ├───────────────┐
    ▼               ▼
VaultSession   RecoveryService
    │               │
    ▼               ▼
Keychain       Argon2id + AES-GCM
Provider       Recovery Envelope
    │               │
    └───────┬───────┘
            ▼
      Random 256-bit Vault Key
            │
            ▼
       VaultFileStore
            │
            ▼
       Encrypted Vault
```

## Boundaries

### `VaultCore`

Existing responsibilities stay unchanged:

- `VaultSession`: short-lived in-memory key cache and explicit lock;
- `KeychainVaultKeyProvider`: user-presence protected device-local key retrieval;
- `RecoveryService`: master-password recovery envelope creation and unwrap;
- `AESGCMVaultCipher`: authenticated encryption;
- `SodiumArgon2IDKDF`: Argon2id KDF;
- `VaultFileStore`: versioned encrypted vault persistence.

4A may add narrowly-scoped interfaces only when the app cannot test lifecycle behavior without them. UI-specific state must not be added to `VaultCore`.

### App layer

The app layer owns:

- deciding whether first-run setup is required;
- deriving standard application-support paths;
- sequencing setup so partial creation cannot be mistaken for a complete vault;
- translating domain errors into generic user-facing states without logging secrets;
- calling `VaultSession.lock()` on explicit lock and relevant app lifecycle events;
- presenting SwiftUI screens.

## Persistence layout

All files live inside the app's sandboxed Application Support container.

Logical names:

```text
Application Support/VaultMac/
    vault.vault
    vault.vault.bak
    recovery.json
    setup.json
```

### `vault.vault`

Existing versioned encrypted vault envelope. No plaintext credential metadata is stored here.

### `recovery.json`

Stores only the versioned `RecoveryEnvelope`: KDF identifier/parameters, salt, AES-GCM nonce/ciphertext/tag. It does not store the master password or plaintext vault key.

### `setup.json`

Non-secret app installation metadata only. It records format/version identifiers needed to decide that setup completed successfully. It must not contain usernames, passwords, credential metadata, the vault key, or master-password-derived material.

The Keychain service/account identifiers are constants owned by the app configuration layer rather than duplicated in views.

## First-run transaction

Creating a vault must be treated as a transaction. The app must not create `setup.json` until all required security artifacts have been written successfully.

Sequence:

1. validate master-password confirmation and non-empty input;
2. generate random 32-byte vault key through the existing CryptoKit vault-key generator;
3. create recovery envelope using `SodiumArgon2IDKDF` and `AESGCMVaultCipher`;
4. write `recovery.json` atomically;
5. write an empty encrypted `VaultDocument` through `VaultFileStore` using the random vault key;
6. install the same key into `KeychainVaultKeyProvider`;
7. write `setup.json` last;
8. install the key into `VaultSession` only through a narrow, testable bootstrap path, or perform a normal provider unlock if practical;
9. transition to unlocked shell.

If any step before `setup.json` fails, the next launch must still enter a recoverable setup state instead of treating the vault as ready. 4A may clean up incomplete non-Keychain artifacts created by the failed transaction. It must never overwrite an existing completed vault silently.

## Unlock flows

### Keychain / Touch ID path

1. Locked view requests unlock.
2. `VaultSession.unlock(reason:)` asks `KeychainVaultKeyProvider` for the vault key.
3. macOS presents user-presence authentication as required by the Keychain item.
4. `VaultSession` validates the returned key is exactly 32 bytes.
5. App attempts to load/decrypt `vault.vault` before transitioning UI to unlocked.
6. Any authentication or decryption error leaves the app locked.

The app must not claim Touch ID specifically when macOS may use system password fallback. UI copy should say `Unlock` or `Unlock with Touch ID / Mac password` only when that wording matches actual system behavior.

### Master-password recovery path

1. User selects `Use Master Password`.
2. App enforces the in-memory recovery backoff gate before a new attempt.
3. App loads `recovery.json`.
4. `RecoveryService` derives the wrapping key using stored Argon2id parameters, rejects unsupported/weak parameters, and authenticates the envelope.
5. Returned vault key must be exactly 32 bytes.
6. App verifies the key by loading/decrypting `vault.vault`.
7. On success, the key is installed into the active `VaultSession`, recovery backoff resets, and UI transitions to unlocked.
8. On failure, the app remains locked and records a failure in the in-memory backoff state.

Recovery must not modify or replace the Keychain item automatically. Repair/re-enrollment is a later explicit flow.

## Locking

4A supports explicit Lock immediately. Locking must call `VaultSession.lock()`, which clears the cached key bytes before dropping the cache.

Automatic lock triggers for sleep, screen lock, inactivity, and app backgrounding are a later 4B hardening slice unless a minimal reliable lifecycle hook is required to prevent obvious leakage during 4A testing.

No decrypted `VaultDocument` should be kept in a global singleton after lock. The app shell may retain only non-secret presentation state such as record count if that is deliberately classified as acceptable metadata; the safer 4A default is to clear it on lock.

## Error handling and logging

User-facing errors are deliberately generic:

- unable to create vault;
- unable to unlock;
- recovery password was not accepted;
- vault data is unavailable or damaged.

Diagnostic logs must never include:

- master password;
- vault key;
- password-derived key;
- credential values;
- recovery ciphertext/salt/tag dumps;
- decrypted vault JSON.

Detailed domain errors may be mapped to internal enum cases for tests, but production UI should not reveal cryptographic oracle detail such as whether a wrong password or modified tag caused authentication failure.

## UI details

### Welcome / Create Vault

Fields:

- Master Password (`SecureField`)
- Confirm Master Password (`SecureField`)

Controls:

- `Create Vault`

Validation:

- both fields must be non-empty;
- fields must match;
- no arbitrary composition rule is imposed in 4A;
- master password is not persisted in SwiftUI state after successful setup.

### Locked

Controls:

- `Unlock`
- `Use Master Password`

Master-password sheet/panel:

- one `SecureField`;
- retry state reflects recovery backoff without exposing crypto details.

### Unlocked Shell

Shows:

- `Vault Unlocked`
- record count
- `Lock`

No credential values are displayed in 4A.

## Testing strategy

### Portable/domain tests

Use fake key providers, fake ciphers/KDFs where appropriate, and a temporary filesystem to test an app coordinator or setup service without invoking real biometric UI.

Required behavior tests:

- clean install is detected as first run;
- completed setup is detected as existing vault;
- setup marker is written only after vault, recovery envelope, and Keychain-install abstraction all succeed;
- a failed setup step does not produce a completed setup marker;
- locked state cannot expose a vault key;
- wrong recovery password leaves state locked and increments backoff;
- successful recovery resets backoff and reaches unlocked state;
- explicit lock clears session and decrypted app state.

### macOS CI

GitHub macOS 15 CI must:

- resolve pinned `swift-sodium 0.11.0`;
- run existing `swift test -Xswiftc -warnings-as-errors`;
- build the actual `VaultMac` macOS app target with warnings treated as errors;
- run app-layer unit tests that do not require interactive Touch ID.

CI must not attempt interactive LocalAuthentication prompts.

### Manual test gate

On a real Mac before 4A is marked complete:

- first run creates vault successfully;
- app relaunch enters Locked state;
- Keychain unlock presents system user-presence authentication and opens vault;
- explicit lock works;
- master-password recovery opens the same vault;
- wrong master password stays locked;
- deleting/corrupting test recovery/vault artifacts fails closed with no crash.

## Security invariants

The following are non-negotiable for this milestone:

- the persisted vault key exists only encrypted/wrapped or inside macOS Keychain;
- master password is never persisted;
- the random vault key remains the single key protecting `vault.vault` regardless of unlock method;
- recovery does not create a second vault or second copy of credential plaintext;
- all vault decryption must authenticate before data is used;
- setup completion is written last;
- no secret is placed in Git fixtures, logs, crash messages, or UI diagnostics;
- no new custom cryptographic primitive is introduced.

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
- automatic workstation/sleep/inactivity lock policy beyond any minimal lifecycle safety hook;
- distribution signing/notarization/App Store submission.

## Acceptance criteria

Milestone 4A is complete only when:

1. a sandboxed `VaultMac` macOS app target builds successfully;
2. first-run setup produces an empty encrypted vault, recovery envelope, Keychain-protected vault key, and completion marker in the intended order;
3. a subsequent launch starts locked;
4. Keychain user-presence unlock can decrypt the vault;
5. master-password recovery can decrypt the same vault without changing the encrypted vault format;
6. wrong-password/tampered-data paths fail closed;
7. explicit Lock clears the active vault session;
8. automated portable tests and macOS CI are green;
9. real-Mac manual user-presence and recovery checks are recorded before declaring the milestone fully complete.
