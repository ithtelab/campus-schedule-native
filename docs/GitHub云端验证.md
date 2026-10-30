# Windows → GitHub macOS 原生验证

私有仓库：[ithtelab/campus-schedule-native](https://github.com/ithtelab/campus-schedule-native)。当前默认分支 `master`，后续新功能分支使用 `codex/` 前缀。

## 使用方式

源码、工程或构建脚本推送到 `master` / `codex/**` 后自动运行；只修改文档不会触发。也可在 GitHub Actions 中手动运行 **Native iOS UI validation**。

工作流为 `.github/workflows/native-ui.yml`：

1. 用 Node 生成并检查 Xcode 工程。
2. `swift test` 验证共享规则。
3. Xcode 编译主 APP 与 Widget Extension，模拟器构建不使用签名。
4. 启动已安装的 iOS 27+ iPhone 模拟器，执行 `capture-ui.sh`。
5. 上传模拟器 APP、截图、检查结果和日志，产物保留三天。

使用 GitHub 官方 `xcode-27` 预览镜像，运行开始时记录实际 Xcode 与模拟器版本；如果环境缺失要求的 SDK/运行时则明确失败，不退回旧 SDK。每次作业最长 20 分钟，不配置额外付费预算，不自动购买任何订阅。账号额度或平台限制仍可能阻止执行。

## 本轮切换原因

2026-10-30，EAS 上传后提示当前账号本月免费 iOS 构建额度用尽，因此本次没有创建可编译的 EAS 构建。它与 Apple Developer Program 会员无关。未购买 Expo 订阅；改用用户已登录的 GitHub 账号和私有仓库。

连接器支持读写仓库与读取构建结果，但当前没有创建仓库或手动启动工作流的接口。这些必要操作通过已登录的 GitHub CLI 完成，令牌未写入工程或工作流。

## 新增原生验收证据

- `campus-assets-test.txt`：实际从 APP 包读取人物图集，并由 UIKit 找到注册的手写字体。
- `today-sticky-*-test.txt`：真实滚动今日页后检查固定 Section 头相对滚动视口的位置。
- `today-sticky-*.png`：滚动后的原生画面。
- 大字体、长文本、进行中、今日结束、空课表等截图仅证明对应页面的渲染；不能替代完整交互与真机测试。

## 交付边界

当前工作流不上传 TestFlight，不发布 App Store，不生成可直接安装到 iPhone 的签名 IPA。应用标识和 App Group 仍是占位值，正式签名需后续配置。无签名模拟器的 App Group 限制和实时活动后台生命周期仍按原验证记录保留，不由本次 UI 验收替代。

## 官方来源

- [GitHub Xcode 27 镜像公告](https://github.com/actions/runner-images/issues/14404)
- [checkout 官方说明](https://github.com/actions/checkout)
- [upload-artifact 官方说明](https://github.com/actions/upload-artifact)
