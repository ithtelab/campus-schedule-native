# TestFlight 0.1.0 (6.1) is visible to the internal tester, but installation fails with “The requested app is not available or doesn't exist”

Please investigate the TestFlight distribution/installation availability of this build. Public API eligibility checks succeed, but the authorized tester cannot install it on an iPhone. We have not established the root cause.

## App and build

- App name: 校园课表 (CampusSchedule)
- App Store Connect App ID: 6828962951
- Bundle ID: com.ithtelab.campusschedule
- Developer Team ID: RA59Z5Z78P
- Marketing version / build: 0.1.0 / 6.1
- Build ID: b57b164c-cbb6-45b2-befa-9ced382ba235
- Minimum supported iOS: 27.0
- Device iOS: 27.2, as previously reported by the tester. Exact hardware model and TestFlight app version have not yet been captured.
- Upload workflow: https://github.com/ithtelab/campus-schedule-native/actions/runs/41169998165 (private; successful upload receipt included in the diagnostic package)

## Reproduction

1. Use the existing authorized account holder's internal testing access on an iPhone.
2. Open TestFlight. The app is listed as “校园课表 0.1.0 (6.1) · 90天” and has an Install button.
3. Tap Install.
4. The installation fails with “无法安装‘校园课表’。所请求的 App 不可用或者不存在。” / “Could not install CampusSchedule. The requested app is not available or doesn't exist.”

Observed on 31 October 2026 at approximately 13:20 Asia/Shanghai (05:20 UTC). Switching between Wi-Fi and cellular still produced the same error.

Expected: the valid, unexpired build assigned to the authorized internal tester can be installed.

## Verified evidence

Read-only API checks at 31 October 2026 05:24:52 UTC show:

- processingState: VALID
- expired: false
- internalBuildState: IN_BETA_TESTING
- externalBuildState: READY_FOR_BETA_SUBMISSION (this report concerns internal installation)
- buildAudienceType from the build audit: APP_STORE_ELIGIBLE
- usesNonExemptEncryption: false
- The internal group “本人真机测试” contains build 6.1 and the account holder.
- The tester's apps relationship includes App ID 6828962951.
- The App Store Connect user has ACCOUNT_HOLDER / ADMIN roles and allAppsVisible=true.
- The tester's INSTALLED state relates to existing tester history; it is not evidence that 6.1 installed successfully.
- The archive and export succeeded. App and widget App Store provisioning, signed App Group entitlements, bundle identifiers and matching build numbers were verified during upload.

Additional observations, not confirmed causes:

- The app's betaLicenseAgreement resource exists; its agreementText is empty. No agreement was modified or accepted during diagnosis. This does not establish whether any separate account-level contract is missing.
- A previous external submission for build 5.1 returned generic HTTP 422 ENTITY_UNPROCESSABLE, “Please try again later.” at 31 October 2026 03:49:00 UTC, error ID 6a2846d9-7bb0-49cd-8b53-c8a739bbe000. No BETA_CONTRACT_MISSING code was returned. Its relationship to the current installation failure is unconfirmed.
- An optional appAvailabilityV2 query returned 404; an optional buildBundles relationship query returned 403 because that relationship does not support reads. Neither response identifies the device installation failure.

Please inspect the download/distribution availability and any app/account eligibility or provisioning state for App ID 6828962951 and build ID b57b164c-cbb6-45b2-befa-9ced382ba235, and provide an actionable reason for the installation failure. If device logs or a sysdiagnose are required, please specify the collection needed.

Attachments: iPhone error screenshot, sanitized read-only install diagnostics, successful upload receipt. No private signing material, passwords, API tokens or credentials are included.
