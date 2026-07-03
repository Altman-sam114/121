import Foundation

struct WarCommandExecutionResult: Equatable {
    let directive: ZoneDirective
    let generatedCommands: [Command]
    let commandResults: [CommandResult]
    let finalState: GameState

    var succeeded: Bool {
        !generatedCommands.isEmpty && commandResults.allSatisfy(\.succeeded)
    }
}

struct WarCommandExecutor {
    let commandHandler: GameCommandHandling
    private let occupationRules = OccupationRules()

    init(commandHandler: GameCommandHandling = RuleEngine()) {
        self.commandHandler = commandHandler
    }

    func execute(_ directive: ZoneDirective, in state: GameState) -> WarCommandExecutionResult {
        if let tactic = directive.tactic {
            return executeTactic(directive, tactic: tactic, in: state)
        }

        switch directive.parameters {
        case .defend(let parameters):
            return executeDefense(directive, parameters: parameters, in: state)
        case .attack(let parameters):
            return executeAttack(directive, parameters: parameters, in: state)
        }
    }

    private func executeTactic(
        _ directive: ZoneDirective,
        tactic: TacticName,
        in state: GameState
    ) -> WarCommandExecutionResult {
        switch tactic {
        case .standardAttack:
            guard case .attack(let parameters) = directive.parameters else {
                return emptyResult(directive: directive, state: state)
            }
            return executeAttack(directive, parameters: parameters, in: state)
        case .holdPosition:
            guard case .defend(let parameters) = directive.parameters else {
                return emptyResult(directive: directive, state: state)
            }
            return executeDefense(directive, parameters: parameters, in: state)
        }
    }

    private func emptyResult(directive: ZoneDirective, state: GameState) -> WarCommandExecutionResult {
        WarCommandExecutionResult(
            directive: directive,
            generatedCommands: [],
            commandResults: [],
            finalState: state
        )
    }

    private func executeDefense(
        _ directive: ZoneDirective,
        parameters: DefenseParameters,
        in state: GameState
    ) -> WarCommandExecutionResult {
        guard let zone = state.warDeploymentState.frontZones[directive.zoneId],
              !zone.frontSegments.isEmpty else {
            return WarCommandExecutionResult(
                directive: directive,
                generatedCommands: [],
                commandResults: [],
                finalState: state
            )
        }

        var nextState = state
        var commands: [Command] = []
        var results: [CommandResult] = []
        let relatedRecordId = "war_directive_\(directive.zoneId.rawValue)_\(directive.type.rawValue)"
        var segmentLoads = Dictionary(
            uniqueKeysWithValues: zone.frontSegments.map {
                ($0.regionId, $0.assignedFrontUnitIds.count)
            }
        )
        let reserveCount = min(parameters.targetReserves, zone.unitsDepth.count)
        let depthFillers = Array(zone.unitsDepth.sorted().dropFirst(reserveCount))
        let unitIds = stableUnique(zone.unitsFront + depthFillers)

        for unitId in unitIds {
            guard let division = nextState.division(id: unitId),
                  division.faction == zone.faction,
                  division.canAct else {
                continue
            }

            guard let targetRegionId = lightestFrontRegion(in: zone, loads: segmentLoads) else {
                continue
            }

            let command: Command
            if division.location(in: nextState.map) == targetRegionId {
                command = parameters.stance == .holdLine
                    ? .hold(divisionId: division.id)
                    : .allowRetreat(divisionId: division.id)
            } else if let destination = tacticalDestination(
                in: targetRegionId,
                for: division,
                state: nextState
            ) {
                command = .move(divisionId: division.id, destination: destination)
            } else {
                command = parameters.stance == .holdLine
                    ? .hold(divisionId: division.id)
                    : .allowRetreat(divisionId: division.id)
            }

            run(
                command,
                fallback: .hold(divisionId: division.id),
                commands: &commands,
                results: &results,
                state: &nextState,
                relatedRecordId: relatedRecordId
            )
            segmentLoads[targetRegionId, default: 0] += 1
        }

        return WarCommandExecutionResult(
            directive: directive,
            generatedCommands: commands,
            commandResults: results,
            finalState: nextState
        )
    }

    private func executeAttack(
        _ directive: ZoneDirective,
        parameters: AttackParameters,
        in state: GameState
    ) -> WarCommandExecutionResult {
        guard let zone = state.warDeploymentState.frontZones[directive.zoneId] else {
            return WarCommandExecutionResult(
                directive: directive,
                generatedCommands: [],
                commandResults: [],
                finalState: state
            )
        }

        let targetZoneId = FrontZoneId(parameters.targetTheaterId.rawValue)
        let sourceSegments = zone.frontSegments.filter { $0.neighborEnemyZone == targetZoneId }
        let segments = sourceSegments.isEmpty ? zone.frontSegments : sourceSegments
        let attackingUnitIds = stableUnique(zone.unitsFront + (zone.unitsFront.isEmpty ? zone.unitsDepth : []))

        var nextState = state
        var commands: [Command] = []
        var results: [CommandResult] = []
        let relatedRecordId = "war_directive_\(directive.zoneId.rawValue)_\(directive.type.rawValue)"

        for unitId in attackingUnitIds {
            guard let division = nextState.division(id: unitId),
                  division.faction == zone.faction,
                  division.canAct else {
                continue
            }

            guard let targetRegionId = targetEnemyRegion(
                for: division,
                zone: zone,
                targetZoneId: targetZoneId,
                segments: segments,
                weightedRegions: parameters.weightedRegions,
                state: nextState
            ) else {
                continue
            }

            let command: Command
            if let target = visibleEnemyDivision(
                in: [targetRegionId],
                for: division,
                zone: zone,
                state: nextState
            ) {
                command = .attack(attackerId: division.id, targetId: target.id)
            } else if let destination = tacticalDestination(
                in: targetRegionId,
                for: division,
                state: nextState
            ) {
                command = .move(divisionId: division.id, destination: destination)
            } else {
                command = .hold(divisionId: division.id)
            }

            run(
                command,
                fallback: .hold(divisionId: division.id),
                commands: &commands,
                results: &results,
                state: &nextState,
                relatedRecordId: relatedRecordId
            )
        }

        return WarCommandExecutionResult(
            directive: directive,
            generatedCommands: commands,
            commandResults: results,
            finalState: nextState
        )
    }

    private func targetEnemyRegion(
        for division: Division,
        zone: FrontZone,
        targetZoneId: FrontZoneId,
        segments: [FrontZoneSegment],
        weightedRegions: [RegionId],
        state: GameState
    ) -> RegionId? {
        let adjacentEnemyRegions = enemyRegions(
            for: segments,
            targetZoneId: targetZoneId,
            zone: zone,
            state: state
        )
        let weighted = weightedRegions.filter { adjacentEnemyRegions.contains($0) }
        let candidates = stableUnique(weighted + adjacentEnemyRegions)

        if let target = visibleEnemyDivision(
            in: candidates,
            for: division,
            zone: zone,
            state: state
        ) {
            return target.location(in: state.map)
        }

        return candidates.first
    }

    private func enemyRegions(
        for segments: [FrontZoneSegment],
        targetZoneId: FrontZoneId,
        zone: FrontZone,
        state: GameState
    ) -> [RegionId] {
        var regionIds: [RegionId] = []
        for segment in segments.sorted(by: { $0.regionId.rawValue < $1.regionId.rawValue }) {
            if state.map.regions[segment.regionId]?.controller != zone.faction ||
                hasEnemyPresence(in: segment.regionId, zone: zone, state: state) {
                regionIds.append(segment.regionId)
            }
            let neighbors = state.map.neighbors(of: segment.regionId).filter { neighborId in
                guard dynamicRegionTouchesZone(
                    sourceRegionId: segment.regionId,
                    neighborRegionId: neighborId,
                    targetZoneId: targetZoneId,
                    state: state
                ),
                    (state.map.regions[neighborId]?.controller != zone.faction ||
                     hasEnemyPresence(in: neighborId, zone: zone, state: state)) else {
                    return false
                }
                return true
            }
            regionIds.append(contentsOf: neighbors.sorted { $0.rawValue < $1.rawValue })
        }
        return stableUnique(regionIds)
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

    private func visibleEnemyDivision(
        in regionIds: [RegionId],
        for division: Division,
        zone: FrontZone,
        state: GameState
    ) -> Division? {
        let regionSet = Set(regionIds)
        return state.divisions
            .filter { target in
                guard target.faction != zone.faction,
                      let targetRegion = target.location(in: state.map),
                      regionSet.contains(targetRegion) else {
                    return false
                }
                return division.coord.distance(to: target.coord) <= division.range
            }
            .sorted {
                if $0.strength == $1.strength {
                    return $0.id < $1.id
                }
                return $0.strength < $1.strength
            }
            .first
    }

    private func tacticalDestination(
        in regionId: RegionId,
        for division: Division,
        state: GameState
    ) -> HexCoord? {
        guard let region = state.map.region(id: regionId) else {
            return nil
        }

        let regionTargets = stableUnique([region.representativeHex] + region.displayHexes)
        let candidates = regionTargets
            .filter { state.map.tile(at: $0)?.isPassable == true }
            .filter { hex in
                guard let occupying = state.division(at: hex) else {
                    return true
                }
                return occupying.id == division.id
            }
            .sorted {
                let lhsIsCurrent = $0 == division.coord
                let rhsIsCurrent = $1 == division.coord
                if lhsIsCurrent != rhsIsCurrent {
                    return !lhsIsCurrent
                }
                let lhsEnemyControlled = state.map.tile(at: $0)?.controller == division.faction.opponent
                let rhsEnemyControlled = state.map.tile(at: $1)?.controller == division.faction.opponent
                if lhsEnemyControlled != rhsEnemyControlled {
                    return lhsEnemyControlled
                }
                let lhsDistance = division.coord.distance(to: $0)
                let rhsDistance = division.coord.distance(to: $1)
                if lhsDistance == rhsDistance {
                    if $0.q == $1.q {
                        return $0.r < $1.r
                    }
                    return $0.q < $1.q
                }
                return lhsDistance < rhsDistance
            }

        if let destination = candidates.first(where: { $0 != division.coord && division.coord.distance(to: $0) <= division.movement }) {
            return destination
        }

        if let current = candidates.first(where: { $0 == division.coord && state.map.tile(at: $0)?.controller != division.faction }) {
            return current
        }

        return approachDestination(toward: regionTargets, for: division, state: state)
    }

    private func approachDestination(
        toward targets: [HexCoord],
        for division: Division,
        state: GameState
    ) -> HexCoord? {
        let movementRange = MovementRules().movementRange(for: division, in: state)
        return movementRange
            .filter { $0 != division.coord }
            .filter { state.division(at: $0) == nil }
            .sorted {
                let lhsDistance = nearestDistance(from: $0, to: targets)
                let rhsDistance = nearestDistance(from: $1, to: targets)
                if lhsDistance == rhsDistance {
                    let lhsEnemyControlled = state.map.tile(at: $0)?.controller == division.faction.opponent
                    let rhsEnemyControlled = state.map.tile(at: $1)?.controller == division.faction.opponent
                    if lhsEnemyControlled != rhsEnemyControlled {
                        return lhsEnemyControlled
                    }
                    if $0.q == $1.q {
                        return $0.r < $1.r
                    }
                    return $0.q < $1.q
                }
                return lhsDistance < rhsDistance
            }
            .first
    }

    private func nearestDistance(from coord: HexCoord, to targets: [HexCoord]) -> Int {
        targets.map { coord.distance(to: $0) }.min() ?? Int.max
    }

    private func lightestFrontRegion(in zone: FrontZone, loads: [RegionId: Int]) -> RegionId? {
        zone.frontSegments
            .map(\.regionId)
            .sorted {
                let lhsLoad = loads[$0, default: 0]
                let rhsLoad = loads[$1, default: 0]
                if lhsLoad == rhsLoad {
                    return $0.rawValue < $1.rawValue
                }
                return lhsLoad < rhsLoad
            }
            .first
    }

    private func run(
        _ command: Command,
        fallback: Command,
        commands: inout [Command],
        results: inout [CommandResult],
        state: inout GameState,
        relatedRecordId: String?
    ) {
        let actingDivisionId = actingDivisionId(for: command)
        let sourceZoneId = actingDivisionId
            .flatMap { logicalZoneId(for: $0, in: state.warDeploymentState) }
            ?? actingDivisionId
                .flatMap { state.division(id: $0) }
                .flatMap { $0.location(in: state.map) }
                .flatMap { state.warDeploymentState.regionToFrontZone[$0] }
        let beforeControllers = state.map.regions.mapValues(\.controller)
        let originalValidation = CommandValidator().validate(command, in: state)
        let result = commandHandler.execute(command, in: state)
        commands.append(command)
        results.append(result)

        if !result.succeeded {
            let rejectionReasons = result.validation.errors.map(\.rawValue).joined(separator: ", ")
            state.appendEvent(
                "Directive command rejected: \(rejectionReasons) for \(command.displayName).",
                category: .frontChange,
                relatedRecordId: relatedRecordId
            )
            let fallbackValidation = CommandValidator().validate(fallback, in: state)
            if !originalValidation.isValid,
               fallbackValidation.isValid,
               fallback != command {
                let fallbackResult = commandHandler.execute(fallback, in: state)
                commands.append(fallback)
                results.append(fallbackResult)
                state = fallbackResult.state
            }
            return
        }

        state = result.state
        let affectedRegionIds = affectedRegionIds(for: command, state: state)
        let occupiedRegionIds = applyDirectiveOccupation(command: command, state: &state)
        let dynamicAdvancedRegionIds = stableUnique((affectedRegionIds + occupiedRegionIds).compactMap { regionId in
            applyStrategicAdvance(
                regionId: regionId,
                hex: moveDestination(for: command),
                sourceZoneId: sourceZoneId,
                command: command,
                state: &state,
                relatedRecordId: relatedRecordId
            )
        })
        let syncResult = StrategicStateSynchronizer().synchronizeAfterOccupationChange(
            in: &state,
            affectedRegionIds: stableUnique(affectedRegionIds + occupiedRegionIds + dynamicAdvancedRegionIds),
            relatedRecordId: relatedRecordId,
            emitRegionOwnerEvents: false
        )
        let changedRegionIds = stableUnique(
            syncResult.changedRegionIds + controllerChanges(from: beforeControllers, to: state.map)
        )
        for regionId in changedRegionIds {
            guard let region = state.map.region(id: regionId) else {
                continue
            }
            state.appendEvent(
                "Region \(regionId.rawValue) controller changed to \(region.controller.displayName) via \(command.displayName).",
                category: .regionOwnerChange,
                relatedRecordId: relatedRecordId
            )
        }
        if !syncResult.affectedRegionIds.isEmpty {
            state.theaterState = TheaterSystem().updateTheaters(
                state: state.theaterState,
                map: state.map,
                divisions: state.divisions,
                turn: state.turn,
                force: true
            )
            state.frontLineState = FrontLineManager().update(
                state: state.frontLineState,
                map: state.map,
                theaterState: state.theaterState,
                divisions: state.divisions,
                turn: state.turn,
                events: syncResult.affectedRegionIds.map { regionId in
                    changedRegionIds.contains(regionId)
                        ? FrontLineEvent.regionControllerChanged(regionId)
                        : FrontLineEvent.occupationChanged(regionId)
                }
            )
            let deploymentEvents = syncResult.affectedRegionIds.map(WarDeploymentEvent.regionControllerChanged)
                + (sourceZoneId.map { [WarDeploymentEvent.frontZoneChanged($0)] } ?? [])
            state.warDeploymentState = WarDeploymentManager().update(
                state: state.warDeploymentState,
                map: state.map,
                divisions: state.divisions,
                turn: state.turn,
                events: deploymentEvents
            )
        }
    }

    @discardableResult
    private func applyStrategicAdvance(
        regionId: RegionId,
        hex: HexCoord?,
        sourceZoneId: FrontZoneId?,
        command: Command,
        state: inout GameState,
        relatedRecordId: String?
    ) -> RegionId? {
        guard case .move = command,
              let advancingZoneId = sourceZoneId,
              let hex else {
            return nil
        }

        let advancingTheaterId = TheaterId(advancingZoneId.rawValue)
        guard state.theaterState.theaters[advancingTheaterId] != nil else {
            return nil
        }

        guard state.theaterState.dynamicTheaterId(for: hex, map: state.map) != advancingTheaterId else {
            return regionId
        }
        guard shouldAdvanceDynamicTheater(
            hex: hex,
            advancingZoneId: advancingZoneId,
            state: state
        ) else {
            return nil
        }

        let expansion = TheaterSystem().expandDynamicTheater(
            state: state.theaterState,
            map: state.map,
            divisions: state.divisions,
            breakthroughHex: hex,
            advancingTheaterId: advancingTheaterId,
            faction: state.warDeploymentState.frontZones[advancingZoneId]?.faction ?? .germany
        )
        state.theaterState = expansion.state

        let oldZoneId = state.warDeploymentState.zoneId(for: hex, map: state.map)
        if oldZoneId != advancingZoneId {
            state.warDeploymentState = WarDeploymentManager().advanceHex(
                hex,
                from: oldZoneId,
                to: advancingZoneId,
                state: state.warDeploymentState,
                map: state.map,
                divisions: state.divisions,
                turn: state.turn
            )
        }
        state.appendEvent(
            "Hex \(hex.q),\(hex.r) reassigned to dynamic theater \(advancingTheaterId.rawValue).",
            category: .theaterChange,
            relatedRecordId: relatedRecordId
        )
        state.appendEvent(
            "Front changed around region \(regionId.rawValue).",
            category: .frontChange,
            relatedRecordId: relatedRecordId
        )
        return regionId
    }

    private func shouldAdvanceDynamicTheater(
        hex: HexCoord,
        advancingZoneId: FrontZoneId,
        state: GameState
    ) -> Bool {
        guard let advancingFaction = state.warDeploymentState.frontZones[advancingZoneId]?.faction else {
            return false
        }

        let destinationZoneId = state.warDeploymentState.zoneId(for: hex, map: state.map)
        if let destinationZoneId,
           destinationZoneId != advancingZoneId,
           let destinationFaction = state.warDeploymentState.frontZones[destinationZoneId]?.faction {
            return destinationFaction != advancingFaction
        }

        if let controller = state.map.tile(at: hex)?.controller {
            return controller != advancingFaction
        }

        return false
    }

    private func actingDivisionId(for command: Command) -> String? {
        switch command {
        case .move(let divisionId, _),
             .hold(let divisionId),
             .allowRetreat(let divisionId),
             .resupply(let divisionId):
            return divisionId
        case .attack(let attackerId, _):
            return attackerId
        case .endTurn:
            return nil
        }
    }

    private func logicalZoneId(for divisionId: String, in state: WarDeploymentState) -> FrontZoneId? {
        state.frontZones.values
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .first {
                $0.unitsFront.contains(divisionId)
                    || $0.unitsDepth.contains(divisionId)
                    || $0.unitsGarrison.contains(divisionId)
            }?
            .id
    }

    private func affectedRegionIds(for command: Command, state: GameState) -> [RegionId] {
        switch command {
        case .move(_, let destination):
            return state.map.region(for: destination).map { [$0] } ?? []
        default:
            return []
        }
    }

    private func moveDestination(for command: Command) -> HexCoord? {
        if case .move(_, let destination) = command {
            return destination
        }
        return nil
    }

    private func controllerChanges(
        from beforeControllers: [RegionId: Faction],
        to map: MapState
    ) -> [RegionId] {
        map.regions.compactMap { regionId, region in
            beforeControllers[regionId] == region.controller ? nil : regionId
        }
    }

    private func stableUnique(_ values: [RegionId]) -> [RegionId] {
        var seen: Set<RegionId> = []
        var result: [RegionId] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result.sorted { $0.rawValue < $1.rawValue }
    }

    private func applyDirectiveOccupation(command: Command, state: inout GameState) -> [RegionId] {
        guard case .move(let divisionId, let destination) = command,
              let division = state.division(id: divisionId),
              occupationRules.canOccupy(division: division, destination: destination, in: state),
              var tile = state.map.tile(at: destination) else {
            return []
        }

        tile.controller = division.faction
        state.map.setTile(tile)
        return state.map.region(for: destination).map { [$0] } ?? []
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
