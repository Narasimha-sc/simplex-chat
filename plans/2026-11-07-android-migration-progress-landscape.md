# Android: migration progress ring is two screens tall in landscape

## Problem

With the migration screens kept in landscape (`2026-10-18-android-orientation-lock-recreate.md`), the upload and download progress ring of migration is about two screens tall, and its percentage is off screen until the user scrolls.

## Cause

`LargeProgressView` (`MigrateFromDevice.kt`, used by `UploadProgressView` and `DownloadProgressView`) sizes the ring to the window width on Android.

## Fix

In landscape on Android, `LargeProgressView`:

- sizes the ring to the window height below the top of its box, minus the bottom bars (the navigation bar, plus the app bar with the one-hand UI) and the padding, at least 120dp; the top is measured with `onGloballyPositioned` plus the scroll offset, so it does not change with scrolling;
- fills the width instead of the whole size, so the ring is not centred lower;
- scales the percentage and byte count by ring size / 300dp, between 0.4 and 1, so they stay inside the ring.

## Scope

- Portrait Android and desktop keep their sizes.
- Landscape is `windowWidth() > windowHeight()`.
