import Foundation
import CryptoKit

/// 加密工具：用主密码派生出密钥，对数据进行 AES-GCM 加密。
/// 主密码本身不存储，只存储密文；主密码错误时解密会失败，据此判断密码是否正确。
enum CryptoManager {

    private static let salt = Data("PasswordVault::salt::v1".utf8)
    private static let info = Data("PasswordVault::encKey::v1".utf8)

    /// 从主密码派生 32 字节对称密钥
    static func deriveKey(from password: String) -> SymmetricKey {
        let passwordData = Data(password.utf8)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: salt,
            info: info,
            outputByteCount: 32
        )
    }

    /// 加密明文，返回 nonce + 密文 + tag 的组合数据
    static func encrypt(_ plain: Data, key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(plain, using: key)
        guard let combined = sealed.combined else {
            throw CryptoError.encryptFailed
        }
        return combined
    }

    /// 解密。密钥错误（即主密码错误）时会抛错。
    static func decrypt(_ combined: Data, key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: key)
    }

    enum CryptoError: Error {
        case encryptFailed
    }
}
