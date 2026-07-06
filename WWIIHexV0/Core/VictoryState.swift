import Foundation

enum VictoryReason: String, Codable, Equatable {
    case scenarioObjectiveControlled
    case bastogneHeldByGermany
    case bastogneAndStVithControlledByGermany
    case alliedUnitsDestroyed
    case bastogneHeldByAlliesAtFinalTurn
    case germanUnitsDestroyed
    case germanArmorUnsupplied

    var displayName: String {
        switch self {
        case .scenarioObjectiveControlled:
            return "达成剧本目标"
        case .bastogneHeldByGermany:
            return "关键城池被攻方长期控制"
        case .bastogneAndStVithControlledByGermany:
            return "攻方控制主要目标"
        case .alliedUnitsDestroyed:
            return "守方军队溃散"
        case .bastogneHeldByAlliesAtFinalTurn:
            return "守方守住关键城池"
        case .germanUnitsDestroyed:
            return "攻方军队溃散"
        case .germanArmorUnsupplied:
            return "攻方主力粮道断绝"
        }
    }
}

struct ScenarioVictoryCondition: Codable, Equatable, Identifiable {
    let id: String
    let type: String
    let faction: Faction
    let objectiveId: String?
    let objectiveIds: [String]
    let status: String
    let description: String
}

struct VictoryState: Codable, Equatable {
    var winner: Faction?
    var reason: VictoryReason?
    var reasonDescription: String?
    var eliminatedGermanDivisions: Int
    var eliminatedAlliedDivisions: Int
    var germanBastogneHeldSinceTurn: Int?
    var germanArmorUnsuppliedSinceTurn: Int?
    var scenarioConditions: [ScenarioVictoryCondition]

    init(
        winner: Faction?,
        reason: VictoryReason?,
        reasonDescription: String? = nil,
        eliminatedGermanDivisions: Int,
        eliminatedAlliedDivisions: Int,
        germanBastogneHeldSinceTurn: Int?,
        germanArmorUnsuppliedSinceTurn: Int?,
        scenarioConditions: [ScenarioVictoryCondition] = []
    ) {
        self.winner = winner
        self.reason = reason
        self.reasonDescription = reasonDescription
        self.eliminatedGermanDivisions = eliminatedGermanDivisions
        self.eliminatedAlliedDivisions = eliminatedAlliedDivisions
        self.germanBastogneHeldSinceTurn = germanBastogneHeldSinceTurn
        self.germanArmorUnsuppliedSinceTurn = germanArmorUnsuppliedSinceTurn
        self.scenarioConditions = scenarioConditions
    }

    static var ongoing: VictoryState {
        VictoryState(
            winner: nil,
            reason: nil,
            eliminatedGermanDivisions: 0,
            eliminatedAlliedDivisions: 0,
            germanBastogneHeldSinceTurn: nil,
            germanArmorUnsuppliedSinceTurn: nil
        )
    }

    func withScenarioConditions(_ conditions: [ScenarioVictoryCondition]) -> VictoryState {
        var copy = self
        copy.scenarioConditions = conditions
        return copy
    }

    var displayReason: String? {
        reasonDescription ?? reason?.displayName
    }

    mutating func recordEliminatedDivision(faction: Faction) {
        switch faction {
        case .germany:
            eliminatedGermanDivisions += 1
        case .allies:
            eliminatedAlliedDivisions += 1
        case .cao, .yuan, .liuBei, .sun, .liuBiao, .maTeng, .han, .neutral:
            break
        }
    }

    private enum CodingKeys: String, CodingKey {
        case winner
        case reason
        case reasonDescription
        case eliminatedGermanDivisions
        case eliminatedAlliedDivisions
        case germanBastogneHeldSinceTurn
        case germanArmorUnsuppliedSinceTurn
        case scenarioConditions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            winner: try container.decodeIfPresent(Faction.self, forKey: .winner),
            reason: try container.decodeIfPresent(VictoryReason.self, forKey: .reason),
            reasonDescription: try container.decodeIfPresent(String.self, forKey: .reasonDescription),
            eliminatedGermanDivisions: try container.decodeIfPresent(Int.self, forKey: .eliminatedGermanDivisions) ?? 0,
            eliminatedAlliedDivisions: try container.decodeIfPresent(Int.self, forKey: .eliminatedAlliedDivisions) ?? 0,
            germanBastogneHeldSinceTurn: try container.decodeIfPresent(Int.self, forKey: .germanBastogneHeldSinceTurn),
            germanArmorUnsuppliedSinceTurn: try container.decodeIfPresent(Int.self, forKey: .germanArmorUnsuppliedSinceTurn),
            scenarioConditions: try container.decodeIfPresent([ScenarioVictoryCondition].self, forKey: .scenarioConditions) ?? []
        )
    }
}
