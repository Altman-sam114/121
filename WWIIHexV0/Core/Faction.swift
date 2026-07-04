import Foundation

enum Faction: String, Codable, Equatable, CaseIterable {
    case germany
    case allies
    case neutral

    /// Active turn factions in the current v2.1 compatibility layer.
    /// `.neutral` is decodable for data ownership, but it is not a turn participant yet.
    static let allCases: [Faction] = [.germany, .allies]

    /// Legacy two-side helper. New multi-faction code should use diplomacy relations.
    var opponent: Faction {
        switch self {
        case .germany:
            return .allies
        case .allies:
            return .germany
        case .neutral:
            return .neutral
        }
    }

    var isNeutral: Bool {
        self == .neutral
    }

    func isHostile(to other: Faction) -> Bool {
        self != other && !isNeutral && !other.isNeutral
    }

    var legacyDisplayName: String {
        switch self {
        case .germany:
            return "Germany"
        case .allies:
            return "Allies"
        case .neutral:
            return "Neutral"
        }
    }

    var displayName: String {
        SanguoDisplayLexicon.factionName(self)
    }

    var shortDisplayName: String {
        SanguoDisplayLexicon.factionShortName(self)
    }
}

enum SanguoDisplayLexicon {
    static let gameTitle = "三国棋策 Agent"
    static let scenarioPreviewName = "官渡迁移预览"

    static func factionName(_ faction: Faction) -> String {
        switch faction {
        case .germany:
            return "曹操势力"
        case .allies:
            return "袁绍势力"
        case .neutral:
            return "中立"
        }
    }

    static func factionShortName(_ faction: Faction) -> String {
        switch faction {
        case .germany:
            return "曹军"
        case .allies:
            return "袁军"
        case .neutral:
            return "中立"
        }
    }
}
