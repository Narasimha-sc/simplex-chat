# Group navigation info counts the items the chat lists

Fix for the endless `After` loading in member support chats. Core only: `src/Simplex/Chat/Store/Messages.hs` and `chat_query_plans.txt`.

## Problem

Opening a member support chat in a group where other members' support chats have newer unread messages makes the app request the same page again and again:

```
/_get chat #1(_support:2) after=28 count=100   -> items=[] navInfo=(afterUnread=0, afterTotal=0)
```

169 requests in about 6 s on the unmodified master build in the 40k-member fixture (33 in the same 6 s on the PR #31 combo build).

## Cause

FACT [code], file:line as of the parent of this commit:

- `Messages.hs:1701`: `getGroupChatAround'` calls `getGroupNavInfo_ db user g (last cis)` and passes neither `scopeInfo` nor `contentFilter`, though the loaded items were selected by them (`getChatItemIDs db user cInfo ...`).
- `Messages.hs:1781-1830`: the four COUNT sub-queries of `getGroupNavInfo_` filter on `user_id`, `group_id` (and `item_status`) only, so they count the items of all scopes: the main chat and every member's support chat.
- Its sibling `queryUnreadGroupItems` (`Messages.hs:1758-1779`) filters by scope, so the unread counts in chat stats are correct and only navInfo disagrees with the loaded items.

Client side, FACT [code], `apps/multiplatform/common/src/commonMain/kotlin/chat/simplex/common/views/chat/`:

- `ChatItemsLoader.kt:65`: on `Initial`, `afterTotal > 0` creates a split at the last loaded item.
- `ChatItemsLoader.kt:36-40`: an `After` response with no items returns early, so the split is never removed.
- `ChatView.kt:2802-2810`: the `PreloadItems` `LaunchedEffect` exists only while `allowLoad && !loadingMoreItems`; its `snapshotFlow` emits `firstVisibleItemIndex` when the effect starts and `preloadItemsAfter` (`ChatView.kt:2851-2866`, the only `ChatPagination.After(` constructor call) requests the page after the split.
- `ChatView.kt:1888-1898`: each request sets `loadingMoreItems` true then false. The effect leaves the composition on `true` and starts again on `false`, which repeats the request.

FACT [output]: Bob's support chat holds items 14, 16, 17, 26, 27, 28. Items 29-35 belong to other members' support chats and are all `rcv_new`. The core returned `afterUnread=7, afterTotal=7`, exactly those 7.

The main chat has the same defect in the other direction: the counts included newer support-chat items.

## Fix

The lists of a group chat are selected by `(scope, contentFilter)` in `getChatItemIDs` and `queryUnreadGroupItems`. In practice the content filter sent with a pagination that returns navigation info (Initial, Around) is `MsgContentTag.Report` (Reports view, no scope). The media filters (image, video, voice, file, link) use Last/After/Before, which return no navigation info. The fix does not depend on which filters clients send. Reports are always stored in a support scope, so for `(Nothing, Just MCReport_)` the listed items are support-scope reports, and counts restricted to the main scope would cover an unrelated set: too low (newer reports never loaded) or too high (the same `after=` loop in the Reports view).

`getGroupNavInfo_` therefore takes the scope and the content filter and counts the same item set as `getChatItemIDs` (search text aside: `getChatItemIDs` applies it, the counts do not, and `initial` always passes none). Instead of a third dispatch on `(scope, contentFilter)`, the three functions share one: `withGroupItemsCond` passes the item-set condition and its parameters to a continuation (rank-2 argument, as the parameter types differ per case):

- main chat -> `group_scope_tag IS NULL AND group_scope_group_member_id IS NULL`, the existing text, so Postgres can use btree indexes;
- member support chat -> `group_scope_tag = ? AND group_scope_group_member_id IS NOT DISTINCT FROM ?` with `(member_support tag, member id)`; the admins' own support chat (`groupMember_ = Nothing`) -> `(tag, NULL)`;
- link filter -> `has_link = 1`;
- any other tag -> `msg_content_tag = ?`, no scope condition;
- scope with a content filter -> `SEInternalError`, as before (so `getGroupNavInfo_` now runs in `ExceptT StoreError IO`).

The query text of `getChatItemIDs` and `queryUnreadGroupItems` is unchanged for every case except the link filter in `queryUnreadGroupItems`, which used `msg_content_tag = ?` and now uses `has_link = 1` like the list it describes. The navigation counts are one local function `countAfter` used with and without `AND item_status = ?`. The two navigation entries in `chat_query_plans.txt` are replaced; they use the covering indexes `idx_chat_items_group_scope_item_status` and `idx_chat_items_group_scope_item_ts` (created in `M20250513_group_scope.hs`).

Reports view behaviour: its navigation counts now cover the reports the view lists (scope-less `msg_content_tag = ?` over all scopes), the same set as its pages and its first-unread/viewed pivot (`unreadCount` stays unfiltered, as before).

Nothing else changes: no client change, no schema change, no API change.

## Alternatives considered

- Kotlin: drop the split when an `After` response is empty. About 4 lines in `ChatItemsLoader.kt`. It also covers any other navInfo/content mismatch, but the client still receives wrong `afterUnread`/`afterTotal`, and the core inconsistency stays hidden. Reasonable as a defence on top of the fix; not a replacement.
- Kotlin: `ignoreLoadingRequests` guard for `After`, as `preloadItemsBefore` has. Same trade-off, plus more state.
- Kotlin: keep the `LaunchedEffect` composed and check `loadingMoreItems` inside it. It changes pagination timing for every chat; blast radius is far larger than the defect.
- Apply the scope condition only when `contentFilter` is `Nothing` and count unfiltered otherwise. It adds a second dispatch parallel to the other two, and the Reports view would count every item of the group instead of its reports.
- Scope the counts by `(group_scope_tag, group_scope_group_member_id)` only. Correct for the main chat and support chats; wrong for the Reports view, see Fix.
- Compute the counts from the loaded scope in Haskell instead of SQL (filter the unscoped counts). Not possible without loading the other items.

## Tests / verification

The diagnosis changed one thing at a time on the 40k-member fixture:

| build | core navInfo | `After` requests opening Bob's chat |
|---|---|---|
| master | unscoped | loop (169 in 6 s) |
| master Kotlin + PR #31 core | unscoped | loop (33 in 6 s) |
| core fix only | scoped | 0 |

With the fix the log stays quiet after open and `navInfo=(0,0)` for each support chat.

- GUI test, desktop, 40,000-member group, 8 s in each of 4 support chats, `apiGetChat` requests counted in the app log: master 135, 141, 1 and 141 (436 in the run), this change 1 in each (5 in the run, with the group chat). Videos are in the PR description.
- Haskell tests: CI only. `SchemaDump`/query-plan test checks `chat_query_plans.txt`. The plan entries were computed with Python sqlite 3.40.1 on the repo schema, not by the CI test; the harness first reproduced all existing SELECT entries of the file byte for byte. The tests execute only the main-scope variants (no test requests navigation info for a support chat or a filtered chat), so only those two entries are in the file.
- No Haskell test: tests assert terminal output through `chat`, which does not show `NavigationInfo`, and no helper decodes the `/_get chat` JSON response, so a case for `afterUnread`/`afterTotal` would need a new JSON-decoding helper.
- Postgres path: not run locally (`IS NOT DISTINCT FROM` is standard in both).

## Open questions

- Header of the support chat showing the previous member's messages when it is opened while the previous one is still animating out is a separate defect, also on master. Fixed separately on branch `nd/support-chat-modal-state` (`key(memberSupportChatsCtx)` in `showMemberSupportChatView`). Not in this change.
- Whether the UI displays the previously wrong `afterUnread` for support chats was not checked.
- Why the core takes about 40 ms per `After` request with 40k members is not established; it only affects whether the loop stops by chance.
