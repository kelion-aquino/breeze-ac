# SmartThings API notes

Findings from mapping Samsung WindFree air conditioners (models `ARA-WW-TP1-22-COMMON` and
`TP1X_DA-AC-RAC-01001_0000`) through the public [SmartThings API](https://developer.smartthings.com/docs/api/public).
Every device exposes a single `main` component.

## Capabilities used by Breeze

| Feature          | Capability / attribute                                  | Command                  | Values                                                        |
|------------------|---------------------------------------------------------|--------------------------|---------------------------------------------------------------|
| Power            | `switch.switch`                                         | `on` / `off`             |                                                               |
| Mode             | `airConditionerMode.airConditionerMode`                 | `setAirConditionerMode`  | `auto`, `cool`, `dry`, `wind` (+ `heat` on some models)       |
| Target temp      | `thermostatCoolingSetpoint.coolingSetpoint`             | `setCoolingSetpoint`     | 16–30 °C, step 1 (`coolingSetpointRange`)                     |
| Fan speed        | `airConditionerFanMode.fanMode`                         | `setFanMode`             | `auto`, `low`, `medium`, `high`, `turbo`                      |
| Swing            | `fanOscillationMode.fanOscillationMode`                 | `setFanOscillationMode`  | `fixed`, `vertical`, `horizontal`, `all`                      |
| WindFree & co.   | `custom.airConditionerOptionalMode.acOptionalMode`      | `setAcOptionalMode`      | `off`, `sleep`, `quiet`, `smart`, `speed`, `windFree`, `windFreeSleep` |
| Auto Clean       | `custom.autoCleaningMode.autoCleaningMode`              | `setAutoCleaningMode`    | `on`, `off`                                                   |
| Room temperature | `temperatureMeasurement.temperature`                    | —                        | °C                                                            |
| Humidity         | `relativeHumidityMeasurement.humidity`                  | —                        | %                                                             |
| Filter           | `custom.dustFilter.dustFilterStatus` / `dustFilterUsage`| —                        | `normal` / `wash`, usage in %                                 |

Always prefer the device's `supported*` lists over hard-coded values. `airConditionerFanMode.availableAcFanModes`
holds the subset allowed in the current mode.

## Quirks

### State is stale until the device is asked to report

After a command succeeds (`"status": "COMPLETED"`), the cloud keeps returning the **old** value for some
attributes (notably `fanMode`) indefinitely. Sending `refresh.refresh` makes the device report its real state,
which shows up within about a second. The official app does this when a device is opened. Breeze sends a refresh
after every command, when the popover opens and on every poll.

### Display light (OCF, inverted)

`samsungce.airConditionerLighting` is listed in `custom.disabledCapabilities`, so the light is controlled through
the raw OCF `execute` capability. The meaning is **inverted**: the option enables a "light off" feature.

```json
{"component": "main", "capability": "execute", "command": "execute",
 "arguments": ["mode/vs/0", {"x.com.samsung.da.options": ["Light_On"]}]}
```

| Option      | Effect              |
|-------------|---------------------|
| `Light_On`  | turns the display **off** |
| `Light_Off` | turns the display **on**  |

The current light state cannot be read back through the API, so Breeze remembers the last choice per device.

### Not available on these models

`custom.spiMode` (ionizer) is disabled and `setSpiMode` is listed in `unavailableCommands`. The air quality, dust
and odor sensors report `null`.

## OAuth

Personal access tokens created after December 2024 expire after 24 hours, so Breeze uses an OAuth-In SmartApp:

- Authorize: `https://api.smartthings.com/oauth/authorize` (`response_type=code`, `state`, `scope`)
- Token: `POST https://auth-global.api.smartthings.com/oauth/token` with HTTP Basic auth (`client_id:client_secret`),
  `grant_type=authorization_code` or `refresh_token`
- Access tokens last 24 h; the refresh token rotates on every use.
- Redirect URIs must be `https`; `https://httpbin.org/get` is the usual choice for personal apps. Breeze intercepts the
  redirect in its login web view, so the page is never actually loaded.
