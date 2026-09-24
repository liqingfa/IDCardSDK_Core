# 大陆居民身份证识别 SDK

`IDCardSDK_Core` 是 iOS 15+ 的本地身份证图片识别库。输入相册照片、`UIImage`、`CGImage` 或 `CVPixelBuffer`，SDK 会检测证件区域、校正透视、识别正反面、提取文字与正面头像，并校验 18 位公民身份号码。整个识别流程不发起网络请求，也不保存图片或识别结果。

## 快速开始

```swift
let result = try await IDCardRecognizer.shared.recognize(image: image)
switch result {
case .front(let card):
    print(card.name, card.idNumber)
    portraitImageView.image = card.portrait
case .back(let card):
    print(card.authority, card.validFrom ?? "")
}
```

已裁剪、摆正的证件图可用 `recognizeNormalizedCard(image:)`。`portrait` 为可选值；若未检测到真实人脸，不会把固定的右侧区域误当头像返回。`originalImage` 默认不保留，使用 `IDCardRecognitionOptions(includeOriginalImage: true)` 可要求返回。

## 集成

### Swift Package Manager

在 Xcode 的 **File → Add Package Dependencies → Add Local** 中选择本目录 `IDCardSDK_Core`，将库产品加入 App target。发布到 Git 仓库后，也可使用仓库 URL 与版本标签集成。示例工程位于 `Examples/IDCardDemo/IDCardDemo.xcodeproj`。

### CocoaPods

在 App 的 `Podfile` 中写入本地路径：

```ruby
platform :ios, '15.0'
use_frameworks!

target 'YourApp' do
  pod 'IDCardSDK_Core', :path => '/path/to/IDCardSDK_Core'
end
```

执行 `pod install` 并打开生成的 `.xcworkspace`。可直接打开已验证的示例：`Examples/IDCardDemoPods/IDCardDemoPods.xcworkspace`。若要通过 Git URL 或 CocoaPods 私有源发布，需先把 podspec 中的示例 `homepage` 和 `source` 换成实际仓库地址，并确定正式授权方式。

### 二进制包

执行 `Scripts/build-xcframework.sh`，输出位于 `build/IDCardSDK_Core.xcframework`，包含 iOS 真机与模拟器切片。源码集成的 SPM 和 CocoaPods 不依赖此二进制包。

## 接口与范围

公开接口、返回结构、错误类型见 `Docs/API.md`。V1.0 只处理已有图片；相机实时扫描、自动拍摄、人脸比对和联网真伪核验属于后续范围。证件号码校验只验证格式、日期与校验位，不能证明证件真实或持证人身份。

## 构建与验证

```bash
xcodebuild -scheme IDCardSDK_Core -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
xcodebuild -scheme IDCardSDK_Core -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test CODE_SIGNING_ALLOWED=NO
```

`Tests/` 含号码校验与正反面解析测试。真实照片准确率和耗时须按 `Docs/Validation.md` 在取得合法授权的脱敏样本上评估；目前不宣称达到需求文档中的准确率目标。示例 App 仅在用户选择照片后执行本地识别，不写入持久化存储。
