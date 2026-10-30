# Test: message forwarding and forced encryption renegotiation in the SimpleX Chat desktop app

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- After onboarding, the chat list is in the left pane (x 1 to 389) and chats open in the right pane. An empty chat list shows only its toolbar, with the profile picture at about 27,730 and a pencil (New chat) at about 363,730. The toolbar is at the bottom of the left pane.
- Connections and groups use the app's preset servers, on the internet: wait up to 60 s for a contact or a member to connect (`ui wait "<text>" 60`).
- The folder `images` in your working directory has `test-card.jpg` (a TV test card) and `simplex-logo.png` (the SimpleX logo). The app's file dialogs take an absolute path: your working directory's absolute path followed by `/images/test-card.jpg`.
- Developer tools are on.

## How to do things in the app

- **The chat list may show "Ask SimpleX Team"**, a contact card every new profile gets. Never open it, never click its connect button and never send it anything: it would contact the real SimpleX team.
- **Send a message:** click the message field at the bottom of the right pane (its placeholder is "Message"), `ui type "<text>"`, then `ui key Return`. Check the message then shows in the chat.
- **Send an image or a file:** click the attachment button, the paperclip icon at the left end of the message field, then "Image" or "File". A file dialog opens: click its "File Name" field, type the absolute path, and press Return. Back in the app, the compose area shows the attachment; press Return in the message field or click the send button at the right end of the field.
- **Message menu:** `ui right-click <x> <y>` on the message's text or attachment (centre from `ui find`). Its items include "Reply", "Download", "Edit", "Forward", "Info", "Delete" and, after a divider, "Select", each only when it applies.
- **Forward one message:** message menu → "Forward". The left pane then lists the chats you can forward to, titled "Forward message…". Click one: it opens with the message above the message field. Type extra text if the case says so, then click the send button at the right end of the message field (or click the field and press Return).
- **Select messages:** message menu → "Select". Each message gets a round checkbox, and the bar above the chat says "Selected 1". Click other messages to select them. The message field is replaced by a bar with three icons and no text: delete (left), moderate (middle, invisible unless you moderate the group) and forward (an arrow, at the right end). Take a shot and click the forward arrow: the left pane lists the chats, titled "Forward messages…".
- **Chat info:** click the chat's name at the top of the right pane. Press Escape to close it and other panes (preferences, member info, a message's info) and get back to the chat.
- **Switch profile:** click the profile picture (about 27,730); the menu lists your other profiles by name: click the one you want.
- **Add a profile:** profile picture → "Your chat profiles" → "Add profile". On "Create profile", click the field about 40 px below the text "Enter your name:", type the name, and click the "Create profile" button (the lower of the two "Create profile" texts; the upper one is the title). The new profile becomes the active one; press Escape until the chat list shows.
- **Copy a 1-time link:** the pencil → "Create 1-time link". Wait for "Share this 1-time invite link" and click the link text under it: the toast "Copied to clipboard" shows. Press Escape until the chat list shows.
- **Connect by the copied link** (as the other profile): the pencil → "Paste link" → "Tap to paste link". An alert names the profile with "Open new chat": click it. The chat opens with a "Connect" bar at the bottom: click it. Switch back to citester and wait up to 60 s until its chat list shows the new contact; open it and check that it shows the contact connected.
- **Create a group:** the pencil → "Create group". Click the field about 40 px below the text "Enter group name:", type the name, and click the "Create group" button (the lower of the two texts). On the next screen, "Invite members", click each contact to invite (a check mark shows), then "Invite to group"; with nobody to invite, click "Skip inviting members".
- **Join a group** (as the invited profile): click the group's row in the chat list; the alert "Join group?" offers "Join": click it. Wait up to 60 s until the group chat shows that you joined.
- **Settings:** profile picture → "Settings". "Your privacy" holds "Auto-accept images"; "Chat data" holds "Delete files for all chat profiles". The last row of "Advanced settings" shows the app's version number: click it, then "Developer tools" → "Chat console". In the console click the message field at the bottom, `ui type` the command, press Return, and read the reply above the field. Press Escape until the chat list shows.

## The test

The parts build on each other: run them in this order. Take a shot at each check, named after its case, with `-` for the dot (`ui shot R53-1`).

**Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone".
2. (S2) Add the profiles `cibob` and `cicarol`, then switch back to citester. Check: the profile menu of citester lists cibob and cicarol.
3. (S3) As citester copy a 1-time link; switch to cibob and connect by it; switch to citester. Check: citester's chat list shows "cibob", connected.
4. (S4) The same with cicarol. Check: citester's chat list shows "cicarol", connected.
5. (S5) As citester create the group `citeam`, inviting cibob and cicarol. Switch to cibob and join "citeam"; then to cicarol and join it; switch to citester. Check: citester's "citeam" shows both members connected within 60 s.
6. (S6) As citester create the group `nofiles` with "Skip inviting members". Chat info → "Group preferences" → click the switch at the right end of the "Files and media" row so it turns off → "Save and notify group members"; press Escape until the chat list shows. Check: "nofiles" is listed.
7. (S7) As citester create the group `extra` with "Skip inviting members" (the forward list shows its search button only from 8 chats).
8. (S8) As citester: the pencil → "Create 1-time link"; wait for the link, do not click it, press Escape; in the alert "Keep unused invitation?" click "Keep". Check: the chat list shows a pending 1-time link entry.
9. (S9) Switch to cibob → chat "citester": send `bob one`; send the image `images/test-card.jpg`; send `images/simplex-logo.png` as a "File". Switch to citester → chat "cibob": send `hello bob`. Check: citester's "cibob" shows "bob one", the received test card as a picture, the file "simplex-logo.png" with a download icon, and "hello bob".

**Forwarding (as citester).**

1. (R53.1) In "cibob": forward "bob one" to "citeam" and send. In "citeam": forward that message to "Private notes" and send. In "Private notes": forward it to "cicarol" and send. Check: "citeam" shows "bob one" with the header "forwarded"; "Private notes" shows it with the header "saved" (or "saved from" and the chat's name); "cicarol" shows it with the header "forwarded".
2. (R53.2) In "cibob": forward "hello bob" and click "cibob" itself in the list; send. Check: "cibob" shows a second "hello bob" with the header "forwarded". (R53.1 covered other chats.)
3. (R53.3) In "cibob": forward "bob one" to "cicarol", type `see this`, send. Check: "see this" follows the forwarded "bob one" as a reply quoting it.
4. (R53.4) In "cibob": message menu of "hello bob" → "Forward". Read the list. Click the magnifier icon at the right end of the toolbar at the bottom of the left pane, type `cib`; take a shot; clear the field (`ui key ctrl+a`, `ui key BackSpace`) and click "Private notes"; send. Check: the list has "Private notes", "cibob", "cicarol", "citeam", "nofiles" and "extra", and lacks the pending 1-time link and "Ask SimpleX Team"; with `cib` only "cibob" is listed. If no magnifier shows, the profile has fewer than 8 chats: create the group `extra2` as in S7 and repeat.
5. (R53.12) In "cibob": select the file "simplex-logo.png" (not downloaded) and "hello bob"; click the forward arrow. Check: the alert "Forward 2 message(s)?" says "1 file(s) were not downloaded." and "Forward messages without files?", with "Forward", "Download" and "Cancel". Click "Download". Check: within 60 s the file shows as downloaded (no download icon). Select the two again and click the forward arrow. Check: the forward list opens with no alert. Click "Private notes" and send.
6. (R53.5) In "cibob": forward the received test card to "citeam" and send; forward the file "simplex-logo.png" to "citeam" and send. Check: "citeam" shows the test card and the file, each with the header "forwarded". Videos and voice messages are not covered: the runner has no video file and no microphone.
7. (R53.6) In "citeam": send `own text`. Open the menu of the forwarded "bob one" (your own message), press Escape, then open the menu of "own text". Check: the forwarded message's menu has no "Edit"; the menu of "own text" has "Edit".
8. (R53.7) In "cibob": forward the received test card to "Private notes" and send; then the file "simplex-logo.png". Check: "Private notes" shows both with the header "saved" or "saved from" "cibob".
9. (R53.9) In "citeam": menu of the forwarded "bob one" → "Info"; if the info has tabs, click "Forwarded". Click the chat name under "Forwarded from". Check: the info says "Forwarded from", names "cibob", and says "Recipient(s) can't see who this message is from."; the click opens the chat "cibob".
10. (R53.10) In "cibob": send `m1`, `m2`, `m3`. Select "m1", "m2" and "m3", click the forward arrow, click "cicarol", send. Check: "cicarol" shows "m1", "m2" and "m3", each with the header "forwarded".
11. (R53.11) In "cibob": message menu of "m3" → "Select"; then click "m1", then "m2" (selection order m3, m1, m2); forward arrow → "Private notes"; send. Check: "Private notes" shows the three new items in the order m1, m2, m3, as in the source chat.
12. (R53.18) In "cibob": select the received test card and "bob one"; forward arrow. Look at "nofiles" in the list, then click it. Check: "nofiles" is greyed out (its name in a lighter grey than the others; compare in the screenshot); clicking it shows the alert "Cannot send message" with "Selected chat preferences prohibit this message.". Close it (click its button or press Escape) and click "cibob" to get back; clear the compose area if it shows the messages (the close icon at its right end).
13. (R53.19) (a) In "cibob": select "m1" and "m2", forward arrow → "cibob". Right-click the send button at the right end of the message field → "Disappearing message" → under "Send disappearing message" click "30 seconds". Note the time. Check: both new items show a timer. Switch to cibob → "citester": the two items are there with a timer. When 40 s have passed since sending, check both sides again. (b) Switch to citester → "cicarol" → chat info → "Contact preferences" → in "Disappearing messages", open "Delete after" and choose "10 min" → "Save and notify contact"; press Escape until the chat shows. In "Private notes" select "m1" and "m2", forward them to "cicarol", send; menu of one of them → "Info". Note the time. Check: (a) the items are gone from both chats after 40 s; (b) the two items show a timer and their info has "Disappears at" about 10 minutes after sending. Their disappearance is checked at the end (step 21).
14. (R53.20) In "cibob": select "m2" and "m3", forward arrow → "citeam", send. Wait 30 s. Menu of the forwarded "m3" → "Info". Check: both items show a sent status (one or two check marks); the info's "Delivery" lists cibob and cicarol, each with a status.

**Forced encryption renegotiation.** The developer-tools button "Renegotiate encryption" is commented out in this app version (`ChatInfoView.kt`, `GroupMemberInfoView.kt`), so its alert "Renegotiate encryption?" cannot appear: these cases check its absence and force the renegotiation from the chat console.

15. (R54.10) As citester: "cibob" → chat info: look for "Renegotiate encryption" (scroll down with `ui scroll`). Then Settings → … → "Chat console": send `/sync @cibob force=on`. Press Escape until the chat list shows, open "cibob" and wait up to 60 s. Check: the info has no "Renegotiate encryption" (note it, not a failure); the console's reply is not an error; the chat shows "agreeing encryption…" and then "encryption agreed". Then send `after sync`. Check: it shows as sent.
16. (R54.11) Chat console: send `/sync #citeam @cicarol force=on`. Open "citeam" and wait up to 60 s; then group info → "cicarol": look for "Renegotiate encryption". Check: the reply is not an error; "citeam" shows "agreeing encryption for cicarol…" and then "encryption agreed for cicarol" (or the same events without the name); the member info has no "Renegotiate encryption".

**Deleted files.**

17. (R53.8) Settings → "Chat data" → "Delete files for all chat profiles" → "Delete" in "Delete files and media?" (confirm any further alert). Check: the footer under "Files & media" says "No received or sent files". Back in "cibob": open the menu of the received test card. Check: it has no "Forward".
18. (R53.15) In "cibob": select the received test card and "bob one"; forward arrow. Check: the alert "Forward 2 message(s)?" says "1 file(s) were deleted." and "Forward messages without files?", with "Cancel" and "Forward".
19. (R53.16) Click "Forward", then "cicarol", send. Check: "cicarol" shows "bob one" and the test card as a picture (its low-resolution preview), both with the header "forwarded".
20. (R53.17) In "cibob": select the file "simplex-logo.png" (its file is deleted now) and "hello bob"; forward arrow. Check: the alert's title counts 1 message ("Forward 1 message(s)?"), with "1 file(s) were deleted.". Click "Forward", then "cicarol", send. Check: "cicarol" gets "hello bob" only, and no file message.
21. (R53.19, end of (b)) When at least 10 minutes have passed since step 13 (b), open citester's "cicarol", then switch to cicarol → "citester". Check: the two items forwarded with "10 min" are gone on both sides.

You have at most 600 turns, and the whole test fits in about 300 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Create your profile" -- wait "Enter profile name" -- click-text "Enter profile name" -- type citester -- shot profile`
- `ui do click 363 730 -- click-text "Create 1-time link" 10 -- wait "Share this 1-time invite link" 30 -- shot link`
- `ui do click 27 730 -- click-text "Your chat profiles" 10 -- click-text "Add profile" 10 -- wait "Enter your name" -- shot add-profile`
- `ui do click-text "Message" -- type "m1" -- key Return -- wait "m1" -- shot m1`

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per case (S1 to S9, then R53.1, R53.2, R53.3, R53.4, R53.12, R53.5, R53.6, R53.7, R53.9, R53.10, R53.11, R53.18, R53.19, R53.20, R54.10, R54.11, R53.8, R53.15, R53.16, R53.17) with PASS, FAIL or SKIPPED (with the reason) and its evidence (the text OCR read, screenshot names), and anything else unexpected. A case the app cannot do on this platform is SKIPPED, not FAIL. End your final message with one line: `CLAUDE-TEST: PASS` if every case you ran passed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
