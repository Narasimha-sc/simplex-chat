# TCP_USER_TIMEOUT switch: platforms

## Problem

The switch is shown on iOS, macOS, Windows and with a SOCKS proxy. The core (simplex-chat/simplexmq#2012) sets `TCP_USER_TIMEOUT` only on Linux and Android, and never for connections via a SOCKS proxy, so there the switch has no effect.

## Cause

The switch was added on all platforms, as the other `TCP_*` rows are.

## Fix

- iOS: the switch, its app group default and `KeepAliveOpts.unackedDataTimeout` are removed.
- `expect val unackedDataTimeoutSupported`:
  - Android: `true`;
  - desktop: `desktopPlatform.isLinux()`.
- `AdvancedNetworkSettingsLayout`: `networkTCPUserTimeout` is nullable; the switch row and its greyed row are shown when it is not null.
- `AdvancedNetworkSettingsView` passes `null` when `unackedDataTimeoutSupported` is false or a SOCKS proxy is used. The Kotlin apps never set `socksMode`, so with a SOCKS proxy every connection goes through it.

## Scope

- Advanced network settings on Android and desktop; iOS returns to master.
- The stored preference and the config sent are unchanged.
