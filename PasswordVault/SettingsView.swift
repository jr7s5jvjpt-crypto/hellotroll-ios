import SwiftUI

/// 设置页
struct SettingsView: View {
    @EnvironmentObject var vault: VaultStore
    @State private var showChangePassword = false
    @State private var showPatternSetup = false
    @State private var showPatternInvalidAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("安全") {
                    Button("修改主密码") { showChangePassword = true }
                    if vault.hasPattern {
                        Button("修改九宫格解锁") { showPatternSetup = true }
                        Button("关闭九宫格解锁", role: .destructive) {
                            vault.clearPattern()
                        }
                    } else {
                        Button("开启九宫格解锁") { showPatternSetup = true }
                    }
                }
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.1").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("数据存储")
                        Spacer()
                        Text("本地加密").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .animation(.easeInOut(duration: 0.25), value: vault.hasPattern)
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView(onSaved: {
                    if vault.hasPattern {
                        showPatternInvalidAlert = true
                    }
                })
            }
            .sheet(isPresented: $showPatternSetup) {
                PatternSetupView()
            }
            .alert("主密码已修改", isPresented: $showPatternInvalidAlert) {
                Button("好的", role: .cancel) {}
            } message: {
                Text("九宫格解锁用的旧主密码已失效，请重新设置九宫格解锁。")
            }
        }
    }
}

/// 修改主密码
struct ChangePasswordView: View {
    @EnvironmentObject var vault: VaultStore
    @Environment(\.dismiss) var dismiss
    var onSaved: (() -> Void)?

    @State private var old = ""
    @State private var new = ""
    @State private var confirm = ""
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            Form {
                SecureField("当前主密码", text: $old)
                SecureField("新主密码", text: $new)
                SecureField("确认新主密码", text: $confirm)
                if let errorMsg {
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("修改主密码")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard !new.isEmpty, new == confirm else {
                            errorMsg = "新密码为空或两次输入不一致"
                            return
                        }
                        if vault.changeMasterPassword(from: old, to: new) {
                            dismiss()
                            onSaved?()
                        } else {
                            errorMsg = "当前主密码错误"
                        }
                    }
                    .disabled(new.isEmpty)
                }
            }
        }
    }
}
