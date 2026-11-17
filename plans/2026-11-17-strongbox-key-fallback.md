# Android: keystore key fallback after a StrongBox failure

## Problem

On some Android 12+ devices, the app fails at the first start and shows "App crashed". The chat database is never created, and each start repeats the failure.

Error:

```
java.security.ProviderException: Keystore key generation failed
Caused by: android.security.KeyStoreException: Unknown error (internal Keystore code: -1000 ...)
    1: Error::Km(r#UNKNOWN_ERROR)) (public error code: 10 internal Keystore code: -1000)
```

## Cause

`Cryptor.createSecretKey` requests a StrongBox key first (#7637). The default keystore is used only after `StrongBoxUnavailableException`. On the reported device, StrongBox key generation for AES-GCM failed with `ProviderException` (keystore `UNKNOWN_ERROR`), not with `StrongBoxUnavailableException`. That exception reaches `initChatController`, which has no `catch`.

Callers of `createSecretKey`, through `KeyStoreItem.set`:

| Caller | Key |
|---|---|
| DatabaseUtils.useDatabaseKey | database passphrase, first start |
| DatabaseEncryptionView | database passphrase, change |
| DatabaseErrorView | database passphrase, entered after an error |
| MigrateToDevice | database passphrase, migration |
| SetAppPasscodeView | app passcode or self-destruct passcode, set |
| LocalAuthView | app passcode, after self-destruct |

## Change

`createSecretKey` catches `ProviderException` around the StrongBox attempt. `StrongBoxUnavailableException` is a subclass of it. The key is then generated in the default keystore. The log records the full exception.

```mermaid
flowchart TD
  A[createSecretKey] --> B{alias exists}
  B -- yes --> C[existing key]
  B -- no --> D{API 31+}
  D -- no --> F[default keystore key]
  D -- yes --> E[StrongBox key]
  E -- ProviderException --> F
  E -- success --> G[StrongBox key returned]
```

## Scope

- Android only: Cryptor.android.kt.
- Existing keys are unchanged.
- An error from the default keystore still propagates, as before #7637.

## Verification

- An API 31+ emulator without StrongBox follows the same `catch`: first start creates the database, and the Database passphrase footer shows the TEE or software storage level.
- The reported StrongBox fault needs the affected device model.
