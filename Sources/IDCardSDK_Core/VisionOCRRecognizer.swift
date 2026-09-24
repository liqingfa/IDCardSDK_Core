import CoreGraphics
import Vision

protocol OCRRecognizing {
    func recognize(image: CGImage) throws -> [IDCardOCRObservation]
}

struct VisionOCRRecognizer: OCRRecognizing {
    func recognize(image: CGImage) throws -> [IDCardOCRObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        guard let supported = try? request.supportedRecognitionLanguages(),
              supported.contains("zh-Hans") else { throw IDCardSDKError.ocrFailed }
        request.recognitionLanguages = supported.contains("en-US") ? ["zh-Hans", "en-US"] : ["zh-Hans"]
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.008
        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            throw IDCardSDKError.ocrFailed
        }
        return (request.results ?? []).compactMap { item in
            guard let candidate = item.topCandidates(1).first else { return nil }
            return IDCardOCRObservation(text: candidate.string,
                                        boundingBox: item.boundingBox,
                                        confidence: candidate.confidence)
        }
    }
}
