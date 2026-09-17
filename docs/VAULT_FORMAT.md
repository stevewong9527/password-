# Vault file format v1

The v1 vault is a JSON-encoded authenticated-encryption envelope. Credential metadata is never intentionally stored outside the encrypted ciphertext.

## Envelope

`VaultEnvelope` contains:

- `formatVersion`: integer envelope format version. v1 readers accept only `1`.
- `nonce`: AES-GCM nonce encoded by `JSONEncoder` as Base64 data.
- `ciphertext`: encrypted serialized `VaultDocument`, encoded as Base64 data.
- `tag`: AES-GCM authentication tag, encoded as Base64 data.

The plaintext `VaultDocument` is itself versioned with `version = 1` and currently contains the credential record array. A reader rejects unsupported envelope or document versions instead of attempting best-effort decoding.

## Encryption

Production macOS builds use CryptoKit AES-256-GCM with a random 256-bit vault key. Each seal operation lets CryptoKit generate a fresh nonce. Authentication failure is fail-closed and no partial plaintext is returned.

## Writes and recovery

A save first serializes and encrypts the complete document, then writes a sibling `.tmp` file. Replacing an existing vault retains the previous encrypted file as `.bak`. If replacement fails, the previous vault remains the recovery source.

No `.tmp`, `.bak`, or vault file may contain plaintext credentials.

## Migration rule

Future format or document versions require an explicit, tested migration path. Code must never silently reinterpret an unknown version as v1.
