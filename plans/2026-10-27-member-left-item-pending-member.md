# Missing "left" line of a pending member, and unread left by late support messages

## Problem
- A member pending approval or review leaves: no "left" line in the group's main chat, no preview change.
- A moderator who has not processed the leave sends to that member's support chat (or edits a message):
  the receiver gets unread and attention counters that no UI path clears.
- A non-active profile's unread badge stays high after a pending member leaves or is removed, until restart.

## Cause
- `xGrpLeave` (`Library/Subscriber.hs:3820`) calls `updateMemberRecordDeleted` (`Library/Internal.hs:2224`),
  which deletes the support chat and sets the status to left, but returned only `GroupInfo`.
- `xGrpLeave` passed the old, pending member to `mkGroupChatScope` (`Library/Internal.hs:1978`), so the item
  is saved in the deleted support chat; the apps hide left members' support chats (`MemberSupportView.kt:89`).
- `mkGetMessageChatScope` (`Library/Internal.hs:1989`) creates the support scope without a status check;
  the send side refuses such a member with `memberCurrentOrPending` (`Library/Internal.hs:1959`).
- The apps handle `LeftMember` and `DeletedMember` only for the active user, so the users list with
  unread counts is not reloaded for other profiles. INFERENCE: the core deletes the support chat items.

## Fix
- `updateMemberRecordDeleted` also returns the updated member; `xGrpLeave` uses it for `mkGroupChatScope`
  (item in the main chat) and `CEvtLeftMember` (no status override). `xGrpMemDel` keeps only `GroupInfo`.
- `mkGetMessageChatScope` rejects a referred member with `memberRemoved` (`Library/Internal.hs:2006`)
  with the send side's error; `isReport` and own support chat unchanged. INFERENCE: CLI shows it, apps log it.
  Left, removed, rejected or deleted members get no item or counters.
- Pending and current members are unchanged. A client that processed the leave no longer forwards the late
  message; one that has not deletes that support chat on the leave.
- Non-active user: `LeftMember`, `DeletedMember` reload users like `groupChatItemsDeleted` (repeated, not
  extracted; `SimpleXAPI.kt:3244`, `:3264`, `SimpleXAPI.swift:2812`, `:2831`): one `listUsers` per event.

## Approaches considered
- Re-read the member after the update: one more query for a value the function already holds.
- `mkGroupChatScope` reads the status itself: about 20 callers change, most without this problem.
- No item for pending members: a product decision; changes what admins and moderators see.
  Only moderators get this leave: pending review forwards it to moderators only; pending approval, not at all.
- Silent drop in the two callers: `mkGetMessageChatScope` returns `Maybe`, larger diff, same visible result.
- Change `deleteGroupMemberSupportChat` or the UI hiding left members' support chats: not the cause.
- Change `getUsersInfo`: it counts only existing items, correct once the items are not created.
- Refresh only on `LeftMember`: `DeletedMember` has the same cause.
- Shared reload helper: a structure-only change. Badge recomputed in the UI: the UI has no such count.
- Chosen: return the updated member; check like the send side; reload users like `groupChatItemsDeleted`.

## Tests
- Added `testGLinkPendingApprovalMemberLeaves`: the admin's last main chat item is "left (signed)";
  fails on master.
- `testScopedSupportForwardLeave`: alice, bob and dan have "left (signed)" as the last main chat item.
- Added `testScopedSupportMessageToLeftMemberDropped`: bob's database marks left cath current; alice gets
  the error, no item, unread or `support_chat_ts`, 0 attention (INFERENCE: error text, cath's id 3 on bob).
- Haskell tests: not run (no CI run yet, not run locally). iOS change: not compiled.

## Open questions
- Join and pending-review items stay in the deleted support chat: admins see "X left" without a join.
- On rejection the rejecting admin sees no line; other moderators see "removed" in the main chat.
- Repeated join and leave moves the group to the top of the chat list each time.
- Rows already stuck in existing databases are not cleaned: migration as an optional follow-up?
