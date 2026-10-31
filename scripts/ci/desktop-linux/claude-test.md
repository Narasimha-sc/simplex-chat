# Test: calls (alerts only) and supporter badges in the SimpleX Chat desktop app

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`, except where step S4 says so. Begin with `ui shot start` to see it.
- After onboarding, the chat list is in the left pane (x 1 to 389) and chats open in the right pane. An empty chat list shows only its toolbar, with the profile picture at about 27,730 and a pencil (New chat) at about 363,730: the search field "Search or paste SimpleX link" appears once there is a chat. The toolbar is at the bottom of the left pane.
- All profiles are in this one app, which shows one profile at a time. A profile that is not shown still receives messages and invitations; its chats show them once you switch to it. Messages go through the preset servers on the internet: after an action in one profile, wait up to 60 s for its effect in another (`ui wait "<text>" 60`).
- Never start a call here: a desktop call opens a web browser, and none runs on this machine. Never tap "Redeem" when it is enabled, and never open "Buy in browser": both reach the real SimpleX badge service or website.

## How to do things in the app

- **Send a message:** click the message field at the bottom of the right pane (placeholder "Message"), `ui type "<text>"`, then `ui key Return`. Check the message then shows in the chat.
- **Chat info / group info:** click the chat's name at the top of the right pane. Press Escape to close it and other panes and get back to the chat.
- **Settings:** click the profile picture (about 27,730), then "Settings". Press Escape to go back one screen, until the chat list shows.
- **Switch profile:** click the profile picture; the menu lists your other profiles by name: click the one you want.
- **Add a profile:** profile picture → "Your chat profiles" → "Add profile". On "Create profile", click the field about 40 px below the text "Enter your name:", type the name, and click the "Create profile" button (the lower of the two "Create profile" texts; the upper one is the title). The new profile becomes the active one; press Escape until the chat list shows.
- **Copy a 1-time link:** pencil (about 363,730) → "Create 1-time link"; wait for the link under "Share this 1-time invite link" and click the link text: the toast "Copied to clipboard" shows. Press Escape until the chat list shows.
- **Open a copied link** (as another profile): pencil → "Paste link" → "Tap to paste link". An alert names the other profile with "Open new chat": click it; the chat opens with a "Connect" button at the bottom: click it. If the alert is "Connect via one-time link?" instead, click "Use current profile".
- **Create a group:** pencil → "Create group". Click the name field, about 40 px below the text "Enter group name:", type the name, and click "Create group". A screen to invite members follows: click "Skip inviting members", or click a contact and then "Invite to group".
- **Contact preferences:** chat info → "Contact preferences". The section "Audio/video calls" has the row "You allow" (click its value to choose "default (yes)", "always", "yes" or "no") and "Contact allows"; "Save and notify contact" saves.

## The test

The cases build on each other: run them in this order. Write texts exactly as given.

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone".
2. (S2) As citester, copy a 1-time link. Add the profile `cibob`; as cibob, open the copied link. Wait up to 120 s until cibob's chat "citester" shows the message field "Message"; send `hi tester`. Switch to citester. Check: within 60 s the chat list shows "cibob" and its chat shows "hi tester".

**R. Cases, then more setup.**

1. (R65.3) As citester → "cibob" → chat info → "Contact preferences": in "Audio/video calls" set "You allow" to "no", click "Save and notify contact", press Escape to chat info. Click "call" (the call button under the name). Check: the alert "Allow calls?" says "You need to allow your contact to call to be able to call them." and offers "Allow" and "Cancel". Click "Allow". Open "Contact preferences" again. Check: "You allow" of "Audio/video calls" is no longer "no". Press Escape until the chat list shows. Then the member info: create the group `ci calls` and invite "cibob" ("Invite to group"). Switch to cibob; click "ci calls" in the chat list → "Join" in the alert "Join group?". Switch to citester; set "You allow" for calls with cibob to "no" again ("Save and notify contact"). Open "ci calls" → group info → click "cibob" in the member list → in cibob's member info click "call". Check: the same alert "Allow calls?" shows; click "Allow". Do not click "call" afterwards. Press Escape until the chat list shows.
2. (R71.0) Settings → "Supporter perks". Check: "Support SimpleX" opens with "How badges protect your privacy", "Buy in browser" and "Redeem badge code". Click "Redeem badge code". Check: "Redeem code" with "Paste the code you received." and a field showing "SB-XXXXX-XXXXX-XXXXX-XXXXX". Click the field and type `SB-ABCDE-FGHIJ-KLMNO-PQRS` (one character short of a code). Check: the field shows the code in groups, and "Redeem" stays disabled (clicking it changes nothing: no alert, no progress). Only the app's own check of a wrong code is in scope: redeeming a code reaches the real badge service, and an already used code needs a real one. Press Escape until the chat list shows.

**S. More setup for the chat list banner.** The "Support SimpleX" banner shows only with more than three chats and only from the next start of the app, since another banner holds its place until then.

3. (S3) Create the groups `ci three` and `ci four` ("Skip inviting members"). The chat list now has "cibob", "ci calls", "ci three" and "ci four". If the chat list shows the banner "Invest in SimpleX Chat!": click it, press Escape to close what it opens, then click the small × at the top right of the banner (it appears once the banner was opened). Check: the banner is gone.
4. (S4) Restart the app: `ui stop`, then `ui start /home/runner/work/_temp/app/simplex` (the job's app directory), then wait up to 120 s for "cibob". If `ui start` fails, mark S4, R69.0 and the banner part of R68.0 SKIPPED with its output, and do only the Settings part of R68.0 if the app still runs.

**R. Banner cases.**

5. (R69.0) Check: within 30 s the chat list shows the banner "Support SimpleX" with "Get badge + better files", and the banner has no × (take a shot; zoom on the banner's top right). Click the banner. Check: "Support SimpleX" opens. Press Escape until the chat list shows. Check: the banner now has a small × at its top right. If the banner never shows, record FAIL with what the chat list shows in its place.
6. (R68.0) Click the banner → "Support SimpleX" → "How badges protect your privacy". Check: the screen "How badges protect your privacy" opens and starts with "A badge is an anonymous credential stored in your profile on your device. This credential is never sent to anyone.". Press Escape until the chat list shows. Settings → "Supporter perks". Check: "Support SimpleX" opens; click "How badges protect your privacy": the same screen opens. Press Escape until the chat list shows.

You have at most 600 turns, and the whole test fits in about 80 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click 27 730 -- click-text "Your chat profiles" 10 -- click-text "Add profile" 10 -- wait "Enter your name" -- shot add-profile`
- `ui do click 363 730 -- click-text "Paste link" 10 -- click-text "Tap to paste link" 10 -- wait "Open new chat" 60 -- shot open-new-chat`
- `ui do click 27 730 -- click-text "Settings" 10 -- click-text "Supporter perks" 10 -- wait "Support SimpleX" -- shot support`

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: a table with one row per case ID (S1, S2, R65.3, R71.0, S3, S4, R69.0, R68.0), each with PASS, FAIL or SKIPPED (with the reason) and its evidence (the text OCR read, screenshot names). A case the app cannot do on this platform is SKIPPED, not FAIL. Add anything else unexpected. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
