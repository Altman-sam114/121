import Foundation

enum GamePhase: String, Codable, Equatable, CaseIterable {
    case germanAI
    case alliedPlayer
    case resolution

    var displayName: String {
        switch self {
        case .germanAI:
            return "AI 势力行动"
        case .alliedPlayer:
            return "玩家行动"
        case .resolution:
            return "结算"
        }
    }
}
