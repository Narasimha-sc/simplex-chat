# Test: private notes, markdown, SimpleX links and images in the SimpleX Chat Android app

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. Colours, icons and the parts of a message (a link inside a text) are judged from the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types ASCII text into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button; `ui key ENTER` in the message field starts a new line.
- The guard refuses the characters `( ) | > ; & < $` and the backtick in any command, also inside quotes. `(` and `)` can be typed as keys: `ui key NUMPAD_LEFT_PAREN`, `ui key NUMPAD_RIGHT_PAREN`. `>` and `|` cannot be typed here.
- Besides the chats, the chat list shows the app's own cards as list items until they are closed ("New 1-time link / Paste link / Scan", "Bottom bar / Top bar", "Invest in SimpleX Chat!"). Leave them open.
- The emulator's Pictures folder has two images: `test-card.jpg`, a TV test card 1280×720 (colour bars, a large circle, "1080" at the top and "TVB" at the bottom), and `simplex-logo.png`, the dark blue and turquoise SimpleX logo on a transparent background. The emulator has no camera.
- The app's preset servers are on the internet: connecting and file transfers can take up to a minute. Wait with `ui wait "<text>" 60`.

## How to do things in the app

- **Send a message:** tap the message field (its placeholder is "Message"), `ui type "<text>"`, then tap "Send Message". Check the message then shows in the chat.
- **Message menu:** `ui long-press <x> <y>` on the message opens its menu ("Share", "Copy", "Save", "Edit", "Info", "Stop file", "Delete", …, as the item allows).
- **Chat list row menu:** `ui long-press` on the row's name.
- **Profile picture:** the leftmost element of the bottom toolbar; it has no text: find it with `ui tree` (a clickable element at the bottom left, left of the search field). Tapping it opens the profile menu: your other profiles by name, "Your chat profiles", "Settings".
- **Switch profile:** profile picture → tap the profile's name. The chat list then shows that profile's chats.
- **Add a profile:** profile picture → "Your chat profiles" → "Add profile". On "Create profile", the name field under "Enter your name:" has the focus: type the name and tap "Create profile". The new profile becomes the active one; `ui key BACK` until the chat list shows.
- **Settings:** profile picture → "Settings". `ui key BACK` goes back.
- **Attach:** tap "Attach" (left of the message field), then "Image" or "File". Android opens a picker that is not part of the app (the photo picker or Files): find the image by name or thumbnail (under Pictures, Images or Recent) and choose it, then confirm if the picker has a button for it. Back in the app, the compose area shows the attachment above the message field; tap "Send Message".
- **Paste into the message field:** long-press the field; Android shows its text menu above it: tap its paste item (find it with `ui tree`).
- **Open an image:** tap it; it opens full screen. `ui key BACK` closes it.
- **Database view:** Settings → "Chat data". Under "Files & media" its footer says "%d file(s) with total size of %s" or "No received or sent files".

## The test

The parts build on each other: run them in this order. Take a shot at each check, named after its case (`ui shot R9.1`).

**S. Setup: three profiles, two contacts.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Get started": click it. Click the field "Enter profile name…", type `citester`, and click "Create profile". On "Your network", click "Continue". The app explains instant notifications in an alert: click "Allow". Android then asks whether the app may always run in the background: click "Allow" again. Click "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone".
2. (S2) As citester: "Start new chat" → "Create 1-time link". Wait for "Share this 1-time invite link". Tap the copy icon, the first of the two icons right of the link (do not tap the link text: it opens Android's share sheet). `ui key BACK` until the chat list shows.
3. (S3) Add the profile `cibob`. As cibob: "Start new chat" → "Paste link / Scan" → "Tap to paste link". An alert names "citester" with "Open new chat": tap it (if the alert is "Connect via one-time link?" instead, tap "Use current profile"). The chat with citester opens with a "Connect" bar at the bottom: tap it. Wait up to 60 s, then send `hello from cibob`. Check: it shows as sent.
4. (S4) Switch to citester. Check: the chat list shows "cibob"; open it: it shows "hello from cibob". `ui key BACK`.
5. (S5) Repeat S2 to S4 for a third profile `cicarol` (message `hello from cicarol`), then switch to citester. Check: the chat list shows "cibob", "cicarol" and "Private notes".

**N. Private notes and markdown (as citester, in "Private notes").** Tap "Private notes" in the chat list to open it.

1. (R9.1) Send `note one`. Long-press it → "Edit": the field shows "note one". `ui key MOVE_END`, type ` edited`, tap "Send Message". Check: one message "note one edited" in place of "note one" (no second message). Long-press it → "Delete" → "Delete for me" in the alert "Delete message?". Check: the message is gone.
2. (R26.1) Send `**bold part** and https://simplex.chat`. Long-press the word "and" of that message → "Copy". Paste into the message field. Check: the field shows `**bold part** and https://simplex.chat`, with the asterisks; send it. Then tap the link "https://simplex.chat" in the first of the two messages (its position from the picture). Check: the alert "Open web link?" shows "https://simplex.chat" (the link is clickable); tap "Cancel" (never open it).
3. (R26.2) Long-press the link "https://simplex.chat" itself in a message. Check: the message menu opens ("Copy", "Info", "Delete" among its items). `ui key BACK`.
4. (R28.0) Send `**text** is bold`. Check in the picture: "text" is drawn bold, without asterisks, and "is bold" is regular.
5. (R27.0) Send four messages, one per kind, with `ui key ENTER` for each new line:
   - heading: `# Heading one`;
   - list: `- item one`, new line, `- item two`;
   - code block: `~~~`, new line, `code line`, new line, `~~~`;
   - rule: `above`, new line, new line, `***`, new line, new line, `below`.
   Check in the pictures: each is rendered, not shown as typed: the heading larger or bold without "#"; the list with bullet markers; the code line in a monospace block without "~~~"; a horizontal line between "above" and "below" without "***". Quotes and tables are not tested here: `>` and `|` cannot be typed (note this in the report).
6. (R30.0) Send `# Title`, new line, `line one`, new line, `line two`. Check: "Title" as a heading, and "line one" and "line two" on two separate lines (not joined into one line).
7. (R29.0) Tap the message field, then `ui key NUMPAD_LEFT_PAREN`, `ui type "see https://simplex.chat"`, `ui key NUMPAD_RIGHT_PAREN`. Check the field shows "(see https://simplex.chat)" (if the brackets did not appear, mark SKIPPED: the keys typed nothing), then send it. Tap the link in the sent message. Check: the alert "Open web link?" shows "https://simplex.chat" without ")"; tap "Cancel". In the picture, the brackets are not in the link colour.
8. (R31.0) Send `call 07777 777 777 or +44 7777 777 777`, then `12345678 2024-10-29 192.168.1.1 7.1.0.14 issue #42`. Check in the picture: both phone numbers are in the link colour; in the second message every part is plain text in the normal text colour. Do not tap the phone numbers.
9. (R26.3) `ui key BACK` to the chat list. "Start new chat" → "Create 1-time link" → tap the copy icon (as in S2) → `ui key BACK` until the chat list shows → open "Private notes" → paste into the message field and send. Check: the message shows "SimpleX one-time invitation" followed by "(via <server>)". Tap that text. Check: the app shows the alert "Connect to yourself?" with "This is your own one-time link!" (an alert in the app, no browser); tap "Cancel".
10. (R26.4) Settings → scroll to the end → tap the app version row (the last row, under "Advanced settings": a version number such as 7.1…) → "Developer tools". Under "Deprecated options", tap the row "SimpleX links": the menu offers "Description" and "Full link". Tap "Full link", `ui key BACK` until the chat shows. Check: the invitation message from R26.3 now shows the full link (starting with "https://") in place of "SimpleX one-time invitation". Set "SimpleX links" back to "Description" the same way. Check: the message shows "SimpleX one-time invitation" again.
11. (R26.6) Long-press the invitation message → "Copy" → paste into the message field. Check: the field shows the full link starting with "https://", not the description. Send it.
12. (R9.2) Attach "Image" `test-card.jpg` and send it. Check: the note shows the test card. Tap it: it opens full screen with "1080" and "TVB" readable; `ui key BACK`. Long-press it → "Save", and shoot at once. Check: the toast "Image saved to Gallery" (in the picture; toasts may be missing from the text). If the shot missed the toast, open "Attach" → "Image": the picker shows one more test card than before; leave it with `ui key BACK`.
13. (R9.3) `ui key BACK` to the chat list. Long-press "Private notes" → "Clear". Check: the alert "Clear private notes?" says "All messages will be deleted - this cannot be undone!"; tap "Clear". Open "Private notes". Check: no messages are left.

**F. Images (citester and cibob).**

1. (R34.1) As citester, open "cibob", attach "Image" `test-card.jpg` and send it. Shot at once, then every few seconds until the image shows "Image sent" (a check mark in its corner). Check: a progress indicator while uploading, then the check mark. Switch to cibob, open "citester". Check: the image is received (shown in full, not a placeholder). Run `ui relaunch`, open "citester" again. Check: the image is still shown. Switch to citester, open "cibob". Check: the image still has its check mark.
2. (R34.13) Settings → "Chat data". Check: the footer under "Files & media" says "2 file(s) with total size of …" (the sent and the received copy of the one image); the total divided by the count is below 231 KB (236700 bytes). Record the count and size.
3. (R34.11) Switch to cibob → "citester". Tap the image. Check: it opens full screen; "1080" and "TVB" are readable. `ui key BACK`.
4. (R34.10) As cibob, long-press the image → "Save", and shoot at once. Check: the toast "Image saved to Gallery" (or, as in R9.2, one more test card in the picker).
5. (R34.4) Switch to citester → "cibob". Attach "Image" (the photo picker, Android's gallery) `simplex-logo.png`. Check: the preview shows the whole logo; send it. Check: the logo shows as sent, and as cibob it is received. "Camera" is not tested (the emulator has none).
6. (S6) As citester: "Start new chat" → "Create group". The name field under "Enter group name:" has the focus: type `ci images` and tap "Create group". On the members screen tap "cibob" and "cicarol", then "Invite to group". Switch to cibob: tap "ci images" in the chat list → "Join" in the alert "Join group?". Do the same as cicarol. Switch to citester → "ci images". Check: the chat shows that cibob and cicarol joined (wait up to 60 s).
7. (R34.5) As citester in "ci images", attach "Image" `test-card.jpg` and send it. Switch to cibob → "ci images", and to cicarol → "ci images". Check: each shows the received test card.
8. (R34.2) Settings → "Your privacy" → "More privacy" → turn on the switch of "Show encryption". `ui key BACK` until the chat list shows. Check in the pictures, at each image's time: a lock icon next to the time of the received test card in cicarol's "ci images"; then as citester, of the sent images in "ci images" and in "cibob".
9. (R34.15) As citester in "cibob": attach "File" and choose `test-card.jpg`; send it. Check: the file item shows the file name and a lock icon by its time; as cibob, the received file item shows it too (tap the file to receive it if it waits). In "ci images" repeat with `simplex-logo.png`; check the lock as citester and as cicarol.
10. (R34.7) As citester in "cibob": note the position of the last image in the chat. Attach "Image" `test-card.jpg`, then in one chain: tap "Send Message", long-press the new image (the bottom of the chat, where the last image was), `ui click-text "Stop file" 3`, `ui click-text Stop 5`, shot. Check: the alert "Stop sending file?" said "Sending file will be stopped.", and the image then shows a cross in place of the progress indicator. If the menu offered "Revoke file" instead, the upload had already finished: `ui key BACK` and mark R34.7 and R34.9 SKIPPED (timing), with the shot.
11. (R34.9) Switch to cibob → "citester". Check: the last image shows a cross (the transfer was cancelled), and tapping it does not open it.
12. (R34.6) As cibob: Settings → "Your privacy" → turn off the switch of "Auto-accept images". Switch to citester → "cibob", send `simplex-logo.png`. Switch to cibob → "citester" and, in one chain, tap the new image twice (`ui do click X Y -- click X Y -- shot R34.6`). Check: the alert "Waiting for image" says "Image will be received when your contact completes uploading it."; "OK" closes it. If the image was received already at the second tap, mark SKIPPED (timing).
13. (R34.8) As citester send `test-card.jpg` to cibob again. As cibob → "citester", in one chain: tap the new image (it starts receiving), long-press it, `ui click-text "Stop file" 3`, `ui click-text Stop 5`, shot. Check: the alert was "Stop receiving file?" with "Receiving file will be stopped.", and the image then shows a cross. If the menu had no "Stop file" because the image was already received, mark SKIPPED (timing). The sender's view of the cancellation is not checked: images go over XFTP, not SMP.
14. (R34.12) As cibob: Settings → "Chat data": record the footer's file count. Back in "citester", long-press the received test card of R34.1 → "Delete" → "Delete for me". Settings → "Chat data" again. Check: the count is one less.

You have at most 385 turns, and the whole test fits in about 290 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Get started" -- click-text "Enter profile name" 30 -- type citester -- shot profile`
- `ui do click-text "Start new chat" -- click-text "Create 1-time link" 10 -- wait "Share this 1-time invite link" 60 -- shot link`
- `ui do click-text "Message" -- type "note one" -- click-text "Send Message" -- wait "note one" -- shot R9.1-sent`
- `ui do relaunch -- click-text citester 30 -- shot R34.1-reopened`

`ui do` stops at the first command that fails, so a failed chain tells you where it stopped.

## Report

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per case (S1 to S6, R9.1, R26.1, R26.2, R28.0, R27.0, R30.0, R29.0, R31.0, R26.3, R26.4, R26.6, R9.2, R9.3, R34.1, R34.13, R34.11, R34.10, R34.4, R34.5, R34.2, R34.15, R34.7, R34.9, R34.6, R34.8, R34.12), each as PASS, FAIL or SKIPPED (with the reason), with its evidence (text from the tree, screenshot names), and anything else unexpected. A case the app cannot do here is SKIPPED, not FAIL. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs that failed.

## The ui helper
