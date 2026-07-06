import Foundation

struct SupplyRules {
    let maxSupplyPathCost = 7
    let suppliedResupplyHPRecovery = 2
    let encircledHPLoss = 1
    let failedRetreatHPLoss = 1
    private let movementRules = MovementRules()

    func updateSupplyStates(in state: inout GameState) {
        let snapshot = state
        for index in state.divisions.indices {
            let division = state.divisions[index]
            state.divisions[index].supplyState = supplyState(for: division, in: snapshot)
        }
    }

    func applyResupplyRest(to divisionId: String, in state: inout GameState) {
        guard let index = state.divisionIndex(id: divisionId) else {
            return
        }

        state.divisions[index].supplyState = supplyState(for: state.divisions[index], in: state)
        let before = state.divisions[index]

        switch before.supplyState {
        case .supplied:
            recoverDivision(
                at: index,
                hp: suppliedResupplyHPRecovery,
                in: &state
            )
        case .lowSupply:
            break
        case .encircled:
            break
        }

        let after = state.divisions[index]
        let hpRecovered = after.hp - before.hp
        let divisionName = divisionDisplayName(after)

        if hpRecovered > 0 {
            state.appendEvent(
                "\(divisionName) 完成整补（\(after.supplyState.displayName)）：兵力 +\(hpRecovered)。"
            )
        } else if isBesieged(after, in: state) {
            state.appendEvent(
                "\(divisionName) 被围于城池或关隘，\(after.supplyState.displayName) 状态下无法恢复兵力。",
                category: .encircle
            )
        } else {
            state.appendEvent("\(divisionName) 处于 \(after.supplyState.displayName)，本次未能恢复兵力。")
        }
    }

    func resolveRetreat(for divisionId: String, in state: inout GameState) {
        guard let index = state.divisionIndex(id: divisionId) else {
            return
        }

        let division = state.divisions[index]
        if let destination = retreatDestination(for: division, in: state) {
            let origin = division.coord
            state.divisions[index].coord = destination
            if let direction = origin.direction(to: destination) {
                state.divisions[index].facing = direction
            }
            state.divisions[index].beginRetreat(to: destination)
            state.appendEvent(
                "\(divisionDisplayName(division)) 撤退：从 \(hexDisplayName(origin, in: state)) 后撤至 \(hexDisplayName(destination, in: state))。"
            )
        } else {
            state.divisions[index].hp = max(1, state.divisions[index].hp - failedRetreatHPLoss)
            state.appendEvent(
                "\(divisionDisplayName(division)) 撤退失败，额外损失 \(failedRetreatHPLoss) 点兵力。"
            )
        }
    }

    func advanceRetreats(in state: inout GameState) {
        let retreatingIds = state.divisions
            .filter(\.isRetreating)
            .map(\.id)

        for divisionId in retreatingIds {
            _ = advanceRetreatStatusIfNeeded(for: divisionId, in: &state)
        }
    }

    func applyEncirclementAttrition(in state: inout GameState) {
        for index in state.divisions.indices where state.divisions[index].supplyState == .encircled {
            let beforeHP = state.divisions[index].hp

            state.divisions[index].hp = max(1, beforeHP - encircledHPLoss)

            let hpLost = beforeHP - state.divisions[index].hp
            if hpLost > 0 {
                let message: String
                if isBesieged(state.divisions[index], in: state) {
                    message = "\(divisionDisplayName(state.divisions[index])) 粮道断绝，遭受围城损耗：兵力 -\(hpLost)。"
                } else {
                    message = "\(divisionDisplayName(state.divisions[index])) 遭受包围损耗：兵力 -\(hpLost)。"
                }
                state.appendEvent(message, category: .encircle)
            }
        }
    }

    func hasSupplyLine(for division: Division, in state: GameState) -> Bool {
        state.map.supplySources(for: division.faction).contains { source in
            supplyPathCost(from: division.coord, to: source.coord, for: division.faction, in: state) <= maxSupplyPathCost
        }
    }

    func supplyState(for division: Division, in state: GameState) -> SupplyState {
        if hasSupplyLine(for: division, in: state) {
            return .supplied
        }

        if isEncircled(division, in: state) {
            return .encircled
        }

        return .lowSupply
    }

    func isEncircled(_ division: Division, in state: GameState) -> Bool {
        guard !hasSupplyLine(for: division, in: state) else {
            return false
        }

        let safeExits = division.coord.neighbors.filter {
            isSafeRetreatTile($0, for: division.faction, in: state)
        }
        return safeExits.count < 2
    }

    func isBesieged(_ division: Division, in state: GameState) -> Bool {
        guard isCityOrFortressPosition(division.coord, in: state),
              !hasSupplyLine(for: division, in: state) else {
            return false
        }

        return hasAdjacentHostileDivision(to: division.coord, faction: division.faction, in: state)
    }

    func isSafeRetreatTile(_ coord: HexCoord, for faction: Faction, in state: GameState) -> Bool {
        guard let tile = state.map.tile(at: coord),
              state.map.contains(coord),
              tile.isPassable,
              state.division(at: coord) == nil else {
            return false
        }

        if tile.isCapturable,
           let controller = tile.controller,
           state.diplomacyState.isHostile(between: controller, and: faction) {
            return false
        }

        if movementRules.isEnemyZoneOfControl(coord, for: faction, in: state) {
            return false
        }

        return state.map.supplySources(for: faction).contains { source in
            supplyPathCost(from: coord, to: source.coord, for: faction, in: state) <= maxSupplyPathCost
        }
    }

    func retreatDestination(for division: Division, in state: GameState) -> HexCoord? {
        let candidates = division.coord.neighbors.filter {
            isSafeRetreatTile($0, for: division.faction, in: state)
        }

        return candidates.min {
            retreatSortKey(for: $0, faction: division.faction, in: state) <
                retreatSortKey(for: $1, faction: division.faction, in: state)
        }
    }

    func supplyPathCost(from start: HexCoord, to goal: HexCoord, for faction: Faction, in state: GameState) -> Int {
        guard state.map.contains(start), state.map.contains(goal) else {
            return Int.max
        }

        var bestCost: [HexCoord: Int] = [start: 0]
        var frontier: [(coord: HexCoord, cost: Int)] = [(start, 0)]

        while !frontier.isEmpty {
            frontier.sort { $0.cost < $1.cost }
            let current = frontier.removeFirst()

            guard current.cost == bestCost[current.coord] else {
                continue
            }

            if current.coord == goal {
                return current.cost
            }

            guard let fromTile = state.map.tile(at: current.coord) else {
                continue
            }

            for direction in HexDirection.ordered {
                let next = current.coord.neighbor(in: direction)
                guard let toTile = state.map.tile(at: next),
                      state.map.contains(next),
                      toTile.isPassable,
                      canSupplyPass(through: next, tile: toTile, for: faction, in: state) else {
                    continue
                }

                var nextCost = current.cost + supplyCost(entering: toTile)
                if movementRules.hasRiverCrossing(from: fromTile, to: toTile, direction: direction) {
                    nextCost += 2
                }

                guard nextCost <= maxSupplyPathCost,
                      nextCost < bestCost[next, default: Int.max] else {
                    continue
                }

                bestCost[next] = nextCost
                frontier.append((next, nextCost))
            }
        }

        return Int.max
    }

    private func canSupplyPass(through coord: HexCoord, tile: HexTile, for faction: Faction, in state: GameState) -> Bool {
        if let division = state.division(at: coord),
           state.diplomacyState.isHostile(between: division.faction, and: faction) {
            return false
        }

        if tile.isCapturable,
           let controller = tile.controller,
           state.diplomacyState.isHostile(between: controller, and: faction) {
            return false
        }

        if movementRules.isEnemyZoneOfControl(coord, for: faction, in: state) {
            if state.division(at: coord)?.faction == faction {
                return true
            }
            return false
        }

        return true
    }

    private func isCityOrFortressPosition(_ coord: HexCoord, in state: GameState) -> Bool {
        guard let tile = state.map.tile(at: coord) else {
            return false
        }

        if isCityOrFortressTile(tile) {
            return true
        }

        guard let regionId = state.map.region(for: coord),
              let region = state.map.region(id: regionId) else {
            return false
        }

        if region.city != nil {
            return true
        }

        return Set([region.representativeHex] + region.displayHexes).contains { regionCoord in
            state.map.tile(at: regionCoord).map(isCityOrFortressTile) ?? false
        }
    }

    private func isCityOrFortressTile(_ tile: HexTile) -> Bool {
        tile.baseTerrain == .city ||
            tile.baseTerrain == .fortress ||
            tile.cityName != nil ||
            tile.fortressName != nil
    }

    private func hasAdjacentHostileDivision(to coord: HexCoord, faction: Faction, in state: GameState) -> Bool {
        state.divisions.contains { other in
            !other.isDestroyed &&
                state.diplomacyState.isHostile(between: other.faction, and: faction) &&
                other.coord.distance(to: coord) == 1
        }
    }

    private func retreatSortKey(for coord: HexCoord, faction: Faction, in state: GameState) -> RetreatSortKey {
        let supplySources = state.map.supplySources(for: faction)
        let pathCost = supplySources
            .map { supplyPathCost(from: coord, to: $0.coord, for: faction, in: state) }
            .min() ?? Int.max
        let sourceDistance = supplySources
            .map { coord.distance(to: $0.coord) }
            .min() ?? Int.max
        let tileCost = state.map.tile(at: coord).map(supplyCost(entering:)) ?? Int.max

        return RetreatSortKey(
            pathCost: pathCost,
            sourceDistance: sourceDistance,
            tileCost: tileCost,
            q: coord.q,
            r: coord.r
        )
    }

    private func recoverDivision(at index: Int, hp: Int, in state: inout GameState) {
        state.divisions[index].reinforceStrength(hp)
    }

    private func advanceRetreatStatusIfNeeded(for divisionId: String, in state: inout GameState) -> Bool {
        guard let index = state.divisionIndex(id: divisionId),
              state.divisions[index].isRetreating else {
            return false
        }

        let wasRetreating = state.divisions[index].isRetreating
        state.divisions[index].advanceRetreatTurn()
        if wasRetreating && !state.divisions[index].isRetreating {
            state.appendEvent("\(divisionDisplayName(state.divisions[index])) 完成撤退整顿。")
        }

        return true
    }

    private func supplyCost(entering tile: HexTile) -> Int {
        if tile.hasRoad {
            return 1
        }

        switch tile.baseTerrain {
        case .mountain:
            return 3
        default:
            return 2
        }
    }

    private func divisionDisplayName(_ division: Division) -> String {
        division.thematicDisplayName
    }

    private func hexDisplayName(_ coord: HexCoord, in state: GameState) -> String {
        guard let tile = state.map.tile(at: coord) else {
            return "地格 \(coord.q),\(coord.r)"
        }

        let anchor = displayAnchor(for: tile, coord: coord, in: state.map)
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

private struct RetreatSortKey: Comparable {
    let pathCost: Int
    let sourceDistance: Int
    let tileCost: Int
    let q: Int
    let r: Int

    static func < (lhs: RetreatSortKey, rhs: RetreatSortKey) -> Bool {
        if lhs.pathCost != rhs.pathCost {
            return lhs.pathCost < rhs.pathCost
        }

        if lhs.sourceDistance != rhs.sourceDistance {
            return lhs.sourceDistance < rhs.sourceDistance
        }

        if lhs.tileCost != rhs.tileCost {
            return lhs.tileCost < rhs.tileCost
        }

        if lhs.q != rhs.q {
            return lhs.q < rhs.q
        }

        return lhs.r < rhs.r
    }
}
