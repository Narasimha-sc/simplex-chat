# Test: the contact address and its settings in the SimpleX Chat desktop app (checklist batch B02-2)

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

Each case ID is `R<row>`, the row of the manual checklist it comes from; `S<n>` is a setup step.

## What is set up

- The app is already running, on its first screen, with a new, empty database. Begin with `ui shot start` to see it. Never run `ui start` or `ui stop`, except in R17.13, which restarts the app exactly as it says.
- After onboarding, the chat list is in the left pane (x 1 to 389) and chats open in the right pane. The toolbar is at the bottom of the left pane: the profile picture at about 27,730 and the pencil (New chat) at about 363,730. Settings, the address and New chat open in the left pane; while one is open, a click anywhere in the right pane (about 900,400) closes it.
- The test uses four profiles of this app: citester, cibob, cicarol and cidan. They talk through the app's preset servers on the internet: a connection takes a few seconds to a minute, so wait up to 60 s for it (`ui wait "<text>" 60`).
- Never open, connect to or message "Ask SimpleX Team" (listed in "New chat") or any other preset contact, group or channel: they reach real people.

## How to do things in the app

- **User menu:** click the profile picture (about 27,730). It shows your profile at the top, then "Create SimpleX address" (or "Your SimpleX address"), "Chat preferences", your other profiles by name (below a line), "Your chat profiles" and "Settings".
- **Add a profile:** user menu → "Your chat profiles" → "Add profile". On "Create profile", click the field about 40 px below the text "Enter your name:", type the name, and click the "Create profile" button (the lower of the two "Create profile" texts). The new profile becomes the active one; press Escape until the left pane shows its chat list. If the alert "Make profile private!" shows, click "OK".
- **Switch profile:** user menu → click the other profile's name.
- **The address:** user menu → "Your SimpleX address". It shows a QR code, "Share address" (copies the address and shows "Copied to clipboard"), "Address settings", and further down "Create 1-time link" and "Delete address". "Address settings" holds the switches "Share with SimpleX contacts" and "Auto-accept" (each switch is at the right end of its row, about x 335), the field "Enter welcome message… (optional)" under "Welcome message", and "Save".
- **Copy a new 1-time link:** pencil → "Create 1-time link". Click the link text under "Share this 1-time invite link": the app copies it and shows "Copied to clipboard". Press Escape until the chat list shows (the link view and "New chat" close one at a time).
- **Connect by a copied 1-time link:** pencil → "Paste link" → "Tap to paste link" → "Open new chat" in the alert → "Connect" at the bottom of the chat; wait up to 60 s until the message field "Message" shows. (The chat already holds an item "Messages, files and calls are protected…", so a wait for the text "Message" passes at once: check in the screenshot that "Connect" is gone and the message field is at the bottom.)
- **Send a request by the copied address:** pencil → "Paste link" → "Tap to paste link". The alert names citester, with "Open new chat": click it. The chat shows "Tap Connect to send request", the field "Add message" and "Connect": click "Connect" (at the bottom of the right pane), then "Send request without message" in the alert "Send contact request?".
- **Send a message:** click the message field at the bottom of the right pane ("Message"), `ui type "<text>"`, then `ui key Return`.
- **Chat info:** click the chat's name at the top of the right pane. Escape closes it. A group's info lists its members; clicking one opens the member's info.
- **Chat menu:** `ui right-click <x> <y>` on a chat's name in the left pane (for a contact request: "Accept", "Reject").

## The test

Run the parts in this order; each builds on the ones before.

**A. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone".
2. (S2) As citester, copy a new 1-time link. Add the profile `cibob`; as cibob connect by the link and send `hello citester`. Switch to citester. Check: the chat list shows "cibob".

**B. Creating and sharing the address (citester).**

1. (R17.15) User menu → "Create SimpleX address" → "Create SimpleX address". Check: the alert "Share address with SimpleX contacts?" says "Add address to your profile, so that your SimpleX contacts can share it with other people. Profile update will be sent to your SimpleX contacts." and has "Share" and "Cancel". Click "Share". Check: the address view shows the QR code.
2. (R17.16) Click "Address settings". Check: "Share with SimpleX contacts" is on. Click its switch. Check: the alert "Stop sharing address?" says "Profile update will be sent to your SimpleX contacts." with "Stop sharing" and "Cancel"; click "Cancel". Check: the switch is on again. Click it again and then "Stop sharing". Check: it is off. Click it once more. Check: the alert "Share address with SimpleX contacts?" with "Share"; click "Share". Check: it is on.
3. (R17.14) Still in "Address settings", click the field "Enter welcome message… (optional)" and type `hello from the address`. Press Escape. Check: the alert "Save settings?" with "Save SimpleX address settings" and "Exit without saving"; click "Exit without saving". Open it again (user menu → "Your SimpleX address" → "Address settings"), type `hello again` in the field, and this time click in the right pane (about 900,400). Check: the same alert shows; click "Exit without saving" (this closes the address screens). Open user menu → "Your SimpleX address" → "Address settings" once more. Check: the field is empty (nothing was saved).
4. (R17.18) Press Escape to the address view ("Your SimpleX address"), scroll down and click "Create 1-time link". Check: a 1-time link view opens. Press Escape without copying. Check: the alert "Keep unused invitation?" with "Delete" and "Keep"; click "Delete". Click "Create 1-time link" again, then click in the right pane (about 900,400). Check: the view closes and the same alert shows; click "Delete" (this closes the address screens too). (The view's closing when another client scans the link needs a second device: not tested.)

**C. Auto-accept and a known address.**

1. (R17.13) User menu → "Your SimpleX address" → "Address settings"; click the switch "Auto-accept". Check: it is on. Press Escape, click "Share address" (Check: "Copied to clipboard") and press Escape until the chat list shows. Add the profile `cicarol`; as cicarol send a request by the copied address. Check: within 60 s cicarol's chat with citester shows the message field "Message": citester accepted it without any action. Switch to citester. Check: "cicarol" is a contact in the chat list, not a request. Restart the app: `ui stop`, then `ui start /home/runner/work/_temp/app/simplex`, then `ui wait "Search or paste SimpleX link" 120`. Open user menu → "Your SimpleX address" → "Address settings". Check: "Auto-accept" is still on. Click its switch. Check: it is off. Press Escape.
2. (R17.12) In the address view click "Share address" (the restart cleared the clipboard). Press Escape until the chat list shows. Switch to cicarol and paste the address (pencil → "Paste link" → "Tap to paste link"). Check: the alert names citester with "Open chat" (the contact already exists), not "Open new chat". Click "Open chat". Check: the existing chat with citester opens.

**D. Rejecting by the chat menu.**

1. (R17.11) Add the profile `cidan`; as cidan send a request by the copied address. Switch to citester. Check: "cidan" shows in the chat list as a request. Right-click it → "Reject". Check: "cidan" is gone from citester's chat list.

**E. The address in contact and member info.**

1. (R17.17a) Switch to cibob, open "citester", open chat info. Check: the info has the section "Address" with a QR code and "Share address" (citester shares the address with contacts since R17.16).
2. (R17.17b) Switch to citester. Pencil → "Create group". Click the field about 40 px below "Enter group name", type `ci addr group`, click "Create group" (the lower one). In "Invite members" click "cibob" to select it, then click "Invite to group". Switch to cibob, open "citester": the chat shows "You are invited to group" with "Tap to join"; click "Tap to join" and wait up to 60 s until "ci addr group" is in cibob's chat list. Open "ci addr group", open its info, click the member "citester". Check: the member's info has the section "Address" (cibob has citester as a contact).
3. (R17.17c) Switch to citester, open "ci addr group" → info → "Create group link" → "Create link" → "Share link" (Check: "Copied to clipboard"). Press Escape until the chat list shows. Switch to cidan; pencil → "Paste link" → "Tap to paste link". Check: the alert names "ci addr group" with "Open group"; click it. The chat shows "Tap Join group" and "Join group" at the bottom: click "Join group" and wait up to 60 s until the bottom shows the message field "Message". Open the group's info and click the member "citester". Check: the member's info has no "Address" section (cidan has no contact with citester).

You have at most 600 turns, and the whole test fits in about 130 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click 27 730 -- click-text "Your SimpleX address" 10 -- click-text "Address settings" 10 -- shot address-settings`
- `ui do click 363 730 -- click-text "Paste link" 10 -- click-text "Tap to paste link" 10 -- wait "Open" 60 -- shot alert`

`ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Take a shot at each check, named after its case (`ui shot R17-16`).

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. It has one row per case ID, in this order: S1, S2, R17.15, R17.16, R17.14, R17.18, R17.13, R17.12, R17.11, R17.17a, R17.17b, R17.17c; each with PASS, FAIL or SKIPPED (with the reason) and its evidence (the text OCR read, screenshot names). A case the app cannot do on this platform is SKIPPED, not FAIL. Add anything else unexpected below the table. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the failed cases.

## The ui helper
