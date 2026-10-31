# Test: chat list media previews, media file names and saving files in the SimpleX Chat desktop app

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- After onboarding, the chat list is in the left pane (x 1 to 389) and chats open in the right pane. An empty chat list shows only its toolbar, with the profile picture at about 27,730 and a pencil (New chat) at about 363,730. The toolbar is at the bottom of the left pane.
- Files to send, by absolute path (`ui` refuses `$`, so write each path out in full, starting from your working directory's absolute path):
  - `<working directory>/images/test-card.jpg` (137 KB, a TV test card) and `<working directory>/images/simplex-logo.png` (28 KB, the SimpleX logo);
  - the large file: your working directory's path ends in `/claude-test`; replace that last part with `/app/simplex/lib/app/resources/libsimplex.so` (the app's core library, tens of megabytes). If the file dialog does not accept that path, open the folder `.../app/simplex/lib/app/resources` in the dialog, take a shot, and pick its largest file.
- Files and images go through the app's preset file servers on the internet: seconds for the small files, up to minutes for the large one.

## How to do things in the app

- **Send a message:** click the message field at the bottom of the right pane (placeholder "Message"), `ui type "<text>"`, then `ui key Return`.
- **Message menu:** `ui right-click <x> <y>` on a message, image or file name opens its menu ("Reply", "Save", "Info", "Delete", …).
- **Switch profile:** click the profile picture (about 27,730); the menu lists your other profiles by name: click the one you want.
- **Add a profile:** profile picture → "Your chat profiles" → "Add profile". On "Create profile", click the field about 40 px below the text "Enter your name:", type the name, and click the "Create profile" button (the lower of the two "Create profile" texts). The new profile becomes the active one; press Escape until the chat list shows.
- **Attach:** click the paperclip icon at the left end of the message field; then "Image" or "File". A file dialog opens: click its "File Name" field, type the absolute path, and press Return. The compose area shows the image or file name; press Return to send.
- **Save dialog:** saving opens a file dialog whose "File Name" field holds the suggested name. To save elsewhere: click the field, `ui key ctrl+a`, type the absolute path, press Return. A saved file shows the toast "File saved". The dialog's Cancel button closes it without saving.
- **File states are icons** left of the file name, read from the picture: down arrow = received, not downloaded; circle = in progress; plain file icon = downloaded; check mark = sent.
- **Receive a file:** click the file name of a received file. Clicking a downloaded file opens the save dialog.

## The test

Run the cases in this order. Profiles: `citester` sends, `cibob` receives, unless a case says otherwise.

**Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone".
2. (S2) As citester: the pencil → "Create 1-time link". Wait up to 60 s for "Share this 1-time invite link". Click the link text under it: the toast "Copied to clipboard" shows. Press Escape until the chat list shows (if "Keep unused invitation?" appears, click "Keep").
3. (S3) Add the profile `cibob`. As cibob: the pencil → "Paste link" → "Tap to paste link". An alert names "citester" with "Open new chat": click it. The chat opens with a "Connect" bar at the bottom: click it. Wait up to 120 s until the message field ("Message") shows in place of the bar, then send `hello from cibob`. Switch to citester. Check: the chat list has "cibob"; open it: it shows "hello from cibob".

**Cases.**

4. (R34.38) As citester in "cibob": attach "Image" `images/test-card.jpg` and send. Switch to cibob and stay on the chat list (press Escape if a chat is open). Check: the row "citester" shows a small picture of the test card. Click that small picture. Check: the image opens large (take a shot; Escape closes it). Switch to citester, attach "File" `images/simplex-logo.png` in "cibob" and send. Switch to cibob, stay on the chat list. Check: the row "citester" shows a file icon with "simplex-logo.png". Click the file icon in the row. Check: the file downloads and then the save dialog opens by itself with "simplex-logo.png"; click Cancel.
5. (R34.39) As cibob: open "citester", right-click the test card image → "Save". Check: the save dialog's "File Name" holds a name starting with "IMG_" followed by a date and time, not "test-card.jpg". Click Cancel. Switch to citester, open "cibob", right-click your sent test card → "Save". Check: the same "IMG_…" name. Cancel.
6. (R35.0) As citester in "cibob": attach "File" the large file and send. Switch to cibob, open "citester", and click the large file's name at once (while it uploads or downloads); click it once more during the download. Wait up to 300 s. Check: once the download finishes, the save dialog opens by itself with the large file's name. Click Cancel.
7. (R38.0) As cibob in "citester": click the downloaded "simplex-logo.png"; in the save dialog save to `<working directory>/.dotlogo.png` (with the leading dot). Check: the toast "File saved". Attach "File" `<working directory>/.dotlogo.png` and send. Check: the sent item's name is ".dotlogo.png". Switch to citester, open "cibob", click the received ".dotlogo.png". Check: when it is downloaded, the save dialog opens and its "File Name" suggests "dotlogo.png" (without the leading dot). Save to `<working directory>/dotlogo.png`; check the toast "File saved". Click the file again and save to the same path `<working directory>/dotlogo.png`. Check: the question "File already exists. Replace it?" appears; click its "No" button, take a shot (the dialog stays), then save to the same path again and click "Yes". Check: the toast "File saved".

You have at most 600 turns, and the whole test fits in about 80 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Create your profile" -- wait "Enter profile name" -- click-text "Enter profile name" -- type citester -- shot profile`
- `ui do click 27 730 -- click-text "cibob" 10 -- key Escape -- shot cibob-list`
- `ui do click-text "Message" -- type "hello from cibob" -- key Return -- wait "hello from cibob" -- shot sent`

`ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Take a shot at each check, named after its case (`ui shot R34-38`).

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. Create it first with one row per case (S1, S2, S3, R34.38, R34.39, R35.0, R38.0), result `todo`, and fill each row in when its case is done: PASS, FAIL or SKIPPED (with the reason), and the evidence (the text OCR read, screenshot names). A case the app cannot do here is SKIPPED, not FAIL. Add anything else unexpected under "Findings". End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
