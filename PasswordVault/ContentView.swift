import SwiftUI

/// 根视图：根据状态显示"设置主密码 / 解锁 / 主界面"
struct RootView: View {
    @EnvironmentObject var vault: VaultStore

    var body: some View {
        if !vault.hasMasterPassword {
            SetupPasswordView()
        } else if !vault.isUnlocked {
            UnlockView()
        } else {
            MainTabView()
        }
    }
}

/// 首次启动：设置主密码
struct SetupPasswordView: View {
    @EnvironmentObject var vault: VaultStore
    @State private var password = ""
    @State private var confirm = ""

    private var canSave: Bool {
        !password.isEmpty && password == confirm
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            Text("设置主密码")
                .font(.title2).bold()
            Text("主密码用于加密你的所有数据，请务必牢记，忘记将无法找回。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            SecureField("设置主密码", text: $password)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)
            SecureField("确认主密码", text: $confirm)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)
            Button {
                vault.setupMasterPassword(password)
            } label: {
                Text("完成")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSave ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!canSave)
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

/// 每次打开 App 的锁屏：输入主密码
struct UnlockView: View {
    @EnvironmentObject var vault: VaultStore
    @State private var password = ""

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            Text("已锁定")
                .font(.title2).bold()
            Text("输入主密码解锁")
                .font(.subheadline)
                .foregroundColor(.secondary)
            SecureField("输入主密码", text: $password)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)
            Button {
                if vault.unlock(with: password) {
                    password = ""
                }
            } label: {
                Text("解锁")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(password.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(password.isEmpty)
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

/// 解锁后的主界面：三个 Tab
struct MainTabView: View {
    var body: some View {
        TabView {
            AccountListView()
                .tabItem { Label("账号", systemImage: "key.fill") }
            GeneratorView()
                .tabItem { Label("生成", systemImage: "dice.fill") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
    }
}
