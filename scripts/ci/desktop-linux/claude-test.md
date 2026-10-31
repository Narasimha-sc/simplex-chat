# Test: chat profiles, profiles of new connections, self-destruct passcode, deleting the database and the last profile in the SimpleX Chat desktop app

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons or the state of switches; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

## What is set up

- The app is already running, on its first screen, with a new, empty database. Begin with `ui shot start` to see it.
- After onboarding, the chat list is in the left pane (x 1 to 389) and chats open in the right pane. The toolbar is at the bottom of the left pane: the profile picture at about 27,730, the title "Chats" with a small signal icon right of it, and a pencil (New chat) at about 363,730.
- Contacts connect through the app's preset servers on the internet: wait up to 120 s for a connection (`ui wait "<text>" 120`).

## How to do things in the app

- **Restart the app** (only where a step says so): `ui stop`, then `ui start <app dir>`, where `<app dir>` is the folder `app/simplex` next to your working directory: your working directory is `<RUNNER_TEMP>/claude-test` and the app is `<RUNNER_TEMP>/app/simplex`; on GitHub's runners that is `ui start /home/runner/work/_temp/app/simplex`. Type the path literally (the helper refuses `$`). `ui start` returns when the window shows; then `ui shot` to see which screen the app opened with. If after a restart the app shows its first onboarding screen ("Create your profile") where the step expects something else, check whether the step expects it; if not, the restart lost the app's data: write that under "Harness notes" and mark the cases that need a restart SKIPPED.
- **Profile menu:** click the profile picture (about 27,730). It shows the active profile at the top, then the other profiles by name (click one to switch to it), "Your chat profiles" and "Settings". Escape closes it.
- **Settings:** profile menu → "Settings". Rows used here: "Your privacy" → "SimpleX Lock", and "Chat data" → "Database passphrase & export". Press Escape to go back one level.
- **Passcode screens** ("New Passcode", "Confirm passcode", "Set passcode", "Enter Passcode", "Current Passcode", or a title naming the action): type the digits with `ui type <digits>`, then click the button at the bottom right ("Save", "Confirm" or "Submit"; disabled until at least 4 digits are entered) or "Cancel".
- **Passphrase fields** ("Current passphrase…", "New passphrase…", "Confirm new passphrase…"): click the field, then `ui type <text>`.
- **Add a profile:** profile menu → "Your chat profiles" → "Add profile". On "Create profile", click the field about 40 px below the text "Enter your name:", type the name, and click the "Create profile" button (the lower of the two "Create profile" texts). The new profile becomes the active one; press Escape until the chat list shows.
- **"Your chat profiles"** lists the visible profiles under a search field "Search". When it opens with more than one profile, an alert "Make profile private!" may show: click "OK". Clicking a profile's row makes it active; right-clicking it opens its menu ("Hide", "Unhide", "Mute", "Delete").
- **New 1-time link:** pencil → "Create 1-time link". The link shows under "Share this 1-time invite link"; clicking the link's text copies it (toast "Copied to clipboard"). Below the QR code, "Share profile" shows the profile the link belongs to: clicking that row opens "Select chat profile", which lists your profiles and "Incognito"; clicking one moves the link to it (choosing another profile also makes that profile the active one) and returns to the link. A pending link shows in the chat list as "invited to connect", with "you shared one-time link" (or "you shared one-time link incognito") under it.
- **Connect by a copied link:** pencil → "Paste link" → "Tap to paste link". An alert shows the name of the profile that made the link and "Open new chat": click it. The chat opens with a "Connect" bar at the bottom: click it.

## Passcodes and passwords used

- App passcode `1234`. Self-destruct passcode `2468`, changed to `1357` in R23.10; after the self-destruct the app passcode is `1357`. In R23.11 the self-destruct passcode is `2468`, changed to `8642`; after it the app passcode is `8642`.
- Database passphrase in R23.11: `cipass1`.
- Hidden profile passwords: cibob `cihide1`, cicarol `cihide2`.

## The test

The cases build on each other: run them in this order. Each case ID is the row of the test table (R…) or a setup step (S…). Take a shot at each check, named after its case (`ui shot R64-7`).

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone".
2. (S2) Add the profile `cibob`, then the profile `cicarol`. Check: cicarol is the active profile (its name is at the top of the profile menu).

**P. Profiles.**

3. (R64.2) Open the profile menu. Check: the other profiles are listed in the order of their last use, the most recent first: "cibob" above "citester". Click "citester". Open the profile menu again. Check: now "cicarol" is above "cibob". Press Escape.
4. (R64.7) As citester: pencil → "Create 1-time link". Check: "Share profile" shows "citester". Click that row; in "Select chat profile" click "cibob". Check: "Share profile" now shows "cibob" and the profile menu's active profile is cibob. Click the link's text (toast "Copied to clipboard"); press Escape until the chat list shows. Check: cibob's chat list shows "invited to connect" with "you shared one-time link"; switch to citester: its chat list shows no pending link. Switch to cicarol and connect by the copied link. Check: the alert names "cibob". After "Connect", wait up to 120 s, send `hi from cicarol`. Switch to cibob. Check: cibob's chat list shows "cicarol" (no longer "invited to connect"), and the chat shows "hi from cicarol".
5. (R64.9) As cibob: pencil → "Create 1-time link" → click the "Share profile" row → "citester". Check: "Share profile" shows "citester" and citester is now the active profile. Click the row again → "Incognito". Check: "Share profile" shows "Incognito" with the footer "A new random profile will be shared.". Press Escape until the chat list shows. Check: citester's chat list shows "invited to connect" with "you shared one-time link incognito"; cibob's chat list (switch to it, then back to citester) shows no new pending link.
6. (R64.10) As citester: pencil → "Create 1-time link". Check: "Share profile" shows "Incognito" (the choice is remembered). Click it → "cicarol". Check: it shows "cicarol", the footer is gone, and cicarol is the active profile. Press Escape until the chat list shows. Check: cicarol's chat list shows a new "invited to connect" with "you shared one-time link". Then, as cicarol: pencil → "Create 1-time link". Check: "Share profile" shows "cicarol" (not incognito: the choice is remembered). Click it → "Incognito", then click it again → "cibob". Check: it shows "cibob", without the incognito footer, and cibob is active. Press Escape until the chat list shows. Check: cibob's chat list shows a new "invited to connect" with "you shared one-time link" (not incognito). Write in the evidence which profile holds each pending link.
7. (R64.4) Switch to citester. Click the signal icon right of "Chats" in the toolbar: "Servers info" opens. Check: it offers "Showing info for" with "All profiles" (three visible profiles). Press Escape. Open "Your chat profiles" (close "Make profile private!" with "OK" if it shows). Right-click "cibob" → "Hide"; on "Hide profile" click "Password to show", type `cihide1`, click "Confirm password", type `cihide1`, click "Save profile password". Do the same for "cicarol" with `cihide2`. Check: only "citester" is listed. Press Escape until the chat list shows, and open "Servers info" again. Check: "Showing info for" and "All profiles" are gone; note the "Messages sent" and "Messages received" numbers it shows (they are citester's alone). Press Escape.
8. (R64.5) Open "Your chat profiles". Click the "Search" field and type `cihide2`. Check: "cicarol" is listed. Click it. Check: cicarol becomes the active profile (profile menu). Open "Your chat profiles" again; right-click "cicarol" → "Unhide". Check: "Unhide profile" opens with a "Profile password" field and "Unhide chat profile"; type `cihide2` in the field and click "Unhide chat profile". Check: back in "Your chat profiles", "cicarol" is listed without a search. Then right-click "cicarol" → "Delete". Check: the alert "Delete chat profile?" with "All chats and messages will be deleted - this cannot be undone!" offers "Profile and server connections" and "Local profile data only"; click "Profile and server connections". Check: cicarol is gone from the list and citester is the active profile.

**L. Self-destruct passcode (as citester).**

9. (S3) Settings → "Your privacy" → "SimpleX Lock" → turn "Enable lock" on; on "New Passcode" type `1234`, "Save", `1234`, "Confirm"; click "OK" in "Passcode set!". Check: the section "Self-destruct passcode" with "Enable self-destruct" shows.
10. (R23.10) Turn "Enable self-destruct" on. Check: "Current Passcode" ("Change self-destruct mode") asks; type `1234`, "Submit". Check: "Set passcode" with "Enable self-destruct passcode"; type `1234`, check "Save" stays disabled (the app passcode can't be the self-destruct passcode); clear it (`ui key BackSpace` four times), type `2468`, "Save", `2468`, "Confirm". Check: the alert "Self-destruct passcode enabled!" with "If you enter this passcode when opening the app, all app data will be irreversibly removed!". Click "OK". Click the field under "New display name:" and type `cisd`. Click "Change self-destruct passcode"; type `1234`, "Submit"; on the next screen type `1357`, "Save", `1357`, "Confirm". Check: the alert "Self-destruct passcode changed!". Restart the app. Check: "Enter Passcode" asks before the chat list; type `1234`, "Submit": citester's chats show ("cibob", the pending links). Restart the app again; type `1357`, "Submit". Check: the app opens with a new empty profile "cisd" (profile menu): no chats, and "Your chat profiles" lists only "cisd".
11. (R23.11) As cisd: Settings → "Chat data" → "Database passphrase & export" → "Database passphrase". Type `cipass1` in "New passphrase…" and "Confirm new passphrase…", click "Update database passphrase", then "Update" (the chat stops: if a passcode screen asks, type `1357`, "Submit"); click "OK" after "Database encrypted!". Click the switch of "Save passphrase in settings" → "Remove". Check: the footer says "You have to enter passphrase every time the app starts - it is not stored on the device.". Then Settings → "Your privacy" → "SimpleX Lock" → turn "Enable self-destruct" on: type `1357`, "Submit"; set `2468` ("Save", `2468`, "Confirm"), click "OK"; type `cisd2` under "New display name:"; "Change self-destruct passcode": `1357`, "Submit", `8642`, "Save", `8642`, "Confirm", "OK". Restart the app. Check: the passcode screen shows (if the passphrase screen "Encrypted database" shows first, note it as a finding, type `cipass1`, click "Open chat"). Type `8642`, "Submit". Check: the app opens with a new empty profile "cisd2" and was not asked for the database passphrase.
12. (S4) Settings → "Your privacy" → "SimpleX Lock" → turn "Enable lock" off; type `8642`, "Submit". Check: the switch is off.

**D. Deleting the database and the last profile.**

13. (R42.3) Settings → "Chat data" → "Database passphrase & export" → "Delete database". Check: the alert "Delete chat profile?" with "This action cannot be undone - your profile, contacts, messages and files will be irreversibly lost." and "Delete"; click "Delete". Check: the alert "Chat database deleted" with "Restart the app to create a new chat profile.". Click "OK". Restart the app. Check: the app starts at its first onboarding screen ("Create your profile").
14. (S5) Onboarding again, as in S1, with the name `citester`.
15. (R64.6) Profile menu → "Your chat profiles" → right-click "citester" → "Delete" → "Profile and server connections". Check: no profile is left: the app shows its no-profile state, with the profile menu offering "Create chat profile" (take a shot of the whole window).

You have at most 600 turns, and the whole test fits in about 190 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Create your profile" -- wait "Enter profile name" -- click-text "Enter profile name" -- type citester -- shot profile`
- `ui do click 363 730 -- click-text "Create 1-time link" 10 -- wait "Share profile" 60 -- shot link`
- `ui do type 1234 -- click-text Save -- wait "Confirm passcode" -- type 1234 -- click-text Confirm -- shot passcode-set`
- `ui do stop -- start /home/runner/work/_temp/app/simplex -- shot after-restart`

`ui do` stops at the first command that fails, so a failed chain tells you where it stopped.

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per case ID (S1 to S5, then R64.2, R64.7, R64.9, R64.10, R64.4, R64.5, R23.10, R23.11, R42.3, R64.6), each as PASS, FAIL or SKIPPED (with the reason; a case the app cannot do on this platform is SKIPPED, not FAIL), with its evidence (the text OCR read, screenshot names), and anything else unexpected. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
