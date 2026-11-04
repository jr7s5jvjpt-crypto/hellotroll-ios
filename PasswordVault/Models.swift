import Foundation

/// 账号类型（用于分组展示）
enum AccountType: String, CaseIterable, Identifiable, Codable {
    case website = "网站"
    case app = "App"
    case bank = "银行卡"
    case idcard = "证件"
    case other = "其他"

    var id: String { rawValue }
}

/// 一条账号记录
struct AccountItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: AccountType = .website
    var title: String = ""
    var account: String = ""
    var password: String = ""
    var note: String = ""
}
