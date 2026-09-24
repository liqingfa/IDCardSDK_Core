import CoreGraphics
import CoreImage
import CoreVideo
import UIKit

public final class IDCardRecognizer {
    public static let shared = IDCardRecognizer()

    public init() {}

    public func recognize(image: UIImage,
                          options: IDCardRecognitionOptions = .init()) async throws -> IDCardRecognitionResult {
        let cgImage = try CardImageProcessor.cgImage(from: image)
        return try process(cgImage, original: options.includeOriginalImage ? image : nil,
                           alreadyNormalized: false, options: options)
    }

    public func recognize(cgImage: CGImage,
                          options: IDCardRecognitionOptions = .init()) async throws -> IDCardRecognitionResult {
        try process(cgImage, original: options.includeOriginalImage ? UIImage(cgImage: cgImage) : nil,
                    alreadyNormalized: false, options: options)
    }

    public func recognize(pixelBuffer: CVPixelBuffer,
                          options: IDCardRecognitionOptions = .init()) async throws -> IDCardRecognitionResult {
        let cgImage = try CardImageProcessor.cgImage(from: pixelBuffer)
        return try process(cgImage, original: options.includeOriginalImage ? UIImage(cgImage: cgImage) : nil,
                           alreadyNormalized: false, options: options)
    }

    public func recognizeNormalizedCard(image: UIImage,
                                        options: IDCardRecognitionOptions = .init()) async throws -> IDCardRecognitionResult {
        let cgImage = try CardImageProcessor.cgImage(from: image)
        return try process(cgImage, original: options.includeOriginalImage ? image : nil,
                           alreadyNormalized: true, options: options)
    }

    private func process(_ input: CGImage, original: UIImage?, alreadyNormalized: Bool,
                         options: IDCardRecognitionOptions) throws -> IDCardRecognitionResult {
        let downsampled = try CardImageProcessor.downsample(input)
        if options.checkImageQuality { try CardImageProcessor.checkQuality(downsampled) }
        let card: CGImage
        if alreadyNormalized {
            card = downsampled
        } else {
            do {
                card = try CardImageProcessor.detectAndRectify(downsampled)
            } catch IDCardSDKError.cardNotFound {
                let ratio = CGFloat(downsampled.width) / CGFloat(downsampled.height)
                guard (1.38...1.82).contains(ratio) else { throw IDCardSDKError.cardNotFound }
                card = downsampled
            }
        }

        let ocr = VisionOCRRecognizer()
        var firstFailure: IDCardSDKError = .cannotDetermineSide
        for quarterTurns in 0..<4 {
            let rotated = try rotate(card, quarterTurns: quarterTurns)
            let aspect = CGFloat(rotated.width) / CGFloat(rotated.height)
            guard (1.20...2.0).contains(aspect) else { continue }
            let oriented = try CardImageProcessor.normalize(rotated)
            let observations = try ocr.recognize(image: oriented)
            switch CardSideDetector.detect(observations) {
            case .front:
                do {
                    let fields = try IDCardParser.parseFront(observations)
                    return .front(IDCardFrontResult(
                        name: fields.name, gender: fields.gender, nation: fields.nation,
                        birthday: fields.birthday, address: fields.address, idNumber: fields.idNumber,
                        portrait: IDCardPortraitExtractor.extract(from: oriented),
                        cardImage: UIImage(cgImage: oriented), originalImage: original,
                        rawOCR: observations, confidence: fields.confidence, isIDNumberValid: true))
                } catch let error as IDCardSDKError {
                    firstFailure = error
                }
            case .back:
                do {
                    let fields = try IDCardParser.parseBack(observations)
                    return .back(IDCardBackResult(
                        authority: fields.authority, validFrom: fields.validFrom,
                        validTo: fields.validTo, isLongTerm: fields.isLongTerm,
                        cardImage: UIImage(cgImage: oriented), originalImage: original,
                        rawOCR: observations, confidence: fields.confidence))
                } catch let error as IDCardSDKError {
                    firstFailure = error
                }
            case .unknown:
                break
            }
        }
        throw firstFailure
    }

    private func rotate(_ image: CGImage, quarterTurns: Int) throws -> CGImage {
        guard quarterTurns != 0 else { return image }
        let orientation: CGImagePropertyOrientation = [.up, .right, .down, .left][quarterTurns]
        let ciImage = CIImage(cgImage: image).oriented(orientation)
        guard let output = CardImageProcessor.context.createCGImage(ciImage, from: ciImage.extent) else {
            throw IDCardSDKError.invalidImage
        }
        return output
    }
}
