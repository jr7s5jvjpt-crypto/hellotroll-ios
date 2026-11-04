import SwiftUI

/// 密码生成器：按用途和规则生成密码
struct GeneratorView: View {
    @EnvironmentObject var vault: VaultStore
    @State private var length: Double = 16
    @State private var upper = true
    @State private var lower = true
    @State private var digits = true
    @State private var symbols = true
    @State private var excludeAmbiguous = false
    @State private var showCopied = false
    @State private var showSaveAction = false
    @State private var showNewAccountSheet = false
    @State private var showUpdateAccountList = false

    // 生成的密码存在 VaultStore 里，切 tab 不丢失
    private var result: String { vault.generatedPassword }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // 生成结果卡片
                    VStack(spacing: 10) {
                        Text("按用途和规则生成密码。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(result.isEmpty ? "点击下方生成" : result)
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.35)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .multilineTextAlignment(.center)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !result.isEmpty {
                                    vault.copyText(result)
                                    showCopied = true
                                }
                            }
                            .id(result)
                            .transition(.scale.combined(with: .opacity))

                        Text(showCopied ? "已复制到剪贴板" : "未复制到剪贴板")
                            .font(.caption)
                            .foregroundColor(showCopied ? .green : .secondary)
                            .animation(.easeInOut(duration: 0.2), value: showCopied)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(cardStyle)

                    // 密码强度
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("密码强度").font(.subheadline)
                            Spacer()
                            Text(strengthLabel)
                                .font(.caption).bold()
                                .foregroundColor(strengthColor)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(.systemGray5))
                                Capsule()
                                    .fill(strengthColor)
                                    .frame(width: geo.size.width * strengthFraction)
                            }
                        }
                        .frame(height: 6)
                        .animation(.easeInOut(duration: 0.35), value: result)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(cardStyle)

                    // 长度
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("长度")
                            Spacer()
                            Text("\(Int(length))").foregroundColor(.secondary)
                        }
                        Slider(value: $length, in: 4...32, step: 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(cardStyle)

                    // 字符规则
                    VStack(alignment: .leading, spacing: 8) {
                        toggleRow("大写 A-Z", "加入大写，提升组合强度", $upper)
                        Divider()
                        toggleRow("小写 a-z", "加入小写，扩大可用范围", $lower)
                        Divider()
                        toggleRow("数字 0-9", "加入数字", $digits)
                        Divider()
                        toggleRow("符号", "加入！@# 等特殊符号", $symbols)
                        Divider()
                        toggleRow("排除混淆", "排除 0/O、1/I/l 等易混淆字符", $excludeAmbiguous)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(cardStyle)

                    // 三个按钮
                    VStack(spacing: 10) {
                        BigActionButton(title: "生成", icon: "wand.and.stars", color: .blue) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                vault.generatedPassword = generate()
                            }
                            showCopied = false
                        }
                        BigActionButton(title: "复制", icon: "doc.on.doc", color: .green, disabled: result.isEmpty) {
                            vault.copyText(result)
                            showCopied = true
                        }
                        BigActionButton(title: "存入保险箱", icon: "square.and.arrow.down", color: .orange, disabled: result.isEmpty) {
                            showSaveAction = true
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("密码生成器")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("存入保险箱", isPresented: $showSaveAction, titleVisibility: .visible) {
                Button("添加为新账号") { showNewAccountSheet = true }
                Button("更新已有账号密码") { showUpdateAccountList = true }
                Button("取消", role: .cancel) {}
            } message: {
                Text("当前生成密码：\(result)")
            }
            .sheet(isPresented: $showNewAccountSheet) {
                AccountEditView(
                    item: AccountItem(password: result),
                    isNew: true
                )
            }
            .sheet(isPresented: $showUpdateAccountList) {
                UpdatePasswordView { item in
                    var updated = item
                    updated.password = result
                    vault.update(updated)
                }
            }
        }
    }

    private var cardStyle: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemBackground))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }

    private func toggleRow(_ title: String, _ sub: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(sub).font(.caption).foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 密码强度（熵值 bits = 长度 × log2(字符池)）

    private var poolSize: Int {
        var n = 0
        if upper { n += 26 }
        if lower { n += 26 }
        if digits { n += 10 }
        if symbols { n += 26 }
        if excludeAmbiguous {
            var excl = 0
            if digits { excl += 1 }
            if upper { excl += 2 }
            if lower { excl += 2 }
            n = max(n - excl, 1)
        }
        return max(n, 1)
    }

    private var entropyBits: Double {
        guard !result.isEmpty else { return 0 }
        return Double(result.count) * log2(Double(poolSize))
    }

    private var strengthFraction: Double {
        min(entropyBits / 100.0, 1.0)
    }

    private var strengthLabel: String {
        let bits = entropyBits
        if bits >= 80 { return "极强" }
        if bits >= 60 { return "强" }
        if bits >= 40 { return "中" }
        return "弱"
    }

    private var strengthColor: Color {
        let bits = entropyBits
        if bits >= 80 { return .green }
        if bits >= 60 { return .teal }
        if bits >= 40 { return .orange }
        return .red
    }

    private func generate() -> String {
        var pool = ""
        if upper { pool += "ABCDEFGHIJKLMNOPQRSTUVWXYZ" }
        if lower { pool += "abcdefghijklmnopqrstuvwxyz" }
        if digits { pool += "0123456789" }
        if symbols { pool += "!@#$%^&*()-_=+[]{};:,.<>?" }
        if excludeAmbiguous {
            let ambiguous = CharacterSet(charactersIn: "0O1Il")
            pool = pool.filter { ch in
                guard let first = ch.unicodeScalars.first else { return false }
                return !ambiguous.contains(first)
            }
        }
        guard !pool.isEmpty else { return "" }
        return String((0..<Int(length)).map { _ in pool.randomElement()! })
    }
}

/// 选择已有账号来更新密码
struct UpdatePasswordView: View {
    @EnvironmentObject var vault: VaultStore
    @Environment(\.dismiss) var dismiss
    @State private var selectedItem: AccountItem?
    @State private var showConfirm = false
    let onUpdate: (AccountItem) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(vault.items) { item in
                    Button {
                        selectedItem = item
                        showConfirm = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title.isEmpty ? "未命名" : item.title)
                                Text(item.account).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.tertiary)
                        }
                    }
                }
            }
            .navigationTitle("选择要更新的账号")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .confirmationDialog(
                "确认更新密码？",
                isPresented: $showConfirm,
                presenting: selectedItem
            ) { item in
                Button("确认更新") {
                    onUpdate(item)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: { item in
                Text("将把「\(item.title.isEmpty ? "未命名" : item.title)」的密码替换为新生成的密码。")
            }
        }
    }
}

/// 带按压缩放反馈的大按钮
struct BigActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var disabled = false
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: {
            guard !disabled else { return }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                pressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    pressed = false
                }
                action()
            }
        }) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14).fill(disabled ? Color.gray : color)
                )
                .scaleEffect(pressed ? 0.96 : 1)
                .opacity(disabled ? 0.45 : (pressed ? 0.85 : 1))
                .animation(.spring(response: 0.2, dampingFraction: 0.5), value: pressed)
        }
        .buttonStyle(.plain)
    }
}
