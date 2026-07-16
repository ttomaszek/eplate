import SwiftUI
import SwiftData

struct MainContainerView: View {
    // MARK: - Properties
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedTab = 0
    @State private var activeDetailRegion: RegionModel?
    @State private var activeDetailPlateText: String = ""
    @State private var activePlateImage: UIImage? = nil
    @State private var showDetailCard = false
    @State private var detailCardMode: ResultCardView.CardMode = .scan
    
    // MARK: - Body / View Hierarchy
    var body: some View {
        ZStack {
            // Main Content Tabs
            TabView(selection: $selectedTab) {
                // Tab 1: Scanner
                ScannerView(isScanningActive: !showDetailCard, onPlateScanned: handleScannedPlate)
                    .tabItem {
                        Label("Skaner", systemImage: "viewfinder.circle")
                    }
                    .tag(0)
                
                // Tab 2: Manual Search
                ManualLookupView(onSelectItem: handleSearchSelectedItem)
                    .tabItem {
                        Label("Szukaj", systemImage: "magnifyingglass")
                    }
                    .tag(1)
                
                // Tab 3: History Log
                HistoryView(onSelectItem: handleHistorySelectedItem)
                    .tabItem {
                        Label("Historia", systemImage: "clock")
                    }
                    .tag(2)
                
                // Tab 4: Collection (Placeholder)
                CollectionView(onSelectItem: handleHistorySelectedItem)
                    .tabItem {
                        Label("Kolekcja", systemImage: "square.stack.3d.up.fill")
                    }
                    .tag(3)
            }
            .tint(.blue)
            .environment(\.colorScheme, .dark) // Enforce dark theme overall
            
            // Dimmed Background Overlay when Card is Active
            if showDetailCard {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissDetailCard()
                    }
                    .transition(.opacity)
            }
            
            // Glassmorphic Details Card
            if let region = activeDetailRegion, showDetailCard {
                VStack {
                    Spacer()
                    ResultCardView(
                        region: region,
                        plateText: activeDetailPlateText,
                        mode: detailCardMode,
                        plateImage: activePlateImage,
                        onDelete: {
                            // Find and delete the item (and its image) from history
                            let cleanedSearch = activeDetailPlateText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                            let descriptor = FetchDescriptor<ScanHistoryItem>()
                            if let items = try? modelContext.fetch(descriptor),
                               let itemToDelete = items.first(where: { $0.rawText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == cleanedSearch }) {
                                deleteImageFile(filename: itemToDelete.imageFilename)
                                modelContext.delete(itemToDelete)
                                try? modelContext.save()
                            }
                            dismissDetailCard()
                        },
                        onDismiss: dismissDetailCard
                    )
                    .transition(.move(edge: .bottom))
                }
                .ignoresSafeArea(edges: .bottom)
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0), value: showDetailCard)
    }
    
    // MARK: - Actions / Helper Methods
    
    private func handleScannedPlate(region: RegionModel, rawText: String, imageFilename: String?) {
        let cleanedSearch = rawText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let descriptor = FetchDescriptor<ScanHistoryItem>()

        let category = PlateDatabase.shared.classify(plateText: rawText, region: region)

        do {
            let existingItems = try modelContext.fetch(descriptor)
            if let existing = existingItems.first(where: { $0.rawText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == cleanedSearch }) {
                // Update date, category, and image (delete old image file first)
                if let oldFilename = existing.imageFilename, oldFilename != imageFilename {
                    deleteImageFile(filename: oldFilename)
                }
                existing.date = Date()
                existing.category = category
                existing.imageFilename = imageFilename
            } else {
                let historyItem = ScanHistoryItem(
                    rawText: rawText,
                    prefix: region.prefix,
                    date: Date(),
                    powiat: region.powiat,
                    wojewodztwo: region.wojewodztwo,
                    seat: region.seat,
                    type: region.type,
                    category: category,
                    imageFilename: imageFilename
                )
                modelContext.insert(historyItem)
            }
        } catch {
            print("Failed to fetch scan history for duplication check: \(error)")
            let historyItem = ScanHistoryItem(
                rawText: rawText,
                prefix: region.prefix,
                date: Date(),
                powiat: region.powiat,
                wojewodztwo: region.wojewodztwo,
                seat: region.seat,
                type: region.type,
                category: category,
                imageFilename: imageFilename
            )
            modelContext.insert(historyItem)
        }

        detailCardMode = .scan
        activeDetailRegion = region
        activeDetailPlateText = rawText
        // Load the image we just saved
        if let fn = imageFilename {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fn)
            activePlateImage = UIImage(contentsOfFile: url.path)
        } else {
            activePlateImage = nil
        }
        showDetailCard = true
    }
    
    private func handleSearchSelectedItem(region: RegionModel, rawText: String) {
        detailCardMode = .search
        activeDetailRegion = region
        activeDetailPlateText = rawText
        activePlateImage = nil
        showDetailCard = true
    }
    
    private func handleHistorySelectedItem(region: RegionModel, rawText: String) {
        detailCardMode = .history
        activeDetailRegion = region
        activeDetailPlateText = rawText
        // Look up the image from the matching history item
        let cleanedSearch = rawText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let descriptor = FetchDescriptor<ScanHistoryItem>()
        if let items = try? modelContext.fetch(descriptor),
           let match = items.first(where: { $0.rawText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == cleanedSearch }) {
            activePlateImage = match.thumbnailImage
        } else {
            activePlateImage = nil
        }
        showDetailCard = true
    }
    
    private func dismissDetailCard() {
        showDetailCard = false
    }

    /// Deletes a plate image file from the documents directory.
    private func deleteImageFile(filename: String?) {
        guard let filename = filename else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}

#Preview {
    MainContainerView()
        .modelContainer(for: ScanHistoryItem.self, inMemory: true)
}
