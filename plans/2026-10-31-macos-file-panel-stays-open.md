# macOS: an Open or Save panel stays on screen after its request ended

## Problem

On macOS desktop, an Open or Save panel is left on screen after the view that requested it has closed.
Examples:
- the QR code Save panel of a one-time invitation, when the peer connects and the invitation view closes;
- a QR code Save panel in any modal, when a desktop notification click closes all modals.

On master, Save or Cancel in that panel writes nothing, and later requests of the same kind open no panel until restart.
With https://github.com/simplex-chat/simplex-chat/pull/7961, Save or Cancel in that panel writes nothing, and a later request opens a second panel while the first one stays open.

## Cause

- A request is ended by cancellation of its awaiting coroutine (`rememberCoroutineScope` in `QRCode`, `QRCode.kt`).
- With PR 7961, `request` is cleared in `finally` (`DialogState.awaitResult`, `DesktopApp.kt`), the chooser inside `key(request)` leaves composition, and Compose `AwtWindow` calls `FileDialog.dispose()`.
- In JDK 17 (the macOS release bundles Amazon Corretto 17), `CFileDialog.dispose()` only unregisters the peer, and `CFileDialog.setVisible(false)` is empty; the native panel keeps running its modal loop.
- The later panel result is stored only in the disposed `FileDialog` by `CFileDialog.Task`.
- A closing `dispose()` exists only in JDK mainline (JDK-7186009).

## Fix

Depends on PR 7961.

`FileDialogAwt` (`DefaultDialog.desktop.kt`), `dispose`:
- When the `FileDialog` is visible, `cancelMacFilePanel()` is called before `FileDialog.dispose()`.

`cancelMacFilePanel()`, private, same file, through JNA (already a dependency):
- A callback is queued on the AppKit main thread with `dispatch_async_f` on the main dispatch queue (`_dispatch_main_q` of libSystem).
- In the callback, `[NSApp modalWindow]` is read; when it is an `NSSavePanel` (`isKindOfClass:`, `NSOpenPanel` included), `[NSApp stopModalWithCode:NSModalResponseCancel]` is sent.
- `objc_msgSend` is declared with fixed argument lists.
- The callback object is held in a top-level property.

The panel then returns as cancelled: `CFileDialog.Task` stores no files and disposes the `FileDialog` again.
