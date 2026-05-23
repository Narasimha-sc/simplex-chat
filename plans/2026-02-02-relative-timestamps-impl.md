# Relative timestamps — implementation plan

Companion to `2026-02-02-relative-timestamps-spec.md`. The spec defines what the user sees and why. This plan defines what the diff looks like.

Two codebases ship the feature:

- **Multiplatform Kotlin** — `apps/multiplatform/`. One source tree, one preference, one set of formatters; the Android target and the Desktop JVM target both consume it. The Desktop JVM target ships a single binary that runs on **Linux**, **macOS**, and **Windows** — there is no per-OS code path here, so "Desktop" below means all three OSes at once.
- **iOS Swift** — `apps/ios/`. Separate codebase, parallel structure (preference, formatters, ticker, toggle), same user-visible behavior.

The two trees are sequenced as independent commits in their respective PRs; neither blocks the other.

## Surface

The change touches the same five layers on each platform:

| Layer | Multiplatform (Android + Desktop L/M/W) | iOS |
|---|---|---|
| Preference | `SharedPreference<Boolean>` in `SimpleXAPI.kt`, default false. | `@AppStorage(DEFAULT_RELATIVE_TIMESTAMPS)` keyed off `appDefaults`, default false. |
| Strings | `MR/base/strings.xml`. | `en.lproj/Localizable.strings`. |
| Formatters | Two pure `(Instant) -> String` functions in `ChatModel.kt`. `CIMeta.timestampText` stays a property — its getter reads the pref synchronously and dispatches. A sibling property `CIMeta.timestampReserveText` returns the 10-char worst-case pad in relative mode for layout reservation. | Same shape: two pure `(Date) -> String` functions in `ChatTypes.swift`; `CIMeta.timestampText` stays a property returning `Text`; a sibling `CIMeta.timestampReserveText` returns the worst-case pad as `Text(verbatim:)`. |
| Ticker | Top-level `mutableStateOf<Long>` driven by a `LaunchedEffect` keyed on the pref. | `ObservableObject` singleton with a `Timer.scheduledTimer`, started/stopped by `ContentView` based on the pref and `scenePhase`. |
| Call sites + toggle | Four reactive surfaces: meta row (`CIMetaView`), chat list, two pending rows, date separator. The date-separator decision logic in `ChatView.kt:3727` is fixed independently (it was already a latent bug). `reserveSpaceForMeta` is **unchanged** — it just reads `meta.timestampReserveText` instead of `meta.timestampText`. New `TimestampsSection` in `Appearance.desktop.kt`/`.android.kt`. | Same surfaces (no floating overlay on iOS). `ciMetaText` is **unchanged in signature** — it branches on the existing `colorMode == .transparent` to pick `meta.timestampReserveText` instead of `meta.timestampText`. New `Section("Timestamps")` in `AppearanceSettings.swift`. |

The dispatch between absolute and relative lives **inside** the `meta.timestampText` getter (one synchronous pref read per access — fast, memory-cached, cheap). Width reservation routes through `meta.timestampReserveText` so display text and reserved width come from the same source per mode and can never disagree. No `relative` parameters thread through `CIMetaText` / `reserveSpaceForMeta` / `ciMetaText` — their signatures are unchanged.

### Why a property, not a parameterized function

The pref read inside a property getter is a `HashMap` lookup against the platform's settings cache — single-digit nanoseconds. Even 200 reads per recomposition costs single-digit microseconds, well below the layout pass overhead it nests inside. The earlier draft's "hot-path pref read" concern, on measurement, is not a concern.

Width-reservation and display each go through their own dedicated accessor (`timestampReserveText` vs `timestampText`) — both pref-aware, both deterministic per mode — so they can't drift relative to each other. There is no parallel-dispatch risk.

Hidden dispatch at the call site is the genuine cost. The property form trades it away for a much smaller diff: no `CIMetaText` signature change, no `reserveSpaceForMeta` signature change, no four-caller cascade, no per-call-site `if (useRelative) ...` at the chat list, pending rows, or message metadata. Net diff is dominated by additive lines (one new property, one new formatter pair, ticker, settings entry) rather than touching every existing accessor.

# Multiplatform (Android + Desktop on Linux, macOS, Windows)

## Foundation

### Preference

`common/src/commonMain/kotlin/chat/simplex/common/model/SimpleXAPI.kt`

Add a `val` near the privacy/UI preference block (around line 124, next to `privacySanitizeLinks`):

```kotlin
val relativeTimestamps = mkBoolPreference(SHARED_PREFS_RELATIVE_TIMESTAMPS, false)
```

Add the constant in the `SHARED_PREFS_*` block (around line 502):

```kotlin
private const val SHARED_PREFS_RELATIVE_TIMESTAMPS = "RelativeTimestamps"
```

The default is `false` so existing behavior is preserved. The name matches the on-disk key convention (`PascalCase`).

### Preference storage and the database export/import boundary

`mkBoolPreference` writes to the platform's `Settings` instance — Android `SharedPreferences`, Desktop `multiplatform-settings`, iOS `UserDefaults.standard` (read via `@AppStorage`). That is the runtime read path. For export/import, the pref piggybacks on the existing `AppSettings` bundle so it travels with the database the same way `oneHandUI`, `chatBottomBar`, `privacyProtectScreen`, and the theme settings already do.

**The existing pipeline** (already in place — no new infrastructure):

1. **On export**, `DatabaseView.kt:594` calls `controller.apiSaveAppSettings(AppSettings.current.prepareForExport())` *before* `apiExportArchive`. `prepareForExport()` produces a delta against `AppSettings.defaults` — only fields whose current value differs are populated. The Haskell core persists this JSON inside the SQL database. The subsequent `apiExportArchive` zips the database, so the saved JSON ships with the archive. iOS analog: `DatabaseView.swift` → `apiSaveAppSettings(AppSettings.current.prepareForExport())`.
2. **On import**, `DatabaseView.kt:673` sets `appPrefs.shouldImportAppSettings.set(true)`. On the next app boot, `Core.kt:136` calls `apiGetAppSettings(...)` (reads the JSON the imported database carried) and invokes `appSettings.importIntoApp()`, which writes each non-nil field into the local `appPreferences` via the same `SharedPreference.set(...)` API user toggles use. `SharedPreference.state` observers fire and the UI picks up the new values. iOS analog: `SimpleXAPI.swift:2125` checks `shouldImportAppSettingsDefault.get()`, fetches via `apiGetAppSettings`, calls `importIntoApp()` (in `AppSettings.swift`), which writes into `UserDefaults`; `@AppStorage` observers fire.

The mechanism is symmetric across both codebases and already battle-tested by `oneHandUI` and `chatBottomBar`, which travel with the export today. Adding `relativeTimestamps` to the bundle is four-line surgery on each side.

**Multiplatform** — `SimpleXAPI.kt:8038-8237`:

```kotlin
data class AppSettings(
  // ... existing fields ...
  var chatBottomBar: Boolean? = null,
  var relativeTimestamps: Boolean? = null,   // NEW
) {
  fun prepareForExport(): AppSettings {
    val empty = AppSettings()
    val def = defaults
    // ... existing diff lines ...
    if (chatBottomBar != def.chatBottomBar) { empty.chatBottomBar = chatBottomBar }
    if (relativeTimestamps != def.relativeTimestamps) { empty.relativeTimestamps = relativeTimestamps }   // NEW
    return empty
  }

  fun importIntoApp() {
    val def = appPreferences
    // ... existing imports ...
    chatBottomBar?.let { if (appPlatform.isAndroid) def.chatBottomBar.set(it) else def.chatBottomBar.set(true) }
    relativeTimestamps?.let { def.relativeTimestamps.set(it) }   // NEW
  }

  companion object {
    val defaults: AppSettings
      get() = AppSettings(
        // ... existing ...
        chatBottomBar = true,
        relativeTimestamps = false,   // NEW — matches the SharedPreference default
      )

    val current: AppSettings
      get() = defaults.copy(
        // ... existing ...
        chatBottomBar = def.chatBottomBar.get(),
        relativeTimestamps = def.relativeTimestamps.get(),   // NEW
      )
  }
}
```

**iOS** — `apps/ios/Shared/Model/AppAPITypes.swift:2118` (the `struct AppSettings` definition):

```swift
struct AppSettings: Codable, Equatable {
  // ... existing fields ...
  var chatBottomBar: Bool? = nil
  var relativeTimestamps: Bool? = nil   // NEW

  func prepareForExport() -> AppSettings {
    var empty = AppSettings()
    let def = AppSettings.defaults
    // ... existing diff lines ...
    if chatBottomBar != def.chatBottomBar { empty.chatBottomBar = chatBottomBar }
    if relativeTimestamps != def.relativeTimestamps { empty.relativeTimestamps = relativeTimestamps }   // NEW
    return empty
  }

  static var defaults: AppSettings {
    AppSettings(
      // ... existing ...
      chatBottomBar: true,
      relativeTimestamps: false   // NEW
    )
  }
}
```

And `apps/ios/Shared/Views/UserSettings/AppSettings.swift` (the extension carrying `importIntoApp()` and `current`):

```swift
extension AppSettings {
  public func importIntoApp() {
    let def = UserDefaults.standard
    // ... existing imports ...
    if let val = chatBottomBar { groupDefaults.setValue(val, forKey: GROUP_DEFAULT_CHAT_BOTTOM_BAR) }
    if let val = relativeTimestamps { def.setValue(val, forKey: DEFAULT_RELATIVE_TIMESTAMPS) }   // NEW
  }

  public static var current: AppSettings {
    let def = UserDefaults.standard
    var c = AppSettings.defaults
    // ... existing reads ...
    c.chatBottomBar = groupDefaults.bool(forKey: GROUP_DEFAULT_CHAT_BOTTOM_BAR)
    c.relativeTimestamps = def.bool(forKey: DEFAULT_RELATIVE_TIMESTAMPS)   // NEW
    return c
  }
}
```

**Compatibility:**

- **Archives from app versions before this feature** — `relativeTimestamps` is absent from the saved JSON. `importIntoApp` skips it (`?.let { ... }` / `if let val = ... { }`), the local default applies. No breakage.
- **Cross-platform archives** — Multiplatform and iOS share the same JSON schema for `AppSettings`. A Kotlin export imports cleanly on iOS and vice versa, just as today's `oneHandUI` does.
- **Cross-version forward compatibility** — older apps reading a JSON that *contains* `relativeTimestamps` ignore the unknown field (every codable / serializable decoder in this project skips unknowns). No breakage.

**Behavior summary:**

- Same-device export → import: pref is preserved.
- Cross-device export → import: the source's value applies on the destination, overriding the destination's prior default. Matches `oneHandUI` / `chatBottomBar`.
- Reinstall + import: the imported archive sets the pref; fresh-install default `false` is overridden.
- Fresh install, no import: default `false`.
- Migrating Android → iOS or Desktop ↔ Phone: the pref carries over.

### Strings

`common/src/commonMain/resources/MR/base/strings.xml`

```xml
<!-- Relative timestamps -->
<string name="relative_timestamps">Relative timestamps</string>
<string name="relative_timestamps_desc">Show timestamps as "2h5m ago" instead of "12:00"</string>

<!-- Abbreviated form (chat list, message metadata) -->
<string name="relative_time_less_than_minute">&lt;1m ago</string>
<string name="relative_time_minutes_ago">%dm ago</string>
<string name="relative_time_hours_minutes_ago">%1$dh%2$dm ago</string>
<string name="relative_time_days_ago">%dd ago</string>
<string name="relative_time_years_days_ago">%1$dy%2$dd ago</string>

<!-- Full-word form (date separators) -->
<string name="relative_date_today">Today</string>
<string name="relative_date_yesterday">Yesterday</string>
<string name="relative_date_days_ago">%d days ago</string>
<string name="relative_date_year_one">1 year</string>
<string name="relative_date_years_n">%d years</string>
<string name="relative_date_day_one">1 day</string>
<string name="relative_date_days_n">%d days</string>
<string name="relative_date_compound_ago">%1$s %2$s ago</string>
```

Pluralization is split into `_one` / `_n` strings rather than positional plurals because the codebase doesn't use Moko Plurals anywhere — adding it for one feature would be churn. The compound separator (`%1$s %2$s ago`) is positional so translators can re-order.

### Ticker state

`common/src/commonMain/kotlin/chat/simplex/common/model/ChatModel.kt`

Top-level, near the existing time helpers (~line 3475):

```kotlin
val timestampTick = mutableStateOf(0L)
```

A single global, of the same `mutableStateOf` shape the rest of `ChatModel.kt` uses. No `StateFlow`, no companion `start/stop` object — the lifecycle is owned by a `LaunchedEffect` (below) keyed on the pref, so the tick advances only while the pref is on and stops as soon as the pref goes off.

## Formatters

`common/src/commonMain/kotlin/chat/simplex/common/model/ChatModel.kt`, immediately after `getTimestampText` (~line 3515):

```kotlin
fun getRelativeTimestampText(t: Instant): String {
  val diff = Clock.System.now() - t
  if (diff.isNegative()) return generalGetString(MR.strings.relative_time_less_than_minute)

  val days = diff.inWholeDays.toInt()
  return when {
    diff.inWholeMinutes < 1 -> generalGetString(MR.strings.relative_time_less_than_minute)
    diff.inWholeHours < 1   -> generalGetString(MR.strings.relative_time_minutes_ago).format(diff.inWholeMinutes.toInt())
    days < 1                -> generalGetString(MR.strings.relative_time_hours_minutes_ago)
                                 .format(diff.inWholeHours.toInt(), (diff.inWholeMinutes % 60).toInt())
    days < 365              -> generalGetString(MR.strings.relative_time_days_ago).format(days)
    else                    -> generalGetString(MR.strings.relative_time_years_days_ago)
                                 .format(days / 365, days % 365)
  }
}

fun getRelativeDateText(t: Instant): String {
  val tz = TimeZone.currentSystemDefault()
  val daysDiff = (Clock.System.now().toLocalDateTime(tz).date.toEpochDays()
                    - t.toLocalDateTime(tz).date.toEpochDays()).toInt()
  if (daysDiff < 0) return generalGetString(MR.strings.relative_date_today)

  return when {
    daysDiff == 0  -> generalGetString(MR.strings.relative_date_today)
    daysDiff == 1  -> generalGetString(MR.strings.relative_date_yesterday)
    daysDiff < 365 -> generalGetString(MR.strings.relative_date_days_ago).format(daysDiff)
    else -> {
      val years = daysDiff / 365
      val days  = daysDiff % 365
      val y = if (years == 1) generalGetString(MR.strings.relative_date_year_one)
              else generalGetString(MR.strings.relative_date_years_n).format(years)
      val d = if (days == 1) generalGetString(MR.strings.relative_date_day_one)
              else generalGetString(MR.strings.relative_date_days_n).format(days)
      generalGetString(MR.strings.relative_date_compound_ago).format(y, d)
    }
  }
}
```

Both functions are pure on `Instant` + `Clock.System.now()` — same shape as the existing `getTimestampText` / `getTimestampDateText` they sit next to.

### `CIMeta.timestampText` becomes pref-aware; `CIMeta.timestampReserveText` is added

`ChatModel.kt:3406` (on `CIMeta`):

```kotlin
val timestampText: String get() =
  if (ChatController.appPrefs.relativeTimestamps.get()) getRelativeTimestampText(itemTs)
  else getTimestampText(itemTs, true)

val timestampReserveText: String get() =
  if (ChatController.appPrefs.relativeTimestamps.get()) WORST_CASE_RELATIVE_TIMESTAMP
  else timestampText
```

`ChatItem.timestampText` at line 2918 is unchanged — it already delegates to `meta.timestampText` and so picks up the relative form automatically.

The two properties have one consumer each:

- `meta.timestampText` — display: read by `CIMetaView.CIMetaText` at line 113 and by the chat-event item views that build `AnnotatedString`s with the message timestamp.
- `meta.timestampReserveText` — layout: read by `reserveSpaceForMeta` at line 172.

`reserveSpaceForMeta` itself changes by a single token:

```kotlin
if (showTimestamp) {
  appendSpace()
  res += meta.timestampReserveText   // was: meta.timestampText
}
```

The four existing callers (`CIRcvDecryptionError.kt:172, 204`, `CIGroupInvitationView.kt:119, 130`, `TextItemView.kt:131`) are **unchanged** — they hand a `CIMeta` to a function whose signature is unchanged.

The worst-case constant is top-level near the formatters:

```kotlin
// 10 chars — wider than any non-pathological relative timestamp shape.
const val WORST_CASE_RELATIVE_TIMESTAMP = "1y100d ago"
```

Without the sibling property, `reserveSpaceForMeta` would reserve the *current* timestamp text width (`5m ago`, `1d ago`, etc.) and the bubble would reflow on minute boundaries. With it, the relative-mode column is stable for the message's whole lifetime.

## Wiring

### Ticker lifecycle

`common/src/desktopMain/kotlin/chat/simplex/common/DesktopApp.kt`, inside the `AppWindow` composable at line 91 (alongside the other top-level `LaunchedEffect`s like the one at 198–201):

```kotlin
val useRelative by remember { ChatController.appPrefs.relativeTimestamps.state }
LaunchedEffect(useRelative) {
  while (useRelative) {
    delay(60_000)
    timestampTick.value = Clock.System.now().epochSeconds
  }
}
```

`LaunchedEffect(useRelative)` re-launches when the pref toggles. When `false`, the `while` body never runs — no tick, no work. When `true`, the tick advances every 60 seconds. Cancellation comes for free with the composable scope. Resume-from-background may show stale relative ages for up to 60 seconds before the next tick lands — acceptable.

Android: same five lines in the app's root composable in `apps/multiplatform/android/src/main/java/chat/simplex/app/MainActivity.kt` (or wherever the top-level Compose tree is rooted — match the equivalent of `DesktopApp.kt`'s `AppWindow`).

### Chat list

`common/src/commonMain/kotlin/chat/simplex/common/views/chatlist/ChatPreviewView.kt:404`:

```kotlin
val useRelative by remember { ChatController.appPrefs.relativeTimestamps.state }
val tick by timestampTick
val chatTs = chat.chatItems.lastOrNull()?.meta?.itemTs ?: chat.chatInfo.chatTs
val ts = remember(tick, useRelative, chatTs) {
  if (useRelative) getRelativeTimestampText(chatTs) else getTimestampText(chatTs)
}
ChatListTimestampView(ts)
```

The dispatch (`if useRelative ...`) is visible at the call site — a reader scanning `ChatPreviewView` sees both branches and knows which one runs.

`ContactRequestView.kt:22` and `ContactConnectionView.kt:23` get the same five-line pattern over their respective `Instant` source (`contactRequest.updatedAt` and `contactConnection.updatedAt`). Three near-identical call sites — extract a private helper only if it simplifies a real reader; otherwise the duplication names the surface at each site.

### Message metadata

`common/src/commonMain/kotlin/chat/simplex/common/views/chat/item/CIMetaView.kt`

`CIMetaText` is **unchanged in signature**. Its body already reads `meta.timestampText` at line 113; with the new pref-aware getter, that text is already correct for the current mode. The only addition is invalidation: `CIMetaView` observes the ticker and forces `CIMetaText` to re-derive on every minute:

```kotlin
val tick by timestampTick
key(tick) {
  CIMetaText(meta, /* existing args unchanged */)
}
```

`key(tick)` is enough — `meta.timestampText` re-reads the pref synchronously on every access, so a tick-triggered re-derivation picks up whatever the pref currently says.

`reserveSpaceForMeta` (line 118) is **also unchanged in signature**. Its only edit is the one-token swap at line 172 (`meta.timestampReserveText` instead of `meta.timestampText`), described under "Width-reservation worst case" above. The four callers — `CIRcvDecryptionError.kt:172, 204`, `CIGroupInvitationView.kt:119, 130`, `TextItemView.kt:131` — see no change.

### Date separators

`common/src/commonMain/kotlin/chat/simplex/common/views/chat/ChatView.kt:3020` (`DateSeparator`):

```kotlin
@Composable
private fun DateSeparator(date: Instant) {
  val useRelative by remember { ChatController.appPrefs.relativeTimestamps.state }
  val tick by timestampTick
  val text = remember(tick, useRelative, date) {
    if (useRelative) getRelativeDateText(date) else getTimestampDateText(date)
  }
  Text(text, /* existing modifier args unchanged */, ...)
}
```

`FloatingDate` at line 2853 only appears while scrolling and disappears after 1 second of stillness — every instance lives well under a tick. Replace its existing `getTimestampDateText(date)` call with a one-line conditional:

```kotlin
text = if (ChatController.appPrefs.relativeTimestamps.get()) getRelativeDateText(date)
       else getTimestampDateText(date)
```

No ticker observation, no `remember(tick, ...)`. The overlay re-derives on every scroll event, which is already several times more often than a minute, so the relative form stays accurate enough in practice.

### Date-separator decision logic

`ChatView.kt:3727` currently decides whether each item shows its per-item timestamp by comparing two formatted timestamp *strings*:

```kotlin
timestamp = largeGap || prevItem.meta.timestampText != chatItem.meta.timestampText,
```

That comparison was already fragile (it depended on `getTimestampText` rounding to minutes for visual stability); with `meta.timestampText` now pref-aware and time-varying, the comparison becomes actively ephemeral — same input data, different result every minute. Replace with explicit minute-floor numeric comparison:

```kotlin
timestamp = largeGap ||
  prevItem.meta.itemTs.epochSeconds / 60 != chatItem.meta.itemTs.epochSeconds / 60,
```

`itemTs.epochSeconds / 60` is the integer minute index in UTC — exactly the granularity the old string comparison was approximating. The decision now depends on the underlying data only, never on the format.

### Chat-event items — out of scope

Two views compose chat-event text ending in `chatItem.timestampText`:

- `CIFeaturePreferenceView.kt:40, 49` — feature-toggle event ("Disappearing messages enabled  5m ago").
- `CIMemberCreatedContactView.kt:48, 65` — group member-created-contact event.

With `meta.timestampText` pref-aware, they automatically display in relative form. We do **not** subscribe them to the ticker. They refresh whenever the chat naturally recomposes (scroll, new message, send). A user who stares at one for several minutes sees its age age slowly fall behind; this matches the spec's carve-out and saves the per-view observation wiring.

### Settings toggle

`common/src/desktopMain/kotlin/chat/simplex/common/views/usersettings/Appearance.desktop.kt`

There is no `PerformanceSection` today — file ends at line 152. Add a new section between `MinimizeToTraySection` and `AppToolbarsSection` (inserted in `AppearanceLayout` at the existing `SectionDividerSpaced()` boundary):

```kotlin
SectionDividerSpaced()
TimestampsSection()
```

And the section composable, placed alongside `MinimizeToTraySection` at line 95:

```kotlin
@Composable
private fun TimestampsSection() {
  SectionView {
    SettingsPreferenceItem(
      icon = null,
      stringResource(MR.strings.relative_timestamps),
      appPrefs.relativeTimestamps,
    )
  }
  SectionTextFooter(stringResource(MR.strings.relative_timestamps_desc))
}
```

Android: same toggle in `common/src/androidMain/kotlin/chat/simplex/common/views/usersettings/Appearance.android.kt`. Match the surrounding section idiom.

# iOS

All paths under `apps/ios/`.

## Foundation

### Preference

`Shared/Views/UserSettings/SettingsView.swift`

Add a constant near the existing `DEFAULT_*` block (around line 50):

```swift
let DEFAULT_RELATIVE_TIMESTAMPS = "relativeTimestamps"
```

Register the default in `appDefaults` (~line 88):

```swift
let appDefaults: [String: Any] = [
  // ... existing keys ...
  DEFAULT_RELATIVE_TIMESTAMPS: false,
]
```

`UserDefaults.standard`, not `groupDefaults` — this is local display logic, not shared with share/notification extensions.

### Strings

`en.lproj/Localizable.strings`:

```
/* Relative timestamps setting */
"Relative timestamps" = "Relative timestamps";
"Show timestamps as '2h5m ago' instead of '12:00'." = "Show timestamps as '2h5m ago' instead of '12:00'.";

/* Abbreviated form (chat list, message metadata) */
"<1m ago" = "<1m ago";
"%dm ago" = "%dm ago";
"%1$dh%2$dm ago" = "%1$dh%2$dm ago";
"%dd ago" = "%dd ago";
"%1$dy%2$dd ago" = "%1$dy%2$dd ago";

/* Full-word form (date separators) */
"Today" = "Today";
"Yesterday" = "Yesterday";
"%d days ago" = "%d days ago";
"1 year" = "1 year";
"%d years" = "%d years";
"1 day" = "1 day";
"%d days" = "%d days";
"%1$@ %2$@ ago" = "%1$@ %2$@ ago";
```

Format specifiers follow Apple's conventions (`%@` for `String`, `%d` for `Int`). Wording matches the multiplatform strings exactly.

### Ticker

`Shared/Model/RelativeTimestampTicker.swift` (new file):

```swift
import SwiftUI
import Combine

final class RelativeTimestampTicker: ObservableObject {
  static let shared = RelativeTimestampTicker()
  @Published var tick: Int = 0
  private var timer: Timer?

  func start() {
    guard timer == nil else { return }
    timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
      self?.tick &+= 1
    }
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }
}
```

One singleton, matching the codebase's pattern (`AppChatState.shared`, `AlertManager.shared`, `ChatModel.shared`). `@Published` invalidates every SwiftUI view that observes the object — no per-view scheduling.

## Formatters

`SimpleXChat/ChatTypes.swift`, immediately after `formatTimestampText` (~line 3807):

```swift
public func formatRelativeTimestamp(_ date: Date) -> String {
  let diff = Int(Date.now.timeIntervalSince(date))
  if diff < 60 { return NSLocalizedString("<1m ago", comment: "relative time") }
  let minutes = diff / 60
  if minutes < 60 {
    return String.localizedStringWithFormat(NSLocalizedString("%dm ago", comment: "relative time"), minutes)
  }
  let hours = minutes / 60
  if hours < 24 {
    return String.localizedStringWithFormat(NSLocalizedString("%1$dh%2$dm ago", comment: "relative time"),
                                            hours, minutes % 60)
  }
  let days = hours / 24
  if days < 365 {
    return String.localizedStringWithFormat(NSLocalizedString("%dd ago", comment: "relative time"), days)
  }
  return String.localizedStringWithFormat(NSLocalizedString("%1$dy%2$dd ago", comment: "relative time"),
                                          days / 365, days % 365)
}

public func formatRelativeDate(_ date: Date) -> String {
  let cal = Calendar.current
  let now = cal.startOfDay(for: .now)
  let then = cal.startOfDay(for: date)
  let daysDiff = cal.dateComponents([.day], from: then, to: now).day ?? 0
  if daysDiff <= 0 { return NSLocalizedString("Today", comment: "relative date") }
  if daysDiff == 1 { return NSLocalizedString("Yesterday", comment: "relative date") }
  if daysDiff < 365 {
    return String.localizedStringWithFormat(NSLocalizedString("%d days ago", comment: "relative date"), daysDiff)
  }
  let years = daysDiff / 365
  let days = daysDiff % 365
  let y = years == 1
    ? NSLocalizedString("1 year", comment: "relative date")
    : String.localizedStringWithFormat(NSLocalizedString("%d years", comment: "relative date"), years)
  let d = days == 1
    ? NSLocalizedString("1 day", comment: "relative date")
    : String.localizedStringWithFormat(NSLocalizedString("%d days", comment: "relative date"), days)
  return String.localizedStringWithFormat(NSLocalizedString("%1$@ %2$@ ago", comment: "compound relative date"),
                                          y, d)
}
```

`startOfDay` in the user's current calendar/timezone — same semantics as the multiplatform formatter's `toEpochDays()` in `TimeZone.currentSystemDefault()`. Future-clock guards collapse to `Today` / `<1m ago`.

### `CIMeta.timestampText` becomes pref-aware; `CIMeta.timestampReserveText` is added

`SimpleXChat/ChatTypes.swift:3724` (on `CIMeta`):

```swift
public var timestampText: Text {
  UserDefaults.standard.bool(forKey: DEFAULT_RELATIVE_TIMESTAMPS)
    ? Text(formatRelativeTimestamp(itemTs))
    : Text(formatTimestampMeta(itemTs))
}

public var timestampReserveText: Text {
  UserDefaults.standard.bool(forKey: DEFAULT_RELATIVE_TIMESTAMPS)
    ? Text(verbatim: "1y100d ago")
    : timestampText
}
```

`ChatItem.timestampText` is unchanged — it delegates to `meta.timestampText` and so picks up the relative form automatically.

`Text(verbatim:)` is used only on the worst-case literal pad (a string literal that SwiftUI would otherwise try to localize). The formatter results go through plain `Text(stringResult)` — matching the existing `formatTimestampMeta`-wrapping idiom; SwiftUI does not localize string variables.

Every previous reader of `meta.timestampText` / `chatItem.timestampText` is unchanged — they still write `meta.timestampText` and the new getter does the right thing. Callers do not learn about the pref.

## Wiring

### Ticker lifecycle

`Shared/ContentView.swift` (the app's true view root under `SimpleXApp.swift`):

```swift
@AppStorage(DEFAULT_RELATIVE_TIMESTAMPS) private var useRelative = false
@Environment(\.scenePhase) private var scenePhase
@StateObject private var ticker = RelativeTimestampTicker.shared
```

Inside the view body, on the root container:

```swift
.onAppear {
  if useRelative && scenePhase == .active { ticker.start() }
}
.onChange(of: useRelative) { on in
  on && scenePhase == .active ? ticker.start() : ticker.stop()
}
.onChange(of: scenePhase) { phase in
  phase == .active && useRelative ? ticker.start() : ticker.stop()
}
```

The `scenePhase` gate stops the `Timer` in `.background` and `.inactive` — no work while the app isn't visible. iOS already drains background timers aggressively, but the explicit stop avoids holding the runloop hostage for nothing. Resume-from-background may show stale relative ages for up to 60 seconds before the next scheduled tick lands — acceptable.

### Chat list

`Shared/Views/ChatList/ChatPreviewView.swift`, around line 48:

```swift
@AppStorage(DEFAULT_RELATIVE_TIMESTAMPS) private var useRelative = false
@ObservedObject private var ticker = RelativeTimestampTicker.shared

// In the body, replacing the existing call:
(useRelative
  ? Text(formatRelativeTimestamp(chatTs))
  : formatTimestampText(chatTs))
  .id(ticker.tick)
  .font(.subheadline)
  .frame(minWidth: 60, alignment: .trailing)
  ...
```

`@ObservedObject var ticker` invalidates the view whenever `ticker.tick` changes — the `.id(ticker.tick)` modifier guarantees a re-derivation of the `Text` itself, not just a layout invalidation. The frame `minWidth` rises to accommodate `1y100d ago` (≈80pt at `.subheadline`).

`ContactRequestView.swift:22` and `ContactConnectionView.swift:23` get the same six-line pattern.

### Message metadata

`Shared/Views/Chat/ChatItem/CIMetaView.swift`

`ciMetaText`'s signature is **unchanged**. Its body branches on the existing `colorMode` to pick the right accessor — display reads `meta.timestampText`, the width-reservation pass reads `meta.timestampReserveText`:

```swift
if showTimesamp {
  appendSpace()
  let ts = colorMode == .transparent ? meta.timestampReserveText : meta.timestampText
  r = r + colored(ts, resolved)
}
```

In absolute mode both accessors return `Text(formatTimestampMeta(itemTs))` — identical behavior. In relative mode, display renders the current relative form and the reservation pass renders a stable `Text(verbatim: "1y100d ago")` so the bubble doesn't reflow when the timestamp ticks over (`23h59m ago → 1d ago` would otherwise shrink five characters).

The callers of `ciMetaText` — `CIMetaView` (lines 32 normal, 47 transparent), `CIChatLinkHeader`, `MsgContentView.swift:134` — are **unchanged** because the signature is unchanged.

`CIMetaView` picks up the ticker to invalidate the display path each minute:

```swift
@ObservedObject private var ticker = RelativeTimestampTicker.shared

var body: some View {
  ciMetaText(meta, /* existing args unchanged */)
    .id(ticker.tick)  // forces re-derivation on tick
}
```

`meta.timestampText` re-reads `UserDefaults` synchronously on every access, so tick-driven re-derivation picks up the current pref value without an explicit `@AppStorage` here. The pref toggle itself drives recomposition through the `Appearance` toggle's own observers.

### Date separators

`Shared/Views/Chat/ChatView.swift:1312`:

```swift
private struct DateSeparator: View {
  let date: Date
  @AppStorage(DEFAULT_RELATIVE_TIMESTAMPS) private var useRelative = false
  @ObservedObject private var ticker = RelativeTimestampTicker.shared

  var body: some View {
    Group {
      if useRelative {
        Text(formatRelativeDate(date))
      } else {
        // existing absolute-form Text(...) unchanged
      }
    }
    .id(ticker.tick)
    .font(.callout)
    .fontWeight(.medium)
    .foregroundStyle(.secondary)
  }
}
```

No floating-date overlay on iOS — this is the only separator surface.

### Date-separator decision logic

`ChatView.swift:1729` currently compares formatted timestamp strings to decide whether each item shows its per-item timestamp:

```swift
timestamp: largeGap || formatTimestampMeta(chatItem.meta.itemTs) != formatTimestampMeta(prevItem.meta.itemTs),
```

In relative mode this becomes ephemeral — the same items produce different comparison results minute-to-minute. Replace with minute-floor numeric comparison:

```swift
timestamp: largeGap ||
  Int(chatItem.meta.itemTs.timeIntervalSince1970 / 60) !=
  Int(prevItem.meta.itemTs.timeIntervalSince1970 / 60),
```

Preserves the existing "same HH:MM → suppress timestamp" semantics (the integer division is the minute floor) while removing the dependency on string formatting.

### Chat-event items — out of scope

Five views compose chat-event text ending in `chatItem.timestampText`:

- `CIFeaturePreferenceView.swift:54`
- `CIMemberCreatedContactView.swift:51`
- `MarkedDeletedItemView.swift:23` (deletion banner)
- `ChatItemView.swift:207, 286` (chat-event-text helpers)
- `CIMetaView.swift:29` (deleted-content fallback — a separate code path from the `ciMetaText` call)

With `meta.timestampText` pref-aware, they automatically display in relative form. We do **not** subscribe them to the ticker. They refresh whenever the chat naturally recomposes (scroll, new message, send). Per the spec's carve-out, the per-minute promise covers the metadata row, the chat list, and the date separator — event banners get the relative format but not the minute tick.

### Settings toggle

`Shared/Views/UserSettings/AppearanceSettings.swift`

Add at the top of the existing `AppearanceSettings` view's property list (~line 37):

```swift
@AppStorage(DEFAULT_RELATIVE_TIMESTAMPS) private var relativeTimestamps = false
```

Insert a new section between "Chat list" (line 71) and "Themes" (line 81):

```swift
Section {
  Toggle("Relative timestamps", isOn: $relativeTimestamps)
} footer: {
  Text("Show timestamps as '2h5m ago' instead of '12:00'.")
}
```

iOS section footers render the description in muted small text by convention — no separate `SectionTextFooter` needed.

# Implementation order

The two codebases ship independently; within each, the steps are additive (no transient state where existing behavior breaks), so the whole change can land in one commit per codebase.

### Multiplatform (Android + Desktop on Linux, macOS, Windows)

1. Preference constant + property (`SimpleXAPI.kt`).
2. `AppSettings` gains the `relativeTimestamps: Boolean?` field plus the five line-additions to `defaults`, `current`, `prepareForExport`, `importIntoApp` (`SimpleXAPI.kt:8038-8237`).
3. Strings (`MR/base/strings.xml`).
4. Top-level tick state + `WORST_CASE_RELATIVE_TIMESTAMP` constant (`ChatModel.kt`).
5. Formatters (`ChatModel.kt`) — `getRelativeTimestampText`, `getRelativeDateText`.
6. `CIMeta.timestampText` becomes pref-aware; new sibling `CIMeta.timestampReserveText` (`ChatModel.kt:3406`).
7. `reserveSpaceForMeta` line 172 swaps `meta.timestampText` → `meta.timestampReserveText`. No signature change. No caller changes.
8. Date-separator decision logic in `ChatView.kt:3727` switches to minute-floor numeric comparison.
9. Ticker lifecycle in `DesktopApp.kt` (one JVM binary covers Linux/macOS/Windows — no per-OS work) and the Android root composable.
10. `CIMetaView` wraps the `CIMetaText` call in `key(tick) { ... }` to invalidate per-minute. `CIMetaText` signature unchanged.
11. Call sites — chat list (`ChatPreviewView.kt`), pending rows (`ContactRequestView.kt`, `ContactConnectionView.kt`).
12. Call sites — `DateSeparator` (with ticker subscription), `FloatingDate` (per-call-site conditional only, no ticker).
13. Settings toggle in `Appearance.desktop.kt` + `Appearance.android.kt`.

### iOS

1. Preference key + default (`SettingsView.swift`, `appDefaults`).
2. `AppSettings` gains the `relativeTimestamps: Bool?` field plus the two line-additions to `defaults` and `prepareForExport` in `AppAPITypes.swift:2118`, and the two line-additions to `importIntoApp()` and `current` in `Shared/Views/UserSettings/AppSettings.swift`.
3. Strings (`en.lproj/Localizable.strings`).
4. `RelativeTimestampTicker` singleton (new file).
5. Formatters in `ChatTypes.swift` — `formatRelativeTimestamp`, `formatRelativeDate`.
6. `CIMeta.timestampText` becomes pref-aware; new sibling `CIMeta.timestampReserveText` (`ChatTypes.swift:3724`).
7. `ciMetaText` body branches on `colorMode == .transparent` to read `timestampReserveText` vs `timestampText`. Signature unchanged. No caller changes.
8. Date-separator decision logic in `ChatView.swift:1729` switches to minute-floor numeric comparison.
9. Ticker lifecycle in `ContentView.swift` (`.onAppear`, `.onChange(of: useRelative)`, `.onChange(of: scenePhase)`).
10. `CIMetaView` adds `@ObservedObject ticker` and `.id(ticker.tick)` on the `ciMetaText` result.
11. Call sites — `ChatPreviewView.swift`, `ContactRequestView.swift`, `ContactConnectionView.swift`.
12. Call sites — `DateSeparator` in `ChatView.swift` (no floating-date overlay on iOS).
13. Settings toggle in `AppearanceSettings.swift`.

# Edge cases handled

- **Future timestamps** — multiplatform `diff.isNegative()` / `daysDiff < 0`; iOS `daysDiff <= 0` / `diff < 60` in their respective formatters. Both collapse to `<1m ago` / `Today` — never a negative duration.
- **Year boundary at 365 days** — explicit `days < 365` / `>= 365` branches in both codebases; no calendar-year math; spec accepts the rounding.
- **Day-boundary semantics for separators** — multiplatform `toEpochDays()` in `TimeZone.currentSystemDefault()`; iOS `Calendar.current.startOfDay(for:)`. Both honor the user's current timezone and the existing separator's grouping rule.
- **Pref toggle during a running session** — multiplatform `LaunchedEffect(useRelative)` re-keys; iOS `.onChange(of: useRelative)` starts/stops the ticker. The Appearance toggle's own observers drive recomposition of consumers; `meta.timestampText` re-reads the pref synchronously each access, so the next recomposition picks up the new format.
- **Background app** — multiplatform Compose stops recomposing in the background; on iOS the `scenePhase != .active` branch invalidates the `Timer`. Neither platform burns CPU while the app is hidden.
- **Resume from background** — visible relative ages may be stale by up to 60 seconds after resume. The next scheduled tick reconciles them. Accepted as a small UX cost in exchange for not adding force-tick plumbing.
- **Width and display agreement** — display reads `meta.timestampText`; width reservation reads `meta.timestampReserveText`. Both are pref-aware, deterministic per mode. In absolute mode the two accessors return the same value (so existing behavior is preserved). In relative mode reservation returns a stable 10-character pad (`1y100d ago`) and display returns the current relative form; the bubble layout never reflows on minute boundaries.
- **Per-item timestamp decision** — `ChatView.kt:3727` and `ChatView.swift:1729` compare minute-floor `epochSeconds / 60` on the underlying `Instant`/`Date`, not formatted strings. The decision is now a function of the data alone, never of the current display mode.
- **Detail / export surfaces** — `localTimestamp(...)` and `SimpleDateFormat` callers (`ChatItemInfoView`, `ServersSummaryView`, archive filenames, `MigrateToDevice`, `DatabaseView`) are deliberately not touched. Clipboard, file, and developer surfaces keep absolute timestamps regardless of the pref.
- **Chat-event items render relative but don't tick** — feature-toggle banners, member-created-contact, marked-deleted, and chat-event-text helpers automatically pick up the relative form through `meta.timestampText` but are not subscribed to the per-minute ticker. They refresh on natural recomposition (scroll, send, new message). Spec acknowledges this.
- **Pref travels with database export/import** — `AppSettings.relativeTimestamps` is included in the serialized bundle that the export saves into the SQL database via `apiSaveAppSettings(current.prepareForExport())`. On import, `importIntoApp()` writes it back into the local `SharedPreference` / `UserDefaults`. The pref is restored across same-device round-trips, cross-device migrations, and reinstall-then-import. Archives written by pre-feature app versions have no `relativeTimestamps` field; `importIntoApp` skips the missing field and the local default applies (same behavior as every other `AppSettings` member).

# Verification

Run each scenario on Android, iOS, and Desktop (verify at least one of Linux/macOS/Windows; the Desktop binary is one codebase but the OS-level taskbar/window rendering varies enough to be worth eyeballing).

1. **Toggle on in Appearance** — chat list, open chat metadata, and any visible date separator switch to relative form within one frame. Chat-event banners (feature toggles, member-created-contact, marked-deleted) also switch — they read `meta.timestampText` and that getter is now pref-aware.
2. **One-minute advance on the ticker surfaces** — wait 60+ seconds with a relative timestamp visible: chat list, message metadata, and date separator each advance by exactly one minute. Chat-event banners do **not** advance on the minute tick by design — they reflect the relative form but refresh only on natural recomposition.
3. **Toggle off** — absolute forms return; the coroutine loop (multiplatform) and `Timer` (iOS) stop within one tick (60s max).
4. **>1-year-old message** — separator reads `1 year 0 days ago`; message metadata reads `1y0d ago`.
5. **<1-minute-old message** — reads `<1m ago` (never `0m ago`).
6. **Future timestamp** — force clock skew or send from a peer with a fast clock: displays `<1m ago` / `Today`, never a negative value.
7. **Layout stability under ticking** — open a long-text bubble with a timestamp at `23h59m ago`; wait for it to flip to `1d ago`. The reserved column stays 10 chars wide; bubble width and wrapping point do not shift. Repeat at `59m ago → 1h0m ago` and `9m ago → 10m ago`.
8. **Per-item timestamp decision is stable across ticks** — two messages 30 seconds apart should show the per-item timestamp on only the first (largeGap and minute floors agree). Two messages 90 seconds apart should show both. Both behaviors should hold identically every minute as ages advance.
9. **Background CPU when pref is off** — no work from this feature (multiplatform: `LaunchedEffect(false)` body never executes; iOS: `Timer` is nil).
10. **Background CPU when pref is on but app is hidden** — multiplatform: Compose stops recomposing but the coroutine continues firing every 60s into a state nobody reads (cheap); iOS: `scenePhase` gate invalidates the `Timer`. Both acceptable.
11. **Per-platform persistence** — toggle on/off, kill the app, relaunch: the setting is restored. Confirm independently on each platform.
12. **Detail-view and exports stay absolute** — long-press a message, open its detail view: every timestamp there is wall-clock. Copy "message info" to the clipboard: pasted text has absolute timestamps. Export a chat archive: filename has a wall-clock prefix. None of these change with the pref.
13. **Pref round-trip via database export/import (same device)** — toggle on, export, import the just-exported archive. The setting is still on. Toggle off, repeat: the setting is still off. The pref survives because it is part of `AppSettings`, which is saved into the database before export and restored on next boot after import (via `shouldImportAppSettings`).
14. **Pref travels cross-device** — on device A toggle on and export. Move the archive to device B (or simulate via fresh-install + import on the same hardware). After import + restart, the setting on device B is on, without re-toggling. Then on device A toggle off and re-export; importing on B turns it off. Confirm same behavior Android → iOS and Desktop → phone (the `AppSettings` JSON schema is shared).
15. **Reinstall + import restores the pref** — toggle on, uninstall, reinstall, import the archive: the setting is on after the first boot following import. (Distinct from "Reinstall without import" — that lands on the default `false`, which matches the behavior of `oneHandUI` and every other `AppSettings` member.)
16. **Backwards-compatible import** — import an archive produced by a pre-feature app version: no error, no UI flash, the local default `false` remains. The missing field is silently skipped by `importIntoApp`.

## SwiftUI previews and screenshot tests

`@Preview` composables and SwiftUI `*_Previews` blocks construct sample `ChatItem`s with `Clock.System.now()` / `Date.now`. In relative mode they all render `<1m ago`. Existing previews continue to work; any *new* golden-screenshot test that depends on a stable timestamp must either freeze the clock or filter the timestamp column out of the comparison, because relative output is intrinsically time-dependent.
