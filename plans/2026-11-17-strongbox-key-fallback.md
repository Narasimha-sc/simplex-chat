# Android: keystore key fallback after a StrongBox failure

## Problem

On an Android 12+ device, the alert "View crashed" with a stack trace is shown at the first start, before the chat database is created. The alias is still absent after the failure, so the StrongBox attempt is repeated at the next start.

Error:

```
java.security.ProviderException: Keystore key generation failed
Caused by: android.security.KeyStoreException: Unknown error (internal Keystore code: -1000 ...)
    1: Error::Km(r#UNKNOWN_ERROR)) (public error code: 10 internal Keystore code: -1000)
```

## Cause

A StrongBox key is requested first in `Cryptor.createSecretKey` (#7637). The default keystore is used only after `StrongBoxUnavailableException`. On the reported device, `ProviderException` was thrown by StrongBox key generation for AES-GCM, caused by KeyMint `UNKNOWN_ERROR` (public code 10, `ERROR_KEYMINT_FAILURE`). The trace frame `Cryptor.android.kt:96` is the StrongBox call. That exception is propagated through `initChatController` (Core.kt, `try`/`finally`) and the coroutine of `withLongRunningApi` to `GlobalExceptionsHandler` (UI.android.kt), where the alert is shown.

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

`ProviderException` is caught around the StrongBox attempt in `createSecretKey`. `StrongBoxUnavailableException` is a subclass of it. The key is then generated in the default keystore. The full exception is logged as a warning.

```mermaid
flowchart TD
  A[createSecretKey] --> B{alias exists}
  B -- yes --> C[existing key]
  B -- no --> D{API 31+}
  D -- no --> F[default keystore key generation]
  D -- yes --> E[StrongBox key generation]
  E -- ProviderException --> F
  E -- success --> G[StrongBox key returned]
  F -- success --> H[default keystore key returned]
  F -- exception --> X[exception propagated to caller]
```

## Scope

- Android only: Cryptor.android.kt.
- Existing keys are unchanged.
- An error from the default keystore is still propagated, as before #7637.
- After one StrongBox failure, the key of that alias is kept in the default keystore until the alias is removed. For the database passphrase, its storage level is shown in the Database passphrase footer while the passphrase is stored.
- The fallback is now logged at warning level, which is printed with developer tools off; before, it was logged at info level, which is printed only with developer tools on.

## Verification

- In AndroidKeyStoreKeyGeneratorSpi.java (android-36 sources), `KM_ERROR_HARDWARE_TYPE_UNAVAILABLE` is mapped to `StrongBoxUnavailableException` at line 413, and every other keystore error to `ProviderException` at line 415. The trace frame `AndroidKeyStoreKeyGeneratorSpi.java:415` is the second case.
- On a device without StrongBox, `StrongBoxUnavailableException` is expected by the mapping at line 413; it is also caught on master.
- The fault was reported from one device; the fix can be tested only on a device with the same StrongBox fault.
