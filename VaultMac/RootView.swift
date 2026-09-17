import SwiftUI
import VaultAppCore

struct RootView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Group {
            switch model.state {
            case .needsSetup: CreateVaultView(model: model)
            case .locked: LockedView(model: model)
            case .unlocked(let recordCount): UnlockedView(model: model, recordCount: recordCount)
            }
        }.padding(32).overlay(alignment: .bottom) { if let message = model.message { Text(message).font(.callout).foregroundStyle(.secondary).padding(.bottom, 12) } }
    }
}
