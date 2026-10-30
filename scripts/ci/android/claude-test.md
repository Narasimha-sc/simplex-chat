# Test: the contact address and its settings in the SimpleX Chat Android app (checklist batch B02-2)

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields, switches ("checkable", "checked") and buttons that have no text.

Each case ID is `R<row>`, the row of the manual checklist it comes from; `S<n>` is a setup step.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button; it closes one screen at a time.
- The test uses four profiles of this app: citester, cibob, cicarol and cidan. They talk through the app's preset servers on the internet: a connection takes a few seconds to a minute, so wait up to 60 s for it (`ui wait "<text>" 60`).
- Never open, connect to or message "Ask SimpleX Team" (listed in "New chat") or any other preset contact, group or channel: they reach real people.

## How to do things in the app

- **User menu:** tap the profile image at the left end of the bottom toolbar (the "profile image placeholder" with the largest y). The menu lists the profiles by name at the top (tap another name to switch to it), then "Create SimpleX address" (or "Your SimpleX address"), "Chat preferences", "Your chat profiles" and "Settings".
- **Add a profile:** user menu → "Your chat profiles" → "Add profile". The name field below "Enter your name:" has the focus: type the name and tap "Create profile" (the button, the lower of the two texts). The new profile becomes the active one; press BACK until its chat list shows. If the alert "Make profile private!" shows, tap "OK".
- **The address:** user menu → "Your SimpleX address". It shows a QR code, "Share address", "Address settings", and further down "Create 1-time link" and "Delete address". "Address settings" holds the switches "Share with SimpleX contacts" and "Auto-accept" (tap the switch at the right end of the row), the field "Enter welcome message… (optional)" under "Welcome message", and "Save".
- **Copy the address or a group link:** tap "Share address" (or "Share link"): Android's share sheet opens; tap "Copy" in it (if the sheet has no "Copy", report it and skip the cases that need the copied link).
- **Copy a new 1-time link:** "Start new chat" → "Create 1-time link". Right of the link under "Share this 1-time invite link" are two icon buttons without text (`ui tree`): the first copies the link; tap it. Then press BACK until the chat list shows (the link view and "New chat" close one at a time).
- **Connect by a copied 1-time link:** "Start new chat" → "Paste link / Scan" → "Tap to paste link" → "Open new chat" in the alert → "Connect" at the bottom of the chat; wait up to 60 s until the message field "Message" shows. (The chat already holds an item "Messages, files and calls are protected…", so a wait for the text "Message" passes at once: check in the screenshot that "Connect" is gone and the message field is at the bottom.)
- **Send a request by the copied address:** "Start new chat" → "Paste link / Scan" → "Tap to paste link". The alert names citester, with "Open new chat": tap it. The chat shows "Tap Connect to send request", the field "Add message" and "Connect": tap "Connect", then "Send request without message" in the alert "Send contact request?".
- **Send a message:** tap the message field ("Message"), `ui type "<text>"`, then tap "Send Message".
- **Chat info:** tap the chat's name at the top of the chat. A group's info lists its members; tapping one opens the member's info.

## The test

Run the parts in this order; each builds on the ones before.

**A. Setup.**

1. (S1) Onboarding. The first screen has "Get started": tap it. Tap the field "Enter profile name…", type `citester`, and tap "Create profile". On "Your network", tap "Continue". The app explains instant notifications in an alert: tap "Allow"; Android then asks whether the app may always run in the background: tap "Allow" again. Tap "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone".
2. (S2) As citester, copy a new 1-time link. Add the profile `cibob`; as cibob connect by the link and send `hello citester`. Switch to citester. Check: the chat list shows "cibob".

**B. Creating and sharing the address (citester).**

1. (R17.15) User menu → "Create SimpleX address" → "Create SimpleX address". Check: the alert "Share address with SimpleX contacts?" says "Add address to your profile, so that your SimpleX contacts can share it with other people. Profile update will be sent to your SimpleX contacts." and has "Share" and "Cancel". Tap "Share". Check: the address view shows the QR code.
2. (R17.16) Tap "Address settings". Check: "Share with SimpleX contacts" is on ("checked" in `ui tree`). Tap its switch. Check: the alert "Stop sharing address?" says "Profile update will be sent to your SimpleX contacts." with "Stop sharing" and "Cancel"; tap "Cancel". Check: the switch is on again. Tap it again and then "Stop sharing". Check: it is off. Tap it once more. Check: the alert "Share address with SimpleX contacts?" with "Share"; tap "Share". Check: it is on.
3. (R17.14) Still in "Address settings", tap the field "Enter welcome message… (optional)" and type `hello from the address`. `ui key BACK` (once more if the first BACK only hid the keyboard). Check: the alert "Save settings?" with "Save SimpleX address settings" and "Exit without saving"; tap "Exit without saving". Open "Address settings" again. Check: the field is empty (nothing was saved).
4. (R17.18) `ui key BACK` to the address view ("Your SimpleX address"), scroll down and tap "Create 1-time link". Check: a 1-time link view opens. `ui key BACK` without copying. Check: the alert "Keep unused invitation?" with "Delete" and "Keep"; tap "Delete". (The view's closing when another client scans the link needs a second device: not tested.)

**C. Auto-accept and a known address.**

1. (R17.13) Press BACK to the address view if needed, then "Address settings"; tap the switch "Auto-accept". Check: it is on. `ui key BACK`, copy the address (How to) and press BACK until the chat list shows. Add the profile `cicarol`; as cicarol send a request by the copied address. Check: within 60 s cicarol's chat with citester shows the message field "Message": citester accepted it without any action. Switch to citester. Check: "cicarol" is a contact in the chat list, not a request. Run `ui relaunch`. Open user menu → "Your SimpleX address" → "Address settings". Check: "Auto-accept" is still on. Tap its switch. Check: it is off. `ui key BACK`.
2. (R17.12) In the address view copy the address again. Press BACK until the chat list shows. Switch to cicarol and paste the address ("Start new chat" → "Paste link / Scan" → "Tap to paste link"). Check: the alert names citester with "Open chat" (the contact already exists), not "Open new chat". Tap "Open chat". Check: the existing chat with citester opens.

**D. The address in contact and member info.**

1. (R17.17a) Switch to cibob, open "citester", open chat info. Check: the info has the section "Address" with a QR code and "Share address" (citester shares the address with contacts since R17.16).
2. (R17.17b) Switch to citester. "Start new chat" → "Create group". Type `ci addr group` in the focused name field and tap "Create group". In "Invite members" tap "cibob" to select it, then tap "Invite to group". Switch to cibob, open "citester": the chat shows "You are invited to group" with "Tap to join"; tap "Tap to join" and wait up to 60 s until "ci addr group" is in cibob's chat list. Open "ci addr group", open its info, tap the member "citester". Check: the member's info has the section "Address" (cibob has citester as a contact).
3. (S3) Add the profile `cidan`.
4. (R17.17c) Switch to citester, open "ci addr group" → info → "Create group link" → "Create link"; copy the link ("Share link" → "Copy"). Press BACK until the chat list shows. Switch to cidan; "Start new chat" → "Paste link / Scan" → "Tap to paste link". Check: the alert names "ci addr group" with "Open group"; tap it. The chat shows "Tap Join group" and "Join group" at the bottom: tap "Join group" and wait up to 60 s until the bottom shows the message field "Message". Open the group's info and tap the member "citester". Check: the member's info has no "Address" section (cidan has no contact with citester).

You have at most 600 turns, and the whole test fits in about 125 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Your SimpleX address" 10 -- click-text "Address settings" 10 -- shot address-settings`
- `ui do click-text "Start new chat" -- click-text "Paste link / Scan" 10 -- click-text "Tap to paste link" 10 -- wait "Open" 60 -- shot alert`

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. It has one row per case ID, in this order: S1, S2, R17.15, R17.16, R17.14, R17.18, R17.13, R17.12, R17.17a, R17.17b, S3, R17.17c; each with PASS, FAIL or SKIPPED (with the reason) and its evidence (the text read, screenshot names). A case the app cannot do on this platform is SKIPPED, not FAIL. Add anything else unexpected below the table. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the failed cases.

## The ui helper
