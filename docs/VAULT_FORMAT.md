# Encrypted Vault Format v1

The on-disk vault is a JSON-encoded `EncryptedVaultEnvelope`. Credential records and their metadata exist only inside the authenticated ciphertext.

## Envelope fields

- `formatVersion`: integer envelope version. Current value: `1`.
- `algorithm`: exact string `AES-256-GCM`.
- `nonce`: AES-GCM nonce encoded by `JSONEncoder` as Base64 data.
- `ciphertext`: encrypted serialized `VaultDocument`, Base64 encoded by `JSONEncoder`.
- `tag`: AES-GCM authentication tag, Base64 encoded by `JSONEncoder`.

The plaintext `VaultDocument` is separately versioned. Its current version is also `1`, but it is intentionally independent from the cryptographic envelope version so future schema migrations can be handled without conflating data-model changes with encryption-format changes.

On open, the implementation first validates the envelope format and algorithm, authenticates/decrypts the ciphertext, decodes the `VaultDocument`, and then rejects an unsupported document version rather than attempting to interpret it as the current schema.

## Security properties

- A new random 256-bit vault key is created with CryptoKit.
- AES-GCM generates a fresh nonce for every seal operation.
- Authentication failure is fail-closed: no partial plaintext is returned.
- Unknown envelope versions, algorithms, and decrypted document versions are rejected rather than guessed.
- Saves are staged to a sibling temporary file. Replacing an existing vault uses `FileManager.replaceItemAt` while retaining the immediately previous encrypted file as `<vault>.previous`.
- No plaintext credential metadata is intentionally stored in the envelope or backup.

Key wrapping, Keychain storage, Touch ID and recovery are deliberately outside this format and belong to the next milestone.
