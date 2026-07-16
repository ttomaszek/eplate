import Foundation
import MapKit
import CoreLocation

final class BoundaryManager {
    // MARK: - Properties
    static let shared = BoundaryManager()
    
    private var boundaryCache: [String: [[CLLocationCoordinate2D]]] = [:]
    private var isLoaded = false
    
    // MARK: - Initialization
    private init() {
        // Load in background
        DispatchQueue.global(qos: .userInitiated).async {
            self.loadBoundaries()
        }
    }
    
    // MARK: - Public Lookup Methods
    
    /// Returns the coordinate boundary polygon coordinates for a given powiat name.
    func getBoundary(forPowiat powiatName: String) -> [[CLLocationCoordinate2D]]? {
        let normalizedKey = normalize(powiatName)
        return boundaryCache[normalizedKey]
    }
    
    // MARK: - Actions / Helper Methods
    
    private func normalize(_ name: String) -> String {
        var clean = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("powiat ") {
            clean = String(clean.dropFirst(7))
        }
        
        // Remove Polish diacritics for query resiliency using native API
        return clean.applyingTransform(.stripDiacritics, reverse: false) ?? clean
    }
    
    private func loadBoundaries() {
        guard let url = Bundle.main.url(forResource: "powiaty", withExtension: "geojson") else {
            print("Failed to locate powiaty.geojson in bundle.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let features = json["features"] as? [[String: Any]] else {
                return
            }
            
            var cache: [String: [[CLLocationCoordinate2D]]] = [:]
            
            for feature in features {
                guard let properties = feature["properties"] as? [String: Any],
                      let nazwa = properties["nazwa"] as? String,
                      let geometry = feature["geometry"] as? [String: Any],
                      let type = geometry["type"] as? String else {
                    continue
                }
                
                var boundaryPolygons: [[CLLocationCoordinate2D]] = []
                
                if type == "Polygon" {
                    guard let coordinates = geometry["coordinates"] as? [[[Double]]],
                          let outerRing = coordinates.first else { continue }
                    let locationCoords = outerRing.map { pt -> CLLocationCoordinate2D in
                        CLLocationCoordinate2D(latitude: pt[1], longitude: pt[0])
                    }
                    boundaryPolygons.append(locationCoords)
                } else if type == "MultiPolygon" {
                    guard let coordinates = geometry["coordinates"] as? [[[[Double]]]] else { continue }
                    for polyCoordinates in coordinates {
                        guard let outerRing = polyCoordinates.first else { continue }
                        let locationCoords = outerRing.map { pt -> CLLocationCoordinate2D in
                            CLLocationCoordinate2D(latitude: pt[1], longitude: pt[0])
                        }
                        boundaryPolygons.append(locationCoords)
                    }
                } else {
                    continue
                }
                
                if !boundaryPolygons.isEmpty {
                    let normalizedKey = normalize(nazwa)
                    cache[normalizedKey] = boundaryPolygons
                }
            }
            
            DispatchQueue.main.async {
                self.boundaryCache = cache
                self.isLoaded = true
                print("Successfully loaded \(self.boundaryCache.count) county boundaries into memory.")
            }
        } catch {
            print("Error loading powiaty.geojson: \(error)")
        }
    }
}
