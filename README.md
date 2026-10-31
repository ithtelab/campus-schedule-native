# 课间册 · iOS 原生工程

当前分发状态：新 App“课间册”（Apple ID `6829142615`）已有 15.1，Apple 处理 VALID、未过期，已关联本人内测组。用户反馈收不到邀请，当前测试者仍为 INVITED；已于 2026-10-31 19:11 重发一次，Apple 已受理，实际送达和安装待确认。新 App 暂无外测组或获批外测构建，旧 App 的公开链接已停用。详见 [邀请与公开下载排查](docs/TestFlight-课间册-邀请排查.md)。

历史 TestFlight：6.1 安装失败，7.1 外测提交返回 Apple 422；现按用户要求，旧 App 的所有构建均已过期，旧公开链接停用。历史凭证见 [TestFlight 发布](docs/TestFlight发布.md)，不再把旧测试资格视为当前可用。界面和功能代码仍保留；本轮重建的是分发配置。

当前已进入第二批实施：SwiftData 本地保存、课程操作、通知计划和 WidgetKit / ActivityKit 扩展已接入。本演示版正常启动使用样例和真实时钟，编辑仅在会话内生效，个人 SwiftData 文件保持隔离；组件读取演示快照，不接入学校。正式个人版本须关闭 `CampusDemoEdition` 构建标记。**系统组件与通知待真机验收，灵动岛完整后台自动结束尚未完成，不能视为全部功能已交付。** “课表”在商店重名后，用户选择并创建“课间册”，项目显示名称已同步，内部工程名称保持 CampusSchedule。详细状态见 [第二批实施记录](docs/第二批实施记录.md)。

## 已实现布局

- 今日：校园手绘标题、突出课程名的吸顶课程卡、统一三列日程；固定演示时间仅用于截图，正常启动使用实际时间。
- 周课表：默认五天同屏、可选七天、星期日期、节次与作息、分时段网格、周次选择和原生整页滑动切周。长按课程出现纸篓，投放只做互动，不删除课程。
- 添加课程：名称、地点、教师、节次、单双周/指定周次及冲突提示；个人模式保存到本机，截图演示模式不写入个人数据。历史颜色字段保留兼容，当前为单色界面。
- 学期与作息：学期名称、第一周周一、总周数、各节起止时间；个人模式保存后更新课程时间。
- 课程详情：课程名称、时间、节次、教室与教师。
- 设置：学校状态、提醒交互预览、外观与数据说明。
- DesignSystem：单色语义配色、手写标题、校园人物、统一间距与卡片。人物固定身份，按课前准备、换教室、上课、课间和当天结束变化，不随机播放；图集兼容深浅背景，不做整图反色，并遵守系统减少动态效果。见 [人物与课表联动](docs/校园人物交互.md)。
- 使用系统 Tab、NavigationStack、Form 和 Sheet 承载原生视觉；未自制玻璃导航。已在目标 SDK 模拟器渲染，真机表现仍待验收。

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
  Resources/           校园插画、标题字体与许可证
Shared/                课程规则、系统快照与组件内容
Widgets/               WidgetKit 与实时活动扩展
Tests/                 共享规则测试
.github/workflows/     macOS 原生验证与截图
ios/                   EAS 所需原生工程与空 Podfile
scripts/               Windows 工程生成、配置检查和模拟器启动工具
app.json               EAS 项目标识（不引入 Expo 运行时）
eas.json               模拟器构建配置
```

## Windows 与 macOS 工作流

真机内测发布配置与当前状态见 [TestFlight 发布](docs/TestFlight发布.md)。云端 `validate` 编译真机架构，`upload` 签名并上传；未确认 Apple 处理和测试权限前不称已可安装。

2026-10-31：历史版本 `0.1.0 (4.1)` 上传后已由用户手动设为过期；5.1 的公开外测未成功提审。已有 [公开邀请链接](https://testflight.apple.com/join/UgcSXDXP)，不能将链接存在等同于已有可安装外测。本轮按用户要求先修应用，未上传新版本。验收项目见 [真机内测清单](docs/真机内测清单.md)。

Windows 编辑 Swift 文件，用 `npm run prepare:ios` 更新原生工程并提交 Git。生成脚本不依赖 Xcode；真正的 Swift 编译仍在 macOS 进行。当前私有仓库的验证与截图流程见 [GitHub 云端验证](docs/GitHub云端验证.md)，原 EAS 配置仍保留在 [Expo 云端预览](docs/Expo云端预览.md)。

当前部署目标为 iOS 27.0，须使用包含 iOS 27 SDK 的 Xcode。若云端环境尚未提供所需 SDK，应停止构建并调整环境，不把缺少 SDK 误判为源码验证成功。部署目标和最低支持版本仍可在后续讨论调整。

macOS 上可在项目根目录运行：

```sh
npm run prepare:ios
xcodebuild -project ios/CampusSchedule.xcodeproj -scheme CampusSchedule -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

随后用 Xcode 打开生成工程，运行 iPhone 模拟器。真机签名与 TestFlight 上传流水线已配置，密钥通过 GitHub Actions Secrets 提供；普通 UI 验证不触发发布。

## 验证状态与后续验收

首轮手绘版本通过 [GitHub 构建 41081745951](https://github.com/ithtelab/campus-schedule-native/actions/runs/41081745951)：Xcode 27.1 编译主 APP 与扩展，12 项规则测试、六个人物资源/字体加载、深浅色实际吸顶和本地重启读回检查通过。该记录为历史基线，当前修复版本的编译、截图与边界见 [首轮真机反馈修复](docs/首轮真机反馈修复.md)。

第二批早期验证包含六项课程规则测试，后续已扩充为二十八项。真实系统组件、通知和灵动岛仍需签名后的真机验收；后台自动下课结束尚未实现可靠机制。相关业务边界见 [第二批实施记录](docs/第二批实施记录.md)。以下为此前 UI 阶段记录。

第二版已通过 EAS 云端 Xcode 27.0 编译，在 iOS 27.0 / iPhone 17 模拟器启动并导出十二张截图：五个页面的深浅色版本，以及七天课表与辅助功能大字体列表，保存于 `screenshots/`。已检查截图并修复日期截断、时间轴错位、大字体时间拆行。尚未完成触控交互、业务自动化测试和真机验证。当前 Expo 账号尚无交互式 EAS Simulator 权限，截图不代表浏览器交互预览已可用。

此前 UI 阶段曾使用无签名模拟器验证，当时尚未配置发布；正式应用标识、签名与 TestFlight 流水线现已配置。此前 EAS 构建记录为历史证据，不代表当前源码；EAS 免费 iOS 构建额度曾用尽，未购买额外订阅，后续验证使用 GitHub macOS 环境。

后续验收仍需检查：小屏 iPhone 与 iPad、VoiceOver、减少透明度、横竖屏、课程详情打开关闭、周次切换、表单添加/取消/保存、提醒设置显隐及长文本。周网格默认五天同屏，辅助功能大字体改用按天分组列表。UI 规范见 [UI设计规范.md](docs/UI设计规范.md)。

此阶段不加入仅复述静态布局的自动化测试。真实课程时间规则、数据合并与通知排程落地时再添加针对性的测试。

## 许可

本项目以 [PolyForm Noncommercial License 1.0.0](LICENSE) 发布，全文见 `LICENSE`。

- **允许**：个人学习、研究、实验、测试、业余项目；慈善机构、教育机构、公共研究机构、公共安全或卫生机构、环保组织及政府机构的非商业使用。
- **禁止**：任何商业用途，包括但不限于销售、以本项目或其衍生作品提供付费服务、将其集成进商业产品、或在企业内部用于营利性经营活动。

需要商业授权请另行联系版权持有人。


## 隐私与提交保护

仓库为公开状态，因此真实手机号、个人邮箱、签名密钥等不得进入版本历史。`.githooks/pre-commit` 会在每次提交前扫描新增内容，命中后拒绝提交并提示改用 `.tool-cache/`（已被忽略）。

首次克隆后需启用一次：

```bash
git config core.hooksPath .githooks
```

App ID、Team ID、构建编号等元数据不属于隐私，可正常记录。
