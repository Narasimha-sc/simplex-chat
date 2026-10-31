# Test: calls (outgoing screen and alerts) and supporter badges in the SimpleX Chat Android app

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button.
- Besides the chats, the chat list shows the app's own cards as list items until they are closed: "New 1-time link / Paste link / Scan" (once there is a conversation), "Bottom bar / Top bar", and "Invest in SimpleX Chat!". They are part of the list, not something drawn over it: leave them open, except where step S3 says otherwise.
- All profiles are in this one app, which shows one profile at a time. A profile that is not shown still receives messages, invitations and calls; its chats show them once you switch to it. Messages go through the preset servers on the internet: after an action in one profile, wait up to 60 s for its effect in another (`ui wait "<text>" 60`).
- The emulator has no microphone and no camera, and one app plays both sides: a call can reach its outgoing screen, never connect. Never tap "Redeem" when it is enabled, and never open "Buy in browser": both reach the real SimpleX badge service or website.

## How to do things in the app

- **Send a message:** tap the message field (placeholder "Message"), `ui type "<text>"`, then tap "Send Message". `ui key BACK` leaves the chat for the chat list.
- **Chat info / group info:** tap the chat's name in the chat's toolbar. `ui key BACK` returns to the chat.
- **Your profile menu:** tap your profile picture at the left end of the chat list's toolbar (with the default reachable toolbar it is at the bottom left; its element reads "profile image placeholder", as chat rows do, so pick it by position). The menu lists your profiles by name, "Your chat profiles" and "Settings".
- **Settings:** profile menu → "Settings". `ui key BACK` goes back one screen.
- **Switch profile:** profile menu → tap the other profile's name.
- **Add a profile:** profile menu → "Your chat profiles" → "Add profile". On "Create profile" the name field under "Enter your name:" has the focus: type the name and tap "Create profile" (the button, not the title). The new profile becomes the active one; `ui key BACK` until the chat list shows.
- **Copy a 1-time link:** "Start new chat" → "Create 1-time link"; under "Share this 1-time invite link" the link is shown with a copy icon at its right end (an unlabeled button: find it with `ui tree` on the link's row) — tap the copy icon (tapping the link text opens Android's share sheet instead). `ui key BACK` until the chat list shows.
- **Open a copied link** (as another profile): "Start new chat" → "Paste link / Scan" → "Tap to paste link". An alert names the other profile with "Open new chat": tap it; the chat opens with a "Connect" button at the bottom: tap it. If the alert is "Connect via one-time link?" instead, tap "Use current profile".
- **Create a group:** "Start new chat" → "Create group". The name field under "Enter group name:" has the focus: type the name and tap "Create group". A screen to invite members follows: tap "Skip inviting members", or tap a contact and then "Invite to group".
- **Contact preferences:** chat info → "Contact preferences". The section "Audio/video calls" has the row "You allow" (tap its value to choose "default (yes)", "always", "yes" or "no") and "Contact allows"; "Save and notify contact" saves.

## The test

The cases build on each other: run them in this order. Write texts exactly as given.

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Get started": click it. Click the field "Enter profile name…", type `citester`, and click "Create profile". On "Your network", click "Continue". The app explains instant notifications in an alert: click "Allow". Android then asks whether the app may always run in the background: click "Allow" again. Click "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone" while there are no conversations.
2. (S2) As citester, copy a 1-time link. Add the profile `cibob`; as cibob, open the copied link. Wait up to 120 s until cibob's chat "citester" shows the message field "Message"; send `hi tester`. Switch to citester. Check: within 60 s the chat list shows "cibob" and its chat shows "hi tester".

**R. Cases, then more setup.**

1. (R65.3) As citester → "cibob" → chat info → "Contact preferences": in "Audio/video calls" set "You allow" to "no", tap "Save and notify contact", go back to chat info. Tap "call" (the call button under the name). Check: the alert "Allow calls?" says "You need to allow your contact to call to be able to call them." and offers "Allow" and "Cancel". Tap "Allow". Open "Contact preferences" again. Check: "You allow" of "Audio/video calls" is no longer "no". Go back to the chat list. Then the member info: create the group `ci calls` and invite "cibob" ("Invite to group"). Switch to cibob; tap "ci calls" in the chat list → "Join" in the alert "Join group?". Switch to citester; set "You allow" for calls with cibob to "no" again ("Save and notify contact"). Open "ci calls" → group info → tap "cibob" in the member list → in cibob's member info tap "call". Check: the same alert "Allow calls?" shows; tap "Allow". Go back to the chat list.
2. (R65.1) As citester → "cibob" → chat info → tap "call". Check: the call screen opens with "cibob" and a call state such as "starting…" or "waiting for answer…" (shot). Only the outgoing screen is in scope: nobody can answer here. If an incoming call alert for cibob shows on top ("Accept", "Reject", "Ignore"), tap "Reject". Tap "Hang up" (the red button). Check: the call screen closes and the chat shows a call item. Then repeat with "video" and hang up.
3. (R71.0) Settings → "Supporter perks". Check: "Support SimpleX" opens with "How badges protect your privacy", "Buy in browser" and "Redeem badge code". Tap "Redeem badge code". Check: "Redeem code" with "Paste the code you received." and a field showing "SB-XXXXX-XXXXX-XXXXX-XXXXX" (a camera area for scanning may show below it without a picture: the emulator has no camera). Tap the field and type `SB-ABCDE-FGHIJ-KLMNO-PQRS` (one character short of a code). Check: the field shows the code in groups, and "Redeem" is disabled (`ui tree` shows its state). Only the app's own check of a wrong code is in scope: redeeming a code reaches the real badge service, and an already used code needs a real one. Go back to the chat list.

**S. More setup for the chat list banner.** The "Support SimpleX" banner shows only with more than three chats and only from the next start of the app, since another banner holds its place until then.

4. (S3) Create the groups `ci three` and `ci four` ("Skip inviting members"). The chat list now has "cibob", "ci calls", "ci three" and "ci four". If the chat list shows the banner "Invest in SimpleX Chat!": tap it, `ui key BACK` to close what it opens, then tap the × at the top right of the banner ("Close button" in the tree; it appears once the banner was opened). Check: the banner is gone.
5. (S4) Run `ui relaunch`.

**R. Banner cases.**

6. (R69.0) Check: within 30 s the chat list shows the banner "Support SimpleX" with "Get badge + better files", and no "Close button" on it (shot and `ui tree`). Tap the banner. Check: "Support SimpleX" opens. Go back to the chat list. Check: the banner now has "Close button" at its top right. If the banner never shows, record FAIL with what the chat list shows in its place.
7. (R68.0) Tap the banner → "Support SimpleX" → "How badges protect your privacy". Check: the screen "How badges protect your privacy" opens and starts with "A badge is an anonymous credential stored in your profile on your device. This credential is never sent to anyone.". Go back to the chat list. Settings → "Supporter perks". Check: "Support SimpleX" opens; tap "How badges protect your privacy": the same screen opens. Go back to the chat list.

You have at most 600 turns, and the whole test fits in about 90 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Get started" -- click-text "Enter profile name" 30 -- type citester -- shot profile`
- `ui do click-text "Start new chat" -- click-text "Paste link / Scan" 10 -- click-text "Tap to paste link" 10 -- wait "Open new chat" 60 -- shot open-new-chat`
- `ui do click-text "Settings" 10 -- click-text "Supporter perks" 10 -- wait "Support SimpleX" -- shot support`

`ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Take a shot at each check, named after its case (`ui shot R65-3`).

## Anything unusual

You are looking for regressions, not only running checks. Besides each case's checks, watch for anything a user would consider wrong, on every screen you pass through:

- a crash, the app closing or restarting, a frozen screen;
- an error alert or dialog of any kind ("View crashed", "Error", "Unexpected error", "Connection error", an error code or exception text);
- an action that takes over 30 s, or a spinner that never ends;
- text cut off, overlapping, garbled, untranslated or showing a raw key (such as `chat_item_…`), wrong plurals, empty labels;
- a control that does nothing, a duplicated or missing item, an item in the wrong place or order;
- a state that differs after a restart or after switching profile;
- anything that differs from how the row or the step describes it.

Record each in `report.md` under a heading `## Unusual`, with the case it happened in and the screenshot names, even when every check passes. A case passes only when its checks pass and nothing unusual happened in it; otherwise mark it FAIL and say why. Never stop at a failure: go on with the next case.

## Report

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: a table with one row per case ID (S1, S2, R65.3, R65.1, R71.0, S3, S4, R69.0, R68.0), each with PASS, FAIL or SKIPPED (with the reason) and its evidence (element texts and positions, screenshot names). A case the app cannot do on this platform is SKIPPED, not FAIL. Add anything else unexpected. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
