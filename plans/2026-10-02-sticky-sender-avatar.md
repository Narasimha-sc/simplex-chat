# Sticky sender avatar in group chats

## Problem
In a group, a sender's run of messages shows one avatar, on its top message. It scrolls away while the rest of
the run is still on screen, and nothing near those messages says who wrote them.

## Cause
- The run rule is `shouldShowAvatar` (`ChatView.kt:3835` on master, used at `:2460`; iOS `ChatView.swift:17`).
  Only the run's first row draws `MemberImage` (`:2119`), as part of the row, so it scrolls away with the row.

## Fix
Avatar top, both platforms: `max(naturalTop, min(belowTopBar, runBottom − avatarSize))`, 4dp/pt under the bar.
- Android/desktop: the run's first row moves its own avatar (`stickyInSenderRun`, a layout modifier that
  reads `coordinates` during placement, in the same frame as the scroll). Once LazyColumn disposes that row,
  `PinnedSenderAvatar` (a composable lambda, so its reads don't recompose the list) draws it at the same
  place. `ShareTouchesWithList` lets drags and wheels reach the list; `senderRunBottom` walks visible items.
- iOS: an overlay draws the pinned avatar and the first row hides its own. The pin is computed in
  `onChatItemsUpdated` and published only when it changes; rows observe only the hidden-row id. A tap
  recognizer on the scroll view begins only inside the pinned avatar and ignores a tap that stops a fling.
  Position and tap test are mirrored for right-to-left.
- Groups only (incl. business and member-support chats). Unchanged: channels (follow-on rows have no avatar
  column, a pinned avatar would cover text), direct chats, the Terminal layout.

## Approaches considered
- Overlay only, row avatar hidden (Android/desktop): rejected, needs shared mutable layout state.
- Avatar in every row of the run: rejected, Android decodes the image on every composition (no cache).
- `stickyHeader`: rejected, pins to the list start (the bottom here) and breaks one list item per merged item.
- Chosen on iOS, overlay only: cells are positioned by `EndlessScrollView`, so moving inside a cell jitters.

## Known limitations
- If the run's last message is the last of a day, the avatar stops at the date separator below it.
- Android/desktop: no pin while selecting; with bar blur on, a pushed-up stand-in disappears at the bar edge,
  not blurred; a jump (quote, first unread, fast fling) into another sender's run can lose it for a frame.
- iOS: while selecting, the pinned avatar is always shifted by the checkbox (offset from the row's avatar if
  the run's first message can't be deleted) and a tap doesn't open member info. None in a pending member's
  "Chat with admins"; "show group as sender" changes split a run; it can trail by a frame; a pushed-out avatar
  disappears with up to 4pt left, then the row's avatar can reappear blurred under the translucent bar.

## Tests
- Added: none. Desktop Linux AppImages, master vs this branch merged with other PRs under review, on
  0b4c798e5; group of the app and two CLI peers, runs of up to 55 messages, 30-line messages.
- Verified: master shows no avatar once the first row is gone, the PR pins it without a second copy; a tall
  last message pushes it up; clicks on the stand-in and on a moved-down row avatar open member info; wheel
  over it scrolls; blocking blurs it; nothing pinned while selecting, in a direct chat, or in Terminal layout.
- Not run: iOS (not compiled, no Swift toolchain here), channels, light/dark theme, one-hand UI off, reports
  bar, in-chat search, floating date, swipe-to-reply, Android (Waydroid, pixel positions, one-hand UI on/off,
  reports bar and a Compose 1.8.2 tap/drag/wheel/fling harness ran only on master 3e6fd3836).

## Open questions
- Before merge: check iOS on a device (or split it into its own PR), and run an Android APK on Waydroid?
- Channels keep the old behaviour: is that the intended scope?
- "Show group as sender": Android/desktop pin the member photo, iOS the group image; align in another PR?
- Two kept comments need approval: on the `PinnedSenderAvatar` lambda and on the iOS tap recognizer.
- iOS: `memberImageTops` only grows while a chat is open; prune it as rows leave the list?
- iOS: `showPinnedMemberInfo` repeats the member lookup; take the member from `PinnedAvatar` instead?
