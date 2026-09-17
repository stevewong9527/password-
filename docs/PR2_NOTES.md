# Milestone 2 PR Notes

Review base: `feature/mvp-core`

This milestone intentionally contains encrypted vault persistence only. It does not include Keychain, Touch ID, recovery, UI, AutoFill, or network features.

Primary security invariants covered by tests:

- no known credential plaintext in the persisted envelope
- fresh AES-GCM output for repeated seals
- wrong keys fail closed
- ciphertext/tag tampering fails closed
- unsupported envelope/document versions are rejected
- the previous persisted copy is encrypted
- the 2,000-record synthetic vault round-trips successfully

The next milestone should introduce a `VaultKeyProvider`/platform boundary instead of adding Keychain APIs directly to `VaultCrypto`.
