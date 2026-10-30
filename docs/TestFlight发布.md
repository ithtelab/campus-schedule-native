# TestFlight 真机测试

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

发布配置和标识已准备。[真机架构验证 41094352914](https://github.com/ithtelab/campus-schedule-native/actions/runs/41094352914) 已实际通过共享规则测试与 iOS device 编译；这是未签名构建，尚未上传 TestFlight。

用户创建共享组并保存关联后，重新申请的主应用与组件描述文件已在本地解码，均确认包含 `group.com.ithtelab.campusschedule`。

首次上传任务 `41095478801` 在 macOS 导入 PKCS#12 阶段失败，尚未上传；已将同一证书包的 PBE/MAC 转为兼容编码并更新 Secrets，不新建或撤销证书，待重试验证。

真机启动从个人空课表开始，不自动导入演示课程。可手工添加课程验证人物状态、通知、桌面/锁屏组件、数据保存和深浅色。学校导入尚未实现，灵动岛完整后台自动结束与衔接仍是已记录的未完成项。
