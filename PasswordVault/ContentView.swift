import SwiftUI

/// 根视图：根据状态显示"设置主密码 / 解锁 / 主界面"
struct RootView: View {
    @EnvironmentObject var vault: VaultStore

    var body: some View {
        ZStack {
            if !vault.hasMasterPassword {
                SetupPasswordView()
                    .transition(.opacity)
            } else if !vault.isUnlocked {
                UnlockView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: vault.hasMasterPassword)
        .animation(.easeInOut(duration: 0.35), value: vault.isUnlocked)
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
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    vault.setupMasterPassword(password)
                }
            } label: {
                Text("完成")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSave ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(!canSave)
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

/// 每次打开 App 的锁屏：主密码 或 九宫格
struct UnlockView: View {
    @EnvironmentObject var vault: VaultStore
    @State private var password = ""
    @State private var mode: UnlockMode = .password
    @State private var errorMsg: String?
    @State private var shake = false

    enum UnlockMode { case password, pattern }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            Text("已锁定")
                .font(.title2).bold()
            Text("解锁后查看你的密码保险箱")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if vault.hasPattern {
                Picker("解锁方式", selection: $mode) {
                    Text("主密码").tag(UnlockMode.password)
                    Text("九宫格").tag(UnlockMode.pattern)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 50)
                .animation(.easeInOut(duration: 0.2), value: mode)
            }

            Group {
                if mode == .password {
                    passwordSection
                } else {
                    patternSection
                }
            }
            .animation(.easeInOut(duration: 0.25), value: mode)

            if let errorMsg {
                Text(errorMsg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .transition(.opacity)
            }
            Spacer()
        }
        .padding()
    }

    private var passwordSection: some View {
        VStack(spacing: 16) {
            SecureField("输入主密码", text: $password)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 50)
                .offset(x: shake ? -8 : 0)
                .animation(.easeInOut(duration: 0.08).repeatCount(shake ? 3 : 0), value: shake)
            Button {
                if vault.unlock(with: password) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        password = ""
                        errorMsg = nil
                    }
                } else {
                    errorMsg = "主密码错误"
                    shake = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shake = false }
                }
            } label: {
                Text("解锁")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(password.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(password.isEmpty)
            .padding(.horizontal, 50)
        }
    }

    private var patternSection: some View {
        VStack(spacing: 16) {
            PatternLockView(onComplete: { pattern in
                if vault.unlockWithPattern(pattern) {
                    errorMsg = nil
                } else {
                    errorMsg = "图案错误"
                }
            })
            .frame(width: 260, height: 260)
            Text("请画出你的解锁图案")
                .font(.caption)
                .foregroundColor(.secondary)
        }
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
