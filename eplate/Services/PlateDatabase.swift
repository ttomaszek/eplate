import Foundation

final class PlateDatabase {
    // MARK: - Properties
    static let shared = PlateDatabase()
    
    private var database: [String: RegionModel] = [:]
    
    // MARK: - Initialization
    private init() {
        loadDatabase()
    }
    
    // MARK: - Database Loading
    private func loadDatabase() {
        guard let url = Bundle.main.url(forResource: "polish_plates", withExtension: "json") else {
            print("Failed to locate polish_plates.json in bundle.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let regions = try decoder.decode([RegionModel].self, from: data)
            // Map by prefix for O(1) lookups
            for region in regions {
                database[region.prefix.uppercased()] = region
            }
            print("Successfully loaded \(database.count) plate prefixes into memory.")
        } catch {
            print("Error loading or decoding polish_plates.json: \(error)")
        }
    }
    
    // MARK: - Public Lookup Methods
    
    /// Looks up a specific prefix directly (e.g. "DW")
    func lookup(prefix: String) -> RegionModel? {
        return database[prefix.uppercased()]
    }
    
    /// Parses a raw scanned license plate string and attempts to match a region.
    /// Returns the matched RegionModel and the fully corrected plate text if found.
    func match(plateText: String) -> (region: RegionModel, correctedText: String)? {
        // 1. Clean the text: Uppercase, retain only letters and digits
        var cleaned = plateText.uppercased().filter { $0.isLetter || $0.isNumber }
        
        // 2. Strip leading country identifier "PL" if it's followed by letters
        if cleaned.hasPrefix("PL") && cleaned.count >= 6 {
            let index2 = cleaned.index(cleaned.startIndex, offsetBy: 2)
            if cleaned[index2].isLetter {
                cleaned = String(cleaned.dropFirst(2))
            }
        }
        
        // 3. Short / Reduced Plate match check (exactly 4 characters)
        if cleaned.count == 4 {
            let firstChar = cleaned.first!
            let voivodeships: Set<Character> = ["D", "C", "L", "F", "E", "K", "W", "O", "R", "B", "G", "S", "T", "N", "P", "Z"]
            if voivodeships.contains(firstChar) {
                // Check if this is actually a classic plate of length 4 (e.g. BIA 1 or PO 12)
                let prefix3 = String(cleaned.prefix(3))
                let isClassic3 = lookup(prefix: prefix3) != nil
                
                let prefix2 = String(cleaned.prefix(2))
                let isClassic2 = lookup(prefix: prefix2) != nil && cleaned.suffix(2).allSatisfy({ $0.isNumber })
                
                if !isClassic3 && !isClassic2 {
                    let suffix = String(cleaned.dropFirst(1))
                    let hasDigits = suffix.contains(where: { $0.isNumber })
                    let hasLetters = suffix.contains(where: { $0.isLetter })
                    if hasDigits && hasLetters {
                        if let baseRegion = getRegionForVoivodeship(letter: firstChar) {
                            let shortRegion = RegionModel(
                                prefix: String(firstChar),
                                powiat: baseRegion.wojewodztwo,
                                wojewodztwo: baseRegion.wojewodztwo,
                                seat: baseRegion.seat,
                                type: "reduced"
                            )
                            return (shortRegion, "\(firstChar) \(suffix)")
                        }
                    }
                }
            }
        }
        
        // Minimum length 4 (classic plates e.g. PO 12, BIA 1), maximum 8 characters
        guard cleaned.count >= 4 && cleaned.count <= 8 else { return nil }
        
        // 3.5. Try to match a Custom Plate first (e.g. "W1 RALLY")
        if cleaned.count >= 5 && cleaned.count <= 7 {
            let firstChar = cleaned.first!
            let secondChar = cleaned[cleaned.index(cleaned.startIndex, offsetBy: 1)]
            let customVoivodeships: Set<Character> = ["D", "C", "L", "F", "E", "K", "W", "O", "R", "B", "G", "S", "T", "N", "P", "Z"]
            
            if customVoivodeships.contains(firstChar) {
                var digitChar = secondChar
                if !digitChar.isNumber {
                    if let corrected = mapLetterToDigit(digitChar) {
                        digitChar = corrected
                    }
                }
                
                if digitChar.isNumber {
                    let suffix = String(cleaned.dropFirst(2))
                    if isValidCustomSuffix(suffix) {
                        if let region = getRegionForCustomPlate(voivodeshipLetter: firstChar) {
                            return (region, "\(firstChar)\(digitChar) \(suffix)")
                        }
                    }
                }
            }
        }
        
        // 4. Try to match a 3-letter prefix first (e.g. "HPS", "DWR", "BIA")
        if cleaned.count >= 3 {
            let prefix3 = String(cleaned.prefix(3))
            if prefix3.allSatisfy({ $0.isLetter }) {
                if let region = lookup(prefix: prefix3) {
                    let rawSuffix = String(cleaned.dropFirst(3))
                    let isClassic = isValidClassicSuffix(rawSuffix, prefixLength: 3)
                    
                    guard rawSuffix.count == 4 || rawSuffix.count == 5 || isClassic else { return nil }
                    
                    let correctedSuffix: String
                    if isClassic {
                        correctedSuffix = correctClassicSuffix(rawSuffix, prefixLength: 3)
                    } else {
                        correctedSuffix = correctSuffix(rawSuffix, prefixLength: 3)
                        
                        let letters = correctedSuffix.filter { $0.isLetter }.count
                        if correctedSuffix.count == 5 && letters > 2 { return nil }
                        if correctedSuffix.count == 4 && letters > 3 { return nil }
                        
                        guard !hasMoreThanThreeConsecutiveLetters(correctedSuffix) else { return nil }
                    }
                    
                    return (region, "\(prefix3) \(correctedSuffix)")
                }
            }
        }
        
        // 5. Try to match a 2-letter prefix (e.g. "UA", "DW", "PO")
        let prefix2 = String(cleaned.prefix(2))
        if prefix2.allSatisfy({ $0.isLetter }) {
            if let region = lookup(prefix: prefix2) {
                let rawSuffix = String(cleaned.dropFirst(2))
                let isClassic = isValidClassicSuffix(rawSuffix, prefixLength: 2)
                
                guard rawSuffix.count == 4 || rawSuffix.count == 5 || isClassic else { return nil }
                
                let correctedSuffix: String
                if isClassic {
                    correctedSuffix = correctClassicSuffix(rawSuffix, prefixLength: 2)
                } else {
                    correctedSuffix = correctSuffix(rawSuffix, prefixLength: 2)
                    
                    // Enforce that standard 2-letter plates start with a digit
                    guard correctedSuffix.first?.isLetter == false else { return nil }
                    
                    let letters = correctedSuffix.filter { $0.isLetter }.count
                    if correctedSuffix.count == 5 && letters > 2 { return nil }
                    if correctedSuffix.count == 4 && letters > 3 { return nil }
                    
                    guard !hasMoreThanThreeConsecutiveLetters(correctedSuffix) else { return nil }
                }
                
                return (region, "\(prefix2) \(correctedSuffix)")
            }
        }
        
        return nil
    }
    
    /// Classifies a matched plate to return its category/styling type.
    func classify(plateText: String, region: RegionModel) -> String {
        // 1. If the matched region type is military, custom, police, or reduced, return that category directly
        switch region.type {
        case "military":
            return "military"
        case "service":
            return "police"
        case "custom":
            return "custom"
        case "reduced":
            return "reduced"
        default:
            break
        }
        
        let clean = plateText.uppercased().filter { $0.isLetter || $0.isNumber }
        let prefix = region.prefix
        
        // 2. Otherwise, check if it's a classic/vintage yellow plate based on suffix layout
        if clean.hasPrefix(prefix) {
            let suffix = String(clean.dropFirst(prefix.count))
            if prefix.count == 2 {
                // 2-letter prefix + 2 digits (e.g. "12") OR + 2 digits + 1 letter (e.g. "12A")
                if suffix.count == 2 {
                    if suffix.allSatisfy({ $0.isNumber }) {
                        return "classic"
                    }
                } else if suffix.count == 3 {
                    let d1 = suffix[suffix.startIndex].isNumber
                    let d2 = suffix[suffix.index(suffix.startIndex, offsetBy: 1)].isNumber
                    let l1 = suffix[suffix.index(suffix.startIndex, offsetBy: 2)].isLetter
                    if d1 && d2 && l1 {
                        return "classic"
                    }
                }
            } else if prefix.count == 3 {
                // 3-letter prefix + 1 or 2 digits (e.g. "1", "12") OR + trailing letter silhouette ("1A", "12A")
                if suffix.count == 2 {
                    // Check digit + letter
                    let d1 = suffix[suffix.startIndex].isNumber
                    let l1 = suffix[suffix.index(suffix.startIndex, offsetBy: 1)].isLetter
                    if d1 && l1 { return "classic" }
                    // Check 2 digits
                    if suffix.allSatisfy({ $0.isNumber }) {
                        return "classic"
                    }
                } else if suffix.count == 3 {
                    // Check "1AB" (1 digit, 2 letters)
                    let d1 = suffix[suffix.startIndex].isNumber
                    let l1 = suffix[suffix.index(suffix.startIndex, offsetBy: 1)].isLetter
                    let l2 = suffix[suffix.index(suffix.startIndex, offsetBy: 2)].isLetter
                    if d1 && l1 && l2 {
                        return "classic"
                    }
                    // Check "12A" (2 digits, 1 letter)
                    let d2_1 = suffix[suffix.startIndex].isNumber
                    let d2_2 = suffix[suffix.index(suffix.startIndex, offsetBy: 1)].isNumber
                    let l2_1 = suffix[suffix.index(suffix.startIndex, offsetBy: 2)].isLetter
                    if d2_1 && d2_2 && l2_1 {
                        return "classic"
                    }
                }
            }
        }
        
        return "standard"
    }
}

// MARK: - Character Type Definitions
private enum CharType {
    case digit
    case letter
}

// MARK: - Private Extensions & Helpers
extension PlateDatabase {
    // Standard 5-character suffix layouts
    private var patterns5: [[CharType]] {
        return [
            [.digit, .digit, .digit, .digit, .digit],
            [.digit, .digit, .digit, .digit, .letter],
            [.digit, .digit, .digit, .letter, .letter],
            [.digit, .letter, .digit, .digit, .digit],
            [.digit, .letter, .letter, .digit, .digit]
        ]
    }
    
    // Standard 4-character suffix layouts for 2-letter prefix plates (Motorcycles/Trailers)
    private var patterns4For2LetterPrefix: [[CharType]] {
        return [
            [.digit, .digit, .digit, .digit],
            [.digit, .digit, .digit, .letter],
            [.digit, .digit, .letter, .digit],
            [.digit, .letter, .digit, .digit],
            [.digit, .digit, .letter, .letter],
            [.digit, .letter, .letter, .digit]
        ]
    }
    
    // Standard 4-character suffix layouts for 3-letter prefix plates (Cars/Motorcycles)
    private var patterns4For3LetterPrefix: [[CharType]] {
        return [
            [.digit, .digit, .digit, .digit],
            [.digit, .digit, .digit, .letter],
            [.digit, .digit, .letter, .digit],
            [.digit, .letter, .digit, .digit],
            [.letter, .digit, .digit, .digit],
            [.letter, .digit, .digit, .letter],
            [.letter, .digit, .letter, .digit],
            [.digit, .letter, .digit, .letter],
            [.digit, .letter, .letter, .digit],
            [.letter, .letter, .digit, .digit],
            [.letter, .letter, .digit, .letter],
            [.letter, .letter, .letter, .digit]
        ]
    }
    
    private func correctSuffix(_ rawSuffix: String, prefixLength: Int) -> String {
        let suffix = rawSuffix.uppercased()
        let length = suffix.count
        
        guard length == 4 || length == 5 else { return suffix }
        
        let patterns = (length == 5) ? patterns5 : (prefixLength == 2 ? patterns4For2LetterPrefix : patterns4For3LetterPrefix)
        
        var bestCorrected = suffix
        var minCost = Int.max
        
        for pattern in patterns {
            var currentCorrected = ""
            var currentCost = 0
            
            for (i, char) in suffix.enumerated() {
                let expectedType = pattern[i]
                let isCharDigit = char.isNumber
                
                if expectedType == .digit {
                    if isCharDigit {
                        currentCorrected.append(char)
                    } else {
                        if let digit = mapLetterToDigit(char) {
                            currentCorrected.append(digit)
                            currentCost += 1
                        } else {
                            currentCorrected.append(char)
                            currentCost += 5
                        }
                    }
                } else {
                    if !isCharDigit {
                        currentCorrected.append(char)
                    } else {
                        if let letter = mapDigitToLetter(char) {
                            currentCorrected.append(letter)
                            currentCost += 1
                        } else {
                            currentCorrected.append(char)
                            currentCost += 5
                        }
                    }
                }
            }
            
            if currentCost < minCost {
                minCost = currentCost
                bestCorrected = currentCorrected
            }
        }
        
        if minCost >= 3 {
            return suffix
        }
        
        return bestCorrected
    }
    
    private func mapLetterToDigit(_ char: Character) -> Character? {
        switch char {
        case "B": return "8"
        case "O", "Q": return "0"
        case "I", "L": return "1"
        case "Z": return "2"
        case "S": return "5"
        default: return nil
        }
    }
    
    private func mapDigitToLetter(_ char: Character) -> Character? {
        switch char {
        case "8": return "B"
        case "0": return "O"
        case "1": return "I"
        case "2": return "Z"
        case "5": return "S"
        default: return nil
        }
    }
    
    private func hasMoreThanThreeConsecutiveLetters(_ string: String) -> Bool {
        var consecutiveCount = 0
        for char in string {
            if char.isLetter {
                consecutiveCount += 1
                if consecutiveCount > 3 {
                    return true
                }
            } else {
                consecutiveCount = 0
            }
        }
        return false
    }
    
    private func isValidCustomSuffix(_ suffix: String) -> Bool {
        let length = suffix.count
        guard length >= 3 && length <= 5 else { return false }
        
        let nonDigitPart = suffix.prefix(length - 2)
        guard nonDigitPart.allSatisfy({ $0.isLetter }) else { return false }
        
        let lastTwo = suffix.suffix(2)
        guard lastTwo.allSatisfy({ $0.isLetter || $0.isNumber }) else { return false }
        
        return true
    }
    
    private func getRegionForVoivodeship(letter: Character) -> RegionModel? {
        let prefixMap: [Character: String] = [
            "B": "BI", "C": "CB", "D": "DW", "E": "EL", "F": "FG", "G": "GD",
            "K": "KR", "L": "LU", "N": "NO", "O": "OP", "P": "PO", "R": "RZ",
            "S": "SK", "T": "TK", "W": "WI", "Z": "ZS"
        ]
        guard let pfx = prefixMap[letter] else { return nil }
        return lookup(prefix: pfx)
    }
    
    private func getRegionForCustomPlate(voivodeshipLetter: Character) -> RegionModel? {
        guard let baseRegion = getRegionForVoivodeship(letter: voivodeshipLetter) else { return nil }
        return RegionModel(
            prefix: String(voivodeshipLetter),
            powiat: "Tablica indywidualna",
            wojewodztwo: baseRegion.wojewodztwo,
            seat: baseRegion.seat,
            type: "custom"
        )
    }
    
    private func isValidClassicSuffix(_ suffix: String, prefixLength: Int) -> Bool {
        let cleanSuffix = suffix.uppercased()
        
        if prefixLength == 2 {
            // Case 1: 2 digits + 1 letter (e.g. "12A")
            if cleanSuffix.count == 3 {
                let d1 = cleanSuffix[cleanSuffix.startIndex].isNumber
                let d2 = cleanSuffix[cleanSuffix.index(cleanSuffix.startIndex, offsetBy: 1)].isNumber
                let l1 = cleanSuffix[cleanSuffix.index(cleanSuffix.startIndex, offsetBy: 2)].isLetter
                return d1 && d2 && l1
            }
            // Case 2: 2 digits + 1 letter + 1 letter (e.g. "12AB" - trailing letter is silhouette)
            if cleanSuffix.count == 4 {
                let d1 = cleanSuffix[cleanSuffix.startIndex].isNumber
                let d2 = cleanSuffix[cleanSuffix.index(cleanSuffix.startIndex, offsetBy: 1)].isNumber
                let l1 = cleanSuffix[cleanSuffix.index(cleanSuffix.startIndex, offsetBy: 2)].isLetter
                let l2 = cleanSuffix[cleanSuffix.index(cleanSuffix.startIndex, offsetBy: 3)].isLetter
                return d1 && d2 && l1 && l2
            }
        } else if prefixLength == 3 {
            // Case 0: 1 digit (e.g. "1")
            if cleanSuffix.count == 1 {
                return cleanSuffix.allSatisfy({ $0.isNumber })
            }
            // Case 1: 1 digit + 1 letter (e.g. "1A") OR 2 digits (e.g. "12")
            if cleanSuffix.count == 2 {
                let d1 = cleanSuffix[cleanSuffix.startIndex].isNumber
                let l1 = cleanSuffix[cleanSuffix.index(cleanSuffix.startIndex, offsetBy: 1)].isLetter
                if d1 && l1 { return true }
                if cleanSuffix.allSatisfy({ $0.isNumber }) { return true }
            }
            // Case 2: 1 digit + 2 letters (e.g. "1AB") OR 2 digits + 1 letter (e.g. "12A")
            if cleanSuffix.count == 3 {
                let d1 = cleanSuffix[cleanSuffix.startIndex].isNumber
                let l1 = cleanSuffix[cleanSuffix.index(cleanSuffix.startIndex, offsetBy: 1)].isLetter
                let l2 = cleanSuffix[cleanSuffix.index(cleanSuffix.startIndex, offsetBy: 2)].isLetter
                if d1 && l1 && l2 { return true }
                
                let d2_1 = cleanSuffix[cleanSuffix.startIndex].isNumber
                let d2_2 = cleanSuffix[cleanSuffix.index(cleanSuffix.startIndex, offsetBy: 1)].isNumber
                let l2_1 = cleanSuffix[cleanSuffix.index(cleanSuffix.startIndex, offsetBy: 2)].isLetter
                if d2_1 && d2_2 && l2_1 { return true }
            }
        }
        return false
    }
    
    private func correctClassicSuffix(_ suffix: String, prefixLength: Int) -> String {
        let cleanSuffix = suffix.uppercased()
        var corrected = ""
        
        if prefixLength == 2 {
            // If count is 4 (e.g. "12AB"), strip the last letter (silhouette) to get "12A"
            let target: String
            if cleanSuffix.count == 4 {
                target = String(cleanSuffix.dropLast())
            } else {
                target = cleanSuffix
            }
            
            // Correct format: digit, digit, letter
            for (i, char) in target.enumerated() {
                if i < 2 {
                    if char.isNumber {
                        corrected.append(char)
                    } else if let digit = mapLetterToDigit(char) {
                        corrected.append(digit)
                    } else {
                        corrected.append(char)
                    }
                } else {
                    if char.isLetter {
                        corrected.append(char)
                    } else if let letter = mapDigitToLetter(char) {
                        corrected.append(letter)
                    } else {
                        corrected.append(char)
                    }
                }
            }
        } else if prefixLength == 3 {
            // If count is 3 (e.g. "1AB" -> "1A", or "12A" -> "12"), drop the last letter (silhouette)
            let target: String
            if cleanSuffix.count == 3 {
                target = String(cleanSuffix.dropLast())
            } else {
                target = cleanSuffix
            }
            
            // If remaining target has length 2 and is digits (e.g. "12"): correct as numbers
            // Else, correct as pattern: digit, letter
            if target.count == 2 {
                let allNumbers = target.allSatisfy({ $0.isNumber || mapLetterToDigit($0) != nil })
                if allNumbers {
                    for char in target {
                        if char.isNumber {
                            corrected.append(char)
                        } else if let digit = mapLetterToDigit(char) {
                            corrected.append(digit)
                        } else {
                            corrected.append(char)
                        }
                    }
                } else {
                    // Pattern: digit, letter
                    for (i, char) in target.enumerated() {
                        if i == 0 {
                            if char.isNumber {
                                corrected.append(char)
                            } else if let digit = mapLetterToDigit(char) {
                                corrected.append(digit)
                            } else {
                                corrected.append(char)
                            }
                        } else {
                            if char.isLetter {
                                corrected.append(char)
                            } else if let letter = mapDigitToLetter(char) {
                                corrected.append(letter)
                            } else {
                                corrected.append(char)
                            }
                        }
                    }
                }
            } else {
                // Suffix has length 1 (digit only)
                for char in target {
                    if char.isNumber {
                        corrected.append(char)
                    } else if let digit = mapLetterToDigit(char) {
                        corrected.append(digit)
                    } else {
                        corrected.append(char)
                    }
                }
            }
        }
        
        return corrected.isEmpty ? cleanSuffix : corrected
    }
    
    /// Returns all standard regions loaded in the database.
    func getAllRegions() -> [RegionModel] {
        return Array(database.values).sorted(by: { $0.powiat < $1.powiat })
    }
    
    /// Returns all military plate definitions.
    func getMilitaryPlates() -> [RegionModel] {
        return Array(database.values)
            .filter { $0.type == "military" }
            .sorted(by: { $0.prefix < $1.prefix })
    }
    
    /// Returns all police command seat definitions.
    func getPoliceSeats() -> [RegionModel] {
        return Array(database.values)
            .filter { $0.type == "service" && $0.prefix.hasPrefix("HP") }
            .sorted(by: { $0.prefix < $1.prefix })
    }
    
    /// Returns other special service definitions.
    func getSpecialServicePlates() -> [RegionModel] {
        return Array(database.values)
            .filter { $0.type == "service" && !$0.prefix.hasPrefix("HP") }
            .sorted(by: { $0.prefix < $1.prefix })
    }
}
