import SwiftUI
import SwiftData

struct CollectionDetailListView: View {
    // MARK: - Properties
    let title: String
    let fallbackRegion: RegionModel
    let items: [ScanHistoryItem]
    var onSelectItem: ((RegionModel, String) -> Void)? = nil

    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext

    // MARK: - Selection State
    @State private var isSelectionMode = false
    @State private var selectedItems = Set<UUID>()
    @State private var showDeleteConfirmation = false

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            if items.isEmpty {
                emptyPlaceholder
            } else {
                List {
                    ForEach(items) { item in
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
                                let region = PlateDatabase.shared.lookup(prefix: item.prefix) ?? fallbackRegion
                                onSelectItem?(region, item.rawText)
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
                // Extra bottom padding so last row isn't hidden under the action panel
                .safeAreaInset(edge: .bottom) {
                    if isSelectionMode { Color.clear.frame(height: 100) }
                }
            }

            // Bottom action panel — slides in when in selection mode
            if isSelectionMode {
                bottomActionPanel
                    .transition(.move(edge: .bottom))
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !items.isEmpty {
                    if isSelectionMode {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSelectionMode = false
                                selectedItems.removeAll()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                    } else {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSelectionMode = true
                            }
                        } label: {
                            Text("Wybierz")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
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

    // MARK: - Bottom Action Panel
    private var bottomActionPanel: some View {
        HStack(spacing: 20) {
            // Share
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

            // Delete
            Button { showDeleteConfirmation = true } label: {
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
    }

    // MARK: - Empty Placeholder
    private var emptyPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.fill")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.2))
                .shadow(color: .white.opacity(0.05), radius: 8)

            Text("Brak zeskanowanych tablic")
                .font(.headline)
                .foregroundColor(.white.opacity(0.4))

            Text("Zeskanuj pierwszą tablicę z tej kategorii w aparacie, aby zapisać ją w kolekcji.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)

            Spacer()
        }
        .padding(.top, 60)
    }

    // MARK: - Actions
    private func deleteItem(_ item: ScanHistoryItem) {
        deleteImageFile(filename: item.imageFilename)
        modelContext.delete(item)
    }

    private func deleteSelectedItems() {
        for item in items where selectedItems.contains(item.id) {
            deleteImageFile(filename: item.imageFilename)
            modelContext.delete(item)
        }
        withAnimation {
            isSelectionMode = false
            selectedItems.removeAll()
        }
    }

    private func shareSelectedPlates() {
        let selectedList = items.filter { selectedItems.contains($0.id) }
        guard !selectedList.isEmpty else { return }

        // Build share items: UIImage for items with a photo, plate text for those without
        let shareItems: [Any] = selectedList.compactMap { item -> Any? in
            if let img = item.thumbnailImage { return img }
            return item.rawText.uppercased()
        }

        let activityVC = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)

        activityVC.completionWithItemsHandler = { _, _, _, _ in
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
            rootVC.present(activityVC, animated: true)
        }
    }

    private func deleteImageFile(filename: String?) {
        guard let filename = filename else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}
