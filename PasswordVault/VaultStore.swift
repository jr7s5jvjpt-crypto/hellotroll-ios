import Foundation
import SwiftUI
import UIKit
import CryptoKit

/// 数据仓库：负责账号数据的加载、保存、加密与解锁。
/// 数据以加密文件形式存在 App 的 Documents 目录下（vault.dat）。
final class VaultStore: ObservableObject {

    @Published var isUnlocked = false
    @Published var hasMasterPassword = false
    @Published var items: [AccountItem] = []

    private var key: SymmetricKey?
    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = dir.appendingPathComponent("vault.dat")
        hasMasterPassword = UserDefaults.standard.bool(forKey: "hasMasterPassword")
    }

    /// 首次启动设置主密码（同时初始化空数据文件）
    func setupMasterPassword(_ password: String) {
        key = CryptoManager.deriveKey(from: password)
        items = []
        _ = try? save()
        UserDefaults.standard.set(true, forKey: "hasMasterPassword")
        isUnlocked = true
    }

    /// 输入主密码解锁；密码正确返回 true
    func unlock(with password: String) -> Bool {
        guard let data = try? Data(contentsOf: fileURL) else { return false }
        let candidateKey = CryptoManager.deriveKey(from: password)
        guard let dec = try? CryptoManager.decrypt(data, key: candidateKey) else { return false }
        key = candidateKey
        items = (try? JSONDecoder().decode([AccountItem].self, from: dec)) ?? []
        isUnlocked = true
        return true
    }

    func add(_ item: AccountItem) {
        items.append(item)
        _ = try? save()
    }

    func update(_ item: AccountItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i] = item
        _ = try? save()
    }

    func delete(_ item: AccountItem) {
        items.removeAll { $0.id == item.id }
        _ = try? save()
    }

    /// 修改主密码：先验证旧密码，再用新密码重新加密全部数据
    func changeMasterPassword(from old: String, to new: String) -> Bool {
        guard unlock(with: old) else { return false }
        key = CryptoManager.deriveKey(from: new)
        _ = try? save()
        return true
    }

    /// 复制文本到剪贴板
    func copyText(_ text: String) {
        UIPasteboard.general.string = text
    }

    // MARK: - 九宫格解锁

    private let patternStoreKey = "patternVault"

    /// 是否已设置九宫格解锁
    var hasPattern: Bool {
        UserDefaults.standard.string(forKey: patternStoreKey) != nil
    }

    /// 设置九宫格：用图案派生密钥加密保护主密码（仅在主密码已验证正确时调用）
    func setPattern(_ pattern: [Int], masterPassword: String) {
        let key = CryptoManager.derivePatternKey(from: pattern)
        guard let enc = try? CryptoManager.encrypt(Data(masterPassword.utf8), key: key) else { return }
        UserDefaults.standard.set(enc.base64EncodedString(), forKey: patternStoreKey)
    }

    /// 用九宫格图案解锁：画对图案 → 解出主密码 → 走正常解锁流程
    func unlockWithPattern(_ pattern: [Int]) -> Bool {
        guard let b64 = UserDefaults.standard.string(forKey: patternStoreKey),
              let enc = Data(base64Encoded: b64) else { return false }
        let key = CryptoManager.derivePatternKey(from: pattern)
        guard let dec = try? CryptoManager.decrypt(enc, key: key),
              let password = String(data: dec, encoding: .utf8) else { return false }
        return unlock(with: password)
    }

    /// 验证主密码是否正确（不改变解锁状态），用于设置九宫格时校验身份
    func verifyMasterPassword(_ password: String) -> Bool {
        guard let data = try? Data(contentsOf: fileURL) else { return false }
        let key = CryptoManager.deriveKey(from: password)
        return (try? CryptoManager.decrypt(data, key: key)) != nil
    }

    /// 关闭九宫格解锁
    func clearPattern() {
        UserDefaults.standard.removeObject(forKey: patternStoreKey)
    }

    private func save() throws {
        guard let key = key else { return }
        let data = try JSONEncoder().encode(items)
        let enc = try CryptoManager.encrypt(data, key: key)
        try enc.write(to: fileURL, options: Data.WritingOptions.atomic)
    }
}
