import Foundation

enum RegionCommand: Codable, Equatable {
    case move(divisionId: String, from: RegionId, to: RegionId)
    case attack(attackerId: String, from: RegionId, targetDivisionId: String, targetRegionId: RegionId?)
    case hold(divisionId: String, regionId: RegionId?)
    case resupply(divisionId: String, regionId: RegionId?)

    var displayName: String {
        switch self {
        case .move:
            return "郡县进军"
        case .attack:
            return "郡县交战"
        case .hold:
            return "郡县固守"
        case .resupply:
            return "郡县补给"
        }
    }

    var actingDivisionId: String {
        switch self {
        case .move(let divisionId, _, _),
             .hold(let divisionId, _),
             .resupply(let divisionId, _):
            return divisionId
        case .attack(let attackerId, _, _, _):
            return attackerId
        }
    }
}
