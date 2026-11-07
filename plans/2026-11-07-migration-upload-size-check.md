# Migration: refuse data over the XFTP upload limit before exporting

Part 1 of #7696.

## Problem

"Migrate to another device" exports the whole database and files, then fails at the upload with "Error uploading the archive" when the archive is over 5 GB. On Android and desktop the alert text is `chat.simplex.common.model.API$Error@…`. "Repeat upload" fails again, and the archive stays in the migration folder until the screen is closed.

## Cause

`APIUploadStandaloneFile` rejects a file over `maxFileSizeHard` (5 GiB, simplexmq `Simplex.FileTransfer.Description`) with `CEFileSize`. The migration screens of both apps export and upload without checking that limit.

## Fix

- `MAX_FILE_SIZE_XFTP_HARD` = 5 GiB in Kotlin `Utils.kt` and Swift `FileUtils.swift`, separate from the badge tier `MAX_FILE_SIZE_XFTP_LEGEND`. Kotlin compares with `exceedsXftpUploadLimit`, the same `>` as the core.
- Before archiving, `MigrateFromDevice` estimates the data size: the files and wallpapers folders (top-level files) plus both databases (`exportDataBytes`); Kotlin in `confirmArchiving` on the "Archive and upload" click, Swift in `exportArchive`. Over the limit, "Database is too large" shows the size and the limit, and the state stays at or returns to "Archive and upload".
- After archiving, the archive size is compared with the limit before the "exported with errors" alert and the upload. Over the limit, the archive is deleted and the same alert is shown.
- Strings: `migrate_from_device_database_too_large_title`, `migrate_from_device_database_too_large_desc`.

## Scope

- Android, desktop: `MigrateFromDevice.kt`, `DatabaseView.kt` (`exportDataBytes`), `Utils.kt`, `strings.xml`.
- iOS: `MigrateFromDevice.swift`, `FileUtils.swift`.
