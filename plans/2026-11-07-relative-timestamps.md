# Relative timestamps

## Problem

The chat list and the messages show only clock times and dates (`12:00`, `02/01`). A reader works out the age of a message from the current time.

## Cause

The app formats these times only with `getTimestampText`, which returns a clock time or a date.

## Fix

- Preference `relativeTimestamps` (key `RelativeTimestamps`, off by default), toggle "Relative timestamps" in its own Appearance section, before the font scale section, on Android and desktop.
- `getRelativeTimestampText(t, now)`:

  | Age | Text |
  |---|---|
  | under 1 minute, or in the future | `just now` |
  | under 1 hour | `5m ago` |
  | under 1 day | `2h5m ago` |
  | under 365 days | `182d ago` |
  | 365 days or more | `1y100d ago` |

- `relativeTimestampsNow`: one `Instant` state. While the preference is on, `MainScreen` sets it every second to the current time truncated to the minute; the state changes once per minute, and within a second after the device wakes from sleep.
- `chatTimestampText(t, shortFormat)` reads the preference state and `relativeTimestampsNow`: an age when on, `getTimestampText` when off. A composition that shows a time is recomposed on each change of either state.
- `chatTimestampText` replaces `getTimestampText` in `CIMeta.timestampText` (message and event times, and the space reserved for the time in a bubble) and in the chat-list rows (`ChatPreviewView`, `ContactRequestView`, `ContactConnectionView`).
- `getItemSeparation` compares the clock times of adjacent items (`getTimestampText(itemTs, true)`).
- `spec/`: the line links to `AppScreen`, `MainScreen`, `PreviewInEitherLayout` and `ChatLayoutRow` follow their shifted lines.

```mermaid
flowchart LR
  P[relativeTimestamps state] --> C[chatTimestampText]
  P -->|on| M
  N[relativeTimestampsNow state] --> C
  M[MainScreen loop, 1 s, minute value] --> N
  G[getTimestampText, clock time] --> S[getItemSeparation]
  C --> T[CIMeta.timestampText]
  C --> L[chat-list rows]
  T --> V[CIMetaView time]
  T --> R[reserved space in the bubble]
  T --> E[event times]
```

## Scope

- Android and desktop (`apps/multiplatform`). iOS is unchanged.
- Unchanged: date separators, the floating date, message info, share text, server statistics, badge pages, file expiry texts.
- The preference is local to the device; it is absent from the exported app settings.
