# Test: custom chat lists (tags): create, add chats, filter, edit, delete in the SimpleX Chat desktop app

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- After onboarding, the chat list is in the left pane (x 1 to 389) and chats open in the right pane. An empty chat list shows only its toolbar, with the profile picture at about 27,730 and a pencil (New chat) at about 363,730: the search field "Search or paste SimpleX link" appears once there is a chat. The toolbar is at the bottom of the left pane.
- **The list row** is just above the search field. With no list of your own it shows the preset filters ("Groups", "Notes") and "Add list"; once a list exists, "Add list" becomes a "+" icon at the end of the row and the list shows by name.
- **Menus:** `ui right-click <x> <y>` on a chat row in the list, or on a list's name in the list row, opens its menu. Press Escape to close a pane or menu.

## The test

The cases build on each other: run them in this order.

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone". Then create two groups: click the pencil, then "Create group"; click the field about 40 px below the text "Enter group name:", type `ci tag one`, and click "Create group" (the lower of the two texts); if "Skip inviting members" shows, click it. Press Escape until the chat list shows, and do the same for `ci tag two`. Check: the chat list shows "ci tag one", "ci tag two" and "Private notes", and the list row shows "Groups", "Notes" and "Add list".
2. (R52.2) Click "Add list". In the editor click the field "List name...", type `work`, and click "Save list". Check: the list row shows "work". Right-click the row "ci tag one" in the chat list → "Add to list" → click "work" in the pane that opens. Click "work" in the list row; shot. Check: the chat list shows "ci tag one" only (not "ci tag two", not "Private notes"). Click "work" again; shot. Check: all chats show again.
3. (R52.3) Right-click "work" in the list row. Check: the menu offers "Edit", "Delete" and "Change order". Click "Edit". The editor shows `work` in the name field: click the field, `ui key End`, `ui type " list"`, and click "Save list". Check: the list row shows "work list"; clicking it still shows "ci tag one" only; click it again to show all chats.
4. (R52.4) Right-click "work list" in the list row → "Delete". Check: the alert "Delete list?" says "All chats will be removed from the list work list, and the list deleted". Click "Confirm". Check: the list row no longer has "work list" and shows "Add list" again; "ci tag one" and "ci tag two" are still in the chat list.

You have at most 72 turns, and the whole test fits in about 46 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Create your profile" -- wait "Enter profile name" -- click-text "Enter profile name" -- type citester -- shot profile`
- `ui do click 363 730 -- click-text "Create group" 10 -- wait "Enter group name" -- shot new-group`

`ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Take a shot at each check, named after its case (`ui shot R52-2`).

## Report

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per case ID (S1, R52.2, R52.3, R52.4) with PASS, FAIL or SKIPPED (with the reason) and its evidence (the text OCR read, screenshot names), and anything else unexpected. A case the app cannot do on this platform is SKIPPED, not FAIL. End your final message with one line: `CLAUDE-TEST: PASS` if every case you ran passed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
