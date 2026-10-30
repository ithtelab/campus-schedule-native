# 大学生课表 · 原生 UI 原型

当前仅实现 SwiftUI 界面布局与内存中的演示交互，不接入学校、不持久化、不发送通知。正式名称待定，工程临时命名 CampusSchedule。

## 已实现布局

- 今日：课程状态卡、演示倒计时、当天摘要和课程时间线。
- 周课表：默认五天同屏、可选七天、星期日期、节次与作息、分时段网格、周次选择和滑动切周。
- 添加课程：名称、地点、教师、节次、单双周/指定周次、课程颜色及冲突提示；添加仅在当前演示会话生效。
- 学期与作息：学期名称、第一周周一、总周数、各节起止时间；修改仅在当前演示会话生效。
- 课程详情：课程名称、时间、节次、教室与教师。
- 设置：学校状态、提醒交互预览、外观与数据说明。
- DesignSystem：语义背景色、统一间距和圆角、课程配色及卡片。
- 使用系统 Tab、NavigationStack、Form 和 Sheet 承载原生视觉；未自制玻璃导航。原生 Liquid Glass 的实际表现需在目标 SDK 和设备验证。

## 目录

```text
CampusSchedule/
  App/                 应用与导航入口
  DesignSystem/        统一视觉与共享组件
  Features/
    Today/             今日安排
    Schedule/          周课表
    CourseDetail/      课程详情
    CourseEditor/      添加课程
    Settings/          设置、学期与作息
  PreviewData/         演示数据与可观察状态
ios/                   EAS 所需原生工程与空 Podfile
scripts/               Windows 工程生成、配置检查和模拟器启动工具
app.json               EAS 项目标识（不引入 Expo 运行时）
eas.json               模拟器构建配置
```

## Windows 与 macOS 工作流

Windows 编辑 Swift 文件，用 `npm run prepare:ios` 更新原生工程并提交 Git。生成脚本不依赖 Xcode；真正的 Swift 编译仍在 macOS 进行。具体 Expo 云端步骤见 [Expo 云端预览.md](docs/Expo云端预览.md)。

当前部署目标为 iOS 27.0，须使用包含 iOS 27 SDK 的 Xcode。若云端环境尚未提供所需 SDK，应停止构建并调整环境，不把缺少 SDK 误判为源码验证成功。部署目标和最低支持版本仍可在后续讨论调整。

macOS 上可在项目根目录运行：

```sh
npm run prepare:ios
xcodebuild -project ios/CampusSchedule.xcodeproj -scheme CampusSchedule -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

随后用 Xcode 打开生成工程，运行 iPhone 模拟器。真机签名、正式 bundle ID、图标和发布配置尚未设置。

## 验证状态与后续验收

第二版已通过 EAS 云端 Xcode 27.0 编译，在 iOS 27.0 / iPhone 17 模拟器启动并导出十二张截图：五个页面的深浅色版本，以及七天课表与辅助功能大字体列表，保存于 `screenshots/`。已检查截图并修复日期截断、时间轴错位、大字体时间拆行。尚未完成触控交互、业务自动化测试和真机验证。当前 Expo 账号尚无交互式 EAS Simulator 权限，截图不代表浏览器交互预览已可用。

最新验证构建：[d9d1219e-9c5a-43c5-9fbc-2f654a9b87bf](https://expo.dev/accounts/ithte/projects/campus-schedule-native/builds/d9d1219e-9c5a-43c5-9fbc-2f654a9b87bf)。用户已付款购买 Apple 开发者会员，会员仍在处理中，尚未开始 TestFlight 签名或上传。详细状态见 `docs/Expo云端预览.md`。

后续验收仍需检查：小屏 iPhone 与 iPad、VoiceOver、减少透明度、横竖屏、课程详情打开关闭、周次切换、表单添加/取消/保存、提醒设置显隐及长文本。周网格默认五天同屏，辅助功能大字体改用按天分组列表。UI 规范见 [UI设计规范.md](docs/UI设计规范.md)。

此阶段不加入仅复述静态布局的自动化测试。真实课程时间规则、数据合并与通知排程落地时再添加针对性的测试。
