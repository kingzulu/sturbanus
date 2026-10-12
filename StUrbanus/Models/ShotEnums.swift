import Foundation

/// Art des Schlags.
enum ShotType: String, Codable, CaseIterable, Identifiable, Sendable {
    case drive
    case woodHybrid
    case longIron
    case shortIronWedge
    case pitch
    case chip
    case bunker
    case putt

    var id: String { rawValue }

    var label: String {
        switch self {
        case .drive: "Drive"
        case .woodHybrid: "Holz/Hybrid"
        case .longIron: "Langes Eisen"
        case .shortIronWedge: "Kurzes Eisen/Wedge"
        case .pitch: "Pitch"
        case .chip: "Chip"
        case .bunker: "Bunker"
        case .putt: "Putt"
        }
    }

    var symbol: String {
        switch self {
        case .drive: "figure.golf"
        case .woodHybrid: "arrow.up.right"
        case .longIron: "arrow.up.forward"
        case .shortIronWedge: "arrow.up"
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

/// Optionale Folge eines Schlags.
enum ShotConsequence: String, Codable, CaseIterable, Identifiable, Sendable {
    case outOfBounds
    case water
    case bunker
    case rough
    case penalty

    var id: String { rawValue }

    var label: String {
        switch self {
        case .outOfBounds: "Aus"
        case .water: "Wasser"
        case .bunker: "Bunker"
        case .rough: "Rough"
        case .penalty: "Strafschlag"
        }
    }

    /// Strafschläge, die diese Folge kostet (Aus: Schlag und Distanz, Wasser: 1, Strafschlag: 1).
    var penaltyStrokes: Int {
        switch self {
        case .outOfBounds, .water, .penalty: 1
        case .bunker, .rough: 0
        }
    }
}
