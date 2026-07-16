import Foundation

struct RegionModel: Codable, Identifiable, Hashable {
    var id: String { prefix }
    let prefix: String
    let powiat: String
    let wojewodztwo: String
    let seat: String
    let type: String // "urban", "rural", "district"
    
    var displayName: String {
        switch type {
        case "urban":
            return "\(powiat)"
        case "district":
            return "\(powiat)"
        case "rural":
            return "Powiat \(powiat)"
        default:
            return powiat
        }
    }
}
