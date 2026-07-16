import SwiftUI

struct PoliceDetailView: View {
    // MARK: - Properties
    let historyItems: [ScanHistoryItem]
    var onSelectItem: ((RegionModel, String) -> Void)? = nil
    
    private var policeSeats: [RegionModel] {
        PlateDatabase.shared.getPoliceSeats()
    }
    
    // MARK: - Helpers
    private var unlockedCount: Int {
        policeSeats.filter { checkUnlocked($0.prefix) }.count
    }
    
    private var progressFraction: Double {
        policeSeats.isEmpty ? 0 : Double(unlockedCount) / Double(policeSeats.count)
    }
    
    /// KGP (Komenda Główna Policji) has a unique prefix — highlight it
    private func isKGP(_ prefix: String) -> Bool {
        prefix.uppercased().hasPrefix("HPA") || prefix.uppercased() == "HPA"
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "shield.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                             }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Komendy Policji")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("Kolekcja wydziałów HP")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            Text("\(unlockedCount)/\(policeSeats.count)")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        // Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 8)
                                Capsule()
                                    .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(geo.size.width * progressFraction, progressFraction > 0 ? 8 : 0), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
                    
                    // Command Seats List
                    VStack(spacing: 12) {
                        ForEach(policeSeats, id: \.prefix) { seat in
                            let isUnlocked = checkUnlocked(seat.prefix)
                            let kgp = isKGP(seat.prefix)
                            
                            // Pre-compute colors to help Swift type-checker
                            let badgeForeground: Color = kgp ? .black : (isUnlocked ? .white : .white.opacity(0.3))
                            let badgeBg: Color = kgp ? Color.yellow.opacity(0.85) : (isUnlocked ? Color.blue.opacity(0.35) : Color.white.opacity(0.05))
                            let badgeBorder: Color = kgp ? Color.yellow.opacity(0.7) : (isUnlocked ? Color.blue.opacity(0.6) : Color.white.opacity(0.1))
                            let rowBg: Color = kgp ? Color.yellow.opacity(0.06) : Color.white.opacity(isUnlocked ? 0.04 : 0.01)
                            let rowBorder: Color = kgp ? Color.yellow.opacity(0.2) : Color.white.opacity(isUnlocked ? 0.08 : 0.03)
                            let iconColor: Color = kgp ? .yellow : (isUnlocked ? .blue : .white.opacity(0.2))
                            let nameColor: Color = isUnlocked ? .white : .white.opacity(0.4)
                            let seatColor: Color = isUnlocked ? .white.opacity(0.4) : .white.opacity(0.2)
                            
                            NavigationLink(destination: CollectionDetailListView(
                                title: seat.powiat,
                                fallbackRegion: seat,
                                items: getScannedPoliceItems(for: seat.prefix),
                                onSelectItem: onSelectItem
                            )) {
                                HStack(spacing: 16) {
                                    // Prefix badge
                                    Text(seat.prefix)
                                        .font(.system(.subheadline, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(badgeForeground)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(badgeBg)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(badgeBorder, lineWidth: 1)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(seat.powiat)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(nameColor)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.85)
                                        
                                        // Secondary label: seat location
                                        Text(seat.seat)
                                            .font(.caption2)
                                            .foregroundColor(seatColor)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: isUnlocked ? "checkmark.circle.fill" : "lock.fill")
                                        .foregroundColor(iconColor)
                                        .font(.subheadline)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(rowBg)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(rowBorder, lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Policja")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Helpers
    
    private func getScannedPoliceItems(for prefix: String) -> [ScanHistoryItem] {
        historyItems.filter { $0.type == "service" && $0.rawText.uppercased().hasPrefix(prefix.uppercased()) }
    }
    
    private func checkUnlocked(_ prefix: String) -> Bool {
        return historyItems.contains { item in
            let cleaned = item.rawText.uppercased().filter { $0.isLetter || $0.isNumber }
            return cleaned.hasPrefix(prefix)
        }
    }
}
