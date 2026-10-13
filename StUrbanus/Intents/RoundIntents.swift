import AppIntents
import SwiftData

// Siri-Befehle für die laufende Runde. Sie laufen ohne die App zu öffnen, auch bei
// gesperrtem iPhone, und antworten gesprochen (z. B. über die AirPods).

/// „Hey Siri, Urbanus Schlag“ → Siri fragt „Welcher Schlag?“ → „Drive rechts ins Aus“.
struct LogShotIntent: AppIntent {
    static let title: LocalizedStringResource = "Schlag erfassen"
    static let description = IntentDescription("Erfasst einen Schlag auf dem aktuellen Loch der laufenden Runde.")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Schlag", requestValueDialog: IntentDialog("Welcher Schlag?"))
    var phrase: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let reply = RoundService.handleVoice(phrase, in: AppModel.container.mainContext)
        return .result(dialog: "\(reply)")
    }
}

/// Gemeinsame Ausführung für die einfachen Rundenbefehle.
@MainActor
private func runRoundCommand(_ command: RoundCommand) -> String {
    let context = AppModel.container.mainContext
    guard let round = RoundService.activeRound(in: context) else { return RoundService.noActiveRound }
    return RoundService.apply(command, to: round, in: context)
}

struct NextHoleIntent: AppIntent {
    static let title: LocalizedStringResource = "Nächstes Loch"
    static let description = IntentDescription("Wechselt zum nächsten Loch der laufenden Runde.")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "\(runRoundCommand(.nextHole))")
    }
}

struct PreviousHoleIntent: AppIntent {
    static let title: LocalizedStringResource = "Vorheriges Loch"
    static let description = IntentDescription("Wechselt zum vorherigen Loch der laufenden Runde.")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "\(runRoundCommand(.previousHole))")
    }
}

struct UndoLastShotIntent: AppIntent {
    static let title: LocalizedStringResource = "Letzten Schlag löschen"
    static let description = IntentDescription("Löscht den zuletzt erfassten Schlag auf dem aktuellen Loch.")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "\(runRoundCommand(.undoLastShot))")
    }
}

struct ScoreIntent: AppIntent {
    static let title: LocalizedStringResource = "Spielstand"
    static let description = IntentDescription("Sagt den aktuellen Spielstand der laufenden Runde an.")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "\(runRoundCommand(.score))")
    }
}

struct EndRoundIntent: AppIntent {
    static let title: LocalizedStringResource = "Runde beenden"
    static let description = IntentDescription("Beendet die laufende Runde und sagt das Ergebnis an.")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "\(runRoundCommand(.endRound))")
    }
}

/// Siri-Sätze. Jeder Satz muss den App-Namen („Urbanus“) enthalten.
struct UrbanusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogShotIntent(),
            phrases: [
                "\(.applicationName) Schlag",
                "Schlag erfassen mit \(.applicationName)",
                "Schlag in \(.applicationName)",
                "Schlag mit \(.applicationName)",
                "Neuer Schlag in \(.applicationName)",
            ],
            shortTitle: "Schlag erfassen",
            systemImageName: "figure.golf"
        )
        AppShortcut(
            intent: NextHoleIntent(),
            phrases: [
                "\(.applicationName) nächstes Loch",
                "Nächstes Loch in \(.applicationName)",
                "Nächstes Loch mit \(.applicationName)",
                "\(.applicationName) weiter",
            ],
            shortTitle: "Nächstes Loch",
            systemImageName: "arrow.right.circle"
        )
        AppShortcut(
            intent: PreviousHoleIntent(),
            phrases: [
                "\(.applicationName) vorheriges Loch",
                "Vorheriges Loch in \(.applicationName)",
            ],
            shortTitle: "Vorheriges Loch",
            systemImageName: "arrow.left.circle"
        )
        AppShortcut(
            intent: UndoLastShotIntent(),
            phrases: [
                "\(.applicationName) letzten Schlag löschen",
                "Letzten Schlag löschen in \(.applicationName)",
            ],
            shortTitle: "Schlag löschen",
            systemImageName: "arrow.uturn.backward.circle"
        )
        AppShortcut(
            intent: ScoreIntent(),
            phrases: [
                "\(.applicationName) Spielstand",
                "Wie steht es in \(.applicationName)",
                "Spielstand in \(.applicationName)",
                "Spielstand mit \(.applicationName)",
            ],
            shortTitle: "Spielstand",
            systemImageName: "list.number"
        )
        AppShortcut(
            intent: EndRoundIntent(),
            phrases: [
                "\(.applicationName) Runde beenden",
                "Runde beenden in \(.applicationName)",
            ],
            shortTitle: "Runde beenden",
            systemImageName: "flag.checkered"
        )
    }
}
