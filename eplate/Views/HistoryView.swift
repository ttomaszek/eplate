import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScanHistoryItem.date, order: .reverse) private var historyItems: [ScanHistoryItem]
    
    var onSelectItem: (RegionModel, String) -> Void
    
    @State private var isSelectionMode = false
    @State private var selectedItems = Set<UUID>()
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Historia")
                                .font(.system(.largeTitle))
                                .fontWeight(.black)
                                .foregroundColor(.white)
                            
                            Text("Ostatnio zeskanowane tablice")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        if !historyItems.isEmpty {
                            if isSelectionMode {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        isSelectionMode = false
                                        selectedItems.removeAll()
                                    }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white.opacity(0.8))
                                        .frame(width: 32, height: 32)
                                        .background(Color.white.opacity(0.12))
                                        .clipShape(Circle())
                                }
                            } else {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        isSelectionMode = true
                                    }
                                }) {
                                    Text("Wybierz")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                    
                    // History List
                    if historyItems.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "clock.badge.xmark")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.2))
                            
                            Text("Brak zeskanowanych tablic")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.4))
                            
                            Text("Twoje zeskanowane blachy pojawią się tutaj.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.3))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(historyItems) { item in
                                ScanHistoryItemCardView(
                                    item: item,
                                    isSelectionMode: isSelectionMode,
                                    isSelected: selectedItems.contains(item.id)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if isSelectionMode {
                                        if selectedItems.contains(item.id) {
                                            selectedItems.remove(item.id)
                                        } else {
                                            selectedItems.insert(item.id)
                                        }
                                    } else {
                                        // Look up full model to pass it on
                                        if let region = PlateDatabase.shared.lookup(prefix: item.prefix) {
                                            onSelectItem(region, item.rawText)
                                        } else {
                                            // If not found in DB (fallback), reconstruct one
                                            let fallbackRegion = RegionModel(
                                                prefix: item.prefix,
                                                powiat: item.powiat,
                                                wojewodztwo: item.wojewodztwo,
                                                seat: item.seat,
                                                type: item.type
                                            )
                                            onSelectItem(fallbackRegion, item.rawText)
                                        }
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if !isSelectionMode {
                                        Button(role: .destructive) {
                                            deleteItem(item)
                                        } label: {
                                            Label("Usuń", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 24, bottom: 6, trailing: 24))
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.black)
                    }
                    
                    // Bottom actions panel for Selection Mode
                    if isSelectionMode {
                        HStack(spacing: 20) {
                            // Share Button
                            Button(action: shareSelectedPlates) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Udostępnij")
                                }
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(14)
                            }
                            .disabled(selectedItems.isEmpty)
                            .opacity(selectedItems.isEmpty ? 0.5 : 1.0)
                            
                            // Delete Button
                            Button(action: { showDeleteConfirmation = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                    Text("Usuń (\(selectedItems.count))")
                                }
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.red.opacity(selectedItems.isEmpty ? 0.4 : 0.85))
                                .cornerRadius(14)
                            }
                            .disabled(selectedItems.isEmpty)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                        .background(
                            ZStack {
                                Rectangle()
                                    .fill(.ultraThinMaterial)
                                    .environment(\.colorScheme, .dark)
                                Color.black.opacity(0.4)
                            }
                            .ignoresSafeArea(edges: .bottom)
                        )
                        .transition(.move(edge: .bottom))
                    }
                }
            }
            .alert("Usuń zaznaczone?", isPresented: $showDeleteConfirmation) {
                Button("Anuluj", role: .cancel) {}
                Button("Usuń", role: .destructive) {
                    deleteSelectedItems()
                }
            } message: {
                Text("Czy na pewno chcesz usunąć zaznaczone tablice (\(selectedItems.count))?")
            }
        }
    }
    
    private func deleteItem(_ item: ScanHistoryItem) {
        deleteImageFile(filename: item.imageFilename)
        modelContext.delete(item)
    }
    
    private func deleteSelectedItems() {
        let itemsToDelete = historyItems.filter { selectedItems.contains($0.id) }
        for item in itemsToDelete {
            deleteImageFile(filename: item.imageFilename)
            modelContext.delete(item)
        }
        withAnimation {
            isSelectionMode = false
            selectedItems.removeAll()
        }
    }
    
    private func shareSelectedPlates() {
        let selectedList = historyItems.filter { selectedItems.contains($0.id) }
        guard !selectedList.isEmpty else { return }

        // Share UIImage for items with a photo, fall back to plate text
        let shareItems: [Any] = selectedList.compactMap { item -> Any? in
            if let img = item.thumbnailImage { return img }
            return item.rawText.uppercased()
        }

        let activityVC = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)

        activityVC.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            withAnimation {
                isSelectionMode = false
                selectedItems.removeAll()
            }
        }

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootVC.present(activityVC, animated: true, completion: nil)
        }
    }

    private func deleteImageFile(filename: String?) {
        guard let filename = filename else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}
