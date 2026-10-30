# Test: sending and receiving files in the SimpleX Chat Android app

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button.
- Besides the chats, the chat list shows the app's own cards as list items until they are closed ("New 1-time link / Paste link / Scan", "Bottom bar / Top bar", "Invest in SimpleX Chat!"). Leave them open.
- The emulator's Pictures folder has two images: `test-card.jpg` (137 KB, a TV test card) and `simplex-logo.png` (28 KB, the SimpleX logo). They are the only files to send. The "File" attachment opens Android's document picker, where they can be chosen as files (under Images, Pictures or Recent; open the picker's side menu, the button at its top left, to switch).
- Files go through the app's preset file servers on the internet. The images are small: their transfers often finish within seconds.
- Android's own screens (photo picker, document picker, save screen) are not part of the app: find their buttons in the tree or the screenshot.

## How to do things in the app

- **Send a message:** tap the message field ("Message"), `ui type "<text>"`, then tap "Send Message".
- **Chat info:** tap the chat's name at the top of the chat. `ui key BACK` goes back.
- **Message menu:** `ui long-press <x> <y>` on a message (for a file: on its file name; centre from `ui find`). The menu lists the items that apply: "Reply", "Share", "Copy", "Save", "Download", "Edit", "Forward", "Info", "Stop file", "Revoke file", "Delete".
- **Profile picture:** the toolbar's left end, level with "Start new chat"; in the tree it is an element "profile image placeholder" (take the one at the toolbar's y). Tapping it opens a menu with your other profiles by name, "Your chat profiles" and "Settings".
- **Switch profile:** profile picture → the other profile's name.
- **Add a profile:** profile picture → "Your chat profiles" → "Add profile". The name field (under "Enter your name:") has the focus: type the name, check the field in the tree, tap "Create profile". The new profile becomes the active one; `ui key BACK` until the chat list shows.
- **Attach:** tap "Attach" (left of the message field): it shows "Camera", "Image", "Video" and "File". "Image" opens Android's photo picker, "File" its document picker. Back in the app, the compose area shows the image or file above the message field; tap "Send Message". Text typed in the field before sending goes with the file.
- **File states are icons** left of the file name, read from the picture: a received file not yet downloaded has a down arrow; a transfer in progress shows a circle; a sent and uploaded file shows a check mark; a cancelled file shows a cross.
- **Receive a file:** tap the file name of a received file (down arrow). Once it is downloaded the app opens a small menu by itself with "Save" (and "Open with …"). Tapping a downloaded file opens that menu again. `ui key BACK` closes it.
- **Save:** "Save" in that menu or in the message menu opens Android's save screen with the file name in a field and a save button. Saving returns to the app.
- **Files count:** profile picture → "Settings" → "Chat data". The text under "Files & media" says "N file(s) with total size of …" or "No received or sent files"; it counts the files of all profiles. `ui key BACK` until the chat list shows. Reopen "Chat data" for a fresh count.

## The test

Run the cases in this order; later cases use what earlier ones set up. Profiles: `citester` sends unless a case says otherwise, `cibob` receives.

**Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Get started": click it. Click the field "Enter profile name…", type `citester`, and click "Create profile". On "Your network", click "Continue". The app explains instant notifications in an alert: click "Allow". Android then asks whether the app may always run in the background: click "Allow" again. Click "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone".
2. (S2) As citester: "Start new chat" → "Create 1-time link". Wait up to 60 s for "Share this 1-time invite link". The link is the text under it; right of it are two icon buttons without text (in `ui tree`, at the link's y): tap the first, the copy button. `ui key BACK` until the chat list shows (if "Keep unused invitation?" appears, tap "Keep").
3. (S3) Add the profile `cibob`. As cibob: "Start new chat" → "Paste link / Scan" → "Tap to paste link". An alert names "citester" with "Open new chat": tap it. The chat opens with a "Connect" bar at the bottom: tap it. Wait up to 120 s until the message field ("Message") shows in place of the bar, then send `hello from cibob`. Switch to citester. Check: the chat list has "cibob"; open it: it shows "hello from cibob".
4. (S4) As citester: "Start new chat" → "Create group". The name field under "Enter group name:" has the focus: type `file group` and tap "Create group". On the next screen tap "cibob", then "Invite to group". Switch to cibob, open "citester", tap "Tap to join" on the invitation; wait up to 120 s for "You joined this group". Switch to citester, open "file group", send `group hello`. Switch to cibob, open "file group". Check: "group hello" shows.

**Direct files.**

5. (R34.16) As citester in "cibob": "Attach" → "File" → choose `test-card.jpg`; send. Take shots while it uploads and after: the icon changes to a check mark. Switch to cibob, open "citester": "test-card.jpg" shows with a down arrow; tap it; take shots until it is downloaded (`ui key BACK` closes the menu that opens). Open "file group", then "citester" again; switch to citester and open "cibob" again. Check: on both sides the file keeps its final state.
6. (R34.25) As cibob in "citester": tap the downloaded "test-card.jpg". Check: the menu offers "Save"; tap it. Check: Android's save screen opens with "test-card.jpg"; tap its save button. Check: back in the app, no error alert. Note the folder the save screen showed.
7. (R34.26) Long-press the same file → "Save". In the save screen tap the name field, `ui key MOVE_END`, then `ui key DEL` 13 times (one `ui key` call with 13 DEL), type `test card copy.jpg`, check the field, tap the save button. Check: the message menu offered "Save"; back in the app with no error.
8. (R34.24) Still as cibob in "citester": "Attach" → "File" → in the document picker open the folder noted in R34.25 (or Downloads, or Recent) and choose "test card copy.jpg"; send. Check: the sent item shows "test card copy.jpg". Switch to citester, open "cibob", tap the received "test card copy.jpg". Check: it downloads (`ui key BACK` closes the menu) and keeps the name "test card copy.jpg".
9. (R34.27) As citester in "cibob": attach "File" `test-card.jpg`, type `same name`, and send. Switch to cibob, open "citester", tap the new "test-card.jpg". Check: both "test-card.jpg" items are downloaded on cibob's side, each with the name "test-card.jpg".
10. (R34.33) As cibob: long-press the latest "test-card.jpg" → "Reply". Check: the compose area shows the quoted item ("same name" and/or "test-card.jpg"). Type `reply to file`, tap "Send Message". Check: the sent message shows the quote above "reply to file". Switch to citester, open "cibob". Check: the reply shows the same quote. Long-press your file with "same name" → "Edit"; tap the field, `ui key MOVE_END`, type ` edited` (with the leading space), tap "Send Message". Check: the item now reads "same name edited" and the tree has "edited" by it; on cibob's side too.

**Group file.**

11. (R34.17) As citester in "file group": attach "File" `simplex-logo.png` and send. Switch to cibob, open "file group". Check: "simplex-logo.png" shows with a down arrow. Tap it. Check: it downloads (`ui key BACK` closes the menu).

**Files count.**

12. (R34.28) As citester: read the files count (N1). In "cibob" attach "File" `simplex-logo.png` and send; wait for the check mark. Read the count again (N2). Check: the row expects the sent file to be deleted after the transfer completes, so N2 equals N1. Record N1 and N2.
13. (R34.29) As citester in "cibob": long-press that "simplex-logo.png" → "Delete" → "Delete for me". Read the count (N3). Check: N3 is lower than N2.

**Stopping and revoking.** The images transfer fast; these cases depend on reaching the file's menu while it still transfers. Chain the steps in one `ui do` (e.g. `ui do click <x> <y> -- long-press <x> <y> -- click-text "Stop file" 5 -- shot R34-20`), with the position taken from the previous file item (the newest item appears at the bottom of the chat, above the message field). A case whose transfer finished first is SKIPPED with that reason.

14. (R34.18) As citester in "cibob": attach "File" `test-card.jpg` and send. At once switch to cibob, open "citester", tap the new file (accept it), and tap it again. Check: if citester's upload was still running, the alert "Waiting for file" says "File will be received when your contact completes uploading it."; tap "OK".
15. (R34.20) As citester send `test-card.jpg` as "File" again. As cibob: tap the new file and at once long-press it → "Stop file". Check: the alert "Stop receiving file?" says "Receiving file will be stopped."; tap "Stop". Check: the item returns to the down arrow. Switch to citester: record what its item shows (file servers send the sender no notice of this).
16. (R34.21) As cibob: tap that file again. Check: it downloads to the end. SKIPPED when R34.20 was skipped.
17. (R34.19) As citester in "cibob": attach "File" `test-card.jpg`, send, and at once long-press the new item → "Stop file". Check: the alert "Stop sending file?" says "Sending file will be stopped."; tap "Stop". Check: the item shows a cross.
18. (R34.23) As citester in "cibob": attach "File" `simplex-logo.png`, type `to revoke`, send, and wait for the check mark. Do not download it as cibob. Long-press it → "Revoke file". Check: the alert "Revoke file?" says "File will be deleted from servers."; tap "Revoke". Check: the item shows a cross.
19. (R34.22) Switch to cibob, open "citester". Check: the "to revoke" file (and the file stopped in R34.19, if it was stopped) shows a cross, and its menu offers no "Download".

**Compose and images.**

20. (R34.34) As citester in "cibob": tap the message field, type `https://simplex.chat`. If "Enable link previews?" appears, tap "Enable". Wait up to 30 s for a link preview card above the field. Then "Attach" → "Image" → choose the test card. Check: the image preview replaces the link preview. Tap "Cancel image preview", then clear the field (tap it, `ui key MOVE_END`, `ui key DEL` 20 times). Now attach "Image" test card first, then type `https://simplex.chat` and wait 10 s. Check: no link preview is added. Send it.
21. (R34.36) As citester in "cibob": "Attach" → "Image" → in the photo picker tap both images (test card and logo), then its confirm button ("Add", "Select" or "Done"). Check: the compose area shows two images. Type `two images`, tap "Send Message". Check: the chat shows two images, and "two images" is under the second (last) one only.
22. (R34.37) Tap one of these two images: it opens full screen. `ui swipe 900 1200 left`, shot; `ui swipe 180 1200 right`, shot. Check: a swipe shows the other image, and the swipe back shows the first. `ui key BACK`.

**Deleting files (destructive, last).**

23. (R34.32) As citester: read the count (C1). Open "file group" → chat info → "Clear chat" → the alert "Clear chat?" → "Clear". Read the count (C2). Check: C2 is lower than C1 and not "No received or sent files"; open "cibob": its images still show, and one opens full screen when tapped (`ui key BACK`).
24. (R34.31) As citester: "cibob" → chat info → "Delete contact" → the alert "Delete contact?" → "Delete contact" → "Delete without notification". Read the count (C3). Check: C3 is lower than C2 and not "No received or sent files"; switch to cibob, open "citester": a downloaded file still opens its "Save" menu when tapped.
25. (R34.35) Profile picture → "Settings" → "Chat data" → "Delete files for all chat profiles" → the alert "Delete files and media?" → "Delete". Check: the text says "No received or sent files".

You have at most 600 turns, and the whole test fits in about 290 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Get started" -- click-text "Enter profile name" 30 -- type citester -- shot profile`
- `ui do click-text "Start new chat" -- click-text "Create 1-time link" 10 -- wait "Share this 1-time invite link" 60 -- shot link`
- `ui do click-text "Message" -- type "hello from cibob" -- click-text "Send Message" -- wait "hello from cibob" -- shot sent`
- `ui do click-text "Settings" 10 -- click-text "Chat data" 10 -- shot files-count`

`ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Take a shot at each check, named after its case (`ui shot R34-16`).

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. Create it first with one row per case (S1 to S4, then R34.16, R34.25, R34.26, R34.24, R34.27, R34.33, R34.17, R34.28, R34.29, R34.18, R34.20, R34.21, R34.19, R34.23, R34.22, R34.34, R34.36, R34.37, R34.32, R34.31, R34.35), result `todo`, and fill each row in when its case is done: PASS, FAIL or SKIPPED (with the reason), and the evidence (text from the tree, the counts, screenshot names). A case the app cannot do here is SKIPPED, not FAIL. Add anything else unexpected under "Findings". End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
