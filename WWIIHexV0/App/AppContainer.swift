import Combine
import Foundation

final class AppContainer: ObservableObject {
    @Published private(set) var gameState: GameState
    @Published private(set) var selectedUnitId: String?
    @Published private(set) var selectedHex: HexCoord?
    @Published private(set) var selectedRegionId: RegionId?
    @Published private(set) var movementHighlights: Set<HexCoord>
    @Published private(set) var attackHighlights: Set<HexCoord>
    @Published private(set) var interactionLog: [GameLogEntry]
    @Published private(set) var lastCommandMessage: String?
    @Published private(set) var lastAgentDecisionRecord: AgentDecisionRecord?
    @Published private(set) var lastWarDirectiveRecords: [WarDirectiveRecord]
    @Published private(set) var observerModeEnabled: Bool
    @Published private(set) var mapDisplayLayer: MapDisplayLayer

    let commandHandler: GameCommandHandling
    let dataLoader: DataLoader
    let playerFaction: Faction
    let warPipelineMode: WarPipelineMode
    let turnManager: TurnManager?
    private var isRunningAI = false

    init(
        gameState: GameState,
        commandHandler: GameCommandHandling,
        dataLoader: DataLoader,
        playerFaction: Faction = .allies,
        turnManager: TurnManager? = nil,
        warPipelineMode: WarPipelineMode = .zoneDirective,
        observerModeEnabled: Bool = false,
        mapDisplayLayer: MapDisplayLayer = .hex
    ) {
        self.gameState = StrategicStateBootstrapper().bootstrapIfNeeded(gameState)
        self.commandHandler = commandHandler
        self.dataLoader = dataLoader
        self.playerFaction = playerFaction
        self.warPipelineMode = warPipelineMode
        self.turnManager = turnManager
        self.selectedUnitId = nil
        self.selectedHex = nil
        self.selectedRegionId = nil
        self.movementHighlights = []
        self.attackHighlights = []
        self.interactionLog = []
        self.lastCommandMessage = nil
        self.lastAgentDecisionRecord = nil
        self.lastWarDirectiveRecords = []
        self.observerModeEnabled = observerModeEnabled
        self.mapDisplayLayer = mapDisplayLayer
    }

    static func bootstrap() -> AppContainer {
        let dataLoader = DataLoader()
        let gameState = dataLoader.loadInitialGameState()
        let commandHandler = RuleEngine()
        let guderian = GameAgent.guderian(from: dataLoader, state: gameState)
        let bootstrappedState = StrategicStateBootstrapper().bootstrapIfNeeded(gameState)
        let turnManager = TurnManager(
            agent: guderian,
            provider: MockAIClient(),
            providerName: "MockAI",
            commandHandler: commandHandler,
            commanderPool: Self.buildCommanderPool(state: bootstrappedState)
        )
        return AppContainer(
            gameState: bootstrappedState,
            commandHandler: commandHandler,
            dataLoader: dataLoader,
            turnManager: turnManager
        )
    }

    func submit(_ command: Command) {
        let result = commandHandler.execute(command, in: gameState)
        gameState = StrategicStateBootstrapper().bootstrapIfNeeded(result.state)
        lastCommandMessage = result.message

        let status = result.succeeded ? "accepted" : "rejected"
        appendInteractionEvent("Command \(status): \(command.displayName). \(result.message)")
        refreshSelectionAfterStateChange()
        runAIIfNeeded()
    }

    func runAIIfNeeded() {
        guard !isRunningAI else {
            return
        }

        gameState = StrategicStateBootstrapper().refreshRuntimeState(gameState)
        guard shouldRunAI(for: gameState.activeFaction, phase: gameState.phase) else {
            return
        }

        isRunningAI = true
        let stateSnapshot = gameState
        let pipelineMode = warPipelineMode
        let observerEnabled = observerModeEnabled

        Task {
            let outcome = await self.runAISequence(
                from: stateSnapshot,
                pipelineMode: pipelineMode,
                observerEnabled: observerEnabled
            )
            await MainActor.run {
                self.gameState = outcome.state
                self.lastAgentDecisionRecord = outcome.record
                self.lastWarDirectiveRecords = outcome.directiveRecords
                self.lastCommandMessage = outcome.record.errors.isEmpty
                    ? "AI turn completed."
                    : "AI turn completed with \(outcome.record.errors.count) issue(s)."
                self.appendInteractionEvent("AI \(outcome.record.provider) resolved \(outcome.record.commandResults.count) command result(s).")
                self.isRunningAI = false
                self.refreshSelectionAfterStateChange()
            }
        }
    }

    func handleBoardTap(_ coord: HexCoord) {
        guard gameState.map.contains(coord) else {
            return
        }

        selectedHex = coord
        selectedRegionId = mapDisplayAdapter.regionId(for: coord)
        appendInteractionEvent(selectionMessage(for: coord))

        let displayedDivisions = mapDisplayAdapter.divisions(displayedAt: coord, viewerFaction: playerFaction)
        if let attacker = selectedActionDivision,
           let enemy = displayedDivisions.first(where: { $0.faction != attacker.faction }) {
            submit(.attack(attackerId: attacker.id, targetId: enemy.id))
            return
        }

        if let tappedDivision = displayedDivisions.first {
            handleDivisionTap(tappedDivision)
            return
        }

        if let division = selectedActionDivision {
            submitMove(division: division, tappedHex: coord)
        } else {
            selectedUnitId = nil
            clearHighlights()
        }
    }

    func holdSelected() {
        guard let division = selectedActionDivision else {
            appendInteractionEvent("Hold rejected: no active allied unit selected.")
            return
        }

        submit(.hold(divisionId: division.id))
    }

    func allowRetreatSelected() {
        guard let division = selectedActionDivision else {
            appendInteractionEvent("Allow retreat rejected: no active allied unit selected.")
            return
        }

        submit(.allowRetreat(divisionId: division.id))
    }

    func resupplySelected() {
        guard let division = selectedActionDivision else {
            appendInteractionEvent("Resupply rejected: no active allied unit selected.")
            return
        }

        submit(.resupply(divisionId: division.id))
    }

    func endTurn() {
        submit(.endTurn)
    }

    func advanceOrRunAI() {
        if shouldRunAI(for: gameState.activeFaction, phase: gameState.phase) {
            runAIIfNeeded()
        } else {
            endTurn()
        }
    }

    func setObserverModeEnabled(_ enabled: Bool) {
        observerModeEnabled = enabled
    }

    func setMapDisplayLayer(_ layer: MapDisplayLayer) {
        mapDisplayLayer = layer
    }

    func resetGame() {
        isRunningAI = false
        gameState = StrategicStateBootstrapper().bootstrapIfNeeded(dataLoader.loadInitialGameState())
        selectedUnitId = nil
        selectedHex = nil
        selectedRegionId = nil
        movementHighlights = []
        attackHighlights = []
        interactionLog = []
        lastCommandMessage = nil
        lastAgentDecisionRecord = nil
        lastWarDirectiveRecords = []
    }

    var selectedDivision: Division? {
        guard let selectedUnitId else {
            return nil
        }
        return gameState.division(id: selectedUnitId)
    }

    var selectedRegionInspectorState: RegionInspectorState? {
        guard let selectedRegionId else {
            return nil
        }
        return mapDisplayAdapter.inspectorState(for: selectedRegionId, selectedHex: selectedHex, viewerFaction: playerFaction)
    }

    var selectedUnitInspectorStrategicState: UnitInspectorStrategicState? {
        guard let selectedDivision else {
            return nil
        }
        return mapDisplayAdapter.unitInspectorState(for: selectedDivision)
    }

    var displayEventLog: [GameLogEntry] {
        Array((gameState.eventLog + interactionLog).suffix(80))
    }

    var selectedUnitCanAct: Bool {
        selectedActionDivision != nil
    }

    private var selectedActionDivision: Division? {
        guard !observerModeEnabled else {
            return nil
        }
        guard let division = selectedDivision,
              division.faction == playerFaction,
              gameState.activeFaction == playerFaction,
              gameState.phase == .alliedPlayer,
              !division.hasActed else {
            return nil
        }

        return division
    }

    private var mapDisplayAdapter: MapDisplayAdapter {
        MapDisplayAdapter(state: gameState, revealAll: observerModeEnabled)
    }

    private func shouldRunAI(for faction: Faction, phase: GamePhase) -> Bool {
        switch faction {
        case .germany:
            return phase == .germanAI
        case .allies:
            return observerModeEnabled && phase == .alliedPlayer
        }
    }

    private func runAISequence(
        from state: GameState,
        pipelineMode: WarPipelineMode,
        observerEnabled: Bool
    ) async -> AgentTurnOutcome {
        var currentState = StrategicStateBootstrapper().refreshRuntimeState(state)
        var lastOutcome: AgentTurnOutcome?
        let maxSteps = observerEnabled ? 2 : 1

        for _ in 0..<maxSteps {
            currentState = StrategicStateBootstrapper().refreshRuntimeState(currentState)
            guard shouldRunAIInSnapshot(state: currentState, observerEnabled: observerEnabled) else {
                break
            }

            let manager = turnManager(for: currentState.activeFaction, state: currentState)
            let outcome = await manager.runAITurn(
                state: currentState,
                faction: currentState.activeFaction,
                pipelineMode: pipelineMode
            )
            currentState = StrategicStateBootstrapper().refreshRuntimeState(outcome.state)
            lastOutcome = AgentTurnOutcome(
                state: currentState,
                record: outcome.record,
                directiveRecords: (lastOutcome?.directiveRecords ?? []) + outcome.directiveRecords
            )
        }

        return lastOutcome ?? AgentTurnOutcome(
            state: currentState,
            record: AgentDecisionRecord(
                id: "agent_noop_turn_\(currentState.turn)",
                turn: currentState.turn,
                agentId: "system",
                provider: "System",
                contextSummary: "No AI faction was active.",
                rawJSON: nil,
                parsedIntent: nil,
                commandResults: [],
                errors: []
            )
        )
    }

    private func shouldRunAIInSnapshot(state: GameState, observerEnabled: Bool) -> Bool {
        switch state.activeFaction {
        case .germany:
            return state.phase == .germanAI
        case .allies:
            return observerEnabled && state.phase == .alliedPlayer
        }
    }

    private func turnManager(for faction: Faction, state: GameState) -> TurnManager {
        if faction == .germany, let turnManager {
            return turnManager
        }

        let agent: GameAgent
        switch faction {
        case .germany:
            agent = GameAgent.guderian(from: dataLoader, state: state)
        case .allies:
            let assignedIds = state.divisions
                .filter { $0.faction == .allies && !$0.isDestroyed }
                .map(\.id)
            agent = GameAgent.sample(
                id: "allied_mock_commander",
                name: "Allied Mock Commander",
                faction: .allies,
                role: .armyCommander,
                assignedDivisionIds: assignedIds
            )
        }

        return TurnManager(
            agent: agent,
            provider: MockAIClient(),
            providerName: "MockAI",
            commandHandler: commandHandler,
            commanderPool: Self.buildCommanderPool(state: state)
        )
    }

    private static func buildCommanderPool(state: GameState) -> TheaterCommanderPool {
        let agents: [any ZoneCommanderProviding] = state.warDeploymentState.frontZones.values
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .map { zone in
                let style: ZoneCommanderAgentConfig.CommandStyle = zone.faction == .germany ? .aggressive : .balanced
                let factionName = zone.faction == .germany ? "German" : "Allied"
                let config = ZoneCommanderAgentConfig(
                    id: "auto_\(zone.id.rawValue)",
                    name: "\(factionName) Commander (\(zone.id.rawValue))",
                    faction: zone.faction,
                    assignedZoneId: zone.id,
                    skills: [],
                    commandStyle: style
                )
                return ZoneCommanderAgent(config: config)
            }
        return TheaterCommanderPool(commanders: agents)
    }

    private func handleDivisionTap(_ division: Division) {
        if observerModeEnabled {
            selectDivision(division)
            appendInteractionEvent("Inspecting unit: \(division.name).")
            return
        }

        if division.faction == playerFaction {
            selectDivision(division)
            appendInteractionEvent("Selected unit: \(division.name).")
            return
        }

        if let attacker = selectedActionDivision {
            submit(.attack(attackerId: attacker.id, targetId: division.id))
        } else {
            selectDivision(division)
            appendInteractionEvent("Selected enemy unit: \(division.name).")
        }
    }

    private func selectDivision(_ division: Division) {
        selectedUnitId = division.id
        selectedHex = mapDisplayAdapter.unitDisplayHex(for: division) ?? division.coord
        selectedRegionId = division.location(in: gameState.map)
        refreshHighlights()
    }

    private func refreshSelectionAfterStateChange() {
        if let selectedUnitId,
           gameState.division(id: selectedUnitId) == nil {
            self.selectedUnitId = nil
        }

        if let selectedDivision {
            selectedHex = mapDisplayAdapter.unitDisplayHex(for: selectedDivision) ?? selectedDivision.coord
            selectedRegionId = selectedDivision.location(in: gameState.map)
        }

        refreshHighlights()
    }

    private func refreshHighlights() {
        guard let division = selectedActionDivision else {
            clearHighlights()
            return
        }

        movementHighlights = MovementRules().movementRange(for: division, in: gameState)
        attackHighlights = Set(
            gameState.divisions
                .filter { $0.faction != division.faction && division.coord.distance(to: $0.coord) <= division.range }
                .map(\.coord)
        )
    }

    private func clearHighlights() {
        movementHighlights = []
        attackHighlights = []
    }

    private func submitMove(division: Division, tappedHex: HexCoord) {
        submit(.move(divisionId: division.id, destination: tappedHex))
    }

    private func selectionMessage(for coord: HexCoord) -> String {
        guard let selectedRegionId,
              let region = gameState.map.region(id: selectedRegionId) else {
            return "Selected hex \(coord.q),\(coord.r)."
        }
        return "Selected region: \(region.name) (\(selectedRegionId.rawValue))."
    }

    private func appendInteractionEvent(_ message: String) {
        interactionLog.append(
            GameLogEntry(
                turn: gameState.turn,
                faction: gameState.activeFaction,
                phase: gameState.phase,
                message: message,
                createdAt: Date()
            )
        )

        if interactionLog.count > 80 {
            interactionLog.removeFirst(interactionLog.count - 80)
        }
    }

}
