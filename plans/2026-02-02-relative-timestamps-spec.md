# Relative timestamps — product spec

## What

The user toggles a setting **Relative timestamps** in Appearance. With it on, every timestamp in the app changes from absolute clock time (`12:00`, `02/01`, `Sun, 1 Feb`) to a duration relative to "now" (`2h5m ago`, `1d ago`, `Yesterday`), and refreshes automatically once a minute so the displayed age stays accurate. The setting ships off by default — opt-in.

The feature covers every SimpleX app and every operating system:

- **Android** — multiplatform Kotlin source (`apps/multiplatform/`, Android target).
- **Desktop** — one Compose Multiplatform JVM binary that runs identically on **Linux**, **macOS**, and **Windows** (`apps/multiplatform/`, Desktop target). No per-OS branching: the same code, the same formatter, the same ticker.
- **iOS** — separate Swift/SwiftUI codebase (`apps/ios/`). Same format, same 60-second cadence, same off-by-default toggle.

The two codebases (multiplatform Kotlin, iOS Swift) ship the feature with parallel structure: one preference, one pair of formatters, one global ticker, one toggle in Appearance. The user-visible behavior is identical across platforms.

Three surfaces change:

1. **Chat list timestamp** — the small text on each chat row showing when its last message arrived. Today it's `12:00` for today and `02/01` for older items.
2. **Message metadata timestamp** — the small text in each message's status row showing when the message was sent or received.
3. **Date separators inside a chat** — the day banner between message groups (today shows `Today` / `Sun, 1 Feb`). On Android and Desktop a floating date overlay also appears while scrolling and follows the same formatter; iOS has no floating overlay, only the inline separator.

Three pending-state list rows — contact request, pending contact connection, content request preview — reuse the same chat-list timestamp surface and follow the same formatter automatically.

### Format — chat list and message metadata

| Age | Display | Example |
|---|---|---|
| `< 1 minute` | `<1m ago` | `<1m ago` |
| `< 1 hour` | `Xm ago` | `5m ago`, `45m ago` |
| `< 24 hours` | `XhYm ago` | `2h5m ago`, `23h0m ago` |
| `< 365 days` | `Xd ago` | `1d ago`, `6d ago`, `182d ago` |
| `≥ 365 days` | `XyXd ago` | `1y0d ago`, `1y100d ago` |

Seconds are never shown — anything under one minute reads `<1m ago`. The worst-case width is 10 characters (`1y100d ago`), which sets the column width the chat list reserves so ages can tick up without shifting layout.

### Format — date separators

| Boundary | Display |
|---|---|
| Same calendar day | `Today` |
| Previous calendar day | `Yesterday` |
| 2 – 364 days | `X days ago` |
| ≥ 365 days | `X years X days ago` |

Pluralization: `1 year` / `2 years`, `1 day` / `2 days`. The two parts compose: `1 year 1 day ago`, `2 years 5 days ago`. The day boundary is calendar-day difference in the user's local timezone — same rule the existing separator already uses to group messages by day — so a message from 11:50 PM yesterday reads `Yesterday`, never `<1h ago`.

### Auto-refresh

A single 60-second ticker invalidates the chat list, the open chat's message metadata, and the date separators above each message when the feature is on. Re-evaluations happen at most once per minute, in lockstep across those surfaces — so the "5m ago → 6m ago" transition is consistent where the user is most likely to be reading.

Two surfaces render relative ages but are *not* on the per-minute ticker:

- **Chat-event banners inside the chat** (a feature being toggled on, a member created as contact, a marked-deleted bookmark) — these are short, mid-history lines a user reads in passing. They display in relative form, but the age refreshes only when the chat naturally recomposes (e.g. on scroll or new message). The `<1m ago` → `5m ago` drift across a minute boundary while the user stares at one isn't enough to justify subscribing every event banner to the ticker.
- **The floating date overlay** (Android/Desktop) that flashes while scrolling and disappears after a second of stillness. Each instance lives well under a minute, so it never sees a tick.

The ticker stops when the feature is off (zero background work for users who don't opt in).

## Why

Relative ages communicate "how recently did this happen" at a glance — the reader's actual question — without subtracting from "now". For active conversations they're more informative than wall-clock time (`2 minutes ago` vs `12:00` — the latter requires knowing what time it is now and doing the math). For long chat-list scanning they make the gap between threads (`1d ago` vs `2 weeks ago`) immediately legible without date arithmetic.

The same information is already conveyed by absolute timestamps; the choice is which mental operation the user performs. Users who prefer absolute reference points keep them by default — the feature ships off so existing behavior is preserved without action.

The 60-second update interval matches the floor of what we display (no seconds): there's no value in tighter, and looser would let `9m ago` stay on screen while the truth is `11m ago`.

## How

### Where the toggle lives

Appearance settings on every platform — a single boolean labeled **Relative timestamps** with a one-line description "Show timestamps as '2h5m ago' instead of '12:00'." The toggle is grouped in its own section (no existing section in Appearance is a natural home for it — see "Open questions"). The on-disk key persists per-user, per-platform; the user toggling on Android does not affect their Desktop or iOS setting.

### What the user sees when they flip it

On toggle-on: every visible timestamp in the chat list, the open chat, and any date separator in view recomputes and redraws in relative form. The 60-second ticker starts.

On toggle-off: absolute formatters return on the next recomposition; the ticker stops.

The state persists across app launches **and travels with the database export / import**. It is included in the `AppSettings` bundle the app already serializes into every export — the same bundle that already carries `oneHandUI`, `chatBottomBar`, theme choice, privacy toggles, and so on. Concretely:

- **Same device** — toggle, export, re-import: the setting is preserved (was always true for `SharedPreferences` / `UserDefaults`, and now belt-and-brace from the `AppSettings` payload too).
- **New device or reinstall + import** — the imported archive applies its `relativeTimestamps` value to the fresh install, overriding the default `false`. A user who turns on relative timestamps on phone A, exports, and imports the archive on phone B gets relative timestamps on phone B without re-toggling.
- **Archives from app versions before this feature** — the field is absent from the saved JSON; the local default applies (same skip-if-nil behavior every other `AppSettings` field has).
- **Fresh install, no import** — default `false`.

### Observable edge cases

- **Future timestamps** (clock skew between the user and a peer, or the user's clock running fast) — relative-mode displays `<1m ago` for messages and `Today` for date separators. We never show negative durations.
- **Leap years** — the year boundary is approximated at 365 days. A 366-day-old message reads `1y0d ago`. Calendar-precise year math is out of scope; this rounding is in the same spirit as `1d ago` for "27 hours ago".
- **Timezone changes and DST** — date separators dispatch on calendar-day difference in the user's *current* timezone, the same rule the existing separator uses to group messages. A user who travels across timezones sees the separators regroup the same way they do today.
- **Layout** — the chat list and message-metadata column reserve space for the worst-case relative width (10 characters, `1y100d ago`) when the setting is on. Reservation reuses each platform's existing mechanism (the multiplatform `reserveSpaceForMeta` helper, the iOS `MetaColorMode.transparent` rendering pass) so display text and reserved width come from a single source. No row-by-row shift as ages tick up; absolute-mode reservation is unchanged.

## Out of scope

- **Per-surface toggling.** One switch covers all three surfaces. A user wanting relative ages on one surface and absolute on another would be choosing inconsistency; we don't expose that.
- **Sub-minute precision.** Anything under 60 seconds reads `<1m ago`. No `Just now`, no `30s ago`. The 60-second cadence and the displayed precision match.
- **Hybrid forms** like `Yesterday at 11pm` for separators or `at 12:00` appended to a relative age. A separator on the previous calendar day reads `Yesterday`; the message timestamps underneath read their own relative age.
- **Per-platform format variants** (`SimpleX [3]` on Windows but `(3) SimpleX` on macOS, or any analog here). The format strings are identical across Android, iOS, and Desktop — same wording, same separators, same worst-case width.
- **Cross-device preference sync.** The toggle is per-install. A user who sets it on their phone has to set it again on their desktop.
- **Timestamps that get serialized to text or files.** The message-detail dialog (`ChatItemInfoView`), the server-stats summary, the message-info copy/share buffer, the database-archive filenames (`SimpleDateFormat`), and the developer terminal all keep absolute timestamps in the text they produce. Relative ages become meaningless once decoupled from a present "now" — copying `"5m ago"` to a file and reopening it tomorrow is a bug, not a feature. This is about the *content* these surfaces emit; the toggle itself persists across database export/import (see "What the user sees when they flip it" above).
- **Quoted-message detail timestamps.** In the message-info dialog the quoted-message header shows `localTimestamp(qi.sentAt)`. It stays absolute for the same reason as the other detail-view timestamps. Inline quote previews inside chat bubbles render no timestamp today and gain none from this change.
- **Three-form plural support** (CLDR rules: zero / one / few / many) for the date-separator strings. Translators get singular and plural; languages that need more (Russian, Polish, Arabic) must pick the least-wrong form, consistent with the rest of the app's count-bearing strings.
- **Locale-aware phrasing variants** (`il y a 2h5m`, `vor 2h5m`). Strings ship in `MR/base/strings.xml` (multiplatform) and `en.lproj/Localizable.strings` (iOS); translation arrives through each platform's normal localization pipeline. The English ordering (`X years X days ago`) may not be ideal in every target language — translators can re-order via the positional format.

## Open questions

- **Section home in Appearance.** Neither codebase has an obvious home: multiplatform desktop has Language, Themes, Tray, Toolbars, Message shape, Profile image, Font scale, Density scale; iOS has Language, Chat list, Themes, Message shape, Profile images, App icon. The toggle ships in a new "Timestamps" section on each platform. The choice is reversible.
