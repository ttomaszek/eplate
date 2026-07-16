import SwiftUI

// MARK: - ScanHistoryItemCardView

/// Unified card used in both HistoryView rows and CollectionDetailListView rows.
/// Matches the collection card style: circular category icon + plate text + location + smart date.
struct ScanHistoryItemCardView: View {
    let item: ScanHistoryItem
    var isSelectionMode: Bool = false
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            // Selection checkbox (history mode only)
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .white.opacity(0.3))
                    .font(.title3)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            // Thumbnail or category icon
            if let uiImage = item.thumbnailImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
            } else {
                Image(systemName: iconName(for: item))
                    .font(.title3)
                    .foregroundColor(accentColor(for: item))
                    .frame(width: 40, height: 40)
                    .background(accentColor(for: item).opacity(0.12))
                    .clipShape(Circle())
            }

            // Plate text + location
            VStack(alignment: .leading, spacing: 3) {
                Text(formatPlate(item))
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(item.displayName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)

                Text(item.wojewodztwo)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(accentColor(for: item).opacity(0.85))
                    .lineLimit(1)
            }

            Spacer()

            // Date + chevron
            VStack(alignment: .trailing, spacing: 4) {
                if !isSelectionMode {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.25))
                }

                Text(smartDate(item.date))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func iconName(for item: ScanHistoryItem) -> String {
        if item.category == "classic" { return "car.badge.gearshape.fill" }
        switch item.type {
        case "military": return "shield.fill"
        case "service": return "building.columns.fill"
        case "reduced": return "arrow.down.right.and.arrow.up.left"
        case "custom": return "licenseplate.fill"
        default: return "car.fill"
        }
    }

    private func accentColor(for item: ScanHistoryItem) -> Color {
        if item.category == "classic" { return Color(red: 242/255, green: 185/255, blue: 50/255) }
        switch item.type {
        case "military": return Color(red: 120/255, green: 135/255, blue: 95/255)
        case "service": return Color.blue
        case "reduced": return Color.cyan
        case "custom": return Color(red: 254/255, green: 44/255, blue: 85/255)
        default: return Color.blue
        }
    }

    private func formatPlate(_ item: ScanHistoryItem) -> String {
        let raw = item.rawText
        if raw.contains(" ") { return raw.uppercased() }
        let clean = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        guard clean.count > 3 else { return clean }
        let prefix = item.prefix.uppercased()
        if clean.hasPrefix(prefix) {
            let idx = clean.index(clean.startIndex, offsetBy: prefix.count)
            return "\(clean[..<idx]) \(clean[idx...])"
        }
        // Fallback: split after leading letters
        let letters = String(clean.prefix(while: { $0.isLetter }))
        if letters.count >= 2 {
            return "\(letters) \(clean.dropFirst(letters.count))"
        }
        return clean
    }

    /// Relative time for items within 24 h, otherwise abbreviated absolute date.
    private func smartDate(_ date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 86400 {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            formatter.locale = Locale(identifier: "pl_PL")
            return formatter.localizedString(for: date, relativeTo: Date())
        } else {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
    }
}

// MARK: - RoundedCorner Shape

// SwiftUI RoundedCorner Helper for drawing selective borders
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Tab Selector View

/// Reusable animated segment control replacing the system Picker(.segmented).
/// Usage: TabSelectorView(tabs: ["A", "B", "C"], selectedTab: $tab)
struct TabSelectorView: View {
    let tabs: [String]
    @Binding var selectedTab: Int
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                        selectedTab = index
                    }
                } label: {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(selectedTab == index ? .white : .white.opacity(0.45))
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background {
                            if selectedTab == index {
                                Capsule()
                                    .fill(Color.white.opacity(0.13))
                                    .matchedGeometryEffect(id: "tab_indicator", in: animation)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }
}

// MARK: - Pressable Button Style

/// Adds a subtle scale + opacity press feedback to any view.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Standard dark card background used across collection views.
    func collectionCardStyle(cornerRadius: CGFloat = 14, opacity: Double = 0.03) -> some View {
        self
            .background(Color.white.opacity(opacity))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
    }
}

