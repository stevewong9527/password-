# Encrypted Vault Format v1

The on-disk vault is a JSON-encoded `EncryptedVaultEnvelope`. Credential records and their metadata exist only inside the authenticated ciphertext.

## Envelope fields

- `formatVersion`: integer envelope version. Current value: `1`.
- `algorithm`: exact string `AES-256-GCM`.
- `nonce`: AES-GCM nonce encoded by `JSONEncoder` as Base64 data.
- `ciphertext`: encrypted serialized `VaultDocument`, Base64 encoded by `JSONEncoder`.
- `tag`: AES-GCM authentication tag, Base64 encoded by `JSONEncoder`.

The plaintext `VaultDocument` is separately versioned so future schema migrations can be handled independently from changes to the cryptographic envelope.

## Security properties

- A new random 256-bit vault key is created with CryptoKit.
- AES-GCM generates a fresh nonce for every seal operation.
- Authentication failure is fail-closed: no partial plaintext is returned.
- Unknown envelope versions and algorithms are rejected rather than guessed.
- Saves are staged to a sibling temporary file. Replacing an existing vault uses `FileManager.replaceItemAt` while retaining the immediately previous encrypted file as `<vault>.previous`.
- No plaintext credential metadata is intentionally stored in the envelope or backup.

Key wrapping, Keychain storage, Touch ID and recovery are deliberately outside this format and belong to the next milestone.
