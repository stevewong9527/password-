import SwiftUI

struct UnlockedView: View {
    @ObservedObject var model: AppModel
    let recordCount: Int
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.open.fill").font(.system(size: 48))
            Text("Vault Unlocked").font(.largeTitle.bold())
            Text("\(recordCount) password records").foregroundStyle(.secondary)
            Button("Lock") { Task { await model.lock() } }.disabled(model.isBusy)
        }
    }
}
