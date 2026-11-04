import SwiftUI

/// 设置九宫格解锁：画两次图案一致 + 输入主密码验证后保存。
struct PatternSetupView: View {
    @EnvironmentObject var vault: VaultStore
    @Environment(\.dismiss) var dismiss

    @State private var step: Step = .first
    @State private var firstPattern: [Int] = []
    @State private var password = ""
    @State private var showPassword = false
    @State private var errorMsg: String?

    enum Step { case first, second }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(step == .first ? "画出你的九宫格图案" : "请再次画出相同的图案")
                    .font(.headline)
                Text("至少连接 4 个点")
                    .font(.caption)
                    .foregroundColor(.secondary)

                PatternLockView(onComplete: { pattern in
                    handle(pattern)
                })
                .id(step)
                .frame(width: 260, height: 260)

                if let errorMsg {
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundColor(.red)
                        .transition(.opacity)
                }

                if showPassword {
                    SecureField("输入主密码以确认", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 40)
                    Button {
                        save()
                    } label: {
                        Text("保存")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(password.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(password.isEmpty)
                    .padding(.horizontal, 40)
                }
            }
            .padding()
            .animation(.easeInOut(duration: 0.25), value: showPassword)
            .navigationTitle("设置九宫格解锁")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func handle(_ pattern: [Int]) {
        switch step {
        case .first:
            firstPattern = pattern
            step = .second
            showPassword = false
            password = ""
            errorMsg = nil
        case .second:
            if pattern == firstPattern {
                showPassword = true
                errorMsg = nil
            } else {
                errorMsg = "两次图案不一致，请重新设置"
                step = .first
                firstPattern = []
                showPassword = false
                password = ""
            }
        }
    }

    private func save() {
        guard vault.verifyMasterPassword(password) else {
            errorMsg = "主密码错误"
            return
        }
        vault.setPattern(firstPattern, masterPassword: password)
        dismiss()
    }
}
