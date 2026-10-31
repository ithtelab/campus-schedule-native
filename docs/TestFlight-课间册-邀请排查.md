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

Apple 于北京时间 **2026-10-31 19:11:34** 成功受理重发请求，邀请资源 ID `0d9e7199-fd38-4425-bcf8-2874cb098e0b`。收件、点击接受和安装均仍待用户确认；不把接口受理写成邮件已送达。

脱敏凭证位于 `.tool-cache/apple/invitation-resend-6829142615.json`；只读资格报告位于 `.tool-cache/apple/install-diagnostic-15.1.json`。未输出私钥、登录凭据或邀请兑换码。

新增 `node scripts/apple-connect.mjs resend-owner-invitation 15.1`，先验证构建有效、已在内测组分配，并且接收者是唯一账号持有人，再调用邀请接口。语法检查与本次实际调用通过。

## 用户待核对事项与公开测试边界

请用户核对 `ch***@icloud.com` 是否为实际收信邮箱，检查收件箱、垃圾邮件或 [iCloud 网页邮箱](https://www.icloud.com/mail/) 中的 TestFlight 邮件；如邮箱不对，再根据用户明确提供的信息处理，不猜测新地址。

公开测试需要新 App 的外测组和通过 Beta App Review 的构建。[Apple TestFlight 说明](https://developer.apple.com/testflight/) 当前条件均不满足，本次未擅自重新创建外测组、启用链接或提交审核。

若重发后用户仍未收到邀请，应记录实际确认结果并升级调查邮件/账号分发链路；现阶段没有证据认定用户设备、邮箱过滤或 Apple 后台中的哪一项是根因。
