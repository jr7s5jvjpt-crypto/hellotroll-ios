import SwiftUI
import UniformTypeIdentifiers

/// 设置页
struct SettingsView: View {
    @EnvironmentObject var vault: VaultStore
    @State private var showChangePassword = false
    @State private var showPatternSetup = false
    @State private var showBiometricSetup = false
    @State private var showImporter = false
    @State private var showPatternInvalidAlert = false
    @State private var backupResult: BackupResult?

    enum BackupResult { case imported, importFailed }

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
                    if vault.isBiometricEnabled {
                        Button("关闭面容识别", role: .destructive) {
                            vault.disableBiometric()
                        }
                    } else {
                        Button("开启面容识别") { showBiometricSetup = true }
                    }
                }
                Section("备份与还原") {
                    if let url = vault.exportBackupFileURL() {
                        ShareLink(item: url, preview: SharePreview("密码保险箱备份")) {
                            Label("导出备份", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button("导入备份") { showImporter = true }
                }
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.2").foregroundColor(.secondary)
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
            .sheet(isPresented: $showBiometricSetup) {
                BiometricSetupView()
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json]
            ) { result in
                switch result {
                case .success(let url):
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    if let data = try? Data(contentsOf: url), vault.importBackup(data: data) {
                        backupResult = .imported
                    } else {
                        backupResult = .importFailed
                    }
                case .failure:
                    backupResult = .importFailed
                }
            }
            .alert("主密码已修改", isPresented: $showPatternInvalidAlert) {
                Button("好的", role: .cancel) {}
            } message: {
                Text("九宫格解锁用的旧主密码已失效，请重新设置九宫格解锁。")
            }
            .alert(
                backupResult == .imported ? "导入成功" : "导入失败",
                isPresented: Binding(
                    get: { backupResult != nil },
                    set: { if !$0 { backupResult = nil } }
                )
            ) {
                Button("好的", role: .cancel) {}
            } message: {
                Text(backupResult == .imported
                     ? "数据已还原，请用对应的主密码重新解锁。"
                     : "无法导入，请确认是有效的备份文件。")
            }
        }
    }
}

/// 开启面容识别：输入主密码验证后启用
struct BiometricSetupView: View {
    @EnvironmentObject var vault: VaultStore
    @Environment(\.dismiss) var dismiss
    @State private var password = ""
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("输入主密码", text: $password)
                } footer: {
                    Text("开启后可用面容识别快速解锁。需先在系统设置中录入面容。")
                }
                if let errorMsg {
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("开启面容识别")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("开启") {
                        guard vault.verifyMasterPassword(password) else {
                            errorMsg = "主密码错误"
                            return
                        }
                        if vault.enableBiometric(masterPassword: password) {
                            dismiss()
                        } else {
                            errorMsg = "开启失败：设备不支持面容识别"
                        }
                    }
                    .disabled(password.isEmpty)
                }
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
