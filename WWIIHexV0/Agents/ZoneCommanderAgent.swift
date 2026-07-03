import Foundation

struct ZoneCommanderAgentConfig: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let faction: Faction
    let assignedZoneId: FrontZoneId
    let skills: [String]
    let commandStyle: CommandStyle

    enum CommandStyle: String, Codable, Equatable {
        case aggressive
        case balanced
        case cautious
    }
}

struct TacticConditionChecker {
    func canUseTactic(
        _ tactic: TacticName,
        commander: ZoneCommanderAgentConfig?,
        zone: FrontZone,
        state: GameState
    ) -> Bool {
        true
    }
}

struct BinaryTacticClassifier {
    let attackThreshold: Double

    init(attackThreshold: Double = MockAICommanderConfig.attackThreshold) {
        self.attackThreshold = attackThreshold
    }

    struct Classification: Equatable {
        let category: CommandCategory
        let tactic: TacticName
        let confidence: Double
        let reason: String
    }

    func classify(
        friendlyStrength: Int,
        visibleEnemyStrength: Int,
        hasContestedForwardPresence: Bool,
        hasStaticDefense: Bool,
        config: ZoneCommanderAgentConfig
    ) -> Classification {
        let ratio = visibleEnemyStrength == 0
            ? Double(friendlyStrength)
            : Double(friendlyStrength) / Double(visibleEnemyStrength)

        let styleBoost: Double
        switch config.commandStyle {
        case .aggressive:
            styleBoost = 0.15
        case .balanced:
            styleBoost = 0
        case .cautious:
            styleBoost = -0.15
        }

        let adjustedRatio = ratio + styleBoost
        let shouldAttack = adjustedRatio >= attackThreshold
            || hasContestedForwardPresence
            || hasStaticDefense

        if shouldAttack {
            return Classification(
                category: .offense,
                tactic: .standardAttack,
                confidence: min(1, adjustedRatio / 2),
                reason: hasContestedForwardPresence ? "forward_presence" : "strength_ratio"
            )
        }

        return Classification(
            category: .defense,
            tactic: .holdPosition,
            confidence: min(1, 1 / max(0.01, adjustedRatio)),
            reason: "outnumbered"
        )
    }
}

protocol ZoneCommanderProviding {
    var config: ZoneCommanderAgentConfig { get }
    func makeDirective(for zone: FrontZone, in state: GameState) -> ZoneDirective?
}

struct ZoneCommanderAgent: ZoneCommanderProviding {
    let config: ZoneCommanderAgentConfig
    let conditionChecker: TacticConditionChecker
    let classifier: BinaryTacticClassifier

    init(
        config: ZoneCommanderAgentConfig,
        conditionChecker: TacticConditionChecker = TacticConditionChecker(),
        classifier: BinaryTacticClassifier = BinaryTacticClassifier()
    ) {
        self.config = config
        self.conditionChecker = conditionChecker
        self.classifier = classifier
    }

    func makeDirective(for zone: FrontZone, in state: GameState) -> ZoneDirective? {
        guard !zone.frontSegments.isEmpty else {
            return nil
        }

        let visibleEnemy = visibleEnemyStrengthByRegion(zone: zone, state: state)
        let classification = classifier.classify(
            friendlyStrength: friendlyFrontStrength(zone: zone, state: state),
            visibleEnemyStrength: visibleEnemy.values.reduce(0, +),
            hasContestedForwardPresence: hasContestedForwardPresence(zone: zone, state: state),
            hasStaticDefense: hasRecentStaticDefense(zone: zone, state: state),
            config: config
        )

        guard conditionChecker.canUseTactic(classification.tactic, commander: config, zone: zone, state: state) else {
            return makeDefenseDirective(tactic: .holdPosition, zone: zone)
        }

        switch classification.category {
        case .offense:
            return makeOffenseDirective(
                tactic: classification.tactic,
                zone: zone,
                visibleEnemy: visibleEnemy,
                state: state
            )
        case .defense:
            return makeDefenseDirective(tactic: classification.tactic, zone: zone)
        }
    }

    private func makeOffenseDirective(
        tactic: TacticName,
        zone: FrontZone,
        visibleEnemy: [RegionId: Int],
        state: GameState
    ) -> ZoneDirective? {
        guard let targetZoneId = bestTargetZoneId(zone: zone, visibleEnemy: visibleEnemy, state: state) else {
            return makeDefenseDirective(tactic: .holdPosition, zone: zone)
        }

        let weightedRegions = visibleEnemy
            .sorted {
                if $0.value == $1.value {
                    return $0.key.rawValue < $1.key.rawValue
                }
                return $0.value > $1.value
            }
            .map(\.key)

        return ZoneDirective(
            zoneId: zone.id,
            attack: AttackParameters(
                targetTheaterId: TheaterId(targetZoneId.rawValue),
                weightedRegions: weightedRegions,
                intensity: .limitedCounter
            ),
            category: tactic.category,
            tactic: tactic,
            commandTarget: .theater(TheaterId(targetZoneId.rawValue))
        )
    }

    private func makeDefenseDirective(tactic: TacticName, zone: FrontZone) -> ZoneDirective {
        ZoneDirective(
            zoneId: zone.id,
            defense: DefenseParameters(targetReserves: 1, stance: .holdLine),
            category: tactic.category,
            tactic: tactic,
            commandTarget: .theater(TheaterId(zone.id.rawValue))
        )
    }

    private func friendlyFrontStrength(zone: FrontZone, state: GameState) -> Int {
        let frontUnitIds = Set(zone.unitsFront + zone.frontSegments.flatMap(\.assignedFrontUnitIds))
        return state.divisions
            .filter { frontUnitIds.contains($0.id) && $0.faction == zone.faction && !$0.isDestroyed }
            .reduce(0) { $0 + combatPower($1, mode: .friendly) }
    }

    private func visibleEnemyStrengthByRegion(zone: FrontZone, state: GameState) -> [RegionId: Int] {
        let visibleEnemyRegions = Set(visibleEnemyRegionIds(zone: zone, state: state))
        var strengthByRegion: [RegionId: Int] = [:]

        for division in state.divisions where division.faction != zone.faction && !division.isDestroyed {
            guard let regionId = division.location(in: state.map),
                  visibleEnemyRegions.contains(regionId) else {
                continue
            }
            strengthByRegion[regionId, default: 0] += combatPower(division, mode: .enemy)
        }

        return strengthByRegion
    }

    private func visibleEnemyRegionIds(zone: FrontZone, state: GameState) -> [RegionId] {
        var regionIds: [RegionId] = []
        for segment in zone.frontSegments.sorted(by: { $0.regionId.rawValue < $1.regionId.rawValue }) {
            if state.map.regions[segment.regionId]?.controller != zone.faction ||
                hasEnemyPresence(in: segment.regionId, zone: zone, state: state) {
                regionIds.append(segment.regionId)
            }

            for neighborId in state.map.neighbors(of: segment.regionId).sorted(by: { $0.rawValue < $1.rawValue }) {
                guard dynamicRegionTouchesZone(
                    sourceRegionId: segment.regionId,
                    neighborRegionId: neighborId,
                    targetZoneId: segment.neighborEnemyZone,
                    state: state
                ),
                    (state.map.regions[neighborId]?.controller != zone.faction ||
                     hasEnemyPresence(in: neighborId, zone: zone, state: state)) else {
                    continue
                }
                regionIds.append(neighborId)
            }
        }
        return stableUnique(regionIds)
    }

    private func bestTargetZoneId(
        zone: FrontZone,
        visibleEnemy: [RegionId: Int],
        state: GameState
    ) -> FrontZoneId? {
        var scoreByZone: [FrontZoneId: Int] = [:]

        for (regionId, strength) in visibleEnemy {
            guard let enemyZoneId = dominantEnemyZoneId(for: regionId, zone: zone, state: state) else {
                continue
            }
            scoreByZone[enemyZoneId, default: 0] += strength
        }

        if let best = scoreByZone.sorted(by: {
            if $0.value == $1.value {
                return $0.key.rawValue < $1.key.rawValue
            }
            return $0.value > $1.value
        }).first?.key {
            return best
        }

        return zone.frontSegments.map(\.neighborEnemyZone).sorted { $0.rawValue < $1.rawValue }.first
    }

    private func dominantEnemyZoneId(
        for regionId: RegionId,
        zone: FrontZone,
        state: GameState
    ) -> FrontZoneId? {
        guard let region = state.map.region(id: regionId) else {
            return state.warDeploymentState.regionToFrontZone[regionId]
        }

        var counts: [FrontZoneId: Int] = [:]
        for hex in region.displayHexes {
            guard let zoneId = state.warDeploymentState.zoneId(for: hex, map: state.map),
                  zoneId != zone.id else {
                continue
            }
            counts[zoneId, default: 0] += 1
        }

        return counts.max {
            $0.value == $1.value ? $0.key.rawValue > $1.key.rawValue : $0.value < $1.value
        }?.key ?? state.warDeploymentState.regionToFrontZone[regionId]
    }

    private func dynamicRegionTouchesZone(
        sourceRegionId: RegionId,
        neighborRegionId: RegionId,
        targetZoneId: FrontZoneId,
        state: GameState
    ) -> Bool {
        guard let sourceRegion = state.map.region(id: sourceRegionId),
              let neighborRegion = state.map.region(id: neighborRegionId) else {
            return false
        }
        let neighborHexes = Set(neighborRegion.displayHexes)
        for hex in sourceRegion.displayHexes {
            guard state.warDeploymentState.zoneId(for: hex, map: state.map) != targetZoneId else {
                continue
            }
            for neighborHex in hex.neighbors where neighborHexes.contains(neighborHex) {
                if state.warDeploymentState.zoneId(for: neighborHex, map: state.map) == targetZoneId {
                    return true
                }
            }
        }
        return false
    }

    private func hasEnemyPresence(
        in regionId: RegionId,
        zone: FrontZone,
        state: GameState
    ) -> Bool {
        state.divisions.contains { division in
            guard division.faction != zone.faction,
                  !division.isDestroyed else {
                return false
            }
            return division.location(in: state.map) == regionId
        }
    }

    private func hasContestedForwardPresence(zone: FrontZone, state: GameState) -> Bool {
        let zoneUnitIds = Set(zone.unitsFront + zone.unitsDepth + zone.unitsGarrison)
        return state.divisions.contains { division in
            guard zoneUnitIds.contains(division.id),
                  division.faction == zone.faction,
                  !division.isDestroyed,
                  let regionId = division.location(in: state.map),
                  let region = state.map.regions[regionId] else {
                return false
            }
            return region.controller != zone.faction
        }
    }

    private func hasRecentStaticDefense(zone: FrontZone, state: GameState) -> Bool {
        guard let previous = state.warDirectiveRecords
            .reversed()
            .first(where: { $0.zoneId == zone.id && $0.faction == zone.faction }) else {
            return false
        }

        guard previous.directiveType == .defend,
              !previous.commandResults.isEmpty else {
            return false
        }

        return previous.commandResults.allSatisfy { summary in
            summary.commandDisplayName?.hasPrefix("Hold") == true
        }
    }

    private enum StrengthMode {
        case friendly
        case enemy
    }

    private func combatPower(_ division: Division, mode: StrengthMode) -> Int {
        switch mode {
        case .friendly:
            return max(1, division.strength) + max(1, division.attack)
        case .enemy:
            return max(1, division.strength) + max(1, division.defense)
        }
    }

    private func stableUnique<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        var result: [T] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }
}

struct TheaterCommanderPool {
    private let commanders: [FrontZoneId: any ZoneCommanderProviding]

    init(commanders: [any ZoneCommanderProviding]) {
        self.commanders = Dictionary(
            uniqueKeysWithValues: commanders.map { ($0.config.assignedZoneId, $0) }
        )
    }

    func envelope(for faction: Faction, in state: GameState, issuerId: String = "theater_pool") -> DirectiveEnvelope {
        let directives = state.warDeploymentState.frontZones.values
            .filter { $0.faction == faction && !$0.frontSegments.isEmpty }
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .compactMap { zone -> ZoneDirective? in
                let commander = commanders[zone.id] ?? ZoneCommanderAgent(config: Self.defaultConfig(for: zone))
                return commander.makeDirective(for: zone, in: state)
            }

        return DirectiveEnvelope(
            issuerId: issuerId,
            turn: state.turn,
            directives: directives,
            commanderAgentId: issuerId,
            theaterContext: contextSummary(for: faction, directives: directives)
        )
    }

    static func automatic(for state: GameState) -> TheaterCommanderPool {
        TheaterCommanderPool(
            commanders: state.warDeploymentState.frontZones.values
                .sorted { $0.id.rawValue < $1.id.rawValue }
                .map { ZoneCommanderAgent(config: defaultConfig(for: $0)) }
        )
    }

    static func defaultConfig(for zone: FrontZone) -> ZoneCommanderAgentConfig {
        let style: ZoneCommanderAgentConfig.CommandStyle = zone.faction == .germany ? .aggressive : .balanced
        let factionName = zone.faction == .germany ? "German" : "Allied"
        return ZoneCommanderAgentConfig(
            id: "auto_\(zone.id.rawValue)",
            name: "\(factionName) Commander (\(zone.id.rawValue))",
            faction: zone.faction,
            assignedZoneId: zone.id,
            skills: [],
            commandStyle: style
        )
    }

    private func contextSummary(for faction: Faction, directives: [ZoneDirective]) -> String {
        "\(faction.displayName): \(directives.count) zone directive(s)."
    }
}
