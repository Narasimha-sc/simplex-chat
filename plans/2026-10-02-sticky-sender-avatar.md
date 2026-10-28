# Sticky sender avatar in group chats

## Problem

In a group, a sender's consecutive messages show one avatar, on the first (top) message. When the sender writes several messages, or one long one, the avatar scrolls away with the first message while the rest of their messages are still on screen, and nothing near them says who wrote them.

## Behaviour

- A sender's consecutive received messages form a run (the same run that today shows a single avatar: time gaps and date separators don't break it).
- When the top of the run scrolls under the top bar, the avatar stays 4dp/pt below the top bar (or the reports/support bar, or the window top in one-hand UI) and scrolls with the run.
- The bottom of the run's last row pushes it up; then the next sender's avatar takes over. A single tall message behaves the same way.
- Tapping the pinned avatar opens member info, as before, both on the stand-in and on the run's first row's own avatar while it is moved down; drags and wheel scrolling over it scroll the list.
- Groups only (including business and member-support chats). Channels are unchanged: follow-on channel rows have no avatar column, so a pinned avatar would cover text.
- Android/desktop: the Terminal chat layout is unchanged. It draws the sender's avatar only on the first row of a run, at the start of the row beside the sender's name, with the message below the name; follow-on rows leave that space empty. Nothing is pinned there and no stand-in is composed.

## Design

One rule on both platforms: the avatar's top is `max(naturalTop, min(belowTopBar, runBottom − avatarSize))`.

### Android and desktop (Compose)

- **The run's first row moves its own avatar.** A layout modifier on the row's avatar reads its `coordinates` during placement. Compose re-runs such placement whenever an ancestor moves (`notifyChildrenUsingCoordinatesWhilePlacing`), so the avatar follows the scroll in the same frame, with no overlay and no extra state. The avatar draws outside its row; rows are not clipped and older rows are placed after newer ones, so it is drawn above the rows it covers. Hit-testing outside the row is not assumed: the GUI test clicked the moved-down avatar of a partly hidden first row and member info opened.
- **A stand-in when that row is gone.** LazyColumn disposes the first row once it scrolls out, but the run can be taller than the screen. An overlay above the list draws the same avatar at the same position only while the run's first row is not in `visibleItemsInfo`, so exactly one of the two is drawn and the hand-off is seamless. It is composed with the top message's member (compared structurally, so a member update such as blocking or a new picture is drawn and passed to member info, and only a hand-off between messages carrying different member snapshots recomposes it) in a composable lambda, which has its own restart scope, so its reads don't recompose the chat list; it is shown or hidden during placement, which runs in the same frame as the list.
- **The stand-in is clickable without blocking scrolling.** A no-op pointer-input node with `sharePointerInputWithSiblings() = true` lets the list under it still receive drags and wheel events.
- Run geometry (`senderRunBottom`) only walks visible items, so the per-frame cost does not depend on run length.

Rejected:
- Overlay only, with the row's avatar hidden: it needs the avatar's position inside the row in the overlay, i.e. shared mutable layout state.
- An avatar composed in every row of the run: Android decodes the profile image on every composition (`base64ToBitmap` has no cache there).
- `stickyHeader`: it pins to the start of the list, which is the bottom in this reversed list, and it adds list items, while the code relies on one list item per merged item.

### iOS (SwiftUI)

- Rows are SwiftUI views inside UIKit cells positioned by `EndlessScrollView`, so a per-frame offset inside a cell would trail the cell by a frame and jitter. Instead an overlay in `ChatView` draws the pinned avatar, and the first row's own avatar is hidden (opacity) while it is pinned.
- The pin is computed in the existing scroll listener (`onChatItemsUpdated`, called from `layoutSubviews` on every scroll frame) and published only when it changes. Rows observe only the hidden-row id, so pushing the avatar up does not re-render every visible row.
- Rows report where their avatar is inside the row (named coordinate space), and the pin is recomputed when that changes.
- Run geometry walks only the visible rows. While the run's first row is above them, the overlay shows the member of the topmost visible message of the run, as on Android/desktop.
- **One vertical reference.** `chatItemsList` extends the scroll view 100pt above its `GeometryReader` (`.padding(.vertical, -100)`), and `EndlessScrollView.insetTop` is the same 100pt (never reassigned), so `contentOffset.y + insetTop` is the top of the `GeometryReader`. That `GeometryReader` and the overlay both fill the `ZStack` that is the first child of the chat `VStack`, whose top is the bottom of the navigation bar plus the `safeAreaInset(edge: .top)` search bar and divider. The pin line, the overlay's `y` and the tap test all measure from that top, on every device and with search open or closed. The iOS chat view has no one-hand (bottom toolbar) layout.
- **Right-to-left.** The row places its avatar with `.padding(.leading, 12)` (plus the selection checkbox), so it sits at the right edge in RTL. The overlay uses the same `.padding(.leading, …)` with `.topLeading` alignment, and the tap test measures x from the right edge of the scroll view when its `effectiveUserInterfaceLayoutDirection` is right-to-left. The iOS app has no RTL localization yet, so RTL is reachable only with the right-to-left pseudolanguage.
- The overlay is above the scroll view, so it would swallow drags. It doesn't take touches; a tap recognizer on the scroll view begins only inside the pinned avatar, doesn't cancel other touches, and ignores a tap that stops a fling.
- This part has not been compiled or run: there is no Swift toolchain here, so it was checked by reading the code only.

## Known limitations

- If the run's last message is the last one of a day, the avatar stops at the bottom of the date separator below it, not at the bubble.
- Android/desktop: no pinning while selecting messages. The avatar stays in the run's first row as on master, there is no stand-in, and pinning resumes when selection ends.
- iOS: in selection mode the pinned avatar is always shifted by the selection checkbox, so in a run whose first message can't be deleted it is offset horizontally from that row's own avatar. Tapping it doesn't open member info; the tap goes to the message under it.
- Android/desktop: with bar blur on, the bars blur a copy of the list only, so when the end of a run pushes the stand-in under the top bar it disappears at the bar edge instead of showing blurred (a pushed-up row avatar does show blurred).
- Android/desktop: after a jump (to a quoted message or the first unread, or a fling past several rows in one frame) that lands inside another sender's run, the pinned avatar can be missing for one frame.
- iOS: no pinned avatar in a pending member's "Chat with admins", where a title bar is drawn over the top of the list.
- iOS: a change of the "show group as sender" flag splits a sender's run (e.g. the local welcome message of a group joined by link, shown with the group's image, followed by the link host's own messages): the welcome message pins the group's image until its bottom pushes it out, then the link host's photo pins beside the host's messages, appearing at the pin line rather than sliding up from a row avatar, because the host's first message has none.
- iOS: SwiftUI may draw the overlay a frame after UIKit moves the cells, so the avatar can trail by one frame of scroll when it pins, unpins or is pushed up. When the avatar is pushed out at the bar, it disappears with up to 4pt still showing (the next sender takes the pin when their row crosses the pin line), and the row's own avatar can reappear blurred under the translucent bar once the next sender's messages reach it.

## Open questions

- Comments kept, each needs maintainer approval: `ChatView.kt` "a lambda has its own restart scope, so the reads below don't recompose ChatItemsList" (explains why `PinnedSenderAvatar` is a lambda named like a component; a local `@Composable fun` gets no restart scope) and `ChatView.swift` "the pinned avatar is drawn above the scroll view, so the scroll view recognizes taps on it to keep drags on it scrolling".
- iOS: `memberImageTops` is keyed by item id and only grows while a chat stays open; it is not pruned as rows leave the list.
- iOS: `showPinnedMemberInfo` repeats the member lookup done where the pinned avatar is chosen; it could take the member from `PinnedAvatar` instead.

## Testing

Desktop Linux AppImages, master build vs a build of this branch merged with other PRs under review, on master 0b4c798e5. A group of two CLI peers and the app: runs of up to 55 messages from one sender, multi-line and 30-line messages, alternating single messages.

- Classic layout: master shows no avatar once the run's first row has scrolled away; the PR build pins it, hands it from the row to the stand-in without a second copy, and a very tall last message pushes it up before the next sender takes over.
- Click on the stand-in and on the moved-down avatar of a partly hidden first row: member info opens. Click where no avatar is pinned: nothing opens. Mouse wheel over the stand-in scrolls the list.
- Selecting messages: no pinning, a click toggles selection, pinning resumes after. Blocking the member blurs the pinned avatar, unblocking clears it. A direct chat: nothing pinned.
- Terminal layout: the same scroll positions look the same on both builds, no avatar drawn over the rows.
- Not run: channels, light/dark theme, one-hand UI off, the reports bar, in-chat search and floating date, swipe-to-reply, Android. iOS was not built or run.
- An earlier round on master 3e6fd3836, before the Terminal chat layout (#7811) and #7725 changed `ChatView.kt`, also checked the pinned position in pixels, one-hand UI on and off, the reports bar, Android (Waydroid), and tap/drag/wheel/fling over the stand-in in a standalone Compose 1.8.2 harness. These were not repeated on the current code.
