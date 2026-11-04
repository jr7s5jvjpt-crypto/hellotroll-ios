import SwiftUI

/// 密码生成器：按用途和规则生成密码（图二布局）
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
            Form {
                Section {
                    Text("按用途和规则生成密码。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)

                    // 生成结果：居中大字
                    Text(result.isEmpty ? "点击下方生成" : result)
                        .font(.title2.monospaced().bold())
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 16)
                        .id(result)
                        .transition(.scale.combined(with: .opacity))
                }

                Section("长度：\(Int(length))") {
                    Slider(value: $length, in: 4...32, step: 1)
                }

                Section("字符规则") {
                    Toggle(isOn: $upper) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("大写 A-Z")
                            Text("加入大写，提升组合强度").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Toggle(isOn: $lower) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("小写 a-z")
                            Text("加入小写，扩大可用范围").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Toggle(isOn: $digits) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("数字 0-9")
                            Text("加入数字").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Toggle(isOn: $symbols) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("符号")
                            Text("加入！@# 等特殊符号").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Toggle(isOn: $excludeAmbiguous) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("排除混淆")
                            Text("排除 0/O、1/I/l 等易混淆字符").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            result = generate()
                        }
                        showCopied = false
                    } label: {
                        Text("生成")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vault.copyText(result)
                            showCopied = true
                        }
                    } label: {
                        Text("复制")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(result.isEmpty)
                    if showCopied {
                        Text("已复制到剪贴板")
                            .font(.caption)
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                            .transition(.opacity)
                    }
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
