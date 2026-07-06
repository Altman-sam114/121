import Foundation

struct StrategistDirectiveAdjustment: Equatable {
    let envelope: DirectiveEnvelope
    let record: StrategistDecisionRecord
}

struct StrategistAgentConfig: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let faction: Faction
    let planningStyle: PlanningStyle

    enum PlanningStyle: String, Codable, Equatable, CaseIterable {
        case decisive
        case balanced
        case cautious

        var displayName: String {
            switch self {
            case .decisive:
                return "决断"
            case .balanced:
                return "持重"
            case .cautious:
                return "谨慎"
            }
        }
    }

    init(id: String, name: String, faction: Faction, planningStyle: PlanningStyle) {
        self.id = id
        self.name = name
        self.faction = faction
        self.planningStyle = planningStyle
    }
}

struct StrategistAgent {
    let config: StrategistAgentConfig

    func plan(
        envelope: DirectiveEnvelope,
        in state: GameState,
        rulerRecord: RulerDecisionRecord?
    ) -> StrategistDirectiveAdjustment {
        let snapshot = StrategistBattlefieldSnapshot(faction: config.faction, state: state)
        let selectedZoneId = chooseSelectedZoneId(
            directives: envelope.directives,
            rulerRecord: rulerRecord,
            snapshot: snapshot
        )
        let directives = envelope.directives.map {
            plan(directive: $0, selectedZoneId: selectedZoneId, snapshot: snapshot, state: state)
        }
        let focusRegionIds = chooseFocusRegionIds(directives: directives, snapshot: snapshot)
        let supportRegionIds = chooseSupportRegionIds(selectedZoneId: selectedZoneId, snapshot: snapshot)
        let record = StrategistDecisionRecord(
            id: "strategist_\(config.id)_turn_\(state.turn)_\(config.faction.rawValue)",
            turn: state.turn,
            faction: config.faction,
            strategistAgentId: config.id,
            selectedFrontZoneId: selectedZoneId,
            focusRegionIds: focusRegionIds,
            supportRegionIds: supportRegionIds,
            rulerPosture: rulerRecord?.posture,
            intent: intent(selectedZoneId: selectedZoneId, focusRegionIds: focusRegionIds, state: state),
            rationale: rationale(
                selectedZoneId: selectedZoneId,
                focusRegionIds: focusRegionIds,
                rulerRecord: rulerRecord,
                snapshot: snapshot,
                state: state
            )
        )
        let adjustedEnvelope = DirectiveEnvelope(
            schemaVersion: envelope.schemaVersion,
            issuerId: envelope.issuerId,
            turn: envelope.turn,
            directives: directives,
            commanderAgentId: envelope.commanderAgentId,
            theaterContext: appendStrategistContext(envelope.theaterContext, record: record)
        )
        return StrategistDirectiveAdjustment(envelope: adjustedEnvelope, record: record)
    }

    private func plan(
        directive: ZoneDirective,
        selectedZoneId: FrontZoneId?,
        snapshot: StrategistBattlefieldSnapshot,
        state: GameState
    ) -> ZoneDirective {
        switch directive.parameters {
        case .attack(let attack):
            let regionCandidates = stableUnique(
                [attack.focusRegionId].compactMap { $0 }
                + attack.weightedRegions
                + (attack.supportRegionIds ?? [])
                + snapshot.enemyRegionIdsByZone[directive.zoneId, default: []]
            )
            let weightedRegions = prioritizedRegions(regionCandidates, snapshot: snapshot)
            let focusRegionId = weightedRegions.first ?? attack.focusRegionId
            let supportRegionIds = stableUnique(
                (attack.supportRegionIds ?? [])
                + snapshot.supportRegionIdsByZone[directive.zoneId, default: []]
            )
            let isSelectedZone = selectedZoneId == directive.zoneId
            return ZoneDirective(
                zoneId: directive.zoneId,
                attack: AttackParameters(
                    targetTheaterId: attack.targetTheaterId,
                    weightedRegions: weightedRegions,
                    intensity: attackIntensity(attack.intensity, isSelectedZone: isSelectedZone),
                    focusRegionId: focusRegionId,
                    supportRegionIds: supportRegionIds,
                    convergenceRegionId: attack.convergenceRegionId ?? focusRegionId,
                    coordinatedZoneIds: attack.coordinatedZoneIds,
                    maxCommittedUnits: attack.maxCommittedUnits,
                    exploitDepth: attack.exploitDepth
                ),
                category: directive.category,
                tactic: directive.tactic,
                commandTarget: focusRegionId.map(DirectiveTarget.region) ?? directive.commandTarget
            )
        case .defend(let defense):
            let zoneStrongpoints = snapshot.supportRegionIdsByZone[directive.zoneId, default: []]
            let strongpoints = prioritizedRegions(
                stableUnique((defense.strongpointRegionIds ?? []) + zoneStrongpoints),
                snapshot: snapshot
            )
            let fallbackRegions = stableUnique((defense.fallbackRegionIds ?? []) + zoneStrongpoints)
            let isSelectedZone = selectedZoneId == directive.zoneId
            return ZoneDirective(
                zoneId: directive.zoneId,
                defense: DefenseParameters(
                    targetReserves: isSelectedZone ? max(1, defense.targetReserves) : defense.targetReserves,
                    stance: defense.stance,
                    fallbackRegionIds: fallbackRegions,
                    counterattackRegionIds: defense.counterattackRegionIds,
                    strongpointRegionIds: strongpoints,
                    maxFrontCommitment: defense.maxFrontCommitment
                ),
                category: directive.category,
                tactic: directive.tactic,
                commandTarget: strongpoints.first.map(DirectiveTarget.region) ?? directive.commandTarget
            )
        }
    }

    private func chooseSelectedZoneId(
        directives: [ZoneDirective],
        rulerRecord: RulerDecisionRecord?,
        snapshot: StrategistBattlefieldSnapshot
    ) -> FrontZoneId? {
        let directiveZoneIds = Set(directives.map(\.zoneId))
        if let preferred = rulerRecord?.preferredFrontZoneId, directiveZoneIds.contains(preferred) {
            return preferred
        }
        return snapshot.zoneScores
            .filter { directiveZoneIds.contains($0.key) }
            .sorted {
                if $0.value == $1.value {
                    return $0.key.rawValue < $1.key.rawValue
                }
                return $0.value > $1.value
            }
            .first?.key
    }

    private func chooseFocusRegionIds(
        directives: [ZoneDirective],
        snapshot: StrategistBattlefieldSnapshot
    ) -> [RegionId] {
        let directed = directives.flatMap(\.targetRegionIds)
        if directed.isEmpty {
            return snapshot.regionScores
                .sorted {
                    if $0.value == $1.value {
                        return $0.key.rawValue < $1.key.rawValue
                    }
                    return $0.value > $1.value
                }
                .prefix(4)
                .map(\.key)
        }
        return prioritizedRegions(stableUnique(directed), snapshot: snapshot).prefix(4).map { $0 }
    }

    private func chooseSupportRegionIds(
        selectedZoneId: FrontZoneId?,
        snapshot: StrategistBattlefieldSnapshot
    ) -> [RegionId] {
        guard let selectedZoneId else {
            return []
        }
        return Array(snapshot.supportRegionIdsByZone[selectedZoneId, default: []].prefix(4))
    }

    private func attackIntensity(_ current: AttackIntensity, isSelectedZone: Bool) -> AttackIntensity {
        guard isSelectedZone else {
            return current == .allOut && config.planningStyle == .cautious ? .limitedCounter : current
        }
        switch config.planningStyle {
        case .decisive:
            return current == .infiltration ? .limitedCounter : current
        case .balanced:
            return current
        case .cautious:
            return current == .allOut ? .limitedCounter : current
        }
    }

    private func prioritizedRegions(
        _ regionIds: [RegionId],
        snapshot: StrategistBattlefieldSnapshot
    ) -> [RegionId] {
        stableUnique(regionIds).sorted {
            let lhs = snapshot.regionScores[$0, default: 0]
            let rhs = snapshot.regionScores[$1, default: 0]
            return lhs == rhs ? $0.rawValue < $1.rawValue : lhs > rhs
        }
    }

    private func intent(selectedZoneId: FrontZoneId?, focusRegionIds: [RegionId], state: GameState) -> String {
        let zone = frontZoneDisplayName(for: selectedZoneId, in: state)
        let regions = regionDisplayList(focusRegionIds, in: state)
        return "军师以\(config.planningStyle.displayName)风格编排防区 \(zone)，目标 \(regions.isEmpty ? "无" : regions)。"
    }

    private func rationale(
        selectedZoneId: FrontZoneId?,
        focusRegionIds: [RegionId],
        rulerRecord: RulerDecisionRecord?,
        snapshot: StrategistBattlefieldSnapshot,
        state: GameState
    ) -> String {
        let posture = rulerRecord?.posture.displayName ?? "未定"
        let zoneText = frontZoneDisplayName(for: selectedZoneId, in: state, emptyText: "无主防区")
        let score = selectedZoneId.map { snapshot.zoneScores[$0, default: 0] } ?? 0
        let focusText = regionDisplayList(focusRegionIds, in: state)
        return "承接君主\(posture)姿态，选择 \(zoneText)（评分 \(score)）并聚焦 \(focusText.isEmpty ? "暂无目标" : focusText)。"
    }

    private func frontZoneDisplayName(
        for zoneId: FrontZoneId?,
        in state: GameState,
        emptyText: String = "无"
    ) -> String {
        guard let zoneId else {
            return emptyText
        }
        guard let zone = state.warDeploymentState.frontZones[zoneId] else {
            return "未知防区"
        }
        let name = zone.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty && name != zone.id.rawValue {
            return name
        }
        let regions = regionDisplayList(Array(zone.regionIds.prefix(2)), in: state)
        return regions.isEmpty ? "\(zone.faction.shortDisplayName)防区" : "\(zone.faction.shortDisplayName)防区：\(regions)"
    }

    private func regionDisplayList(_ regionIds: [RegionId], in state: GameState) -> String {
        regionIds
            .map { state.map.region(id: $0)?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
            .map { $0.isEmpty ? "未知郡县" : $0 }
            .joined(separator: "、")
    }

    private func appendStrategistContext(_ context: String?, record: StrategistDecisionRecord) -> String {
        let strategistContext = "军师 \(record.strategistAgentId)：\(record.intent)"
        guard let context, !context.isEmpty else {
            return strategistContext
        }
        return "\(context) \(strategistContext)"
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

extension StrategistAgent {
    static func automatic(for faction: Faction, in state: GameState) -> StrategistAgent {
        StrategistAgent(config: .automatic(for: faction, state: state))
    }
}

extension StrategistAgentConfig {
    static func automatic(for faction: Faction, state: GameState) -> StrategistAgentConfig {
        switch faction {
        case .germany, .cao, .maTeng:
            return StrategistAgentConfig(
                id: "strategist_\(faction.rawValue)",
                name: "\(faction.displayName)军师",
                faction: faction,
                planningStyle: .decisive
            )
        case .allies, .yuan, .sun:
            return StrategistAgentConfig(
                id: "strategist_\(faction.rawValue)",
                name: "\(faction.displayName)军师",
                faction: faction,
                planningStyle: .balanced
            )
        case .liuBei, .liuBiao, .han, .neutral:
            return StrategistAgentConfig(
                id: "strategist_\(faction.rawValue)",
                name: "\(faction.displayName)军师",
                faction: faction,
                planningStyle: .cautious
            )
        }
    }
}

private struct StrategistBattlefieldSnapshot {
    let zoneScores: [FrontZoneId: Int]
    let regionScores: [RegionId: Int]
    let enemyRegionIdsByZone: [FrontZoneId: [RegionId]]
    let supportRegionIdsByZone: [FrontZoneId: [RegionId]]

    init(faction: Faction, state: GameState) {
        var zoneScores: [FrontZoneId: Int] = [:]
        var regionScores: [RegionId: Int] = [:]
        var enemyRegionsByZone: [FrontZoneId: [RegionId]] = [:]
        var supportRegionsByZone: [FrontZoneId: [RegionId]] = [:]

        let zones = state.warDeploymentState.frontZones.values
            .filter { $0.faction == faction && !$0.frontSegments.isEmpty }
        for zone in zones {
            let friendlyStrength = Self.strength(
                for: zone.unitsFront + zone.unitsDepth,
                faction: faction,
                state: state
            )
            let zonePressure = zone.pressure + zone.frontSegments.count
            zoneScores[zone.id] = friendlyStrength + zonePressure * 3
            supportRegionsByZone[zone.id] = Self.stableUnique(
                zone.frontSegments.map(\.regionId) + zone.regionIds
            )

            var enemyRegionIds: [RegionId] = []
            for segment in zone.frontSegments {
                regionScores[segment.regionId, default: 0] += zonePressure + segment.strength
                if segment.isEncircled {
                    regionScores[segment.regionId, default: 0] += 8
                }
                if state.map.regions[segment.regionId]?.controller != faction {
                    enemyRegionIds.append(segment.regionId)
                    regionScores[segment.regionId, default: 0] += 6
                }
                enemyRegionIds.append(contentsOf: Self.enemyNeighborRegions(segment: segment, zone: zone, state: state))
            }
            enemyRegionsByZone[zone.id] = Self.stableUnique(enemyRegionIds)
        }

        self.zoneScores = zoneScores
        self.regionScores = regionScores
        self.enemyRegionIdsByZone = enemyRegionsByZone
        self.supportRegionIdsByZone = supportRegionsByZone
    }

    private static func strength(for unitIds: [String], faction: Faction, state: GameState) -> Int {
        let ids = Set(unitIds)
        return state.divisions
            .filter { ids.contains($0.id) && $0.faction == faction && !$0.isDestroyed }
            .reduce(0) { $0 + max(1, $1.strength) + max(1, $1.attack) }
    }

    private static func enemyNeighborRegions(
        segment: FrontZoneSegment,
        zone: FrontZone,
        state: GameState
    ) -> [RegionId] {
        guard let sourceRegion = state.map.region(id: segment.regionId) else {
            return []
        }
        var regionIds: [RegionId] = []
        for hex in sourceRegion.displayHexes {
            for neighbor in hex.neighbors {
                guard let regionId = state.map.region(for: neighbor),
                      regionId != segment.regionId,
                      state.warDeploymentState.zoneId(for: neighbor, map: state.map) == segment.neighborEnemyZone else {
                    continue
                }
                if state.map.regions[regionId]?.controller != zone.faction ||
                    state.divisions.contains(where: {
                        state.diplomacyState.isHostile(between: $0.faction, and: zone.faction) &&
                            !$0.isDestroyed &&
                            $0.location(in: state.map) == regionId
                    }) {
                    regionIds.append(regionId)
                }
            }
        }
        return stableUnique(regionIds)
    }

    private static func stableUnique<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        var result: [T] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }
}
