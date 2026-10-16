import SwiftUI

/// Farben von Zulu Golf (zulugolf.de).
extension Color {
    static let zuluNavy = Color("ZGNavy")
    static let zuluGold = Color("ZGGold")
}

/// ZG-Monogramm. Hat weiße Flächen, steht deshalb immer auf Marineblau.
struct ZGBadge: View {
    var height: CGFloat = 28

    var body: some View {
        Image("ZGLogo")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .padding(.horizontal, height * 0.3)
            .padding(.vertical, height * 0.2)
            .background(Color.zuluNavy, in: RoundedRectangle(cornerRadius: height * 0.3))
            .accessibilityLabel("Zulu Golf")
    }
}
