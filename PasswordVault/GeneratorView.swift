import SwiftUI

/// 密码生成器：按用途和规则生成密码（紧凑布局，一屏可见）
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
                VStack(spacing: 10) {
                    // 生成结果卡片
                    VStack(spacing: 6) {
                        Text(result.isEmpty ? "点击下方生成" : result)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.35)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .multilineTextAlignment(.center)
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

                        Text(showCopied ? "已复制到剪贴板" : "点密码可复制")
                            .font(.caption2)
                            .foregroundColor(showCopied ? .green : .secondary)
                            .animation(.easeInOut(duration: 0.2), value: showCopied)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(cardStyle)

                    // 密码强度（基于真实熵值）
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("密码强度").font(.subheadline)
                            Spacer()
                            Text(strengthDetail)
                                .font(.caption2).bold()
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(cardStyle)

                    // 长度 + 字符规则（合并到一张卡片，省空间）
                    VStack(spacing: 0) {
                        HStack {
                            Text("长度")
                            Spacer()
                            Text("\(Int(length))").foregroundColor(.secondary)
                        }
                        .padding(.bottom, 4)
                        Slider(value: $length, in: 4...32, step: 1)
                            .controlSize(.small)

                        Divider().padding(.vertical, 6)

                        toggleRow("大写 A-Z", $upper)
                        Divider().padding(.vertical, 2)
                        toggleRow("小写 a-z", $lower)
                        Divider().padding(.vertical, 2)
                        toggleRow("数字 0-9", $digits)
                        Divider().padding(.vertical, 2)
                        toggleRow("符号 !@#$", $symbols)
                        Divider().padding(.vertical, 2)
                        toggleRow("排除易混淆 0O1Il", $excludeAmbiguous)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(cardStyle)

                    // 生成 / 复制
                    VStack(spacing: 8) {
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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("密码生成器")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var cardStyle: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(.systemBackground))
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    private func toggleRow(_ title: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Text(title).font(.subheadline)
        }
    }

    // MARK: - 密码强度（基于真实信息熵：bits = 长度 × log2(字符池大小)）

    /// 当前字符池大小（实际可用字符数）
    private var poolSize: Int {
        var n = 0
        if upper { n += 26 }
        if lower { n += 26 }
        if digits { n += 10 }
        if symbols { n += 26 }
        if excludeAmbiguous {
            // 排除 0 O 1 I l 共5个字符（从对应的类别中减去）
            var excl = 0
            if digits { excl += 1 } // 0
            if upper { excl += 2 }  // O, I
            if lower { excl += 2 }  // l
            n = max(n - excl, 1)
        }
        return max(n, 1)
    }

    /// 熵值（比特）
    private var entropyBits: Double {
        guard !result.isEmpty else { return 0 }
        return Double(result.count) * log2(Double(poolSize))
    }

    private var strengthFraction: Double {
        // 以 100 bits 为满分基准
        min(entropyBits / 100.0, 1.0)
    }

    private var strengthLabel: String {
        let bits = entropyBits
        if bits >= 80 { return "极强" }
        if bits >= 60 { return "强" }
        if bits >= 40 { return "中" }
        if bits > 0 { return "弱" }
        return "—"
    }

    private var strengthDetail: String {
        guard entropyBits > 0 else { return "" }
        return "\(strengthLabel) · \(Int(entropyBits)) bits"
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
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(disabled ? Color.gray : color)
                )
                .scaleEffect(pressed ? 0.97 : 1)
                .opacity(disabled ? 0.45 : (pressed ? 0.85 : 1))
                .animation(.spring(response: 0.2, dampingFraction: 0.5), value: pressed)
        }
        .buttonStyle(.plain)
    }
}
