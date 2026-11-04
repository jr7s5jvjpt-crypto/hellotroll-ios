import Foundation

/// 账号类型（用于分组展示），支持自定义类型
enum AccountType: String, CaseIterable, Identifiable, Codable {
    case website = "网站"
    case app = "App"
    case bank = "银行卡"
    case idcard = "证件"
    case custom = "自定义"
    case other = "其他"

    var id: String { rawValue }
}

/// 一条账号记录
struct AccountItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: AccountType = .website
    /// 自定义类型的名称（当 type == .custom 时使用）
    var customType: String = ""
    var title: String = ""
    var account: String = ""
    var password: String = ""
    var note: String = ""
}

/// 账号的显示类型名：自定义类型显示自定义名称，否则显示内置类型
func typeDisplayName(for item: AccountItem) -> String {
    if item.type == .custom && !item.customType.isEmpty {
        return item.customType
    }
    return item.type.rawValue
}
