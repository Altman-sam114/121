import Foundation

enum VictoryReason: String, Codable, Equatable {
    case bastogneHeldByGermany
    case bastogneAndStVithControlledByGermany
    case alliedUnitsDestroyed
    case bastogneHeldByAlliesAtFinalTurn
    case germanUnitsDestroyed
    case germanArmorUnsupplied

    var displayName: String {
        switch self {
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

struct VictoryState: Codable, Equatable {
    var winner: Faction?
    var reason: VictoryReason?
    var eliminatedGermanDivisions: Int
    var eliminatedAlliedDivisions: Int
    var germanBastogneHeldSinceTurn: Int?
    var germanArmorUnsuppliedSinceTurn: Int?

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

    mutating func recordEliminatedDivision(faction: Faction) {
        switch faction {
        case .germany:
            eliminatedGermanDivisions += 1
        case .allies:
            eliminatedAlliedDivisions += 1
        }
    }
}
