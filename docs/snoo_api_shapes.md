# Snoo API Shapes

Reference for the Snoo endpoints inspected from this app on April 12, 2026.

These shapes were confirmed by running `rails runner` with the app's stored Snoo credentials and inspecting the JSON returned by the API.

All example values below are redacted placeholders. Treat the examples as key/type references, not literal production values.

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
        "updatedAt": "YYYY-MM-DDTHH:MM:SS.sssZ"
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

## Observed Event Payload Shape

Live event payloads currently observed by `SnooMqttListener` have this shape:

```json
{
  "serialNumber": "device_serial",
  "deviceType": 1,
  "firmwareVersion": "v1.15.05",
  "babyIds": [
    "baby_id"
  ],
  "name": "device_name",
  "presence": {
    "online": true,
    "since": "YYYY-MM-DDTHH:MM:SS.sssZ"
  },
  "presenceIoT": {
    "online": true,
    "since": "YYYY-MM-DDTHH:MM:SS.sssZ"
  },
  "awsIoT": {
    "thingName": "aws_iot_thing_name",
    "clientEndpoint": "example-ats.iot.us-east-1.amazonaws.com",
    "awsRegion": "us-east-1",
    "clientReady": true
  },
  "activityState": {
    "event": "cry",
    "event_time_ms": 1700000000000,
    "iot_capable": true,
    "left_safety_clip": 1,
    "right_safety_clip": 1,
    "rx_signal": {
      "rssi": -45,
      "strength": 100
    },
    "state_machine": {
      "audio": "on",
      "down_transition": "LEVEL2",
      "hold": "off",
      "is_active_session": "true",
      "session_id": "session_id",
      "since_session_start_ms": 159604,
      "state": "LEVEL3",
      "sticky_white_noise": "off",
      "time_left": 240,
      "up_transition": "LEVEL4",
      "weaning": "off"
    },
    "sw_version": "v1.15.05",
    "system_state": "normal"
  },
  "lastSSID": {
    "name": "wifi_name",
    "updatedAt": "YYYY-MM-DDTHH:MM:SS.sssZ"
  },
  "provisionedAt": "YYYY-MM-DDTHH:MM:SS.sssZ"
}
```

Important runtime fields:
- Top level: `serialNumber`, `firmwareVersion`, `name`, `presence.online`, `presenceIoT.online`, `awsIoT.thingName`
- `activityState`: `event`, `event_time_ms`, `left_safety_clip`, `right_safety_clip`, `sw_version`, `system_state`
- `activityState.state_machine`: `state`, `up_transition`, `down_transition`, `hold`, `audio`, `sticky_white_noise`, `time_left`, `weaning`, `session_id`, `is_active_session`, `since_session_start_ms`

Notes:
- `event_time_ms` is in Unix epoch milliseconds.
- `left_safety_clip` and `right_safety_clip` are currently observed as `1`/`0` style integers.
- `state_machine.state` is observed as values like `ONLINE`, `BASELINE`, `LEVEL1`, `LEVEL2`, `LEVEL3`.
- The same payload may be seen more than once in polling mode; the app now deduplicates repeated payloads by event signature before saving.

## Current Mapping In App

The dashboard settings panel currently prefers:
- `GET /us/me/v10/babies` for baby-specific Snoo settings
- `GET /us/me/v10/settings` for account-level fallback values such as `daytimeStart`
- event payloads as a fallback for runtime/device state

## Runtime Control Commands

The app's runtime controls use the device AWS IoT MQTT topic:

- Topic: `<thingName>/state_machine/control`
- Transport: MQTT over secure WebSocket to the device `awsIoT.clientEndpoint`

Observed and referenced command payloads:

```json
{
  "ts": 17760640870280000,
  "command": "send_status"
}
```

```json
{
  "ts": 17760640870280000,
  "command": "go_to_state",
  "state": "LEVEL1",
  "hold": "on"
}
```

```json
{
  "ts": 17760640870280000,
  "command": "set_sticky_white_noise",
  "state": "on",
  "timeout_min": 15
}
```

Notes:
- `ts` is sent as a large integer timestamp in 100 ns-style units (`Time.now.to_f * 10_000_000` in the app).
- `go_to_state` is used for both direct state/level moves and hold toggles.
- `set_sticky_white_noise` appears to accept `state: "on" | "off"` and a `timeout_min` integer.
- `hold` is sent as `"on"` or `"off"`.
- The `send_status` command path was validated from this app on April 13, 2026 by publishing successfully against the live device MQTT endpoint.
