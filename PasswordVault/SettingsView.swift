import SwiftUI
import UniformTypeIdentifiers

/// 设置页
struct SettingsView: View {
    @EnvironmentObject var vault: VaultStore
    @State private var showChangePassword = false
    @State private var showPatternSetup = false
    @State private var showImporter = false
    @AppStorage("autoClearClipboard") private var autoClearClipboard = true
    @AppStorage("showPasswordInList") private var showPasswordInList = false
    @State private var showPatternInvalidAlert = false
    @State private var backupResult: BackupResult?
    @State private var autoLockSelection: Double = 0

    enum BackupResult { case imported, importFailed }

    private var lastBackupText: String {
        guard let d = vault.lastBackupDate else { return "从未" }
        let days = Int(Date().timeIntervalSince(d) / 86400)
        if days <= 0 { return "今天" }
        if days < 365 { return "\(days) 天前" }
        return "\(days / 365) 年前"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showChangePassword = true
                    } label: {
                        Label("修改主密码", systemImage: "key")
                    }
                    if vault.hasPattern {
                        Button {
                            showPatternSetup = true
                        } label: {
                            Label("修改九宫格解锁", systemImage: "circle.grid.cross.fill")
                        }
                        Button(role: .destructive) {
                            vault.clearPattern()
                        } label: {
                            Label("关闭九宫格解锁", systemImage: "circle.grid.cross")
                        }
                    } else {
                        Button {
                            showPatternSetup = true
                        } label: {
                            Label("开启九宫格解锁", systemImage: "circle.grid.cross.fill")
                        }
                    }
                    LabeledContent {
                        Picker("自动锁定", selection: $autoLockSelection) {
                            Text("立即锁定").tag(0.0)
                            Text("30 秒").tag(30.0)
                            Text("1 分钟").tag(60.0)
                            Text("5 分钟").tag(300.0)
                            Text("10 分钟").tag(600.0)
                        }
                        .onChange(of: autoLockSelection) { newValue in
                            vault.autoLockInterval = newValue
                        }
                    } label: {
                        Label("自动锁定", systemImage: "timer")
                    }
                    LabeledContent {
                        Toggle("", isOn: $autoClearClipboard)
                            .labelsHidden()
                    } label: {
                        Label("复制后自动清除剪贴板", systemImage: "doc.on.clipboard")
                    }
                    LabeledContent {
                        Toggle("", isOn: $showPasswordInList)
                            .labelsHidden()
                    } label: {
                        Label("账号列表显示密码", systemImage: "eye")
                    }
                } header: {
                    Text("安全")
                } footer: {
                    Text("切后台后超过该时间需重新输入密码；完全退出软件后始终需要密码。")
                }
                Section("备份与还原") {
                    if let url = vault.exportBackupFileURL() {
                        ShareLink(item: url, preview: SharePreview("密码保险箱备份")) {
                            Label("导出加密备份", systemImage: "lock.doc")
                        }
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("导入加密备份", systemImage: "lock.doc.fill")
                    }
                    if let csvURL = vault.exportCSVFileURL() {
                        ShareLink(item: csvURL, preview: SharePreview("账号数据 CSV")) {
                            Label("导出 CSV 表格", systemImage: "tablecells")
                        }
                    }
                }
                Section("关于") {
                    HStack {
                        Label("版本", systemImage: "info.circle")
                        Spacer()
                        Text("1.2").foregroundColor(.secondary)
                    }
                    HStack {
                        Label("上次备份", systemImage: "arrow.clockwise")
                        Spacer()
                        Text(lastBackupText).foregroundColor(.secondary)
                    }
                    HStack {
                        Label("数据存储", systemImage: "lock.shield")
                        Spacer()
                        Text("本地加密").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .onAppear { autoLockSelection = vault.autoLockInterval }
            .animation(.easeInOut(duration: 0.25), value: vault.securityRefresh)
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
