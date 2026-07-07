import SwiftUI

struct EventLogView: View {
    let entries: [GameLogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("战报")
                .font(.headline)
                .foregroundStyle(SanguoDesignTokens.inkText)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if recentEntries.isEmpty {
                        Text("暂无战报。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentEntries) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.category.displayName)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(item.category.foregroundStyle)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(item.category.backgroundStyle)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))

                                    Text(metadata(for: item.entry))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Text(item.entry.message)
                                    .font(.body)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(minHeight: 120)
        }
        .padding(12)
        .background(SanguoDesignTokens.parchmentPanel.opacity(0.94))
        .overlay {
            RoundedRectangle(cornerRadius: SanguoDesignTokens.panelCornerRadius)
                .stroke(SanguoDesignTokens.panelStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: SanguoDesignTokens.panelCornerRadius))
    }

    private var recentEntries: [LogDisplayEntry] {
        entries
            .suffix(60)
            .reversed()
            .map { LogDisplayEntry(entry: $0, category: LogDisplayCategory(entry: $0)) }
    }

    private func metadata(for entry: GameLogEntry) -> String {
        let faction = entry.faction?.displayName ?? "系统"
        let phase = entry.phase?.displayName ?? "开局"
        if entry.relatedRecordId != nil {
            return "回合 \(entry.turn) - \(faction) - \(phase) - 军机审计"
        }
        return "回合 \(entry.turn) - \(faction) - \(phase)"
    }
}

private struct LogDisplayEntry: Identifiable {
    let entry: GameLogEntry
    let category: LogDisplayCategory

    var id: UUID {
        entry.id
    }
}

private enum LogDisplayCategory {
    case combat
    case retreat
    case reinforcement
    case encirclement
    case supply
    case frontChange
    case theaterChange
    case regionOwnerChange
    case diplomacy
    case event

    init(entry: GameLogEntry) {
        switch entry.category {
        case .combat:
            self = .combat
            return
        case .retreat:
            self = .retreat
            return
        case .reinforce:
            self = .reinforcement
            return
        case .encircle:
            self = .encirclement
            return
        case .supply:
            self = .supply
            return
        case .frontChange:
            self = .frontChange
            return
        case .theaterChange:
            self = .theaterChange
            return
        case .regionOwnerChange:
            self = .regionOwnerChange
            return
        case .diplomacy:
            self = .diplomacy
            return
        case .event:
            break
        }

        let message = entry.message
        let text = message.lowercased()

        if text.contains("retreat") || text.contains("routed") || text.contains("routing") || text.contains("撤退") {
            self = .retreat
        } else if text.contains("reinforce") || text.contains("replacement") || text.contains("replenish") || text.contains("补员") {
            self = .reinforcement
        } else if text.contains("encircle") || text.contains("encircled") || text.contains("合围") || text.contains("包围") {
            self = .encirclement
        } else if text.contains("attack") || text.contains("damage") || text.contains("combat") || text.contains("hit") || text.contains("进攻") || text.contains("战斗") {
            self = .combat
        } else if text.contains("supply") || text.contains("supplied") || text.contains("粮草") || text.contains("粮道") {
            self = .supply
        } else {
            self = .event
        }
    }

    var displayName: String {
        switch self {
        case .combat:
            return "战斗"
        case .retreat:
            return "撤退"
        case .reinforcement:
            return "补员"
        case .encirclement:
            return "合围"
        case .supply:
            return "粮草"
        case .frontChange:
            return "战线"
        case .theaterChange:
            return "方面"
        case .regionOwnerChange:
            return "郡县"
        case .diplomacy:
            return "外交"
        case .event:
            return "事件"
        }
    }

    var foregroundStyle: Color {
        switch self {
        case .combat:
            return SanguoDesignTokens.vermilion
        case .retreat:
            return SanguoDesignTokens.bronze
        case .reinforcement:
            return SanguoDesignTokens.jade
        case .encirclement:
            return Color(red: 0.42, green: 0.25, blue: 0.56)
        case .supply:
            return SanguoDesignTokens.riverBlue
        case .frontChange:
            return Color(red: 0.18, green: 0.34, blue: 0.58)
        case .theaterChange:
            return Color(red: 0.28, green: 0.24, blue: 0.48)
        case .regionOwnerChange:
            return Color(red: 0.24, green: 0.48, blue: 0.32)
        case .diplomacy:
            return Color(red: 0.10, green: 0.52, blue: 0.62)
        case .event:
            return .secondary
        }
    }

    var backgroundStyle: Color {
        foregroundStyle.opacity(0.12)
    }
}
