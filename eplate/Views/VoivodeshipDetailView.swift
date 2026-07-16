import SwiftUI

struct VoivodeshipDetailView: View {
    // MARK: - Properties
    let voivodeshipName: String
    let historyItems: [ScanHistoryItem]
    var onSelectItem: ((RegionModel, String) -> Void)? = nil
    
    @State private var selectedSegment = 0 // 0: Powiaty, 1: Indywidualne, 2: Zmniejszone
    
    // Get counties filtered and sorted
    private var counties: [RegionModel] {
        // Find all unique powiaty in the DB for this voivodeship
        // (excluding reduced/custom/military/service base prefixes)
        let all = PlateDatabase.shared.getAllRegions()
        return all.filter { 
            $0.wojewodztwo == voivodeshipName && 
            $0.type != "reduced" && 
            $0.type != "custom" && 
            $0.type != "military" && 
            $0.type != "service"
        }
    }
    
    private var prefixLetters: [String] {
        let letters = counties.map { String($0.prefix.prefix(1)).uppercased() }
        return Array(Set(letters)).sorted()
    }
    
    // MARK: - Progress Helpers
    private var unlockedCountiesCount: Int {
        counties.filter { region in
            historyItems.contains { $0.prefix.uppercased() == region.prefix.uppercased() }
        }.count
    }
    
    private var progressFraction: Double {
        counties.isEmpty ? 0 : Double(unlockedCountiesCount) / Double(counties.count)
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Progress Header Card
                    VStack(spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Postęp województwa")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white.opacity(0.5))
                                Text("\(unlockedCountiesCount) z \(counties.count) powiatów odblokowanych")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Text("\(Int(progressFraction * 100))%")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.black)
                                .foregroundColor(.blue)
                        }
                        
                        // Progress bar
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
                    .padding(16)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    
                    // Top Segment Picker (custom)
                    TabSelectorView(
                        tabs: ["Powiaty", "Indywidualne", "Zmniejszone"],
                        selectedTab: $selectedSegment
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    
                    VStack(spacing: 24) {
                        if selectedSegment == 0 {
                            powiatyList
                        } else if selectedSegment == 1 {
                            customList
                        } else {
                            shortList
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle(voivodeshipName)
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Subviews
    
    // 1. Powiaty Section
    private var powiatyList: some View {
        VStack(spacing: 12) {
            ForEach(counties, id: \.prefix) { region in
                let hasRegular = checkCountyRegularUnlocked(prefix: region.prefix)
                let hasVintage = checkCountyVintageUnlocked(prefix: region.prefix)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(region.powiat)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                            
                            Text("Siedziba: \(region.seat)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.4))
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 8)
                        
                        Text(region.prefix)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(minWidth: 40)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    HStack(spacing: 12) {
                        // Regular Badge
                        NavigationLink(destination: CollectionDetailListView(
                            title: "\(region.powiat) (Zwykłe)",
                            fallbackRegion: region,
                            items: getScannedRegularItems(for: region.prefix),
                            onSelectItem: onSelectItem
                        )) {
                            HStack(spacing: 6) {
                                Image(systemName: hasRegular ? "checkmark.circle.fill" : "circle")
                                    .font(.caption2)
                                Text("Zwykła")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(hasRegular ? .white : .white.opacity(0.25))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(hasRegular ? Color.blue.opacity(0.35) : Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(hasRegular ? Color.blue.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableButtonStyle())
                        
                        // Vintage Badge
                        NavigationLink(destination: CollectionDetailListView(
                            title: "\(region.powiat) (Zabytkowe)",
                            fallbackRegion: region,
                            items: getScannedVintageItems(for: region.prefix),
                            onSelectItem: onSelectItem
                        )) {
                            HStack(spacing: 6) {
                                Image(systemName: hasVintage ? "checkmark.circle.fill" : "circle")
                                    .font(.caption2)
                                Text("Zabytkowa")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(hasVintage ? .black : .white.opacity(0.25))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(hasVintage ? Color(red: 242/255, green: 185/255, blue: 50/255) : Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(hasVintage ? Color(red: 242/255, green: 185/255, blue: 50/255).opacity(0.8) : Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableButtonStyle())
                        
                        Spacer()
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
        }
    }
    
    // 2. Custom Section (Voivodeship Letter + 0-9)
    private var customList: some View {
        VStack(spacing: 12) {
            let combos = prefixLetters.flatMap { letter in
                (0...9).map { "\(letter)\($0)" }
            }
            
            LazyVStack(spacing: 12) {
                ForEach(combos, id: \.self) { prefix in
                    let isUnlocked = checkCustomUnlocked(prefix: prefix)
                    
                    NavigationLink(destination: CollectionDetailListView(
                        title: "Indywidualna \(prefix)",
                        fallbackRegion: getCustomFallbackRegion(for: prefix),
                        items: getScannedCustomItems(for: prefix),
                        onSelectItem: onSelectItem
                    )) {
                        HStack(spacing: 16) {
                            Text(prefix)
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(isUnlocked ? .white : .white.opacity(0.3))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isUnlocked ? Color(red: 254/255, green: 44/255, blue: 85/255).opacity(0.3) : Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isUnlocked ? Color(red: 254/255, green: 44/255, blue: 85/255).opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Indywidualna \(prefix)")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(isUnlocked ? .white : .white.opacity(0.4))
                                    .lineLimit(1)
                                
                                Text(isUnlocked ? "Zeskanowana" : "Zablokowana")
                                    .font(.caption2)
                                    .foregroundColor(isUnlocked ? Color(red: 254/255, green: 44/255, blue: 85/255) : .white.opacity(0.2))
                            }
                            
                            Spacer()
                            
                            Image(systemName: isUnlocked ? "checkmark.circle.fill" : "lock.fill")
                                .foregroundColor(isUnlocked ? Color(red: 254/255, green: 44/255, blue: 85/255) : .white.opacity(0.2))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(isUnlocked ? 0.04 : 0.01))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(isUnlocked ? 0.08 : 0.03), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }
    
    // 3. Short / Reduced Section
    private var shortList: some View {
        LazyVStack(spacing: 12) {
            ForEach(prefixLetters, id: \.self) { letter in
                let isUnlocked = checkShortUnlocked(letter: letter)
                
                NavigationLink(destination: CollectionDetailListView(
                    title: "Zmniejszona \(letter)",
                    fallbackRegion: getShortFallbackRegion(for: letter),
                    items: getScannedShortItems(for: letter),
                    onSelectItem: onSelectItem
                )) {
                    HStack(spacing: 16) {
                        Text(letter)
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundColor(isUnlocked ? .white : .white.opacity(0.3))
                            .frame(width: 40, height: 40)
                            .background(isUnlocked ? Color.cyan.opacity(0.35) : Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isUnlocked ? Color.cyan.opacity(0.7) : Color.white.opacity(0.1), lineWidth: 1)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Zmniejszona \(letter)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(isUnlocked ? .white : .white.opacity(0.4))
                                .lineLimit(1)
                            
                            Text(isUnlocked ? "Zeskanowana" : "Zablokowana")
                                .font(.caption2)
                                .foregroundColor(isUnlocked ? .cyan : .white.opacity(0.2))
                        }
                        
                        Spacer()
                        
                        Image(systemName: isUnlocked ? "checkmark.circle.fill" : "lock.fill")
                            .foregroundColor(isUnlocked ? .cyan : .white.opacity(0.2))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(isUnlocked ? 0.04 : 0.01))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(isUnlocked ? 0.08 : 0.03), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }
    
    // MARK: - Helpers
    
    private func getScannedRegularItems(for prefix: String) -> [ScanHistoryItem] {
        historyItems.filter { $0.prefix.uppercased() == prefix.uppercased() && $0.category != "classic" }
    }
    
    private func getScannedVintageItems(for prefix: String) -> [ScanHistoryItem] {
        historyItems.filter { $0.prefix.uppercased() == prefix.uppercased() && $0.category == "classic" }
    }
    
    private func getScannedCustomItems(for prefix: String) -> [ScanHistoryItem] {
        historyItems.filter { $0.type == "custom" && $0.rawText.uppercased().hasPrefix(prefix.uppercased()) }
    }
    
    private func getScannedShortItems(for letter: String) -> [ScanHistoryItem] {
        historyItems.filter { $0.type == "reduced" && $0.rawText.uppercased().hasPrefix(letter.uppercased()) }
    }
    
    private func getCustomFallbackRegion(for prefix: String) -> RegionModel {
        return counties.first ?? RegionModel(prefix: prefix, powiat: "Indywidualne", wojewodztwo: voivodeshipName, seat: "Polska", type: "custom")
    }
    
    private func getShortFallbackRegion(for letter: String) -> RegionModel {
        return counties.first ?? RegionModel(prefix: letter, powiat: "Zmniejszone", wojewodztwo: voivodeshipName, seat: "Polska", type: "reduced")
    }
    
    private func checkCountyRegularUnlocked(prefix: String) -> Bool {
        historyItems.contains { $0.prefix.uppercased() == prefix.uppercased() && $0.category != "classic" }
    }
    
    private func checkCountyVintageUnlocked(prefix: String) -> Bool {
        historyItems.contains { $0.prefix.uppercased() == prefix.uppercased() && $0.category == "classic" }
    }
    
    private func checkCustomUnlocked(prefix: String) -> Bool {
        historyItems.contains { item in
            item.type == "custom" && item.rawText.uppercased().hasPrefix(prefix.uppercased())
        }
    }
    
    private func checkShortUnlocked(letter: String) -> Bool {
        historyItems.contains { item in
            item.type == "reduced" && item.rawText.uppercased().hasPrefix(letter.uppercased())
        }
    }
}
