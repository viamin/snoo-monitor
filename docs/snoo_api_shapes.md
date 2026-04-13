# Snoo API Shapes

Reference for the Snoo endpoints inspected from this app on April 12, 2026.

These shapes were confirmed by running `rails runner` with the app's stored Snoo credentials and inspecting the JSON returned by the API.

## `GET /us/me/v10/settings`

Global account-level settings.

Example shape:

```json
{
  "daytimeStart": 7,
  "country": "US",
  "additionalLogging": false
}
```

Notes:
- `daytimeStart` appears to be an hour-of-day integer.
- This endpoint does not include baby-specific Snoo tuning settings like responsiveness or start volume.

## `GET /us/me/v10/babies`

Array of baby records. The Snoo tuning values currently used by the dashboard live under each baby's `settings` object.

Example shape:

```json
[
  {
    "_id": "baby_id",
    "babyName": "baby_name",
    "birthDate": "YYYY-MM-DD",
    "sex": "Female",
    "preemie": null,
    "disabledLimiter": false,
    "settings": {
      "responsivenessLevel": "lvl-2",
      "minimalLevelVolume": "lvl-2",
      "soothingLevelVolume": "lvl0",
      "minimalLevel": "baseline",
      "motionLimiter": true,
      "weaning": false,
      "carRideMode": false,
      "daytimeStart": 7,
      "ledBrightnessScale": 3
    },
    "pictures": [
      {
        "id": "picture_id",
        "mime": "image/png",
        "encoded": false,
        "updatedAt": "2026-03-13T05:41:56.424Z"
      }
    ],
    "breathSettingHistory": [],
    "createdAt": "YYYY-MM-DDTHH:MM:SS.sssZ",
    "updatedAt": "YYYY-MM-DDTHH:MM:SS.sssZ",
    "startedUsingSnooAt": "YYYY-MM-DDTHH:MM:SS.sssZ",
    "expectedBirthDate": "YYYY-MM-DD",
    "updatedByUserAt": "YYYY-MM-DDTHH:MM:SS.sssZ",
    "dateOfFirstSession": "YYYY-MM-DDTHH:MM:SS.sssZ"
  }
]
```

Important fields in `settings`:
- `responsivenessLevel`
- `minimalLevelVolume`
- `soothingLevelVolume`
- `minimalLevel`
- `motionLimiter`
- `weaning`
- `carRideMode`
- `daytimeStart`
- `ledBrightnessScale`

## `GET /us/me/v10/me`

User/profile metadata.

Example shape:

```json
{
  "email": "user@example.com",
  "privacyConsent": [],
  "familyId": "family_id",
  "givenName": "given_name",
  "surname": "surname",
  "region": "US",
  "userId": "user_id"
}
```

Notes:
- Useful for family/user identifiers.
- Does not appear to contain Snoo tuning settings.

## `GET /us/me/v10/devices`

Observed response:

```http
404 Cannot GET /us/me/v10/devices
```

Notes:
- Although this path appeared in Charles, direct API requests from this app returned `404`.
- Device inventory is currently fetched successfully from `GET /hds/me/v11/devices`.

## Current Mapping In App

The dashboard settings panel currently prefers:
- `GET /us/me/v10/babies` for baby-specific Snoo settings
- `GET /us/me/v10/settings` for account-level fallback values such as `daytimeStart`
- event payloads as a fallback for runtime/device state
