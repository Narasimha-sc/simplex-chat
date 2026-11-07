# CLI: --log-file never creates the log file in WebSockets server mode (-p)

Fixes #7113.

## Problem

`simplex-chat -p 5225 --log-file a.log` never creates `a.log`, with or without a connected client. Without `-p` the CLI appends errors and service events (`logEventToFile`, `Controller.hs`) to the file.

## Cause

`--log-file` was added in #1957 to the terminal output loop only: `runTerminalOutput` (`Terminal/Output.hs`) appends each error and `logEventToFile` event to the file instead of printing it. With `-p`, `simplexChatCLI'` (`Terminal/Main.hs`) runs the WebSockets server (`apps/simplex-chat/Server.hs`) in place of the terminal, and the server code does not read `--log-file`.

## Fix

In the `-p` branch of `simplexChatCLI'`, when `--log-file` is set, `addLogFileHook` sets `ChatHooks.eventHook` in the config passed to the server. The core calls the hook in `toView_` for each local event before it is queued, so events are written whether or not a client is connected; the hook returns the event unchanged.

The hook:
- writes errors and `logEventToFile` events, formatted by `serializeChatError` / `serializeChatResponse` with the current user, as terminal mode writes them;
- appends under an `MVar` lock, because the core calls it from several threads and GHC allows one write handle per file in a process;
- prints `log-file write error: …` on a failed write, and the server continues.

## Scope

- `src/Simplex/Chat/Terminal/Main.hs`: `simplexChatCLI'` and `addLogFileHook`.
- CLI only: `-p` is parsed by `simplexChatCLI'`, which only the `simplex-chat` executable calls with a server; the directory and badge services pass `Nothing`, and the apps do not use this module.
- Terminal mode, `-e` and `--headless` are unchanged.
- Events of a remote host controlled by the server (`pollEvents`, `Remote.hs`) are written to `outputQ` without `toView_` and are not logged.
