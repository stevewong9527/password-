import SwiftUI

@main
struct VaultMacApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene { WindowGroup { RootView(model: model).frame(minWidth: 520, minHeight: 380).task { await model.bootstrap() } } }
}
