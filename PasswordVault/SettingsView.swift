import SwiftUI

/// 设置页
struct SettingsView: View {
    @EnvironmentObject var vault: VaultStore
    @State private var showChangePassword = false

    var body: some View {
        NavigationStack {
            Form {
                Section("安全") {
                    Button("修改主密码") { showChangePassword = true }
                }
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("数据存储")
                        Spacer()
                        Text("本地加密").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView()
            }
        }
    }
}

/// 修改主密码
struct ChangePasswordView: View {
    @EnvironmentObject var vault: VaultStore
    @Environment(\.dismiss) var dismiss
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
