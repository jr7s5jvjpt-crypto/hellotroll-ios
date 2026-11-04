import SwiftUI

@main
struct PasswordVaultApp: App {
    @StateObject private var vault = VaultStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(vault)
                .onChange(of: scenePhase) { _, newPhase in
                    // 切到后台即锁定，下次进入需重新验证
                    if newPhase == .background {
                        vault.lock()
                    }
                }
        }
    }
}
