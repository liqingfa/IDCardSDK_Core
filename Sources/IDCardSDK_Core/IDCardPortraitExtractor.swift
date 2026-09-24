import CoreGraphics
import UIKit
import Vision

enum IDCardPortraitExtractor {
    static func extract(from card: CGImage) -> UIImage? {
        let candidate = CGRect(x: CGFloat(card.width) * 0.62,
                               y: CGFloat(card.height) * 0.12,
                               width: CGFloat(card.width) * 0.35,
                               height: CGFloat(card.height) * 0.69).integral
        guard let portraitArea = card.cropping(to: candidate) else { return nil }

        let request = VNDetectFaceRectanglesRequest()
        guard (try? VNImageRequestHandler(cgImage: portraitArea).perform([request])) != nil,
              let face = request.results?.max(by: {
                  $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height
              }) else {
            return nil
        }

        let box = face.boundingBox
        let x = max(0, box.minX - box.width * 0.55)
        let top = max(0, 1 - box.maxY - box.height * 0.5)
        let right = min(1, box.maxX + box.width * 0.55)
        let bottom = min(1, 1 - box.minY + box.height * 1.0)
        let crop = CGRect(x: x * CGFloat(portraitArea.width),
                          y: top * CGFloat(portraitArea.height),
                          width: (right - x) * CGFloat(portraitArea.width),
                          height: (bottom - top) * CGFloat(portraitArea.height)).integral
        guard crop.width > 0, crop.height > 0,
              let result = portraitArea.cropping(to: crop) else { return UIImage(cgImage: portraitArea) }
        return UIImage(cgImage: result)
    }
}
