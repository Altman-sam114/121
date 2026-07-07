import Foundation

enum Faction: String, Codable, Equatable, CaseIterable {
    case germany
    case allies
    case cao
    case yuan
    case liuBei
    case sun
    case liuBiao
    case maTeng
    case han
    case neutral

    /// Active turn factions in the current v2.1 compatibility layer.
    /// Three Kingdoms factions are decodable for data, but turn order is still legacy two-side.
    static let activeTurnCases: [Faction] = [.germany, .allies]

    /// Keep legacy `allCases` as the active turn set until turn order is redesigned.
    static let allCases: [Faction] = activeTurnCases

    /// Factions that scenario data and the MapEditor may express.
    static let scenarioCases: [Faction] = [
        .germany,
        .allies,
        .cao,
        .yuan,
        .liuBei,
        .sun,
        .liuBiao,
        .maTeng,
        .han,
        .neutral
    ]

    /// Legacy two-side helper. New multi-faction code should use diplomacy relations.
    var opponent: Faction {
        switch self {
        case .germany:
            return .allies
        case .allies:
            return .germany
        case .cao:
            return .yuan
        case .yuan:
            return .cao
        case .liuBei, .sun, .liuBiao, .maTeng, .han:
            return .neutral
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
        case .cao:
            return "Cao Cao"
        case .yuan:
            return "Yuan Shao"
        case .liuBei:
            return "Liu Bei"
        case .sun:
            return "Sun Clan"
        case .liuBiao:
            return "Liu Biao"
        case .maTeng:
            return "Ma Teng"
        case .han:
            return "Han Court"
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
    static let gameTitle = "三国棋策"
    static let scenarioPreviewName = "官渡迁移预览"

    static func factionName(_ faction: Faction) -> String {
        switch faction {
        case .germany:
            return "曹操势力"
        case .allies:
            return "袁绍势力"
        case .cao:
            return "曹操势力"
        case .yuan:
            return "袁绍势力"
        case .liuBei:
            return "刘备势力"
        case .sun:
            return "孙氏势力"
        case .liuBiao:
            return "刘表势力"
        case .maTeng:
            return "马腾势力"
        case .han:
            return "汉室"
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
        case .cao:
            return "曹军"
        case .yuan:
            return "袁军"
        case .liuBei:
            return "刘军"
        case .sun:
            return "孙军"
        case .liuBiao:
            return "荆州"
        case .maTeng:
            return "马军"
        case .han:
            return "汉室"
        case .neutral:
            return "中立"
        }
    }
}
