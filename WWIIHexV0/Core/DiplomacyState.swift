import Foundation

struct CountryId: Hashable, Codable, Equatable, RawRepresentable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    init(_ value: String) {
        self.rawValue = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct DiplomaticBlocId: Hashable, Codable, Equatable, RawRepresentable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    init(_ value: String) {
        self.rawValue = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum DiplomaticStatus: String, Codable, Equatable, CaseIterable {
    case allied
    case coBelligerent
    case neutral
    case hostile
    case atWar

    var isHostile: Bool {
        self == .hostile || self == .atWar
    }

    var displayName: String {
        switch self {
        case .allied:
            return "Allied"
        case .coBelligerent:
            return "Co-belligerent"
        case .neutral:
            return "Neutral"
        case .hostile:
            return "Hostile"
        case .atWar:
            return "At war"
        }
    }
}

struct CountryProfile: Identifiable, Codable, Equatable {
    let id: CountryId
    var name: String
    var faction: Faction
    var blocId: DiplomaticBlocId
    var rulerAgentId: String
    var isPrimaryBelligerent: Bool
    var capitalRegionId: RegionId?
    var surrenderProgress: Int
    var warSupport: Int

    init(
        id: CountryId,
        name: String,
        faction: Faction,
        blocId: DiplomaticBlocId,
        rulerAgentId: String,
        isPrimaryBelligerent: Bool = false,
        capitalRegionId: RegionId? = nil,
        surrenderProgress: Int = 0,
        warSupport: Int = 70
    ) {
        self.id = id
        self.name = name
        self.faction = faction
        self.blocId = blocId
        self.rulerAgentId = rulerAgentId
        self.isPrimaryBelligerent = isPrimaryBelligerent
        self.capitalRegionId = capitalRegionId
        self.surrenderProgress = max(0, min(100, surrenderProgress))
        self.warSupport = max(0, min(100, warSupport))
    }
}

struct DiplomaticBloc: Identifiable, Codable, Equatable {
    let id: DiplomaticBlocId
    var name: String
    var faction: Faction
    var memberCountryIds: [CountryId]

    init(id: DiplomaticBlocId, name: String, faction: Faction, memberCountryIds: [CountryId]) {
        self.id = id
        self.name = name
        self.faction = faction
        self.memberCountryIds = memberCountryIds.sorted { $0.rawValue < $1.rawValue }
    }
}

struct DiplomaticRelation: Identifiable, Codable, Equatable {
    let firstCountryId: CountryId
    let secondCountryId: CountryId
    var status: DiplomaticStatus
    var tension: Int
    var sinceTurn: Int

    var id: String {
        "\(firstCountryId.rawValue):\(secondCountryId.rawValue)"
    }

    init(
        firstCountryId: CountryId,
        secondCountryId: CountryId,
        status: DiplomaticStatus,
        tension: Int = 0,
        sinceTurn: Int = 1
    ) {
        if firstCountryId.rawValue <= secondCountryId.rawValue {
            self.firstCountryId = firstCountryId
            self.secondCountryId = secondCountryId
        } else {
            self.firstCountryId = secondCountryId
            self.secondCountryId = firstCountryId
        }
        self.status = status
        self.tension = max(0, min(100, tension))
        self.sinceTurn = max(1, sinceTurn)
    }

    func contains(_ countryId: CountryId) -> Bool {
        firstCountryId == countryId || secondCountryId == countryId
    }
}

enum RulerStrategicPosture: String, Codable, Equatable, CaseIterable {
    case offensive
    case defensive
    case coalitionMaintenance
    case stabilizeFront

    var displayName: String {
        switch self {
        case .offensive:
            return "进取"
        case .defensive:
            return "守成"
        case .coalitionMaintenance:
            return "合盟"
        case .stabilizeFront:
            return "稳固"
        }
    }
}

struct RulerDecisionRecord: Identifiable, Codable, Equatable {
    let id: String
    let turn: Int
    let faction: Faction
    let countryId: CountryId?
    let rulerAgentId: String
    let posture: RulerStrategicPosture
    let preferredFrontZoneId: FrontZoneId?
    let targetRegionIds: [RegionId]
    let attackThresholdAdjustment: Double
    let reserveBias: Int
    let diplomacySummary: String
    let rationale: String
}

struct DiplomacyState: Codable, Equatable {
    var countries: [CountryProfile]
    var blocs: [DiplomaticBloc]
    var relations: [DiplomaticRelation]
    var rulerRecords: [RulerDecisionRecord]
    var lastUpdatedTurn: Int?

    init(
        countries: [CountryProfile] = [],
        blocs: [DiplomaticBloc] = [],
        relations: [DiplomaticRelation] = [],
        rulerRecords: [RulerDecisionRecord] = [],
        lastUpdatedTurn: Int? = nil
    ) {
        self.countries = countries.sorted { $0.id.rawValue < $1.id.rawValue }
        self.blocs = blocs.sorted { $0.id.rawValue < $1.id.rawValue }
        self.relations = relations.sorted { $0.id < $1.id }
        self.rulerRecords = rulerRecords
        self.lastUpdatedTurn = lastUpdatedTurn
    }

    static var empty: DiplomacyState {
        DiplomacyState()
    }

    static func initial(for factions: [Faction], turn: Int) -> DiplomacyState {
        var countries: [CountryProfile] = []
        var blocs: [DiplomaticBloc] = []

        for faction in stableUnique(factions) {
            let seed = factionDiplomacySeed(for: faction)
            countries.append(contentsOf: seed.countries)
            blocs.append(contentsOf: seed.blocs)
        }

        return DiplomacyState(
            countries: countries,
            blocs: blocs,
            relations: makeInitialRelations(countries: countries, turn: turn),
            lastUpdatedTurn: turn
        )
    }

    static func initial(from factionStrings: [String], turn: Int) -> DiplomacyState {
        let factions = factionStrings.compactMap(Faction.init(rawValue:))
        return initial(for: factions.isEmpty ? Faction.allCases : factions, turn: turn)
    }

    var latestRulerRecord: RulerDecisionRecord? {
        rulerRecords.last
    }

    func countries(for faction: Faction) -> [CountryProfile] {
        countries.filter { $0.faction == faction }
    }

    func primaryCountry(for faction: Faction) -> CountryProfile? {
        countries(for: faction).first(where: \.isPrimaryBelligerent) ?? countries(for: faction).first
    }

    func relation(between lhs: CountryId, and rhs: CountryId) -> DiplomaticRelation? {
        let key = DiplomaticRelation(firstCountryId: lhs, secondCountryId: rhs, status: .neutral).id
        return relations.first { $0.id == key }
    }

    func hostileCountryIds(to faction: Faction) -> [CountryId] {
        let ownCountryIds = Set(countries(for: faction).map(\.id))
        var hostileCountryIds: Set<CountryId> = []
        for relation in relations where relation.status.isHostile {
            let touchesOwnCountry = ownCountryIds.contains(relation.firstCountryId) ||
                ownCountryIds.contains(relation.secondCountryId)
            guard touchesOwnCountry else {
                continue
            }
            if !ownCountryIds.contains(relation.firstCountryId) {
                hostileCountryIds.insert(relation.firstCountryId)
            }
            if !ownCountryIds.contains(relation.secondCountryId) {
                hostileCountryIds.insert(relation.secondCountryId)
            }
        }
        return hostileCountryIds.sorted { $0.rawValue < $1.rawValue }
    }

    func summary(for faction: Faction) -> String {
        let countryNames = countries(for: faction).map(\.name).joined(separator: ", ")
        let hostileCount = hostileCountryIds(to: faction).count
        return "\(faction.displayName): \(countryNames.isEmpty ? "no countries" : countryNames); \(hostileCount) hostile relation(s)."
    }

    mutating func appendRulerRecord(_ record: RulerDecisionRecord) {
        rulerRecords.append(record)
        if rulerRecords.count > 40 {
            rulerRecords.removeFirst(rulerRecords.count - 40)
        }
        lastUpdatedTurn = record.turn
    }

    private static func makeInitialRelations(countries: [CountryProfile], turn: Int) -> [DiplomaticRelation] {
        var relations: [DiplomaticRelation] = []
        for lhsIndex in countries.indices {
            for rhsIndex in countries.indices where rhsIndex > lhsIndex {
                let lhs = countries[lhsIndex]
                let rhs = countries[rhsIndex]
                let status = initialStatus(between: lhs.faction, and: rhs.faction)
                relations.append(
                    DiplomaticRelation(
                        firstCountryId: lhs.id,
                        secondCountryId: rhs.id,
                        status: status,
                        tension: status == .atWar ? 100 : 10,
                        sinceTurn: turn
                    )
                )
            }
        }
        return relations
    }

    private static func stableUnique(_ factions: [Faction]) -> [Faction] {
        var seen: Set<Faction> = []
        var result: [Faction] = []
        for faction in factions where !seen.contains(faction) {
            seen.insert(faction)
            result.append(faction)
        }
        return result
    }

    private static func initialStatus(between lhs: Faction, and rhs: Faction) -> DiplomaticStatus {
        if lhs == rhs {
            return .allied
        }
        if lhs == .neutral || rhs == .neutral || lhs == .han || rhs == .han {
            return .neutral
        }
        let atWarPairs: Set<Set<Faction>> = [
            Set([.germany, .allies]),
            Set([.cao, .yuan])
        ]
        return atWarPairs.contains(Set([lhs, rhs])) ? .atWar : .neutral
    }

    private static func factionDiplomacySeed(for faction: Faction) -> (
        countries: [CountryProfile],
        blocs: [DiplomaticBloc]
    ) {
        switch faction {
        case .germany:
            let country = CountryProfile(
                id: "germany",
                name: "German Reich",
                faction: .germany,
                blocId: "axis",
                rulerAgentId: "ruler_germany",
                isPrimaryBelligerent: true,
                warSupport: 82
            )
            return ([country], [DiplomaticBloc(id: "axis", name: "Axis", faction: .germany, memberCountryIds: [country.id])])
        case .allies:
            let countries = [
                CountryProfile(
                    id: "united_states",
                    name: "United States",
                    faction: .allies,
                    blocId: "allied_coalition",
                    rulerAgentId: "ruler_allies",
                    isPrimaryBelligerent: true,
                    warSupport: 78
                ),
                CountryProfile(
                    id: "united_kingdom",
                    name: "United Kingdom",
                    faction: .allies,
                    blocId: "allied_coalition",
                    rulerAgentId: "ruler_uk",
                    warSupport: 74
                ),
                CountryProfile(
                    id: "belgium",
                    name: "Belgium",
                    faction: .allies,
                    blocId: "allied_coalition",
                    rulerAgentId: "ruler_belgium",
                    warSupport: 68
                )
            ]
            return (
                countries,
                [
                    DiplomaticBloc(
                        id: "allied_coalition",
                        name: "Allied Coalition",
                        faction: .allies,
                        memberCountryIds: countries.map(\.id)
                    )
                ]
            )
        case .cao:
            return singleCountrySeed(
                faction: .cao,
                countryId: "power_cao",
                blocId: "bloc_cao",
                name: "曹操",
                rulerAgentId: "ruler_cao_cao",
                isPrimaryBelligerent: true,
                warSupport: 78
            )
        case .yuan:
            return singleCountrySeed(
                faction: .yuan,
                countryId: "power_yuan",
                blocId: "bloc_yuan",
                name: "袁绍",
                rulerAgentId: "ruler_yuan_shao",
                isPrimaryBelligerent: true,
                warSupport: 76
            )
        case .liuBei:
            return singleCountrySeed(
                faction: .liuBei,
                countryId: "power_liu_bei",
                blocId: "bloc_liu_bei",
                name: "刘备",
                rulerAgentId: "ruler_liu_bei",
                warSupport: 66
            )
        case .sun:
            return singleCountrySeed(
                faction: .sun,
                countryId: "power_sun",
                blocId: "bloc_sun",
                name: "孙氏",
                rulerAgentId: "ruler_sun",
                warSupport: 70
            )
        case .liuBiao:
            return singleCountrySeed(
                faction: .liuBiao,
                countryId: "power_liu_biao",
                blocId: "bloc_liu_biao",
                name: "刘表",
                rulerAgentId: "ruler_liu_biao",
                warSupport: 54
            )
        case .maTeng:
            return singleCountrySeed(
                faction: .maTeng,
                countryId: "power_ma_teng",
                blocId: "bloc_ma_teng",
                name: "马腾",
                rulerAgentId: "ruler_ma_teng",
                warSupport: 62
            )
        case .han:
            return singleCountrySeed(
                faction: .han,
                countryId: "power_han",
                blocId: "bloc_han",
                name: "汉室",
                rulerAgentId: "ruler_han_court",
                warSupport: 40
            )
        case .neutral:
            return singleCountrySeed(
                faction: .neutral,
                countryId: "power_neutral",
                blocId: "bloc_neutral",
                name: "中立郡县",
                rulerAgentId: "ruler_neutral",
                warSupport: 0
            )
        }
    }

    private static func singleCountrySeed(
        faction: Faction,
        countryId: CountryId,
        blocId: DiplomaticBlocId,
        name: String,
        rulerAgentId: String,
        isPrimaryBelligerent: Bool = false,
        warSupport: Int
    ) -> (countries: [CountryProfile], blocs: [DiplomaticBloc]) {
        let country = CountryProfile(
            id: countryId,
            name: name,
            faction: faction,
            blocId: blocId,
            rulerAgentId: rulerAgentId,
            isPrimaryBelligerent: isPrimaryBelligerent,
            warSupport: warSupport
        )
        let bloc = DiplomaticBloc(id: blocId, name: "\(name)集团", faction: faction, memberCountryIds: [countryId])
        return ([country], [bloc])
    }
}
