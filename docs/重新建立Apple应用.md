# 重新建立 Apple 应用（2026-10-31）

用户明确选择删除旧 Apple 应用记录后重建，并表示后续自行上传。此处清理范围是本项目的 Apple 分发记录与发布标识；现有 Swift/SwiftUI 功能代码保留。不再由助手上传或提审。

用户已确定产品名称为“课表”。手机显示名称、项目应用配置和新 App Store Connect 记录的名称统一使用“课表”，内部工程名 CampusSchedule 不影响产品名称。

## 已实际完成

- 旧 App `6828962951`、主标识 `com.ithtelab.campusschedule`：将剩余有效的 6.1、7.1 设为过期。4.1、5.1 此前已过期。
- 用户随后在苹果网页直接移除旧 App，截图显示 App 列表“无 App”，旧条目移除已由用户完成；这不代表 Apple 抹掉已上传的历史或允许复用旧标识。
- 删除旧 App 的两个测试组“本人测试”“公开外部测试”，原公开邀请链接停用。
- 删除精确匹配旧主应用和组件标识的 18 份描述文件，读回确认旧 App 无测试组、这两个标识无描述文件、所有旧构建已过期。记录在忽略目录 `.tool-cache/apple/retirement-result-6828962951.json`。
- 已注册新的主应用和组件 App ID，并启用 App Groups 能力。工程改用下表新标识，版本重置为 0.1.0；清除旧 Expo/EAS projectId 关联。
- 账号级 Apple Distribution 证书、API 密钥及团队用户保留，便于用户自行签名上传；未撤销其他应用的访问权限。

## 新工程标识

| 项目 | 新值 | 实际状态 |
| --- | --- | --- |
| 主应用 | `com.ithtelab.campustimetable` | Apple App ID 已注册 |
| 组件 | `com.ithtelab.campustimetable.widgets` | Apple App ID 已注册 |
| App Group | `group.com.ithtelab.campustimetable` | 工程已配置，待网页创建并关联 |
| 版本 | `0.1.0` | 主应用与组件一致 |
| 建议 SKU | `campustimetable-ios-20261031` | 待新建 App 时填写 |
| 新 App Store Connect 记录 | 待创建 | 尚无新 App ID 数字编号 |

新的 bundle ID 是独立 App，手机旧 App 的个人数据不会自动迁入。现阶段仍为隔离演示数据模式。

## 苹果网页操作：旧条目已移除，新共享组与新 App 待创建

当前工具可处理公开 API 支持的分发记录，无法操作用户已登录的 Apple 网页来移除或新建 App 条目。

1. **已完成**：用户在网页移除旧 App，截图显示列表为空。苹果会保留已上传构建的历史，原 bundle ID 与 SKU 不能用于新建记录，不能承诺从服务器抹掉全部历史。[官方规则](https://developer.apple.com/help/app-store-connect/create-an-app-record/remove-an-app/)
2. 打开 [开发者标识管理](https://developer.apple.com/account/resources/identifiers/list)，切换“App Groups”，创建 `group.com.ithtelab.campustimetable`，描述可填 CampusTimetable。切回 App IDs，分别打开新主应用与 widgets，在 App Groups 的 Configure 中勾选这个新组，Continue/Save。仅开启能力开关不等于关联完成。
3. 打开 [App Store Connect Apps](https://appstoreconnect.apple.com/apps)，点“＋ → 新建 App”：iOS、名称“课表”、主要语言简体中文、Bundle ID 选 `com.ithtelab.campustimetable`、SKU 填 `campustimetable-ios-20261031`。不要选旧标识或复用旧 SKU。如果苹果提示名称不可用，记录具体提示再决定，不自动改成其他名称。

## 自行上传

保留了现有的 [手动发布工作流](https://github.com/ithtelab/campus-schedule-native/actions/workflows/testflight.yml)，默认操作仍是 validate，不会因为推送代码而自动上传。网页设置完成后，用户可自行点 Run workflow，选择 upload，复用仓库中此前授权保存的签名凭据。新描述文件会按新标识申请并校验 App Group。

也可用远程 Mac 上的 Xcode 打开 `ios/CampusSchedule.xcodeproj` 自行归档上传。原生工程默认构建号为 1；GitHub 工作流会使用它自己的 run number.run attempt，二者都是新 App 的独立构建记录，主应用与组件须保持一致。

此次只重建配置和注册新 App IDs，没有上传新构建、创建新测试组或提交新审核。删除重建是排查尝试，不保证账号或 Apple 服务层面的分发故障会消失。
