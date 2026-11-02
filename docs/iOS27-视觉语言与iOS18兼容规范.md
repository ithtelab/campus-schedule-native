# iOS 27 视觉语言 · iOS 18+ 兼容开发规范

一份可复用的项目规范模板。适用于：在 Windows 上写 Swift、macOS 云端编译、需要同时支持最新设计语言与较旧系统的原生 App。

文中所有 API 名称与可用版本均**未在本次编写时编译验证**。落地前必须在目标 SDK 上编译确认，详见第 9 节「待验证清单」。

---

## 1. 版本策略

| 项 | 取值 | 理由 |
| --- | --- | --- |
| 最低部署目标 | iOS 18.0 | 覆盖绝大多数在用设备；SwiftData / Observation 均已可用 |
| 编译 SDK | Xcode 27 / iOS 27 SDK | 才能使用新设计语言的 API |
| Swift 语言版本 | 6.0 | 严格并发检查，早发现跨线程问题 |
| 项目格式 | 由脚本生成或 Xcode 工程 | 二者择一，避免手工维护漂移 |

### 1.1 三条硬规则

1. **任何高于 18.0 的 API 必须用 `#available` 包裹**，并同时提供降级实现。禁止只写 `if #available` 不留 `else`。
2. **禁止用占位版本号绕过检查**（如 `@available(iOS 99, *)`）。那会把「以后补」变成永久债。
3. **每引入一个新 API，在「降级表」里补一行**，写明可用版本与降级方案。降级表是这套规范的核心资产。

### 1.2 版本分界

已知的三条分界线，都要单独处理：

```
iOS 18.0  ← 部署下限
iOS 26.0  ← 一批新 API（如定时启动实时活动）
iOS 27.0  ← 又一批新 API（如拖拽会话）
```

不要假设「新 API 一定在 26」或「一定在 27」。**以编译器报错为准**，报错会直接告诉你真实版本。

---

## 2. 架构分层

```
┌─────────────────────────────────┐
│  Features     业务界面，按功能分包      │
├─────────────────────────────────┤
│  DesignSystem 令牌 + 组件 + 材质，无业务 │
├─────────────────────────────────┤
│  Services     系统能力封装（存储/通知/同步）│
├─────────────────────────────────┤
│  Shared       纯逻辑，独立 SwiftPM 包    │
└─────────────────────────────────┘
```

### 2.1 为什么把纯逻辑放进独立 SwiftPM 包

这是整套工作流里收益最大的一条：

- **测试不需要模拟器**。`swift test` 直接在 macOS runner 上跑，几秒钟出结果；用 Xcode 测试目标则要启动模拟器，慢一个数量级。
- **编译错误更早暴露**。包可以脱离 App 单独编译。
- **强制隔离**。放进包里的代码不能用 UIKit / SwiftUI，天然逼你把规则与界面分开。

代价是包内不能引用 App 层类型。需要跨层时用 **协议或轻量投影类型**，不要为了省事把视图模型塞进包里。

### 2.2 分层依赖方向

只允许向下依赖：

```
Features → DesignSystem → Shared
Features → Services → Shared
```

不允许 `DesignSystem` 依赖 `Features`，也不允许 `Shared` 反向依赖任何一层。

---

## 3. 目录结构

```
ProjectName/
├─ App/
│  ├─ AppEntry.swift            场景入口、环境注入
│  └─ RootView.swift            顶层导航（iPhone 标签栏 / iPad 分栏）
├─ DesignSystem/
│  ├─ Tokens/
│  │  ├─ Palette.swift          语义色
│  │  ├─ Typography.swift       字号与字重
│  │  ├─ Spacing.swift          间距与圆角
│  │  └─ Motion.swift           动效时长与曲线
│  ├─ Materials/
│  │  ├─ GlassSurface.swift     玻璃/材质降级
│  │  └─ SurfaceLevels.swift    层级背景
│  └─ Components/
│     ├─ PrimaryButton.swift
│     ├─ Card.swift
│     ├─ EmptyState.swift
│     └─ SettingRow.swift
├─ Features/
│  └─ <Feature>/
│     ├─ <Feature>View.swift
│     ├─ <Feature>Model.swift
│     └─ <Feature>Detail.swift
├─ Services/
│  ├─ Persistence/              本地存储
│  ├─ Notifications/            本地通知
│  ├─ Sync/                     可选云同步
│  └─ System/                   组件、实时活动等
├─ Shared/                      独立 SwiftPM target，纯逻辑
├─ Tests/                       对应 Shared 的单元测试
├─ Resources/
│  ├─ Assets.xcassets
│  └─ PrivacyInfo.xcprivacy
└─ docs/
```

**一个功能一个目录**，不要把十个 View 平铺在一个文件夹里。

---

## 4. 视觉与材质规范

### 4.1 设计原则

- **层级靠材质，不靠装饰**。三到四层足以表达全部关系，超过就很难读。
- **颜色只作识别辅助**。列表项、卡片用低饱和着色 + 一条窄色条，正文永远用主文字色。整块高饱和填充会破坏克制感，且在深色模式下对比度难保证。
- **不用自定义导航/标签栏**。系统组件自带新设计语言的全部行为（滚动边缘、折叠、无障碍）。
- **动效服务于状态变化**，不做入场动画堆砌。

### 4.2 三层材质

| 层级 | 用途 | 实现 |
| --- | --- | --- |
| 底层 | 页面背景 | 系统背景色（不要写死白/黑） |
| 中层 | 卡片、分组容器 | 材质或玻璃 |
| 浮层 | 悬浮操作、底部条 | 玻璃 + 阴影 |

### 4.3 玻璃的统一入口

不要在视图里直接调新 API。所有玻璃效果走**一个修饰器**，集中处理版本与无障碍降级：

```swift
struct GlassSurface: ViewModifier {
    var shape: RoundedRectangle
    var level: Level = .regular

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    enum Level { case regular, prominent }

    func body(content: Content) -> some View {
        if reduceTransparency {
            // 降低透明度开启时必须退回不透明，否则内容读不清。
            content.background(DesignSystem.Palette.surface, in: shape)
        } else if #available(iOS 27, *) {
            content.glassEffect(level == .prominent ? .regular.tint(.accentColor) : .regular,
                                in: shape)
        } else {
            // 18–26：用系统材质近似，补极细描边维持边界感。
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay { shape.strokeBorder(DesignSystem.Palette.hairline, lineWidth: 0.5) }
        }
    }
}
```

`glassEffect` 的确切签名以编译器为准；若签名不同，只改这一个文件。

### 4.4 降级对照表

引入新能力时在此登记。**这张表比任何代码注释都重要**。

| 能力 | iOS 27 | iOS 26 | iOS 18–25 | 降级方案 |
| --- | --- | --- | --- | --- |
| 玻璃卡片/浮层 | `glassEffect` | 同左 | `ultraThinMaterial` | 材质 + 0.5pt 描边 |
| 玻璃按钮 | 玻璃按钮样式 | 同左 | `bordered` / `borderedProminent` | 描边按钮 |
| 拖拽会话进度 | `DragSession` + `onDragSessionUpdated` | **不可用** | **不可用** | 用落点的 `isTargeted` 回调驱动 |
| 定时启动实时活动 | `Activity.request(…, start:)` | 同左 | **不可用** | 立即启动 + 本地通知承担提示 |
| 滚动边缘渐隐 | 系统自动 | 同左 | 手动渐变遮罩 | 顶部/底部叠一层渐变 |
| 标签栏玻璃 | 系统自动 | 同左 | 系统默认 | 无需处理 |

> 表中 `DragSession` 与定时实时活动两行的版本号是**实际编译报错确认**过的；其余仍需验证。

### 4.5 无障碍必须覆盖的四项

玻璃与动效最容易在这四项上翻车：

1. **降低透明度**（Reduce Transparency）→ 玻璃退回不透明
2. **增强对比度**（Increase Contrast）→ 描边与分隔线加粗
3. **减弱动态效果**（Reduce Motion）→ 去掉位移与缩放，只留淡入
4. **动态字体到辅助功能字号** → 网格类布局改为列表

---

## 5. 数据管理

### 5.1 分层

```
View  →  Model（@Observable）  →  Repository  →  SwiftData
                                        ↘  可选云同步
```

View 不直接碰 SwiftData。中间隔一层仓库，才能在测试里注入假实现，也方便日后换存储。

### 5.2 模型演进规则

- **新增字段必须是可选的**。非可选字段会让旧数据解码直接失败。
- **不要为了「干净」重命名已有字段**。改名等同于丢数据，除非写显式迁移。
- **结构大改走版本化迁移**（`VersionedSchema` + `MigrationPlan`），不要靠运行时容错。

### 5.3 云同步

两条路线，按需选：

| 路线 | 前提 | 适用 |
| --- | --- | --- |
| SwiftData + CloudKit | 必须在开发者网站为 App ID 启用 CloudKit 服务 | 数据量大、需要自动合并 |
| iCloud 键值存储 | 只需 iCloud 能力（可在 API 侧启用） | 数据小、结构简单 |

**键值存储的单值有体积上限**（约 1 MB 量级），写入前要预检并给出明确错误，不要等系统拒绝。

同步必须处理冲突。**判断依据不是时间戳**，而是「上次成功同步的内容」：

```
本地未改动 + 云端改了  → 采用云端
本地改了 + 云端没改    → 上传
两边都改              → 弹窗让用户选
```

用时间戳判断会静默丢数据，因为无法区分「本地没改」和「本地改了但没推」。

### 5.4 开关必须诚实

任何开关的实际能力与显示状态必须一致。典型反例：用户打开「提醒」→ 系统弹权限 → 用户拒绝 → 开关仍显示「开」，但永远不会响。

规则：**权限被拒时把开关退回关闭，并给出直达系统设置的入口**（系统不会二次弹窗）。

---

## 6. 云端构建

### 6.1 成本结构

- 私有仓库的 macOS runner **按分钟计费，且倍率高于 Linux**。
- 公开仓库的托管 macOS runner 免费。
- 因此：**不要用 `push` 触发重任务**。改为 `workflow_dispatch` 手动触发。

一次误配的路径过滤器，能在一天内烧光月度额度，然后连带让签名上传也跑不起来。

### 6.2 签名链路

```
App Store Connect API 密钥（JWT 鉴权）
        ↓
申请/复用 Distribution 证书
        ↓
按 bundle ID 申请 App Store 描述文件
        ↓
解码描述文件，校验 entitlements
        ↓
xcodebuild archive → exportArchive → 上传
```

**关键校验点**：拿到描述文件后要**解码**并断言——应用标识符正确、共享组确实在 entitlements 里、`get-task-allow` 为 false、没有 `ProvisionedDevices`。

不校验的后果：打包成功、上传成功，但签名能力缺失，问题要到运行时才暴露。

### 6.3 构建号

用 `run_number.run_attempt` 组合，保证唯一且可追溯。主应用与扩展必须一致。

### 6.4 三个真实踩过的坑

1. **行尾符**：脚本以 CRLF 保存后，Linux 上 `set -euo pipefail` 会被解析成非法参数，**第一行就崩**。`.gitattributes` 里显式写 `*.sh text eol=lf`。
2. **绕过 Git 的属性转换**：用 GitHub API 直接写 blob 时不会应用 `eol=lf`，会把 CRLF 内容推上去。用 API 推送后要复核文件哈希。
3. **Bundle ID 前缀匹配**：`filter[identifier]` 是前缀匹配，查 `com.example.app` 会同时返回 `com.example.app.widgets`。必须按完整字符串精确筛选。

---

## 7. 测试与发布

### 7.1 测试分层

| 层 | 工具 | 运行环境 | 速度 |
| --- | --- | --- | --- |
| 纯逻辑 | Swift Testing | macOS 直接跑 | 秒级 |
| 界面 | 模拟器 + 截图 | macOS 模拟器 | 分钟级 |
| 真机 | TestFlight / Ad Hoc | 物理设备 | 小时级 |

**把大部分判断逻辑推进第一层**。第二层只验证「能编译 + 渲染不崩」，不要在截图流程里做业务断言。

### 7.2 测试要覆盖「降级路径」

新版 API 的分支必须在低版本 SDK 下也能编译。最省事的办法：**部署目标就设成最低版本**，让编译器强制检查所有可用性。

### 7.3 发布路径

| 路径 | 前置 | 时效 |
| --- | --- | --- |
| TestFlight 内测 | 构建处理完成 + 测试员是团队用户 | 通常即时 |
| TestFlight 外测 | 通过 Beta App Review | 需审核 |
| Ad Hoc | 设备 UDID 已注册 | 可绕过 TestFlight |
| App Store | 完整元数据 + 截图 + 隐私问卷 + 定价 | 需审核 |

**内测不经过审核**。如果内测拿不到构建，不要往审核方向排查。

---

## 8. 潜在技术风险

| 风险 | 影响 | 缓解 |
| --- | --- | --- |
| 新 API 版本判断错误 | 低版本编译失败或运行时崩溃 | 部署目标即最低版本；以编译器报错为准 |
| 玻璃效果在降低透明度下不可读 | 无障碍不达标 | 统一修饰器强制降级 |
| 私有仓库 macOS 额度耗尽 | 构建与上传同时中断 | 手动触发；关闭 push 自动跑 |
| TestFlight 邀请不送达 | 无法分发 | 见 8.1 |
| 抓取第三方系统 | 审核与法律风险 | 优先官方接口或用户主动粘贴 |
| SwiftData 模型演进 | 旧数据无法读取 | 新字段可选；大改走版本化迁移 |
| 云同步冲突判断错误 | 静默丢数据 | 以「上次同步内容」判断，冲突交由用户 |
| 上传凭证过期 | 流水线突然失败 | 记录到期日；到期前轮换 |

### 8.1 TestFlight 邀请不送达的排查顺序

按此顺序排查，不要跳步：

1. 构建状态是否 `VALID` 且未过期
2. 构建是否已加入**内部**测试组
3. 测试员是否为 App Store Connect 用户，且状态为「已邀请」
4. 测试员的 App 关系是否包含目标 App
5. 设备上 TestFlight 登录的 **App Store 账户**（不是 iCloud 账户）是否与邀请邮箱一致
6. 设备系统版本是否达到构建的最低要求
7. 是否同时被加入了外部测试组（外测必须过审才发邀请）

**全部正常但仍收不到** → 属于账号或服务端状态，转人工支持。此时准备一份含构建 ID、组 ID、请求 ID 的报告，比反复重试有效得多。

---

## 9. 待验证清单

编写本文时**未执行编译**。以下项目必须在目标 SDK 上确认后才能当作事实使用：

- [ ] `glassEffect(_:in:)` 的确切签名与可用版本
- [ ] 玻璃按钮样式的名称与版本
- [ ] 滚动边缘、标签栏折叠相关 API 的名称
- [ ] `DragSession` 与 `onDragSessionUpdated` 的可用版本
- [ ] 定时启动实时活动的参数与可用版本
- [ ] `AccessibilityReduceTransparency` 环境键在目标 SDK 的名称

验证方式：写一个最小视图，逐个 API 引用，看编译器报出的可用版本号。**报错信息比文档更准**。

---

## 10. 落地检查表

新项目开工前逐条确认：

- [ ] 部署目标设为目标最低版本，不是最新版
- [ ] `Shared` 独立成 SwiftPM 包，`swift test` 可单独跑
- [ ] DesignSystem 里只有一个玻璃入口修饰器
- [ ] 降级表已建立，且随代码同步更新
- [ ] `.gitattributes` 锁定脚本为 LF
- [ ] CI 只保留手动触发
- [ ] 描述文件生成后解码校验 entitlements
- [ ] 所有权限开关都能在拒绝后退回
- [ ] 深浅色、降低透明度、增强对比度、减弱动效、辅助功能字号五项都过一遍
