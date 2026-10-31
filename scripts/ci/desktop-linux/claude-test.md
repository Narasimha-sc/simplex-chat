# Test: SimpleX Lock, the chat database and its passphrase, message deletion and hidden profiles in the SimpleX Chat desktop app

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons or the state of switches; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

## What is set up

- The app is already running, on its first screen, with a new, empty database. Begin with `ui shot start` to see it.
- After onboarding, the chat list is in the left pane (x 1 to 389) and chats open in the right pane. The toolbar is at the bottom of the left pane: the profile picture at about 27,730 and a pencil (New chat) at about 363,730.
- Contacts connect through the app's preset servers on the internet: wait up to 120 s for a connection (`ui wait "<text>" 120`).

## How to do things in the app

- **Restart the app** (only where a step says so): `ui stop`, then `ui start <app dir>`, where `<app dir>` is the folder `app/simplex` next to your working directory: your working directory is `<RUNNER_TEMP>/claude-test` and the app is `<RUNNER_TEMP>/app/simplex`; on GitHub's runners that is `ui start /home/runner/work/_temp/app/simplex`. Type the path literally (the helper refuses `$`). `ui start` returns when the window shows; then `ui shot` to see which screen the app opened with. If after a restart the app shows its first onboarding screen ("Create your profile") where the step expects something else, the restart lost the app's data: write that under "Harness notes" in the report and mark the cases that need a restart SKIPPED.
- **Settings:** click the profile picture (about 27,730), then "Settings". Rows used here: "Your privacy" → "SimpleX Lock" (its value shows "Off" or "Passcode"), and "Chat data" → "Database passphrase & export". Press Escape to go back one level.
- **Passcode screens** ("New Passcode", "Confirm passcode", "Enter Passcode", "Current Passcode", or a title naming the action): type the digits with `ui type <digits>` (the screen takes the keyboard's digit keys), then click the button at the bottom right of the pad ("Save", "Confirm" or "Submit"; it stays disabled until at least 4 digits are entered) or "Cancel" at the bottom left. The entered digits show as dots.
- **Passphrase fields** ("Current passphrase…", "New passphrase…", "Confirm new passphrase…", "Enter passphrase…"): click the field, then `ui type <text>`. The eye icon at the right end of each field shows or hides its text.
- **Switch profile:** click the profile picture; the menu lists your other profiles by name: click the one you want.
- **Add a profile:** profile picture → "Your chat profiles" → "Add profile". On "Create profile", click the field about 40 px below the text "Enter your name:", type the name, and click the "Create profile" button (the lower of the two "Create profile" texts; the upper one is the title). The new profile becomes the active one; press Escape until the chat list shows.
- **"Your chat profiles"** lists the profiles under a search field "Search". When it opens with more than one profile, an alert "Make profile private!" may show: click "OK". Right-clicking a profile's row opens its menu ("Hide", "Mute", "Delete" …).
- **Create a group:** pencil → "Create group". Click the name field, about 40 px below the text "Enter group name:", type the name, and click "Create group". If "Skip inviting members" shows, click it. Press Escape until the chat list shows.
- **Connect two profiles:** as the inviting profile: pencil → "Create 1-time link"; wait for the link under "Share this 1-time invite link" and click the link's text: the toast "Copied to clipboard" shows. Press Escape until the chat list shows. Switch to the other profile: pencil → "Paste link" → "Tap to paste link". An alert shows the inviting profile's name and "Open new chat": click it. The chat opens with a "Connect" bar at the bottom: click it.
- **Chat info:** click the chat's name at the top of the right pane; Escape closes it.
- **Drop-down rows** ("Delete messages after", "Lock after"): click the row; the list of values opens; click a value.

## Passcodes and passphrases used

- App passcode: `1234`, changed to `5678` in R23.8. Wrong passcode: `9999`.
- Database passphrase: `cipass1` from R57.10, `cipass2` from R57.11. Wrong passphrase: `wrongpass`.
- Hidden profile password: `cihide1`.

## The test

The cases build on each other: run them in this order. Each case ID is the row of the test table (R…) or a setup step (S…). Take a shot at each check, named after its case (`ui shot R23-6`).

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone".
2. (S2) Create three groups: `ci g1`, `ci g2`, `ci g3`. Check: the chat list shows all three.
3. (S3) As citester create a 1-time link; add the profile `cibob`; as cibob connect by the copied link. Wait up to 120 s, then as cibob send `hello from cibob` in the chat "citester". Switch to citester. Check: citester's chat list shows "cibob", and the chat "cibob" shows "hello from cibob". citester now has 4 chats.

**P. A hidden profile.**

4. (R64.1) As citester: add the profile `cicarol`. Switch to citester. Open "Your chat profiles" (close "Make profile private!" with "OK" if it shows). Right-click the row "cicarol" → "Hide". On "Hide profile", click "Password to show", type `cihide1`, click "Confirm password", type `cihide1`, click "Save profile password". Check: "cicarol" is no longer listed, and the row "Enter password in search" shows above the title. Press Escape until the chat list shows; check the profile menu (profile picture) does not list cicarol. Press Escape.

**M. Automatic message deletion (as citester).**

5. (R58.4) Settings → "Chat data". Check: "Delete messages after" shows "never". Choose "1 month". Check: the alert "Enable automatic message deletion?" with "This action cannot be undone - the messages sent and received earlier than selected will be deleted. It may take several minutes." and the buttons "Delete messages" and "Cancel". Click "Cancel". Check: the row shows "never" again.
6. (R58.1) Choose "1 year", then "Delete messages" in the alert. Check: within 60 s the progress indicator is gone and the row shows "1 year" (note the seconds it took, from two shots). Press Escape until the chat list shows.
7. (R58.5) Open the chat "ci g1" → chat info. Check: "Delete messages after" shows "default (1 year)", with the footer "Delete chat messages from your device.". Choose "1 day". Check: the alert "Change automatic message deletion?" with "This action cannot be undone - the messages sent and received in this chat earlier than selected will be deleted." and "Delete messages"; click it; the row shows "1 day". Then open the chat "cibob" → chat info → "Delete messages after" → "never". Check: the alert "Disable automatic message deletion?" with "Messages in this chat will never be deleted." and "Disable delete messages"; click it; the row shows "never". The chats' messages are all younger than a day, so none is deleted: check that "hello from cibob" still shows. Press Escape.

**L. SimpleX Lock.** The desktop app has only the passcode lock: "System" authentication and backgrounding the app don't exist here.

8. (R1.16) Restart the app. Check: the alert "SimpleX Lock" with "To protect your information, turn on SimpleX Lock. You will be prompted to complete authentication before this feature is enabled." and "Turn on" shows over the chat list (the app shows it on the first start with more than 3 chats). Click "Turn on". Check: "New Passcode" shows. Type `1234`, click "Save". Check: "Confirm passcode" shows; type `1235`: "Confirm" stays disabled (clicking it does nothing). Clear it with BackSpace (`ui key BackSpace` four times), type `1234`, click "Confirm". Check: the alert "SimpleX Lock turned on" with "You will be required to authenticate when you start or resume the app after 30 seconds in background.". Click "OK". If the notice did not show after the restart, restart once more and check again; if it still does not show, mark R1.16 FAIL and turn the lock on in R23.6 instead.
9. (R23.6) Settings → "Your privacy". Check: "SimpleX Lock" shows "Passcode". Click it. Check: "Enable lock" is on (screenshot), "Lock after" shows "30 seconds", and "Change passcode" is listed. Press Escape until the chat list shows. Then open "Your chat profiles" from the profile menu and click "Add profile". Check: a passcode screen titled "Change chat profiles" with "Log in using your credential" shows before "Create profile": passcode is asked on authentication. Leave it open for R23.2.
10. (R23.2) Type `9999`, click "Submit". Check: "Create profile" does not open; the screen offers "Unlock". Click "Unlock", type `1234`, click "Submit". Check: "Create profile" opens. Press Escape until the chat list shows, without creating a profile.
11. (R23.3) Settings → "Your privacy" → "SimpleX Lock". Click the switch of "Enable lock" to turn it off. Check: a passcode screen ("Enter Passcode", "Disable SimpleX Lock") shows. Click "Cancel". Check: the alert "Authentication failed" with "You could not be verified; please try again."; after "OK", the switch is on again and "Lock after" is still listed.
12. (R23.8) Click "Change passcode". Check: "Current Passcode" ("Change passcode") shows; type `1234`, "Submit". Check: "New Passcode" with "App passcode" shows; type `5678`, "Save", then `5678`, "Confirm". Check: the alert "Passcode changed!". Click "OK".
13. (R23.7) Click "Lock after". Check: it offers "10 seconds", "30 seconds", "1 minutes", "3 minutes", "10 minutes" and "Immediately". Choose "10 seconds". Check: the row shows "10 seconds". Their effect needs the app in the background, which the desktop runner can't do: write that in the evidence.
14. (R23.1) Restart the app. Check: the app asks for the passcode ("Enter Passcode") before the chat list shows. Type `5678`, "Submit". Check: the chat list shows. Turning the lock on and off and the passcode on opening a sheet were checked in R1.16, R23.3 and R23.6: cite them.
15. (S4) Settings → "Your privacy" → "SimpleX Lock" → turn "Enable lock" off; on the passcode screen type `5678`, "Submit". Check: the switch is off and "SimpleX Lock" shows "Off" in "Your privacy". Press Escape until the chat list shows.

**D. The chat database (as citester).**

16. (R42.1) Settings → "Chat data" → "Database passphrase & export". Under "Run chat", click the switch of "Chat is running". Check: the alert "Stop chat?" with "Stop chat to export, import or delete chat database. You will not be able to receive and send messages while the chat is stopped."; click "Stop". Check: the row says "Chat is stopped" and the footer "You must use the most recent version of your chat database on one device ONLY, otherwise you may stop receiving the messages from some contacts." shows. Press Escape twice to Settings. Check: "Your privacy", "Network & servers" and "Audio & video calls" are disabled (greyed) and do not open on click. Press Escape until the chat list shows. Check: clicking "ci g1" does not open it, and the toolbar shows a red stop icon; click it: the alert "Chat is stopped" with "You can start chat via app Settings / Database or by restarting the app.". Then Settings → "Chat data" → "Database passphrase & export" → click the switch again. Check: it says "Chat is running", and the chats open again.
17. (R57.3) Settings → "Chat data" → "Database passphrase & export" → "Database passphrase". Check: the footer says "The passphrase is stored in settings as plaintext." and "Database is encrypted using a random passphrase, you can change it.", and the view has no "Current passphrase…" field (a new installation is encrypted with a random passphrase).
18. (R57.4) Press Escape once, then click "Export database". Check: the alert "Set passphrase to export" with "Database is encrypted using a random passphrase. Please change it before exporting." and, after "OK", the "Database passphrase" view opens. Check: the switch of "Save passphrase in settings" is disabled (clicking it changes nothing): the passphrase must be changed before it can be removed from settings.
19. (R57.9) In "Database passphrase": type `cipass1` in "New passphrase…" and `cipass9` in "Confirm new passphrase…". Check: "Update database passphrase" stays disabled (grey; clicking it shows no alert).
20. (R57.10) Clear "Confirm new passphrase…" (click it, `ui key ctrl+a`, `ui key BackSpace`) and type `cipass1`. Click the eye icon of "New passphrase…": check its text reads `cipass1`; click it again: it shows asterisks (evidence for R57.7). Click "Update database passphrase". Check: the alert "Change database passphrase?" with "Database encryption passphrase will be updated and stored in settings." and "Update"; click "Update". Check: within 60 s the alert "Database encrypted!" shows; after "OK" the footer says "The passphrase is stored in settings as plaintext." without the random-passphrase line, and a "Current passphrase…" field shows.
21. (R57.8) Type `wrongpass` in "Current passphrase…", `cipass2` in "New passphrase…" and in "Confirm new passphrase…", click "Update database passphrase", then "Update". Check: the alert "Wrong passphrase!" with "Please enter correct current passphrase.". Click "OK", clear the three fields, press Escape twice.
22. (R42.2) Click "Export database" (the chat stops and starts by itself). A file dialog opens: click its "File Name" field, type `<your working directory>/ci-export.zip` (the absolute path), and press Return. Check: no error alert shows and the dialog closes. Then click "Import database". In the file dialog type the same path and press Return. Check: the alert "Import chat database?" with "Your current chat database will be DELETED and REPLACED with the imported one." and "Import"; click "Import". Check: the alert "Chat database imported" with "Restart the app to use imported chat database.". Click "OK". Restart the app. Check: "Encrypted database" with "Database passphrase is required to open chat." shows (the import does not keep the saved passphrase): click "Enter passphrase…", type `cipass1`, click "Save passphrase and open chat". Check: the chat list shows "cibob", "ci g1", "ci g2" and "ci g3".
23. (R57.5) Restart the app. Check: the chat list shows without any passphrase screen (the passphrase is stored in settings).
24. (R57.11) Settings → "Chat data" → "Database passphrase & export" → "Database passphrase". Click the switch of "Save passphrase in settings". Check: the alert "Remove passphrase from settings?" with "Remove"; click "Remove". Check: the footer says "You have to enter passphrase every time the app starts - it is not stored on the device.". Keep this state for R57.6 and R57.7, then come back to this case (part 2) after R57.7.
25. (R57.6) Restart the app. Check: "Encrypted database" with "Database passphrase is required to open chat." and an "Open chat" button. Click "Enter passphrase…", type `wrongpass`, click "Open chat". Check: the alert "Wrong passphrase!" with "Enter correct passphrase.". Click "OK".
26. (R57.7) Clear the field, type `cipass1`. Click the eye icon at the right end of the field. Check: the field shows `cipass1`; click it again: asterisks. (The change-passphrase view was checked in R57.10.) Click "Open chat". Check: the chat list shows.
27. (R57.11, part 2) Settings → "Chat data" → "Database passphrase & export" → "Database passphrase". Turn "Save passphrase in settings" on. Check: the footer says "The passphrase will be stored in settings as plaintext after you change it or restart the app.". Restart the app. Check: "Encrypted database" shows with "Save passphrase and open chat": type `cipass1` and click it (saved on start). Restart the app again. Check: the chat list shows without a passphrase screen. Then turn the switch off again ("Remove"), turn it on again, and change the passphrase: "Current passphrase…" `cipass1`, new and confirm `cipass2`, "Update database passphrase", "Update", "OK" after "Database encrypted!". Restart the app. Check: the chat list shows without a passphrase screen (saved on passphrase change).

The case R42.4 (chat archive view) is not in this test: the view appears only for archives made by older app versions.

You have at most 600 turns, and the whole test fits in about 280 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Create your profile" -- wait "Enter profile name" -- click-text "Enter profile name" -- type citester -- shot profile`
- `ui do click 27 730 -- click-text "Settings" 10 -- click-text "Your privacy" 10 -- click-text "SimpleX Lock" 10 -- shot lock`
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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per case ID (S1 to S4, then R64.1, R58.4, R58.1, R58.5, R1.16, R23.6, R23.2, R23.3, R23.8, R23.7, R23.1, R42.1, R57.3, R57.4, R57.9, R57.10, R57.8, R42.2, R57.5, R57.11, R57.6, R57.7), each as PASS, FAIL or SKIPPED (with the reason; a case the app cannot do on this platform is SKIPPED, not FAIL), with its evidence (the text OCR read, screenshot names), and anything else unexpected. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
