import Foundation

struct GeneralAssignment: Codable, Equatable, Identifiable {
    let id: String
    var generalId: String { id }
    var hqRegionId: RegionId?
    var assignedDivisionIds: [String]
    var commandStyleRawValue: String?
    var skills: [String]
    var loyalty: Int
    var satisfaction: Int
    var interventionCount: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case hqRegionId
        case assignedDivisionIds
        case commandStyleRawValue
        case skills
        case loyalty
        case satisfaction
        case interventionCount
    }

    init(
        generalId: String,
        hqRegionId: RegionId? = nil,
        assignedDivisionIds: [String] = [],
        commandStyleRawValue: String? = nil,
        skills: [String] = [],
        loyalty: Int = 70,
        satisfaction: Int = 70,
        interventionCount: Int = 0
    ) {
        self.id = generalId
        self.hqRegionId = hqRegionId
        self.assignedDivisionIds = assignedDivisionIds.sorted()
        self.commandStyleRawValue = commandStyleRawValue
        self.skills = skills.sorted()
        self.loyalty = Self.clampPercent(loyalty)
        self.satisfaction = Self.clampPercent(satisfaction)
        self.interventionCount = max(0, interventionCount)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            generalId: try container.decode(String.self, forKey: .id),
            hqRegionId: try container.decodeIfPresent(RegionId.self, forKey: .hqRegionId),
            assignedDivisionIds: try container.decodeIfPresent([String].self, forKey: .assignedDivisionIds) ?? [],
            commandStyleRawValue: try container.decodeIfPresent(String.self, forKey: .commandStyleRawValue),
            skills: try container.decodeIfPresent([String].self, forKey: .skills) ?? [],
            loyalty: try container.decodeIfPresent(Int.self, forKey: .loyalty) ?? 70,
            satisfaction: try container.decodeIfPresent(Int.self, forKey: .satisfaction) ?? 70,
            interventionCount: try container.decodeIfPresent(Int.self, forKey: .interventionCount) ?? 0
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(hqRegionId, forKey: .hqRegionId)
        try container.encode(assignedDivisionIds, forKey: .assignedDivisionIds)
        try container.encodeIfPresent(commandStyleRawValue, forKey: .commandStyleRawValue)
        try container.encode(skills, forKey: .skills)
        try container.encode(loyalty, forKey: .loyalty)
        try container.encode(satisfaction, forKey: .satisfaction)
        try container.encode(interventionCount, forKey: .interventionCount)
    }

    func withAssignedDivisionIds(_ divisionIds: [String]) -> GeneralAssignment {
        GeneralAssignment(
            generalId: generalId,
            hqRegionId: hqRegionId,
            assignedDivisionIds: divisionIds,
            commandStyleRawValue: commandStyleRawValue,
            skills: skills,
            loyalty: loyalty,
            satisfaction: satisfaction,
            interventionCount: interventionCount
        )
    }

    func withSnapshot(commandStyleRawValue: String?, skills: [String]) -> GeneralAssignment {
        GeneralAssignment(
            generalId: generalId,
            hqRegionId: hqRegionId,
            assignedDivisionIds: assignedDivisionIds,
            commandStyleRawValue: commandStyleRawValue,
            skills: skills,
            loyalty: loyalty,
            satisfaction: satisfaction,
            interventionCount: interventionCount
        )
    }

    func registeringPlayerIntervention(cost: Int = 4) -> GeneralAssignment {
        GeneralAssignment(
            generalId: generalId,
            hqRegionId: hqRegionId,
            assignedDivisionIds: assignedDivisionIds,
            commandStyleRawValue: commandStyleRawValue,
            skills: skills,
            loyalty: loyalty,
            satisfaction: satisfaction - max(0, cost),
            interventionCount: interventionCount + 1
        )
    }

    private static func clampPercent(_ value: Int) -> Int {
        max(0, min(100, value))
    }
}
