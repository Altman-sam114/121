import Foundation

enum Command: Codable, Equatable {
    case move(divisionId: String, destination: HexCoord)
    case attack(attackerId: String, targetId: String)
    case hold(divisionId: String)
    case allowRetreat(divisionId: String)
    case resupply(divisionId: String)
    case queueProduction(kind: ProductionKind)
    case improveRoad(regionId: RegionId)
    case proposeDiplomacy(
        sourceCountryId: CountryId,
        targetCountryId: CountryId,
        proposal: DiplomaticProposal
    )
    case endTurn

    static func rest(divisionId: String) -> Command {
        .resupply(divisionId: divisionId)
    }

    static func reinforce(divisionId: String) -> Command {
        .resupply(divisionId: divisionId)
    }

    var displayName: String {
        switch self {
        case .move(let divisionId, let destination):
            return "进军(\(divisionId) -> \(destination.q),\(destination.r))"
        case .attack(let attackerId, let targetId):
            return "攻击(\(attackerId) -> \(targetId))"
        case .hold(let divisionId):
            return "固守(\(divisionId))"
        case .allowRetreat(let divisionId):
            return "准许撤退(\(divisionId))"
        case .resupply(let divisionId):
            return "补给(\(divisionId))"
        case .queueProduction(let kind):
            return "募兵(\(kind.displayName))"
        case .improveRoad(let regionId):
            return "修路(\(regionId.rawValue))"
        case .proposeDiplomacy(let sourceCountryId, let targetCountryId, let proposal):
            return "外交(\(sourceCountryId.rawValue) -> \(targetCountryId.rawValue): \(proposal.displayName))"
        case .endTurn:
            return "结束回合"
        }
    }

    var actingDivisionId: String? {
        switch self {
        case .move(let divisionId, _),
             .hold(let divisionId),
             .allowRetreat(let divisionId),
             .resupply(let divisionId):
            return divisionId
        case .attack(let attackerId, _):
            return attackerId
        case .queueProduction:
            return nil
        case .improveRoad:
            return nil
        case .proposeDiplomacy:
            return nil
        case .endTurn:
            return nil
        }
    }

    var isRecoveryCommand: Bool {
        switch self {
        case .resupply:
            return true
        case .move,
             .attack,
             .hold,
             .allowRetreat,
             .queueProduction,
             .improveRoad,
             .proposeDiplomacy,
             .endTurn:
            return false
        }
    }
}
