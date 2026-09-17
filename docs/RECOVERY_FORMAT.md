# Master Password Recovery Envelope v1

The recovery path does not encrypt the vault directly with the user's master password. It derives a 256-bit wrapping key with Argon2id and uses that key only to wrap the same random 256-bit vault key used by the device-unlock path.

## v1 fields

- `formatVersion`: `1`
- `kdf.algorithm`: `argon2id13`
- `kdf.opsLimit`: operation/pass parameter
- `kdf.memLimit`: memory parameter in bytes
- `kdf.outputLength`: derived wrapping-key length
- `kdf.saltLength`: salt length
- `salt`: random KDF salt
- `nonce`: AES-GCM nonce
- `ciphertext`: encrypted 32-byte vault key
- `tag`: AES-GCM authentication tag

## Production v1 policy

New envelopes use at least Argon2id13, ops limit `3`, memory limit `268435456` bytes (256 MiB), a 32-byte derived key, and a 16-byte random salt. The implementation rejects envelopes below the configured minimum rather than silently substituting weaker parameters.

Argon2id is provided by `jedisct1/swift-sodium` pinned to `0.11.0`, which wraps libsodium. AES-GCM uses Apple CryptoKit.

## Failure behavior

Recovery fails closed for unknown versions, unsupported KDFs, downgraded parameters, malformed salts, KDF failure, incorrect master passwords, modified authenticated ciphertext, or an invalid recovered vault-key length.

No master password, derived wrapping key, or plaintext vault key may be logged.
