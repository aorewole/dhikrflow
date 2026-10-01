# Dhikr Counter — Third-Party Dependency Inventory

Every dependency in Dhikr Counter is audited according to the policy in `docs/MASTER_SPEC.md` and `docs/PRIVACY_AND_RELEASE.md`.

---

## Production Dependencies

| Package | Version | License | Justification | Network Access? | Platform / Privacy Risk |
|---|---|---|---|---|---|
| **`flutter`** | SDK | BSD-3-Clause | Core application UI framework | None | None |
| **`cupertino_icons`** | `^1.0.8` | MIT | Standard iOS-style glyph icons | None | None |
| **`shared_preferences`** | `^2.5.5` | BSD-3-Clause | Local key-value store for user settings, theme, and favorite adhkar | **None** | Purely local OS preferences (NSUserDefaults / SharedPreferences) |
| **`path_provider`** | `^2.1.6` | BSD-3-Clause | Resolves standard app documents directory for local JSON session storage | **None** | Sandbox-contained file paths |

---

## Development Dependencies

| Package | Version | License | Justification |
|---|---|---|---|
| **`flutter_test`** | SDK | BSD-3-Clause | Official test harness for unit, widget, and state machine verification |
| **`flutter_lints`** | `^6.0.0` | BSD-3-Clause | Official static analysis lint rules |

---

## Privacy Certification

- **Zero Cloud APIs:** None of the packages communicate over HTTP, WebSockets, or remote sockets.
- **Zero Telemetry / Analytics:** No Firebase, Google Analytics, Amplitude, Sentry, or third-party trackers.
- **Zero Audio Storage:** None of the persistence packages store or serialize microphone audio buffers.
