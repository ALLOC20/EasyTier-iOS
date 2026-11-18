# iOS 15 兼容性迁移报告（`ios15` 分支）

> 基线：上游 `main`（`17c74db`）。改动：13 个文件，+388/-96，commit `07d423b`。
> 目标：deployment target 从 iOS 16.0 降至 **iOS 15.0**（服务 TrollStore iOS 15.6 设备）。
> macOS 侧不动（仍为 13.0），iOS 16+ 行为完全保持原样。

## 一、兼容层（`EasyTier/Utils/Compatibility.swift`）

采用**模块内同名 shadow 类型**方案：类型/方法名与 SwiftUI 完全一致，
调用点零改动，运行时按 `#available` 分流（iOS 16+ 走原生实现，iOS 15 走回退）。

| 兼容项 | 替代的 iOS 16+ API | 调用点 | iOS 15 回退 |
|---|---|---|---|
| `LabeledContent`（shadow struct） | SwiftUI.LabeledContent | 76 | HStack 行布局（纯文本值 secondary 灰、右对齐） |
| `NavigationStack`（shadow struct） | SwiftUI.NavigationStack | 15 | `NavigationView` + `.stack` 样式 |
| `compatGroupedForm()` | `.formStyle(.grouped)` | 25 | no-op（iOS 15 的 Form 本就是 grouped） |
| `compatScrollDismissesKeyboard()` | `.scrollDismissesKeyboard(.immediately)` | 11 | 点按收起键盘 |
| `AdaptiveVerticalTextField` | `TextField(axis: .vertical)` | 5 | 单行 TextField |
| `compatLineLimit(2...4)` | 范围版 `lineLimit` | 3 | 固定下限值 |
| `adaptiveTextFieldAlert` | alert 内嵌 TextField | 2 | sheet 表单（字段/按钮一致） |
| `compatWidgetAccentable()`（Widget target） | `.widgetAccentable()` | 1 | no-op |

另外在 `AdaptiveNavigation.swift` 补了第三分支：iOS 15 上用隐藏
`NavigationLink(isActive:)` 实现程序化推送导航。

## 二、手工改写

- **DashboardView**：`Task.sleep(for:)` → `Task.sleep(nanoseconds:)`（`for:` 是 iOS 16 API）
- **NetworkEditView**：iOS 分支的 value-based `NavigationLink` 用 `#available(iOS 16)` 门控，iOS 15 走 destination 式链接
- **StatusView**：`ViewThatFits` 门控（iOS 15 iPad 直接用双栏布局）
- **Widget.swift**：`ToggleVPNConnectionIntent` 标注 `@available(iOS 16)`；iOS 17 以下按钮改纯展示（低版本 Widget 本不支持交互）；`#available` 域改用 `iOSApplicationExtension`
- **ControlWidget.swift**：`ToggleVPNIntent` 补 `@available(iOS 18.0)`（`SetValueIntent` 实测为 iOS 18+ API）
- **project.pbxproj**：4 个 target 的 `IPHONEOS_DEPLOYMENT_TARGET` 全部 16.0 → 15.0

## 三、iOS 15 上的已知行为差异（按设计取舍）

1. Widget 无一键开关按钮（iOS 15 Widget 不支持交互），只显示状态
2. 键盘收起方式：滚动收起 → 点按收起
3. 新建/重命名网络的弹窗：alert → sheet
4. ControlWidget / Siri 快捷指令不可用（AppIntents 生态 16+/18+，与 16 时期一致）

核心 VPN 功能（NetworkExtension 隧道 + Rust FFI 数据面）**完全不受影响**。

## 四、编译验证

### 本地（M1 MacBook Air）
- 需要 **Xcode 27.2+**（代码含 iOS 27.1 门控 API，旧 SDK 编不过）
- 打开 `EasyTier.xcodeproj`，选 `EasyTier` scheme → 真机（iOS 15.6）直接 Run

### GitHub Actions（fork）
- `xcode-27` 为 GitHub 官方标准托管标签，`nightly.yml` **无需任何修改**
- fork 后保持 public（Actions 免费），push 分支后在 Actions 页手动 Run workflow（选 `ios15` 分支），或推到 main 自动触发
- 产物：免签 TrollStore IPA（artifact + rolling `nightly` Release），全程零签名凭据

## 五、已排除的风险（实测）

| 风险 | 实测结果 |
|---|---|
| TOMLKit 最低版本 | iOS 13+（Package.swift 实测）✓ |
| `SetValueIntent` 可用性 | iOS 18.0+（官方文档），已正确标注 ✓ |
| `topBarLeading` 可用性 | iOS 14.0+（官方文档），target 15 直接可用 ✓ |
| iOS 17+ API（全仓） | 均已有 `#available` 门控 ✓ |
| Rust FFI / NetworkExtension | 不依赖 iOS 16/17 API ✓ |
