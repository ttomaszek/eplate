import SwiftUI
import MapKit
import CoreLocation

struct ResultCardView: View {
    // MARK: - Types
    enum CardMode {
        case scan
        case search
        case history
    }
    
    // MARK: - Properties
    let region: RegionModel
    let plateText: String
    let mode: CardMode
    var plateImage: UIImage? = nil
    var onDelete: (() -> Void)? = nil
    var onDismiss: () -> Void
    
    @State private var position: MapCameraPosition = .automatic
    @State private var markerCoordinate: CLLocationCoordinate2D?
    @State private var boundaryCoordinates: [[CLLocationCoordinate2D]]? = nil
    @State private var isGeocoding = false
    @State private var showDeleteConfirmation = false
    
    // MARK: - Computed Category Properties
    private var category: String {
        PlateDatabase.shared.classify(plateText: plateText, region: region)
    }
    
    private var categoryDisplayName: String {
        switch category {
        case "classic": return "Zabytkowa"
        case "military": return "Wojskowa"
        case "police": return "Służbowa"
        case "reduced": return "Zmniejszona"
        case "custom": return "Indywidualna"
        default: return "Standardowa"
        }
    }
    
    private var categoryBadgeColor: Color {
        switch category {
        case "classic": return Color(red: 212/255, green: 175/255, blue: 55/255)
        case "military": return Color(red: 85/255, green: 107/255, blue: 47/255)
        case "police": return Color(red: 0/255, green: 80/255, blue: 160/255)
        case "reduced": return Color.cyan
        case "custom": return Color(red: 254/255, green: 44/255, blue: 85/255) // Premium Hot Pink
        default: return Color.blue
        }
    }
    
    private var accentColor: Color {
        switch category {
        case "classic": return Color(red: 212/255, green: 175/255, blue: 55/255)
        case "military": return Color(red: 85/255, green: 107/255, blue: 47/255)
        case "police": return Color(red: 0/255, green: 80/255, blue: 160/255)
        case "reduced": return Color.cyan
        case "custom": return Color(red: 254/255, green: 44/255, blue: 85/255) // Premium Hot Pink
        default: return Color.blue
        }
    }
    
    private var categoryIcon: String {
        switch category {
        case "classic": return "car.badge.gearshape.fill"
        case "military": return "shield.fill"
        case "police": return "building.columns.fill"
        case "reduced": return "arrow.down.right.and.arrow.up.left"
        case "custom": return "licenseplate.fill"
        default: return "car.fill"
        }
    }
    
    // MARK: - Body / View Hierarchy
    var body: some View {
        VStack(spacing: 0) {
            // Header Row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    // Scanned Plate Text
                    Text(formatPlate(plateText))
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .foregroundColor(.white)
                    
                    // Powiat Name — constrained width so badges never get pushed off screen (fix 7.4)
                    Text(region.displayName)
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.55, alignment: .leading)
                }
                
                Spacer()
                
                // Badges stack (Voivodeship and Category)
                VStack(alignment: .trailing, spacing: 6) {
                    // Voivodeship Badge
                    Text(region.wojewodztwo)
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(category == "classic" ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: accentColor.opacity(0.3), radius: 6, x: 0, y: 3)
                    
                    // Category Badge
                    if category != "standard" {
                        HStack(spacing: 4) {
                            Image(systemName: categoryIcon)
                                .font(.system(size: 10, weight: .bold))
                            Text(categoryDisplayName)
                                .font(.system(size: 11, weight: .black))
                        }
                        .foregroundColor(category == "classic" ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [categoryBadgeColor, categoryBadgeColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: categoryBadgeColor.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                }
                .padding(.trailing, (mode == .search || mode == .history) ? 36 : 0)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 22)
            
            // Plate image (shown when available)
            if let img = plateImage {
                let ratio = img.size.height > 0 ? (img.size.width / img.size.height) : 1.0
                let availableWidth = UIScreen.main.bounds.width - 56
                let fittedHeight = availableWidth / ratio
                let finalHeight = min(120, fittedHeight)
                
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(ratio, contentMode: .fit)
                    .frame(height: finalHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .padding(.horizontal, 28)
                    .padding(.bottom, 16)
            }

            // Details Grid
            VStack(spacing: 14) {
                DetailColumn(title: "Siedziba", value: region.seat, icon: "building.2.fill", accentColor: accentColor)
                DetailColumn(title: "Wyróżnik", value: region.prefix, icon: "abc", accentColor: accentColor)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 26)

            // Map Section
            mapSection
            
            // Action Buttons
            if mode == .scan {
                Button(action: onDismiss) {
                    Text("Gotowe")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 28)
                }
                .padding(.bottom, 24)
            } else if mode == .history {
                HStack(spacing: 16) {
                    // Share Button
                    Button(action: {
                        if let img = plateImage {
                            shareSingle(item: img)
                        } else {
                            sharePlateText()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Udostępnij")
                        }
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 42)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    
                    // Delete Button
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                            Text("Usuń")
                        }
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 42)
                        .background(Color.red.opacity(0.85))
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
            } else {
                Spacer()
                    .frame(height: 16)
            }
        }
        .background(
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                
                // Increased opacity so card is readable over dark list backgrounds (fix 6.3)
                Color.black.opacity(0.65)
            }
        )
        .clipShape(RoundedCorner(radius: 24, corners: [.topLeft, .topRight]))
        .overlay(
            RoundedCorner(radius: 24, corners: [.topLeft, .topRight])
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .overlay(
            Group {
                if mode == .search || mode == .history {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: onDismiss) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 28, height: 28)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Circle())
                            }
                            .padding(.top, 20)
                            .padding(.trailing, 20)
                        }
                        Spacer()
                    }
                }
            }
        )
        .alert("Usuń z historii", isPresented: $showDeleteConfirmation) {
            Button("Anuluj", role: .cancel) {}
            Button("Usuń", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Czy na pewno chcesz usunąć tę tablicę ze swojej historii skanowania?")
        }
        .onAppear {
            geocodeRegionSeat()
        }
    }
    
    @MapContentBuilder
    private var mapContent: some MapContent {
        if let boundaries = boundaryCoordinates {
            ForEach(0..<boundaries.count, id: \.self) { idx in
                MapPolygon(coordinates: boundaries[idx])
                    .foregroundStyle(accentColor.opacity(0.15))
                    .stroke(accentColor, lineWidth: 2)
            }
        }
        
        if let coord = markerCoordinate {
            Annotation(region.seat, coordinate: coord) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.25))
                        .frame(width: 42, height: 42)
                    
                    Circle()
                        .fill(accentColor)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                }
            }
        }
    }
    
    private var mapSection: some View {
        ZStack {
            if isGeocoding {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 200)
                    .overlay(
                        ProgressView()
                            .tint(accentColor)
                    )
            } else if let coord = markerCoordinate {
                Map(position: $position) {
                    mapContent
                }
                .mapStyle(.standard(pointsOfInterest: .all, showsTraffic: false))
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 200)
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "map.badge.xmark")
                                .foregroundColor(.white.opacity(0.4))
                                .font(.title2)
                            Text("Nie udało się załadować mapy")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                        }
                    )
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 26)
    }
    
    // MARK: - Actions / Helper Methods
    
    private func geocodeRegionSeat() {
        isGeocoding = true
        let query = "\(region.seat), \(region.wojewodztwo), Poland"
        let geocoder = CLGeocoder()
        
        // Load boundary polygon coordinates for the county
        self.boundaryCoordinates = BoundaryManager.shared.getBoundary(forPowiat: region.powiat)
        
        geocoder.geocodeAddressString(query) { placemarks, error in
            isGeocoding = false
            if let coordinate = placemarks?.first?.location?.coordinate {
                self.markerCoordinate = coordinate
                self.position = .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
                ))
            } else {
                print("Geocoding error for \(query): \(String(describing: error))")
            }
        }
    }
    
    private func sharePlateText() {
        let textToShare = formatPlate(plateText)
        shareSingle(item: textToShare)
    }

    private func shareSingle(item: Any) {
        let activityVC = UIActivityViewController(activityItems: [item], applicationActivities: nil)

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
    
    private func formatPlate(_ raw: String) -> String {
        if raw.contains(" ") {
            return raw.uppercased()
        }
        
        let clean = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        guard clean.count > 3 else { return clean }
        
        let prefixLength = region.prefix.count
        if clean.hasPrefix(region.prefix) {
            let index = clean.index(clean.startIndex, offsetBy: prefixLength)
            return "\(clean[..<index]) \(clean[index...])"
        }
        return clean
    }
}

// MARK: - Subviews & Supporting Views

struct DetailColumn: View {
    let title: String
    let value: String
    let icon: String
    var accentColor: Color = .blue
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(accentColor)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .kerning(1.0)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
