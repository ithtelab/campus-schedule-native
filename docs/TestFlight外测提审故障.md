# 5.1 外测提审未受理

2026-10-31 最新状态：0.1.0 (5.1) 在 TestFlight 中一直显示“准备提交”，不是“等待审核”。实际请求未受理，不能通过等待审核来解释这个状态。

## 已验证事实

- App：校园课表，Apple ID `6828962951`。
- Team：`RA59Z5Z78P`。
- Bundle ID：`com.ithtelab.campusschedule`。
- Build ID：`679a3052-bd18-4b15-9aa6-cb9745ef4ec1`。
- 包处理 VALID，expired=false，正常剩余测试期；本人内部状态 IN_BETA_TESTING。
- 外部状态 READY_FOR_BETA_SUBMISSION，审核资源查询无记录。
- 外测组已关联 5.1，公开链接启用，限额 100；缺少审核通过，不能供外部安装。
- 主语言 zh-Hans，Beta 描述、反馈邮箱、联系人姓名/电话/邮箱均非空，无需演示登录账号。
- 曾发现 5.1 中文测试说明条目存在但内容为空，已修正漏检并补齐；读回 81 字后提审仍失败，不能把该问题当作全部根因。
- 曾只撤销未提审外测组关联，试图重走网页添加向导；现已恢复关联。没有使 5.1 失效，也没有停用内部测试。

## Apple 最后一次完整响应

时间：2026-10-31 11:49:00 北京时间（03:49:00 UTC）。

`POST https://api.appstoreconnect.apple.com/v1/betaAppReviewSubmissions`

```json
{
  "errors": [{
    "id": "6a2846d9-7bb0-49cd-8b53-c8a739bbe000",
    "status": "422",
    "code": "ENTITY_UNPROCESSABLE",
    "title": "There was an error processing your request.",
    "detail": "Please try again later."
  }]
}
```

响应无 source/meta/associatedErrors，未给具体拒绝原因。原始错误保存在忽略目录 `.tool-cache/apple/beta-review-error.json`，不包含请求 Authorization 或私钥。

## 交给 Apple Developer Support 的说明

App ID 6828962951, Team ID RA59Z5Z78P. TestFlight external beta submission for version 0.1.0 build 5.1 consistently fails at POST /v1/betaAppReviewSubmissions with HTTP 422 ENTITY_UNPROCESSABLE, “Please try again later.” Error ID: 6a2846d9-7bb0-49cd-8b53-c8a739bbe000, observed 2026-10-31 03:49:00 UTC.

The build is VALID, not expired, and available for internal testing. External state remains READY_FOR_BETA_SUBMISSION with no review submission resource. The external group is associated. Beta description, feedback email, contact information, and non-empty zh-Hans What to Test notes are saved. No demo account is required. Repeated requests do not enter the review queue.

Please investigate why this submission is rejected, including any account/app-level TestFlight eligibility or agreement provisioning issue, and provide the actionable validation error. The public API has not returned a BETA_CONTRACT_MISSING code, so that cause is unconfirmed.

官方支持入口：https://developer.apple.com/contact/ 。尚未代用户向 Apple 发送工单。

苹果开发者论坛存在相似外测提审错误报告，但不能据此认定本账号的根因相同：https://developer.apple.com/forums/thread/814565 。
