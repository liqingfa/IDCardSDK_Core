import CoreGraphics
import UIKit

public enum IDCardSide: String {
    case front, back, unknown
}

public enum IDCardGender: String {
    case male = "男"
    case female = "女"
    case unknown = "未知"
}

public struct IDCardOCRObservation {
    public let text: String
    /// Vision normalized coordinates, origin at the lower-left.
    public let boundingBox: CGRect
    public let confidence: Float

    public init(text: String, boundingBox: CGRect, confidence: Float) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

public struct IDCardRecognitionOptions {
    public var includeOriginalImage: Bool
    public var checkImageQuality: Bool

    public init(includeOriginalImage: Bool = false, checkImageQuality: Bool = true) {
        self.includeOriginalImage = includeOriginalImage
        self.checkImageQuality = checkImageQuality
    }
}

public struct IDNumberValidationResult {
    public let isValid: Bool
    public let birthday: String?
    public let gender: IDCardGender?
    public let checkCodeValid: Bool
}

public struct IDCardFrontResult {
    public let name: String
    public let gender: IDCardGender
    public let nation: String
    /// ISO 8601 calendar date, yyyy-MM-dd.
    public let birthday: String
    public let address: String
    public let idNumber: String
    public let portrait: UIImage?
    public let cardImage: UIImage
    public let originalImage: UIImage?
    public let rawOCR: [IDCardOCRObservation]
    public let confidence: Float
    public let isIDNumberValid: Bool
}

public struct IDCardBackResult {
    public let authority: String
    public let validFrom: String?
    public let validTo: String?
    public let isLongTerm: Bool
    public let cardImage: UIImage
    public let originalImage: UIImage?
    public let rawOCR: [IDCardOCRObservation]
    public let confidence: Float
}

public enum IDCardRecognitionResult {
    case front(IDCardFrontResult)
    case back(IDCardBackResult)

    public var side: IDCardSide {
        switch self {
        case .front: return .front
        case .back: return .back
        }
    }
}

public enum IDCardSDKError: Error, Equatable {
    case invalidImage
    case cardNotFound
    case cardIncomplete
    case imageTooBlurry
    case imageTooDark
    case imageTooBright
    case unsupportedCard
    case ocrFailed
    case cannotDetermineSide
    case invalidIDNumber
    case parseFailed
    case internalError
}
