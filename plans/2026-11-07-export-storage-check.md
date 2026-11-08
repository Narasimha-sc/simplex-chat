# Export and migration: warn when free space is short

## Problem

"Export database" and "Migrate to another device" start without checking free space. On a nearly full device the export fails or fills the disk.

## Cause

The core export copies both databases, the files and the wallpapers to a temporary folder, then writes the archive of that copy (`exportArchive`, `Archive.hs`). For a migration upload, the XFTP agent then writes an encrypted copy of the archive into the migration folder. About twice the data size is needed, and neither app compares it with free space.

## Fix

- Before "Export database" and before archiving for migration, the data size (`exportDataBytes`) is compared with free space. If short, "You may not have enough storage" shows the space needed and the space available, with Continue and Cancel. On Continue the step proceeds as before; on Cancel it is not started (migration stays at or returns to "Archive and upload").
- Android, desktop: with `exportStorageShortfall(exportFreeBytes, archiveFreeBytes, dataBytes)` in `DatabaseView.kt`, twice the data size is required free in the archive folder (the export folder, or `migration_temp_files` for migration) and the data size in the export folder. `confirmExportStorage` is called on the "Export database" click before the chat is stopped, and on the "Archive and upload" click before the state is set to "Archiving database".
- iOS: with `exportStorageShortfall`, twice the data size is required in `volumeAvailableCapacityForImportantUsage` of the documents volume.
- Strings: `not_enough_storage_title`, `not_enough_storage_desc`.

Android, desktop:

```mermaid
flowchart LR
  E["Export database click"] --> C1{"storage short?"}
  C1 -- no --> S["stop chat, export"]
  C1 -- yes --> W1["You may not have enough storage"]
  W1 -- Continue --> S
  W1 -- Cancel --> R["chat keeps running"]
  A["Archive and upload click"] --> C2{"storage short?"}
  C2 -- no --> AR["Archiving database"]
  C2 -- yes --> W2["You may not have enough storage"]
  W2 -- Continue --> AR
  W2 -- Cancel --> U["Archive and upload"]
```

iOS:

```mermaid
flowchart LR
  E["Export database tap"] --> S["stop chat"] --> C1{"storage short?"}
  C1 -- no --> X["export"]
  C1 -- yes --> W1["You may not have enough storage"]
  W1 -- Continue --> X
  W1 -- Cancel --> P["chat stays stopped"]
  A["Archiving database"] --> C2{"storage short?"}
  C2 -- no --> X2["archive and upload"]
  C2 -- yes --> W2["You may not have enough storage"]
  W2 -- Continue --> X2
  W2 -- Cancel --> U["Archive and upload"]
```

## Scope

- Android, desktop: `DatabaseView.kt`, `MigrateFromDevice.kt`, `strings.xml`.
- iOS: `DatabaseView.swift`, `MigrateFromDevice.swift`.
- "Migrate here" and "Import database" are unchanged.
