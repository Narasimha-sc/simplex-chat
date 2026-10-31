# macOS: a clicked QR code image is not saved

## Problem

On macOS desktop, a click on any QR code opens the native Save panel.
After Save, no image file is created at the chosen location.
The panel closes, and the app shows neither a toast nor an alert.
For a one-time invitation, the invitation is not marked as used, so leaving the view shows "Keep unused invitation?".

## Cause

- On click, `saveTempImageUncompressed(image, true)` is called (`QRCode.kt`, `QRCode`).
- In `saveTempImageUncompressed` (`Utils.desktop.kt`), the save slot is awaited without a `filename`.
- On macOS, `FileDialogChooser` (`DefaultDialog.desktop.kt`) selects `FileDialogAwt`: an AWT `FileDialog` in `SAVE` mode.
- The JDK 17 macOS peer `CFileDialog` runs an `NSSavePanel` and returns the panel URL (chosen folder plus typed name) as the selected file.
- `File.separator` and a generated `IMG_<time>.png` name are appended to that file path, as to a folder.
- `outputStream()` on that path throws; the exception is caught, printed to stdout by `Log.e`, and `null` is returned.
- On `null`, `shareFile` and `onShare` are skipped in `QRCode`.

## Fix

Depends on https://github.com/simplex-chat/simplex-chat/pull/7961 (`shareFile` after the save only on Android; `file_saved` toast after the write).

`saveTempImageUncompressed` (`Utils.desktop.kt`), on macOS only (`desktopPlatform.isMac()`):
- `ext` is computed before the dialog.
- The save slot is awaited with `DialogParams(filename = generateNewFileName("IMG", ext, tmpDir))`.
- The image is written to the returned file itself.

Linux and Windows: unchanged (no filename; a new file in the returned folder).
