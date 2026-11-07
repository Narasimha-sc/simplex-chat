# Export and migration: warn when free space is short

## Problem

"Export database" and "Migrate to another device" start without checking free space. On a nearly full device the export fails or fills the disk.

## Cause

The core export copies both databases and the files to a temporary folder, then writes the archive of that copy (`exportArchive`, `Archive.hs`). A migration upload then writes an encrypted copy of the archive into the migration folder. About twice the data size is needed, and neither app compares it with free space.

## Fix

- Before "Export database" and before archiving for migration, the data size (`exportDataBytes`) is compared with free space. If short, "You may not have enough storage" shows the space needed and the space available, with Continue and Cancel. Continue proceeds as before; Cancel stops (migration returns to "Archive and upload").
- Android, desktop: `exportStorageShortfall(exportDir, archiveDir, dataBytes)` in `DatabaseView.kt` requires twice the data size in the archive folder (the export folder, or `migration_temp_files` for migration) and the data size in the export folder. On desktop the two folders can be on different volumes. `confirmExportStorage` shows the alert and awaits the answer.
- iOS: `exportStorageShortfall` requires twice the data size in `volumeAvailableCapacityForImportantUsage` of the documents volume. The alert is a case of each screen's own alert enum, and Continue starts the export from it.
- Strings: `not_enough_storage_title`, `not_enough_storage_desc`.

## Scope

- Android, desktop: `DatabaseView.kt`, `MigrateFromDevice.kt`, `strings.xml`.
- iOS: `DatabaseView.swift`, `MigrateFromDevice.swift`.
- "Migrate here" and "Import database" are unchanged.
