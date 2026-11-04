import Foundation
import SwiftUI
import UIKit
import CryptoKit
import LocalAuthentication
import Security

/// 数据仓库：负责账号数据的加载、保存、加密与解锁。
/// 数据以加密文件形式存在 App 的 Documents 目录下（vault.dat）。
final class VaultStore: ObservableObject {

    @Published var isUnlocked = false
    @Published var hasMasterPassword = false
    @Published var items: [AccountItem] = []
    /// 安全相关设置变化时的刷新触发器（九宫格/面容开关等），供设置页 UI 刷新
    @Published var securityRefresh = 0

    private var key: SymmetricKey?
    private let fileURL: URL
    /// 数据文件魔数前缀，用于校验数据完整性（新格式带前缀，兼容旧格式）
    private let vaultMagic = "PV1"

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
        hasMasterPassword = true
        isUnlocked = true
    }

    /// 输入主密码解锁；密码正确返回 true
    func unlock(with password: String) -> Bool {
        guard let data = try? Data(contentsOf: fileURL) else { return false }
        let candidateKey = CryptoManager.deriveKey(from: password)
        guard let dec = try? CryptoManager.decrypt(data, key: candidateKey) else { return false }
        key = candidateKey
        // 校验并去除数据前缀（兼容无前缀的旧版本数据）
        var payload = dec
        let magic = Data(vaultMagic.utf8)
        if dec.count >= magic.count, Data(dec.prefix(magic.count)) == magic {
            payload = Data(dec.dropFirst(magic.count))
        }
        items = (try? JSONDecoder().decode([AccountItem].self, from: payload)) ?? []
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

    /// 锁定：清空内存中的密钥与数据，回到锁屏
    func lock() {
        key = nil
        items = []
        isUnlocked = false
    }

    /// 自动锁定时间（秒）。0 表示切后台立即锁定；非 0 表示后台停留超过该时间才锁定。
    /// 无论设置多少，完全退出软件（进程被杀）后重新打开始终需要输入密码。
    var autoLockInterval: Double {
        get { UserDefaults.standard.double(forKey: "autoLockInterval") }
        set { UserDefaults.standard.set(newValue, forKey: "autoLockInterval") }
    }

    /// 账号列表是否直接显示密码（默认隐藏）
    var showPasswordInList: Bool {
        get { UserDefaults.standard.bool(forKey: "showPasswordInList") }
        set { UserDefaults.standard.set(newValue, forKey: "showPasswordInList") }
    }

    /// 上次备份时间
    var lastBackupDate: Date? {
        UserDefaults.standard.object(forKey: "lastBackupDate") as? Date
    }

    /// 连续输错达到上限后，临时锁定（防暴力破解）
    private var failCount = 0
    private var lockUntil: Date?

    /// 当前是否处于输错锁定状态
    var isLockedOut: Bool {
        guard let until = lockUntil else { return false }
        if until > Date() { return true }
        lockUntil = nil
        failCount = 0
        return false
    }

    /// 记录一次输错；连续 5 次错误锁定 30 秒
    func registerFail() {
        failCount += 1
        if failCount >= 5 {
            lockUntil = Date().addingTimeInterval(30)
            failCount = 0
        }
    }

    /// 解锁成功时清除失败计数
    func clearFails() {
        failCount = 0
        lockUntil = nil
    }

    /// 修改主密码：先验证旧密码，再用新密码重新加密全部数据
    func changeMasterPassword(from old: String, to new: String) -> Bool {
        guard unlock(with: old) else { return false }
        key = CryptoManager.deriveKey(from: new)
        _ = try? save()
        securityRefresh += 1
        return true
    }

    /// 复制文本到剪贴板；默认 30 秒后自动清空（避免密码残留）
    func copyText(_ text: String) {
        let pb = UIPasteboard.general
        pb.string = text
        let enabled = UserDefaults.standard.object(forKey: "autoClearClipboard") as? Bool ?? true
        guard enabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if pb.string == text { pb.string = "" }
        }
    }

    /// 常见弱密码库（本地比对，不联网）
    private let commonWeakPasswords: Set<String> = [
        "123456", "password", "123456789", "12345678", "12345", "qwerty", "abc123",
        "111111", "123123", "admin", "letmein", "welcome", "000000", "password1",
        "iloveyou", "1234567", "1234567890", "1234", "football", "monkey"
    ]

    /// 判断密码是否过弱（过短、过于简单、或常见弱密码）
    func isWeakPassword(_ p: String) -> Bool {
        if p.isEmpty { return false }
        if commonWeakPasswords.contains(p.lowercased()) { return true }
        if p.count < 8 { return true }
        let hasLetter = p.rangeOfCharacter(from: .letters) != nil
        let hasDigit = p.rangeOfCharacter(from: .decimalDigits) != nil
        return !(hasLetter && hasDigit)
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
        securityRefresh += 1
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

    /// 验证主密码是否正确（不改变解锁状态），用于设置九宫格/面容时校验身份
    func verifyMasterPassword(_ password: String) -> Bool {
        guard let data = try? Data(contentsOf: fileURL) else { return false }
        let key = CryptoManager.deriveKey(from: password)
        return (try? CryptoManager.decrypt(data, key: key)) != nil
    }

    /// 关闭九宫格解锁
    func clearPattern() {
        UserDefaults.standard.removeObject(forKey: patternStoreKey)
        securityRefresh += 1
    }

    // MARK: - 面容识别

    private let biometricService = "com.pwvault.biometric"
    private let biometricAccount = "masterPassword"

    /// 是否已启用面容识别
    var isBiometricEnabled: Bool {
        UserDefaults.standard.bool(forKey: "biometricEnabled")
    }

    /// 启用面容识别：先扫描面容验证，通过后把主密码存入普通钥匙串
    func enableBiometric(masterPassword: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            completion(false)
            return
        }
        // 先扫描面容验证（开启时也扫一次，与常规软件一致）
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                               localizedReason: "开启面容识别前请先验证") { success, _ in
            guard success else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            // 面容通过后，主密码存入普通钥匙串（不设生物识别 access control，避免读取时崩溃）
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.biometricService,
                kSecAttrAccount as String: self.biometricAccount,
                kSecValueData as String: Data(masterPassword.utf8),
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            SecItemDelete(query as CFDictionary)
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            UserDefaults.standard.set(true, forKey: "biometricEnabled")
            DispatchQueue.main.async {
                self.securityRefresh += 1
                completion(true)
            }
        }
    }

    /// 关闭面容识别
    func disableBiometric() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: biometricService,
            kSecAttrAccount as String: biometricAccount
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.set(false, forKey: "biometricEnabled")
        securityRefresh += 1
    }

    /// 用面容识别解锁：先由系统在界面触发面容验证，通过后再读取钥匙串中的主密码
    func unlockWithBiometric(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            completion(false)
            return
        }
        // 先扫描面容验证
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                               localizedReason: "使用面容识别快速解锁") { success, _ in
            guard success else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            // 面容通过后读取普通钥匙串（不再触发生物识别 access control，避免崩溃）
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.biometricService,
                kSecAttrAccount as String: self.biometricAccount,
                kSecReturnData as String: true
            ]
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            guard status == errSecSuccess, let data = item as? Data,
                  let password = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            let ok = self.unlock(with: password)
            DispatchQueue.main.async { completion(ok) }
        }
    }

    // MARK: - 备份与还原

    /// 导出备份：把加密数据打包成 JSON（base64）
    func exportBackupData() -> Data? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let dict: [String: Any] = [
            "version": 1,
            "created": ISO8601DateFormatter().string(from: Date()),
            "data": data.base64EncodedString()
        ]
        return try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted])
    }

    /// 生成备份文件 URL（写入临时目录，用于分享/保存）
    func exportBackupFileURL() -> URL? {
        guard let data = exportBackupData() else { return nil }
        UserDefaults.standard.set(Date(), forKey: "lastBackupDate")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PasswordVaultBackup-\(Int(Date().timeIntervalSince1970)).json")
        try? data.write(to: url)
        return url
    }

    /// 导入备份：解析 JSON，写回加密数据文件。成功后返回 true（需要重新解锁）
    func importBackup(data: Data) -> Bool {
        guard let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let b64 = dict["data"] as? String,
              let raw = Data(base64Encoded: b64) else { return false }
        do {
            try raw.write(to: fileURL, options: Data.WritingOptions.atomic)
            lock()
            return true
        } catch {
            return false
        }
    }

    private func save() throws {
        guard let key = key else { return }
        let data = try JSONEncoder().encode(items)
        // 加魔数前缀，用于读取时校验完整性
        let payload = Data(vaultMagic.utf8) + data
        let enc = try CryptoManager.encrypt(payload, key: key)
        try enc.write(to: fileURL, options: Data.WritingOptions.atomic)
    }
}
