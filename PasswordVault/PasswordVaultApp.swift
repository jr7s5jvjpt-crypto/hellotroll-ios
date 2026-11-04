import SwiftUI

@main
struct PasswordVaultApp: App {
    @StateObject private var vault = VaultStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(vault)
        }
    }
}
