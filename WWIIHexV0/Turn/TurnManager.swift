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
    let marshalAgent: MarshalAgent?
    let rulerAgent: RulerAgent?
    let diplomatAgent: DiplomatAgent?
    let governorAgent: GovernorAgent?
    let strategistAgent: StrategistAgent?
    let generalAgent: GeneralAgent?
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
        marshalAgent: MarshalAgent? = nil,
        rulerAgent: RulerAgent? = nil,
        diplomatAgent: DiplomatAgent? = nil,
        governorAgent: GovernorAgent? = nil,
        strategistAgent: StrategistAgent? = nil,
        generalAgent: GeneralAgent? = nil,
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
        self.marshalAgent = marshalAgent
        self.rulerAgent = rulerAgent
        self.diplomatAgent = diplomatAgent
        self.governorAgent = governorAgent
        self.strategistAgent = strategistAgent
        self.generalAgent = generalAgent
        self.warCommandExecutor = warCommandExecutor ?? WarCommandExecutor(commandHandler: commandHandler)
    }

    func runGermanAITurn(
        state: GameState,
        pipelineMode: WarPipelineMode = .marshalDirective
    ) async -> AgentTurnOutcome {
        await runAITurn(state: state, faction: .germany, pipelineMode: pipelineMode)
    }

    func runAITurn(
        state: GameState,
        faction: Faction,
        pipelineMode: WarPipelineMode = .marshalDirective
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
        case .marshalDirective:
            return runMarshalDirectiveTurn(
                state: state,
                faction: faction,
                contextSummary: contextSummary
            )
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
            let envelope = makeZoneDirectiveEnvelope(state: state, faction: faction, issuerId: agent.id)
            let rulerAdjustment = applyRulerAdjustment(to: envelope, state: state, faction: faction)
            let diplomatAdjustment = applyDiplomatPlanning(
                to: rulerAdjustment.envelope,
                state: rulerAdjustment.state,
                faction: faction,
                rulerRecord: rulerAdjustment.record
            )
            let governorAdjustment = applyGovernorPlanning(
                to: diplomatAdjustment.envelope,
                state: diplomatAdjustment.state,
                faction: faction,
                rulerRecord: rulerAdjustment.record
            )
            let diplomatJSON = try Self.canonicalDiplomatJSON(diplomatAdjustment.record)
            let strategistAdjustment = applyStrategistPlanning(
                to: governorAdjustment.envelope,
                state: governorAdjustment.state,
                faction: faction,
                rulerRecord: rulerAdjustment.record
            )
            let generalAdjustment = applyGeneralPlanning(
                to: strategistAdjustment.envelope,
                state: strategistAdjustment.state
            )
            let governorJSON = try Self.canonicalGovernorJSON(governorAdjustment.record)
            let generalJSON = try Self.canonicalDirectiveJSON(generalAdjustment.envelope)
            let rawJSON = [
                "Diplomat proposal JSON:\n\(diplomatJSON)",
                "Governor advice JSON:\n\(governorJSON)",
                "General-adjusted ZoneDirective JSON:\n\(generalJSON)"
            ].joined(separator: "\n\n")
            return executeDirectiveEnvelope(
                generalAdjustment.envelope,
                state: generalAdjustment.state,
                faction: faction,
                contextSummary: contextSummary,
                rawJSON: rawJSON,
                parsedIntent: "ruler-diplomat-governor-strategist-general-shaped zone directives",
                providerSuffix: "RulerDiplomatGovernorStrategistGeneralDirective",
                additionalDiagnostics: diagnostics
                    + rulerAdjustment.diagnostics
                    + diplomatAdjustment.diagnostics
                    + governorAdjustment.diagnostics
                    + strategistAdjustment.diagnostics
                    + generalAdjustment.diagnostics,
                preCommandResults: diplomatAdjustment.commandResults
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

    private func runMarshalDirectiveTurn(
        state: GameState,
        faction: Faction,
        contextSummary: String
    ) -> AgentTurnOutcome {
        do {
            let diagnostics = directiveDiagnostics(for: faction, state: state)
            let fallbackPool = commanderPool ?? TheaterCommanderPool.automatic(for: state)
            let marshal = marshalAgent ?? MarshalAgent(
                config: MarshalAgentConfig.automatic(for: faction, state: state)
            )
            let resolution = marshal.resolve(
                for: faction,
                in: state,
                fallbackPool: fallbackPool,
                issuerId: agent.id
            )
            let compiledJSON = try Self.canonicalDirectiveJSON(resolution.directiveEnvelope)
            let rulerAdjustment = applyRulerAdjustment(to: resolution.directiveEnvelope, state: state, faction: faction)
            let rulerJSON = try Self.canonicalDirectiveJSON(rulerAdjustment.envelope)
            let diplomatAdjustment = applyDiplomatPlanning(
                to: rulerAdjustment.envelope,
                state: rulerAdjustment.state,
                faction: faction,
                rulerRecord: rulerAdjustment.record
            )
            let diplomatJSON = try Self.canonicalDiplomatJSON(diplomatAdjustment.record)
            let governorAdjustment = applyGovernorPlanning(
                to: diplomatAdjustment.envelope,
                state: diplomatAdjustment.state,
                faction: faction,
                rulerRecord: rulerAdjustment.record
            )
            let governorJSON = try Self.canonicalGovernorJSON(governorAdjustment.record)
            let strategistAdjustment = applyStrategistPlanning(
                to: governorAdjustment.envelope,
                state: governorAdjustment.state,
                faction: faction,
                rulerRecord: rulerAdjustment.record
            )
            let strategistJSON = try Self.canonicalDirectiveJSON(strategistAdjustment.envelope)
            let generalAdjustment = applyGeneralPlanning(
                to: strategistAdjustment.envelope,
                state: strategistAdjustment.state
            )
            let generalJSON = try Self.canonicalDirectiveJSON(generalAdjustment.envelope)
            let rawJSON = [
                resolution.rawTheaterJSON,
                "Compiled ZoneDirective JSON:\n\(compiledJSON)",
                "Ruler-adjusted ZoneDirective JSON:\n\(rulerJSON)",
                "Diplomat proposal JSON:\n\(diplomatJSON)",
                "Governor advice JSON:\n\(governorJSON)",
                "Strategist-adjusted ZoneDirective JSON:\n\(strategistJSON)",
                "General-adjusted ZoneDirective JSON:\n\(generalJSON)"
            ]
            .compactMap { $0 }
            .joined(separator: "\n\n")

            return executeDirectiveEnvelope(
                generalAdjustment.envelope,
                state: generalAdjustment.state,
                faction: faction,
                contextSummary: contextSummary,
                rawJSON: rawJSON,
                parsedIntent: resolution.theaterEnvelope?.strategicIntent ?? "ruler-diplomat-governor-strategist-general-shaped marshal directives",
                providerSuffix: "RulerDiplomatGovernorStrategistGeneralMarshalDirective",
                additionalDiagnostics: diagnostics
                    + resolution.diagnostics
                    + rulerAdjustment.diagnostics
                    + diplomatAdjustment.diagnostics
                    + governorAdjustment.diagnostics
                    + strategistAdjustment.diagnostics
                    + generalAdjustment.diagnostics,
                preCommandResults: diplomatAdjustment.commandResults
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

    private func makeZoneDirectiveEnvelope(
        state: GameState,
        faction: Faction,
        issuerId: String
    ) -> DirectiveEnvelope {
        if state.warDeploymentState.frontZones.isEmpty {
            return DirectiveEnvelope(issuerId: issuerId, turn: state.turn, directives: [])
        }
        if let commanderPool {
            return commanderPool.envelope(for: faction, in: state, issuerId: issuerId)
        }
        return TheaterCommanderPool.automatic(for: state).envelope(for: faction, in: state, issuerId: issuerId)
    }

    private func applyRulerAdjustment(
        to envelope: DirectiveEnvelope,
        state: GameState,
        faction: Faction
    ) -> (state: GameState, envelope: DirectiveEnvelope, record: RulerDecisionRecord, diagnostics: [String]) {
        let ruler = rulerAgent ?? RulerAgent.automatic(for: faction, in: state)
        let adjustment = ruler.adjust(envelope: envelope, in: state)
        var nextState = state
        nextState.diplomacyState.appendRulerRecord(adjustment.record)
        nextState.appendEvent(
            "\(adjustment.record.rulerAgentId) 为 \(faction.displayName) 采取\(adjustment.record.posture.displayName)姿态。",
            category: .diplomacy
        )
        let targetSummary = adjustment.record.preferredFrontZoneId?.rawValue ?? "无"
        return (
            state: nextState,
            envelope: adjustment.envelope,
            record: adjustment.record,
            diagnostics: [
                "君主 \(adjustment.record.rulerAgentId) 以\(adjustment.record.posture.displayName)姿态塑形指令；优先防区 \(targetSummary)。"
            ]
        )
    }

    private func applyStrategistPlanning(
        to envelope: DirectiveEnvelope,
        state: GameState,
        faction: Faction,
        rulerRecord: RulerDecisionRecord?
    ) -> (state: GameState, envelope: DirectiveEnvelope, record: StrategistDecisionRecord, diagnostics: [String]) {
        let strategist = strategistAgent ?? StrategistAgent.automatic(for: faction, in: state)
        let adjustment = strategist.plan(envelope: envelope, in: state, rulerRecord: rulerRecord)
        var nextState = state
        nextState.appendStrategistRecord(adjustment.record)
        nextState.appendEvent(
            "\(adjustment.record.strategistAgentId) 编排 \(faction.displayName) 军令：\(adjustment.record.intent)",
            category: .event,
            relatedRecordId: adjustment.record.id
        )
        let targetSummary = adjustment.record.focusRegionIds.map(\.rawValue).joined(separator: ", ")
        return (
            state: nextState,
            envelope: adjustment.envelope,
            record: adjustment.record,
            diagnostics: [
                "军师 \(adjustment.record.strategistAgentId) 编排目标 \(targetSummary.isEmpty ? "无" : targetSummary)。"
            ]
        )
    }

    private func applyDiplomatPlanning(
        to envelope: DirectiveEnvelope,
        state: GameState,
        faction: Faction,
        rulerRecord: RulerDecisionRecord?
    ) -> (
        state: GameState,
        envelope: DirectiveEnvelope,
        record: DiplomatDecisionRecord,
        commandResults: [CommandResultSummary],
        diagnostics: [String]
    ) {
        let diplomat = diplomatAgent ?? DiplomatAgent.automatic(for: faction, in: state)
        let adjustment = diplomat.plan(envelope: envelope, in: state, rulerRecord: rulerRecord)
        var nextState = state
        nextState.diplomacyState.appendDiplomatRecord(adjustment.record)
        nextState.appendEvent(
            "\(adjustment.record.diplomatAgentId) 提出 \(faction.displayName) 外交方案：\(adjustment.record.summary)",
            category: .diplomacy,
            relatedRecordId: adjustment.record.id
        )
        let target = adjustment.record.targetCountryId?.rawValue ?? "无对象"
        var commandResults: [CommandResultSummary] = []
        var diagnostics = [
            "外交官 \(adjustment.record.diplomatAgentId) 建议\(adjustment.record.proposal.displayName)，对象 \(target)。"
        ]
        if let command = diplomacyCommand(for: adjustment.record) {
            let result = commandHandler.execute(command, in: nextState)
            nextState = result.state
            commandResults.append(.diplomatCommand(record: adjustment.record, result: result))
            if result.succeeded {
                diagnostics.append("外交提案已经规则层执行：\(command.displayName)。")
            } else {
                let reasons = result.validation.errors.map(\.rawValue).joined(separator: ", ")
                diagnostics.append("外交提案被规则层拒绝：\(reasons)。")
            }
        } else {
            diagnostics.append("外交提案缺少源国家或目标国家，未生成外交命令。")
        }

        return (
            state: nextState,
            envelope: adjustment.envelope,
            record: adjustment.record,
            commandResults: commandResults,
            diagnostics: diagnostics
        )
    }

    private func diplomacyCommand(for record: DiplomatDecisionRecord) -> Command? {
        guard let sourceCountryId = record.sourceCountryId,
              let targetCountryId = record.targetCountryId else {
            return nil
        }

        return .proposeDiplomacy(
            sourceCountryId: sourceCountryId,
            targetCountryId: targetCountryId,
            proposal: record.proposal
        )
    }

    private func applyGovernorPlanning(
        to envelope: DirectiveEnvelope,
        state: GameState,
        faction: Faction,
        rulerRecord: RulerDecisionRecord?
    ) -> (state: GameState, envelope: DirectiveEnvelope, record: GovernorDecisionRecord, diagnostics: [String]) {
        let governor = governorAgent ?? GovernorAgent.automatic(for: faction, in: state)
        let adjustment = governor.plan(envelope: envelope, in: state, rulerRecord: rulerRecord)
        var nextState = state
        nextState.appendGovernorRecord(adjustment.record)
        let recommendation = adjustment.record.recommendedProductionKind?.displayName ?? "不新增队列"
        nextState.appendEvent(
            "\(adjustment.record.governorAgentId) 建议 \(faction.displayName) \(adjustment.record.focus.displayName)：\(recommendation)",
            category: .supply,
            relatedRecordId: adjustment.record.id
        )
        let regions = adjustment.record.focusRegionIds.map(\.rawValue).joined(separator: ", ")
        return (
            state: nextState,
            envelope: adjustment.envelope,
            record: adjustment.record,
            diagnostics: [
                "太守 \(adjustment.record.governorAgentId) 建议\(adjustment.record.focus.displayName)；重点郡县 \(regions.isEmpty ? "无" : regions)。"
            ]
        )
    }

    private func applyGeneralPlanning(
        to envelope: DirectiveEnvelope,
        state: GameState
    ) -> (state: GameState, envelope: DirectiveEnvelope, records: [GeneralDecisionRecord], diagnostics: [String]) {
        let general = generalAgent ?? GeneralAgent()
        let adjustment = general.plan(envelope: envelope, in: state)
        var nextState = state
        nextState.appendGeneralRecords(adjustment.records)
        if !adjustment.records.isEmpty {
            let summary = adjustment.records
                .prefix(3)
                .map { "\($0.generalName ?? $0.generalId ?? "未分配") \($0.action)" }
                .joined(separator: "；")
            nextState.appendEvent(
                "武将层复核 \(adjustment.records.count) 条军令：\(summary)",
                category: .event
            )
        }
        return (
            state: nextState,
            envelope: adjustment.envelope,
            records: adjustment.records,
            diagnostics: adjustment.records.map {
                "武将 \($0.generalName ?? $0.generalId ?? "未分配") 在 \($0.zoneId.rawValue) \($0.action)。"
            }
        )
    }

    private func executeDirectiveEnvelope(
        _ envelope: DirectiveEnvelope,
        state: GameState,
        faction: Faction,
        contextSummary: String,
        rawJSON: String,
        parsedIntent: String,
        providerSuffix: String,
        additionalDiagnostics: [String],
        preCommandResults: [CommandResultSummary] = []
    ) -> AgentTurnOutcome {
        var nextState = state
        var commandResults: [CommandResultSummary] = preCommandResults
        var directiveRecords: [WarDirectiveRecord] = []
        var errors = additionalDiagnostics
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
                id: "war_directive_\(envelope.issuerId)_turn_\(state.turn)_\(directiveIndex)",
                issuerId: envelope.issuerId,
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

        if envelope.directives.isEmpty || !additionalDiagnostics.isEmpty {
            let record = WarDirectiveRecord(
                id: "war_directive_\(envelope.issuerId)_turn_\(state.turn)_diagnostic",
                issuerId: envelope.issuerId,
                turn: state.turn,
                faction: faction,
                zoneId: nil,
                directiveType: nil,
                commandResults: [],
                diagnostics: errors,
                commanderAgentId: envelope.commanderAgentId
            )
            nextState.warDirectiveRecords.append(record)
            directiveRecords.append(record)
        }

        return AgentTurnOutcome(
            state: nextState,
            record: AgentDecisionRecord(
                id: "agent_\(envelope.issuerId)_turn_\(state.turn)_directives",
                turn: state.turn,
                agentId: envelope.issuerId,
                provider: "\(providerName)+\(providerSuffix)",
                contextSummary: contextSummary,
                rawJSON: rawJSON,
                parsedIntent: parsedIntent,
                commandResults: commandResults,
                errors: errors
            ),
            directiveRecords: directiveRecords
        )
    }

    private func isAITurn(faction: Faction, state: GameState) -> Bool {
        switch faction {
        case .germany:
            return state.activeFaction == .germany && state.phase == .germanAI
        case .allies:
            return state.activeFaction == .allies && state.phase == .alliedPlayer
        case .cao, .yuan, .liuBei, .sun, .liuBiao, .maTeng, .han, .neutral:
            return false
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

    static func canonicalGovernorJSON(_ record: GovernorDecisionRecord) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(record)
        return String(decoding: data, as: UTF8.self)
    }

    static func canonicalDiplomatJSON(_ record: DiplomatDecisionRecord) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(record)
        return String(decoding: data, as: UTF8.self)
    }
}
