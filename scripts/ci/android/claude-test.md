# Test: chat profiles, profiles of new connections, self-destruct passcode, deleting the database and the last profile in the SimpleX Chat Android app

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text, with their states (checked, enabled).

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button.
- Besides the chats, the chat list shows the app's own cards as list items until they are closed. Leave them open.
- Contacts connect through the app's preset servers on the internet: wait up to 120 s for a connection (`ui wait "<text>" 120`).

## How to do things in the app

- **Restart the app:** `ui relaunch`. It waits up to 90 s for the chat list ("Start new chat"); when a passcode screen or an onboarding screen shows first it may report an error: that is expected where a step says so; take a shot and continue from the screen.
- **Profile menu:** tap your profile picture at the left end of the bottom toolbar (`profile image placeholder` in the tree, the one with the largest y). The sheet lists your profiles by name in a row at its top (the active one first, then the others, most recently used first), then "Your chat profiles", …, "Settings". Tap another profile's name to switch to it; `ui key BACK` closes the sheet.
- **Settings:** profile menu → "Settings". Rows used here: "Your privacy" → "SimpleX Lock", and "Chat data" → "Database passphrase & export". `ui key BACK` goes back one level.
- **Passcode screens** ("New Passcode", "Confirm passcode", "Set passcode", "Enter Passcode", "Current Passcode", or a title naming the action): tap the digits of the on-screen pad (`ui click-text 1`, …), then the button under the pad ("Save", "Confirm" or "Submit"; disabled until at least 4 digits are entered) or "Cancel". The key right of 0 (no text) deletes the last digit.
- **Passphrase fields** ("New passphrase…", "Confirm new passphrase…"): tap the field, then `ui type <text>`.
- **Add a profile:** profile menu → "Your chat profiles" → "Add profile". On "Create profile" the name field has the focus: type the name, check it in the tree, tap "Create profile". The new profile becomes the active one; `ui key BACK` until the chat list shows.
- **"Your chat profiles"** lists the visible profiles under a search field "Search". When it opens with more than one profile, an alert "Make profile private!" may show: tap "OK". Tapping a profile's row makes it active; long-pressing it (`ui long-press <x> <y>` at its name) opens its menu ("Hide", "Unhide", "Mute", "Delete").
- **New 1-time link:** "Start new chat" → "Create 1-time link". The link shows under "Share this 1-time invite link"; right of its "…" are two buttons without text: copy, then share. Tap the copy button (the left one; find it in `ui tree`). Below the QR code, "Share profile" shows the profile the link belongs to: tapping that row opens "Select chat profile", which lists your profiles and "Incognito"; tapping one moves the link to it (choosing another profile also makes that profile the active one) and returns to the link. A pending link shows in the chat list as "invited to connect", with "you shared one-time link" (or "you shared one-time link incognito") under it.
- **Connect by a copied link:** "Start new chat" → "Paste link / Scan" → "Tap to paste link". An alert shows the name of the profile that made the link and "Open new chat": tap it. The chat opens with a "Connect" bar at the bottom: tap it.

## Passcodes and passwords used

- App passcode `1234`. Self-destruct passcode `2468`, changed to `1357` in R23.10; after the self-destruct the app passcode is `1357`. In R23.11 the self-destruct passcode is `2468`, changed to `8642`; after it the app passcode is `8642`.
- Database passphrase in R23.11: `cipass1`.
- Hidden profile passwords: cibob `cihide1`, cicarol `cihide2`.

## The test

The cases build on each other: run them in this order. Each case ID is the row of the test table (R…) or a setup step (S…). Take a shot at each check, named after its case (`ui shot R64-7`).

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Get started": click it. Click the field "Enter profile name…", type `citester`, and click "Create profile". On "Your network", click "Continue". The app explains instant notifications in an alert: click "Allow"; if Android then asks whether the app may always run in the background, click "Allow" again. Click "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone" while there are no conversations.
2. (S2) Add the profile `cibob`, then the profile `cicarol`. Check: cicarol is the active profile.

**P. Profiles.**

3. (R64.2) Open the profile menu. Check: the row of profiles is "cicarol", "cibob", "citester" from left to right (the active one, then the others by their last use, most recent first; compare their x). Tap "citester". Open the profile menu again. Check: now "citester", "cicarol", "cibob". `ui key BACK`.
4. (R64.7) As citester: "Start new chat" → "Create 1-time link". Check: "Share profile" shows "citester". Tap that row; in "Select chat profile" tap "cibob". Check: "Share profile" now shows "cibob" and cibob is the active profile. Tap the copy button; `ui key BACK` until the chat list shows. Check: cibob's chat list shows "invited to connect" with "you shared one-time link"; switch to citester: its chat list shows no pending link. Switch to cicarol and connect by the copied link. Check: the alert names "cibob". After "Connect", wait up to 120 s, send `hi from cicarol` (tap the message field, type, tap the send button at its right end). Switch to cibob. Check: cibob's chat list shows "cicarol" (no longer "invited to connect"), and the chat shows "hi from cicarol".
5. (R64.9) As cibob: "Start new chat" → "Create 1-time link" → tap the "Share profile" row → "citester". Check: "Share profile" shows "citester" and citester is now the active profile. Tap the row again → "Incognito". Check: "Share profile" shows "Incognito" with the footer "A new random profile will be shared.". `ui key BACK` until the chat list shows. Check: citester's chat list shows "invited to connect" with "you shared one-time link incognito"; cibob's chat list (switch to it, then back to citester) shows no new pending link.
6. (R64.10) As citester: "Start new chat" → "Create 1-time link". Check: "Share profile" shows "Incognito" (the choice is remembered). Tap it → "cicarol". Check: it shows "cicarol", the footer is gone, and cicarol is the active profile. `ui key BACK` until the chat list shows. Check: cicarol's chat list shows a new "invited to connect" with "you shared one-time link". Then, as cicarol: "Start new chat" → "Create 1-time link". Check: "Share profile" shows "cicarol" (not incognito: the choice is remembered). Tap it → "Incognito", then tap it again → "cibob". Check: it shows "cibob", without the incognito footer, and cibob is active. `ui key BACK` until the chat list shows. Check: cibob's chat list shows a new "invited to connect" with "you shared one-time link" (not incognito). Write in the evidence which profile holds each pending link.
7. (R64.4) Switch to citester. Tap the signal icon right of the title "Chats" in the bottom toolbar (no text; find it in `ui tree`): "Servers info" opens. Check: it offers "Showing info for" with "All profiles" (three visible profiles). `ui key BACK`. Open "Your chat profiles" (close "Make profile private!" with "OK" if it shows). Long-press "cibob" → "Hide"; on "Hide profile" tap "Password to show", type `cihide1`, tap "Confirm password", type `cihide1`, tap "Save profile password". Do the same for "cicarol" with `cihide2`. Check: only "citester" is listed. `ui key BACK` until the chat list shows, and open "Servers info" again. Check: "Showing info for" and "All profiles" are gone; note the "Messages sent" and "Messages received" numbers it shows (they are citester's alone). `ui key BACK`.
8. (R64.5) Open "Your chat profiles". Tap the "Search" field and type `cihide2`. Check: "cicarol" is listed. Tap it. Check: cicarol becomes the active profile. Open "Your chat profiles" again; long-press "cicarol" → "Unhide". Check: "Unhide profile" opens with a "Profile password" field and "Unhide chat profile"; type `cihide2` in the field and tap "Unhide chat profile". Check: back in "Your chat profiles", "cicarol" is listed without a search. Then long-press "cicarol" → "Delete". Check: the alert "Delete chat profile?" with "All chats and messages will be deleted - this cannot be undone!" offers "Profile and server connections" and "Local profile data only"; tap "Profile and server connections". Check: cicarol is gone from the list and citester is the active profile.

**L. Self-destruct passcode (as citester).**

9. (S3) Settings → "Your privacy" → "SimpleX Lock" → "Lock mode" → "Passcode"; turn "Enable lock" on; on "New Passcode" enter `1234`, "Save", `1234`, "Confirm"; tap "OK" in "Passcode set!". Check: the section "Self-destruct passcode" with "Enable self-destruct" shows.
10. (R23.10) Turn "Enable self-destruct" on. Check: "Current Passcode" ("Change self-destruct mode") asks; enter `1234`, "Submit". Check: "Set passcode" with "Enable self-destruct passcode"; enter `1234`, check "Save" stays disabled (the app passcode can't be the self-destruct passcode); delete the digits, enter `2468`, "Save", `2468`, "Confirm". Check: the alert "Self-destruct passcode enabled!" with "If you enter this passcode when opening the app, all app data will be irreversibly removed!". Tap "OK". Tap the field under "New display name:" and type `cisd`. Tap "Change self-destruct passcode"; enter `1234`, "Submit"; on the next screen enter `1357`, "Save", `1357`, "Confirm". Check: the alert "Self-destruct passcode changed!". `ui relaunch` (an error is expected). Check: "Enter Passcode" asks before the chat list; enter `1234`, "Submit": citester's chats show ("cibob", the pending links). `ui relaunch` again; enter `1357`, "Submit". Check: the app opens with a new empty profile "cisd": no chats, and "Your chat profiles" lists only "cisd".
11. (R23.11) As cisd: Settings → "Chat data" → "Database passphrase & export" → "Database passphrase". Type `cipass1` in "New passphrase…" and "Confirm new passphrase…", tap "Update database passphrase", then "Update" (the chat stops: if a passcode screen asks, enter `1357`, "Submit"); tap "OK" after "Database encrypted!". Tap the switch of "Save passphrase in Keystore" → "Remove". Check: the footer says "You have to enter passphrase every time the app starts - it is not stored on the device.". Then Settings → "Your privacy" → "SimpleX Lock" → turn "Enable self-destruct" on: enter `1357`, "Submit"; set `2468` ("Save", `2468`, "Confirm"), tap "OK"; type `cisd2` under "New display name:"; "Change self-destruct passcode": `1357`, "Submit", `8642`, "Save", `8642`, "Confirm", "OK". `ui relaunch` (an error is expected). Check: the passcode screen shows (if the passphrase screen "Encrypted database" shows first, note it as a finding, type `cipass1` in "Enter passphrase…", tap "Open chat"). Enter `8642`, "Submit". Check: the app opens with a new empty profile "cisd2" and was not asked for the database passphrase.
12. (S4) Settings → "Your privacy" → "SimpleX Lock" → turn "Enable lock" off; enter `8642`, "Submit". Check: the switch is off.

**D. Deleting the database and the last profile.**

13. (R42.3) Settings → "Chat data" → "Database passphrase & export" → "Delete database". Check: the alert "Delete chat profile?" with "This action cannot be undone - your profile, contacts, messages and files will be irreversibly lost." and "Delete"; tap "Delete". Check: the alert "Chat database deleted" with "Restart the app to create a new chat profile.". Tap "OK". `ui relaunch` (an error is expected). Check: the app shows its first onboarding screen ("Get started").
14. (S5) Onboarding again, as in S1, with the name `citester`.
15. (R64.6) Profile menu → "Your chat profiles" → long-press "citester" → "Delete" → "Profile and server connections". Check: no profile is left: the app returns to its first onboarding screen ("Get started").

You have at most 600 turns, and the whole test fits in about 190 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Get started" -- click-text "Enter profile name" 30 -- type citester -- shot profile`
- `ui do click-text "Start new chat" -- click-text "Create 1-time link" 10 -- wait "Share profile" 60 -- shot link`
- `ui do click-text 1 -- click-text 2 -- click-text 3 -- click-text 4 -- click-text Save -- wait "Confirm passcode" -- shot confirm`
- `ui do relaunch -- shot after-restart`

`ui do` stops at the first command that fails, so a failed chain tells you where it stopped (a `relaunch` that reports an error stops the chain).

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per case ID (S1 to S5, then R64.2, R64.7, R64.9, R64.10, R64.4, R64.5, R23.10, R23.11, R42.3, R64.6), each as PASS, FAIL or SKIPPED (with the reason; a case the app cannot do on this platform is SKIPPED, not FAIL), with its evidence (the text on screen, screenshot names), and anything else unexpected. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
