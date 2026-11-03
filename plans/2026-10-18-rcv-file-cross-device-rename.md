# Received files stuck when the temporary folder is on another file system

## Problem

Receiving a file over XFTP never completes when the chat's temporary folder and the folder the file is saved to are on different file systems.

Typical setups:

- CLI and bots with default folders: the temporary folder is the system temporary directory (`/tmp`, a tmpfs on Fedora, Arch and others), and files are saved to `~/Downloads` when that folder exists. This includes a CLI used as a remote host for desktop.
- CLI with `/fr N <path>`, `/_download` or `--files-folder` / `--temp-folder` pointing to different file systems.
- Desktop whose `simplex_v1_files` folder is a symlink or mount point on another disk.

The desktop and mobile apps with default folders are not affected: desktop sets both folders inside its data folder (`coreTmpDir` and `filesDir` in `Files.desktop.kt`), Android in `filesDir`, iOS under one app directory.

## Cause

An XFTP receive finishes by moving a file from the temporary folder to the target path with `renameFile`. A rename across file systems fails: with `EXDEV` on Linux and macOS, and with `ERROR_NOT_SAME_DEVICE` on Windows, where `renameFile` calls `MoveFileEx` without `MOVEFILE_COPY_ALLOWED`.

The agent downloads and decrypts the file into `xftp.decrypted` in its work folder `<temp>/<ts>_rcv.xftp`, sends `RFDONE`, and then marks the download complete, whatever the result of processing `RFDONE`. The chat renames the file to the target path. When the rename fails, the error is shown and `RFDONE` is not sent again. A received chat item stays at "receiving" with 100% progress, and the destination contains the empty placeholder file created when the file was accepted; a `/_download` never reports completion. Two days after the download started, the agent's cleanup deletes its work folder, which contains the only complete copy.

## Scope

All renames in the chat core and the simplexmq client code were checked:

| Site | From → to | Affected |
|---|---|---|
| `Subscriber.hs`, `RFDONE` | agent work folder (temporary folder) → files folder, `/fr` path or `/_download` path | yes, fixed |
| `Internal.hs`, `appendFileChunk` (inline receive with local encryption) | chat temporary folder → files folder or `/fr` path | yes, not changed: no sender in this code base produces inline user files (`xftpFileInvitation` and `createSndFileTransferXFTP` set `fileInline = Nothing`), so only a modified client reaches it |
| `Remote.hs`, `storeRemoteFile` | chat temporary folder → remote hosts folder (controller side) | yes, on the send side when host-file encryption is on (for example, with a symlinked `remote_hosts` folder); separate PR |
| `Web.hs`, `Archive.hs` | within one folder | no |
| simplexmq client (agent, XFTP send and receive) | no renames | no |

## Change

When the rename fails, copy the file instead: in `RFDONE`, `renameFile xftpPath fsTargetPath` falls back to `copyFile`. The source is not removed at this call site: it is in the agent's work folder. `agentXFTPDeleteRcvFile`, called after the file status is updated, deletes that folder or, if the agent has not yet marked the download complete, marks the download for the agent's periodic cleanup.

`copyFile` writes to a temporary file in the destination folder and renames it over the destination. When the copy fails with an exception (for example, a full disk), that temporary file is removed and the destination is unchanged.

## Options considered

1. **Copy when the rename fails (this change).** One call site; receives where the rename succeeds are unchanged.
2. **Copy only on the cross-device error.** Requires an IO-level catch and new imports, there is no portable `IOErrorType` for `EXDEV` (Windows reports `ERROR_NOT_SAME_DEVICE`), and it does not complete receives after other rename failures that a copy can recover from.
3. **Write directly to the files folder.** The agent would require a target path from the chat (a simplexmq API change).

## Limitations

- On a cross-file-system receive, the copy runs in `agentSubscriber`, which processes agent events one at a time, so other events are delayed for the duration of the copy. For an XFTP file received in a contact or group chat, the copy also runs under that chat's lock, so commands for that chat wait as well. Measured copy times across file systems are 0.06 s to about 20 s for 100 MB to 700 MB, depending on the disk. The XFTP file size limit is 1 GB by default, 2 GB with a supporter badge and 5 GB with a legend badge; the measured copy times cover only up to 700 MB, so the stall for 2 GB and 5 GB files is extrapolated (INFERENCE). This delay is accepted.
- If the process stops during the copy, the item stays at "receiving". When the process stops without running exception handlers (a crash, a forced kill), a `.copyFile*.tmp` file remains in the destination folder. With `renameFile` this interval was negligible.
- If the copy fails, the item stays at "receiving", as before for any rename failure, and the error shown is the copy error; the rename error is not shown or logged.
- If processing `RFDONE` fails after a successful copy (for example, a database error), `agentXFTPDeleteRcvFile` is not called, and the source file in the agent's work folder remains until the agent deletes the download.
