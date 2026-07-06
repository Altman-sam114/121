import Foundation

struct EconomyRules {
    private let baseManpowerReserve = 320
    private let baseIndustryReserve = 160
    private let baseSupplyReserve = 180
    private let maxAutomaticReinforcementPerDivision = 2
    private let maxRoadImprovementHexes = 2
    let roadImprovementCost = EconomyResources(manpower: 20, industry: 30, supplies: 10)

    func makeInitialState(map: MapState, factions: [Faction], turn: Int) -> EconomyState {
        var state = EconomyState(lastResolvedTurn: turn)
        let uniqueFactions = Set(factions).isEmpty ? Set(Faction.allCases) : Set(factions)

        for faction in uniqueFactions {
            let income = income(for: faction, map: map)
            state.updateLedger(
                FactionEconomyLedger(
                    faction: faction,
                    stockpile: EconomyResources(
                        manpower: baseManpowerReserve + income.manpower * 2,
                        industry: baseIndustryReserve + income.industry,
                        supplies: baseSupplyReserve + income.supplies
                    ),
                    lastIncome: income,
                    lastUpdatedTurn: turn
                )
            )
        }

        return state
    }

    func bootstrapIfNeeded(_ state: GameState) -> GameState {
        guard state.economyState.ledgers.isEmpty else {
            return state
        }

        var next = state
        let factions = next.divisions.map(\.faction) + Faction.allCases
        next.economyState = makeInitialState(map: next.map, factions: factions, turn: next.turn)
        next.appendEvent(
            "已按受控城池、工坊、粮道枢纽和郡县补建府库账本。",
            category: .supply
        )
        return next
    }

    func canQueueProduction(kind: ProductionKind, faction: Faction, in state: GameState) -> Bool {
        state.economyState.ledger(for: faction).stockpile.canAfford(kind.cost)
    }

    func queueProduction(kind: ProductionKind, faction: Faction, in state: inout GameState) -> Bool {
        var ledger = state.economyState.ledger(for: faction)
        guard ledger.stockpile.canAfford(kind.cost) else {
            state.appendEvent(
                "\(faction.displayName) 府库不足，无法排产 \(kind.displayName)：需要 \(resourceSummary(kind.cost))。",
                category: .supply
            )
            return false
        }

        ledger.stockpile.subtract(kind.cost)
        let order = ProductionOrder(
            id: productionOrderId(kind: kind, faction: faction, turn: state.turn, index: ledger.productionQueue.count),
            faction: faction,
            kind: kind,
            createdTurn: state.turn
        )
        ledger.productionQueue.append(order)
        ledger.lastUpdatedTurn = state.turn
        state.economyState.updateLedger(ledger)
        state.appendEvent(
            "\(faction.displayName) 排产 \(kind.displayName)：消耗 \(resourceSummary(kind.cost))，预计 \(kind.buildTurns) 回合。",
            category: .supply
        )
        return true
    }

    func roadImprovementNeeded(region: RegionNode, faction: Faction, map: MapState) -> Bool {
        region.infrastructure < 5 || !roadImprovementTargets(in: region, faction: faction, map: map).isEmpty
    }

    func improveRoad(regionId: RegionId, faction: Faction, in state: inout GameState) -> Bool {
        ensureLedger(for: faction, in: &state)
        guard let region = state.map.region(id: regionId),
              region.controller == faction,
              hasControlledHex(in: region, faction: faction, map: state.map),
              roadImprovementNeeded(region: region, faction: faction, map: state.map) else {
            return false
        }

        var ledger = state.economyState.ledger(for: faction)
        guard ledger.stockpile.canAfford(roadImprovementCost) else {
            state.appendEvent(
                "\(faction.displayName) 修缮道路资源不足：需要 \(resourceSummary(roadImprovementCost))。",
                category: .supply
            )
            return false
        }

        let improvedHexes = applyRoadImprovement(to: region, faction: faction, map: &state.map)
        ledger.stockpile.subtract(roadImprovementCost)
        ledger.lastUpdatedTurn = state.turn
        state.economyState.updateLedger(ledger)
        let hexSummary = improvedHexes.isEmpty
            ? "整修驿道与桥涵"
            : improvedHexes.map { roadHexDisplayName($0, in: state.map) }.joined(separator: "；")
        let infrastructure = state.map.region(id: regionId)?.infrastructure ?? region.infrastructure
        state.appendEvent(
            "\(faction.displayName) 修缮 \(regionDisplayName(region)) 道路：\(hexSummary)，基础设施 \(infrastructure)，消耗 \(resourceSummary(roadImprovementCost))。",
            category: .supply
        )
        return true
    }

    func resolveFactionTurn(for faction: Faction, in state: inout GameState) {
        ensureLedger(for: faction, in: &state)

        var ledger = state.economyState.ledger(for: faction)
        let turnIncome = income(for: faction, map: state.map)
        ledger.stockpile.add(turnIncome)
        ledger.lastIncome = turnIncome

        let upkeep = supplyUpkeep(for: faction, in: state)
        let paidUpkeep = EconomyResources(supplies: min(ledger.stockpile.supplies, upkeep.supplies))
        ledger.stockpile.subtract(paidUpkeep)
        ledger.lastUpkeep = upkeep
        let supplyShortfall = max(0, upkeep.supplies - paidUpkeep.supplies)

        if supplyShortfall > 0 {
            applyStrategicSupplyShortfall(for: faction, in: &state)
        }

        let reinforcementSpend = applyAutomaticReinforcement(for: faction, ledger: &ledger, in: &state)
        ledger.lastReinforcementSpend = reinforcementSpend

        advanceProduction(for: faction, ledger: &ledger, in: &state)

        ledger.lastUpdatedTurn = state.turn
        state.economyState.updateLedger(ledger)
        state.economyState.lastResolvedTurn = state.turn
        state.appendEvent(
            "\(faction.displayName) 府库结算：收入 +\(resourceSummary(turnIncome))；军粮维护 \(resourceSummary(upkeep))；补员消耗 \(resourceSummary(reinforcementSpend))；府库余量 \(resourceSummary(ledger.stockpile))。",
            category: .supply
        )
    }

    func cityLevel(for region: RegionNode, map: MapState) -> CityLevel {
        let hasHexCity = region.displayHexes.contains { hex in
            guard let tile = map.tile(at: hex) else {
                return false
            }
            return tile.baseTerrain == .city || tile.cityName != nil || tile.fortressName != nil
        }

        guard region.city != nil || hasHexCity || region.factories > 0 else {
            return .none
        }

        if region.city?.isCapital == true ||
            (region.city?.victoryPoints ?? 0) >= 5 ||
            region.factories >= 5 {
            return .metropolis
        }

        if (region.city?.victoryPoints ?? 0) >= 2 ||
            region.factories >= 2 ||
            region.supplyValue >= 3 {
            return .town
        }

        return .village
    }

    func income(for faction: Faction, map: MapState) -> EconomyResources {
        var income = EconomyResources()

        for region in map.regions.values where region.controller == faction && region.isPassable {
            guard hasControlledHex(in: region, faction: faction, map: map) else {
                continue
            }

            let level = cityLevel(for: region, map: map)
            let coreBonus = region.coreOf.isEmpty || region.coreOf.contains(faction) ? 1 : 0
            let regionManpower = max(1, level.manpowerGrowth + coreBonus * 4 + region.infrastructure)
            let regionIndustry = max(0, region.factories + level.industryValue + region.infrastructure / 3)
            let regionSupplies = max(1, region.supplyValue * 3 + region.factories + region.infrastructure / 2)

            income.add(
                EconomyResources(
                    manpower: regionManpower,
                    industry: regionIndustry,
                    supplies: regionSupplies
                )
            )
        }

        if map.regions.isEmpty {
            let controlledTiles = map.tiles.values.filter { $0.controller == faction }
            income.add(
                EconomyResources(
                    manpower: max(12, controlledTiles.count * 2),
                    industry: max(8, controlledTiles.filter { $0.baseTerrain == .city || $0.cityName != nil }.count * 4),
                    supplies: max(12, map.supplySources(for: faction).count * 12)
                )
            )
        }

        return income
    }

    private func ensureLedger(for faction: Faction, in state: inout GameState) {
        if state.economyState.ledgers[faction] == nil {
            let income = income(for: faction, map: state.map)
            state.economyState.updateLedger(
                FactionEconomyLedger(
                    faction: faction,
                    stockpile: EconomyResources(
                        manpower: baseManpowerReserve + income.manpower,
                        industry: baseIndustryReserve + income.industry,
                        supplies: baseSupplyReserve + income.supplies
                    ),
                    lastIncome: income,
                    lastUpdatedTurn: state.turn
                )
            )
        }
    }

    private func supplyUpkeep(for faction: Faction, in state: GameState) -> EconomyResources {
        let upkeep = state.divisions
            .filter { $0.faction == faction && !$0.isDestroyed }
            .reduce(0) { partial, division in
                partial + 2 + (division.isArmor ? 2 : 0) + (division.isArtillery ? 1 : 0)
            }
        return EconomyResources(supplies: upkeep)
    }

    private func applyStrategicSupplyShortfall(for faction: Faction, in state: inout GameState) {
        for index in state.divisions.indices
            where state.divisions[index].faction == faction &&
            state.divisions[index].supplyState == .supplied {
            state.divisions[index].supplyState = .lowSupply
        }

        state.appendEvent(
            "\(faction.displayName) 战略粮草耗尽，本回合原本粮草充足的军队降为粮草不足。",
            category: .supply
        )
    }

    private func applyAutomaticReinforcement(
        for faction: Faction,
        ledger: inout FactionEconomyLedger,
        in state: inout GameState
    ) -> EconomyResources {
        var spend = EconomyResources()
        let candidateIds = state.divisions
            .filter { division in
                division.faction == faction &&
                    !division.isDestroyed &&
                    !division.isRetreating &&
                    division.supplyState == .supplied &&
                    division.strength < division.maxStrength &&
                    !isAdjacentToEnemy(division, in: state)
            }
            .sorted { lhs, rhs in
                let lhsMissing = lhs.maxStrength - lhs.strength
                let rhsMissing = rhs.maxStrength - rhs.strength
                if lhsMissing != rhsMissing {
                    return lhsMissing > rhsMissing
                }
                return lhs.id < rhs.id
            }
            .map(\.id)

        for divisionId in candidateIds {
            guard let index = state.divisionIndex(id: divisionId) else {
                continue
            }

            let missing = state.divisions[index].maxStrength - state.divisions[index].strength
            let desired = min(maxAutomaticReinforcementPerDivision, missing)
            let perStrengthCost = reinforcementCostPerStrength(for: state.divisions[index])
            var restored = 0

            for _ in 0..<desired where ledger.stockpile.canAfford(perStrengthCost) {
                ledger.stockpile.subtract(perStrengthCost)
                spend.add(perStrengthCost)
                restored += 1
            }

            if restored > 0 {
                state.divisions[index].reinforceStrength(restored)
                state.appendEvent(
                    "\(state.divisions[index].thematicDisplayName) 后方自动补员：兵力 +\(restored)。",
                    category: .reinforce
                )
            }
        }

        return spend
    }

    private func reinforcementCostPerStrength(for division: Division) -> EconomyResources {
        let armorWeight = division.components
            .filter { $0.type == .tank || $0.type == .cavalry }
            .reduce(0.0) { $0 + $1.weight }
        let motorizedWeight = division.components
            .filter { $0.type == .motorizedInfantry || $0.type == .naval }
            .reduce(0.0) { $0 + $1.weight }
        let artilleryWeight = division.components
            .filter { $0.type == .artillery || $0.type == .siegeEngine }
            .reduce(0.0) { $0 + $1.weight }

        return EconomyResources(
            manpower: max(4, Int((8 + 6 * (1 - armorWeight)).rounded())),
            industry: max(1, Int((1 + armorWeight * 5 + motorizedWeight * 2 + artilleryWeight * 3).rounded())),
            supplies: 1
        )
    }

    private func advanceProduction(
        for faction: Faction,
        ledger: inout FactionEconomyLedger,
        in state: inout GameState
    ) {
        var remainingOrders: [ProductionOrder] = []

        for var order in ledger.productionQueue {
            guard order.faction == faction else {
                remainingOrders.append(order)
                continue
            }

            if order.remainingTurns > 0 {
                order.remainingTurns -= 1
            }

            guard order.isReady else {
                remainingOrders.append(order)
                continue
            }

            if order.kind == .supplyStockpile {
                ledger.stockpile.add(EconomyResources(supplies: order.kind.supplyOutput))
                state.appendEvent(
                    "\(faction.displayName) 完成 \(order.kind.displayName)：粮草 +\(order.kind.supplyOutput)。",
                    category: .supply
                )
                continue
            }

            if let deployment = deploymentHex(for: faction, preferredRegionId: order.deploymentRegionId, in: state) {
                let division = makeProducedDivision(
                    order: order,
                    faction: faction,
                    coord: deployment.coord,
                    index: state.divisions.count
                )
                state.divisions.append(division)
                order.deploymentRegionId = deployment.regionId
                state.appendEvent(
                    "\(faction.displayName) 在 \(deploymentSummary(for: deployment, in: state)) 部署 \(division.thematicDisplayName)。",
                    category: .reinforce
                )
            } else {
                remainingOrders.append(order)
                state.appendEvent(
                    "\(order.kind.displayName) 已整备完成，但当前没有安全后方部署格，留待下回合继续寻找。",
                    category: .reinforce
                )
            }
        }

        ledger.productionQueue = remainingOrders
    }

    private func deploymentHex(
        for faction: Faction,
        preferredRegionId: RegionId?,
        in state: GameState
    ) -> (coord: HexCoord, regionId: RegionId?)? {
        let preferredRegions = (preferredRegionId
            .flatMap { state.map.region(id: $0).map { [$0] } } ?? [])
            .filter {
                $0.controller == faction &&
                    hasControlledHex(in: $0, faction: faction, map: state.map) &&
                    deploymentRegionIsQualified($0, map: state.map)
            }
        let controlledRegions = state.map.regions.values
            .filter {
                $0.controller == faction &&
                    hasControlledHex(in: $0, faction: faction, map: state.map) &&
                    deploymentRegionIsQualified($0, map: state.map)
            }
            .sorted {
                deploymentRegionScore($0, map: state.map) == deploymentRegionScore($1, map: state.map)
                    ? $0.id.rawValue < $1.id.rawValue
                    : deploymentRegionScore($0, map: state.map) > deploymentRegionScore($1, map: state.map)
            }
        let regions = preferredRegions + controlledRegions

        for region in regions {
            let hexes = ([region.representativeHex] + region.displayHexes)
                .filter { state.map.tile(at: $0)?.isPassable == true }
                .filter { state.map.tile(at: $0)?.controller == faction }
                .filter { state.division(at: $0) == nil }
                .filter { !isEnemyAdjacent(to: $0, faction: faction, in: state) }
                .sorted {
                    if $0 == region.representativeHex {
                        return true
                    }
                    if $1 == region.representativeHex {
                        return false
                    }
                    if $0.q == $1.q {
                        return $0.r < $1.r
                    }
                    return $0.q < $1.q
                }

            if let hex = hexes.first {
                return (hex, region.id)
            }
        }

        let supplyHexes = state.map.supplySources(for: faction)
            .map(\.coord)
            .filter { state.map.tile(at: $0)?.isPassable == true }
            .filter { state.division(at: $0) == nil }
            .filter { !isEnemyAdjacent(to: $0, faction: faction, in: state) }
        if let hex = supplyHexes.first {
            return (hex, state.map.region(for: hex))
        }

        return nil
    }

    func hasControlledHex(in region: RegionNode, faction: Faction, map: MapState) -> Bool {
        regionHexes(for: region).contains { coord in
            map.tile(at: coord)?.controller == faction
        }
    }

    private func applyRoadImprovement(
        to region: RegionNode,
        faction: Faction,
        map: inout MapState
    ) -> [HexCoord] {
        let targets = roadImprovementPlan(in: region, faction: faction, map: map)
        var improvedHexes: [HexCoord] = []

        for coord in targets.prefix(maxRoadImprovementHexes) {
            guard var tile = map.tile(at: coord) else {
                continue
            }
            tile.hasRoad = true
            map.setTile(tile)
            improvedHexes.append(coord)
        }

        if var updatedRegion = map.regions[region.id] {
            updatedRegion.infrastructure = min(5, updatedRegion.infrastructure + 1)
            map.regions[region.id] = updatedRegion
        }

        return improvedHexes
    }

    private func roadImprovementTargets(
        in region: RegionNode,
        faction: Faction,
        map: MapState
    ) -> [HexCoord] {
        eligibleRoadHexes(in: region, faction: faction, map: map)
            .filter { map.tile(at: $0)?.hasRoad == false }
            .sorted {
                let lhsScore = roadImprovementPriority($0, region: region, map: map)
                let rhsScore = roadImprovementPriority($1, region: region, map: map)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return coordPrecedes($0, $1)
            }
    }

    private func roadImprovementPlan(
        in region: RegionNode,
        faction: Faction,
        map: MapState
    ) -> [HexCoord] {
        let targets = roadImprovementTargets(in: region, faction: faction, map: map)
        guard !targets.isEmpty else {
            return []
        }

        if let connectedPlan = connectedRoadImprovementPlan(
            targets: targets,
            region: region,
            faction: faction,
            map: map
        ), !connectedPlan.isEmpty {
            return Array(connectedPlan.prefix(maxRoadImprovementHexes))
        }

        return Array(targets.prefix(maxRoadImprovementHexes))
    }

    private func connectedRoadImprovementPlan(
        targets: [HexCoord],
        region: RegionNode,
        faction: Faction,
        map: MapState
    ) -> [HexCoord]? {
        let eligibleHexes = Set(eligibleRoadHexes(in: region, faction: faction, map: map))
        guard !eligibleHexes.isEmpty else {
            return nil
        }

        let roadAnchors = Set(eligibleHexes.filter { map.tile(at: $0)?.hasRoad == true })
        if !roadAnchors.isEmpty {
            for target in targets {
                guard let path = shortestRoadPath(
                    fromAny: roadAnchors,
                    to: target,
                    eligibleHexes: eligibleHexes
                ) else {
                    continue
                }
                let plan = path.filter { map.tile(at: $0)?.hasRoad != true }
                let filledPlan = fillRoadPlan(plan, targets: targets, connectedTo: roadAnchors)
                if !filledPlan.isEmpty {
                    return filledPlan
                }
            }
        }

        if let externalConnection = targets.first(where: { hasAdjacentRoad($0, map: map) }) {
            return fillRoadPlan([externalConnection], targets: targets, connectedTo: Set([externalConnection]))
        }

        guard let seed = roadSeedHex(in: region, eligibleHexes: eligibleHexes, map: map) else {
            return nil
        }
        for target in targets where target != seed {
            guard let path = shortestRoadPath(
                fromAny: Set([seed]),
                to: target,
                eligibleHexes: eligibleHexes
            ) else {
                continue
            }
            let plan = path.filter { map.tile(at: $0)?.hasRoad != true }
            let filledPlan = fillRoadPlan(plan, targets: targets, connectedTo: Set(plan))
            if !filledPlan.isEmpty {
                return filledPlan
            }
        }

        let seedPlan = map.tile(at: seed)?.hasRoad == true ? [] : [seed]
        let filledSeedPlan = fillRoadPlan(seedPlan, targets: targets, connectedTo: Set(seedPlan))
        return filledSeedPlan.isEmpty ? nil : filledSeedPlan
    }

    private func fillRoadPlan(
        _ plan: [HexCoord],
        targets: [HexCoord],
        connectedTo anchors: Set<HexCoord>
    ) -> [HexCoord] {
        let targetSet = Set(targets)
        var result: [HexCoord] = []
        var seen = Set<HexCoord>()
        for coord in plan where targetSet.contains(coord) && !seen.contains(coord) {
            result.append(coord)
            seen.insert(coord)
        }

        var network = anchors
        network.formUnion(result)
        while result.count < maxRoadImprovementHexes {
            guard let next = targets.first(where: { coord in
                !seen.contains(coord) && coord.neighbors.contains { network.contains($0) }
            }) else {
                break
            }
            result.append(next)
            seen.insert(next)
            network.insert(next)
        }
        return result
    }

    private func shortestRoadPath(
        fromAny starts: Set<HexCoord>,
        to target: HexCoord,
        eligibleHexes: Set<HexCoord>
    ) -> [HexCoord]? {
        guard eligibleHexes.contains(target) else {
            return nil
        }

        let startList = starts
            .filter { eligibleHexes.contains($0) }
            .sorted(by: coordPrecedes)
        guard !startList.isEmpty else {
            return nil
        }

        var queue = startList
        var visited = Set(startList)
        var previous: [HexCoord: HexCoord] = [:]
        var index = 0

        while index < queue.count {
            let current = queue[index]
            index += 1
            if current == target {
                return reconstructPath(to: target, previous: previous)
            }

            for neighbor in current.neighbors.sorted(by: coordPrecedes)
                where eligibleHexes.contains(neighbor) && !visited.contains(neighbor) {
                visited.insert(neighbor)
                previous[neighbor] = current
                queue.append(neighbor)
            }
        }

        return nil
    }

    private func reconstructPath(
        to target: HexCoord,
        previous: [HexCoord: HexCoord]
    ) -> [HexCoord] {
        var path = [target]
        var current = target
        while let parent = previous[current] {
            path.append(parent)
            current = parent
        }
        return Array(path.reversed())
    }

    private func eligibleRoadHexes(
        in region: RegionNode,
        faction: Faction,
        map: MapState
    ) -> [HexCoord] {
        regionHexes(for: region)
            .filter { coord in
                guard let tile = map.tile(at: coord) else {
                    return false
                }
                return tile.isPassable && tile.controller == faction
            }
    }

    private func roadSeedHex(
        in region: RegionNode,
        eligibleHexes: Set<HexCoord>,
        map: MapState
    ) -> HexCoord? {
        eligibleHexes.sorted {
            let lhsScore = roadSeedPriority($0, region: region, map: map)
            let rhsScore = roadSeedPriority($1, region: region, map: map)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            return coordPrecedes($0, $1)
        }.first
    }

    private func roadImprovementPriority(_ coord: HexCoord, region: RegionNode, map: MapState) -> Int {
        guard let tile = map.tile(at: coord) else {
            return 0
        }
        var score = coord == region.representativeHex ? 8 : 0
        if tile.baseTerrain == .city || tile.cityName != nil || tile.fortressName != nil {
            score += 6
        }
        if map.supplySources.contains(where: { $0.coord == coord }) {
            score += 5
        }
        if coord.neighbors.contains(where: { map.tile(at: $0)?.hasRoad == true }) {
            score += 3
        }
        return score
    }

    private func roadSeedPriority(_ coord: HexCoord, region: RegionNode, map: MapState) -> Int {
        guard let tile = map.tile(at: coord) else {
            return 0
        }
        var score = tile.hasRoad ? 20 : 0
        if coord == region.representativeHex {
            score += 10
        }
        if tile.baseTerrain == .city || tile.cityName != nil || tile.fortressName != nil {
            score += 8
        }
        if map.supplySources.contains(where: { $0.coord == coord }) {
            score += 6
        }
        if hasAdjacentRoad(coord, map: map) {
            score += 5
        }
        return score
    }

    private func hasAdjacentRoad(_ coord: HexCoord, map: MapState) -> Bool {
        coord.neighbors.contains { map.tile(at: $0)?.hasRoad == true }
    }

    private func coordPrecedes(_ lhs: HexCoord, _ rhs: HexCoord) -> Bool {
        lhs.q == rhs.q ? lhs.r < rhs.r : lhs.q < rhs.q
    }

    private func regionHexes(for region: RegionNode) -> [HexCoord] {
        Array(Set([region.representativeHex] + region.displayHexes))
    }

    private func deploymentRegionIsQualified(_ region: RegionNode, map: MapState) -> Bool {
        let level = cityLevel(for: region, map: map)
        if region.city?.isCapital == true {
            return true
        }

        switch level {
        case .metropolis,
             .town:
            return true
        case .none,
             .village:
            break
        }

        return region.factories >= 2 ||
            region.infrastructure >= 4 ||
            region.supplyValue >= 3
    }

    private func deploymentRegionScore(_ region: RegionNode, map: MapState) -> Int {
        let level = cityLevel(for: region, map: map)
        return level.industryValue * 3 + region.factories * 2 + region.supplyValue + region.infrastructure
    }

    private func makeProducedDivision(
        order: ProductionOrder,
        faction: Faction,
        coord: HexCoord,
        index: Int
    ) -> Division {
        let id = "prod_\(faction.rawValue)_\(order.kind.rawValue)_\(order.createdTurn)_\(index)"
        let name = "\(order.kind.displayName) \(order.createdTurn)-\(index)"

        switch order.kind {
        case .infantryDivision:
            return .infantry(id: id, name: name, faction: faction, coord: coord)
        case .panzerDivision:
            return .panzer(id: id, name: name, faction: faction, coord: coord)
        case .motorizedDivision:
            return .motorized(id: id, name: name, faction: faction, coord: coord)
        case .artilleryDivision:
            return .artillery(id: id, name: name, faction: faction, coord: coord)
        case .supplyStockpile:
            return .infantry(id: id, name: name, faction: faction, coord: coord)
        }
    }

    private func isAdjacentToEnemy(_ division: Division, in state: GameState) -> Bool {
        isEnemyAdjacent(to: division.coord, faction: division.faction, in: state)
    }

    private func isEnemyAdjacent(to coord: HexCoord, faction: Faction, in state: GameState) -> Bool {
        state.divisions.contains { other in
            state.diplomacyState.isHostile(between: other.faction, and: faction) &&
                !other.isDestroyed &&
                other.coord.distance(to: coord) <= 1
        }
    }

    private func productionOrderId(kind: ProductionKind, faction: Faction, turn: Int, index: Int) -> String {
        "order_\(faction.rawValue)_\(kind.rawValue)_\(turn)_\(index)"
    }

    private func resourceSummary(_ resources: EconomyResources) -> String {
        "人口 \(resources.manpower)、军械 \(resources.industry)、粮草 \(resources.supplies)"
    }

    private func deploymentSummary(
        for deployment: (coord: HexCoord, regionId: RegionId?),
        in state: GameState
    ) -> String {
        guard let regionId = deployment.regionId,
              let region = state.map.region(id: regionId),
              !region.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "后方安全格 \(hexDisplayName(deployment.coord, in: state.map))"
        }
        return "\(regionDisplayName(region)) 后方安全格 \(hexDisplayName(deployment.coord, in: state.map))"
    }

    private func regionDisplayName(_ region: RegionNode) -> String {
        let name = region.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty || name == region.id.rawValue ? "未知郡县" : name
    }

    private func roadHexDisplayName(_ coord: HexCoord, in map: MapState) -> String {
        let base = hexDisplayName(coord, in: map)
        return base.contains("官道") ? base : "\(base)新修官道"
    }

    private func hexDisplayName(_ coord: HexCoord, in map: MapState) -> String {
        guard let tile = map.tile(at: coord) else {
            return "地格 \(coord.q),\(coord.r)"
        }

        let anchor = displayAnchor(for: tile, coord: coord, in: map)
        let terrain = tile.hasRoad ? "官道" : tile.baseTerrain.displayName
        return "\(anchor)\(terrain)（\(coord.q),\(coord.r)）"
    }

    private func displayAnchor(for tile: HexTile, coord: HexCoord, in map: MapState) -> String {
        let cityName = tile.cityName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !cityName.isEmpty {
            return cityName
        }
        let fortressName = tile.fortressName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fortressName.isEmpty {
            return fortressName
        }
        if let regionId = map.region(for: coord),
           let region = map.region(id: regionId) {
            let regionName = region.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !regionName.isEmpty && regionName != region.id.rawValue {
                return regionName
            }
        }
        return "地格"
    }
}
