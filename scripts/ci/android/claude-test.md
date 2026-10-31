# Test: custom chat lists (tags): create, add chats, filter, edit, delete in the SimpleX Chat Android app

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button.
- Besides the chats, the chat list shows the app's own cards as list items until they are closed: "New 1-time link / Paste link / Scan" (once there is a conversation), "Bottom bar / Top bar", and "Invest in SimpleX Chat!". They are part of the list, not something drawn over it: leave them open.
- **The list row** is just above the search field "Search or paste SimpleX link". With no list of your own it shows the preset filters ("Groups", "Notes") and "Add list"; once a list exists, "Add list" becomes a "+" icon at the end of the row and the list shows by name.
- **Menus:** `ui long-press <x> <y>` on a chat row in the list, or on a list's name in the list row (centre from `ui find`), opens its menu.

## The test

The cases build on each other: run them in this order.

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Get started": click it. Click the field "Enter profile name…", type `citester`, and click "Create profile". On "Your network", click "Continue". The app explains instant notifications in an alert: click "Allow". Android then asks whether the app may always run in the background: click "Allow" again. Click "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone" while there are no conversations. Then create two groups: click "Start new chat" (the round button in the bottom toolbar), then "Create group". The name field under "Enter group name:" has the focus: type `ci tag one` and click "Create group"; click "Skip inviting members" if it shows; `ui key BACK` until the chat list shows. Do the same for `ci tag two`. Check: the chat list shows "ci tag one", "ci tag two" and "Private notes", and the list row shows "Groups", "Notes" and "Add list".
2. (R52.2) Click "Add list". In the editor tap the field "List name...", type `work`, and click "Save list". Check: the list row shows "work". Long-press the row "ci tag one" in the chat list → "Add to list" → tap "work" in the screen that opens. Tap "work" in the list row; shot. Check: the chat list shows "ci tag one" only (not "ci tag two", not "Private notes"). Tap "work" again; shot. Check: all chats show again.
3. (R52.3) Long-press "work" in the list row. Check: the menu offers "Edit", "Delete" and "Change order". Tap "Edit". The editor shows `work` in the name field: tap the field, `ui key MOVE_END`, `ui type " list"`, check the field shows `work list`, and tap "Save list". Check: the list row shows "work list"; tapping it still shows "ci tag one" only; tap it again to show all chats.
4. (R52.4) Long-press "work list" in the list row → "Delete". Check: the alert "Delete list?" says "All chats will be removed from the list work list, and the list deleted". Tap "Confirm". Check: the list row no longer has "work list" and shows "Add list" again; "ci tag one" and "ci tag two" are still in the chat list.

You have at most 600 turns, and the whole test fits in about 50 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Get started" -- click-text "Enter profile name" 30 -- type citester -- shot profile`
- `ui do click-text "Start new chat" -- click-text "Create group" 10 -- wait "Enter group name" -- shot new-group`

`ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Take a shot at each check, named after its case (`ui shot R52-2`).

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per case ID (S1, R52.2, R52.3, R52.4) with PASS, FAIL or SKIPPED (with the reason) and its evidence (text from the screen, screenshot names), and anything else unexpected. A case the app cannot do on this platform is SKIPPED, not FAIL. End your final message with one line: `CLAUDE-TEST: PASS` if every case you ran passed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
