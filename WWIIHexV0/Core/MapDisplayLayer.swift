import Foundation

enum MapDisplayLayer: String, Codable, Equatable, CaseIterable, Identifiable {
    case hex
    case province
    case initialTheater
    case dynamicTheater
    case frontLine
    case deployment

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .hex:
            return "地格"
        case .province:
            return "郡县"
        case .initialTheater:
            return "初始方面"
        case .dynamicTheater:
            return "动态方面"
        case .frontLine:
            return "战线"
        case .deployment:
            return "防区"
        }
    }
}
