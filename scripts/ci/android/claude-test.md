# Test: attachment options, chat list media previews and media file names in the SimpleX Chat Android app

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button.
- Besides the chats, the chat list shows the app's own cards as list items until they are closed ("New 1-time link / Paste link / Scan", "Bottom bar / Top bar", "Invest in SimpleX Chat!"). Leave them open.
- The emulator's Pictures folder has two images: `test-card.jpg` (a TV test card) and `simplex-logo.png` (the SimpleX logo). "Image" opens Android's photo picker; "File" opens its document picker, where they can be chosen as files (under Images, Pictures or Recent; the picker's side menu, the button at its top left, switches folders).
- Files go through the app's preset file servers on the internet; these small files transfer in seconds.
- Android's own screens (pickers, keyboard) are not part of the app: find their elements in the tree or the screenshot.

## How to do things in the app

- **Send a message:** tap the message field ("Message"), `ui type "<text>"`, then tap "Send Message".
- **Message menu:** `ui long-press <x> <y>` on a message or image opens its menu ("Reply", "Save", "Info", "Delete", …).
- **Profile picture:** the toolbar's left end, level with "Start new chat"; in the tree an element "profile image placeholder" at the toolbar's y. It opens a menu with your other profiles by name and "Your chat profiles".
- **Switch profile:** profile picture → the other profile's name.
- **Add a profile:** profile picture → "Your chat profiles" → "Add profile". The name field (under "Enter your name:") has the focus: type the name, check the field in the tree, tap "Create profile". The new profile becomes the active one; `ui key BACK` until the chat list shows.
- **Attach:** tap "Attach" (left of the message field): it shows "Camera", "Image", "Video" and "File". The compose area then shows the image or file; tap "Send Message".
- **Receive a file:** tap a received file (down arrow icon). Once downloaded, the app opens a small menu by itself with "Save" (and "Open with …"); `ui key BACK` closes it.

## The test

Run the cases in this order. Profiles: `citester` sends, `cibob` receives.

**Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Get started": click it. Click the field "Enter profile name…", type `citester`, and click "Create profile". On "Your network", click "Continue". The app explains instant notifications in an alert: click "Allow". Android then asks whether the app may always run in the background: click "Allow" again. Click "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone".
2. (S2) As citester: "Start new chat" → "Create 1-time link". Wait up to 60 s for "Share this 1-time invite link". The link is the text under it; right of it are two icon buttons without text (in `ui tree`, at the link's y): tap the first, the copy button. `ui key BACK` until the chat list shows (if "Keep unused invitation?" appears, tap "Keep").
3. (S3) Add the profile `cibob`. As cibob: "Start new chat" → "Paste link / Scan" → "Tap to paste link". An alert names "citester" with "Open new chat": tap it. The chat opens with a "Connect" bar at the bottom: tap it. Wait up to 120 s until the message field ("Message") shows in place of the bar, then send `hello from cibob`. Switch to citester. Check: the chat list has "cibob"; open it: it shows "hello from cibob".

**Cases.**

4. (R36.0) As citester in "cibob": tap the message field and take a shot. If no on-screen keyboard shows (the emulator has a hardware keyboard, which can keep it hidden), mark the case SKIPPED with that reason. Otherwise tap "Attach" and take a shot. Check: "Camera", "Image", "Video" and "File" are all on screen, above the keyboard's top edge (their y smaller than the keyboard's top in the picture), none covered by it. `ui key BACK` to close them.
5. (R34.38) As citester in "cibob": "Attach" → "Image" → choose the test card in the photo picker (and its confirm button if it has one); send. Switch to cibob and stay on the chat list. Check: the row "citester" shows a small picture of the test card. Tap that small picture. Check: the image opens full screen (shot; `ui key BACK`). Switch to citester, in "cibob" "Attach" → "File" → choose `simplex-logo.png`; send. Switch to cibob, stay on the chat list. Check: the row "citester" shows a file icon (in the tree an element "File") with "simplex-logo.png". Tap the file icon in the row. Check: it downloads and the menu with "Save" opens by itself (`ui key BACK`).
6. (R34.39) As cibob: open "citester", long-press the test card image → "Save". Then tap "Attach" → "File"; in the document picker open Images (or Pictures, or Recent) and take a shot. Check: the picker lists a newly saved image whose name starts with "IMG_" followed by a date and time; the original name "test-card.jpg" is not given to the saved copy. `ui key BACK` until the chat shows.
7. (R35.0) As citester in "cibob": "Attach" → "File" → `test-card.jpg`; send. Switch to cibob, open "citester", tap the new "test-card.jpg" at once. Check: once it is downloaded, the menu with "Save" opens by itself, without another tap (`ui key BACK`). These files download in seconds, so a tap during the download itself is not checked here.

You have at most 600 turns, and the whole test fits in about 70 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Get started" -- click-text "Enter profile name" 30 -- type citester -- shot profile`
- `ui do click-text "Start new chat" -- click-text "Create 1-time link" 10 -- wait "Share this 1-time invite link" 60 -- shot link`
- `ui do click-text "Message" -- type "hello from cibob" -- click-text "Send Message" -- wait "hello from cibob" -- shot sent`

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. Create it first with one row per case (S1, S2, S3, R36.0, R34.38, R34.39, R35.0), result `todo`, and fill each row in when its case is done: PASS, FAIL or SKIPPED (with the reason), and the evidence (text from the tree, screenshot names). A case the app cannot do here is SKIPPED, not FAIL. Add anything else unexpected under "Findings". End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
