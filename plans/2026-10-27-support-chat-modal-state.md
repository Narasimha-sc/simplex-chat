# Support chat: header of one member over the messages of another

Branch: `nd/support-chat-modal-state`.

## Problem

Open a member support chat (Bob), go back and at once open another (Cara): the toolbar says "Cara Support Two" but the list shows Bob's messages. Reproduced 2/2 on desktop with a script that taps Bob, waits for his message, clicks back and taps Cara immediately. The accessibility tree contained Bob's text under Cara's header.

The bug is on master. It is rarely visible there with large groups, because opening a support chat first waits ~1.1-1.3 s for `apiListMembers`, which lets the previous modal finish its exit animation. With 4 members, master shows the same symptom.

## Cause

1. `ModalManager.showInView` draws modals with `AnimatedContent(targetState = modalCount.value)`, and the content of each state is `modalViews.getOrNull(it - 1)` (`ModalView.kt:216-229`).
2. `showCustomModal` removes the modal that is still closing without waiting for its animation (`ModalView.kt:147-149`).
3. Back lowers `modalCount` by one and starts the exit animation; the next open raises it again before the animation ends. State 2 keeps its content slot, so Cara's lambda runs in Bob's composition. Log: no `MemberSupportChatView` dispose for Bob's context before Cara's modal was shown.
4. In `ChatView`, `mergedItems` and `reversedChatItems` are `remember { derivedStateOf { chatsCtx.chatItems... } }` with no key (`ChatView.kt:1819-1824`). They keep reading Bob's `chatsCtx`, while the toolbar reads the member from the new parameter.

## Fix

`MemberSupportChatView.kt`, `showMemberSupportChatView`: wrap the modal content in `key(memberSupportChatsCtx)`. Each opened support chat has its own `ChatsContext`, so a different chat never reuses the previous composition state. Whole diff: one wrapper, content unchanged (+8/-6 lines from re-indentation).

All five openers (`ChatView.kt:251`, `ChatView.kt:502`, `MemberSupportView.kt:139`, `GroupMemberInfoView.kt:418`, `GroupChatInfoView.kt:492`) go through this function, so all are covered.

## Alternatives considered

- **B2: `key(holder.data)` around `it.modal(...)` in `ModalManager.showInView`.** One line, and removes the class of bug for every modal reopened during an exit animation. Rejected for this change: it touches every modal on every platform. It is the better structural fix and is left as an open question.
- **B3: key every `remember` in `ChatView`/`ChatLayout` by `chatsCtx`.** Many sites, easy to miss one.
- **B4: delay `showCustomModal` until the exit animation ends.** A timing workaround that adds latency to every open.

## Tests and verification

The diagnosis changed one thing at a time, 40k-member fixture, same script (`race2.sh`):

| build | modal key | core navInfo scoped | Bob -> back -> Cara at once |
|---|---|---|---|
| combo (PR #31 + instrumentation) | no | no | wrong content 2/2 |
| core fix only | no | yes | wrong content 2/2 |
| key fix only | yes | no | correct 2/2, Bob's dispose logged |
| both | yes | yes | correct |

- The key alone fixes the content; the unrelated core change alone does not. They are independent.
- Master, 4-member profile, same script: wrong content. Master, 40k fixture: correct, Cara opens in 1.64 s.
- GUI test, desktop, "open a member's support chat, Back, open another member after a controlled gap", 16 repetitions per run: 4-member group, master 6 of 12 counted repetitions show the wrong messages, this change 0 of 12; 40,000-member group, 0 on both builds (the member reload on master delays the open past the animation). Videos and counts are in the PR description.
- Haskell tests are not involved (Kotlin-only change).

## Open questions

- B2 instead of B1 (see above).
- Separate bug, not in this change: in the same scenario, core `getGroupNavInfo_` (`Messages.hs:1701`, `1781-1828`) counts newer items across all group scopes. The client then keeps a split that cannot be filled and `preloadItemsAfter` (`ChatView.kt:2865`) repeats `after=` requests without end. Fix: branch `nd/support-chat-navigation-counts`.
- `showGroupReportsView` (`GroupReportsView.kt:79`) uses the same `ModalViewId.SECONDARY_CHAT` slot with a fresh `ChatsContext` and no key, so reports reopened during the exit animation have the same exposure. Unchanged here; another argument for the wider `ModalManager.showInView` fix.
- Not checked on Android; the change is in common code.
