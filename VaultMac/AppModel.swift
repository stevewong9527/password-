import Foundation
import VaultAppCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state: VaultAppState = .needsSetup
    @Published var message: String?
    @Published var isBusy = false
    @Published var showMasterPassword = false
    @Published private(set) var recoveryDelay: TimeInterval = 0
    private let coordinator: VaultAppCoordinator?

    init() {
        do { coordinator = try VaultMacDependencies.makeCoordinator() }
        catch { coordinator = nil; message = "Vault data is unavailable." }
    }
    func bootstrap() async { guard let coordinator else { return }; await coordinator.bootstrap(); await refreshState() }
    func createVault(masterPassword: String, confirmation: String) async -> Bool {
        guard let coordinator else { return false }; isBusy = true; defer { isBusy = false }
        do { try await coordinator.createVault(masterPassword: masterPassword, confirmation: confirmation); message = nil; await refreshState(); return true }
        catch VaultAppCoordinatorError.invalidPasswordConfirmation { message = "Master passwords must be non-empty and match." }
        catch { message = "Unable to create vault." }
        return false
    }
    func unlockWithDeviceAuthentication() async {
        guard let coordinator else { return }; isBusy = true; defer { isBusy = false }
        do { try await coordinator.unlockWithDeviceAuthentication(reason: "Unlock your VaultMac password vault"); message = nil }
        catch { message = "Unable to unlock." }
        await refreshState()
    }
    func unlockWithMasterPassword(_ password: String) async -> Bool {
        guard let coordinator else { return false }; isBusy = true; defer { isBusy = false }
        do { try await coordinator.unlockWithMasterPassword(password); message = nil; showMasterPassword = false; recoveryDelay = 0; await refreshState(); return true }
        catch VaultAppCoordinatorError.recoveryTemporarilyBlocked(let delay) { recoveryDelay = delay; message = "Please wait before trying again." }
        catch { recoveryDelay = await coordinator.recoveryRemainingDelay(); message = "Recovery password was not accepted." }
        await refreshState(); return false
    }
    func lock() async { guard let coordinator else { return }; await coordinator.lock(); message = nil; recoveryDelay = 0; await refreshState() }
    private func refreshState() async { guard let coordinator else { return }; state = await coordinator.state }
}
