import SwiftUI

/// „Über Caddy“: Zulu-Golf-Logo, Leitsatz und Link zu zulugolf.de.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Image("ZGLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 240)
                        .padding(.top, 40)
                        .accessibilityLabel("Zulu Golf")

                    VStack(spacing: 14) {
                        Text("Mit Haltung auf den Platz.")
                            .font(.caption.bold())
                            .tracking(3)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.zuluGold)
                        Text("Das Ziel im Blick.")
                            .font(.largeTitle.bold())
                        Text("Caddy erfasst jeden Schlag, damit du siehst, wo du Schläge verlierst. Ein ruhiger Stand, ein klarer Gedanke, und mit jedem Schlag ein Stück besser.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(.horizontal, 24)

                    Link(destination: URL(string: "https://www.zulugolf.de")!) {
                        Label("zulugolf.de", systemImage: "arrow.up.right.square")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.zuluGold)
                    .foregroundStyle(Color.zuluNavy)
                    .padding(.horizontal, 24)

                    Text(version)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
            }
            .background(Color.zuluNavy.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .tint(.zuluGold)
                }
            }
            .toolbarBackground(Color.zuluNavy, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
