# Test: private notes, markdown, SimpleX links and images in the SimpleX Chat desktop app

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons or colours; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- After onboarding, the chat list is in the left pane (x 1 to 389) and chats open in the right pane. The toolbar is at the bottom of the left pane: the profile picture at about 27,730 and a pencil (New chat) at about 363,730.
- The folder `images` in your working directory has two images: `test-card.jpg`, a TV test card 1280×720 (colour bars, a large circle, "1080" at the top and "TVB" at the bottom), and `simplex-logo.png`, the dark blue and turquoise SimpleX logo on a transparent background. Paths you type in file dialogs are absolute: build them from your working directory (for example `<working directory>/images/test-card.jpg`); never type `$`.
- The app's preset servers are on the internet: connecting and file transfers can take up to a minute. Wait with `ui wait "<text>" 60`.
- The guard refuses the characters `( ) | > ; & < $` and the backtick in any command, also inside quotes. Type them as keys: `ui key parenleft`, `ui key parenright`, `ui key bar`, `ui key greater`.

## How to do things in the app

- **Send a message:** click the message field at the bottom of the right pane (its placeholder is "Message"), `ui type "<text>"`, then `ui key Return`. A new line inside a message is `ui key shift+Return`. Check the message then shows in the chat.
- **Message menu:** `ui right-click <x> <y>` on the message (centre from `ui find`) opens its menu ("Reply", "Share", "Copy", "Save", "Edit", "Info", "Stop file", "Delete", …, as the item allows). Escape closes menus, alerts and panes.
- **Chat list row menu:** `ui right-click` on the row's name.
- **Switch profile:** click the profile picture (about 27,730); the menu lists your other profiles by name: click the one you want. The chat list then shows that profile's chats.
- **Add a profile:** profile picture → "Your chat profiles" → "Add profile". On "Create profile", click the field about 40 px below the text "Enter your name:", type the name, and click the "Create profile" button (the lower of the two "Create profile" texts). The new profile becomes the active one; press Escape until the chat list shows.
- **Settings:** profile picture → "Settings". Escape goes back.
- **Attach an image or a file:** click the paperclip icon at the left end of the message field, then "Image" (or "File"). A file dialog opens: click its "File Name" field, type the absolute path, and press Return. The compose area then shows the image above the message field; `ui key Return` sends it.
- **Save dialog:** "Save" in a message menu opens a file dialog with the file's name in its "File Name" field: `ui key ctrl+a`, type the absolute path to save to, and press Return. The app then shows the toast "File saved".
- **Open an image:** click it; it opens larger. Escape closes it.
- **Database view:** Settings → "Chat data". Under "Files & media" its footer says "%d file(s) with total size of %s" or "No received or sent files".
- **Paste:** click the message field, then `ui key ctrl+v`.

## The test

The parts build on each other: run them in this order. Take a shot at each check, named after its case (`ui shot R9.1`).

**S. Setup: three profiles, two contacts.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone".
2. (S2) As citester: the pencil → "Create 1-time link". Wait for "Share this 1-time invite link". Click the link text below it (it starts with "https://"). Check: the toast "Copied to clipboard". Press Escape until the chat list shows.
3. (S3) Add the profile `cibob`. As cibob: the pencil → "Paste link" → "Tap to paste link". An alert names "citester" with "Open new chat": click it (if the alert is "Connect via one-time link?" instead, click "Use current profile"). The chat with citester opens with a "Connect" bar at the bottom: click it. Wait up to 60 s, then send `hello from cibob`. Check: it shows as sent.
4. (S4) Switch to citester. Check: the chat list shows "cibob"; open it: it shows "hello from cibob".
5. (S5) Repeat S2 to S4 for a third profile `cicarol` (message `hello from cicarol`), then switch to citester. Check: the chat list shows "cibob", "cicarol" and "Private notes".

**N. Private notes and markdown (as citester, in "Private notes").** Click "Private notes" in the chat list to open it.

1. (R9.1) Send `note one`. Right-click it → "Edit": the field shows "note one". `ui key ctrl+End`, type ` edited`, `ui key Return`. Check: one message "note one edited" in place of "note one" (no second message). Right-click it → "Delete" → "Delete for me" in the alert "Delete message?". Check: the message is gone.
2. (R26.1) Send `**bold part** and https://simplex.chat`. Right-click the words "and" of that message → "Copy". Check: the toast "Copied to clipboard". Paste into the message field. Check: the field shows `**bold part** and https://simplex.chat`, with the asterisks; press `ui key Return` to send it. Then click the link "https://simplex.chat" in the first of the two messages. Check: the alert "Open web link?" shows "https://simplex.chat" (the link is clickable); click "Cancel" (never open it: no browser runs here).
3. (R26.2) Right-click the link "https://simplex.chat" itself in a message. Check: the message menu opens on the link ("Copy", "Info", "Delete" among its items). Escape.
4. (R28.0) Send `**text** is bold`. Check in the picture: "text" is drawn bold, without asterisks, and "is bold" is regular.
5. (R27.0) Send six messages, one per kind, each typed with new lines as `ui key shift+Return`:
   - heading: `# Heading one`;
   - list: `- item one`, new line, `- item two`;
   - quote: `ui key greater`, then type ` quoted text`;
   - code block: `~~~`, new line, `code line`, new line, `~~~`;
   - table: `ui key bar` then ` a ` then `ui key bar` then ` b ` then `ui key bar`; new line; `ui key bar` `---` `ui key bar` `---` `ui key bar`; new line; `ui key bar` ` 1 ` `ui key bar` ` 2 ` `ui key bar` (one `ui do` chain);
   - rule: `above`, new line, new line, `***`, new line, new line, `below`.
   Check in the pictures: each is rendered, not shown as typed: the heading larger or bold without "#"; the list with bullet markers; the quote without ">" and marked as a quote; the code line in a monospace block without "~~~"; the table as a grid with cells "a", "b", "1", "2" and no "|" or "---"; a horizontal line between "above" and "below" without "***".
6. (R30.0) Send `# Title`, new line, `line one`, new line, `line two`. Check: "Title" as a heading, and "line one" and "line two" on two separate lines (not joined into one line).
7. (R29.0) Click the message field, then in one chain: `ui key parenleft`, `ui type "see https://simplex.chat"`, `ui key parenright`; check the field shows "(see https://simplex.chat)", then `ui key Return`. Click the link in the sent message. Check: the alert "Open web link?" shows "https://simplex.chat" without ")"; click "Cancel". In the picture, the brackets are not in the link colour.
8. (R31.0) Send `call 07777 777 777 or +44 7777 777 777`, then `12345678 2024-10-29 192.168.1.1 7.1.0.14 issue #42`. Check in the picture: both phone numbers are in the link colour; in the second message every part is plain text in the normal text colour. Do not click the phone numbers.
9. (R33.0) Type `https://simplеx.chat` (the fifth letter is the Cyrillic "е", U+0435: type the text exactly as written here) and send it. Check: the message shows `https://simpl[U+0435]x.chat`. Click it. Check: the alert "Open web link?" shows `https://simpl[U+0435]x.chat`; click "Cancel".
10. (R26.3) The pencil → "Create 1-time link"; click the link text (toast "Copied to clipboard"); press Escape until the chat list shows; open "Private notes"; paste into the message field and send. Check: the message shows "SimpleX one-time invitation" followed by "(via <server>)". Click that text. Check: the app shows the alert "Connect to yourself?" with "This is your own one-time link!" (an alert in the app, no browser); click "Cancel".
11. (R26.4) Settings → scroll to the end of the list → click the app version row (the last row, under "Advanced settings": a version number such as 7.1…) → "Developer tools". Under "Deprecated options", click the row "SimpleX links": the menu offers "Description" and "Full link". Click "Full link", press Escape until the chat shows. Check: the invitation message from R26.3 now shows the full link (starting with "https://") in place of "SimpleX one-time invitation". Set "SimpleX links" back to "Description" the same way. Check: the message shows "SimpleX one-time invitation" again.
12. (R26.6) Right-click the invitation message → "Copy" → paste into the message field. Check: the field shows the full link starting with "https://", not the description. Send it.
13. (R9.2) Attach "Image" `images/test-card.jpg` and send it. Check: the note shows the test card. Click it: it opens larger with "1080" and "TVB" readable; Escape. Right-click it → "Save"; save to `<working directory>/notes-test-card.jpg`. Check: the toast "File saved".
14. (R9.3) Press Escape until the chat list shows. Right-click "Private notes" → "Clear". Check: the alert "Clear private notes?" says "All messages will be deleted - this cannot be undone!"; click "Clear". Open "Private notes". Check: no messages are left.

**F. Images (citester and cibob).**

1. (R34.1) As citester, open "cibob", attach "Image" `images/test-card.jpg` and send it. Shot at once, then every few seconds until the image shows a check mark in its corner. Check: the image shows a progress indicator while uploading, then the check mark. Switch to cibob, open "citester". Check: the image is received (shown in full, not a placeholder). Press Escape until the chat list shows, open "citester" again. Check: the image is still shown. Switch to citester, reopen "cibob". Check: the image still has its check mark.
2. (R34.13) Settings → "Chat data". Check: the footer under "Files & media" says "2 file(s) with total size of …" (the sent and the received copy of the one image); the total divided by the count is below 231 KB (236700 bytes). Record the count and size. Escape until the chat list shows.
3. (R34.11) Switch to cibob → "citester". Click the image. Check: it opens larger; "1080" and "TVB" are readable. Escape.
4. (R34.10) As cibob, right-click the image → "Save"; save to `<working directory>/received-test-card.jpg`. Check: the toast "File saved".
5. (R34.4) Switch to citester → "cibob". Attach "Image" (the image chooser, the desktop's gallery) `images/simplex-logo.png`. Check: the preview shows the whole logo; send it. Check: the logo shows as sent, and as cibob it is received. Taking a photo is not tested (the runner has no camera).
6. (S6) As citester: the pencil → "Create group". Click the field about 40 px below "Enter group name:", type `ci images`, click "Create group". On the members screen click "cibob" and "cicarol", then "Invite to group". Switch to cibob: click "ci images" in the chat list → "Join" in the alert "Join group?". Do the same as cicarol. Switch to citester → "ci images". Check: the chat shows that cibob and cicarol joined (wait up to 60 s).
7. (R34.5) As citester in "ci images", attach "Image" `images/test-card.jpg` and send it. Switch to cibob → "ci images", and to cicarol → "ci images". Check: each shows the received test card.
8. (R34.2) Settings → "Your privacy" → "More privacy" → click the switch at the right end of "Show encryption" to turn it on. Escape until the chat list shows. Check in the pictures, zoomed on each image's time: a lock icon next to the time of the received test card in cicarol's "ci images"; then as citester, of the sent images in "ci images" and in "cibob".
9. (R34.15) As citester in "cibob": attach "File", path `<working directory>/images/test-card.jpg`, and send it. Check: the file item shows the file name and a lock icon by its time; as cibob, the received file item shows it too (click the file to receive it if it waits). In "ci images" repeat with `<working directory>/images/simplex-logo.png`; check the lock as citester and as cicarol.
10. (R34.7) As citester in "cibob": note the position of the last image in the chat. Attach "Image" `images/test-card.jpg`, then in one chain: `ui key Return`, right-click the new image (the bottom of the chat, where the last image was), `ui click-text "Stop file" 3`, `ui click-text Stop 5`, shot. Check: the alert "Stop sending file?" said "Sending file will be stopped.", and the image then shows a cross in place of the progress indicator. If the menu offered "Revoke file" instead, the upload had already finished: press Escape and mark R34.7 and R34.9 SKIPPED (timing), with the shot.
11. (R34.9) Switch to cibob → "citester". Check: the last image shows a cross (the transfer was cancelled), and clicking it does not open it.
12. (R34.6) As cibob: Settings → "Your privacy" → turn off the switch of "Auto-accept images". Switch to citester → "cibob", send `images/simplex-logo.png`. Switch to cibob → "citester" and, in one chain, click the new image twice (`ui do click X Y -- click X Y -- shot R34.6`). Check: the alert "Waiting for image" says "Image will be received when your contact completes uploading it."; OK closes it. If the image was received already at the second click, mark SKIPPED (timing).
13. (R34.8) As citester send `images/test-card.jpg` to cibob again. As cibob → "citester", in one chain: click the new image (it starts receiving), right-click it, `ui click-text "Stop file" 3`, `ui click-text Stop 5`, shot. Check: the alert was "Stop receiving file?" with "Receiving file will be stopped.", and the image then shows a cross. If the menu had no "Stop file" because the image was already received, mark SKIPPED (timing). The sender's view of the cancellation is not checked: images go over XFTP, not SMP.
14. (R34.12) As cibob: Settings → "Chat data": record the footer's file count. Escape, open "citester", right-click the received test card of R34.1 → "Delete" → "Delete for me". Settings → "Chat data" again. Check: the count is one less.

You have at most 600 turns, and the whole test fits in about 300 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Create your profile" -- wait "Enter profile name" -- click-text "Enter profile name" -- type citester -- shot profile`
- `ui do click 363 730 -- click-text "Create 1-time link" 10 -- wait "Share this 1-time invite link" 60 -- shot link`
- `ui do click-text "Message" -- type "note one" -- key Return -- wait "note one" -- shot R9.1-sent`
- `ui do click 27 730 -- click-text "Your chat profiles" 10 -- click-text "Add profile" 10 -- wait "Enter your name" -- shot add-profile`

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per case (S1 to S6, R9.1, R26.1, R26.2, R28.0, R27.0, R30.0, R29.0, R31.0, R33.0, R26.3, R26.4, R26.6, R9.2, R9.3, R34.1, R34.13, R34.11, R34.10, R34.4, R34.5, R34.2, R34.15, R34.7, R34.9, R34.6, R34.8, R34.12), each as PASS, FAIL or SKIPPED (with the reason), with its evidence (the text OCR read, screenshot names), and anything else unexpected. A case the app cannot do here is SKIPPED, not FAIL. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs that failed.

## The ui helper
