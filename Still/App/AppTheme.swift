import SwiftUI

/// Colors come in light/dark pairs so buttons retain readable contrast.
enum AppTheme: String, CaseIterable, Identifiable {
    case graphite = "Graphite", moss = "Moss", ocean = "Ocean", clay = "Clay", plum = "Plum"
    var id: String { rawValue }
    var color: Color {
        if self == .graphite { return .primary }
        let light: UIColor
        let dark: UIColor
        switch self {
        case .moss: light = UIColor(red: 0.25, green: 0.35, blue: 0.22, alpha: 1); dark = UIColor(red: 0.68, green: 0.79, blue: 0.56, alpha: 1)
        case .ocean: light = UIColor(red: 0.15, green: 0.34, blue: 0.46, alpha: 1); dark = UIColor(red: 0.55, green: 0.77, blue: 0.88, alpha: 1)
        case .clay: light = UIColor(red: 0.52, green: 0.26, blue: 0.19, alpha: 1); dark = UIColor(red: 0.93, green: 0.66, blue: 0.52, alpha: 1)
        case .plum: light = UIColor(red: 0.40, green: 0.24, blue: 0.45, alpha: 1); dark = UIColor(red: 0.80, green: 0.66, blue: 0.86, alpha: 1)
        case .graphite: return .primary
        }
        return Color(UIColor { trait in trait.userInterfaceStyle == .dark ? dark : light })
    }
}

struct ThemePicker: View {
    @AppStorage("theme") private var theme = AppTheme.graphite.rawValue
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
            ForEach(AppTheme.allCases) { item in
                Button { theme = item.rawValue } label: {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle().fill(item.color).frame(width: 38, height: 38)
                            if theme == item.rawValue { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(Color(uiColor: .systemBackground)) }
                        }
                        Text(item.rawValue).font(.caption).foregroundStyle(.primary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 8)
                }.buttonStyle(QuietPress()).accessibilityLabel(item.rawValue + " theme")
                    .accessibilityAddTraits(theme == item.rawValue ? .isSelected : [])
            }
        }.padding(.vertical, 8)
    }
}
