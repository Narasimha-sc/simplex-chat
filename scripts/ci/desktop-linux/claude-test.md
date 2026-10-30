# Test: sending and receiving files in the SimpleX Chat desktop app

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- After onboarding, the chat list is in the left pane (x 1 to 389) and chats open in the right pane. An empty chat list shows only its toolbar, with the profile picture at about 27,730 and a pencil (New chat) at about 363,730. The toolbar is at the bottom of the left pane.
- Files to send, by absolute path (`ui` refuses `$`, so write each path out in full, starting from your working directory's absolute path):
  - `<working directory>/images/test-card.jpg` (137 KB) and `<working directory>/images/simplex-logo.png` (28 KB);
  - `<working directory>/prompt.md`, this prompt, a Markdown file;
  - the large file: your working directory's path ends in `/claude-test`; replace that last part with `/app/simplex/lib/app/resources/libsimplex.so` (the app's core library, tens of megabytes). If the file dialog does not accept that path, open the folder `.../app/simplex/lib/app/resources` in the dialog, take a shot, and pick its largest file.
- Files and images go through the app's preset file servers on the internet: uploads and downloads take seconds for the small files and up to minutes for the large one.

## How to do things in the app

- **Send a message:** click the message field at the bottom of the right pane (placeholder "Message"), `ui type "<text>"`, then `ui key Return`.
- **Chat info:** click the chat's name at the top of the right pane. Press Escape to close it and other panes and get back to the chat.
- **Message menu:** `ui right-click <x> <y>` on a message (for a file: on its file name; centre from `ui find`) opens its menu: "Reply", "Copy", "Save", "Download", "Edit", "Forward", "Info", "Stop file", "Revoke file", "Delete" (only the items that apply are shown).
- **Switch profile:** click the profile picture (about 27,730); the menu lists your other profiles by name: click the one you want.
- **Add a profile:** profile picture → "Your chat profiles" → "Add profile". On "Create profile", click the field about 40 px below the text "Enter your name:", type the name, and click the "Create profile" button (the lower of the two "Create profile" texts; the upper one is the title). The new profile becomes the active one; press Escape until the chat list shows.
- **Attach:** click the attachment button, the paperclip icon at the left end of the message field. A row of options shows: "Image", "Video", "File". "Image" and "File" open a file dialog: click its "File Name" field, type the absolute path, and press Return. Back in the app, the compose area shows the image or the file name above the message field; press Return (or click the send button at the right end of the field) to send. Text typed in the field before sending goes with the file.
- **Save dialog:** saving a file opens a file dialog whose "File Name" field holds the suggested name. To save elsewhere: click the field, `ui key ctrl+a`, type the absolute path, press Return. If the path exists, a question "File already exists. Replace it?" appears. A saved file shows the toast "File saved".
- **File states are icons** left of the file name, read from the picture: a received file not yet downloaded has a down arrow; a transfer in progress shows a circle or spinner; a sent and uploaded file shows a check mark; a cancelled file shows a cross. The file name and size are text below or right of the icon.
- **Receive a file:** click the file name of a received file (a down arrow icon). Once it is downloaded, the app opens it by itself: the save dialog, or for a Markdown file its view. Click the dialog's Cancel button unless the case saves the file. Clicking a downloaded file opens the save dialog again.
- **Files count:** profile picture → "Settings" → "Chat data". The footer under "Files & media" says "N file(s) with total size of …" or "No received or sent files". It counts the files of all profiles. Press Escape until the chat list shows. Reopen "Chat data" each time to read a fresh count.

## The test

Run the cases in this order; later cases use what earlier ones set up. Profiles: `citester` sends unless a case says otherwise, `cibob` receives.

**Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone".
2. (S2) As citester: the pencil → "Create 1-time link". Wait up to 60 s for "Share this 1-time invite link". Click the link text under it: the toast "Copied to clipboard" shows. Press Escape until the chat list shows (if "Keep unused invitation?" appears, click "Keep").
3. (S3) Add the profile `cibob`. As cibob: the pencil → "Paste link" → "Tap to paste link". An alert names "citester" with "Open new chat": click it. The chat opens with a "Connect" bar at the bottom: click it. Wait up to 120 s until the message field ("Message") shows in place of the bar, then send `hello from cibob`. Switch to citester. Check: the chat list has "cibob"; open it: it shows "hello from cibob".
4. (S4) As citester: the pencil → "Create group". Click the name field, about 40 px below the text "Enter group name:", type `file group`, and click "Create group". On the next screen click "cibob" (its row gets a check), then "Invite to group". Switch to cibob, open "citester", click "Tap to join" on the invitation. Wait up to 120 s until the group "file group" shows "You joined this group" or its chat opens. Switch to citester, open "file group", send `group hello`. Switch to cibob, open "file group". Check: "group hello" shows.

**Direct files.**

5. (R34.16) As citester in "cibob": attach "File" `images/test-card.jpg` and send. Take shots while it uploads and after: the icon changes from progress to a check mark. Switch to cibob, open "citester": the file "test-card.jpg" shows with a down arrow; click its name; take shots until the download finishes (the arrow becomes a plain file icon; the save dialog opens: Cancel). Open "file group", then "citester" again. Switch to citester and open "cibob" again. Check: on both sides the file keeps its final state after reopening the chat.
6. (R34.25) As cibob in "citester": click the downloaded "test-card.jpg". Check: the save dialog opens with "test-card.jpg" in "File Name". Save to `<working directory>/saved-click.jpg`. Check: the toast "File saved".
7. (R34.26) Right-click the same file → "Save". Save to `<working directory>/test card copy.jpg` (with the spaces). Check: the menu has "Save"; the toast "File saved".
8. (R34.24) Still as cibob in "citester": attach "File" `<working directory>/test card copy.jpg` and send. Check: the sent item shows the name "test card copy.jpg". Switch to citester, open "cibob", click the received "test card copy.jpg" to download it. Check: the download finishes and the save dialog that opens suggests "test card copy.jpg". Click the dialog's Cancel button.
9. (R34.27) As citester in "cibob": attach "File" `images/test-card.jpg`, type `same name`, and send. Switch to cibob, open "citester", download the new "test-card.jpg". Check: both "test-card.jpg" items on cibob's side are downloaded, and clicking each opens the save dialog with "test-card.jpg" (Cancel each).
10. (R34.33) As cibob: right-click the latest "test-card.jpg" → "Reply". Check: the compose area shows the quoted item (its text "same name" and/or the file name "test-card.jpg"). Type `reply to file`, press Return. Check: the sent message shows that quote above "reply to file". Switch to citester, open "cibob". Check: the reply shows there with the same quote. Right-click your file with the text "same name" → "Edit", change the text to `same name edited` (`ui key ctrl+a`, type), press Return. Check: the item now shows "same name edited" (and an edited mark, a small pencil icon by the time); on cibob's side too.
11. (R32.0) As citester in "cibob": attach "File" `<working directory>/prompt.md` and send. Switch to cibob, open "citester", click "prompt.md" to download it; once downloaded the app opens it (if not, click it again). Check: it opens a view of the file with the heading "Test: sending and receiving files in the SimpleX Chat desktop app" rendered as a heading (without "#"). The view's top bar has icon buttons; click the one that switches the view (left of the save icon). Check: the file now shows as plain text with "# Test:" at the start of the first line. Click it again to go back, take shots of both, press Escape.

**Group file.**

12. (R34.17) As citester in "file group": attach "File" `images/simplex-logo.png` and send. Switch to cibob, open "file group". Check: "simplex-logo.png" shows with a down arrow (not downloaded yet). Click it. Check: it downloads (plain file icon; Cancel the save dialog that opens).

**Files count.**

13. (R34.28) As citester: read the files count (N1). In "cibob" attach "File" `images/simplex-logo.png` and send; wait until it shows the check mark. Read the count again (N2). Check: the row expects the sent file to be deleted after the transfer completes, so N2 equals N1. Record N1 and N2.
14. (R34.29) As citester in "cibob": right-click that "simplex-logo.png" → "Delete" → "Delete for me". Read the count (N3). Check: N3 is lower than N2.

**Large file: accepting, stopping, receiving again.**

15. (R34.18) As citester in "cibob": attach "File" the large file and send. At once switch to cibob, open "citester", click the large file's name (accept it) while citester's side still uploads, then click it again. Check: an alert "Waiting for file" says "File will be received when your contact completes uploading it." Click OK. If the upload finished before you accepted, mark SKIPPED with that reason.
16. (R34.20) As cibob, while the large file downloads (progress circle): right-click it → "Stop file". Check: the alert "Stop receiving file?" says "Receiving file will be stopped."; click "Stop". Check: the item returns to the not-downloaded state (down arrow). Switch to citester. Check: its item is unchanged (files go through file servers, so the sender gets no notice; the row's "sender should see cancellation" applies to the older direct transfer: record what citester shows).
17. (R34.21) As cibob: click the large file again. Check: it downloads to the end (plain file icon; Cancel the save dialog that opens). Wait up to 300 s.
18. (R34.19) As citester in "cibob": send the large file again; at once right-click the new item → "Stop file". Check: the alert "Stop sending file?" says "Sending file will be stopped."; click "Stop". Check: the item shows a cross. If the upload finished first (the menu shows "Revoke file", not "Stop file"), mark SKIPPED with that reason.
19. (R34.22) Switch to cibob, open "citester". Check: the item of the file stopped in R34.19 shows a cross, and its menu offers no "Download".
20. (R34.23) As citester in "cibob": attach "File" `images/test-card.jpg`, type `to revoke`, send, and wait for the check mark. Do not download it as cibob. Right-click it → "Revoke file". Check: the alert "Revoke file?" says "File will be deleted from servers."; click "Revoke". Check: the item shows a cross. Switch to cibob. Check: the "to revoke" file shows a cross and offers no "Download".

**Compose.**

21. (R34.34) As citester in "cibob": click the message field and type `https://simplex.chat`. If "Enable link previews?" appears, click "Enable". Wait up to 30 s for a link preview card above the field. Then attach "Image" `images/test-card.jpg`. Check: the image preview replaces the link preview. Clear the compose area (the cross on the image preview, then `ui key ctrl+a`, `ui key BackSpace`). Now attach "Image" `images/test-card.jpg` first, then type `https://simplex.chat` and wait 10 s. Check: no link preview is added. Send it.
22. (R34.36) As citester in "cibob": attach "Image"; in the file dialog type the path of the `images` folder and press Return (the dialog opens it), then type `"test-card.jpg" "simplex-logo.png"` (both names in double quotes, with the quotes) and press Return. Check: the compose area shows two images. Type `two images` and send. Check: the chat shows two images, and the text "two images" is under the second (last) one only. If the dialog takes only one file, mark the case FAIL only if you are sure both were selected; otherwise SKIPPED with what the dialog did.

**Deleting files (destructive, last).**

23. (R34.32) As citester: read the count (C1). Open "file group" → chat info → "Clear chat" → the alert "Clear chat?" → "Clear". Read the count (C2). Check: C2 is lower than C1 (the group's files are deleted) and not "No received or sent files"; open "cibob": its images and files still show, and the image from R34.36 still opens when clicked (Escape closes it).
24. (R34.31) As citester: open "cibob" → chat info → "Delete contact" → the alert "Delete contact?" → "Delete contact" → "Delete without notification". Read the count (C3). Check: C3 is lower than C2 and not "No received or sent files" (cibob's received copies remain); switch to cibob, open "citester": its downloaded files still save (click one: the save dialog opens; Cancel).
25. (R34.35) Profile picture → "Settings" → "Chat data" → "Delete files for all chat profiles" → the alert "Delete files and media?" → "Delete". Check: the footer says "No received or sent files".

You have at most 600 turns, and the whole test fits in about 280 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Create your profile" -- wait "Enter profile name" -- click-text "Enter profile name" -- type citester -- shot profile`
- `ui do click 27 730 -- click-text "cibob" 10 -- click-text "citester" 10 -- shot cibob-chat`
- `ui do click-text "Message" -- type "hello from cibob" -- key Return -- wait "hello from cibob" -- shot sent`
- `ui do click 27 730 -- click-text "Settings" 10 -- click-text "Chat data" 10 -- shot files-count`

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. Create it first with one row per case (S1 to S4, then R34.16, R34.25, R34.26, R34.24, R34.27, R34.33, R32.0, R34.17, R34.28, R34.29, R34.18, R34.20, R34.21, R34.19, R34.22, R34.23, R34.34, R34.36, R34.32, R34.31, R34.35), result `todo`, and fill each row in when its case is done: PASS, FAIL or SKIPPED (with the reason), and the evidence (the text OCR read, the counts, screenshot names). A case the app cannot do here is SKIPPED, not FAIL. Add anything else unexpected under "Findings". End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
