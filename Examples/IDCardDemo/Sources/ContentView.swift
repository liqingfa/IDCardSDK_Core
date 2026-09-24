import IDCardSDK_Core
import PhotosUI
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var showPicker = false
    @State private var sourceImage: UIImage?
    @State private var result: IDCardRecognitionResult?
    @State private var errorText: String?
    @State private var isRecognizing = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("从相册选择身份证照片，在设备本地识别。")
                        .foregroundColor(.secondary)
                    Button("选择身份证照片") { showPicker = true }
                        .buttonStyle(.borderedProminent)
                    if let sourceImage {
                        Image(uiImage: sourceImage)
                            .resizable().scaledToFit().frame(maxHeight: 260)
                    }
                    if isRecognizing { ProgressView("正在识别") }
                    if let errorText {
                        Text(errorText).foregroundColor(.red)
                    }
                    if let result { resultView(result) }
                }
                .padding()
            }
            .navigationTitle("身份证识别 Demo")
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker { image in
                sourceImage = image
                result = nil
                errorText = nil
                isRecognizing = true
                Task {
                    do {
                        result = try await IDCardRecognizer.shared.recognize(image: image)
                    } catch {
                        errorText = "识别失败：\(error)"
                    }
                    isRecognizing = false
                }
            }
        }
    }

    @ViewBuilder
    private func resultView(_ result: IDCardRecognitionResult) -> some View {
        switch result {
        case .front(let card):
            VStack(alignment: .leading, spacing: 8) {
                Text("身份证正面").font(.headline)
                if let portrait = card.portrait {
                    Image(uiImage: portrait).resizable().scaledToFit().frame(height: 150)
                }
                field("姓名", card.name)
                field("性别", card.gender.rawValue)
                field("民族", card.nation)
                field("出生日期", card.birthday)
                field("住址", card.address)
                field("公民身份号码", card.idNumber)
                field("号码校验", card.isIDNumberValid ? "通过" : "失败")
                field("置信度", String(format: "%.2f", card.confidence))
                Image(uiImage: card.cardImage).resizable().scaledToFit()
            }
        case .back(let card):
            VStack(alignment: .leading, spacing: 8) {
                Text("身份证反面").font(.headline)
                field("签发机关", card.authority)
                field("有效期限开始", card.validFrom ?? "")
                field("有效期限结束", card.isLongTerm ? "长期" : card.validTo ?? "")
                field("置信度", String(format: "%.2f", card.confidence))
                Image(uiImage: card.cardImage).resizable().scaledToFit()
            }
        }
    }

    private func field(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label + "：").foregroundColor(.secondary)
            Text(value).textSelection(.enabled)
        }
    }
}

private struct ImagePicker: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                guard let image = image as? UIImage else { return }
                DispatchQueue.main.async { self.parent.onPick(image) }
            }
        }
    }
}
