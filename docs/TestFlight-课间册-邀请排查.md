# 课间册 15.1：内测邀请与公开下载排查（2026-10-31）

用户本次明确反馈：收不到内部测试邀请链接，公开测试也无法下载。不能直接沿用旧 App 6.1 的“点击安装后 App 不存在”作为本次症状。

## 当前读回结果

北京时间约 19:08，重新从 Apple 查询新 App `6829142615`（课间册、`com.ithtelab.campustimetable`）：

- 最新构建 15.1，ID `f53c1084-6f2a-4ce0-a1cd-bfb0eb161567`，VALID、expired=false，最低 iOS 18.0；这与旧上下文中的 7.1/iOS 27.0 是不同记录，不混用。
- 内部状态 IN_BETA_TESTING，外部 READY_FOR_BETA_SUBMISSION，无外测审核记录。
- “本人真机测试”组已关联 15.1，账号持有人已在组内，账号有 ACCOUNT_HOLDER/ADMIN 与全部 App 可见权限；测试者 apps 关系包含本 App。
- 收件地址为账号持有人的 iCloud 邮箱，聊天和报告中只显示 `ch***@icloud.com`；测试者状态 INVITED，尚无接受或安装记录。该状态不能证明邮件实际已送到用户收件箱。
- 新 App 的外测组列表为空。旧 `UgcSXDXP` 链接归属旧 App `6828962951`，已于退役时停用，不能用于新 App。
- 当前 Beta 描述、反馈邮箱、隐私链接和审核联系人字段均已存在；betaLicenseAgreement 的 agreementText 也已有值，不继续套用旧 App 的空文本推断。

## 已执行动作

使用 [Apple 官方邀请接口](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-betatesterinvitations)，仅对有 15.1 内测资格的唯一账号持有人重发一次邀请。无新增测试者、删除资格、重建 App、构建上传或外测提审。

Apple 于北京时间 **2026-10-31 19:11:34** 成功受理重发请求，邀请资源 ID `0d9e7199-fd38-4425-bcf8-2874cb098e0b`。用户随后明确确认该邮箱是本人邮箱，重发后仍未收到。邮件实际投递未成功得到确认，接受与安装也未确认；不把接口受理写成邮件已送达。

脱敏凭证位于 `.tool-cache/apple/invitation-resend-6829142615.json`；只读资格报告位于 `.tool-cache/apple/install-diagnostic-15.1.json`。未输出私钥、登录凭据或邀请兑换码。

新增 `node scripts/apple-connect.mjs resend-owner-invitation 15.1`，先验证构建有效、已在内测组分配，并且接收者是唯一账号持有人，再调用邀请接口。语法检查与本次实际调用通过。

## 用户待核对事项与公开测试边界

`ch***@icloud.com` 已由用户确认是本人邮箱，不再反复要求确认地址。用户已反馈仍未收到邀请，当前只读查询仍为 INVITED。已进一步询问该邮箱能否收到其他普通邮件，用于区分邮箱收信和 TestFlight 邀请投递；此项尚未得到回答，不能自行假定其他邮件正常。

已直接读取 Apple DocC 官方 JSON 结构，确认现有请求使用的 type / relationships 格式正确。[BetaTesterInvitation](https://developer.apple.com/documentation/appstoreconnectapi/betatesterinvitation) 响应只有 id、type 和导航 links，没有用户可兑换的邀请 URL 或兑换码；导航 self-link 不能当作用户邀请链接使用。当前公开接口也未提供邮箱实际送达日志。不重复发信、不删除测试者、不编造替代邀请链接。

公开测试需要新 App 的外测组和通过 Beta App Review 的构建。[Apple TestFlight 说明](https://developer.apple.com/testflight/) 当前条件均不满足，本次未擅自重新创建外测组、启用链接或提交审核。

重发后用户仍未收到，已保存事实并准备 [邮件邀请故障报告](Apple-课间册-内测邀请未收到.md)。尚未发送给 Apple。现阶段没有证据认定用户设备、邮箱过滤或 Apple 后台中的哪一项是根因；若普通邮件也收不到，应先处理邮箱收信，若其他邮件正常，再将具体邀请编号交 Apple 核查投递链路。
