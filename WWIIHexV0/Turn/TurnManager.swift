import Foundation

// v0 TurnManager: only orchestrates German AI turn. Does not implement rules.
// Builds context -> provider -> JSON -> parser -> mapper -> RuleEngine -> record.

struct AgentTurnOutcome: Equatable {
    let state: GameState
    let record: AgentDecisionRecord
    let directiveRecords: [WarDirectiveRecord]

    init(
        state: GameState,
        record: AgentDecisionRecord,
        directiveRecords: [WarDirectiveRecord] = []
    ) {
        self.state = state
        self.record = record
        self.directiveRecords = directiveRecords
    }
}

struct TurnManager {
    let agent: GameAgent
    let provider: DecisionProvider
    let providerName: String
    let commandHandler: GameCommandHandling
    let contextBuilder: AgentContextBuilder
    let parser: AgentDecisionParser
    let mapper: AgentCommandMapper
    let commanderPool: TheaterCommanderPool?
    let warCommandExecutor: WarCommandExecutor

    init(
        agent: GameAgent,
        provider: DecisionProvider,
        providerName: String,
        commandHandler: GameCommandHandling,
        contextBuilder: AgentContextBuilder = AgentContextBuilder(),
        parser: AgentDecisionParser = AgentDecisionParser(),
        mapper: AgentCommandMapper = AgentCommandMapper(),
        commanderPool: TheaterCommanderPool? = nil,
        warCommandExecutor: WarCommandExecutor? = nil
    ) {
        self.agent = agent
        self.provider = provider
        self.providerName = providerName
        self.commandHandler = commandHandler
        self.contextBuilder = contextBuilder
        self.parser = parser
        self.mapper = mapper
        self.commanderPool = commanderPool
        self.warCommandExecutor = warCommandExecutor ?? WarCommandExecutor(commandHandler: commandHandler)
    }

    func runGermanAITurn(
        state: GameState,
        pipelineMode: WarPipelineMode = .zoneDirective
    ) async -> AgentTurnOutcome {
        await runAITurn(state: state, faction: .germany, pipelineMode: pipelineMode)
    }

    func runAITurn(
        state: GameState,
        faction: Faction,
        pipelineMode: WarPipelineMode = .zoneDirective
    ) async -> AgentTurnOutcome {
        let context = contextBuilder.agentContext(for: agent, state: state, playerDirective: nil)
        let contextSummary = Self.contextSummary(context)

        guard agent.faction == faction else {
            return AgentTurnOutcome(
                state: state,
                record: failureRecord(
                    state: state,
                    contextSummary: contextSummary,
                    rawJSON: nil,
                    parsedIntent: nil,
                    errors: ["AI turn requested for \(faction.displayName), but manager agent belongs to \(agent.faction.displayName)."]
                )
            )
        }

        guard isAITurn(faction: faction, state: state) else {
            return AgentTurnOutcome(
                state: state,
                record: failureRecord(
                    state: state,
                    contextSummary: contextSummary,
                    rawJSON: nil,
                    parsedIntent: nil,
                    errors: ["\(faction.displayName) AI turn requested outside its controllable phase."]
                )
            )
        }

        switch pipelineMode {
        case .zoneDirective:
            return runDirectiveTurn(
                state: state,
                faction: faction,
                contextSummary: contextSummary
            )
        case .legacyAgentOrder:
            return await runLegacyAgentOrderTurn(state: state, context: context, contextSummary: contextSummary)
        }
    }

    private func runLegacyAgentOrderTurn(
        state: GameState,
        context: AgentContext,
        contextSummary: String
    ) async -> AgentTurnOutcome {
        do {
            let envelope = try await provider.decide(context: context)
            let rawJSON = try Self.canonicalJSON(envelope)
            let parsedDecision = try parser.parse(rawJSON, expectedAgentId: agent.id, expectedTurn: state.turn)
            var nextState = state
            var commandResults: [CommandResultSummary] = []
            var errors: [String] = parsedDecision.orders.isEmpty ? ["Agent returned no orders."] : []

            for (index, order) in parsedDecision.orders.enumerated() {
                do {
                    let issuedCommand = try mapper.map(order, agentId: parsedDecision.agentId, state: nextState)
                    let result = commandHandler.execute(issuedCommand.command, in: nextState)
                    nextState = result.state
                    commandResults.append(
                        .mapped(orderIndex: index, order: order, command: issuedCommand.command, result: result)
                    )

                    if !result.succeeded {
                        errors.append("Order \(index) rejected: \(result.validation.errors.map(\.rawValue).joined(separator: ", ")).")
                    }
                } catch {
                    errors.append("Order \(index) mapping failed: \(error.localizedDescription)")
                    commandResults.append(.mappingFailed(orderIndex: index, order: order, error: error))
                }
            }

            let endTurnResult = commandHandler.execute(.endTurn, in: nextState)
            nextState = endTurnResult.state
            commandResults.append(.endTurn(result: endTurnResult))
            if !endTurnResult.succeeded {
                errors.append("AI end turn failed: \(endTurnResult.validation.errors.map(\.rawValue).joined(separator: ", ")).")
            }

            let record = AgentDecisionRecord(
                id: "agent_\(agent.id)_turn_\(state.turn)",
                turn: state.turn,
                agentId: agent.id,
                provider: providerName,
                contextSummary: contextSummary,
                rawJSON: rawJSON,
                parsedIntent: parsedDecision.intent,
                commandResults: commandResults,
                errors: errors
            )
            return AgentTurnOutcome(state: nextState, record: record)
        } catch {
            return AgentTurnOutcome(
                state: state,
                record: failureRecord(
                    state: state,
                    contextSummary: contextSummary,
                    rawJSON: nil,
                    parsedIntent: nil,
                    errors: [error.localizedDescription]
                )
            )
        }
    }

    private func runDirectiveTurn(
        state: GameState,
        faction: Faction,
        contextSummary: String
    ) -> AgentTurnOutcome {
        do {
            let diagnostics = directiveDiagnostics(for: faction, state: state)
            let envelope: DirectiveEnvelope
            if state.warDeploymentState.frontZones.isEmpty {
                envelope = DirectiveEnvelope(issuerId: agent.id, turn: state.turn, directives: [])
            } else if let commanderPool {
                envelope = commanderPool.envelope(for: faction, in: state, issuerId: agent.id)
            } else {
                envelope = TheaterCommanderPool.automatic(for: state).envelope(for: faction, in: state, issuerId: agent.id)
            }
            let rawJSON = try Self.canonicalDirectiveJSON(envelope)
            var nextState = state
            var commandResults: [CommandResultSummary] = []
            var directiveRecords: [WarDirectiveRecord] = []
            var errors = diagnostics
            if envelope.directives.isEmpty {
                errors.append("Commander returned no directives.")
            }

            for (directiveIndex, directive) in envelope.directives.enumerated() {
                let execution = warCommandExecutor.execute(directive, in: nextState)
                nextState = execution.finalState
                var perDirectiveResults: [CommandResultSummary] = []
                var perDirectiveDiagnostics: [String] = []

                if execution.generatedCommands.isEmpty {
                    let diagnostic = "Directive \(directiveIndex) generated no executable commands."
                    errors.append(diagnostic)
                    perDirectiveDiagnostics.append(diagnostic)
                }

                for (commandIndex, pair) in zip(execution.generatedCommands, execution.commandResults).enumerated() {
                    let summary = CommandResultSummary.directiveCommand(
                        directiveIndex: directiveIndex,
                        commandIndex: commandIndex,
                        directive: directive,
                        command: pair.0,
                        result: pair.1
                    )
                    commandResults.append(summary)
                    perDirectiveResults.append(summary)
                    if !pair.1.succeeded {
                        let diagnostic = "Directive \(directiveIndex) command \(commandIndex) rejected: \(pair.1.validation.errors.map(\.rawValue).joined(separator: ", "))."
                        errors.append(diagnostic)
                        perDirectiveDiagnostics.append(diagnostic)
                    }
                }

                let record = WarDirectiveRecord(
                    id: "war_directive_\(agent.id)_turn_\(state.turn)_\(directiveIndex)",
                    issuerId: agent.id,
                    turn: state.turn,
                    faction: faction,
                    zoneId: directive.zoneId,
                    directiveType: directive.type,
                    targetRegionIds: directive.targetRegionIds,
                    commandResults: perDirectiveResults,
                    diagnostics: perDirectiveDiagnostics,
                    category: directive.category,
                    tactic: directive.tactic,
                    commanderAgentId: envelope.commanderAgentId,
                    commandTarget: directive.commandTarget
                )
                nextState.warDirectiveRecords.append(record)
                directiveRecords.append(record)
            }

            let endTurnResult = commandHandler.execute(.endTurn, in: nextState)
            nextState = endTurnResult.state
            commandResults.append(.endTurn(result: endTurnResult))
            if !endTurnResult.succeeded {
                errors.append("AI end turn failed: \(endTurnResult.validation.errors.map(\.rawValue).joined(separator: ", ")).")
            }

            if envelope.directives.isEmpty || !diagnostics.isEmpty {
                let record = WarDirectiveRecord(
                    id: "war_directive_\(agent.id)_turn_\(state.turn)_diagnostic",
                    issuerId: agent.id,
                    turn: state.turn,
                    faction: faction,
                    zoneId: nil,
                    directiveType: nil,
                    commandResults: [],
                    diagnostics: errors
                )
                nextState.warDirectiveRecords.append(record)
                directiveRecords.append(record)
            }

            return AgentTurnOutcome(
                state: nextState,
                record: AgentDecisionRecord(
                    id: "agent_\(agent.id)_turn_\(state.turn)_directives",
                    turn: state.turn,
                    agentId: agent.id,
                    provider: "\(providerName)+Directive",
                    contextSummary: contextSummary,
                    rawJSON: rawJSON,
                    parsedIntent: "v0.352 zone directives",
                    commandResults: commandResults,
                    errors: errors
                ),
                directiveRecords: directiveRecords
            )
        } catch {
            return AgentTurnOutcome(
                state: state,
                record: failureRecord(
                    state: state,
                    contextSummary: contextSummary,
                    rawJSON: nil,
                    parsedIntent: nil,
                    errors: [error.localizedDescription]
                )
            )
        }
    }

    private func isAITurn(faction: Faction, state: GameState) -> Bool {
        switch faction {
        case .germany:
            return state.activeFaction == .germany && state.phase == .germanAI
        case .allies:
            return state.activeFaction == .allies && state.phase == .alliedPlayer
        }
    }

    private func directiveDiagnostics(for faction: Faction, state: GameState) -> [String] {
        var diagnostics: [String] = []
        if state.warDeploymentState.frontZones.isEmpty {
            diagnostics.append("ZoneDirective pipeline selected but WarDeploymentState has no FrontZone data; legacy pipeline was not invoked.")
        }

        for division in state.divisions where division.faction == faction && !division.isDestroyed {
            guard let regionId = division.location(in: state.map),
                  state.warDeploymentState.regionToFrontZone[regionId] != nil else {
                diagnostics.append("Division \(division.id) is not assigned to any FrontZone; no directive generated for this unit.")
                continue
            }
        }

        return diagnostics
    }

    private func failureRecord(
        state: GameState,
        contextSummary: String,
        rawJSON: String?,
        parsedIntent: String?,
        errors: [String]
    ) -> AgentDecisionRecord {
        AgentDecisionRecord(
            id: "agent_\(agent.id)_turn_\(state.turn)_failed",
            turn: state.turn,
            agentId: agent.id,
            provider: providerName,
            contextSummary: contextSummary,
            rawJSON: rawJSON,
            parsedIntent: parsedIntent,
            commandResults: [],
            errors: errors
        )
    }

    static func contextSummary(_ context: AgentContext) -> String {
        "\(context.agentId) turn \(context.turn): \(context.friendlyDivisions.count) friendly divisions, \(context.enemyDivisions.count) known enemy divisions, \(context.objectives.count) objectives visible."
    }

    static func canonicalJSON(_ envelope: AgentDecisionEnvelope) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(envelope)
        return String(decoding: data, as: UTF8.self)
    }

    static func canonicalDirectiveJSON(_ envelope: DirectiveEnvelope) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(envelope)
        return String(decoding: data, as: UTF8.self)
    }
}
