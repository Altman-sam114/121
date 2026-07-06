import SwiftUI

struct HUDView: View {
    let gameState: GameState
    let onEndTurn: () -> Void
    let onNewGame: (() -> Void)?

    init(gameState: GameState, onEndTurn: @escaping () -> Void, onNewGame: (() -> Void)? = nil) {
        self.gameState = gameState
        self.onEndTurn = onEndTurn
        self.onNewGame = onNewGame
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(SanguoDisplayLexicon.gameTitle)
                    .font(.headline)

                Spacer()

                if let onNewGame {
                    NewGameButton(action: onNewGame)
                }

                Button(action: onEndTurn) {
                    Label("结束回合", systemImage: "forward.end")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .frame(minHeight: SanguoDesignTokens.controlMinHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(SanguoDesignTokens.vermilion)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    metric("回合", "\(gameState.turn) / \(gameState.maxTurns)")
                    metric("势力", gameState.activeFaction.displayName)
                }

                GridRow {
                    metric("阶段", gameState.phase.displayName)
                    metric("胜负", victoryText)
                }

                GridRow {
                    metric("人口", "\(activeLedger.stockpile.manpower)")
                    metric("军械", "\(activeLedger.stockpile.industry)")
                }

                GridRow {
                    metric("粮草", "\(activeLedger.stockpile.supplies)")
                    metric("队列", "\(activeLedger.productionQueue.count)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .foregroundStyle(SanguoDesignTokens.inkText)
        .background(SanguoDesignTokens.parchmentPanel.opacity(0.96))
        .overlay {
            RoundedRectangle(cornerRadius: SanguoDesignTokens.panelCornerRadius)
                .stroke(SanguoDesignTokens.panelStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: SanguoDesignTokens.panelCornerRadius))
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(SanguoDesignTokens.mutedInk)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var victoryText: String {
        guard let winner = gameState.victoryState.winner else {
            return "未分胜负"
        }
        let victory = "\(winner.displayName) 胜利"
        guard let reason = gameState.victoryState.displayReason else {
            return victory
        }
        return "\(victory)：\(reason)"
    }

    private var activeLedger: FactionEconomyLedger {
        gameState.economyState.ledger(for: gameState.activeFaction)
    }
}
