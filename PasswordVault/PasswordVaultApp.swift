import SwiftUI

@main
struct PasswordVaultApp: App {
    @StateObject private var vault = VaultStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var backgroundTime: Date?

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(vault)
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .background:
                        // 记录进入后台的时间，回到前台时判断是否超时
                        backgroundTime = Date()
                    case .active:
                        if let bg = backgroundTime {
                            let interval = vault.autoLockInterval
                            if interval <= 0 || Date().timeIntervalSince(bg) >= interval {
                                vault.lock()
                            }
                        }
                        backgroundTime = nil
                    default:
                        break
                    }
                }
        }
    }
}
