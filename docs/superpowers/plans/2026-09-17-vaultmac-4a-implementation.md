# VaultMac Milestone 4A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a sandboxed macOS 15+ SwiftUI app shell that creates a first encrypted vault, persists recovery/setup metadata safely, and unlocks the same vault through either macOS Keychain user-presence or the master-password recovery path.

**Architecture:** Keep `VaultCore` as the cryptographic/domain layer. Add a testable `VaultAppCore` Swift package target for app lifecycle/coordinator logic, and a real `VaultMac.xcodeproj` SwiftUI app target that wires macOS storage paths, `KeychainVaultKeyProvider`, `SodiumArgon2IDKDF`, `AESGCMVaultCipher`, and `VaultFileStore` into the coordinator. The app target contains presentation only; setup completion remains a transaction with `setup.json` written last.

**Tech Stack:** Swift 6, SwiftUI, macOS 15+, CryptoKit, Security/Keychain, LocalAuthentication, pinned `swift-sodium` 0.11.0, Swift Testing, Xcode project + App Sandbox.

**Spec:** `docs/superpowers/specs/2026-09-17-macos-app-4a-design.md`

## Global Constraints

- Product name: `VaultMac`; bundle identifier: `com.stevewong.vaultmac`.
- macOS deployment target: 15.0.
- App Sandbox enabled from the first app target.
- Vault key is exactly 32 bytes and is never persisted in plaintext outside macOS Keychain.
- Master password is never persisted.
- `setup.json` is written last, after recovery envelope, encrypted vault and Keychain install all succeed.
- No credential list/edit/import UI in 4A.
- CI must not trigger interactive LocalAuthentication.
- No secret values in logs, errors, fixtures or Git.

---

### Task 1: Testable app lifecycle core

**Files:**
- Modify: `Package.swift`
- Create: `Sources/VaultAppCore/AppConfiguration.swift`
- Create: `Sources/VaultAppCore/AppFileStore.swift`
- Create: `Sources/VaultAppCore/VaultAppCoordinator.swift`
- Create: `Tests/VaultAppCoreTests/VaultAppCoordinatorTests.swift`

**Interfaces:**
- Consumes: `VaultDocument`, `RecoveryEnvelope`, `RecoveryBackoff`, `VaultSession` concepts from `VaultCore` only through narrow app-facing protocols.
- Produces: `VaultAppState`, `VaultSetupArtifacts`, `VaultAppCoordinator`, and storage/key/recovery protocols used by the macOS app target.

- [ ] **Step 1: Add `VaultAppCore` package target and a failing first-run detection test.**

```swift
@Test func cleanInstallStartsInSetup() async throws {
    let coordinator = VaultAppCoordinator(dependencies: .fakeEmpty())
    await coordinator.bootstrap()
    #expect(await coordinator.state == .needsSetup)
}
```

- [ ] **Step 2: Run `swift test -Xswiftc -warnings-as-errors`; verify RED because `VaultAppCore` does not exist.**
- [ ] **Step 3: Implement the minimal state machine and storage protocols.**

```swift
public enum VaultAppState: Equatable, Sendable {
    case needsSetup
    case locked
    case unlocked(recordCount: Int)
}
```

- [ ] **Step 4: Add tests for completed setup -> locked and explicit lock -> locked with cleared record count.**
- [ ] **Step 5: Run package tests and keep all warnings as errors.**

---

### Task 2: First-run transaction and recovery unlock

**Files:**
- Modify: `Sources/VaultAppCore/VaultAppCoordinator.swift`
- Create: `Sources/VaultAppCore/SetupMetadata.swift`
- Modify: `Tests/VaultAppCoreTests/VaultAppCoordinatorTests.swift`
- Create: `Tests/VaultAppCoreTests/FirstRunTransactionTests.swift`

**Interfaces:**
- Consumes: app-facing protocols for key generation, recovery envelope creation, encrypted vault write, Keychain key install, setup/recovery metadata persistence.
- Produces: `createVault(masterPassword:confirmation:)`, `unlockWithDeviceAuthentication(reason:)`, `unlockWithMasterPassword(_:)`, `lock()`.

- [ ] **Step 1: Write RED test proving setup marker is absent if Keychain installation fails.**
- [ ] **Step 2: Write RED test proving successful setup calls operations in order `recovery -> vault -> keychain -> setup`.**
- [ ] **Step 3: Implement first-run transaction with `setup.json` write last and cleanup of incomplete file artifacts only.**
- [ ] **Step 4: Write RED tests for wrong recovery password staying locked/incrementing backoff, and successful recovery resetting backoff/unlocking only after vault verification.**
- [ ] **Step 5: Implement recovery/device unlock methods without exposing cryptographic error detail to presentation state.**
- [ ] **Step 6: Run complete Swift package test suite.**

---

### Task 3: Real macOS SwiftUI app target

**Files:**
- Create: `VaultMac.xcodeproj/project.pbxproj`
- Create: `VaultMac/VaultMacApp.swift`
- Create: `VaultMac/AppModel.swift`
- Create: `VaultMac/RootView.swift`
- Create: `VaultMac/CreateVaultView.swift`
- Create: `VaultMac/LockedView.swift`
- Create: `VaultMac/UnlockedView.swift`
- Create: `VaultMac/VaultMacDependencies.swift`
- Create: `VaultMac/VaultMac.entitlements`
- Create: `VaultMac/Info.plist`

**Interfaces:**
- Consumes: `VaultAppCore` coordinator interfaces plus concrete `VaultCore` implementations.
- Produces: signed-capable sandboxed `VaultMac.app` target (CI builds with signing disabled).

- [ ] **Step 1: Create Xcode project with local Swift package references to `VaultCore` and `VaultAppCore`, deployment target 15.0 and bundle id `com.stevewong.vaultmac`.**
- [ ] **Step 2: Enable App Sandbox entitlement and no unnecessary network/file entitlements.**
- [ ] **Step 3: Implement `VaultMacDependencies` using Application Support paths, `KeychainVaultKeyProvider`, `SodiumArgon2IDKDF`, `AESGCMVaultCipher`, and `VaultFileStore`.**
- [ ] **Step 4: Implement SwiftUI root routing for `needsSetup`, `locked`, `unlocked`.**
- [ ] **Step 5: Create setup UI with two `SecureField`s and clear both fields after success.**
- [ ] **Step 6: Create locked UI with device unlock and master-password sheet; create unlocked shell with count + Lock.**
- [ ] **Step 7: Build with `xcodebuild -project VaultMac.xcodeproj -scheme VaultMac -configuration Debug CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build`.**

---

### Task 4: CI, review and milestone status

**Files:**
- Modify: `.github/workflows/swift-tests.yml`
- Modify: `TODO.md`
- Create: `docs/MANUAL_TEST_4A.md`

**Interfaces:**
- CI verifies both Swift package tests and the real Xcode app build.
- Manual checklist records the only remaining interactive Touch ID/system-password gate.

- [ ] **Step 1: Extend macOS 15 workflow to run package tests then `xcodebuild` for the `VaultMac` scheme with signing disabled.**
- [ ] **Step 2: Add manual first-run/relaunch/device-auth/master-password/corruption checklist.**
- [ ] **Step 3: Review PR diff for secret leakage, setup ordering, sandbox entitlements and duplicate crypto logic.**
- [ ] **Step 4: Run GitHub macOS CI; if red, inspect logs and fix root cause only.**
- [ ] **Step 5: Update `TODO.md`: mark automated 4A work complete but leave real-Mac interactive manual gate unchecked until performed.**

---

## Completion Gate

Automated 4A work is complete only when `swift test -Xswiftc -warnings-as-errors` and the `VaultMac` Xcode build are green on macOS 15 CI. Full Milestone 4A remains **IN PROGRESS** until the real-Mac manual user-presence and recovery checklist has been executed and recorded.
