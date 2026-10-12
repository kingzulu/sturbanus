import SwiftUI

/// Erfassung per Tipp in drei Schritten: Schlagart → Ergebnis → optionale Folge.
struct ShotEntryPanel: View {
    let onSave: (ShotType, ShotResult, ShotConsequence?) -> Void

    @State private var shotType: ShotType?
    @State private var result: ShotResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let shotType, let result {
                stepHeader("3. Folge (optional)", summary: "\(shotType.label) · \(result.label)")
                BigButtonGrid(items: ShotConsequence.allCases, label: \.label, tint: .red) { consequence in
                    save(shotType, result, consequence)
                }
                BigButton(title: "Ohne Folge speichern", systemImage: "checkmark", tint: .accentColor) {
                    save(shotType, result, nil)
                }
            } else if let shotType {
                stepHeader("2. Ergebnis", summary: shotType.label)
                BigButtonGrid(items: ShotResult.allCases, label: \.label, symbol: \.symbol, tint: .orange) { result = $0 }
            } else {
                stepHeader("1. Schlagart", summary: nil)
                BigButtonGrid(items: ShotType.allCases, label: \.label, symbol: \.symbol, tint: .accentColor) { shotType = $0 }
            }
        }
        .animation(.snappy, value: shotType)
        .animation(.snappy, value: result)
    }

    @ViewBuilder
    private func stepHeader(_ title: String, summary: String?) -> some View {
        HStack {
            Text(title).font(.headline)
            if let summary {
                Text(summary).foregroundStyle(.secondary)
            }
            Spacer()
            if shotType != nil {
                Button("Zurück") {
                    if result != nil { result = nil } else { shotType = nil }
                }
            }
        }
    }

    private func save(_ type: ShotType, _ result: ShotResult, _ consequence: ShotConsequence?) {
        onSave(type, result, consequence)
        shotType = nil
        self.result = nil
    }
}

struct BigButtonGrid<Item: Identifiable & Hashable>: View {
    let items: [Item]
    let label: KeyPath<Item, String>
    var symbol: KeyPath<Item, String>? = nil
    var selected: Item? = nil
    let tint: Color
    let action: (Item) -> Void

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items) { item in
                Button {
                    action(item)
                } label: {
                    VStack(spacing: 4) {
                        if let symbol {
                            Image(systemName: item[keyPath: symbol]).font(.title3)
                        }
                        Text(item[keyPath: label])
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                }
                .buttonStyle(.bordered)
                .tint(selected == item ? Color.accentColor : tint)
                .overlay {
                    if selected == item {
                        RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, lineWidth: 3)
                    }
                }
            }
        }
    }
}

struct BigButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }
}
