# TestFlight internal invitation resend accepted, but the account holder receives no email — 课间册

Please investigate the TestFlight invitation delivery associated with the invitation resource below. The recipient has confirmed the address is correct, other ordinary emails arrive normally in this iCloud mailbox, and only the TestFlight invitation is missing after a resend. The specific cause is not established.

## App, build and recipient

- App: 课间册
- App Store Connect App ID: 6829142615
- Bundle ID: com.ithtelab.campustimetable
- Team ID: RA59Z5Z78P
- Assigned internal build: 15.1
- Build ID: f53c1084-6f2a-4ce0-a1cd-bfb0eb161567
- Build state: VALID, not expired; internal state IN_BETA_TESTING
- Recipient: the sole account holder's existing iCloud email, shown as ch***@icloud.com in this sanitized report. Apple can identify the exact recipient from the invitation resource.
- Internal group: 本人真机测试

## Actual result

The account holder is an existing tester in the group containing build 15.1. The tester has access to this app, the App Store Connect user has ACCOUNT_HOLDER / ADMIN roles and allAppsVisible=true, and the tester state remains INVITED.

One resend was made using the documented POST /v1/betaTesterInvitations endpoint. Apple returned a successful response and created invitation resource:

- Invitation resource ID: 0d9e7199-fd38-4425-bcf8-2874cb098e0b
- Resend accepted at: 2026-10-31 11:11:34 UTC / 19:11:34 Asia/Shanghai

The user subsequently confirmed this is their mailbox and other ordinary emails arrive normally, but the TestFlight invitation still has not arrived. There is no confirmed acceptance or installation. We have not repeatedly resent invitations, deleted/re-added the tester, or expired the build during this investigation.

## Expected result and request

The existing authorized internal tester should receive the TestFlight invitation for this app, accept it and test the assigned valid build. Please inspect the delivery or eligibility outcome for the invitation ID and advise whether there is an actionable delivery error. If more mailbox or account information is needed, please specify it.

The public invitation response does not contain a redeem URL/code or mailbox delivery log, so the API response alone cannot confirm email delivery. The separate old app and its disabled public link are not the subject of this report. The current app has no active external testing group; this report concerns the missing internal invitation only.

This report is prepared locally and has not been submitted to Apple. Ordinary mailbox delivery is confirmed to work; please investigate the specific TestFlight delivery or account/app eligibility outcome without treating the successful resend response as proof that the email arrived.
