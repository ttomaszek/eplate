import Foundation
import SwiftData
import UIKit

@Model
final class ScanHistoryItem: Identifiable {
    // MARK: - Properties
    @Attribute(.unique) var id: UUID
    var rawText: String
    var prefix: String
    var date: Date
    var powiat: String
    var wojewodztwo: String
    var seat: String
    var type: String
    var category: String = "standard"
    var imageFilename: String? = nil
    
    // MARK: - Initialization
    init(
        rawText: String,
        prefix: String,
        date: Date = Date(),
        powiat: String,
        wojewodztwo: String,
        seat: String,
        type: String,
        category: String = "standard",
        imageFilename: String? = nil
    ) {
        self.id = UUID()
        self.rawText = rawText
        self.prefix = prefix
        self.date = date
        self.powiat = powiat
        self.wojewodztwo = wojewodztwo
        self.seat = seat
        self.type = type
        self.category = category
        self.imageFilename = imageFilename
    }
    
    // MARK: - Computed Properties
    var displayName: String {
        switch type {
        case "urban":
            return "\(powiat)"
        case "district":
            return "\(powiat)"
        case "rural":
            return "Powiat \(powiat)"
        case "military":
            return "Wojsko Polskie"
        default:
            return powiat
        }
    }

    /// Resolved URL of the stored plate image, if available.
    var imageURL: URL? {
        guard let filename = imageFilename else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(filename)
    }

    /// Loads the plate thumbnail from disk, if available.
    var thumbnailImage: UIImage? {
        guard let url = imageURL else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
