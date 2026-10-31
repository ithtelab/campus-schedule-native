# 6.1 真机安装失败：可见版本但提示 App 不可用

2026-10-31，用户实际 iPhone 截图确认：TestFlight 能显示“校园课表 0.1.0 (6.1) · 90天”和安装按钮，但点击后提示“无法安装‘校园课表’。所请求的 App 不可用或者不存在。”截图时间约北京时间 13:20。用户更换 Wi-Fi/蜂窝网络后仍为相同错误。

**当前未解决，不能称 6.1 已可实际安装。** 云端上传成功、Apple 处理 VALID、内部 IN_BETA_TESTING 和分组关联均只代表相应阶段通过，不能代替手机安装成功。本轮不停止测试、不使构建过期、不删除测试者、不修改协议、不重复上传未改包。

## 实际只读诊断

诊断命令：`node scripts/apple-connect.mjs diagnose-install 6.1`。

最新记录时间：北京时间 2026-10-31 13:24:52。报告保存在忽略目录 `.tool-cache/apple/install-diagnostic-6.1.json`，不包含 API 私钥或令牌。

- App ID `6828962951`，Team `RA59Z5Z78P`，Bundle ID `com.ithtelab.campusschedule`。
- 构建 ID `b57b164c-cbb6-45b2-befa-9ced382ba235`，版本 `0.1.0 (6.1)`。
- Apple 处理 VALID，expired=false，内部 IN_BETA_TESTING，外部 READY_FOR_BETA_SUBMISSION。
- 本人真机测试组：6.1 已关联，唯一账号持有人已关联。该测试者查询 apps 包含本 App；账号拥有 ACCOUNT_HOLDER / ADMIN、allAppsVisible=true。
- 测试者 INSTALLED 是既有测试状态，不是本次 6.1 已安装的证据。
- 最低 iOS 27.0，用户此前报告设备 iOS 27.2；未出现导出合规缺失状态。
- Beta license resource 查询存在，agreementText 为空；不能据此判定账号缺少 Apple 的分发合同，也不自行填写或接受协议。
- App Availability 查询 404；buildBundles 关系查询 403、接口不支持读取。这些查询未提供安装失败的明确原因，不把其当成签名校验失败。
- 5.1 早前外测提审曾返回通用 HTTP 422 ENTITY_UNPROCESSABLE，没有 BETA_CONTRACT_MISSING 代码；未证明与此次 6.1 安装失败同因。

## 结论与下一步

用户要求尝试更换 App 版本号：从一直沿用的 `0.1.0` 升至 `0.1.1`，下一次上传同时产生新构建号。已对比 4.1 与 6.1 使用的 workflow 和签名上传脚本，没有差异。此次升级是分发故障的排查尝试，不预先声称能解决根因，也不使现有 6.1 失效。

已核对的分配和权限没有发现缺项；更像 TestFlight 服务端分发/账号状态或其他安装可用性问题，但尚未证实根因。现有公开 API 没有给出手机这次请求失败的具体分发原因。

[苹果开发者论坛的同类报告](https://developer.apple.com/forums/thread/813703) 中，Apple DTS 工程师要求仍能复现的开发者通过 Feedback Assistant 提交报告并提供受影响 App ID。这只支持升级调查的路径，不证明我们的根因相同。

可提交的正文见 [Apple 故障报告](Apple-TestFlight-6.1-安装故障报告.md)。反馈入口：[Feedback Assistant](https://feedbackassistant.apple.com/)，或 [Apple Developer Support](https://developer.apple.com/contact/)。尚未代用户发送报告，也未取得工单编号。登录后的协议/账号提示及设备日志不在当前工具可读范围内，不能声称已核对所有账号协议。
