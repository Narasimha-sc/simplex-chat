# Chat console crash on duplicate list keys

## Problem

The chat console (Android, desktop) crashes with `IllegalArgumentException: Key "(…, …)" was already used`. Its rows are keyed by `item.id to item.createdAtNanos`, i.e. the creation time in milliseconds (set by the factories; `sampleData` uses 0 and 1) and `System.nanoTime()`. Terminal items are created on several threads: commands in `sendCmd` on the IO dispatcher, received events in the receiver coroutine (also on the IO dispatcher), and items created on the main thread. Two items created in the same millisecond and within one `nanoTime` tick get the same key — on different threads, or on the main thread when the clock is coarse (a rejected console command and its error response are created back to back) — and the next measure pass throws. This shows the "View crashed" alert: desktop closes the console, Android recreates the activity.

`nanoTime` never goes backwards but is not unique; how often ties happen depends on the clock's granularity (finer on Linux x86 than on Windows or ARM). #4812 added this key (with `createdAtNanos`); it also keeps rows in place while new items arrive.

## Fix

Key the rows by a per-item number from a shared `AtomicLong`, assigned when the item is created. `createdAtNanos` had no other reader and is removed. `TerminalItem.id` is now set but read nowhere; it is the creation millisecond and not unique, so it must never be used as a key. #4812's key paired it with `nanoTime`, and that pair still collided because both parts, the millisecond and `nanoTime`, can tie. `id` is left in place to keep the diff minimal (see the second alternative below).

## Alternatives considered

- Reuse `id` as the counter, assigned in the factories: items constructed directly (e.g. `sampleData`) bypass it.
- Make `id` itself the counter, assigned in the base class, and key rows by `item.id`: one identity field that is unique, the same idea as `ChatInfo.InvalidJSON.idGenerator`, which fills its id from its own counter as a default constructor argument. It removes the `id` parameter from both constructors and changes both factory bodies and the two `sampleData` lines, about 7 more partial-line edits; the factory call signatures stay, so no call site changes. Not taken: the diff is larger, and `id` would change meaning, since the factories' creation millisecond and `sampleData`'s 0 and 1 would become sequence numbers.
- No key: no crash, but when scrolled up, new items shift the visible rows (which #4812's key also prevents).
- Number items when they are added to the list: `addTerminalItem` runs on several threads, so this still needs an atomic counter, plus a mutable field or a wrapper; larger.
- Generator in the `TerminalItem` companion object: the same size, but it would have to be declared before `sampleData`, which constructs items while the companion is initialised. A top-level property does not depend on order, because no other top-level initializer in the file constructs an item.
- Stronger time-based keys (thread id, identity hash, UUID): uniqueness by chance, or the same counter at higher cost.

## Not included

- iOS keys console rows by a `Date` too; duplicates there do not crash.
- `ChatModel.addTerminalItem` updates the list from several threads without a lock, so an item can be lost or `subList` can throw `IndexOutOfBoundsException`; it cannot create duplicate keys. Fixed separately in Narasimha-sc/simplex-chat#57.

## Testing

Desktop AppImage, master vs this PR. A duplicate needs two items created within one clock tick, so the repro runs the app with a small `LD_PRELOAD` library that rounds the monotonic clock to 1 ms: on master, a few `/sql chat select 1` commands in the chat console show "View crashed"; the PR build shows the rows. Regression with the normal clock on both builds: autoscroll, scroll position kept while scrolled up, row details and Share, the row cap (200, or 500 with developer tools), rows added while the console is closed, the console in its own window. Android APK: smoke test of the console.
