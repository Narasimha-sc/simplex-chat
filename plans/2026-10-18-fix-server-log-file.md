# CLI: the --log-file log file is never created in WebSockets server mode (-p)

Fixes #7113.

## Problem

With `simplex-chat -p 5225 --log-file a.log`, `a.log` is never created, with or without a connected client.

## Cause

`--log-file` was added in #1957 to the terminal output loop only: in `runTerminalOutput` (`Terminal/Output.hs`), each error and `logEventToFile` event is appended to the file in place of being printed. With `-p`, the WebSockets server (`apps/simplex-chat/Server.hs`) is run by `simplexChatCLI'` (`Terminal/Main.hs`) in place of the terminal, and `--log-file` is not read by the server code.

## Fix

In the `-p` branch of `simplexChatCLI'`, when `--log-file` is set, `ChatHooks.eventHook` is set by `addLogFileHook` in the config passed to the server. The core calls the hook in `toView_` for each local event before the event is queued.

Hook mechanics:
- the `eventHook` of the passed config, when set, is called first, and its result is logged and returned;
- errors and `logEventToFile` events are written, formatted by `serializeChatError` / `serializeChatResponse` with the local current user (`currentUser`);
- appends are serialised by an `MVar` lock;
- on a failed write, `log-file write error: …` is printed, and the server continues.

## Scope

- `src/Simplex/Chat/Terminal/Main.hs`: `simplexChatCLI'` and `addLogFileHook`.
- CLI only: `simplex-chat` executable (the directory and badge services pass `Nothing` as the server function).
- Terminal mode, `-e` and `--headless` are unchanged.
- Events of a remote host controlled by the server (`pollEvents`, `Remote.hs`) are written to `outputQ` without `toView_` and are not logged.
- While a remote controller session is connected (`RCSessionConnected`), errors and `allowRemoteEvent` events are written by `toView_` to `remoteOutputQ`; they are logged by the hook and absent from the terminal mode file.
