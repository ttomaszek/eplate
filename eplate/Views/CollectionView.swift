import SwiftUI
import SwiftData

struct SpecialServiceGroup: Identifiable {
    let id = UUID()
    let code: String
    let name: String
    let description: String
}

struct CollectionView: View {
    // MARK: - Query
    @Query private var historyItems: [ScanHistoryItem]
    var onSelectItem: ((RegionModel, String) -> Void)? = nil
    
    // MARK: - State
    @State private var selectedTab = 0 // 0: Województwa, 1: Wojsko, 2: Służby
    
    private let voivodeshipsList = [
        "Dolnośląskie", "Kujawsko-pomorskie", "Lubelskie", "Lubuskie",
        "Łódzkie", "Małopolskie", "Mazowieckie", "Opolskie",
        "Podkarpackie", "Podlaskie", "Pomorskie", "Śląskie",
        "Świętokrzyskie", "Warmińsko-mazurskie", "Wielkopolskie", "Zachodniopomorskie"
    ]
    
    private var militaryPlates: [RegionModel] {
        PlateDatabase.shared.getMilitaryPlates()
    }
    
    private var specialServices: [SpecialServiceGroup] {
        let allServices = PlateDatabase.shared.getSpecialServicePlates() + PlateDatabase.shared.getPoliceSeats()
        var groups: [SpecialServiceGroup] = []
        
        if allServices.contains(where: { $0.prefix.hasPrefix("HP") }) {
            groups.append(SpecialServiceGroup(code: "HP", name: "Policja", description: "Komendy wojewódzkie i KGP"))
        }
        if allServices.contains(where: { $0.prefix.hasPrefix("HC") }) {
            groups.append(SpecialServiceGroup(code: "HC", name: "Straż Graniczna", description: "Oddziały Straży Granicznej"))
        }
        if let sop = allServices.first(where: { $0.prefix == "HB" }) {
            groups.append(SpecialServiceGroup(code: "HB", name: sop.powiat, description: "Służba Ochrony Państwa"))
        }
        if let cba = allServices.first(where: { $0.prefix == "HA" }) {
            groups.append(SpecialServiceGroup(code: "HA", name: cba.powiat, description: "Centralne Biuro Antykorupcyjne"))
        }
        if let abw = allServices.first(where: { $0.prefix == "HK" }) {
            groups.append(SpecialServiceGroup(code: "HK", name: abw.powiat, description: "Agencja Bezpieczeństwa Wewnętrznego"))
        }
        if let kas = allServices.first(where: { $0.prefix == "HS" }) {
            groups.append(SpecialServiceGroup(code: "HS", name: kas.powiat, description: "Krajowa Administracja Skarbowa"))
        }
        if let sm = allServices.first(where: { $0.prefix == "HW" }) {
            groups.append(SpecialServiceGroup(code: "HW", name: sm.powiat, description: "Straż Marszałkowska"))
        }
        
        return groups
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Title
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Kolekcja")
                                .font(.system(.largeTitle))
                                .fontWeight(.black)
                                .foregroundColor(.white)
                            
                            Text("Twój postęp w kompletowaniu tablic")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    // Dashboard Progress Cards
                    HStack(spacing: 16) {
                        // Total Scans Card
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Zeskanowane")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("\(historyItems.count)")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.black)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        
                        // Powiaty Unlocked Card
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Odkryte Powiaty")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("\(unlockedPowiatyCount)/\(totalPowiatyCount)")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.black)
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    
                    // Custom Animated Tab Selector
                    TabSelectorView(
                        tabs: ["Województwa", "Wojsko", "Służby"],
                        selectedTab: $selectedTab
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    
                    // Content Lists
                    ScrollView {
                        VStack(spacing: 24) {
                            if selectedTab == 0 {
                                voivodeshipsTab
                            } else if selectedTab == 1 {
                                militaryTab
                            } else {
                                servicesTab
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews / Tab Contents
    
    // 1. Województwa Tab
    private var voivodeshipsTab: some View {
        VStack(spacing: 12) {
            ForEach(voivodeshipsList, id: \.self) { wojName in
                let total = getCountiesCount(for: wojName)
                let unlocked = getUnlockedCountiesCount(for: wojName)
                let pct = total > 0 ? Double(unlocked) / Double(total) : 0.0
                
                NavigationLink(destination: VoivodeshipDetailView(voivodeshipName: wojName, historyItems: historyItems, onSelectItem: onSelectItem)) {
                    VStack(spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(wojName)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                                    .multilineTextAlignment(.leading)
                                
                                Text("\(unlocked) z \(total) powiatów")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            
                            Spacer(minLength: 8)
                            
                            HStack(spacing: 6) {
                                Text("\(Int(pct * 100))%")
                                    .font(.system(.caption, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.25))
                            }
                        }
                        
                        // Progress Bar (improved height + contrast)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 8)
                                
                                Capsule()
                                    .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(geo.size.width * pct, pct > 0 ? 8 : 0), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }
    
    // 2. Wojsko Tab
    private var militaryTab: some View {
        VStack(spacing: 12) {
            // Section header
            let unlockedMilitary = militaryPlates.filter { checkMilitaryPrefixUnlocked($0.prefix) }.count
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tablice wojskowe")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(unlockedMilitary) z \(militaryPlates.count) odblokowanych")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.35))
                }
                Spacer()
            }
            .padding(.bottom, 4)
            
            ForEach(militaryPlates, id: \.prefix) { group in
                let isUnlocked = checkMilitaryPrefixUnlocked(group.prefix)
                
                NavigationLink(destination: CollectionDetailListView(
                    title: "Wojskowa \(group.prefix)",
                    fallbackRegion: group,
                    items: getScannedMilitaryItems(for: group.prefix),
                    onSelectItem: onSelectItem
                )) {
                    HStack(spacing: 16) {
                        Text(group.prefix)
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(isUnlocked ? .white : .white.opacity(0.3))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isUnlocked ? Color.green.opacity(0.35) : Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isUnlocked ? Color.green.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.powiat)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(isUnlocked ? .white : .white.opacity(0.4))
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                            
                            Text(isUnlocked ? "Zeskanowana" : "Zablokowana")
                                .font(.caption2)
                                .foregroundColor(isUnlocked ? .green : .white.opacity(0.2))
                        }
                        
                        Spacer()
                        
                        Image(systemName: isUnlocked ? "checkmark.circle.fill" : "lock.fill")
                            .foregroundColor(isUnlocked ? .green : .white.opacity(0.2))
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
    
    // 3. Służby Tab
    private var servicesTab: some View {
        VStack(spacing: 12) {
            // Section header
            let unlockedServices = specialServices.filter { checkServiceUnlocked($0.code) }.count
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Służby specjalne")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(unlockedServices) z \(specialServices.count) odblokowanych")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.35))
                }
                Spacer()
            }
            .padding(.bottom, 4)
            
            ForEach(specialServices) { service in
                let isUnlocked = checkServiceUnlocked(service.code)
                
                if service.code == "HP" {
                    // Policja links to seats details
                    NavigationLink(destination: PoliceDetailView(historyItems: historyItems, onSelectItem: onSelectItem)) {
                        HStack(spacing: 16) {
                            Text(service.code)
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.35))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue.opacity(0.6), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(service.name)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text(service.description)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.4))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                } else {
                    // Regular service groups
                    NavigationLink(destination: CollectionDetailListView(
                        title: service.name,
                        fallbackRegion: getServiceFallbackRegion(for: service.code, name: service.name),
                        items: getScannedServiceItems(for: service.code),
                        onSelectItem: onSelectItem
                    )) {
                        HStack(spacing: 16) {
                            Text(service.code)
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(isUnlocked ? .white : .white.opacity(0.3))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isUnlocked ? Color.purple.opacity(0.35) : Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isUnlocked ? Color.purple.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(service.name)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(isUnlocked ? .white : .white.opacity(0.4))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.85)
                                
                                Text(service.description)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.3))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            
                            Spacer()
                            
                            Image(systemName: isUnlocked ? "checkmark.circle.fill" : "lock.fill")
                                .foregroundColor(isUnlocked ? .purple : .white.opacity(0.2))
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
    }
    
    // MARK: - Helpers & Calculations
    
    private var totalPowiatyCount: Int {
        let all = PlateDatabase.shared.getAllRegions()
        return all.filter {
            $0.type != "reduced" && $0.type != "custom" && $0.type != "military" && $0.type != "service"
        }.count
    }
    
    private var unlockedPowiatyCount: Int {
        let all = PlateDatabase.shared.getAllRegions().filter {
            $0.type != "reduced" && $0.type != "custom" && $0.type != "military" && $0.type != "service"
        }
        return all.filter { region in
            historyItems.contains { $0.prefix.uppercased() == region.prefix.uppercased() }
        }.count
    }
    
    private func getCountiesCount(for wojName: String) -> Int {
        let all = PlateDatabase.shared.getAllRegions()
        return all.filter {
            $0.wojewodztwo == wojName &&
            $0.type != "reduced" &&
            $0.type != "custom" &&
            $0.type != "military" &&
            $0.type != "service"
        }.count
    }
    
    private func getUnlockedCountiesCount(for wojName: String) -> Int {
        let all = PlateDatabase.shared.getAllRegions().filter {
            $0.wojewodztwo == wojName &&
            $0.type != "reduced" &&
            $0.type != "custom" &&
            $0.type != "military" &&
            $0.type != "service"
        }
        return all.filter { region in
            historyItems.contains { $0.prefix.uppercased() == region.prefix.uppercased() }
        }.count
    }
    
    private func getScannedMilitaryItems(for prefix: String) -> [ScanHistoryItem] {
        historyItems.filter { $0.type == "military" && $0.rawText.uppercased().hasPrefix(prefix.uppercased()) }
    }
    
    private func getScannedServiceItems(for prefix: String) -> [ScanHistoryItem] {
        historyItems.filter { $0.type == "service" && $0.rawText.uppercased().hasPrefix(prefix.uppercased()) }
    }
    
    private func getServiceFallbackRegion(for prefix: String, name: String) -> RegionModel {
        return RegionModel(prefix: prefix, powiat: name, wojewodztwo: "Służby", seat: "Polska", type: "service")
    }
    
    private func checkMilitaryPrefixUnlocked(_ prefix: String) -> Bool {
        return historyItems.contains { item in
            let cleaned = item.rawText.uppercased().filter { $0.isLetter || $0.isNumber }
            return cleaned.hasPrefix(prefix)
        }
    }
    
    private func checkServiceUnlocked(_ prefix: String) -> Bool {
        return historyItems.contains { item in
            let cleaned = item.rawText.uppercased().filter { $0.isLetter || $0.isNumber }
            return cleaned.hasPrefix(prefix)
        }
    }
}

#Preview {
    CollectionView()
}
