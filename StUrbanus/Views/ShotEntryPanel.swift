import SwiftUI

/// Erfassung per Tipp in drei Schritten: Schlagart → Ergebnis → optionale Folge (inkl. „Eingelocht“).
/// Beim GIR-Schlag (Par−2) wird in Schritt 3 ausdrücklich gefragt, ob das Grün getroffen wurde.
struct ShotEntryPanel: View {
    /// Ist der nächste Schlag der GIR-Schlag dieses Lochs?
    var isGIRShot = false
    let onSave: (ShotType, ShotResult, ShotConsequence?, Bool?) -> Void

    @State private var shotType: ShotType?
    @State private var result: ShotResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let shotType, let result {
                stepHeader(isGIRShot ? "Folge (GIR-Schlag):" : "Folge:", summary: "\(shotType.label) · \(result.label)")
                BigButton(title: "Eingelocht", systemImage: "flag.checkered", tint: .green) {
                    save(shotType, result, .holed, gir: nil)
                }
                if isGIRShot {
                    girQuestion(shotType, result)
                }
                BigButtonGrid(items: ShotConsequence.allCases.filter { $0 != .holed && (!isGIRShot || $0 != .green) },
                              label: \.label, tint: .red) { consequence in
                    save(shotType, result, consequence, gir: nil)
                }
                if !isGIRShot {
                    BigButton(title: "Ohne Folge speichern", systemImage: "checkmark", tint: .accentColor) {
                        save(shotType, result, nil, gir: nil)
                    }
                }
            } else if let shotType {
                stepHeader("Ergebnis:", summary: shotType.label)
                BigButtonGrid(items: ShotResult.allCases, label: \.label, symbol: \.symbol, tint: .orange) { result = $0 }
            } else {
                stepHeader("Nächster Schlag:", summary: isGIRShot ? "nächster Schlag ist der GIR-Schlag" : nil)
                BigButtonGrid(items: ShotType.selectable, label: \.label, symbol: \.symbol, tint: .accentColor) { shotType = $0 }
            }
        }
        .animation(.snappy, value: shotType)
        .animation(.snappy, value: result)
    }

    /// Hervorgehobene GIR-Frage: Grün getroffen (Folge „Grün“) oder verfehlt.
    @ViewBuilder
    private func girQuestion(_ type: ShotType, _ result: ShotResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Green in Regulation – Grün getroffen?", systemImage: "flag.fill")
                .font(.subheadline.bold())
            HStack(spacing: 10) {
                BigButton(title: "Grün getroffen", systemImage: "checkmark.circle.fill", tint: .green) {
                    save(type, result, .green, gir: true)
                }
                BigButton(title: "Verfehlt", systemImage: "xmark.circle", tint: .gray) {
                    save(type, result, nil, gir: false)
                }
            }
            Text("Oder wähle unten, wo der Ball liegt (zählt als verfehlt).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
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

    private func save(_ type: ShotType, _ result: ShotResult, _ consequence: ShotConsequence?, gir: Bool?) {
        onSave(type, result, consequence, gir)
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
