# SDK API 与错误说明

## 入口

```swift
try await IDCardRecognizer.shared.recognize(image: uiImage)
try await IDCardRecognizer.shared.recognize(cgImage: cgImage)
try await IDCardRecognizer.shared.recognize(pixelBuffer: pixelBuffer)
try await IDCardRecognizer.shared.recognizeNormalizedCard(image: croppedCard)
```

`recognize` 会做方向标准化、矩形检测、透视校正与 OCR。若矩形检测不到，但图片的长宽比接近证件，SDK 会按已裁好的图片尝试识别。`recognizeNormalizedCard` 跳过证件检测，适合业务已经拿到证件图的情况。两种入口都会进行 OCR、字段解析和号码校验。

`IDCardRecognitionOptions` 提供 `includeOriginalImage` 与 `checkImageQuality`。原图默认不返回；质量检查默认启用，其阈值在采集真实样本后仍需调优。

## 返回值

`IDCardRecognitionResult.front` 返回姓名、性别、民族、出生日期、住址、18 位号码、证件头像、标准化证件图、可选原图、OCR 行结果、置信度与号码校验状态。`back` 返回签发机关、有效期限起止日期、长期标识、标准化证件图、可选原图、OCR 行结果与置信度。日期字符串使用 `yyyy-MM-dd`；长期有效时 `validTo` 为 `nil`。

OCR 的 `boundingBox` 使用 Vision 坐标，原点位于左下角，范围为 `0...1`。`confidence` 是启发式组合分数，不是经过业务样本校准的概率，不能直接作为实名认证放行依据。

## 错误

| 错误 | 含义 |
| --- | --- |
| `invalidImage` | 输入图像无法读取或尺寸无效 |
| `cardNotFound` | 普通照片中未找到证件区域 |
| `cardIncomplete` | 矩形检测后无法完成透视校正 |
| `imageTooBlurry`、`imageTooDark`、`imageTooBright` | 图片质量检查失败 |
| `ocrFailed` | Vision OCR 失败或设备上的请求不支持简体中文 |
| `cannotDetermineSide` | 正反面关键词均不足 |
| `invalidIDNumber` | 正面号码缺失、日期无效或校验位不通过 |
| `parseFailed` | 必需字段无法提取 |

`unsupportedCard` 与 `internalError` 为未来扩展保留；当前代码不会主动抛出。调用方应向用户提供重新拍摄或手动核对入口，不应把空字段包装成识别成功。

## 隐私

SDK 不请求网络、不写入 `UserDefaults`、不存储原图或 OCR 数据、不输出个人信息日志。调用方若要保存身份证信息，应自行处理告知、授权、加密、访问控制和删除。示例 App 仅把结果保存在页面状态中。
