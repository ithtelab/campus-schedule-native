# TestFlight: external review submission fails after a marketing-version change; previous build is visible but cannot be installed internally

Please investigate TestFlight distribution eligibility and submission processing for App ID 6828962951. We have captured a fresh error for a newly uploaded marketing version. We have not established the root cause or whether both symptoms share it.

## Latest build and API error

- App: 校园课表 / CampusSchedule
- Team ID: RA59Z5Z78P
- App ID: 6828962951
- Bundle ID: com.ithtelab.campusschedule
- Marketing version / build: 0.1.1 / 7.1, upgraded from marketing version 0.1.0
- Build ID: ddcc9625-a6bc-4138-871f-cec1abd870c4
- Signed upload completed on 31 October 2026 at 05:30:57 UTC.
- processingState VALID, expired false, audience APP_STORE_ELIGIBLE
- internalBuildState IN_BETA_TESTING; externalBuildState READY_FOR_BETA_SUBMISSION
- No successful Beta App Review submission exists for this build.

The App Store Connect website's external Add Build → What to Test wizard displays “There was an error processing your request. Please try again later.” after Submit for Review. The What to Test field is populated. Authorized review contact fields, description and feedback email are present; a demo account is not required. We updated the review notes and beta description to accurately describe this demo edition, then made one authorized API submission. It returned:

```json
{
  "timestamp": "2026-10-31T05:37:22.715Z",
  "method": "POST",
  "path": "/v1/betaAppReviewSubmissions",
  "buildID": "ddcc9625-a6bc-4138-871f-cec1abd870c4",
  "status": 422,
  "traceHeaders": { "x-request-id": "UNCHDTZWUV4XPH4S3GRDOHTJBI" },
  "errors": [{
    "id": "8ace89c8-5d1e-4aa4-89a8-30656aa0a7b2",
    "status": "422",
    "code": "ENTITY_UNPROCESSABLE",
    "title": "There was an error processing your request.",
    "detail": "Please try again later."
  }]
}
```

Request payload:

```json
{"data":{"type":"betaAppReviewSubmissions","relationships":{"build":{"data":{"type":"builds","id":"ddcc9625-a6bc-4138-871f-cec1abd870c4"}}}}}
```

The response has no source pointer, associated error, or BETA_CONTRACT_MISSING code. Please use the request ID to identify the actionable failure or any account/app provisioning state preventing submission.

## Separate internal installation symptom

The prior build 0.1.0 (6.1), ID b57b164c-cbb6-45b2-befa-9ced382ba235, was processed VALID, unexpired and assigned to the authorized account holder's internal group. The tester can see it in the iPhone TestFlight app with an Install button, but tapping it produces: “无法安装‘校园课表’。所请求的 App 不可用或者不存在。” / “Could not install CampusSchedule. The requested app is not available or doesn't exist.”

The screenshot shows approximately 13:20 Asia/Shanghai on 31 October 2026 (05:20 UTC). Switching Wi-Fi/cellular still fails. The tester previously reported iOS 27.2; the app minimum is iOS 27.0. Exact hardware model and TestFlight version have not yet been captured. The user has not yet confirmed the device installation result for the newer 7.1; please do not treat the 6.1 screenshot as a 7.1 failure.

Read-only checks show the account holder has ACCOUNT_HOLDER / ADMIN roles and allAppsVisible=true, the internal group contains both the tester and build, and the tester's apps relationship includes this App ID. The current tester state for the new build is INVITED; previous INSTALLED state did not prove that 6.1 had installed.

The betaLicenseAgreement resource exists and its agreementText is empty. We have not modified legal agreement text, and do not claim that this represents a missing account-level contract. Earlier 5.1 beta submission attempts returned the same generic 422, without a contract-specific code. Old 4.1 expiry was explicitly confirmed by the user as manual; this report does not claim unexplained expiry.

## Expected result

The eligible external build should submit for Beta App Review, or return a specific requirement we can resolve. An assigned internal tester should be able to install a valid, compatible build. Please investigate both observations and indicate whether they are related. We can collect device diagnostics if you specify what is required.

Attachments prepared: website submission error screenshot, 6.1 iPhone installation error screenshot, exact 7.1 API response with request ID, sanitized read-only 7.1 diagnostics and upload receipt. No credentials, API tokens, signing keys, passwords or full personal contact details are included. This report has not yet been sent to Apple Support or Feedback Assistant.
