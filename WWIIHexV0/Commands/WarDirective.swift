import Foundation

enum DirectiveType: String, Codable, Equatable, CaseIterable {
    case defend
    case attack
}

enum CommandCategory: String, Codable, Equatable, CaseIterable {
    case offense
    case defense
}

enum TacticName: String, Codable, Equatable, CaseIterable {
    case standardAttack
    case holdPosition

    var category: CommandCategory {
        switch self {
        case .standardAttack:
            return .offense
        case .holdPosition:
            return .defense
        }
    }
}

struct TacticCondition: Codable, Equatable {
    let requiredCommanderSkills: [String]
    let minimumStrengthRatio: Double
    let requiresArmorUnit: Bool

    init(
        requiredCommanderSkills: [String],
        minimumStrengthRatio: Double,
        requiresArmorUnit: Bool
    ) {
        self.requiredCommanderSkills = requiredCommanderSkills
        self.minimumStrengthRatio = max(0, minimumStrengthRatio)
        self.requiresArmorUnit = requiresArmorUnit
    }

    static let none = TacticCondition(
        requiredCommanderSkills: [],
        minimumStrengthRatio: 0,
        requiresArmorUnit: false
    )
}

struct TacticDescriptor: Codable, Equatable {
    let name: TacticName
    let category: CommandCategory
    let condition: TacticCondition
    let description: String
}

enum DirectiveTarget: Equatable {
    case theater(TheaterId)
    case region(RegionId)
}

extension DirectiveTarget: Codable {
    private enum CodingKeys: String, CodingKey {
        case theater
        case region
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let theaterId = try container.decodeIfPresent(TheaterId.self, forKey: .theater) {
            self = .theater(theaterId)
            return
        }
        if let regionId = try container.decodeIfPresent(RegionId.self, forKey: .region) {
            self = .region(regionId)
            return
        }
        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "DirectiveTarget requires theater or region.")
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .theater(let theaterId):
            try container.encode(theaterId, forKey: .theater)
        case .region(let regionId):
            try container.encode(regionId, forKey: .region)
        }
    }
}

enum DefenseStance: String, Codable, Equatable, CaseIterable {
    case holdLine
    case flexible
}

enum AttackIntensity: String, Codable, Equatable, CaseIterable {
    case infiltration
    case limitedCounter
    case allOut
}

struct DefenseParameters: Codable, Equatable {
    let targetReserves: Int
    let stance: DefenseStance

    init(targetReserves: Int, stance: DefenseStance) {
        self.targetReserves = max(0, targetReserves)
        self.stance = stance
    }
}

struct AttackParameters: Codable, Equatable {
    let targetTheaterId: TheaterId
    let weightedRegions: [RegionId]
    let intensity: AttackIntensity

    init(
        targetTheaterId: TheaterId,
        weightedRegions: [RegionId],
        intensity: AttackIntensity
    ) {
        self.targetTheaterId = targetTheaterId
        self.weightedRegions = weightedRegions
        self.intensity = intensity
    }
}

enum DirectiveParameters: Equatable {
    case defend(DefenseParameters)
    case attack(AttackParameters)

    var defense: DefenseParameters? {
        if case .defend(let parameters) = self {
            return parameters
        }
        return nil
    }

    var attack: AttackParameters? {
        if case .attack(let parameters) = self {
            return parameters
        }
        return nil
    }
}

struct ZoneDirective: Codable, Equatable {
    let zoneId: FrontZoneId
    let type: DirectiveType
    let parameters: DirectiveParameters
    let category: CommandCategory?
    let tactic: TacticName?
    let commandTarget: DirectiveTarget?

    var targetRegionIds: [RegionId] {
        switch parameters {
        case .defend:
            return []
        case .attack(let attack):
            return attack.weightedRegions
        }
    }

    init(
        zoneId: FrontZoneId,
        type: DirectiveType,
        parameters: DirectiveParameters,
        category: CommandCategory? = nil,
        tactic: TacticName? = nil,
        commandTarget: DirectiveTarget? = nil
    ) {
        self.zoneId = zoneId
        self.type = type
        self.parameters = parameters
        self.category = category
        self.tactic = tactic
        self.commandTarget = commandTarget
    }

    init(
        zoneId: FrontZoneId,
        defense: DefenseParameters,
        category: CommandCategory? = nil,
        tactic: TacticName? = nil,
        commandTarget: DirectiveTarget? = nil
    ) {
        self.init(
            zoneId: zoneId,
            type: .defend,
            parameters: .defend(defense),
            category: category,
            tactic: tactic,
            commandTarget: commandTarget
        )
    }

    init(
        zoneId: FrontZoneId,
        attack: AttackParameters,
        category: CommandCategory? = nil,
        tactic: TacticName? = nil,
        commandTarget: DirectiveTarget? = nil
    ) {
        self.init(
            zoneId: zoneId,
            type: .attack,
            parameters: .attack(attack),
            category: category,
            tactic: tactic,
            commandTarget: commandTarget
        )
    }

    private enum CodingKeys: String, CodingKey {
        case zoneId
        case type
        case parameters
        case category
        case tactic
        case commandTarget
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        zoneId = try container.decode(FrontZoneId.self, forKey: .zoneId)
        type = try container.decode(DirectiveType.self, forKey: .type)
        category = try container.decodeIfPresent(CommandCategory.self, forKey: .category)
        tactic = try container.decodeIfPresent(TacticName.self, forKey: .tactic)
        commandTarget = try container.decodeIfPresent(DirectiveTarget.self, forKey: .commandTarget)

        switch type {
        case .defend:
            parameters = .defend(try container.decode(DefenseParameters.self, forKey: .parameters))
        case .attack:
            parameters = .attack(try container.decode(AttackParameters.self, forKey: .parameters))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(zoneId, forKey: .zoneId)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(tactic, forKey: .tactic)
        try container.encodeIfPresent(commandTarget, forKey: .commandTarget)

        switch parameters {
        case .defend(let defense):
            try container.encode(defense, forKey: .parameters)
        case .attack(let attack):
            try container.encode(attack, forKey: .parameters)
        }
    }
}

struct DirectiveEnvelope: Codable, Equatable {
    let schemaVersion: Int
    let issuerId: String
    let turn: Int
    let directives: [ZoneDirective]
    let commanderAgentId: String?
    let theaterContext: String?

    init(
        schemaVersion: Int = 1,
        issuerId: String,
        turn: Int,
        directives: [ZoneDirective],
        commanderAgentId: String? = nil,
        theaterContext: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.issuerId = issuerId
        self.turn = turn
        self.directives = directives
        self.commanderAgentId = commanderAgentId
        self.theaterContext = theaterContext
    }
}
