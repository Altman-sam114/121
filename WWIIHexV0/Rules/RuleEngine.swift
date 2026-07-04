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
            message: "命令已执行：\(command.displayName)。"
        )
    }

    func apply(_ command: Command, to state: GameState) -> GameState {
        execute(command, in: state).state
    }
}
