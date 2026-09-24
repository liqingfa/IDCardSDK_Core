import XCTest
import UIKit
@testable import IDCardSDK_Core

final class IDCardSDKCoreTests: XCTestCase {
    func testIDNumberChecksumDateAndGender() {
        let result = IDNumberValidator.validate("11010519491231002X")
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.birthday, "1949-12-31")
        XCTAssertEqual(result.gender, .female)
        XCTAssertTrue(result.checkCodeValid)
        XCTAssertFalse(IDNumberValidator.validate("110105194912310021").isValid)
        XCTAssertFalse(IDNumberValidator.validate("110105199902300021").isValid)
    }

    func testFrontParserRequiresValidatedNumberAndAddress() throws {
        let observations = [
            o("姓名张三", 0.82), o("性别女民族汉", 0.70),
            o("出生1949年12月31日", 0.60), o("住址北京市东城区", 0.44),
            o("某某街道1号", 0.36), o("公民身份号码11010519491231002X", 0.10)
        ]
        XCTAssertEqual(CardSideDetector.detect(observations), .front)
        let fields = try IDCardParser.parseFront(observations)
        XCTAssertEqual(fields.name, "张三")
        XCTAssertEqual(fields.gender, .female)
        XCTAssertEqual(fields.nation, "汉")
        XCTAssertEqual(fields.birthday, "1949-12-31")
        XCTAssertEqual(fields.address, "北京市东城区某某街道1号")
        XCTAssertEqual(fields.idNumber, "11010519491231002X")
        XCTAssertThrowsError(try IDCardParser.parseFront(observations.dropLast().map { $0 }))
    }

    func testBackParserHandlesLongTermValidity() throws {
        let observations = [
            o("中华人民共和国居民身份证", 0.78),
            o("签发机关北京市公安局", 0.35),
            o("有效期限2015.01.01-长期", 0.20)
        ]
        XCTAssertEqual(CardSideDetector.detect(observations), .back)
        let fields = try IDCardParser.parseBack(observations)
        XCTAssertEqual(fields.authority, "北京市公安局")
        XCTAssertEqual(fields.validFrom, "2015-01-01")
        XCTAssertNil(fields.validTo)
        XCTAssertTrue(fields.isLongTerm)
    }

    func testSyntheticFrontImageThroughVision() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 630))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1000, height: 630))
            let style: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 42), .foregroundColor: UIColor.black
            ]
            for (text, y) in [
                ("姓名 张三", 55), ("性别 女   民族 汉", 130),
                ("出生 1949年12月31日", 205), ("住址 北京市东城区", 285),
                ("某某街道1号", 350), ("公民身份号码 11010519491231002X", 505)
            ] {
                (text as NSString).draw(at: CGPoint(x: 60, y: y), withAttributes: style)
            }
        }
        let result = try await IDCardRecognizer.shared.recognizeNormalizedCard(
            image: image, options: .init(checkImageQuality: false))
        guard case .front(let card) = result else { return XCTFail("Expected front") }
        XCTAssertEqual(card.name, "张三")
        XCTAssertEqual(card.idNumber, "11010519491231002X")
        XCTAssertTrue(card.isIDNumberValid)
    }

    private func o(_ text: String, _ y: CGFloat) -> IDCardOCRObservation {
        IDCardOCRObservation(text: text, boundingBox: CGRect(x: 0.1, y: y, width: 0.75, height: 0.06), confidence: 0.98)
    }
}
