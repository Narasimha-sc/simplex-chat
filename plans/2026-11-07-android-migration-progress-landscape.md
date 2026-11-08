# Android: migration progress ring and QR code do not fit the screen in landscape

## Problem

With the migration screens kept in landscape (`2026-10-18-android-orientation-lock-recreate.md`):

- the upload and download progress ring of migration is about two screens tall, and its percentage is off screen until the user scrolls;
- the QR code of the uploaded archive link is taller than the visible area on a phone, and the other device cannot scan it.

## Cause

- `LargeProgressView` (`MigrateFromDevice.kt`, used by `UploadProgressView` and `DownloadProgressView`) sizes the ring to the window width on Android.
- `LinkShownView` (`MigrateFromDevice.kt`) shows `SimpleXLinkQRCode`, which is sized to the section width minus its padding, up to 400dp.

## Fix

`landscapeWindowBottomPx()` returns, in landscape on Android, the window height minus the bottom bars (the navigation bar, plus the app bar with the one-hand UI); elsewhere it returns null.

In landscape on Android:

- `LargeProgressView` sizes the ring to the height between the top of its box and that bottom, minus the padding, at least 120dp. The top is measured with `onGloballyPositioned` plus the scroll offset. The box fills the width instead of the whole size. The percentage and byte count are scaled by ring size / 300dp, between 0.4 and 1.
- `LinkShownView` limits the QR code width to the height between `topPaddingToContent(false)` and that bottom, plus the padding of `SimpleXLinkQRCode`, and centres it.

## Scope

- Portrait Android and desktop keep their sizes.
- Landscape is `windowOrientation() == WindowOrientation.LANDSCAPE`.
