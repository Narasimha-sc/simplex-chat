# Test: SimpleX Lock, the chat database and its passphrase, message deletion and hidden profiles in the SimpleX Chat Android app

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text, with their states (checked, enabled).

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button, `ui key HOME` its home button, `ui key APP_SWITCH` its recent-apps button.
- Besides the chats, the chat list shows the app's own cards as list items until they are closed. Leave them open.
- The emulator has no screen lock, fingerprint or face enrolled: Android's own ("System") authentication is unavailable here, by design of this test.
- Contacts connect through the app's preset servers on the internet: wait up to 120 s for a connection (`ui wait "<text>" 120`).

## How to do things in the app

- **Restart the app:** `ui relaunch`. It waits up to 90 s for the chat list ("Start new chat"); when a passcode or passphrase screen shows first it may report an error: that is expected where a step says so; take a shot and continue from the screen.
- **Profile menu:** tap your profile picture at the left end of the bottom toolbar (`profile image placeholder` in the tree, the one with the largest y). The sheet lists your profiles by name in a row at its top, then "Your chat profiles", …, "Settings". Tap another profile's name to switch to it; `ui key BACK` closes the sheet.
- **Settings:** profile menu → "Settings". Rows used here: "Your privacy" → "SimpleX Lock" (its value shows "Off", "System" or "Passcode"), and "Chat data" → "Database passphrase & export". `ui key BACK` goes back one level.
- **Passcode screens** ("New Passcode", "Confirm passcode", "Enter Passcode", "Current Passcode", or a title naming the action): tap the digits of the on-screen pad (`ui click-text 1`, …), then the button under the pad ("Save", "Confirm" or "Submit"; it stays disabled until at least 4 digits are entered) or "Cancel". The entered digits show as dots.
- **Passphrase fields** ("Current passphrase…", "New passphrase…", "Confirm new passphrase…", "Enter passphrase…"): tap the field, then `ui type <text>`. The eye button at the right end of each field has no text: find it in `ui tree`; it shows or hides the field's text.
- **Add a profile:** profile menu → "Your chat profiles" → "Add profile". On "Create profile" the name field has the focus: type the name, check it in the tree, tap "Create profile". The new profile becomes the active one; `ui key BACK` until the chat list shows.
- **"Your chat profiles"** lists the profiles under a search field "Search". When it opens with more than one profile, an alert "Make profile private!" may show: tap "OK". Long-press a profile's row (`ui long-press <x> <y>` at its name) to open its menu ("Hide", "Mute", "Delete" …).
- **Create a group:** "Start new chat" → "Create group". The name field under "Enter group name:" has the focus: type the name and tap "Create group". Wait for "Invite members", then `ui key BACK` until the chat list shows (tap "Skip inviting members" if it shows).
- **Connect two profiles:** as the inviting profile: "Start new chat" → "Create 1-time link"; wait for the link under "Share this 1-time invite link". Right of the link's "…" are two buttons without text: copy, then share. Tap the copy button (the left one; find it in `ui tree`). `ui key BACK` until the chat list shows. Switch to the other profile: "Start new chat" → "Paste link / Scan" → "Tap to paste link". An alert shows the inviting profile's name and "Open new chat": tap it. The chat opens with a "Connect" bar at the bottom: tap it.
- **Chat info:** tap the chat's name at the top of the chat; `ui key BACK` closes it.
- **Drop-down rows** ("Lock mode", "Lock after", "Delete messages after"): tap the row; a list of values opens; tap a value.
- **Background and back:** `ui key HOME` puts the app in the background. To bring it back without restarting it: `ui key APP_SWITCH`, then tap the SimpleX card (the large card in the middle of the screen, about 540,1200). If that does not bring the app back, report it under "Harness notes".
- **Waiting a fixed time:** `ui wait ci-no-such-text <secs>` returns after `<secs>` seconds with an error, which is expected.

## Passcodes and passphrases used

- App passcode: `1234`, changed to `5678` in R23.8. Wrong passcode: `9999`.
- Database passphrase: `cipass1` from R57.10, `cipass2` from R57.11. Wrong passphrase: `wrongpass`.
- Hidden profile password: `cihide1`.

## The test

The cases build on each other: run them in this order. Each case ID is the row of the test table (R…) or a setup step (S…). Take a shot at each check, named after its case (`ui shot R23-6`).

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Get started": click it. Click the field "Enter profile name…", type `citester`, and click "Create profile". On "Your network", click "Continue". The app explains instant notifications in an alert: click "Allow"; if Android then asks whether the app may always run in the background, click "Allow" again. Click "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone" while there are no conversations.
2. (S2) Create three groups: `ci g1`, `ci g2`, `ci g3`. Check: the chat list shows all three.
3. (S3) As citester create a 1-time link; add the profile `cibob`; as cibob connect by the copied link. Wait up to 120 s, then as cibob send `hello from cibob` in the chat "citester" (tap the message field, type, tap the send button at the right end of the field). Switch to citester. Check: citester's chat list shows "cibob", and the chat "cibob" shows "hello from cibob". citester now has 4 chats.

**P. A hidden profile.**

4. (R64.1) As citester: add the profile `cicarol`. Switch to citester. Open "Your chat profiles" (close "Make profile private!" with "OK" if it shows). Long-press the row "cicarol" → "Hide". On "Hide profile", tap "Password to show", type `cihide1`, tap "Confirm password", type `cihide1`, tap "Save profile password". Check: "cicarol" is no longer listed, and "Enter password in search" shows above the title. `ui key BACK` until the chat list shows; check the profile menu does not list cicarol.

**M. Automatic message deletion (as citester).**

5. (R58.4) Settings → "Chat data". Check: "Delete messages after" shows "never". Choose "1 month". Check: the alert "Enable automatic message deletion?" with "This action cannot be undone - the messages sent and received earlier than selected will be deleted. It may take several minutes." and the buttons "Delete messages" and "Cancel". Tap "Cancel". Check: the row shows "never" again.
6. (R58.1) Choose "1 year", then "Delete messages" in the alert. Check: within 60 s the progress indicator is gone and the row shows "1 year" (note the seconds it took, from two shots). `ui key BACK` until the chat list shows.
7. (R58.5) Open the chat "ci g1" → chat info. Check: "Delete messages after" shows "default (1 year)", with the footer "Delete chat messages from your device.". Choose "1 day". Check: the alert "Change automatic message deletion?" with "This action cannot be undone - the messages sent and received in this chat earlier than selected will be deleted." and "Delete messages"; tap it; the row shows "1 day". Then open the chat "cibob" → chat info → "Delete messages after" → "never". Check: the alert "Disable automatic message deletion?" with "Messages in this chat will never be deleted." and "Disable delete messages"; tap it; the row shows "never". The chats' messages are all younger than a day, so none is deleted: check that "hello from cibob" still shows. `ui key BACK` until the chat list shows.

**L. SimpleX Lock.**

8. (R1.16) `ui relaunch`. Check: the alert "SimpleX Lock" with "To protect your information, turn on SimpleX Lock." and "You will be prompted to complete authentication before this feature is enabled." and "Turn on" shows over the chat list (the app shows it on the first start with more than 3 chats). If it does not show, `ui relaunch` once more; if it still does not show, mark R1.16 and R23.5 FAIL and go on with R23.4. Tap "Turn on". Check: the dialog "SimpleX Lock mode" offers "Passcode entry" and "System authentication".
9. (R23.5) Tap "System authentication". Check: the alert "Authentication unavailable" with "Device authentication is not enabled. You can turn on SimpleX Lock via Settings, once you enable device authentication.". Tap "OK". Check (Settings → "Your privacy"): "SimpleX Lock" shows "Off".
10. (R23.4) Tap "SimpleX Lock". Check: "Lock mode" shows "System". Tap the switch of "Enable lock". Check: the same alert "Authentication unavailable" shows, and after "OK" the switch is off (`ui tree`: not checked).
11. (R23.6) "Lock mode" → "Passcode". Tap the switch of "Enable lock". Check: "New Passcode" shows. Enter `1234`, "Save". Check: "Confirm passcode" shows; enter `1235`: "Confirm" stays disabled. Tap the clear key (the key left of 0, no text) or the backspace key (right of 0) to clear, enter `1234`, tap "Confirm". Check: the alert "Passcode set!" with "Please remember or store it securely - there is no way to recover a lost password!"; tap "OK"; the switch is on, "Lock after" shows "30 seconds" and "Change passcode" is listed. `ui key BACK` until the chat list shows. Then profile menu → "Your chat profiles" → "Add profile". Check: a passcode screen titled "Change chat profiles" with "Log in using your credential" shows before "Create profile". Leave it open for R23.2.
12. (R23.2) Enter `9999`, tap "Submit". Check: "Create profile" does not open; the screen offers "Unlock". Tap "Unlock", enter `1234`, tap "Submit". Check: "Create profile" opens. `ui key BACK` until the chat list shows, without creating a profile.
13. (R23.3) Settings → "Your privacy" → "SimpleX Lock". Tap the switch of "Enable lock" to turn it off. Check: a passcode screen ("Enter Passcode", "Disable SimpleX Lock") shows. Tap "Cancel". Check: the alert "Authentication failed" with "You could not be verified; please try again."; after "OK" the switch is on again.
14. (R23.9) "Lock mode" → "System". Check: a passcode screen ("Enter Passcode", "Change lock mode") shows; enter `1234`, "Submit". Check: the switch to System authentication fails here: the alert "Authentication failed" shows, and "Lock mode" still shows "Passcode". (Switching is offered both ways; System authentication itself is unavailable on this emulator.)
15. (R23.8) Tap "Change passcode". Check: "Current Passcode" ("Change passcode") shows; enter `1234`, "Submit". Check: "New Passcode" with "App passcode" shows; enter `5678`, "Save", then `5678`, "Confirm". Check: the alert "Passcode changed!". Tap "OK".
16. (R23.7) Tap "Lock after". Check: it offers "10 seconds", "30 seconds", "1 minutes", "3 minutes", "10 minutes" and "Immediately". Choose "10 seconds". `ui key BACK` until the chat list shows. `ui key HOME`, wait 20 s (`ui wait ci-no-such-text 20`), and bring the app back (see "Background and back"). Check: the app asks for the passcode; enter `5678`, "Submit": the chat list shows. Then Settings → "Your privacy" → "SimpleX Lock" → "Lock after" → "3 minutes"; `ui key BACK` until the chat list shows; `ui key HOME`, wait 20 s, bring the app back. Check: the chat list shows without a passcode screen.
17. (R23.1) `ui relaunch` (an error is expected). Check: the app asks for the passcode ("Enter Passcode", "Unlock") before the chat list. Enter `5678`, "Submit". Check: the chat list shows. Turning the lock on and off, resuming from the background and the passcode on opening a sheet were checked in R23.6, R23.3, R23.7 and R23.2: cite them.
18. (S4) Settings → "Your privacy" → "SimpleX Lock" → turn "Enable lock" off; on the passcode screen enter `5678`, "Submit". Check: the switch is off and "SimpleX Lock" shows "Off" in "Your privacy". `ui key BACK` until the chat list shows.

**D. The chat database (as citester).**

19. (R42.1) Settings → "Chat data" → "Database passphrase & export". Under "Run chat", tap the switch of "Chat is running". Check: the alert "Stop chat?" with "Stop chat to export, import or delete chat database. You will not be able to receive and send messages while the chat is stopped."; tap "Stop". Check: the row says "Chat is stopped" and the footer "You must use the most recent version of your chat database on one device ONLY, otherwise you may stop receiving the messages from some contacts." shows. `ui key BACK` twice to Settings. Check: "Your privacy", "Notifications", "Network & servers" and "Audio & video calls" are disabled (`ui tree`: not enabled; tapping them opens nothing). `ui key BACK` until the chat list shows. Check: tapping "ci g1" does not open it, and the toolbar shows a red stop icon ("Chat is stopped" in the tree); tap it: the alert "Chat is stopped" with "You can start chat via app Settings / Database or by restarting the app.". Then Settings → "Chat data" → "Database passphrase & export" → tap the switch again. Check: it says "Chat is running", and the chats open again.
20. (R57.3) Settings → "Chat data" → "Database passphrase & export" → "Database passphrase". Check: the footer starts with "Android Keystore" and says "is used to securely store passphrase - it allows notification service to work.", then "Database is encrypted using a random passphrase, you can change it.", and the view has no "Current passphrase…" field (a new installation is encrypted with a random passphrase).
21. (R57.4) `ui key BACK` once, then tap "Export database". Check: the alert "Set passphrase to export" with "Database is encrypted using a random passphrase. Please change it before exporting." and, after "OK", the "Database passphrase" view opens. Check: the switch of "Save passphrase in Keystore" is disabled (`ui tree`): the passphrase must be changed before it can be removed from the Keystore.
22. (R57.9) In "Database passphrase": type `cipass1` in "New passphrase…" and `cipass9` in "Confirm new passphrase…". Check: "Update database passphrase" stays disabled (`ui tree`; tapping it shows no alert).
23. (R57.10) Clear "Confirm new passphrase…" (tap it, `ui key DEL` until it is empty) and type `cipass1`. Tap the eye button of "New passphrase…": check its text reads `cipass1`; tap it again: hidden again (evidence for R57.7). Tap "Update database passphrase". Check: the alert "Change database passphrase?" with "Database encryption passphrase will be updated and stored in the Keystore." and "Update"; tap "Update". Check: within 60 s the alert "Database encrypted!" shows; after "OK" the footer no longer has the random-passphrase line, and a "Current passphrase…" field shows.
24. (R57.8) Type `wrongpass` in "Current passphrase…", `cipass2` in "New passphrase…" and in "Confirm new passphrase…", tap "Update database passphrase", then "Update". Check: the alert "Wrong passphrase!" with "Please enter correct current passphrase.". Tap "OK", clear the three fields, `ui key BACK` twice.
25. (R42.2) Tap "Export database" (the chat stops and starts by itself). Android's file picker opens to save the archive (its file name starts with `simplex-chat.`): choose Downloads if it asks for a place and tap its "Save" button. Check: the picker closes without an error alert. Then tap "Import database". Android's file picker opens: find the saved `simplex-chat.….zip` (Downloads or Recent) and tap it. Check: the alert "Import chat database?" with "Your current chat database will be DELETED and REPLACED with the imported one." and "Import"; tap "Import". Check: the alert "Chat database imported" with "Restart the app to use imported chat database.". Tap "OK". `ui relaunch` (an error is expected). Check: "Encrypted database" with "Database passphrase is required to open chat." shows (the import does not keep the saved passphrase): tap "Enter passphrase…", type `cipass1`, tap "Save passphrase and open chat". Check: the chat list shows "cibob", "ci g1", "ci g2" and "ci g3". If the picker cannot be driven, mark R42.2 SKIPPED with what blocked it.
26. (R57.5) `ui relaunch`. Check: the chat list shows without any passphrase screen (the passphrase is stored in the Keystore).
27. (R57.11) Settings → "Chat data" → "Database passphrase & export" → "Database passphrase". Tap the switch of "Save passphrase in Keystore". Check: the alert "Remove passphrase from Keystore?" with "Notifications will be delivered only until the app stops!" and "Remove"; tap "Remove". Check: the footer says "You have to enter passphrase every time the app starts - it is not stored on the device.". Keep this state for R57.6 and R57.7, then come back to this case (part 2) after R57.7.
28. (R57.6) `ui relaunch` (an error is expected). Check: "Encrypted database" with "Database passphrase is required to open chat." and an "Open chat" button. Tap "Enter passphrase…", type `wrongpass`, tap "Open chat". Check: the alert "Wrong passphrase!" with "Enter correct passphrase.". Tap "OK".
29. (R57.7) Clear the field (`ui key DEL` until empty), type `cipass1`. Tap the eye button at the right end of the field. Check: the field shows `cipass1`; tap it again: hidden. (The change-passphrase view was checked in R57.10.) Tap "Open chat". Check: the chat list shows.
30. (R57.11, part 2) Settings → "Chat data" → "Database passphrase & export" → "Database passphrase". Turn "Save passphrase in Keystore" on. Check: the footer says "Android Keystore will be used to securely store passphrase after you restart the app or change passphrase - it will allow receiving notifications.". `ui relaunch` (an error is expected). Check: "Encrypted database" shows with "Save passphrase and open chat": type `cipass1` and tap it (saved on start). `ui relaunch` again. Check: the chat list shows without a passphrase screen. Then turn the switch off again ("Remove"), turn it on again, and change the passphrase: "Current passphrase…" `cipass1`, new and confirm `cipass2`, "Update database passphrase", "Update", "OK" after "Database encrypted!". `ui relaunch`. Check: the chat list shows without a passphrase screen (saved on passphrase change).

The case R42.4 (chat archive view) is not in this test: the view appears only for archives made by older app versions.

You have at most 600 turns, and the whole test fits in about 300 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Get started" -- click-text "Enter profile name" 30 -- type citester -- shot profile`
- `ui do click-text Settings 10 -- click-text "Your privacy" 10 -- click-text "SimpleX Lock" 10 -- shot lock`
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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per case ID (S1 to S4, then R64.1, R58.4, R58.1, R58.5, R1.16, R23.5, R23.4, R23.6, R23.2, R23.3, R23.9, R23.8, R23.7, R23.1, R42.1, R57.3, R57.4, R57.9, R57.10, R57.8, R42.2, R57.5, R57.11, R57.6, R57.7), each as PASS, FAIL or SKIPPED (with the reason; a case the app cannot do on this platform is SKIPPED, not FAIL), with its evidence (the text on screen, screenshot names), and anything else unexpected. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
