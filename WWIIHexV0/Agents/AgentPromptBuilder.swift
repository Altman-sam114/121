import Foundation

// DEPRECATED as of v0.352 - kept for regression reference, not invoked by default. See WarPipelineMode.
// Builds LLM prompt from AgentContext. v0 keeps it simple; mostly for LocalLLMDecisionProvider.

struct AgentPromptBuilder {
    func makeRequest(
        context: AgentContext,
        model: String,
        temperature: Double = 0.2,
        maxTokens: Int = 1200
    ) -> LLMRequest {
        LLMRequest(
            model: model,
            systemPrompt: systemPrompt(context: context),
            userPrompt: userPrompt(context: context),
            temperature: temperature,
            maxTokens: maxTokens,
            responseFormat: "json_object"
        )
    }

    private func systemPrompt(context: AgentContext) -> String {
        """
        你是《三国棋策 Agent》的本地 LLM 军机决策层，负责把战场摘要转成结构化军令。
        执行者：\(context.agentId)
        势力：\(context.faction.displayName)（兼容 id：\(context.faction.rawValue)）
        性格：\(context.personality)

        只能返回符合 schema 的合法 JSON。不要输出散文、Markdown、注释或额外字段。
        不得假设不可见情报，不得修改规则，不得虚构军队，不得绕过命令校验。
        兼容字段 division 表示武将统领的军队。军令应尊重可见官道、粮草/补给状态、
        当前郡县控制和本回合可达的接战机会。
        """
    }

    private func userPrompt(context: AgentContext) -> String {
        let objectives = context.objectives
            .map { "\($0.name) 郡县id:\($0.regionId?.rawValue ?? "未知"), 控制:\($0.controller?.displayName ?? "中立")" }
            .joined(separator: "\n")
        let friendly = context.friendlyDivisions
            .map { "\($0.id) \($0.name) 兵力:\($0.strength)/\($0.maxStrength) 郡县id:\($0.regionId?.rawValue ?? "未知") 粮草:\($0.supplyState.displayName) 已行动:\($0.hasActed)" }
            .joined(separator: "\n")
        let enemies = context.enemyDivisions
            .map { "\($0.id) \($0.name) 兵力:\($0.strength)/\($0.maxStrength) 郡县id:\($0.regionId?.rawValue ?? "未知")" }
            .joined(separator: "\n")
        let regions = context.visibleRegions
            .filter(\.visible)
            .map { "\($0.id.rawValue) \($0.name) 地形:\($0.terrain.displayName) 控制:\($0.controller.displayName) 邻郡id:\($0.neighbors.map(\.rawValue).joined(separator: ","))" }
            .joined(separator: "\n")
        let recentEvents = context.recentEvents.map(\.message).joined(separator: "\n")

        return """
        当前任务：
        为该执行者麾下军队在第 \(context.turn) 回合、\(context.phase.displayName) 阶段下达作战军令。
        intent 和 reason 必须使用三国语义：武将、军队、郡县、官道、粮道、围城压力和可见交战。
        JSON key 与 command type value 必须严格保持下面列出的英文兼容值。

        可用军令：
        - move：需要 divisionId 和 toRegionId
        - attack：需要 divisionId 和 targetDivisionId
        - hold：需要 divisionId
        - resupply：需要 divisionId

        战场摘要：
        己方军队：
        \(friendly)

        已知敌对军队：
        \(enemies)

        目标：
        \(objectives)

        可见郡县：
        \(regions)

        粮草与补给：
        己方粮草充足 \(context.supplySummary.friendlySupplied)，粮草不足 \(context.supplySummary.friendlyLowSupply)，被围 \(context.supplySummary.friendlyEncircled)

        近期战报：
        \(recentEvents)

        玩家指示：
        \(context.playerDirective ?? "无")

        JSON schema:
        {
          "schemaVersion": 2,
          "agentId": "\(context.agentId)",
          "turn": \(context.turn),
          "intent": "简短三国作战意图",
          "orders": [
            {
              "type": "move|attack|hold|resupply",
              "divisionId": "既有军队 id",
              "toRegionId": "既有可见郡县 id",
              "targetDivisionId": null,
              "stance": null,
              "reason": "简短理由，相关时提到官道、粮草、武将姿态或可见交战"
            }
          ]
        }
        """
    }
}
