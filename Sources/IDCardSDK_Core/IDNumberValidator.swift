import Foundation

public enum IDNumberValidator {
    private static let weights = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2]
    private static let checkCharacters = Array("10X98765432")

    public static func validate(_ input: String) -> IDNumberValidationResult {
        let value = input.uppercased()
        let characters = Array(value)
        let digits = characters.prefix(17).compactMap(\.wholeNumberValue)
        guard characters.count == 18,
              digits.count == 17,
              characters[17].isNumber || characters[17] == "X" else {
            return IDNumberValidationResult(isValid: false, birthday: nil, gender: nil, checkCodeValid: false)
        }

        var weightedSum = 0
        for index in 0..<17 { weightedSum += digits[index] * weights[index] }
        let checksumIndex = weightedSum % 11
        let checkCodeValid = characters[17] == checkCharacters[checksumIndex]
        let dateDigits = String(characters[6..<14])
        let birthday = DateParser.isoDate(fromDigits: dateDigits)
        let gender: IDCardGender = digits[16] % 2 == 0 ? .female : .male
        return IDNumberValidationResult(
            isValid: checkCodeValid && birthday != nil && !digits.prefix(6).allSatisfy({ $0 == 0 }),
            birthday: birthday,
            gender: gender,
            checkCodeValid: checkCodeValid
        )
    }
}

enum DateParser {
    static func isoDate(fromDigits digits: String) -> String? {
        guard digits.count == 8, digits.allSatisfy(\.isNumber),
              let year = Int(digits.prefix(4)),
              let month = Int(digits.dropFirst(4).prefix(2)),
              let day = Int(digits.suffix(2)) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components),
              calendar.dateComponents([.year, .month, .day], from: date) == components else { return nil }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
