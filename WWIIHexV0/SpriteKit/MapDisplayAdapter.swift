import SpriteKit

typealias DisplayColor = SKColor

enum VisibilityState: Equatable {
    case unseen
    case explored
    case visible
}

struct HexDisplayState {
    let coord: HexCoord
    let regionId: RegionId?
    let terrain: BaseTerrain
    let controller: Faction?
    let cityName: String?
    let fortressName: String?
    let isRepresentative: Bool
    let visibility: VisibilityState
}

struct UnitDisplayPlacement: Equatable {
    let divisionId: String
    let hex: HexCoord
    let offset: CGPoint
    let stackIndex: Int
    let stackCount: Int
}

extension UnitDisplayPlacement {
    static func == (lhs: UnitDisplayPlacement, rhs: UnitDisplayPlacement) -> Bool {
        lhs.divisionId == rhs.divisionId &&
            lhs.hex == rhs.hex &&
            lhs.offset.x == rhs.offset.x &&
            lhs.offset.y == rhs.offset.y &&
            lhs.stackIndex == rhs.stackIndex &&
            lhs.stackCount == rhs.stackCount
    }
}

struct RegionInspectorState: Equatable {
    let region: RegionNode
    let selectedHex: HexCoord?
    let selectedHexController: Faction?
    let selectedHexDynamicTheaterId: TheaterId?
    let selectedHexDynamicTheaterDisplayName: String?
    let selectedHexFrontZoneId: FrontZoneId?
    let selectedHexFrontZoneDisplayName: String?
    let selectedHexHasRoad: Bool?
    let selectedHexRoadStatusSummary: String?
    let theaterId: TheaterId?
    let theaterDisplayName: String?
    let frontZoneId: FrontZoneId?
    let frontZoneDisplayName: String?
    let frontPressure: Double
    let roadHexCount: Int
    let pressuredRoadHexCount: Int
    let roadPressureSourceSummaries: [String]
    let passableHexCount: Int
    let friendlyDivisions: [Division]
    let visibleEnemyDivisions: [Division]
    let visibleNonHostileDivisions: [Division]
    let friendlyGeneralSummaries: [String]
    let visibleEnemyEngagementSummaries: [String]
    let visibleNonHostileRelationSummaries: [String]
    let objectiveNames: [String]
    let objectiveStatus: String
    let cityLevel: CityLevel
    let economicOutput: EconomyResources
}

struct UnitInspectorStrategicState: Equatable {
    let coord: HexCoord
    let coordDisplayName: String
    let regionId: RegionId?
    let regionDisplayName: String?
    let dynamicTheaterId: TheaterId?
    let dynamicTheaterDisplayName: String?
    let frontLineIds: [FrontLineId]
    let frontLineDisplayNames: [String]
    let frontZoneId: FrontZoneId?
    let frontZoneDisplayName: String?
    let deploymentRole: UnitDeploymentRole
    let generalAssignment: GeneralAssignment?
}

struct MapDisplayAdapter {
    let state: GameState
    let revealAll: Bool

    init(state: GameState, revealAll: Bool = false) {
        self.state = state
        self.revealAll = revealAll
    }

    func regionId(for hex: HexCoord) -> RegionId? {
        state.map.region(for: hex)
    }

    func displayHexes(for regionId: RegionId) -> [HexCoord] {
        state.map.region(id: regionId)?.displayHexes ?? []
    }

    func representativeHex(for regionId: RegionId) -> HexCoord? {
        state.map.representativeHex(for: regionId)
    }

    func terrainColor(for hex: HexCoord) -> DisplayColor {
        TerrainStyle.fillColor(for: terrain(for: hex))
    }

    func controllerColor(for hex: HexCoord) -> DisplayColor {
        TerrainStyle.controllerColor(for: controller(for: hex))
    }

    func unitDisplayHex(for division: Division) -> HexCoord? {
        division.coord
    }

    func visibility(for hex: HexCoord, faction: Faction) -> VisibilityState {
        if revealAll {
            return .visible
        }
        guard !state.map.regions.isEmpty,
              let regionId = regionId(for: hex) else {
            return .visible
        }

        let visibleRegions = RegionVisibilityRules().visibleRegions(for: faction, in: state)
        return visibleRegions.contains(regionId) ? .visible : .unseen
    }

    func hexDisplayState(for hex: HexCoord, viewerFaction: Faction) -> HexDisplayState? {
        guard state.map.contains(hex) else {
            return nil
        }

        let regionId = regionId(for: hex)
        let region = regionId.flatMap { state.map.region(id: $0) }
        let tile = state.map.tile(at: hex)
        let terrain = tile?.baseTerrain ?? region?.terrain ?? .plain
        let cityName = tile?.cityName ?? (hex == region?.representativeHex ? region?.city?.name : nil)
        let fortressName = tile?.fortressName

        return HexDisplayState(
            coord: hex,
            regionId: regionId,
            terrain: terrain,
            controller: tile?.controller ?? region?.controller,
            cityName: cityName,
            fortressName: fortressName,
            isRepresentative: hex == region?.representativeHex,
            visibility: visibility(for: hex, faction: viewerFaction)
        )
    }

    func unitPlacements(viewerFaction: Faction) -> [String: UnitDisplayPlacement] {
        let visibleDivisions = state.divisions.filter { isDivisionVisible($0, viewerFaction: viewerFaction) }
        let grouped = Dictionary(grouping: visibleDivisions) { division in
            unitDisplayHex(for: division) ?? division.coord
        }

        var placements: [String: UnitDisplayPlacement] = [:]
        for (hex, divisions) in grouped {
            let sorted = divisions.sorted { lhs, rhs in
                lhs.id < rhs.id
            }
            for (index, division) in sorted.enumerated() {
                placements[division.id] = UnitDisplayPlacement(
                    divisionId: division.id,
                    hex: hex,
                    offset: stackOffset(index: index, count: sorted.count),
                    stackIndex: index,
                    stackCount: sorted.count
                )
            }
        }
        return placements
    }

    func divisions(displayedAt hex: HexCoord, viewerFaction: Faction) -> [Division] {
        let placements = unitPlacements(viewerFaction: viewerFaction)
        return state.divisions
            .filter { placements[$0.id]?.hex == hex }
            .sorted { lhs, rhs in
                if lhs.faction == viewerFaction, rhs.faction != viewerFaction {
                    return true
                }
                if lhs.faction != viewerFaction, rhs.faction == viewerFaction {
                    return false
                }
                return lhs.id < rhs.id
            }
    }

    func isDivisionVisible(_ division: Division, viewerFaction: Faction) -> Bool {
        if division.faction == viewerFaction {
            return true
        }

        guard let displayHex = unitDisplayHex(for: division) else {
            return false
        }
        return visibility(for: displayHex, faction: viewerFaction) == .visible
    }

    func inspectorState(for regionId: RegionId, selectedHex: HexCoord? = nil, viewerFaction: Faction) -> RegionInspectorState? {
        guard let region = state.map.region(id: regionId) else {
            return nil
        }

        let divisions = state.divisions.filter { division in
            division.location(in: state.map) == regionId
        }
        let friendly = divisions.filter { $0.faction == viewerFaction }
        let visibleEnemy = divisions.filter { division in
            isDiplomaticallyHostile(division.faction, to: viewerFaction) &&
                isDivisionVisible(division, viewerFaction: viewerFaction)
        }
        let visibleNonHostile = divisions.filter { division in
            division.faction != viewerFaction &&
                !isDiplomaticallyHostile(division.faction, to: viewerFaction) &&
                isDivisionVisible(division, viewerFaction: viewerFaction)
        }
        let visibleHostileDivisions = state.divisions.filter { division in
            isDiplomaticallyHostile(division.faction, to: viewerFaction) &&
                !division.isDestroyed &&
                isDivisionVisible(division, viewerFaction: viewerFaction)
        }
        let objectiveNames = state.map.objectives
            .filter { objective in
                region.displayHexes.contains(objective.coord)
            }
            .map(\.name)
        let objectiveStatus = objectiveNames.isEmpty
            ? "无"
            : "由\(region.controller.displayName)控制"

        let cityLevel = EconomyRules().cityLevel(for: region, map: state.map)
        let economicOutput = regionalEconomicOutput(for: region, cityLevel: cityLevel)
        let regionTiles = region.displayHexes.compactMap { state.map.tile(at: $0) }
        let roadHexCount = regionTiles.count { $0.hasRoad }
        let pressuredRoadHexCount = region.displayHexes.count { coord in
            state.map.tile(at: coord)?.hasRoad == true &&
                visibleHostileDivisions.contains { $0.coord.distance(to: coord) <= 1 }
        }
        let passableHexCount = regionTiles.count { $0.isPassable }
        let engagementAnchor = selectedHex ?? region.representativeHex
        let roadPressureSourceSummaries = roadPressureSummaries(
            for: region,
            hostileDivisions: visibleHostileDivisions,
            anchor: engagementAnchor
        )
        let selectedHexRoadStatusSummary = selectedHex.flatMap {
            selectedHexRoadStatusSummary(for: $0, hostileDivisions: visibleHostileDivisions)
        }
        let friendlyGeneralSummaries = friendly.compactMap { division -> String? in
            guard let generalName = generalDisplayName(for: division) else {
                return nil
            }
            return "\(division.thematicDisplayName)：\(generalName)"
        }
        let visibleEnemyEngagementSummaries = visibleEnemy
            .filter { !$0.isDestroyed }
            .sorted { lhs, rhs in
                let lhsDistance = lhs.coord.distance(to: engagementAnchor)
                let rhsDistance = rhs.coord.distance(to: engagementAnchor)
                if lhsDistance != rhsDistance {
                    return lhsDistance < rhsDistance
                }
                return lhs.id < rhs.id
            }
            .prefix(3)
            .map { division in
                enemyEngagementSummary(for: division, anchor: engagementAnchor)
            }
        let visibleNonHostileRelationSummaries = visibleNonHostile
            .filter { !$0.isDestroyed }
            .sorted { lhs, rhs in
                if lhs.faction != rhs.faction {
                    return lhs.faction.rawValue < rhs.faction.rawValue
                }
                return lhs.id < rhs.id
            }
            .prefix(3)
            .map { division in
                nonHostileRelationSummary(for: division, viewerFaction: viewerFaction)
            }

        let selectedHexDynamicTheaterId = selectedHex.flatMap {
            state.theaterState.dynamicTheaterId(for: $0, map: state.map)
        }
        let selectedHexFrontZoneId = selectedHex.flatMap {
            state.warDeploymentState.zoneId(for: $0, map: state.map)
        }
        let theaterId = state.theaterState.dominantDynamicTheaterId(for: regionId, map: state.map)
        let frontZoneId = dominantDynamicFrontZoneId(for: regionId)

        return RegionInspectorState(
            region: region,
            selectedHex: selectedHex,
            selectedHexController: selectedHex.flatMap { state.map.tile(at: $0)?.controller },
            selectedHexDynamicTheaterId: selectedHexDynamicTheaterId,
            selectedHexDynamicTheaterDisplayName: theaterDisplayName(for: selectedHexDynamicTheaterId),
            selectedHexFrontZoneId: selectedHexFrontZoneId,
            selectedHexFrontZoneDisplayName: frontZoneDisplayName(for: selectedHexFrontZoneId),
            selectedHexHasRoad: selectedHex.flatMap { state.map.tile(at: $0)?.hasRoad },
            selectedHexRoadStatusSummary: selectedHexRoadStatusSummary,
            theaterId: theaterId,
            theaterDisplayName: theaterDisplayName(for: theaterId),
            frontZoneId: frontZoneId,
            frontZoneDisplayName: frontZoneDisplayName(for: frontZoneId),
            frontPressure: state.frontLineState.regionStates[regionId]?.frontLines
                .flatMap(\.segments)
                .map(\.pressureLevel)
                .max() ?? 0,
            roadHexCount: roadHexCount,
            pressuredRoadHexCount: pressuredRoadHexCount,
            roadPressureSourceSummaries: roadPressureSourceSummaries,
            passableHexCount: passableHexCount,
            friendlyDivisions: friendly,
            visibleEnemyDivisions: visibleEnemy,
            visibleNonHostileDivisions: visibleNonHostile,
            friendlyGeneralSummaries: friendlyGeneralSummaries,
            visibleEnemyEngagementSummaries: Array(visibleEnemyEngagementSummaries),
            visibleNonHostileRelationSummaries: Array(visibleNonHostileRelationSummaries),
            objectiveNames: objectiveNames,
            objectiveStatus: objectiveStatus,
            cityLevel: cityLevel,
            economicOutput: economicOutput
        )
    }

    func unitInspectorState(for division: Division) -> UnitInspectorStrategicState {
        let regionId = division.location(in: state.map)
        let frontLineIds = regionId
            .flatMap { state.frontLineState.regionStates[$0]?.frontLines.map(\.id) } ?? []
        let frontZoneId = state.warDeploymentState.zoneId(for: division.coord, map: state.map)
        let dynamicTheaterId = state.theaterState.dynamicTheaterId(for: division.coord, map: state.map)
        return UnitInspectorStrategicState(
            coord: division.coord,
            coordDisplayName: hexDisplayName(division.coord),
            regionId: regionId,
            regionDisplayName: unitRegionDisplayName(for: regionId),
            dynamicTheaterId: dynamicTheaterId,
            dynamicTheaterDisplayName: theaterDisplayName(for: dynamicTheaterId),
            frontLineIds: frontLineIds.sorted { $0.rawValue < $1.rawValue },
            frontLineDisplayNames: frontLineIds
                .sorted { $0.rawValue < $1.rawValue }
                .map(frontLineDisplayName),
            frontZoneId: frontZoneId,
            frontZoneDisplayName: frontZoneDisplayName(for: frontZoneId),
            deploymentRole: WarDeploymentManager().deploymentRole(
                for: division,
                in: state.map,
                state: state.warDeploymentState,
                diplomacyState: state.diplomacyState
            ),
            generalAssignment: generalAssignment(for: division, fallbackZoneId: frontZoneId)
        )
    }

    private func generalAssignment(for division: Division, fallbackZoneId: FrontZoneId?) -> GeneralAssignment? {
        let zones = state.warDeploymentState.frontZones.values
            .filter { $0.faction == division.faction }
            .sorted { $0.id.rawValue < $1.id.rawValue }

        if let assigned = zones.first(where: {
            $0.generalAssignment?.assignedDivisionIds.contains(division.id) == true
        })?.generalAssignment {
            return assigned
        }

        guard let fallbackZoneId,
              let zone = state.warDeploymentState.frontZones[fallbackZoneId],
              zone.faction == division.faction else {
            return nil
        }
        return zone.generalAssignment
    }

    private func unitRegionDisplayName(for regionId: RegionId?) -> String? {
        guard let regionId else {
            return nil
        }
        let name = state.map.region(id: regionId)?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "未命名郡县" : name
    }

    private func hexDisplayName(_ coord: HexCoord) -> String {
        guard let tile = state.map.tile(at: coord) else {
            return "未知地格（\(coord.q),\(coord.r)）"
        }
        let anchor = displayAnchor(for: tile, coord: coord)
        let terrain = tile.hasRoad ? "官道" : tile.baseTerrain.displayName
        return "\(anchor)\(terrain)（\(coord.q),\(coord.r)）"
    }

    private func displayAnchor(for tile: HexTile, coord: HexCoord) -> String {
        let cityName = tile.cityName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !cityName.isEmpty {
            return cityName
        }
        let fortressName = tile.fortressName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fortressName.isEmpty {
            return fortressName
        }
        if let regionId = state.map.region(for: coord),
           let region = state.map.region(id: regionId) {
            let regionName = region.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !regionName.isEmpty && regionName != region.id.rawValue {
                return regionName
            }
        }
        return "地格"
    }

    private func theaterDisplayName(for theaterId: TheaterId?) -> String? {
        guard let theaterId else {
            return nil
        }
        guard let theater = state.theaterState.theaters[theaterId] else {
            return "未命名方面"
        }
        let name = theater.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isInternalDisplayName(name, rawValue: theaterId.rawValue) {
            return name
        }
        let regionSuffix = regionNameSuffix(for: theater.regionIds)
        if let faction = theater.controllingFaction {
            return "\(faction.shortDisplayName)方面\(regionSuffix)"
        }
        return "未命名方面\(regionSuffix)"
    }

    private func frontLineDisplayName(for frontLineId: FrontLineId) -> String {
        guard let frontLine = state.frontLineState.frontLines[frontLineId] else {
            return "未命名战线"
        }
        return "\(frontLine.factionA.shortDisplayName)-\(frontLine.factionB.shortDisplayName)战线"
    }

    private func frontZoneDisplayName(for frontZoneId: FrontZoneId?) -> String? {
        guard let frontZoneId else {
            return nil
        }
        guard let zone = state.warDeploymentState.frontZones[frontZoneId] else {
            return "未命名防区"
        }
        let name = zone.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isInternalDisplayName(name, rawValue: frontZoneId.rawValue) {
            return name
        }
        return "\(zone.faction.shortDisplayName)防区\(regionNameSuffix(for: zone.regionIds))"
    }

    private func isInternalDisplayName(_ name: String, rawValue: String) -> Bool {
        name.isEmpty || name == rawValue || name.contains("_")
    }

    private func regionNameSuffix(for regionIds: [RegionId]) -> String {
        let regionNames = regionIds.prefix(2).compactMap { regionId -> String? in
            let name = state.map.region(id: regionId)?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? nil : name
        }
        return regionNames.isEmpty ? "" : "：" + regionNames.joined(separator: "、")
    }

    private func generalDisplayName(for division: Division) -> String? {
        let zoneId = state.warDeploymentState.zoneId(for: division.coord, map: state.map)
        guard let assignment = generalAssignment(for: division, fallbackZoneId: zoneId) else {
            return nil
        }
        let displayName = assignment.generalDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return displayName.isEmpty ? "未命名武将" : displayName
    }

    private func enemyEngagementSummary(for division: Division, anchor: HexCoord) -> String {
        let distance = division.coord.distance(to: anchor)
        let rangeSummary = distance <= division.range
            ? "入射程"
            : "距射程 \(distance - division.range)"
        let generalSummary = generalDisplayName(for: division).map { "，敌将 \($0)" } ?? ""
        return "\(division.thematicDisplayName)：距 \(distance)，\(rangeSummary)，兵力 \(division.strength)/\(division.maxStrength)\(generalSummary)"
    }

    private func roadPressureSummaries(
        for region: RegionNode,
        hostileDivisions: [Division],
        anchor: HexCoord
    ) -> [String] {
        let roadHexes = region.displayHexes.filter { coord in
            state.map.tile(at: coord)?.hasRoad == true
        }
        let pressureSources = hostileDivisions.compactMap { enemy -> (
            enemy: Division,
            road: HexCoord,
            roadDistance: Int,
            anchorDistance: Int
        )? in
            guard let nearestRoad = roadHexes
                .filter({ enemy.coord.distance(to: $0) <= 1 })
                .sorted(by: { lhs, rhs in
                    let lhsRoadDistance = enemy.coord.distance(to: lhs)
                    let rhsRoadDistance = enemy.coord.distance(to: rhs)
                    if lhsRoadDistance != rhsRoadDistance {
                        return lhsRoadDistance < rhsRoadDistance
                    }
                    let lhsAnchorDistance = lhs.distance(to: anchor)
                    let rhsAnchorDistance = rhs.distance(to: anchor)
                    if lhsAnchorDistance != rhsAnchorDistance {
                        return lhsAnchorDistance < rhsAnchorDistance
                    }
                    return "\(lhs.q),\(lhs.r)" < "\(rhs.q),\(rhs.r)"
                })
                .first else {
                return nil
            }
            return (
                enemy,
                nearestRoad,
                enemy.coord.distance(to: nearestRoad),
                nearestRoad.distance(to: anchor)
            )
        }
        return pressureSources
            .sorted { lhs, rhs in
                if lhs.roadDistance != rhs.roadDistance {
                    return lhs.roadDistance < rhs.roadDistance
                }
                if lhs.anchorDistance != rhs.anchorDistance {
                    return lhs.anchorDistance < rhs.anchorDistance
                }
                return lhs.enemy.id < rhs.enemy.id
            }
            .prefix(3)
            .map { item in
                let generalSummary = generalDisplayName(for: item.enemy).map { "，敌将 \($0)" } ?? ""
                return "\(item.enemy.thematicDisplayName)：压迫官道 \(item.road.q),\(item.road.r)，距官道 \(item.roadDistance)，距锚点 \(item.anchorDistance)\(generalSummary)"
            }
    }

    private func selectedHexRoadStatusSummary(for hex: HexCoord, hostileDivisions: [Division]) -> String {
        guard state.map.tile(at: hex)?.hasRoad == true else {
            return "离官道"
        }

        let pressureSource = hostileDivisions
            .filter { $0.coord.distance(to: hex) <= 1 }
            .sorted { lhs, rhs in
                let lhsDistance = lhs.coord.distance(to: hex)
                let rhsDistance = rhs.coord.distance(to: hex)
                if lhsDistance != rhsDistance {
                    return lhsDistance < rhsDistance
                }
                if lhs.thematicDisplayName != rhs.thematicDisplayName {
                    return lhs.thematicDisplayName < rhs.thematicDisplayName
                }
                return lhs.id < rhs.id
            }
            .first

        guard let pressureSource else {
            return "据官道，未受可见敌军压迫"
        }

        let distance = pressureSource.coord.distance(to: hex)
        let generalSummary = generalDisplayName(for: pressureSource).map { "，敌将 \($0)" } ?? ""
        return "据官道，受 \(pressureSource.thematicDisplayName) 压迫，距 \(distance)\(generalSummary)"
    }

    private func nonHostileRelationSummary(for division: Division, viewerFaction: Faction) -> String {
        let relationSummary = diplomaticRelationSummary(from: viewerFaction, to: division.faction)
        let generalSummary = generalDisplayName(for: division).map { "，武将 \($0)" } ?? ""
        return "\(division.thematicDisplayName)：\(division.faction.shortDisplayName)，\(relationSummary)，非敌对\(generalSummary)"
    }

    private func diplomaticRelationSummary(from viewerFaction: Faction, to otherFaction: Faction) -> String {
        guard let viewerCountry = state.diplomacyState.primaryCountry(for: viewerFaction),
              let otherCountry = state.diplomacyState.primaryCountry(for: otherFaction) else {
            return "关系未建档"
        }
        guard let relation = state.diplomacyState.relation(between: viewerCountry.id, and: otherCountry.id) else {
            return "关系未建档"
        }
        return "\(relation.status.displayName)，紧张 \(relation.tension)"
    }

    private func isDiplomaticallyHostile(_ faction: Faction, to viewerFaction: Faction) -> Bool {
        state.diplomacyState.isHostile(between: faction, and: viewerFaction)
    }

    private func dominantDynamicFrontZoneId(for regionId: RegionId) -> FrontZoneId? {
        guard let region = state.map.region(id: regionId) else {
            return state.warDeploymentState.regionToFrontZone[regionId]
        }
        var counts: [FrontZoneId: Int] = [:]
        for hex in region.displayHexes {
            if let zoneId = state.warDeploymentState.zoneId(for: hex, map: state.map) {
                counts[zoneId, default: 0] += 1
            }
        }
        return counts.max {
            $0.value == $1.value ? $0.key.rawValue > $1.key.rawValue : $0.value < $1.value
        }?.key ?? state.warDeploymentState.regionToFrontZone[regionId]
    }

    private func terrain(for hex: HexCoord) -> BaseTerrain {
        if let regionId = regionId(for: hex),
           let region = state.map.region(id: regionId) {
            return region.terrain
        }
        return state.map.tile(at: hex)?.baseTerrain ?? .plain
    }

    private func controller(for hex: HexCoord) -> Faction? {
        if let regionId = regionId(for: hex),
           let region = state.map.region(id: regionId) {
            return region.controller
        }
        return state.map.tile(at: hex)?.controller
    }

    private func regionalEconomicOutput(for region: RegionNode, cityLevel: CityLevel) -> EconomyResources {
        let coreBonus = region.coreOf.isEmpty || region.coreOf.contains(region.controller) ? 1 : 0
        return EconomyResources(
            manpower: max(1, cityLevel.manpowerGrowth + coreBonus * 4 + region.infrastructure),
            industry: max(0, region.factories + cityLevel.industryValue + region.infrastructure / 3),
            supplies: max(1, region.supplyValue * 3 + region.factories + region.infrastructure / 2)
        )
    }

    private func stackOffset(index: Int, count: Int) -> CGPoint {
        guard count > 1 else {
            return .zero
        }

        let offsets: [CGPoint] = [
            CGPoint(x: -10, y: 8),
            CGPoint(x: 10, y: -8),
            CGPoint(x: -10, y: -8),
            CGPoint(x: 10, y: 8)
        ]
        return offsets[index % offsets.count]
    }
}
