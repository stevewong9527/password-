import SwiftUI

struct CreateVaultView: View {
    @ObservedObject var model: AppModel
    @State private var masterPassword = ""
    @State private var confirmation = ""
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield").font(.system(size: 48))
            Text("Create Vault").font(.largeTitle.bold())
            Text("Your master password is used only to protect a recovery copy of the vault key.").multilineTextAlignment(.center).foregroundStyle(.secondary)
            SecureField("Master Password", text: $masterPassword).textFieldStyle(.roundedBorder)
            SecureField("Confirm Master Password", text: $confirmation).textFieldStyle(.roundedBorder)
            Button("Create Vault") { let p = masterPassword; let c = confirmation; Task { if await model.createVault(masterPassword: p, confirmation: c) { masterPassword = ""; confirmation = "" } } }.keyboardShortcut(.defaultAction).disabled(model.isBusy || masterPassword.isEmpty || confirmation.isEmpty)
        }.frame(maxWidth: 420)
    }
}
