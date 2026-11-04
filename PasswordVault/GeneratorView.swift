import SwiftUI

/// 密码生成器：紧凑但不挤，一屏可见
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
            VStack(spacing: 12) {
                // 密码结果
                VStack(spacing: 8) {
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
                    if showCopied {
                        Text("已复制")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(cardStyle)

                // 密码强度
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("密码强度").font(.subheadline)
                        Spacer()
                        if !result.isEmpty {
                            Text(strengthDetail)
                                .font(.caption2).bold()
                                .foregroundColor(strengthColor)
                        }
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
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(cardStyle)

                // 长度
                VStack(spacing: 6) {
                    HStack {
                        Text("长度").font(.subheadline)
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
                VStack(spacing: 0) {
                    toggleRow("大写 A-Z", $upper)
                    Divider().padding(.vertical, 4)
                    toggleRow("小写 a-z", $lower)
                    Divider().padding(.vertical, 4)
                    toggleRow("数字 0-9", $digits)
                    Divider().padding(.vertical, 4)
                    toggleRow("符号 !@#", $symbols)
                    Divider().padding(.vertical, 4)
                    toggleRow("排除易混淆 0O1Il", $excludeAmbiguous)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(cardStyle)

                // 按钮
                HStack(spacing: 12) {
                    BigActionButton(title: "生成", icon: "wand.and.stars", color: .blue) {
                        result = generate()
                        showCopied = false
                    }
                    BigActionButton(title: "复制", icon: "doc.on.doc", color: .green, disabled: result.isEmpty) {
                        vault.copyText(result)
                        showCopied = true
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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

    private var strengthDetail: String {
        let bits = entropyBits
        if bits >= 80 { return "极强 · \(Int(bits)) bits" }
        if bits >= 60 { return "强 · \(Int(bits)) bits" }
        if bits >= 40 { return "中 · \(Int(bits)) bits" }
        return "弱 · \(Int(bits)) bits"
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
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(disabled ? Color.gray : color)
                )
                .scaleEffect(pressed ? 0.97 : 1)
                .opacity(disabled ? 0.45 : (pressed ? 0.85 : 1))
        }
        .buttonStyle(.plain)
    }
}
