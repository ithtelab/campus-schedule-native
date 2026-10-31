# TestFlight Beta review submission fails with HTTP 422 — 课间册 15.1

This report is prepared for Apple Developer Support and has not been sent. Please investigate the request below: the API returns a generic processing error and the build never enters review. This is a submission failure, not an App Review rejection.

## App and build

- App: 课间册
- App Store Connect App ID: 6829142615
- Bundle ID: com.ithtelab.campustimetable
- Team ID: RA59Z5Z78P
- Build number: 15.1
- Build ID: f53c1084-6f2a-4ce0-a1cd-bfb0eb161567
- Processing: VALID; expired: false; audience: APP_STORE_ELIGIBLE
- Minimum iOS version: 18.0
- Internal state: IN_BETA_TESTING
- External state before and after the request: READY_FOR_BETA_SUBMISSION
- External group: 公开外部测试, ID 04e6c0d3-76d0-4f19-ad73-73f9af08466f

## Exact request and response

At 2026-10-31 12:17:50.969 UTC / 20:17:50.969 Asia/Shanghai, one authorized submission request was made:

```http
POST /v1/betaAppReviewSubmissions
Content-Type: application/json
```

```json
{
  "data": {
    "type": "betaAppReviewSubmissions",
    "relationships": {
      "build": {
        "data": {
          "type": "builds",
          "id": "f53c1084-6f2a-4ce0-a1cd-bfb0eb161567"
        }
      }
    }
  }
}
```

Apple responded with HTTP 422 and header `x-request-id: IR6BIUU4F4VBPI64IXXUIVIUT4`:

```json
{
  "errors": [
    {
      "id": "91c9b0a7-a33b-4fec-90a3-316f8673fa9f",
      "status": "422",
      "code": "ENTITY_UNPROCESSABLE",
      "title": "There was an error processing your request.",
      "detail": "Please try again later."
    }
  ]
}
```

After the error, GET /v1/builds/f53c1084-6f2a-4ce0-a1cd-bfb0eb161567/betaAppReviewSubmission returned 404. No review resource or review rejection message exists. The external build state remains READY_FOR_BETA_SUBMISSION.

## Checks already completed

- The valid, unexpired, externally eligible build is assigned to the external group.
- Review first name, last name, phone, email and notes are populated; demoAccountRequired=false.
- Beta descriptions, feedback emails and privacy policy URLs exist for both en-US and zh-Hans.
- Build What to Test text exists: en-US 318 characters; zh-Hans 81 characters.
- The beta license agreement has nonempty agreementText.
- The account holder has ACCOUNT_HOLDER / ADMIN roles and access to all apps.
- The new public link is enabled with a limit of 100: https://testflight.apple.com/join/s1RtwCzq . This is a configuration check only; there is no approved external build and no verified external download or device installation.
- Existing review contact and metadata were preserved. No binary was reuploaded, no build was expired, no tester was removed, and no repeated review submission was performed during this attempt.

Please use the request ID to identify the failed validation or processing step and specify any actionable account/app setting or field that needs correction. The response does not identify a field; we cannot determine the cause from it.

Separately, the account holder has not received an internal TestFlight invitation after an API-accepted resend, although ordinary emails arrive normally. The invitation resource is 0d9e7199-fd38-4425-bcf8-2874cb098e0b (2026-10-31 11:11:34 UTC). This may be relevant context, but no common cause is established. See the separate invitation report.

No private keys, API tokens, passwords or full personal contact details are included in this report. Source diagnostics are retained locally in the ignored .tool-cache/apple directory.
