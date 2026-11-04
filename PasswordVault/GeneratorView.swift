import SwiftUI

/// 密码生成器：按用途和规则生成密码（图二布局，自定义卡片式）
struct GeneratorView: View {
    @EnvironmentObject var vault: VaultStore
    @State private var length: Double = 16
    @State private var upper = true
    @State private var lower = true
    @State private var digits = true
    @State private var symbols = true
    @State private var excludeAmbiguous = false
    @State private var result = ""
    @State private var showCopied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 生成结果卡片
                    VStack(spacing: 14) {
                        Text("按用途和规则生成密码。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(result.isEmpty ? "点击下方生成" : result)
                            .font(.title2.monospaced().bold())
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !result.isEmpty {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        vault.copyText(result)
                                        showCopied = true
                                    }
                                }
                            }
                            .id(result)
                            .transition(.scale.combined(with: .opacity))

                        if showCopied {
                            Text("已复制到剪贴板")
                                .font(.caption)
                                .foregroundColor(.green)
                                .transition(.opacity)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(cardStyle)

                    // 长度
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("长度")
                            Spacer()
                            Text("\(Int(length))").foregroundColor(.secondary)
                        }
                        Slider(value: $length, in: 4...32, step: 1)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(cardStyle)

                    // 字符规则
                    VStack(alignment: .leading, spacing: 12) {
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
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(cardStyle)

                    // 生成 / 复制：上下两个独立按钮
                    VStack(spacing: 12) {
                        BigActionButton(title: "生成", icon: "wand.and.stars", color: .blue) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                result = generate()
                            }
                            showCopied = false
                        }
                        BigActionButton(title: "复制", icon: "doc.on.doc", color: .green, disabled: result.isEmpty) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                vault.copyText(result)
                                showCopied = true
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("密码生成器")
            .navigationBarTitleDisplayMode(.inline)
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

/// 带按压缩放反馈的大按钮（生成 / 复制）
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
                .padding()
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
