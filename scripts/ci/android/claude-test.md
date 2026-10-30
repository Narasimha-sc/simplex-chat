# Test: message forwarding and forced encryption renegotiation in the SimpleX Chat Android app

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button.
- Besides the chats, the chat list shows the app's own cards as list items until they are closed: "New 1-time link / Paste link / Scan" (once there is a conversation), "Bottom bar / Top bar", and "Invest in SimpleX Chat!". They are part of the list, not something drawn over it: leave them open.
- The emulator's Pictures folder has `test-card.jpg` (a TV test card) and `simplex-logo.png` (the SimpleX logo).
- Connections and groups use the app's preset servers, on the internet: wait up to 60 s for a contact or a member to connect (`ui wait "<text>" 60`).
- Developer tools are on.

## How to do things in the app

- **The chat list may show "Ask SimpleX Team"**, a contact card every new profile gets. Never open it, never tap its connect button and never send it anything: it would contact the real SimpleX team.
- **Send a message:** tap the message field at the bottom of the chat (its placeholder is "Message"), `ui type "<text>"`, then click "Send Message". Check the message then shows in the chat.
- **Send an image or a file:** click "Attach" (left of the message field), then "Image" or "File". Android opens a picker that is not part of the app (the photo picker, or Files): find the file (under Pictures, Images or Recent; `test-card.jpg` shows the test card) and choose it, then confirm the choice if the picker has a button for it ("Add", "Select", "Done"). Back in the app, the compose area shows the attachment; click "Send Message".
- **Message menu:** `ui long-press <x> <y>` on the message's text or attachment (centre from `ui find`). Its items include "Reply", "Download", "Edit", "Forward", "Info", "Delete" and "Select", each only when it applies.
- **Forward one message:** message menu → "Forward". The screen then lists the chats you can forward to, titled "Forward message…". Click one: it opens with the message above the message field. Type extra text if the case says so, then click "Send Message".
- **Select messages:** message menu → "Select". Each message gets a round checkbox and the bar says "Selected 1". Click other messages to select them. The message field is replaced by a bar with three icon buttons without text: delete (left), moderate (middle, invisible unless you moderate the group) and forward (an arrow, right). Find the forward button in `ui tree` (the right one of the three at the bottom) and click it: the screen lists the chats, titled "Forward messages…".
- **Chat info:** click the chat's name at the top of the chat. `ui key BACK` closes it and other screens (preferences, member info, a message's info).
- **Switch profile:** click your profile picture, at the left end of the bottom toolbar (`profile image placeholder` in the tree, the one with the largest y). The picker shows your profiles by name in a row at its top: click the one you want.
- **Add a profile:** profile picture → "Your chat profiles" → "Add profile". On "Create profile" the name field under "Enter your name:" has the focus: type the name and click "Create profile". The new profile becomes the active one; `ui key BACK` until the chat list shows.
- **Copy a 1-time link:** "Start new chat" → "Create 1-time link". Wait for "Share this 1-time invite link"; the link is in the row under it, followed by "…" and two icon buttons without text: copy, then share. Find the copy button in `ui tree` (the first clickable element right of "…") and click it; never click the link text or the share button, which open Android's share sheet. Then `ui key BACK` until the chat list shows.
- **Connect by the copied link** (as the other profile): "Start new chat" → "Paste link / Scan" → "Tap to paste link". An alert names the profile with "Open new chat": click it. The chat opens with a "Connect" bar at the bottom: click it. Switch back to citester and wait up to 60 s until its chat list shows the new contact; open it and check that it shows the contact connected.
- **Create a group:** "Start new chat" → "Create group". The name field under "Enter group name:" has the focus: type the name and click "Create group". On "Invite members" click each contact to invite (a check mark shows), then "Invite to group"; with nobody to invite, click "Skip inviting members".
- **Join a group** (as the invited profile): click the group's row in the chat list; the alert "Join group?" offers "Join": click it. Wait up to 60 s until the group chat shows that you joined.
- **Settings:** profile picture → "Settings". "Your privacy" holds "Auto-accept images"; "Chat data" holds "Delete files for all chat profiles". Scroll down to the last row of "Advanced settings", which shows the app's version number: click it, then "Developer tools" → "Chat console". In the console, tap the text field at the bottom, `ui type` the command, click "Send Message", and read the reply above the field. `ui key BACK` until the chat list shows.

## The test

The parts build on each other: run them in this order. Take a shot at each check, named after its case (`ui shot R53-1`; shot names allow only letters, digits, - and _).

**Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Get started": click it. Click the field "Enter profile name…", type `citester`, and click "Create profile". On "Your network", click "Continue". The app explains instant notifications in an alert: click "Allow". Android then asks whether the app may always run in the background: click "Allow" again. Click "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone" while there are no conversations.
2. (S2) Add the profiles `cibob` and `cicarol`, then switch back to citester. Check: citester's picker shows cibob and cicarol.
3. (S3) As citester copy a 1-time link; switch to cibob and connect by it; switch to citester. Check: citester's chat list shows "cibob", connected.
4. (S4) The same with cicarol. Check: citester's chat list shows "cicarol", connected.
5. (S5) As citester create the group `citeam`, inviting cibob and cicarol. Switch to cibob and join "citeam"; then to cicarol and join it; switch to citester. Check: citester's "citeam" shows both members connected within 60 s.
6. (S6) As citester create the group `nofiles` with "Skip inviting members". Chat info → "Group preferences" → click the switch at the right end of the "Files and media" row so it turns off → "Save and notify group members"; `ui key BACK` until the chat list shows. Check: "nofiles" is listed.
7. (S7) As citester create the group `extra` with "Skip inviting members" (the forward list shows its search button only from 8 chats).
8. (S8) As citester: "Start new chat" → "Create 1-time link"; wait for the link, do not copy it, `ui key BACK`; in the alert "Keep unused invitation?" click "Keep". Check: the chat list shows a pending 1-time link entry.
9. (S9) Switch to cibob → chat "citester": send `bob one`; send `test-card.jpg` as an "Image"; send `simplex-logo.png` as a "File". Switch to citester → chat "cibob": send `hello bob`. Check: citester's "cibob" shows "bob one", the received test card as a picture, the file "simplex-logo.png" with a download icon, and "hello bob".

**Forwarding (as citester).**

1. (R53.1) In "cibob": forward "bob one" to "citeam" and send. In "citeam": forward that message to "Private notes" and send. In "Private notes": forward it to "cicarol" and send. Check: "citeam" shows "bob one" with the header "forwarded"; "Private notes" shows it with the header "saved" (or "saved from" and the chat's name); "cicarol" shows it with the header "forwarded".
2. (R53.2) In "cibob": forward "hello bob" and click "cibob" itself in the list; send. Check: "cibob" shows a second "hello bob" with the header "forwarded". (R53.1 covered other chats.)
3. (R53.3) In "cibob": forward "bob one" to "cicarol", tap the message field, type `see this`, send. Check: "see this" follows the forwarded "bob one" as a reply quoting it.
4. (R53.4) In "cibob": message menu of "hello bob" → "Forward". Read the list. Click "Search" (the magnifier in the toolbar), type `cib`; take a shot; `ui key BACK` to close the search, then click "Private notes"; send. Check: the list has "Private notes", "cibob", "cicarol", "citeam", "nofiles" and "extra", and lacks the pending 1-time link and "Ask SimpleX Team"; with `cib` only "cibob" is listed. If "Search" is missing, the profile has fewer than 8 chats: create the group `extra2` as in S7 and repeat.
5. (R53.12) In "cibob": select the file "simplex-logo.png" (not downloaded) and "hello bob"; click the forward button. Check: the alert "Forward 2 message(s)?" says "1 file(s) were not downloaded." and "Forward messages without files?", with "Forward", "Download" and "Cancel". Click "Download". Check: within 60 s the file shows as downloaded (no download icon). Select the two again and click the forward button. Check: the forward list opens with no alert. Click "Private notes" and send.
6. (R53.5) In "cibob": forward the received test card to "citeam" and send; forward the file "simplex-logo.png" to "citeam" and send. Check: "citeam" shows the test card and the file, each with the header "forwarded". Videos and voice messages are not covered: the emulator has no video file and no microphone.
7. (R53.6) In "citeam": send `own text`. Open the menu of the forwarded "bob one" (your own message), `ui key BACK`, then open the menu of "own text". Check: the forwarded message's menu has no "Edit"; the menu of "own text" has "Edit".
8. (R53.7) In "cibob": forward the received test card to "Private notes" and send; then the file "simplex-logo.png". Check: "Private notes" shows both with the header "saved" or "saved from" "cibob".
9. (R53.9) In "citeam": menu of the forwarded "bob one" → "Info"; if the info has tabs, click "Forwarded". Click the chat name under "Forwarded from". Check: the info says "Forwarded from", names "cibob", and says "Recipient(s) can't see who this message is from."; the click opens the chat "cibob".
10. (R53.10) In "cibob": send `m1`, `m2`, `m3`. Select "m1", "m2" and "m3", click the forward button, click "cicarol", send. Check: "cicarol" shows "m1", "m2" and "m3", each with the header "forwarded".
11. (R53.11) In "cibob": message menu of "m3" → "Select"; then click "m1", then "m2" (selection order m3, m1, m2); forward button → "Private notes"; send. Check: "Private notes" shows the three new items in the order m1, m2, m3, as in the source chat.
12. (R53.18) In "cibob": select the received test card and "bob one"; forward button. Look at "nofiles" in the list, then click it. Check: "nofiles" is greyed out (its name in a lighter grey than the others; compare in the screenshot); clicking it shows the alert "Cannot send message" with "Selected chat preferences prohibit this message.". Close the alert, then click "cibob" in the list to leave it; if the compose area of "cibob" then shows the two messages above the message field, clear it with the close icon at its right end (find it in `ui tree`).
13. (R53.19) (a) In "cibob": select "m1" and "m2", forward button → "cibob". `ui long-press` the "Send Message" button → "Disappearing message" → under "Send disappearing message" click "30 seconds". Note the time. Check: both new items show a timer. Switch to cibob → "citester": the two items are there with a timer. When 40 s have passed since sending, check both sides again. (b) Switch to citester → "cicarol" → chat info → "Contact preferences" → in "Disappearing messages", open "Delete after" and choose "10 min" → "Save and notify contact"; `ui key BACK` until the chat shows. In "Private notes" select "m1" and "m2", forward them to "cicarol", send; menu of one of them → "Info". Note the time. Check: (a) the items are gone from both chats after 40 s; (b) the two items show a timer and their info has "Disappears at" about 10 minutes after sending. Their disappearance is checked at the end (step 20).
14. (R53.20) In "cibob": select "m2" and "m3", forward button → "citeam", send. Wait 30 s. Menu of the forwarded "m3" → "Info". Check: both items show a sent status (one or two check marks); the info's "Delivery" lists cibob and cicarol, each with a status.

**Forced encryption renegotiation.** The developer-tools button "Renegotiate encryption" is commented out in this app version (`ChatInfoView.kt`, `GroupMemberInfoView.kt`), so its alert "Renegotiate encryption?" cannot appear: these cases check its absence and force the renegotiation from the chat console.

15. (R54.10) As citester: "cibob" → chat info: look for "Renegotiate encryption" (scroll down with `ui scroll`). Then Settings → … → "Chat console": send `/sync @cibob force=on`. `ui key BACK` until the chat list shows, open "cibob" and wait up to 60 s. Check: the info has no "Renegotiate encryption" (note it, not a failure); the console's reply is not an error; the chat shows "agreeing encryption…" and then "encryption agreed". Then send `after sync`. Check: it shows as sent.
16. (R54.11) Chat console: send `/sync #citeam @cicarol force=on`. Open "citeam" and wait up to 60 s; then group info → "cicarol": look for "Renegotiate encryption". Check: the reply is not an error; "citeam" shows "agreeing encryption for cicarol…" and then "encryption agreed for cicarol" (or the same events without the name); the member info has no "Renegotiate encryption".

**Deleted files.**

17. (R53.8) Settings → "Chat data" → "Delete files for all chat profiles" → "Delete" in "Delete files and media?" (confirm any further alert). Check: the footer under "Files & media" says "No received or sent files". Back in "cibob": open the menu of the received test card. Check: it has no "Forward".
18. (R53.15) In "cibob": select the received test card and "bob one"; forward button. Check: the alert "Forward 2 message(s)?" says "1 file(s) were deleted." and "Forward messages without files?", with "Cancel" and "Forward".
19. (R53.16) Click "Forward", then "cicarol", send. Check: "cicarol" shows "bob one" and the test card as a picture (its low-resolution preview), both with the header "forwarded".
20. (R53.17) In "cibob": select the file "simplex-logo.png" (its file is deleted now) and "hello bob"; forward button. Check: the alert's title counts 1 message ("Forward 1 message(s)?"), with "1 file(s) were deleted.". Click "Forward", then "cicarol", send. Check: "cicarol" gets "hello bob" only, and no file message.
21. (R53.19, end of (b)) When at least 10 minutes have passed since step 13 (b), open citester's "cicarol", then switch to cicarol → "citester". Check: the two items forwarded with "10 min" are gone on both sides.

You have at most 600 turns, and the whole test fits in about 300 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Get started" -- click-text "Enter profile name" 30 -- type citester -- shot profile`
- `ui do click-text "Start new chat" -- click-text "Create 1-time link" 10 -- wait "Share this 1-time invite link" 30 -- shot link`
- `ui do click-text "Your chat profiles" 10 -- click-text "Add profile" 10 -- wait "Enter your name" -- type cibob -- shot add-profile`
- `ui do click-text "Message" -- type m1 -- click-text "Send Message" -- wait m1 -- shot m1`

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per case (S1 to S9, then R53.1, R53.2, R53.3, R53.4, R53.12, R53.5, R53.6, R53.7, R53.9, R53.10, R53.11, R53.18, R53.19, R53.20, R54.10, R54.11, R53.8, R53.15, R53.16, R53.17) with PASS, FAIL or SKIPPED (with the reason) and its evidence (the text read, screenshot names), and anything else unexpected. A case the app cannot do on this platform is SKIPPED, not FAIL. End your final message with one line: `CLAUDE-TEST: PASS` if every case you ran passed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
