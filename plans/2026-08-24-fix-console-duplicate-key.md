# Chat console crash on duplicate list keys

## Problem

The chat console (Android, desktop) crashes with `IllegalArgumentException: Key "(…, …)" was already used`. Its rows are keyed by `item.id to item.createdAtNanos`, i.e. the creation time in milliseconds and `System.nanoTime()`. Terminal items are created on several threads: commands in `sendCmd` on the IO dispatcher, received events in the receiver coroutine (also on the IO dispatcher), and items created on the main thread. Two items created within one clock tick get the same key — on different threads, or on the main thread when the clock is coarse (a rejected console command and its error response are created back to back) — and the next measure pass throws. This shows the "View crashed" alert: desktop closes the console, Android recreates the activity.

`nanoTime` never goes backwards but is not unique; how often ties happen depends on the clock's granularity (finer on Linux x86 than on Windows or ARM). #4812 added this key (with `createdAtNanos`); it also keeps rows in place while new items arrive.

## Fix

Key the rows by a per-item number from a shared `AtomicLong`, assigned when the item is created. `createdAtNanos` had no other reader and is removed.

## Alternatives considered

- Reuse `id` as the counter: assigned in the factories, it is bypassed by items constructed directly (e.g. `sampleData`); assigned in the base class, it works like this fix but changes both constructors and every factory call.
- No key: no crash, but when scrolled up, new items shift the visible rows (which #4812's key also prevents).
- Number items when they are added to the list: `addTerminalItem` runs on several threads, so this still needs an atomic counter, plus a mutable field or a wrapper; larger.
- Generator in the `TerminalItem` companion object: the same size, but it would have to be declared before `sampleData`, which constructs items while the companion is initialised. A top-level property does not depend on order, because no other top-level initializer in the file constructs an item.
- Stronger time-based keys (thread id, identity hash, UUID): uniqueness by chance, or the same counter at higher cost.

## Not included

- iOS keys console rows by a `Date` too; duplicates there do not crash.
- `ChatModel.addTerminalItem` updates the list from several threads without a lock, so an item can be lost or `subList` can throw `IndexOutOfBoundsException`; it cannot create duplicate keys. Fixed separately in Narasimha-sc/simplex-chat#57.

## Testing

Desktop AppImage, master vs this PR. A duplicate needs two items created within one clock tick, so the repro runs the app with a small `LD_PRELOAD` library that rounds the monotonic clock to 1 ms: on master, a few `/sql chat select 1` commands in the chat console show "View crashed"; the PR build shows the rows. Regression with the normal clock on both builds: autoscroll, scroll position kept while scrolled up, row details and Share, the row cap (200, or 500 with developer tools), rows added while the console is closed, the console in its own window. Android APK: smoke test of the console.
