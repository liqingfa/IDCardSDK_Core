import Foundation

enum CardSideDetector {
    static func detect(_ observations: [IDCardOCRObservation]) -> IDCardSide {
        let text = observations.map(\.text).joined(separator: " ")
        let frontWords = ["姓名", "性别", "民族", "出生", "住址", "公民身份号码", "身份号码"]
        let backWords = ["中华人民共和国", "居民身份证", "签发机关", "有效期限"]
        var front = frontWords.filter { text.contains($0) }.count
        let back = backWords.filter { text.contains($0) }.count
        if IDCardParser.findIDNumber(in: observations) != nil { front += 3 }
        if front >= 2 && front > back { return .front }
        if back >= 2 && back > front { return .back }
        return .unknown
    }
}

enum IDCardParser {
    struct FrontFields {
        let name: String
        let gender: IDCardGender
        let nation: String
        let birthday: String
        let address: String
        let idNumber: String
        let confidence: Float
    }

    struct BackFields {
        let authority: String
        let validFrom: String?
        let validTo: String?
        let isLongTerm: Bool
        let confidence: Float
    }

    static func parseFront(_ input: [IDCardOCRObservation]) throws -> FrontFields {
        let lines = ordered(input)
        guard let idNumber = findIDNumber(in: input) else { throw IDCardSDKError.invalidIDNumber }
        let validation = IDNumberValidator.validate(idNumber)
        guard validation.isValid, let validatedBirthday = validation.birthday else {
            throw IDCardSDKError.invalidIDNumber
        }
        let name = value(after: "姓名", in: lines) ?? nearestValue(to: "姓名", in: input)
        let cleanName = (name ?? "").replacingOccurrences(of: #"[^\p{Han}·]"#, with: "", options: .regularExpression)
        guard !cleanName.isEmpty, cleanName.count <= 12 else { throw IDCardSDKError.parseFailed }

        let genderText = value(after: "性别", in: lines) ?? lines.map(\.text).first(where: { $0.contains("性别") }) ?? ""
        let gender: IDCardGender = genderText.contains("女") ? .female :
            (genderText.contains("男") ? .male : (validation.gender ?? .unknown))
        let nationText = value(after: "民族", in: lines) ?? ""
        let nation = nationText.replacingOccurrences(of: #"[^\p{Han}]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "族", with: "")

        let recognizedBirthday = dates(in: lines.map(\.text).joined(separator: " ")).first
        let birthday = recognizedBirthday ?? validatedBirthday
        let address = parseAddress(lines)
        guard !address.isEmpty else { throw IDCardSDKError.parseFailed }

        let averageOCR = input.map(\.confidence).reduce(0, +) / Float(max(input.count, 1))
        let complete: Float = [!nameIsEmpty(cleanName), !nation.isEmpty, !address.isEmpty].filter { $0 }.count == 3 ? 1 : 0.7
        let birthdayConsistent: Float = recognizedBirthday == nil || recognizedBirthday == validatedBirthday ? 1 : 0
        let genderConsistent: Float = gender == validation.gender || gender == .unknown ? 1 : 0
        let layout: Float = input.contains { $0.text.contains("公民身份号码") } ? 1 : 0.6
        let confidence = min(1, averageOCR * 0.4 + complete * 0.2 + 0.2 +
                             (birthdayConsistent + genderConsistent) * 0.05 + layout * 0.1)
        return FrontFields(name: cleanName, gender: gender, nation: nation,
                           birthday: birthday, address: address, idNumber: idNumber,
                           confidence: confidence)
    }

    static func parseBack(_ input: [IDCardOCRObservation]) throws -> BackFields {
        let lines = ordered(input)
        let authority = (value(after: "签发机关", in: lines) ?? nearestValue(to: "签发机关", in: input) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !authority.isEmpty else { throw IDCardSDKError.parseFailed }
        let combined = lines.map(\.text).joined(separator: " ")
        let recognizedDates = dates(in: combined)
        guard let validFrom = recognizedDates.first else { throw IDCardSDKError.parseFailed }
        let longTerm = combined.contains("长期")
        let validTo = longTerm ? nil : recognizedDates.dropFirst().first
        guard longTerm || validTo != nil else { throw IDCardSDKError.parseFailed }
        let averageOCR = input.map(\.confidence).reduce(0, +) / Float(max(input.count, 1))
        let layout: Float = combined.contains("有效期限") ? 1 : 0.6
        return BackFields(authority: authority, validFrom: validFrom, validTo: validTo,
                          isLongTerm: longTerm, confidence: min(1, averageOCR * 0.7 + 0.2 + layout * 0.1))
    }

    static func findIDNumber(in input: [IDCardOCRObservation]) -> String? {
        let texts = input.map(\.text) + [input.map(\.text).joined(separator: "")]
        var fallback: String?
        for text in texts {
            let halfWidth = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
            let normalized = halfWidth.uppercased()
                .replacingOccurrences(of: "O", with: "0")
                .replacingOccurrences(of: "I", with: "1")
                .replacingOccurrences(of: "L", with: "1")
                .filter { $0.isNumber || $0 == "X" }
            let chars = Array(normalized)
            guard chars.count >= 18 else { continue }
            for start in 0...(chars.count - 18) {
                let candidate = String(chars[start..<(start + 18)])
                if IDNumberValidator.validate(candidate).isValid { return candidate }
                if fallback == nil { fallback = candidate }
            }
        }
        return fallback
    }

    private static func ordered(_ input: [IDCardOCRObservation]) -> [IDCardOCRObservation] {
        input.sorted { lhs, rhs in
            if abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > 0.035 {
                return lhs.boundingBox.midY > rhs.boundingBox.midY
            }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
    }

    private static func value(after label: String, in lines: [IDCardOCRObservation]) -> String? {
        for line in lines where line.text.contains(label) {
            let parts = line.text.components(separatedBy: label)
            if let tail = parts.dropFirst().first?.trimmingCharacters(in: .whitespacesAndNewlines), !tail.isEmpty {
                let labels = ["姓名", "性别", "民族", "出生", "住址", "公民身份号码", "签发机关", "有效期限"]
                let end = labels.filter { $0 != label }.compactMap { tail.range(of: $0)?.lowerBound }.min() ?? tail.endIndex
                let cleaned = String(tail[..<end]).replacingOccurrences(of: #"^[：:]"#, with: "", options: .regularExpression)
                if !cleaned.isEmpty { return cleaned }
            }
        }
        return nil
    }

    private static func nearestValue(to label: String, in input: [IDCardOCRObservation]) -> String? {
        guard let anchor = input.first(where: { $0.text.contains(label) }) else { return nil }
        return input.filter {
            $0.text != anchor.text && abs($0.boundingBox.midY - anchor.boundingBox.midY) < 0.065 &&
            $0.boundingBox.midX > anchor.boundingBox.midX
        }.min(by: { $0.boundingBox.minX < $1.boundingBox.minX })?.text
    }

    private static func parseAddress(_ lines: [IDCardOCRObservation]) -> String {
        guard let start = lines.firstIndex(where: { $0.text.contains("住址") }) else { return "" }
        var parts: [String] = []
        let startLine = lines[start]
        let tail = startLine.text.components(separatedBy: "住址").dropFirst().joined()
        if !tail.isEmpty { parts.append(tail) }
        for line in lines.dropFirst(start + 1) {
            if line.text.contains("公民身份号码") || line.text.contains("身份号码") ||
                findIDNumber(in: [line]) != nil { break }
            if line.boundingBox.midY < 0.16 { break }
            parts.append(line.text)
        }
        return parts.joined().replacingOccurrences(of: #"\s|[：:]"#, with: "", options: .regularExpression)
    }

    private static func dates(in text: String) -> [String] {
        let pattern = #"((?:19|20)\d{2})[年./\-]?(\d{1,2})[月./\-]?(\d{1,2})日?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let yearRange = Range(match.range(at: 1), in: text),
                  let monthRange = Range(match.range(at: 2), in: text),
                  let dayRange = Range(match.range(at: 3), in: text),
                  let month = Int(text[monthRange]), let day = Int(text[dayRange]) else { return nil }
            let digits = String(format: "%@%02d%02d", String(text[yearRange]), month, day)
            return DateParser.isoDate(fromDigits: digits)
        }
    }

    private static func nameIsEmpty(_ name: String) -> Bool { name.isEmpty }
}
