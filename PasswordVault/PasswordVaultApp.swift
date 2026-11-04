import SwiftUI
import UIKit

@main
struct PasswordVaultApp: App {
    @StateObject private var vault = VaultStore()
    @State private var backgroundTime: Date?

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(vault)
                // 记录进入后台的时间，回到前台时判断是否超时自动锁定
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    backgroundTime = Date()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    if let bg = backgroundTime {
                        let interval = vault.autoLockInterval
                        if interval <= 0 || Date().timeIntervalSince(bg) >= interval {
                            vault.lock()
                        }
                    }
                    backgroundTime = nil
                }
        }
    }
}
