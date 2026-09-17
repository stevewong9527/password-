import SwiftUI

struct LockedView: View {
    @ObservedObject var model: AppModel
    @State private var masterPassword = ""
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill").font(.system(size: 48))
            Text("Vault Locked").font(.largeTitle.bold())
            Button("Unlock") { Task { await model.unlockWithDeviceAuthentication() } }.keyboardShortcut(.defaultAction).disabled(model.isBusy)
            Button("Use Master Password") { masterPassword = ""; model.showMasterPassword = true }.buttonStyle(.link).disabled(model.isBusy)
        }.sheet(isPresented: $model.showMasterPassword) {
            VStack(spacing: 16) {
                Text("Recover Vault").font(.title2.bold())
                SecureField("Master Password", text: $masterPassword).textFieldStyle(.roundedBorder)
                if model.recoveryDelay > 0 { Text("Try again in about \(Int(ceil(model.recoveryDelay))) seconds.").font(.caption).foregroundStyle(.secondary) }
                HStack { Button("Cancel") { masterPassword = ""; model.showMasterPassword = false }; Spacer(); Button("Unlock") { let p = masterPassword; Task { if await model.unlockWithMasterPassword(p) { masterPassword = "" } } }.keyboardShortcut(.defaultAction).disabled(model.isBusy || masterPassword.isEmpty || model.recoveryDelay > 0) }
            }.padding(24).frame(width: 380)
        }
    }
}
