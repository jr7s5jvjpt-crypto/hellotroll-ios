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
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: vault.hasMasterPassword)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: vault.isUnlocked)
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
    @State private var isUnlocking = false
    @State private var unlockSucceeded = false

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

            if vault.isBiometricEnabled {
                Button {
                    vault.unlockWithBiometric { ok in
                        if !ok { errorMsg = "面容识别失败或未授权" }
                    }
                } label: {
                    Label("面容解锁", systemImage: "faceid")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 50)
            }

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
                guard !isUnlocking else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isUnlocking = true
                }
                // 给按压动画一点时间，再验证密码
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if vault.verifyMasterPassword(password) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            unlockSucceeded = true
                        }
                        // 打勾反馈后，真正解锁进入主界面
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            _ = vault.unlock(with: password)
                        }
                    } else {
                        errorMsg = "主密码错误"
                        shake = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            isUnlocking = false
                            shake = false
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if unlockSucceeded {
                        Image(systemName: "checkmark.circle.fill")
                    } else if isUnlocking {
                        ProgressView()
                    }
                    Text(unlockSucceeded ? "已解锁" : (isUnlocking ? "解锁中…" : "解锁"))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(unlockSucceeded ? Color.green : (password.isEmpty ? Color.gray : Color.blue))
                .foregroundColor(.white)
                .cornerRadius(12)
                .scaleEffect(isUnlocking ? 0.94 : 1.0)
            }
            .disabled(password.isEmpty || isUnlocking)
            .padding(.horizontal, 50)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isUnlocking)
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

/// 解锁后的主界面：三个 Tab（自定义底部导航，小图标 + 点击反馈）
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            if selectedTab == 0 {
                AccountListView().transition(.opacity)
            } else if selectedTab == 1 {
                GeneratorView().transition(.opacity)
            } else {
                SettingsView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            tabBar
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(0, "账号", "key.fill")
            tabButton(1, "生成", "dice.fill")
            tabButton(2, "设置", "gearshape.fill")
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func tabButton(_ index: Int, _ title: String, _ icon: String) -> some View {
        let selected = selectedTab == index
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(selected ? .blue : .secondary)
                    .scaleEffect(selected ? 1.05 : 0.9)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(selected ? .blue : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
