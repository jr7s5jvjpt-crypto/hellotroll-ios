import Foundation
import SwiftUI
import UIKit

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
        hasMasterPassword = FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// 首次启动设置主密码（同时初始化空数据文件）
    func setupMasterPassword(_ password: String) {
        key = CryptoManager.deriveKey(from: password)
        items = []
        _ = try? save()
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

    private func save() throws {
        guard let key = key else { return }
        let data = try JSONEncoder().encode(items)
        let enc = try CryptoManager.encrypt(data, key: key)
        try enc.write(to: fileURL, options: .atomic)
    }
}
