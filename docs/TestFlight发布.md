# TestFlight 真机测试

2026-10-31 状态变更：4.1 已被提前标记为 EXPIRED，当前不可安装。Apple 返回失效时间为北京时间 03:13:44，包处理仍为 VALID，原 Beta 审核记录已不可查询。用户确认未操作停止测试；现有发布脚本未执行 expired=true，触发来源未能从 Apple API 确定，不归因于用户或审核拒绝。尝试 expired=false 被 Apple 409 拒绝（不允许恢复已失效构建），将重新上传替代构建。下文首次发布成功状态为历史记录。

替代版本 `0.1.0 (5.1)` 已由 [上传任务 41164506639](https://github.com/ithtelab/campus-schedule-native/actions/runs/41164506639) 成功签名上传，源码 `8a86b48`。Apple 最终确认 VALID、expired=false、内部状态 IN_BETA_TESTING，正常到期日为北京时间 2027-01-29 11:31:13。已重新关联本人内部测试组，可通过现有内测资格更新。构建 ID 为 `679a3052-bd18-4b15-9aa6-cb9745ef4ec1`。

同一公开外测组已关联 5.1，原链接仍启用、限额 100 人。但 Beta 提审连续返回 Apple 422 `ENTITY_UNPROCESSABLE: Please try again later.`，间隔后重试仍未受理；5.1 外部状态为 READY_FOR_BETA_SUBMISSION，审核记录为空。不得称已重新排队或外部用户可安装。此问题不影响已恢复的本人内部测试。

此次补充 `expired` / `expirationDate` 状态输出和 `audit-build` 只读诊断；测试分配、外测提审及处理检查现同时排除 expired=true，防止将处理结果 VALID 误认为可测试。

用户于 2026-10-31 明确要求上传 TestFlight 供本人真机测试。上传测试包不等于发布 App Store 正式版。

## 本项目标识

- 主应用：`com.ithtelab.campusschedule`
- 组件扩展：`com.ithtelab.campusschedule.widgets`
- 共享数据组：`group.com.ithtelab.campusschedule`
- 开发团队：`RA59Z5Z78P`
- App Store Connect Apple ID：`6828962951`
- [App Store Connect 测试页](https://appstoreconnect.apple.com/apps/6828962951/testflight/ios)

应用正式名称仍待定；手机显示“课表”，当前使用可替换的黑白日历测试图标。应用标识首次上传后应保持稳定，避免破坏安装更新与本地数据连续性。

`app.json` 保存应用及共享组标识。生成器同步两个 target 的构建设置；Info.plist 和 entitlements 引用同一构建变量，运行时从实际 bundle 获取共享组，截图脚本读取相同配置，避免多处手工修改。

## 云端流程

私有仓库 `ithtelab/campus-schedule-native` 的 `.github/workflows/testflight.yml` 仅手动触发。

1. `validate`：生成工程、静态检查、24 项共享规则测试、iOS 真机架构的未签名编译。通过也不能直接安装。
2. `upload`：同样先执行测试；使用分发证书，为主应用和组件申请 App Store 描述文件；检查团队、应用 ID、共享组、非开发分发类型；导入临时钥匙串，手动签名 archive，验证代码签名，通过 Xcode 上传 App Store Connect。
3. 上传成功后保存 `testflight-upload.json`，记录源码、版本与 build。状态是 `UPLOADED_AWAITING_APPLE_PROCESSING`，不是已经可安装。
4. 等待 Apple 处理完成，在内部测试组中添加用户自己的账号并选择该 build，再检查 TestFlight 安装权限。

每次运行的 build 取 `GitHub run number.run attempt`，主应用与扩展一致。并发发布串行，不中断正在上传的任务。这里只上传测试构建，不提交正式版审核或创建外部公开测试链接。

## 凭据

团队 API Key 已经 Apple API 实际认证；本地生成一份本项目的 Apple Distribution 证书并复用，不自动撤销其他证书。证书、私钥和密码均在忽略目录 `.tool-cache/apple/`，不提交 Git。

GitHub 发布需要以下 Actions Secrets：

| 名称 | 内容 |
| --- | --- |
| APPLE_API_KEY_ID / APPLE_API_ISSUER_ID | API 密钥标识 |
| APPLE_API_PRIVATE_KEY | 团队 API 私钥 |
| APPLE_TEAM_ID | 开发团队 |
| APPLE_CERTIFICATE_ID | 已创建的分发证书 ID |
| APPLE_DISTRIBUTION_P12 | 包含签名私钥的证书包，Base64 只用于传输 |
| APPLE_DISTRIBUTION_PASSWORD | 证书包保护密码 |

`scripts/apple-connect.mjs secrets` 通过标准输入提交到该仓库的 Secrets，不在命令行参数、聊天或构建产物中打印秘密。首次存储曾被自动审批拒绝；用户随后明确同意将这批凭据存入该私有仓库并继续上传，七项 Secrets 已实际存储。此授权用于本项目签名上传。

云端在 runner 临时目录使用凭据，结束时删除临时钥匙串及私钥文件；产物只保留普通构建日志和上传状态，不打包凭据目录。

## Apple 网页首次设置

API 已注册两个 App ID 并开启 App Groups。用户在 Apple Developer 网站创建共享组后，还必须分别进入两个 App ID 的 App Groups → Configure，选中共享组，Continue/Save。仅勾选能力而未关联组，描述文件会包含空的 application-groups 数组，发布脚本会拒绝打包。

App Store Connect 的应用记录已实际查询到。新 App 记录由用户在网页创建，遵循 [Apple 的创建流程](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)。

团队 API 密钥和权限说明参照 [Apple 官方 API 指南](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/)。隐私清单按实际 UserDefaults 本机/同一 App Group 用途声明 `CA92.1`、`1C8F.1`，参见 [Apple 的 Required Reason API 说明](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)。

## 当前状态及真机范围

发布配置和标识已准备。[真机架构验证 41094352914](https://github.com/ithtelab/campus-schedule-native/actions/runs/41094352914) 已实际通过共享规则测试与 iOS device 编译。

用户创建共享组并保存关联后，重新申请的主应用与组件描述文件已在本地解码，均确认包含 `group.com.ithtelab.campusschedule`。

已完成的首次签名上传：

| 项目 | 实际结果 |
| --- | --- |
| 版本 / build | `0.1.0 (4.1)` |
| 源码 | `8e618aae41729a2f507f8f5bfb66dd23394442d3` |
| [上传任务 41096792817](https://github.com/ithtelab/campus-schedule-native/actions/runs/41096792817) | SUCCESS |
| Swift Testing | 24 项 / 4 个 suite 通过 |
| App Store 描述文件 | 主应用与组件的团队、标识、共享组均通过 |
| 签名归档 | `ARCHIVE SUCCEEDED`，codesign 验证通过 |
| 实际包检查 | 两个 bundle 的显示名称、版本、隐私清单、签名共享组通过 |
| Xcode 上传 | `Upload succeeded`、`EXPORT SUCCEEDED` |
| [同源码 UI 回归 41096767805](https://github.com/ithtelab/campus-schedule-native/actions/runs/41096767805) | SUCCESS，模拟器截图、人物联动、吸顶及本地重启验证 |
| Apple 处理结果 | `4.1` 为 `VALID` |
| 内部测试状态 | `IN_BETA_TESTING` |
| 内部测试资格 | 已将唯一账户持有人加入“本人真机测试”，邀请为 `INVITED` |
| 分享范围 | 内部组，公开链接关闭；未邀请其他成员 |

上传凭证为本机 `.tool-cache/preview/testflight-first-upload/build/testflight-upload.json`，内测配置凭证为 `.tool-cache/apple/testflight-ready.json`。Apple 已允许内部测试，但尚未收到用户已安装的反馈，不能说真机验收已通过。

`scripts/apple-connect.mjs watch-internal 4.1` 持续查询 Apple 处理结果，只有明确 `VALID` 才将指定 build 分配到内部组，并只添加团队唯一 `ACCOUNT_HOLDER`。如果持有人不能唯一确定则停止，不批量添加团队成员。已为该 build 写入简体中文测试说明，明确首次空课表、学校导入未完成及灵动岛后台行为限制。

手机端安装：安装 Apple TestFlight，使用开发者账号对应的 iCloud 邮箱查看 Apple 内测邀请，点 View in TestFlight 后安装 `0.1.0 (4.1)`。邀请生成不等于已确认邮件送达或用户接受；若未收到邮件，先检查垃圾邮件，再核对该测试者状态。

发布过程中修正了两个实际问题：首次任务 `41095478801` 的 PKCS#12 导入格式；随后任务 `41096034614` 在签名归档成功后被 Apple 拒绝组件缺少 `CFBundleDisplayName`。采用同一证书的兼容编码并补充组件显示名称后，任务 `41096792817` 通过，未撤销其他证书。

真机启动从个人空课表开始，不自动导入演示课程。可手工添加课程验证人物状态、通知、桌面/锁屏组件、数据保存和深浅色。学校导入尚未实现，灵动岛完整后台自动结束与衔接仍是已记录的未完成项。

## 外部公开测试（2026-10-31）

用户随后明确要求增加外部测试，并选择公开邀请链接。已复用 `0.1.0 (4.1)`，其 audience 为 `APP_STORE_ELIGIBLE`，不需要重新编译。

- 已创建“公开外部测试”组并关联 build 4.1。
- 用户提供审核联系电话并同意将账号邮箱作为公开测试反馈邮箱。电话只提交给 Apple 审核；联系方式不提交 Git，发布辅助配置位于忽略目录。
- 已保存简体中文 Beta 描述、无须登录/无需演示账号的说明、准确的现有功能及未完成项说明。
- 已提交 Beta App Review，submission ID `33e0232a-63d1-4812-9be6-6da119e9994e`；Apple 返回 `WAITING_FOR_REVIEW`，build 外部状态为 `WAITING_FOR_BETA_REVIEW`。
- 公开链接已由 Apple 生成并启用：[加入外部测试](https://testflight.apple.com/join/UgcSXDXP)，限额 100 人。

当前是等待审核，不能把“链接已生成”写成“外部测试者已可安装”。苹果审核通过后才可供外部测试安装；不承诺审核通过或具体完成时间。现有本人内部测试继续可用。

外测操作由 `prepare-external`、`configure-external`、`submit-external`、`external-link` 和 `external-status` 辅助命令完成，均已实际调用并核对 Apple 返回值。本次只修改发布辅助脚本和记录；验证为 Node 语法检查及真实 Apple API 操作，不把这些操作当作新的 iOS 编译验收。
