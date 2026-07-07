import Foundation

struct RuleEngine {
    private let validator = CommandValidator()
    private let executor = CommandExecutor()

    func execute(_ command: Command, in state: GameState) -> CommandResult {
        let preparedState = EconomyRules().bootstrapIfNeeded(state)
        let validation = validator.validate(command, in: preparedState)
        guard validation.isValid else {
            return CommandResult(
                command: command,
                validation: validation,
                state: preparedState,
                message: "命令被拒绝：\(validation.displayMessage)。"
            )
        }

        let nextState = executor.execute(command, in: preparedState)
        return CommandResult(
            command: command,
            validation: validation,
            state: nextState,
            message: "命令已执行：\(commandResultDisplayName(command, in: preparedState))。"
        )
    }

    func apply(_ command: Command, to state: GameState) -> GameState {
        execute(command, in: state).state
    }

    private func commandResultDisplayName(_ command: Command, in state: GameState) -> String {
        switch command {
        case .move(let divisionId, let destination):
            let unitName = divisionDisplayName(divisionId, in: state)
            let destinationName = destinationDisplayName(destination, in: state)
            return "\(unitName) 进军至 \(destinationName)"
        case .attack(let attackerId, let targetId):
            let attackerName = divisionDisplayName(attackerId, in: state)
            let targetName = divisionDisplayName(targetId, in: state)
            return "\(attackerName) 攻击 \(targetName)"
        case .hold(let divisionId):
            return "\(divisionDisplayName(divisionId, in: state)) 固守阵地"
        case .allowRetreat(let divisionId):
            return "\(divisionDisplayName(divisionId, in: state)) 改为机动撤退"
        case .resupply(let divisionId):
            return "\(divisionDisplayName(divisionId, in: state)) 补给休整"
        case .queueProduction(let kind):
            return "排产 \(kind.displayName)"
        case .improveRoad(let regionId):
            return "修缮 \(regionDisplayName(regionId, in: state.map)) 官道"
        case .proposeDiplomacy(let sourceCountryId, let targetCountryId, let proposal):
            let sourceName = countryDisplayName(sourceCountryId, in: state)
            let targetName = countryDisplayName(targetCountryId, in: state)
            return "\(sourceName) 向 \(targetName) 提出\(proposal.displayName)"
        case .endTurn:
            return "结束本回合"
        }
    }

    private func divisionDisplayName(_ divisionId: String, in state: GameState) -> String {
        guard let division = state.division(id: divisionId) else {
            return "未知军队"
        }
        return division.thematicDisplayName
    }

    private func destinationDisplayName(_ destination: HexCoord, in state: GameState) -> String {
        guard let tile = state.map.tile(at: destination) else {
            return "未知地格（\(destination.q),\(destination.r)）"
        }
        let anchor = displayAnchor(for: tile, coord: destination, in: state.map)
        let terrain = tile.hasRoad ? "官道" : tile.baseTerrain.displayName
        return "\(anchor)\(terrain)（\(destination.q),\(destination.r)）"
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
        if let regionId = map.region(for: coord) {
            let regionName = regionDisplayName(regionId, in: map)
            if regionName != "未知郡县" {
                return regionName
            }
        }
        return "地格"
    }

    private func regionDisplayName(_ regionId: RegionId, in map: MapState) -> String {
        guard let region = map.region(id: regionId) else {
            return "未知郡县"
        }

        let name = region.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty || name == regionId.rawValue ? "未知郡县" : name
    }

    private func countryDisplayName(_ countryId: CountryId, in state: GameState) -> String {
        guard let country = state.diplomacyState.countries.first(where: { $0.id == countryId }) else {
            return "未知势力"
        }

        let name = country.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty || name == countryId.rawValue
            ? country.faction.displayName
            : name
    }
}
