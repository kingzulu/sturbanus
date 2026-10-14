import Foundation

/// Art des Schlags bzw. Schläger.
enum ShotType: String, Codable, CaseIterable, Identifiable, Sendable {
    case drive
    case woodHybrid
    case iron5
    case iron6
    case iron7
    case iron8
    case iron9
    case wedge
    case pitch
    case chip
    case bunker
    case putt
    // Frühere Sammelkategorien; nur noch zum Lesen älterer Einträge, nicht mehr auswählbar.
    case longIron
    case shortIronWedge

    var id: String { rawValue }

    /// Zur Auswahl angebotene Schlagarten (ohne die alten Sammelkategorien).
    static let selectable: [ShotType] = [
        .drive, .woodHybrid, .iron5, .iron6, .iron7, .iron8, .iron9, .wedge, .pitch, .chip, .bunker, .putt,
    ]

    var label: String {
        switch self {
        case .drive: "Drive"
        case .woodHybrid: "Holz/Hybrid"
        case .iron5: "Eisen 5"
        case .iron6: "Eisen 6"
        case .iron7: "Eisen 7"
        case .iron8: "Eisen 8"
        case .iron9: "Eisen 9"
        case .wedge: "Wedge"
        case .pitch: "Pitch"
        case .chip: "Chip"
        case .bunker: "Bunker"
        case .putt: "Putt"
        case .longIron: "Langes Eisen"
        case .shortIronWedge: "Kurzes Eisen/Wedge"
        }
    }

    var symbol: String {
        switch self {
        case .drive: "figure.golf"
        case .woodHybrid: "arrow.up.right"
        case .iron5, .iron6, .iron7, .iron8, .iron9, .longIron: "arrow.up.forward"
        case .wedge, .shortIronWedge: "arrow.up"
        case .pitch: "arrow.up.and.down"
        case .chip: "arrow.turn.right.up"
        case .bunker: "beach.umbrella"
        case .putt: "flag"
        }
    }
}

/// Ergebnis des Schlags.
enum ShotResult: String, Codable, CaseIterable, Identifiable, Sendable {
    case good
    case left
    case right
    case short
    case long

    var id: String { rawValue }

    var label: String {
        switch self {
        case .good: "Gut"
        case .left: "Links"
        case .right: "Rechts"
        case .short: "Zu kurz"
        case .long: "Zu lang"
        }
    }

    var symbol: String {
        switch self {
        case .good: "checkmark.circle.fill"
        case .left: "arrow.left"
        case .right: "arrow.right"
        case .short: "arrow.down"
        case .long: "arrow.up"
        }
    }
}

/// Optionale Folge eines Schlags: wo der Ball liegt bzw. was passiert ist.
enum ShotConsequence: String, Codable, CaseIterable, Identifiable, Sendable {
    case fairway
    case firstCut
    case green
    case rough
    case bunker
    case water
    case outOfBounds
    case penalty
    /// Ball ist im Loch; das Loch ist damit beendet.
    case holed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .holed: "Eingelocht"
        case .fairway: "Fairway"
        case .firstCut: "First Cut"
        case .green: "Grün"
        case .rough: "Rough"
        case .bunker: "Bunker"
        case .water: "Wasser"
        case .outOfBounds: "Aus"
        case .penalty: "Strafschlag"
        }
    }

    /// Strafschläge, die diese Folge kostet (Aus: Schlag und Distanz, Wasser: 1, Strafschlag: 1).
    var penaltyStrokes: Int {
        switch self {
        case .outOfBounds, .water, .penalty: 1
        case .fairway, .firstCut, .green, .rough, .bunker, .holed: 0
        }
    }
}
