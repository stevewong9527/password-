# VaultMac Milestone 4A — Real Mac Manual Test

Date template: YYYY-MM-DD  
Commit tested: `<feature/mvp-core SHA>`  
Mac model: `<model>`  
macOS version: `<version>`

Use only synthetic test passwords and an empty/test vault. Never use a real exported password CSV for this checklist.

## Preconditions

- [ ] Build and launch the `VaultMac` scheme on a real Mac running macOS 15 or later.
- [ ] Confirm the app is using bundle identifier `com.stevewong.vaultmac` and App Sandbox is enabled.
- [ ] Start with a clean test installation, or make a safe copy of any existing test vault before destructive corruption checks.

## First-run setup

- [ ] Fresh launch shows **Create Vault** rather than the locked/unlocked screen.
- [ ] Empty or mismatched master-password confirmation is rejected.
- [ ] A synthetic master password creates the vault successfully.
- [ ] After success, the password fields are cleared.
- [ ] `vault.vault`, `recovery.json`, and `setup.json` exist in VaultMac Application Support.
- [ ] `setup.pending` does not remain after a successful setup.
- [ ] No plaintext vault key or master password appears in the Application Support files.

## Relaunch and device authentication

- [ ] Quit and relaunch VaultMac; it starts **Locked**.
- [ ] Press **Unlock** and confirm macOS presents user-presence authentication.
- [ ] Touch ID works when available; macOS system-password fallback also works when offered by the OS.
- [ ] Successful device authentication opens the same vault and shows the expected record count.
- [ ] Cancel/fail the system authentication prompt; VaultMac remains locked and does not crash.

## Explicit lock

- [ ] From **Vault Unlocked**, press **Lock**.
- [ ] The app immediately returns to **Vault Locked**.
- [ ] Unlock again to confirm the vault remains readable.

## Master-password recovery

- [ ] From the locked screen, open **Use Master Password**.
- [ ] Enter an incorrect password; the vault remains locked.
- [ ] Repeated failures show/enforce the in-memory retry delay.
- [ ] After the delay, enter the correct synthetic master password; the same vault unlocks.
- [ ] A successful recovery resets the retry backoff.
- [ ] Recovery does not silently replace/re-enrol the Keychain item.

## Corruption / fail-closed checks

Before each check, keep a safe copy of the synthetic test files so they can be restored.

- [ ] Modify a byte in `recovery.json`; master-password recovery fails closed with a generic error and no crash.
- [ ] Restore `recovery.json`.
- [ ] Modify a byte in `vault.vault`; both unlock paths refuse to present the vault as unlocked.
- [ ] Restore `vault.vault`.
- [ ] Temporarily move `setup.json` away **after ensuring `setup.pending` is absent**; VaultMac reports unavailable/incomplete state.
- [ ] In that state, attempting **Create Vault** does not overwrite or delete the existing `vault.vault` or `recovery.json`.
- [ ] Restore `setup.json`; the original test vault can be unlocked again.

## Result

- [ ] PASS — all checks above completed on a real Mac.
- [ ] FAIL — record the failed checkbox, exact commit, and non-secret error symptoms in the PR/issue before marking Milestone 4A complete.

Do not paste master passwords, vault keys, recovery envelope contents, or decrypted vault data into test notes, screenshots, issues, crash reports, or CI logs.
