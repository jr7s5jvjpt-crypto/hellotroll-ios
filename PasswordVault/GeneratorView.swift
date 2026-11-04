import SwiftUI

/// 密码生成器
struct GeneratorView: View {
    @EnvironmentObject var vault: VaultStore
    @State private var length: Double = 12
    @State private var upper = true
    @State private var lower = true
    @State private var digits = true
    @State private var symbols = true
    @State private var result = ""
    @State private var showCopied = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(result.isEmpty ? "点击下方生成" : result)
                        .font(.title3.monospaced())
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 8)
                    Button("生成密码") {
                        result = generate()
                        showCopied = false
                    }
                    .frame(maxWidth: .infinity)
                    if !result.isEmpty {
                        Button("复制") {
                            vault.copyText(result)
                            showCopied = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                    if showCopied {
                        Text("已复制到剪贴板")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                Section("长度：\(Int(length))") {
                    Slider(value: $length, in: 4...32, step: 1)
                }
                Section("包含字符") {
                    Toggle("大写字母 A-Z", isOn: $upper)
                    Toggle("小写字母 a-z", isOn: $lower)
                    Toggle("数字 0-9", isOn: $digits)
                    Toggle("符号 !@#$%^&*", isOn: $symbols)
                }
            }
            .navigationTitle("密码生成器")
        }
    }

    private func generate() -> String {
        var pool = ""
        if upper { pool += "ABCDEFGHIJKLMNOPQRSTUVWXYZ" }
        if lower { pool += "abcdefghijklmnopqrstuvwxyz" }
        if digits { pool += "0123456789" }
        if symbols { pool += "!@#$%^&*()-_=+[]{};:,.<>?" }
        guard !pool.isEmpty else { return "" }
        return String((0..<Int(length)).map { _ in pool.randomElement()! })
    }
}
