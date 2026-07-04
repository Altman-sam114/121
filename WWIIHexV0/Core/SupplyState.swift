import Foundation

enum SupplyState: String, Codable, Equatable, CaseIterable {
    case supplied
    case lowSupply
    case encircled

    var displayName: String {
        switch self {
        case .supplied:
            return "粮道通畅"
        case .lowSupply:
            return "粮草紧张"
        case .encircled:
            return "粮道断绝"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .supplied:
            return "足"
        case .lowSupply:
            return "缺"
        case .encircled:
            return "断"
        }
    }
}
