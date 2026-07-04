import Foundation

enum Faction: String, Codable, Equatable, CaseIterable {
    case germany
    case allies

    var opponent: Faction {
        switch self {
        case .germany:
            return .allies
        case .allies:
            return .germany
        }
    }

    var legacyDisplayName: String {
        switch self {
        case .germany:
            return "Germany"
        case .allies:
            return "Allies"
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
        }
    }

    static func factionShortName(_ faction: Faction) -> String {
        switch faction {
        case .germany:
            return "曹军"
        case .allies:
            return "袁军"
        }
    }
}
