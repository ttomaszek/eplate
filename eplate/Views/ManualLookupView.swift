import SwiftUI

struct ManualLookupView: View {
    @State private var searchText = ""
    @State private var allRegions: [RegionModel] = []
    
    var onSelectItem: (RegionModel, String) -> Void
    
    var filteredRegions: [RegionModel] {
        if searchText.isEmpty {
            return allRegions
        } else {
            let query = searchText.lowercased().folding(options: .diacriticInsensitive, locale: .current)
            return allRegions.filter { region in
                let prefixMatch = region.prefix.lowercased().contains(query)
                let powiatMatch = region.powiat.lowercased().folding(options: .diacriticInsensitive, locale: .current).contains(query)
                let seatMatch = region.seat.lowercased().folding(options: .diacriticInsensitive, locale: .current).contains(query)
                let wojMatch = region.wojewodztwo.lowercased().folding(options: .diacriticInsensitive, locale: .current).contains(query)
                return prefixMatch || powiatMatch || seatMatch || wojMatch
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                    .onTapGesture {
                        hideKeyboard()
                    }
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Wyszukiwarka")
                                .font(.system(.largeTitle))
                                .fontWeight(.black)
                                .foregroundColor(.white)
                            
                            Text("Szukaj po wyróżniku lub powiecie")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.4))
                        
                        TextField("Szukaj", text: $searchText)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .tint(.blue)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    
                    // Results List
                    if filteredRegions.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "questionmark.folder")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.2))
                            
                            Text("Taka blacha nie istnieje")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.4))
                            
                            Text("Wpisz poprawną nazwę lub kod.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.3))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredRegions) { region in
                                    LookupRowView(region: region)
                                        .onTapGesture {
                                            hideKeyboard()
                                            // Trigger callback with empty plate placeholder since it's manual search
                                            onSelectItem(region, region.prefix)
                                        }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 30)
                        }
                        .scrollDismissesKeyboard(.immediately)
                        .background(
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    hideKeyboard()
                                }
                        )
                    }
                }
            }
        }
        .onAppear {
            loadAllRegions()
        }
    }
    
    private func loadAllRegions() {
        guard let url = Bundle.main.url(forResource: "polish_plates", withExtension: "json") else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let regions = try decoder.decode([RegionModel].self, from: data)
            // Sort by prefix alphabetically
            self.allRegions = regions.sorted { $0.prefix < $1.prefix }
        } catch {
            print("Failed to load regions for manual lookup: \(error)")
        }
    }
}

