import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo
import UIKit
import Vision

enum CardImageProcessor {
    static let context = CIContext(options: [.useSoftwareRenderer: false])
    static let outputSize = CGSize(width: 1000, height: 630)

    static func cgImage(from image: UIImage) throws -> CGImage {
        guard image.size.width > 0, image.size.height > 0 else { throw IDCardSDKError.invalidImage }
        if image.imageOrientation == .up, let cgImage = image.cgImage { return cgImage }
        let maxDimension: CGFloat = 2400
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let corrected = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let cgImage = corrected.cgImage else { throw IDCardSDKError.invalidImage }
        return cgImage
    }

    static func cgImage(from pixelBuffer: CVPixelBuffer) throws -> CGImage {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let output = context.createCGImage(image, from: image.extent) else { throw IDCardSDKError.invalidImage }
        return output
    }

    static func downsample(_ image: CGImage, maxDimension: CGFloat = 2400) throws -> CGImage {
        let longest = CGFloat(max(image.width, image.height))
        guard longest > 0 else { throw IDCardSDKError.invalidImage }
        guard longest > maxDimension else { return image }
        let input = CIImage(cgImage: image)
        let scale = maxDimension / longest
        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = input
        filter.scale = Float(scale)
        filter.aspectRatio = 1
        guard let result = filter.outputImage,
              let output = context.createCGImage(result, from: result.extent) else { throw IDCardSDKError.invalidImage }
        return output
    }

    static func detectAndRectify(_ image: CGImage) throws -> CGImage {
        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = 0.55
        request.minimumAspectRatio = 0.48
        request.maximumAspectRatio = 0.82
        request.minimumSize = 0.14
        request.quadratureTolerance = 30
        request.maximumObservations = 8
        try VNImageRequestHandler(cgImage: image).perform([request])
        guard let rectangles = request.results, !rectangles.isEmpty else { throw IDCardSDKError.cardNotFound }
        let rectangle = rectangles.max { lhs, rhs in
            score(lhs) < score(rhs)
        }!
        let input = CIImage(cgImage: image)
        let width = CGFloat(image.width), height = CGFloat(image.height)
        func point(_ normalized: CGPoint) -> CGPoint {
            CGPoint(x: normalized.x * width, y: normalized.y * height)
        }
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = input
        filter.topLeft = point(rectangle.topLeft)
        filter.topRight = point(rectangle.topRight)
        filter.bottomLeft = point(rectangle.bottomLeft)
        filter.bottomRight = point(rectangle.bottomRight)
        guard let output = filter.outputImage,
              let corrected = context.createCGImage(output, from: output.extent) else {
            throw IDCardSDKError.cardIncomplete
        }
        return corrected
    }

    private static func score(_ rectangle: VNRectangleObservation) -> Float {
        let ratio = rectangle.boundingBox.height / max(rectangle.boundingBox.width, 0.001)
        let shape = max(0, 1 - abs(Float(ratio) - 0.631) * 2)
        let area = Float(rectangle.boundingBox.width * rectangle.boundingBox.height)
        return rectangle.confidence * (shape + area)
    }

    static func normalize(_ image: CGImage) throws -> CGImage {
        guard image.width > 0, image.height > 0 else { throw IDCardSDKError.invalidImage }
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        let rendered = renderer.image { _ in
            UIImage(cgImage: image).draw(in: CGRect(origin: .zero, size: outputSize))
        }
        guard let cgImage = rendered.cgImage else { throw IDCardSDKError.invalidImage }
        return cgImage
    }

    static func checkQuality(_ image: CGImage) throws {
        let width = 96, height = 60
        var pixels = [UInt8](repeating: 0, count: width * height)
        let space = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(data: &pixels, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width, space: space,
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let average = Double(pixels.reduce(0) { $0 + Int($1) }) / Double(pixels.count)
        if average < 28 { throw IDCardSDKError.imageTooDark }
        if average > 245 { throw IDCardSDKError.imageTooBright }
        var edges = 0
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = Int(pixels[y * width + x])
                let laplacian = abs(4 * center - Int(pixels[(y - 1) * width + x])
                                    - Int(pixels[(y + 1) * width + x])
                                    - Int(pixels[y * width + x - 1])
                                    - Int(pixels[y * width + x + 1]))
                edges += laplacian
            }
        }
        let edgeMean = Double(edges) / Double((width - 2) * (height - 2))
        if edgeMean < 2.0 { throw IDCardSDKError.imageTooBlurry }
    }
}
