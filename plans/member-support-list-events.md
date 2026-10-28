# Member support chats: update the list from events

## Problem
A group owner in a large group opens "Chats with members" and opens members' support chats one after another.
The first chat opens quickly; every later one takes over a second (up to several seconds) to open.

## Cause
- Only the top modal is composed (`ModalView.kt:206-229`), so `MemberSupportView` re-enters composition on Back.
- On every entry it loaded all members (`MemberSupportView.kt:44-46` on master; iOS `.onAppear`,
  `MemberSupportView.swift:22-25`). The database has one connection (`DBStore.dbConnection :: MVar`),
  so the next `/_get chat #g(_support:m)` queues behind that query; cancelling the coroutine does not stop it.
- Reporter's `/sql slow` log: `getGroupMembers` 1.6 s avg, 15 s max (122 calls); scoped `getGroupChat` ≤37 ms.
- The reload was the only refresh of support stats: the apps ignored them in events, `APIChatItemsRead`
  returned `GroupChat gInfo' Nothing` (`Commands.hs:1334` on master), deletions kept the old scope member.

## Fix
- Core: mark-read, `deleteGroupCIs`, group send (new `saveSndChatItems'`), `createChatItems` and
  moderation-before-message return the updated member; the first support chat open re-reads it (Postgres
  `support_chat_ts` keeps microseconds, so a patched copy could differ). Old clients: both apps strip the scope.
- Apps: `upsertSupportChatMember(cInfo)` adds the member or replaces only `supportChat` and profile, from
  `NewChatItems`, `ChatItemsDeleted`, delete, send/forward and mark-read responses and the support chat load.
- The list loads only when members are not loaded for its group; iOS resets `membersLoaded` on resume.
- `withLoadedSupportChat` keeps list stats in iOS member info (stale copy), `JoinedGroupMember(Connecting)` and
  accept-member responses: their member predates the "pending review" item (Kotlin: either order).
### Known limitations
- A failed load is not retried on reopen (refresh button retries). A remote host still reloads on every
  open, because an older host does not return the updated member on read, send and delete.
- A member load in flight overwrites a newer update; out-of-order snapshots (including Kotlin member-info
  actions that upsert the member as read at their start) can show an older count until the next update.
- Connection-state labels and a profile changed over a direct connection refresh only on a member re-read.
- Kotlin: a channel update empties another group's open list until reopen or (local host) that group's next
  member update, which then drops the channel's relay members until the next relay update.
- iOS: a re-sort popping the pushed support chat needs a device test; a list shown at resume is not reloaded;
  after resume the mention picker reloads all members, and returning to the list mid-load loads it again.
## Approaches considered
- Refresh only the viewed member on return (`apiGroupMemberInfo`): still polls, misses other members.
- Load once, no updates: the member just read keeps the badge, new support chats do not appear.
- Debounce or delayed cancellable reload: the next open still queues behind a started load.
- Support-members-only query (`/_members support`): tried, did not help.
- Faster member query: only shortens the wait. Second read connection: commits fail with BUSY.
- Updated chat info only for support chats: extra branch; `saveRcvChatItem'` already does it for every type.
- Chosen: load once and upsert from chat infos, so no support chat open waits behind a member reload.

## Tests
No tests added. Desktop AppImage, 4 pending + 40,000 SQL filler members, 3 trials per build (PR body):
2nd-4th opens 1.02-1.41 s on master vs 0.44-0.54 s; `apiListMembers` 5 vs 1 per run; badges, refresh OK.
Not run: Android, iOS (Swift not compiled), Haskell tests (CI only), Postgres. Delete count: inconclusive.

## Open questions
1. iOS: compile and device-test (re-sort popping the pushed chat) before leaving draft?
2. Limit `createChatItems`/`saveSndChatItems'` updated chat info to support chats instead of every chat type?
3. Separate PRs: channel support open (`ChatView.kt:228`, `ChatView.swift:768`), iOS unscoped
   `apiGetChatContentTypes` (`ChatView.swift:804`, 2.7 s avg in reporter's log), "@" (`GroupMentions.kt:133`),
   Info (`ChatView.kt:723`), `ChannelRelaysView.kt:38`, support "Mark read" without scope (`ChatView.kt:796`)?
4. Re-test the delete-item count with live peers?
